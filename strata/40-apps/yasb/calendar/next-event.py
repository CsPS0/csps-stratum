#!/usr/bin/env python3
"""Next calendar event for the YASB top bar.

Reads one or more private iCal links (Google Calendar: Settings > your calendar > Integrate
calendar > "Secret address in iCal format") from calendar-url.txt next to YASB's config, one per
line, and prints JSON for a YASB Custom widget:

    {"text": "14:00 Standup", "tooltip": "Sat 21 Nov 14:00  Standup\n..."}

Nothing is printed when there is no upcoming event, so the widget hides itself.

The link gives read access to the calendar, so it lives only in that local file (never in the
repo). The last download is cached next to it so the widget keeps working offline.

Standard library only. Windows Python ships without a time-zone database, so time zones are
taken from the VTIMEZONE blocks inside the calendar file itself. Recurring events support the
rules Google writes: DAILY / WEEKLY / MONTHLY / YEARLY with INTERVAL, COUNT, UNTIL, BYDAY
(incl. 2TU / -1FR), BYMONTHDAY, BYMONTH, plus EXDATE and moved single occurrences.

    python next-event.py [path-to-url-file]
"""
import datetime as dt
import json
import os
import re
import sys
import urllib.request

CONFIG = os.path.join(os.path.expanduser("~"), ".config", "yasb")
URL_FILE = sys.argv[1] if len(sys.argv) > 1 else os.path.join(CONFIG, "calendar-url.txt")
CACHE = os.path.join(os.path.dirname(URL_FILE), ".calendar-cache.ics")
LOOKAHEAD_DAYS = 30
TITLE_MAX = 28
DAYS = ["MO", "TU", "WE", "TH", "FR", "SA", "SU"]

UTC = dt.timezone.utc
NOW = dt.datetime.now(UTC)


# ---------- fetching ----------

def fetch():
    """Download every calendar in the URL file; fall back to the cached copy."""
    if not os.path.exists(URL_FILE):
        return None
    with open(URL_FILE, encoding="utf-8-sig") as f:
        urls = [u.strip() for u in f if u.strip() and not u.lstrip().startswith("#")]
    texts = []
    try:
        for u in urls:
            if u.startswith(("http://", "https://")):
                req = urllib.request.Request(u, headers={"User-Agent": "yasb-next-event"})
                with urllib.request.urlopen(req, timeout=15) as r:
                    texts.append(r.read().decode("utf-8", "replace"))
            else:  # a local .ics file (handy for testing)
                with open(u, encoding="utf-8-sig") as f:
                    texts.append(f.read())
        data = "\n".join(texts)
        with open(CACHE, "w", encoding="utf-8") as f:
            f.write(data)
        return data
    except Exception:
        if os.path.exists(CACHE):
            with open(CACHE, encoding="utf-8") as f:
                return f.read()
        return None


# ---------- parsing ----------

def unfold(text):
    return re.sub(r"\r?\n[ \t]", "", text).splitlines()


def parse_line(line):
    """'DTSTART;TZID=Europe/Budapest:20261121T140000' -> ('DTSTART', {'TZID': ...}, '2026...')"""
    m = re.match(r"([^:;]+)((?:;[^:]*)?):(.*)", line)
    if not m:
        return None, {}, ""
    params = {}
    for p in m.group(2).split(";")[1:]:
        if "=" in p:
            k, v = p.split("=", 1)
            params[k.upper()] = v.strip('"')
    return m.group(1).upper(), params, m.group(3)


def blocks(lines):
    """Yield (name, props) for every component; props is a list of (name, params, value)."""
    stack = []
    for line in lines:
        name, params, value = parse_line(line)
        if name == "BEGIN":
            stack.append((value.upper(), []))
        elif name == "END" and stack:
            yield stack.pop()
        elif stack and name:
            stack[-1][1].append((name, params, value))


def get(props, key):
    for n, p, v in props:
        if n == key:
            return p, v
    return {}, None


def parse_dt(value):
    value = value.strip()
    if "T" not in value:
        return dt.datetime.strptime(value[:8], "%Y%m%d"), True
    naive = dt.datetime.strptime(value[:15], "%Y%m%dT%H%M%S")
    if value.endswith("Z"):
        return naive.replace(tzinfo=UTC), False
    return naive, False


def parse_offset(s):
    sign = -1 if s.startswith("-") else 1
    s = s.lstrip("+-")
    return sign * dt.timedelta(hours=int(s[:2]), minutes=int(s[2:4]), seconds=int(s[4:6] or 0))


# ---------- time zones from VTIMEZONE ----------

