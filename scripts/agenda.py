#!/usr/bin/env python3
"""Reads the calendar named in ~/.config/jellyface/desktop.json ("agenda.source": a local .ics path or an http(s)
iCal URL, for example Google Calendar's "secret address in iCal format") and writes the next few days of events to
~/.local/state/jellyface/agenda.json for the desktop Agenda card. Standard library only.

Commands:  agenda.py            refresh now
           agenda.py add TITLE YYYY-MM-DD [HH:MM [HH:MM [LOCATION]]]   add a local event (no time = all day)
           agenda.py remove ID  remove a local event
           agenda.py set SRC    save the calendar source (.ics path or iCal URL) and refresh
           agenda.py add-source SRC | remove-source SRC   extra calendars (a friend's, a team's, a sports fixture list ...)
           agenda.py holidays [REGION ...]   show Google's public holidays and festivals for a region, for example
                                    indian, usa, uk, canadian, australian, german, "christian" or "hindu" (none = clear)
           agenda.py status

Supported: timed and all-day events, UTC / TZID / floating times, and simple repeats (RRULE DAILY, WEEKLY with
BYDAY, MONTHLY, YEARLY, INTERVAL, COUNT, UNTIL; EXDATE). Anything it cannot read is skipped, never fatal.
"""
import hashlib, json, os, re, sys, time, urllib.request
from datetime import date, datetime, timedelta, timezone

try:
    from zoneinfo import ZoneInfo
except ImportError:  # pragma: no cover
    ZoneInfo = None

CONF = os.path.join(os.environ.get("XDG_CONFIG_HOME", os.path.expanduser("~/.config")), "jellyface", "desktop.json")
LOCAL = os.path.join(os.environ.get("XDG_STATE_HOME", os.path.expanduser("~/.local/state")), "jellyface", "events.json")
OUT = os.path.join(os.environ.get("XDG_STATE_HOME", os.path.expanduser("~/.local/state")), "jellyface", "agenda.json")
MONTHS = os.path.join(os.environ.get("XDG_STATE_HOME", os.path.expanduser("~/.local/state")), "jellyface", "calendar.json")
HOLIDAY_URL = "https://calendar.google.com/calendar/ical/{}%23holiday%40group.v.calendar.google.com/public/basic.ics"
DAYS = {"MO": 0, "TU": 1, "WE": 2, "TH": 3, "FR": 4, "SA": 5, "SU": 6}


def write_private(path, obj, **kw):
    """Atomic write, readable by you only (calendar events and the secret iCal address are private)."""
    os.makedirs(os.path.dirname(path), exist_ok=True)
    tmp = path + ".tmp"
    with os.fdopen(os.open(tmp, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600), "w") as f:
        json.dump(obj, f, **kw)
    os.replace(tmp, path)


def write(obj):
    write_private(OUT, obj)


def read_source(src):
    src = re.sub(r"^webcal://", "https://", src, flags=re.I)
    if re.match(r"https?://", src):
        req = urllib.request.Request(src, headers={"User-Agent": "JellyFace-agenda"})
        with urllib.request.urlopen(req, timeout=20) as r:
            return r.read(20_000_000).decode("utf-8", "replace")   # a calendar is kilobytes; never read an endless reply
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


