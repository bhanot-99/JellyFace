#!/usr/bin/env python3
"""Gmail IMAP Email Fetcher & Manager for JellyFace Desktop Dashboard.

Connects to Gmail via secure IMAP (SSL) to fetch recent primary emails,
unread counts, sender info, subjects, snippets, and syncs read/unread status.

Config file: ~/.config/jellyface/mail.json (mode 0600)
State file:  ~/.local/state/jellyface/mail.json

Usage:
  mail.py refresh
  mail.py set-password <app_password>
  mail.py set-account <email_address>
  mail.py mark-read <id>
  mail.py open-client [gmail|thunderbird]
  mail.py status
"""

import email
import email.header
import email.utils
import html
import imaplib
import json
import os
import re
import socket
import subprocess
import sys
import time
from datetime import datetime, timezone

CONF_DIR = os.path.join(os.environ.get("XDG_CONFIG_HOME", os.path.expanduser("~/.config")), "jellyface")
STATE_DIR = os.path.join(os.environ.get("XDG_STATE_HOME", os.path.expanduser("~/.local/state")), "jellyface")
CONF_FILE = os.path.join(CONF_DIR, "mail.json")
STATE_FILE = os.path.join(STATE_DIR, "mail.json")

DEFAULT_EMAIL = "bhanot1054@gmail.com"


def write_private_json(path, data):
    """Write JSON data atomically with 0600 file permissions."""
    os.makedirs(os.path.dirname(path), exist_ok=True)
    tmp = path + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
        f.flush()
        os.fsync(f.fileno())
    os.chmod(tmp, 0o600)
    os.replace(tmp, path)


def load_config():
    """Load configuration, initializing with bhanot1054@gmail.com if not present."""
    cfg = {
        "enabled": True,
        "email": DEFAULT_EMAIL,
        "app_password": "",
        "server": "imap.gmail.com",
        "port": 993,
        "folder": "INBOX",
        "limit": 8
    }
    if os.path.exists(CONF_FILE):
        try:
            with open(CONF_FILE, "r", encoding="utf-8") as f:
                loaded = json.load(f)
                if isinstance(loaded, dict):
                    cfg.update(loaded)
        except Exception as e:
            print(f"[mail] Warning: unable to parse config {CONF_FILE}: {e}", file=sys.stderr)
    else:
        # First-time initialization
        write_private_json(CONF_FILE, cfg)
    return cfg


def save_config(cfg):
    write_private_json(CONF_FILE, cfg)


def load_state():
    if os.path.exists(STATE_FILE):
        try:
            with open(STATE_FILE, "r", encoding="utf-8") as f:
                return json.load(f)
        except Exception:
            pass
    return {"emails": [], "lastUpdated": 0, "status": "unconfigured"}


def save_state(state):
    state["lastUpdated"] = int(time.time())
    write_private_json(STATE_FILE, state)


def decode_mime_header(header_value):
    """Safely decode RFC 2047 MIME encoded headers."""
    if not header_value:
        return ""
    try:
        decoded_parts = email.header.decode_header(header_value)
        result = []
        for part, encoding in decoded_parts:
            if isinstance(part, bytes):
                enc = encoding or "utf-8"
                try:
                    result.append(part.decode(enc, errors="replace"))
                except LookupError:
                    result.append(part.decode("utf-8", errors="replace"))
            else:
                result.append(str(part))
        return " ".join(result).strip()
    except Exception:
        return str(header_value).strip()


def clean_text_snippet(raw_text, max_len=120):
    """Strip HTML tags, URLs, and excessive whitespace into a clean preview snippet."""
    if not raw_text:
        return ""
    text = html.unescape(raw_text)
    # Strip HTML tags
    text = re.sub(r"<[^>]+>", " ", text)
    # Strip URLs
    text = re.sub(r"https?://\S+", "", text)
    # Collapse whitespace
    text = re.sub(r"\s+", " ", text).strip()
    if len(text) > max_len:
        return text[:max_len].rstrip() + "..."
    return text


def format_email_date(date_str):
    """Format RFC 2822 date into human-readable dashboard label."""
    if not date_str:
        return ""
    try:
        dt = email.utils.parsedate_to_datetime(date_str)
        if dt is None:
            return ""
        # Convert to local time
        local_dt = dt.astimezone()
        now = datetime.now(timezone.utc).astimezone()

        if local_dt.date() == now.date():
            # Today: "10:42 AM"
            return local_dt.strftime("%I:%M %p").lstrip("0")
        elif (now.date() - local_dt.date()).days == 1:
            return "Yesterday"
        elif local_dt.year == now.year:
            # This year: "Oct 14"
            return local_dt.strftime("%b %d")
        else:
            return local_dt.strftime("%b %d, %Y")
    except Exception:
        return ""