def nth_weekday(year, month, weekday, n):
    """n-th (1..5, or -1..-5 from the end) weekday of a month, or None."""
    if n > 0:
        d = dt.date(year, month, 1)
        d += dt.timedelta(days=(weekday - d.weekday()) % 7 + 7 * (n - 1))
        return d if d.month == month else None
    nxt = dt.date(year + (month == 12), month % 12 + 1, 1)
    d = nxt - dt.timedelta(days=1)
    d -= dt.timedelta(days=(d.weekday() - weekday) % 7 + 7 * (-n - 1))
    return d if d.month == month else None


class VTimezone:
    """Offsets from a VTIMEZONE's STANDARD / DAYLIGHT parts (yearly BYMONTH + BYDAY rules)."""

    def __init__(self):
        self.rules = []  # (start naive local, offset, rrule dict or None)

    def add(self, props):
        _, start = get(props, "DTSTART")
        _, off = get(props, "TZOFFSETTO")
        _, rule = get(props, "RRULE")
        if start and off:
            self.rules.append((parse_dt(start)[0], parse_offset(off), parse_rrule(rule) if rule else None))

    def offset(self, local):
        best, best_off = None, None
        for start, off, rule in self.rules:
            for year in (local.year - 1, local.year):
                if rule and rule.get("BYMONTH") and rule.get("BYDAY"):
                    m = re.match(r"([+-]?\d*)([A-Z]{2})", rule["BYDAY"])
                    n = int(m.group(1) or 1)
                    day = nth_weekday(year, int(rule["BYMONTH"]), DAYS.index(m.group(2)), n)
                    if not day:
                        continue
                    t = dt.datetime.combine(day, start.time())
                else:
                    t = start
                if start <= t <= local and (best is None or t > best):
                    best, best_off = t, off
        if best_off is None and self.rules:
            best_off = min(self.rules, key=lambda r: r[0])[1]
        return best_off


def to_utc(naive_or_aware, tzid, zones):
    if naive_or_aware.tzinfo:
        return naive_or_aware.astimezone(UTC)
    zone = zones.get(tzid) if tzid else None
    off = zone.offset(naive_or_aware) if zone else None
    if off is None:  # floating time or unknown zone: treat as this PC's local time
        return naive_or_aware.astimezone().astimezone(UTC)
    return (naive_or_aware - off).replace(tzinfo=UTC)


# ---------- recurrence ----------

def parse_rrule(s):
    return dict(p.split("=", 1) for p in s.split(";") if "=" in p)


def add_months(d, n):
    y, m = divmod(d.month - 1 + n, 12)
    return y + d.year, m + 1


def occurrences(start, rule, until_limit):
    """Wall-clock start times of a recurring event, up to until_limit (naive)."""
    freq = rule.get("FREQ")
    interval = int(rule.get("INTERVAL", 1))
    count = int(rule["COUNT"]) if "COUNT" in rule else None
    until = parse_dt(rule["UNTIL"])[0].replace(tzinfo=None) if "UNTIL" in rule else None
    byday = rule.get("BYDAY", "").split(",") if rule.get("BYDAY") else []
    bymonthday = [int(x) for x in rule.get("BYMONTHDAY", "").split(",") if x]
    bymonth = [int(x) for x in rule.get("BYMONTH", "").split(",") if x]
    n = 0

    def emit(t):
        nonlocal n
        if t < start:
            return True
        if until and t > until:
            return False
        if count is not None and n >= count:
            return False
        n += 1
        return t

    period = 0
    while period < 5000:
        if freq == "DAILY":
            base = start + dt.timedelta(days=period * interval)
            cands = [base] if not byday or DAYS[base.weekday()] in [b[-2:] for b in byday] else []
        elif freq == "WEEKLY":
            week0 = start - dt.timedelta(days=start.weekday())
            base = week0 + dt.timedelta(weeks=period * interval)
            days = [DAYS.index(b[-2:]) for b in byday] or [start.weekday()]
            cands = sorted(base + dt.timedelta(days=d) for d in days)
        elif freq in ("MONTHLY", "YEARLY"):
            if freq == "MONTHLY":
                y, m = add_months(start, period * interval)
                months = [(y, m)]
            else:
                y = start.year + period * interval
                months = [(y, mm) for mm in (bymonth or [start.month])]
            cands = []
            for y, m in months:
                if byday:
                    for b in byday:
                        mt = re.match(r"([+-]?\d*)([A-Z]{2})", b)
                        if mt.group(1):
                            d = nth_weekday(y, m, DAYS.index(mt.group(2)), int(mt.group(1)))
                            if d:
                                cands.append(dt.datetime.combine(d, start.time()))
                        else:  # every such weekday in the month
                            for k in range(1, 6):
                                d = nth_weekday(y, m, DAYS.index(mt.group(2)), k)
                                if d:
                                    cands.append(dt.datetime.combine(d, start.time()))
                else:
                    for md in (bymonthday or [start.day]):
                        try:
                            cands.append(start.replace(year=y, month=m, day=md))
                        except ValueError:
                            pass
            cands.sort()
        else:
            return
        if cands and cands[0] > until_limit:
            return
        for t in cands:
            r = emit(t)
            if r is False:
                return
            if r is not True:
                yield r
        period += 1