def event_zone(value, params):
    """The zone a start time is written in (None for all-day and floating times): recurrences repeat at the same WALL-CLOCK
    time in that zone, so they move by an hour in local time when daylight saving changes there."""
    value = value.strip()
    if "VALUE=DATE" in params.upper() or re.fullmatch(r"\d{8}", value):
        return None
    if value.endswith("Z"):
        return timezone.utc
    m = re.search(r"TZID=([^;:]+)", params)
    if m and ZoneInfo:
        try:
            return ZoneInfo(m.group(1))
        except Exception:
            return None
    return None


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
                    cur["tz"] = event_zone(value, params)
                    if cur["tz"] is not None:   # the same moment as the zone's wall clock reads it
                        wall = datetime.strptime(value.strip().rstrip("Z")[:15], "%Y%m%dT%H%M%S")
                        cur["wall"] = wall
                elif name == "UID":
                    cur["uid"] = value.strip()
                elif name == "RECURRENCE-ID":
                    cur["recid"] = parse_dt(value, params)[0]
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
    # a changed or cancelled single occurrence of a repeating event is its own VEVENT (RECURRENCE-ID): the repeat must
    # skip that date, or the old occurrence shows up next to the moved one
    masters = {}
    for ev in events:
        if "rrule" in ev and "uid" in ev:
            masters.setdefault(ev["uid"], []).append(ev)
    for ev in events:
        if "recid" in ev:
            for m in masters.get(ev.get("uid"), []):
                m["exdates"].append(ev["recid"])
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
    tz = ev.get("tz")
    wall_start = ev.get("wall", start)   # the repeat runs on the event's own wall clock (see event_zone)

    def local(wall):
        if tz is None:
            return wall
        return wall.replace(tzinfo=tz).astimezone().replace(tzinfo=None)

    freq, step = rule.get("FREQ"), int(rule.get("INTERVAL", "1"))
    count = int(rule["COUNT"]) if "COUNT" in rule else None
    until = None
    if "UNTIL" in rule:
        try:
            until = parse_dt(rule["UNTIL"], "")[0] + (timedelta(days=1) if len(rule["UNTIL"]) == 8 else timedelta(0))
        except Exception:
            pass
    byday = [DAYS[d[-2:]] for d in rule.get("BYDAY", "").split(",") if d[-2:] in DAYS]
    n, day = 0, wall_start.replace(hour=0, minute=0, second=0)
    tod = wall_start - day
    guard = 0
    cur = day
    if count is None:
        # no COUNT: occurrences only depend on the distance from the start, so skip straight to the window (a birthday
        # that started 20 years ago would otherwise run out of loop iterations before reaching today)
        cur = max(day, (lo - length).replace(hour=0, minute=0, second=0, microsecond=0) - timedelta(days=2))
    while cur <= hi + timedelta(days=2) and guard < 5000:
        guard += 1
        ok = False
        if freq == "DAILY":
            ok = (cur - day).days % step == 0
        elif freq == "WEEKLY":
            wk = ((cur - day).days + day.weekday()) // 7
            ok = wk % step == 0 and cur.weekday() in (byday or [wall_start.weekday()])
        elif freq == "MONTHLY":
            months = (cur.year - day.year) * 12 + cur.month - day.month
            ok = months % step == 0 and cur.day == wall_start.day
        elif freq == "YEARLY":
            ok = (cur.year - day.year) % step == 0 and (cur.month, cur.day) == (wall_start.month, wall_start.day)
        if ok and cur >= day:
            n += 1
            if count is not None and n > count:
                return
            occ = local(cur + tod)
            if until is not None and occ > until:
                return
            yield occ, occ + length
        cur += timedelta(days=1)


def set_source(src):
    try:
        with open(CONF) as f:
            conf = json.load(f)
    except Exception:
        conf = {}
    conf.setdefault("agenda", {})["source"] = src
    write_private(CONF, conf, indent=4)
    print("agenda source saved" if src else "agenda source cleared")


def update_conf(fn):
    try:
        with open(CONF) as f:
            conf = json.load(f)
    except Exception:
        conf = {}
    fn(conf.setdefault("agenda", {}))
    write_private(CONF, conf, indent=4)


def set_list(key, items, label):
    update_conf(lambda a: a.__setitem__(key, items))
    print(f"{label}: " + (", ".join(items) if items else "none"))


def holiday_url(region):
    region = region.strip().lower()
    return HOLIDAY_URL.format(region if "." in region else f"en.{region}")


def load_local():
    try:
        with open(LOCAL) as f:
            data = json.load(f)
        return data if isinstance(data, list) else []
    except Exception:
        return []


def save_local(items):
    write_private(LOCAL, items)


def add_local(args):
    if len(args) < 2:
        sys.exit("usage: agenda.py add TITLE YYYY-MM-DD [HH:MM [HH:MM [LOCATION]]]")
    title, day = args[0].strip(), args[1]
    start_t = args[2] if len(args) > 2 else ""
    end_t = args[3] if len(args) > 3 else ""
    loc = args[4] if len(args) > 4 else ""
    if not title:
        sys.exit("an event needs a title")
    try:
        d = datetime.strptime(day, "%Y-%m-%d")
        if start_t:
            s = datetime.strptime(f"{day} {start_t}", "%Y-%m-%d %H:%M")
            e = datetime.strptime(f"{day} {end_t}", "%Y-%m-%d %H:%M") if end_t else s + timedelta(hours=1)
            if e <= s:
                e = s + timedelta(hours=1)
        else:
            s, e = d, d + timedelta(days=1)
    except ValueError:
        sys.exit("bad date or time (use YYYY-MM-DD and HH:MM)")
    items = load_local()
    items.append({"id": "L" + hashlib.sha1(f"{title}{s}{time.time()}".encode()).hexdigest()[:10], "title": title,
                  "location": loc, "start": s.isoformat(), "end": e.isoformat(), "allDay": not start_t})
    save_local(items)