def get_body_snippet(msg):
    """Extract snippet text from email.message.Message."""
    body_text = ""
    try:
        if msg.is_multipart():
            for part in msg.walk():
                content_type = part.get_content_type()
                content_disp = str(part.get("Content-Disposition", ""))
                if "attachment" in content_disp:
                    continue
                if content_type == "text/plain":
                    payload = part.get_payload(decode=True)
                    if payload:
                        charset = part.get_content_charset() or "utf-8"
                        body_text = payload.decode(charset, errors="replace")
                        break
                elif content_type == "text/html" and not body_text:
                    payload = part.get_payload(decode=True)
                    if payload:
                        charset = part.get_content_charset() or "utf-8"
                        body_text = payload.decode(charset, errors="replace")
        else:
            payload = msg.get_payload(decode=True)
            if payload:
                charset = msg.get_content_charset() or "utf-8"
                body_text = payload.decode(charset, errors="replace")
    except Exception:
        pass
    return clean_text_snippet(body_text)


def fetch_gmail_emails(cfg):
    """Connect to Gmail via IMAP and retrieve latest emails."""
    account = cfg.get("email", DEFAULT_EMAIL)
    password = (cfg.get("app_password") or "").strip().replace(" ", "")
    server = cfg.get("server", "imap.gmail.com")
    port = int(cfg.get("port", 993))
    folder = cfg.get("folder", "INBOX")
    limit = int(cfg.get("limit", 8))

    if not password:
        return None, "no_password"

    socket.setdefaulttimeout(12)
    mail = None
    try:
        mail = imaplib.IMAP4_SSL(server, port)
        mail.login(account, password)
        status, _ = mail.select(folder, readonly=False)
        if status != "OK":
            return None, f"Failed to select folder {folder}"

        # Search for messages
        status, data = mail.search(None, "ALL")
        if status != "OK" or not data or not data[0]:
            mail.close()
            mail.logout()
            return [], "ok"

        msg_ids = data[0].split()
        # Take the most recent 'limit' messages
        recent_ids = msg_ids[-limit:]
        recent_ids.reverse()  # Newest first

        emails_list = []
        for msg_id in recent_ids:
            try:
                # Fetch flags and RFC822 using BODY.PEEK so we don't automatically mark unseen messages as read
                res, fetch_data = mail.fetch(msg_id, "(FLAGS BODY.PEEK[])")
                if res != "OK" or not fetch_data:
                    continue

                raw_email = None
                flags_str = ""
                for part in fetch_data:
                    if isinstance(part, tuple):
                        if len(part) >= 2 and isinstance(part[1], bytes):
                            raw_email = part[1]
                        if len(part) >= 1 and isinstance(part[0], bytes):
                            flags_str = part[0].decode("latin-1", errors="ignore")
                    elif isinstance(part, bytes):
                        flags_str += " " + part.decode("latin-1", errors="ignore")

                if not raw_email:
                    continue

                msg = email.message_from_bytes(raw_email)

                # Parse Flags
                is_unread = "\\Seen" not in flags_str

                # Parse Subject
                subject = decode_mime_header(msg.get("Subject", "(No Subject)"))

                # Parse Sender
                from_header = decode_mime_header(msg.get("From", ""))
                real_name, from_email = email.utils.parseaddr(from_header)
                sender_name = real_name or from_email.split("@")[0] or "Unknown"

                # Parse Date
                date_header = msg.get("Date", "")
                time_str = format_email_date(date_header)
                try:
                    dt = email.utils.parsedate_to_datetime(date_header)
                    timestamp = dt.timestamp() if dt else time.time()
                except Exception:
                    timestamp = time.time()

                # Parse Preview Snippet
                preview = get_body_snippet(msg)
                if not preview:
                    preview = subject

                # Unique ID: use IMAP msg id string with prefix
                imap_id = msg_id.decode("ascii") if isinstance(msg_id, bytes) else str(msg_id)
                msg_uid = f"gmail-{imap_id}"

                emails_list.append({
                    "id": msg_uid,
                    "imap_id": imap_id,
                    "sender": sender_name,
                    "email": from_email,
                    "subject": subject,
                    "preview": preview,
                    "time": time_str,
                    "timestamp": timestamp,
                    "unread": is_unread,
                    "tag": "Primary"
                })
            except Exception as e:
                print(f"[mail] Error parsing message {msg_id}: {e}", file=sys.stderr)
                continue

        try:
            mail.close()
            mail.logout()
        except Exception:
            pass

        return emails_list, "ok"

    except imaplib.IMAP4.error as e:
        err_str = str(e)
        if mail:
            try:
                mail.logout()
            except Exception:
                pass
        return None, f"auth_error: {err_str}"
    except Exception as e:
        if mail:
            try:
                mail.logout()
            except Exception:
                pass
        return None, f"network_error: {e}"


