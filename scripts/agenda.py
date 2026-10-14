#!/usr/bin/env python3
"""Reads the calendar named in ~/.config/jellyface/desktop.json ("agenda.source": a local .ics path or an http(s)
iCal URL, for example Google Calendar's "secret address in iCal format") and writes the next few days of events to
~/.local/state/jellyface/agenda.json for the desktop Agenda card. Standard library only.

Supported: timed and all-day events, UTC / TZID / floating times, and simple repeats (RRULE DAILY, WEEKLY with
BYDAY, MONTHLY, YEARLY, INTERVAL, COUNT, UNTIL; EXDATE). Anything it cannot read is skipped, never fatal.
"""
import json, os, re, sys, urllib.request
from datetime import date, datetime, timedelta, timezone

try:
    from zoneinfo import ZoneInfo
except ImportError:  # pragma: no cover
    ZoneInfo = None

CONF = os.path.join(os.environ.get("XDG_CONFIG_HOME", os.path.expanduser("~/.config")), "jellyface", "desktop.json")
OUT = os.path.join(os.environ.get("XDG_STATE_HOME", os.path.expanduser("~/.local/state")), "jellyface", "agenda.json")
DAYS = {"MO": 0, "TU": 1, "WE": 2, "TH": 3, "FR": 4, "SA": 5, "SU": 6}


def write(obj):
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    tmp = OUT + ".tmp"
    with open(tmp, "w") as f:
        json.dump(obj, f)
    os.replace(tmp, OUT)


def read_source(src):
    if re.match(r"https?://", src):
        req = urllib.request.Request(src, headers={"User-Agent": "JellyFace-agenda"})
        with urllib.request.urlopen(req, timeout=20) as r:
            return r.read().decode("utf-8", "replace")
    with open(os.path.expanduser(src), encoding="utf-8", errors="replace") as f:
        return f.read()


def unfold(text):
    out = []
    for line in text.replace("\r\n", "\n").replace("\r", "\n").split("\n"):
        if line[:1] in (" ", "\t") and out:
            out[-1] += line[1:]
        else:
            out.append(line)
    return out


def unescape(v):
    return re.sub(r"\\([nN,;\\])", lambda m: "\n" if m.group(1) in "nN" else m.group(1), v)


def parse_dt(value, params):
    """-> (datetime in local naive time or date, all_day)"""
    value = value.strip()
    if "VALUE=DATE" in params.upper() or re.fullmatch(r"\d{8}", value):
        return datetime.strptime(value[:8], "%Y%m%d"), True
    if value.endswith("Z"):
        dt = datetime.strptime(value, "%Y%m%dT%H%M%SZ").replace(tzinfo=timezone.utc)
        return dt.astimezone().replace(tzinfo=None), False
    dt = datetime.strptime(value[:15], "%Y%m%dT%H%M%S")
    m = re.search(r"TZID=([^;:]+)", params)
    if m and ZoneInfo:
        try:
            return dt.replace(tzinfo=ZoneInfo(m.group(1))).astimezone().replace(tzinfo=None), False
        except Exception:
            pass
    return dt, False


def parse_events(text):
    events, cur = [], None
    for line in unfold(text):
        if line == "BEGIN:VEVENT":
            cur = {"exdates": []}
        elif line == "END:VEVENT":
            if cur and "start" in cur:
                events.append(cur)
            cur = None
        elif cur is not None and ":" in line:
            head, value = line.split(":", 1)
            name, _, params = head.partition(";")
            name = name.upper()
            try:
                if name == "DTSTART":
                    cur["start"], cur["allday"] = parse_dt(value, params)
                elif name == "DTEND":
                    cur["end"], _ = parse_dt(value, params)
                elif name == "SUMMARY":
                    cur["title"] = unescape(value)
                elif name == "LOCATION":
                    cur["location"] = unescape(value)
                elif name == "RRULE":
                    cur["rrule"] = dict(p.split("=", 1) for p in value.split(";") if "=" in p)
                elif name == "EXDATE":
                    for v in value.split(","):
                        cur["exdates"].append(parse_dt(v, params)[0])
                elif name == "STATUS" and value.upper() == "CANCELLED":
                    cur["cancelled"] = True
            except Exception:
                pass
    return events


def occurrences(ev, lo, hi):
    start = ev["start"]
    length = (ev["end"] - start) if "end" in ev else timedelta(hours=0 if ev["allday"] else 1)
    if ev["allday"] and length <= timedelta(0):
        length = timedelta(days=1)
    rule = ev.get("rrule")
    if not rule:
        yield start, start + length
        return
    freq, step = rule.get("FREQ"), int(rule.get("INTERVAL", "1"))
    count = int(rule["COUNT"]) if "COUNT" in rule else None
    until = None
    if "UNTIL" in rule:
        try:
            until = parse_dt(rule["UNTIL"], "")[0] + (timedelta(days=1) if len(rule["UNTIL"]) == 8 else timedelta(0))
        except Exception:
            pass
    byday = [DAYS[d[-2:]] for d in rule.get("BYDAY", "").split(",") if d[-2:] in DAYS]
    n, day = 0, start.replace(hour=0, minute=0, second=0)
    tod = start - day
    guard = 0
    cur = day
    while cur <= hi + timedelta(days=1) and guard < 5000:
        guard += 1
        ok = False
        if freq == "DAILY":
            ok = (cur - day).days % step == 0
        elif freq == "WEEKLY":
            wk = ((cur - day).days + day.weekday()) // 7
            ok = wk % step == 0 and cur.weekday() in (byday or [start.weekday()])
        elif freq == "MONTHLY":
            months = (cur.year - day.year) * 12 + cur.month - day.month
            ok = months % step == 0 and cur.day == start.day
        elif freq == "YEARLY":
            ok = (cur.year - day.year) % step == 0 and (cur.month, cur.day) == (start.month, start.day)
        if ok and cur >= day:
            n += 1
            if count is not None and n > count:
                return
            occ = cur + tod
            if until is not None and occ > until:
                return
            yield occ, occ + length
        cur += timedelta(days=1)


def main():
    try:
        with open(CONF) as f:
            conf = json.load(f).get("agenda", {})
    except Exception:
        conf = {}
    src = conf.get("source", "") or ""
    days = int(conf.get("days", 2))
    if not src:
        write({"state": "no-source", "events": [], "updated": datetime.now().isoformat()})
        return
    try:
        events = parse_events(read_source(src))
    except Exception as e:
        write({"state": "error", "error": str(e)[:200], "events": [], "updated": datetime.now().isoformat()})
        return
    now = datetime.now()
    lo = now.replace(hour=0, minute=0, second=0, microsecond=0)
    hi = lo + timedelta(days=days)
    out = []
    for ev in events:
        if ev.get("cancelled"):
            continue
        try:
            for s, e in occurrences(ev, lo, hi):
                if e <= lo or s >= hi or any(abs((s - x).total_seconds()) < 60 for x in ev["exdates"]):
                    continue
                out.append({"title": ev.get("title", "(no title)"), "location": ev.get("location", ""),
                            "start": s.isoformat(), "end": e.isoformat(), "allDay": ev["allday"]})
        except Exception:
            continue
    out.sort(key=lambda x: (x["start"], x["title"]))
    write({"state": "ok", "events": out[:60], "updated": now.isoformat()})


main()