def add_days(days_map, s, e, title, holiday):
    """Every calendar day an event touches (an all-day event ends at midnight of the day AFTER its last day)."""
    last = e - timedelta(seconds=1) if e > s else s
    d = s.replace(hour=0, minute=0, second=0, microsecond=0)
    while d <= last and len(days_map) < 800:
        days_map.setdefault(d.strftime("%Y-%m-%d"), []).append({"title": title, "holiday": holiday})
        d += timedelta(days=1)


def main():
    if len(sys.argv) > 2 and sys.argv[1] in ("add-source", "remove-source"):
        cur = []
        try:
            with open(CONF) as f:
                cur = list(json.load(f).get("agenda", {}).get("sources", []))
        except Exception:
            pass
        src = sys.argv[2]
        cur = [x for x in cur if x != src] + ([src] if sys.argv[1] == "add-source" else [])
        set_list("sources", cur, "extra calendars")
    elif len(sys.argv) > 1 and sys.argv[1] == "holidays":
        set_list("holidays", [r for r in sys.argv[2:] if r.strip()], "holiday calendars")
    elif len(sys.argv) > 1 and sys.argv[1] == "add":
        add_local(sys.argv[2:])
    elif len(sys.argv) > 2 and sys.argv[1] == "remove":
        save_local([e for e in load_local() if e["id"] != sys.argv[2]])
    elif len(sys.argv) > 1 and sys.argv[1] == "set":
        set_source(sys.argv[2] if len(sys.argv) > 2 else "")
    elif len(sys.argv) > 1 and sys.argv[1] == "status":
        try:
            with open(OUT) as f:
                d = json.load(f)
            print(d.get("state"), len(d.get("events", [])), "events", d.get("error", ""))
        except Exception:
            print("no agenda data yet")
        return
    try:
        with open(CONF) as f:
            conf = json.load(f).get("agenda", {})
    except Exception:
        conf = {}
    sources = [(x, False) for x in ([conf.get("source", "")] + list(conf.get("sources", []))) if x]
    sources += [(holiday_url(r), True) for r in conf.get("holidays", []) if str(r).strip()]
    try:
        days = max(1, int(conf.get("days", 2)))
    except (TypeError, ValueError):
        days = 2
    now = datetime.now()
    lo = now.replace(hour=0, minute=0, second=0, microsecond=0)
    hi = lo + timedelta(days=days)
    # the month grid on the dashboard looks further around than the card does
    mlo, mhi = lo - timedelta(days=45), lo + timedelta(days=200)
    state, error, events = "ok", "", []
    for src, holiday in sources:
        try:
            events += [{**ev, "holiday": holiday} for ev in parse_events(read_source(src))]
        except Exception as e:
            state, error = "error", str(e)[:200]
    out, days_map = [], {}
    for ev in load_local():
        try:
            s, e = datetime.fromisoformat(ev["start"]), datetime.fromisoformat(ev["end"])
            if e > lo and s < hi:
                out.append({**ev, "local": True})
            if e > mlo and s < mhi:
                add_days(days_map, s, e, ev["title"], False)
        except Exception:
            continue
    if not sources and not out and not load_local():
        state = "no-source"
    for ev in events:
        if ev.get("cancelled"):
            continue
        try:
            for s, e in occurrences(ev, mlo, mhi):
                if e <= mlo or s >= mhi or any(abs((s - x).total_seconds()) < 60 for x in ev["exdates"]):
                    continue
                title = ev.get("title", "(no title)")
                add_days(days_map, s, e, title, ev["holiday"])
                if e > lo and s < hi:
                    out.append({"title": title, "location": ev.get("location", ""), "start": s.isoformat(),
                                "end": e.isoformat(), "allDay": ev["allday"]})
        except Exception:
            continue
    out.sort(key=lambda x: (x["start"], x["title"]))
    write({"state": state, "error": error, "events": out[:60], "updated": now.isoformat()})
    write_private(MONTHS, {d: sorted(v, key=lambda x: (not x["holiday"], x["title"]))[:6] for d, v in days_map.items()})


main()