def get_setup_card(account):
    """Helpful setup card shown when the App Password has not yet been entered."""
    return [
        {
            "id": "setup-card",
            "sender": "Gmail Connection Setup",
            "email": account,
            "subject": f"Connect {account} with an App Password",
            "preview": "1. Go to myaccount.google.com/apppasswords -> 2. Generate 16-char App Password -> 3. Run: jellyface mail set-password <password>",
            "time": "Now",
            "timestamp": time.time(),
            "unread": True,
            "tag": "Setup"
        }
    ]


def get_error_card(account, err_msg):
    """Informative card shown if authentication fails."""
    return [
        {
            "id": "error-card",
            "sender": "Gmail Auth Error",
            "email": account,
            "subject": "App Password authentication failed",
            "preview": f"Error: {err_msg}. Ensure 2-Step Verification is on, generate an App Password at myaccount.google.com/apppasswords, and update with: jellyface mail set-password",
            "time": "Now",
            "timestamp": time.time(),
            "unread": True,
            "tag": "Error"
        }
    ]


def refresh():
    cfg = load_config()
    account = cfg.get("email", DEFAULT_EMAIL)

    emails, status = fetch_gmail_emails(cfg)

    if status == "no_password":
        state = {
            "account": account,
            "emails": get_setup_card(account),
            "status": "needs_password",
            "lastError": "No App Password configured"
        }
        save_state(state)
        print(f"[mail] Setup required: enter App Password for {account} via 'jellyface mail set-password <pass>'")
        return

    if status.startswith("auth_error"):
        state = {
            "account": account,
            "emails": get_error_card(account, status.replace("auth_error: ", "")),
            "status": "auth_error",
            "lastError": status
        }
        save_state(state)
        print(f"[mail] Authentication error for {account}: {status}")
        return

    if status.startswith("network_error"):
        print(f"[mail] Network error connecting to Gmail: {status}")
        # Keep existing cached emails if available
        curr_state = load_state()
        if not curr_state.get("emails"):
            curr_state["emails"] = get_error_card(account, "Unable to reach imap.gmail.com")
        curr_state["lastError"] = status
        save_state(curr_state)
        return

    # Successful fetch!
    state = {
        "account": account,
        "emails": emails,
        "status": "synced",
        "lastError": ""
    }
    save_state(state)
    unread_count = sum(1 for m in emails if m.get("unread"))
    print(f"[mail] Successfully synced {len(emails)} emails ({unread_count} unread) from {account}")
    print("__JELLYFACE_MAIL_JSON__" + json.dumps(state, ensure_ascii=False))


def mark_read(mail_id):
    state = load_state()
    cfg = load_config()
    imap_id = None

    # Update local state immediately
    for m in state.get("emails", []):
        if m.get("id") == mail_id:
            m["unread"] = False
            imap_id = m.get("imap_id")

    save_state(state)
    print(f"[mail] Marked {mail_id} as read locally")

    # If this is a real Gmail email with imap_id and credentials exist, sync to server
    password = (cfg.get("app_password") or "").strip().replace(" ", "")
    if imap_id and password:
        try:
            account = cfg.get("email", DEFAULT_EMAIL)
            mail = imaplib.IMAP4_SSL(cfg.get("server", "imap.gmail.com"), int(cfg.get("port", 993)))
            mail.login(account, password)
            mail.select(cfg.get("folder", "INBOX"))
            mail.store(imap_id, "+FLAGS", "\\Seen")
            mail.close()
            mail.logout()
            print(f"[mail] Flagged email {imap_id} as \\Seen on Gmail server")
        except Exception as e:
            print(f"[mail] Note: Could not sync read flag to Gmail server: {e}")