# ---------- events ----------

def events(text):
    lines = unfold(text)
    comps = list(blocks(lines))
    zones = {}
    current = None
    for name, props in comps:  # STANDARD/DAYLIGHT end before their VTIMEZONE
        if name in ("STANDARD", "DAYLIGHT"):
            current = current or VTimezone()
            current.add(props)
        elif name == "VTIMEZONE":
            _, tzid = get(props, "TZID")
            if tzid and current:
                zones[tzid] = current
            current = None

    window_end = NOW + dt.timedelta(days=LOOKAHEAD_DAYS)
    out = []
    overrides = {}  # (uid, original start utc) -> True (moved / cancelled single occurrence)
    vevents = [props for name, props in comps if name == "VEVENT"]
    for props in vevents:
        rp, rid = get(props, "RECURRENCE-ID")
        if rid:
            _, uid = get(props, "UID")
            t, _ = parse_dt(rid)
            overrides[(uid, to_utc(t, rp.get("TZID"), zones))] = True

    for props in vevents:
        _, status = get(props, "STATUS")
        if status == "CANCELLED":
            continue
        _, summary = get(props, "SUMMARY")
        _, uid = get(props, "UID")
        sp, sv = get(props, "DTSTART")
        if not sv:
            continue
        start, allday = parse_dt(sv)
        ep, ev = get(props, "DTEND")
        if ev:
            end, _ = parse_dt(ev)
            duration = (end.replace(tzinfo=None) - start.replace(tzinfo=None))
        else:
            duration = dt.timedelta(days=1) if allday else dt.timedelta(0)
        tzid = sp.get("TZID")
        title = (summary or "(no title)").replace("\\,", ",").replace("\\;", ";").replace("\\n", " ").strip()

        _, rule = get(props, "RRULE")
        _, rid = get(props, "RECURRENCE-ID")
        if rule and not rid:
            exdates = set()
            for n, p, v in props:
                if n == "EXDATE":
                    for part in v.split(","):
                        t, _ = parse_dt(part)
                        exdates.add(to_utc(t, p.get("TZID", tzid), zones))
            wall = start.replace(tzinfo=None)
            limit = window_end.replace(tzinfo=None) + dt.timedelta(days=1)
            starts = []
            for occ in occurrences(wall, parse_rrule(rule), limit):
                s_utc = to_utc(occ.replace(tzinfo=UTC) if start.tzinfo else occ, None if start.tzinfo else tzid, zones)
                if s_utc in exdates or (uid, s_utc) in overrides:
                    continue
                starts.append((occ, s_utc))
        else:
            starts = [(start.replace(tzinfo=None), to_utc(start, tzid, zones))]

        for wall_start, s_utc in starts:
            if allday:
                day = wall_start.date()
                s_local = dt.datetime.combine(day, dt.time()).astimezone()
                e_local = s_local + duration
            else:
                s_local = s_utc.astimezone()
                e_local = s_local + duration
            if e_local <= NOW or s_local > window_end:
                continue
            out.append({"start": s_local, "end": e_local, "allday": allday, "title": title})
    out.sort(key=lambda e: (e["start"], e["allday"]))
    return out


def short(title):
    return title if len(title) <= TITLE_MAX else title[:TITLE_MAX - 1].rstrip() + "…"


def when(e, now_local):
    s = e["start"]
    days = (s.date() - now_local.date()).days
    day = "today" if days <= 0 else "tomorrow" if days == 1 else s.strftime("%a") if days < 7 else s.strftime("%d %b")
    if e["allday"]:
        return day
    if s <= now_local:
        return "now"
    return s.strftime("%H:%M") if days == 0 else f"{day} {s:%H:%M}"


def main():
    text = fetch()
    if not text:
        return
    now_local = NOW.astimezone()
    evs = events(text)
    if not evs:
        return
    timed = [e for e in evs if not e["allday"]]
    today_allday = [e for e in evs if e["allday"] and e["start"].date() <= now_local.date()]
    head = timed[0] if timed else (today_allday[0] if today_allday else evs[0])
    lines = []
    for e in evs[:8]:
        t = e["start"].strftime("%a %d %b") + ("  all day" if e["allday"] else e["start"].strftime("  %H:%M"))
        lines.append(f"{t}   {e['title']}")
    print(json.dumps({"text": f"{when(head, now_local)}  {short(head['title'])}", "tooltip": "\n".join(lines)}))


if __name__ == "__main__":
    main()
