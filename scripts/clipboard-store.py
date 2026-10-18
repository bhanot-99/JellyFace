#!/usr/bin/env python3
"""JellyFace clipboard history store.

  clipboard-store.py add            called by `wl-paste --watch` after every clipboard change: records the new content
  clipboard-store.py pin ID         pin / unpin an entry (pinned entries are never trimmed)
  clipboard-store.py delete ID      remove one entry
  clipboard-store.py clear          remove everything except pinned entries

History lives in ~/.local/state/jellyface/clipboard/history.json (newest first); images are saved next to it as PNG.
Content that a password manager marks as sensitive is never stored.
"""
import fcntl, glob, hashlib, json, os, subprocess, sys, threading, time

STATE = os.path.join(os.environ.get("XDG_STATE_HOME", os.path.expanduser("~/.local/state")), "jellyface", "clipboard")
HIST = os.path.join(STATE, "history.json")
MAX_ENTRIES = 50          # unpinned entries kept
MAX_TEXT = 200_000        # characters; longer text is not stored
MAX_IMAGE = 8_000_000     # bytes


def run(*cmd, limit=None):
    """stdout of cmd. With a limit, reading stops one byte past it (the caller sees len > limit and skips the entry), so a
    huge clipboard is never pulled into memory just to be thrown away. Killed after 5 s."""
    try:
        p = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
    except OSError:
        return b""
    timer = threading.Timer(5, p.kill)
    timer.start()
    try:
        data = p.stdout.read(limit + 1) if limit else p.stdout.read()
    except Exception:
        data = b""
    finally:
        timer.cancel()
        p.kill()
        p.wait()
        p.stdout.close()
    return data


def load():
    try:
        with open(HIST) as f:
            data = json.load(f)
        # a damaged or hand-edited entry must not make every later copy fail
        return [e for e in data if isinstance(e, dict) and isinstance(e.get("id"), str)] if isinstance(data, list) else []
    except Exception:
        return []


def private(path, flags=os.O_WRONLY | os.O_CREAT | os.O_TRUNC):
    """Open for writing, readable by you only (the history can hold anything you copied)."""
    return os.fdopen(os.open(path, flags, 0o600), "wb" if flags & os.O_TRUNC else "w")


def save(entries):
    tmp = HIST + ".tmp"
    with private(tmp) as f:
        f.write(json.dumps(entries).encode())
    os.replace(tmp, HIST)


def drop_file(e):
    if e.get("file"):
        try:
            os.remove(e["file"])
        except OSError:
            pass


def trim(entries):
    keep, unpinned = [], 0
    for e in entries:
        if e.get("pinned"):
            keep.append(e)
        elif unpinned < MAX_ENTRIES:
            unpinned += 1
            keep.append(e)
        else:
            drop_file(e)
    return keep


def add(entries):
    types = run("wl-paste", "--list-types").decode(errors="replace").split()
    if not types or any("passwordManagerHint" in t for t in types):
        return entries
    entry = None
    if any(t.startswith("text/plain") or t in ("UTF8_STRING", "STRING") for t in types):
        raw = run("wl-paste", "--no-newline", "--type", "text/plain", limit=MAX_TEXT * 4)   # up to 4 bytes per character
        text = raw.decode(errors="replace")
        if not text.strip() or len(text) > MAX_TEXT:
            return entries
        key = hashlib.sha1(text.encode()).hexdigest()[:16]
        entry = {"id": key, "kind": "text", "text": text}
    elif "image/png" in types:
        data = run("wl-paste", "--type", "image/png", limit=MAX_IMAGE)
        if not data or len(data) > MAX_IMAGE:
            return entries
        key = hashlib.sha1(data).hexdigest()[:16]
        path = os.path.join(STATE, f"img-{key}.png")
        with private(path) as f:
            f.write(data)
        entry = {"id": key, "kind": "image", "file": path, "text": ""}
    if not entry:
        return entries
    old = next((e for e in entries if e["id"] == entry["id"]), None)
    entry["pinned"] = bool(old and old.get("pinned"))
    entry["time"] = int(time.time())
    entries = [e for e in entries if e["id"] != entry["id"]]
    return trim([entry] + entries)


def prune_orphans(entries):
    """Delete image files nothing refers to any more (history lost or reset, an interrupted copy)."""
    used = {e.get("file") for e in entries}
    for path in glob.glob(os.path.join(STATE, "img-*.png")):
        if path not in used:
            try:
                os.remove(path)
            except OSError:
                pass


def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else ""
    os.makedirs(STATE, mode=0o700, exist_ok=True)
    try:
        os.chmod(STATE, 0o700)   # also for a history folder created by an older version
    except OSError:
        pass
    with open(os.path.join(STATE, ".lock"), "w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        entries = load()
        if cmd == "add":
            entries = add(entries)
        elif cmd == "pin" and len(sys.argv) > 2:
            for e in entries:
                if e["id"] == sys.argv[2]:
                    e["pinned"] = not e.get("pinned")
        elif cmd == "delete" and len(sys.argv) > 2:
            for e in entries:
                if e["id"] == sys.argv[2]:
                    drop_file(e)
            entries = [e for e in entries if e["id"] != sys.argv[2]]
        elif cmd == "clear":
            for e in entries:
                if not e.get("pinned"):
                    drop_file(e)
            entries = [e for e in entries if e.get("pinned")]
        else:
            sys.exit("usage: clipboard-store.py add|pin ID|delete ID|clear")
        prune_orphans(entries)
        save(entries)


main()
