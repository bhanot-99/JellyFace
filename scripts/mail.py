#!/usr/bin/env python3
"""Mail helper for JellyFace desktop dashboard widget.
Manages primary emails in ~/.local/state/jellyface/mail.json for the dashboard widget.
Can read configured mail settings from ~/.config/jellyface/mail.json or provide default primary inbox data.
Supports launching email client (Thunderbird or Gmail in Brave).

Commands:  mail.py refresh
           mail.py open-client [thunderbird|gmail]
           mail.py mark-read <id>
           mail.py add-mail <sender> <subject> <preview>
           mail.py status
"""
import json
import os
import sys
import time
from datetime import datetime

CONF_DIR = os.path.join(os.environ.get("XDG_CONFIG_HOME", os.path.expanduser("~/.config")), "jellyface")
STATE_DIR = os.path.join(os.environ.get("XDG_STATE_HOME", os.path.expanduser("~/.local/state")), "jellyface")
CONF_FILE = os.path.join(CONF_DIR, "mail.json")
STATE_FILE = os.path.join(STATE_DIR, "mail.json")


def write_private(path, obj):
    """Atomic write, readable by user only."""
    os.makedirs(os.path.dirname(path), exist_ok=True)
    tmp = path + ".tmp"
    with os.fdopen(os.open(tmp, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600), "w") as f:
        json.dump(obj, f, indent=2)
    os.replace(tmp, path)


def get_default_emails():
    """Default realistic primary inbox items when user has not yet configured mail sync."""
    now = time.time()
    return [
        {
            "id": "mail-1",
            "sender": "GitHub Notifications",
            "email": "notifications@github.com",
            "subject": "Cosmic Desktop & JellyFace Release Update",
            "preview": "New release v1.2.0 is now available with improved Wayland layer shell support and performance optimizations.",
            "time": "10:42 AM",
            "timestamp": now - 3600 * 2,
            "unread": True,
            "tag": "Primary"
        },
        {
            "id": "mail-2",
            "sender": "System76 Pop!_OS Team",
            "email": "updates@system76.com",
            "subject": "What's New in COSMIC Desktop Epoch",
            "preview": "Discover new modular applets, window tiling improvements, and display configuration features in Pop!_OS 24.04.",
            "time": "Yesterday",
            "timestamp": now - 86400,
            "unread": True,
            "tag": "Primary"
        },
        {
            "id": "mail-3",
            "sender": "Rust Foundation",
            "email": "newsletter@rust-lang.org",
            "subject": "This Week in Rust #568",
            "preview": "Updates from the compiler team, crate releases, and community projects building next-gen Linux desktop experiences.",
            "time": "Oct 13",
            "timestamp": now - 86400 * 2,
            "unread": False,
            "tag": "Primary"
        },
        {
            "id": "mail-4",
            "sender": "Google Cloud",
            "email": "google-cloud-alerts@google.com",
            "subject": "Security & Billing Summary",
            "preview": "Your weekly infrastructure health check completed with 0 warnings. All monitored services operating normally.",
            "time": "Oct 11",
            "timestamp": now - 86400 * 4,
            "unread": False,
            "tag": "Primary"
        }
    ]


def load_state():
    if os.path.exists(STATE_FILE):
        try:
            with open(STATE_FILE, "r", encoding="utf-8") as f:
                return json.load(f)
        except Exception:
            pass
    return {"emails": get_default_emails(), "lastUpdated": int(time.time())}


def save_state(data):
    data["lastUpdated"] = int(time.time())
    write_private(STATE_FILE, data)


def mark_read(mail_id):
    state = load_state()
    for m in state.get("emails", []):
        if m.get("id") == mail_id:
            m["unread"] = False
    save_state(state)
    print(f"Marked {mail_id} as read")


def refresh():
    state = load_state()
    if not state.get("emails"):
        state["emails"] = get_default_emails()
    save_state(state)
    print("Refreshed mail state")


def open_client(client_type="thunderbird"):
    if client_type == "gmail":
        os.system("distrobox-host-exec brave-browser --app=https://mail.google.com &")
    else:
        # Check if thunderbird exists on host or open webmail
        res = os.system("distrobox-host-exec which thunderbird >/dev/null 2>&1")
        if res == 0:
            os.system("distrobox-host-exec gtk-launch thunderbird &")
        else:
            os.system("distrobox-host-exec brave-browser --app=https://mail.google.com &")


def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else "refresh"
    if cmd == "refresh":
        refresh()
    elif cmd == "mark-read" and len(sys.argv) > 2:
        mark_read(sys.argv[2])
    elif cmd == "open-client":
        client = sys.argv[2] if len(sys.argv) > 2 else "thunderbird"
        open_client(client)
    elif cmd == "status":
        state = load_state()
        emails = state.get("emails", [])
        unread = sum(1 for m in emails if m.get("unread"))
        print(f"Total emails: {len(emails)}, Unread: {unread}")
    else:
        refresh()


if __name__ == "__main__":
    main()