def open_client(client_type="gmail"):
    """Launch mail client securely and detached without shell injection or zombie processes."""
    cfg = load_config()
    account = cfg.get("email", DEFAULT_EMAIL)
    gmail_url = f"https://mail.google.com/mail/u/{account}/"

    if client_type == "gmail":
        subprocess.Popen(
            ["distrobox-host-exec", "brave-browser", f"--app={gmail_url}"],
            start_new_session=True,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL
        )
    else:
        # Check if thunderbird binary exists on host
        has_tb = subprocess.run(
            ["distrobox-host-exec", "which", "thunderbird"],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL
        ).returncode == 0
        if has_tb:
            subprocess.Popen(
                ["distrobox-host-exec", "gtk-launch", "thunderbird"],
                start_new_session=True,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL
            )
        else:
            subprocess.Popen(
                ["distrobox-host-exec", "brave-browser", f"--app={gmail_url}"],
                start_new_session=True,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL
            )


def set_password(password):
    cfg = load_config()
    cleaned = password.strip().replace(" ", "")
    cfg["app_password"] = cleaned
    save_config(cfg)
    print(f"[mail] App password saved securely in {CONF_FILE} (0600 permissions)")
    refresh()


def set_account(account):
    cfg = load_config()
    cfg["email"] = account.strip()
    save_config(cfg)
    print(f"[mail] Account set to {account} in {CONF_FILE}")
    refresh()


def print_status():
    cfg = load_config()
    state = load_state()
    account = cfg.get("email", DEFAULT_EMAIL)
    has_pwd = bool((cfg.get("app_password") or "").strip())
    emails = state.get("emails", [])
    unread = sum(1 for m in emails if m.get("unread"))
    last_updated = state.get("lastUpdated", 0)
    updated_str = time.strftime("%Y-%m-%d %H:%M:%S", time.localtime(last_updated)) if last_updated else "Never"

    print("═════════════════════════════════════════════════════")
    print(" JellyFace Gmail Integration Status")
    print("═════════════════════════════════════════════════════")
    print(f" Account:       {account}")
    print(f" App Password:  {'Configured (' + str(len(cfg.get('app_password', ''))) + ' chars)' if has_pwd else 'NOT CONFIGURED'}")
    print(f" Server:        {cfg.get('server', 'imap.gmail.com')}:{cfg.get('port', 993)}")
    print(f" Status:        {state.get('status', 'unknown')}")
    print(f" Last Updated:  {updated_str}")
    print(f" Cached Emails: {len(emails)} ({unread} unread)")
    if state.get("lastError"):
        print(f" Last Error:    {state.get('lastError')}")
    print("─────────────────────────────────────────────────────")
    if not has_pwd:
        print(" To start live syncing with Gmail:")
        print(" 1. Ensure 2-Step Verification is active on your Google Account.")
        print(" 2. Open: https://myaccount.google.com/apppasswords")
        print(" 3. Create an App Password named 'JellyFace'.")
        print(" 4. Run: jellyface mail set-password <16-character-password>")
    print("═════════════════════════════════════════════════════")


def main():
    if len(sys.argv) < 2:
        refresh()
        return

    cmd = sys.argv[1].lower()

    if cmd in ("refresh", "sync"):
        refresh()
    elif cmd in ("set-password", "password"):
        if len(sys.argv) < 3:
            print("Error: Password required. Usage: jellyface mail set-password <16-char-app-password>", file=sys.stderr)
            sys.exit(1)
        set_password(sys.argv[2])
    elif cmd in ("set-account", "account"):
        if len(sys.argv) < 3:
            print("Error: Email required. Usage: jellyface mail set-account <email>", file=sys.stderr)
            sys.exit(1)
        set_account(sys.argv[2])
    elif cmd == "mark-read":
        if len(sys.argv) < 3:
            print("Error: Mail ID required. Usage: jellyface mail mark-read <id>", file=sys.stderr)
            sys.exit(1)
        mark_read(sys.argv[2])
    elif cmd == "open-client":
        client = sys.argv[2] if len(sys.argv) > 2 else "gmail"
        open_client(client)
    elif cmd in ("status", "info"):
        print_status()
    else:
        print(f"Unknown command: {cmd}")
        print("Valid commands: refresh, set-password, set-account, mark-read, open-client, status")
        sys.exit(1)


if __name__ == "__main__":
    main()
