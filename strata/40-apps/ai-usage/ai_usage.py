#!/usr/bin/env python3
"""How much Claude and Antigravity quota is used, for the YASB bar (Windows) and the KDE panel (Linux).

    python ai_usage.py claude
    python ai_usage.py antigravity

Prints JSON for a bar widget; "sections" feed the click-open details (popup.py, the KDE popup):

    {"text": "Claude 37% used", "tooltip": "...", "title": "Claude usage", "footer": "Updated 23:30",
     "sections": [{"title": "5-hour limit", "used": 37, "resets": "23:30"}, ...]}

Nothing is printed while the app isn't running, so the widget hides itself.

- Claude: shown while Claude Code or the Claude desktop app runs. Reads Claude Code's own sign-in
  (~/.claude/.credentials.json) and asks the same usage endpoint Claude Code's /usage uses. The
  answer is cached for 5 minutes (the endpoint rate-limits). If the sign-in has expired, Claude
  Code is asked to refresh it (`claude auth status`), at most every 15 minutes; this script never
  writes the credentials file itself.
- Antigravity: shown while Antigravity's local server runs (the standalone app's language_server,
  or Antigravity IDE's `agy --hub`). It asks that server for the per-model quota, finding it and
  its one-off CSRF token through the discovery file the app writes for local clients
  (~/.gemini/antigravity/daemon/hub_<port>.json) or, for the IDE on Linux, the server's command
  line. The token is never stored or printed.

Standard library only.
"""
import json
import os
import re
import shutil
import ssl
import subprocess
import sys
import time
import urllib.request
from datetime import datetime

WIN = os.name == "nt"
NO_WINDOW = 0x08000000 if WIN else 0  # CREATE_NO_WINDOW: no console flash under pythonw
HOME = os.path.expanduser("~")
CACHE_DIR = os.path.join(
    os.environ.get("LOCALAPPDATA", HOME) if WIN else os.environ.get("XDG_CACHE_HOME", os.path.join(HOME, ".cache")),
    "ai-usage")

CLAUDE_CREDENTIALS = os.path.join(HOME, ".claude", ".credentials.json")
CLAUDE_USAGE_URL = "https://api.anthropic.com/api/oauth/usage"
CLAUDE_TTL = 300
CLAUDE_REFRESH_EVERY = 900
AG_PATH = "/exa.language_server_pb.LanguageServerService/GetUserStatus"


def run(args, timeout=15):
    try:
        return subprocess.run(args, capture_output=True, text=True, timeout=timeout,
                              creationflags=NO_WINDOW).stdout or ""
    except (OSError, subprocess.SubprocessError):
        return ""


def processes():
    """[(pid, lower-case name, argv)]. argv is only known on Linux."""
    procs = []
    if WIN:
        for line in run(["tasklist", "/FO", "CSV", "/NH"]).splitlines():
            f = line.strip().strip('"').split('","')
            if len(f) > 1:
                procs.append((f[1], f[0].lower(), []))
        return procs
    for pid in os.listdir("/proc"):
        if not pid.isdigit():
            continue
        try:
            with open(f"/proc/{pid}/cmdline", "rb") as fh:
                argv = fh.read().decode(errors="replace").rstrip("\0").split("\0")
        except OSError:
            continue
        # Electron apps (the Claude desktop app) rewrite their command line as one space-separated string.
        if len(argv) == 1 and " " in argv[0] and not os.path.exists(argv[0]):
            argv = argv[0].split(" ")
        if argv and argv[0]:
            procs.append((pid, os.path.basename(argv[0]).lower(), argv))
    return procs


def load(name):
    try:
        with open(os.path.join(CACHE_DIR, name), encoding="utf-8") as fh:
            return json.load(fh)
    except (OSError, ValueError):
        return {}


def save(name, data):
    os.makedirs(CACHE_DIR, exist_ok=True)
    path = os.path.join(CACHE_DIR, name)
    with open(path + ".tmp", "w", encoding="utf-8") as fh:
        json.dump(data, fh)
    os.replace(path + ".tmp", path)


def when(iso):
    """'23:30' today, 'Mon 20:00' later."""
    try:
        t = datetime.fromisoformat(iso.replace("Z", "+00:00")).astimezone()
    except (AttributeError, ValueError):
        return "?"
    return t.strftime("%H:%M") if t.date() == datetime.now().date() else t.strftime("%a %H:%M")


# ---------------------------------------------------------------- Claude

# Browsers start claude.exe (through cmd) as the Claude browser extension's native messaging host.
# That copy runs whenever the browser does, so it doesn't count as Claude being open.
BROWSERS = {"brave.exe", "chrome.exe", "msedge.exe", "firefox.exe", "vivaldi.exe", "opera.exe", "arc.exe"}


def win_process_tree():
    """{pid: (parent pid, lower-case exe name)} from a Toolhelp snapshot (Windows only)."""
    import ctypes
    from ctypes import wintypes

    class Entry(ctypes.Structure):
        _fields_ = [("dwSize", wintypes.DWORD), ("cntUsage", wintypes.DWORD),
                    ("th32ProcessID", wintypes.DWORD), ("th32DefaultHeapID", ctypes.c_size_t),
                    ("th32ModuleID", wintypes.DWORD), ("cntThreads", wintypes.DWORD),
                    ("th32ParentProcessID", wintypes.DWORD), ("pcPriClassBase", wintypes.LONG),
                    ("dwFlags", wintypes.DWORD), ("szExeFile", wintypes.WCHAR * 260)]

    k32 = ctypes.WinDLL("kernel32", use_last_error=True)
    k32.CreateToolhelp32Snapshot.restype = wintypes.HANDLE
    k32.Process32FirstW.argtypes = k32.Process32NextW.argtypes = [wintypes.HANDLE, ctypes.POINTER(Entry)]
    snap = k32.CreateToolhelp32Snapshot(0x2, 0)  # TH32CS_SNAPPROCESS
    tree = {}
    if not snap or snap == wintypes.HANDLE(-1).value:
        return tree
    try:
        e = Entry(dwSize=ctypes.sizeof(Entry))
        ok = k32.Process32FirstW(snap, ctypes.byref(e))
        while ok:
            tree[e.th32ProcessID] = (e.th32ParentProcessID, e.szExeFile.lower())
            ok = k32.Process32NextW(snap, ctypes.byref(e))
    finally:
        k32.CloseHandle(snap)
    return tree


def browser_hosted(pid, tree):
    for _ in range(3):  # claude.exe <- cmd.exe <- browser
        pid = tree.get(pid, (0, ""))[0]
        if tree.get(pid, (0, ""))[1] in BROWSERS:
            return True
    return False


def claude_running(procs):
    if WIN:
        tree = win_process_tree()
        if tree:
            return any(name == "claude.exe" and not browser_hosted(pid, tree) for pid, (_, name) in tree.items())
        return any(name == "claude.exe" for _, name, _ in procs)
    return any(name in {"claude", "claude-desktop"} and "--chrome-native-host" not in argv for _, name, argv in procs)


def claude_token():
    try:
        with open(CLAUDE_CREDENTIALS, encoding="utf-8") as fh:
            oauth = json.load(fh)["claudeAiOauth"]
        return oauth["accessToken"], oauth.get("expiresAt", 0) / 1000
    except (OSError, ValueError, KeyError, TypeError):
        return None, 0


def claude_refresh(cache):
    """Let Claude Code renew its own expired sign-in."""
    if time.time() - cache.get("refresh_tried", 0) < CLAUDE_REFRESH_EVERY:
        return
    cache["refresh_tried"] = time.time()
    exe = shutil.which("claude") or os.path.join(HOME, ".local", "bin", "claude")
    if os.path.exists(exe) or shutil.which("claude"):
        run([exe, "auth", "status"], timeout=30)


def claude():
    cache = load("claude.json")
    data, fetched = cache.get("data"), cache.get("fetched", 0)
    if not data or time.time() - fetched > CLAUDE_TTL:
        token, expires = claude_token()
        if token and expires < time.time():
            claude_refresh(cache)
            token, expires = claude_token()
        if token and expires >= time.time():
            req = urllib.request.Request(CLAUDE_USAGE_URL, headers={
                "Authorization": f"Bearer {token}", "anthropic-beta": "oauth-2025-04-20",
                "User-Agent": "ai-usage"})
            try:
                with urllib.request.urlopen(req, timeout=10) as r:
                    data, fetched = json.load(r), time.time()
                cache.update(data=data, fetched=fetched)
            except (OSError, ValueError):
                pass  # keep showing the last known values
        save("claude.json", cache)
    if not data:
        return None
    sections = []
    for key, title in (("five_hour", "5-hour limit"), ("seven_day", "7-day limit"),
                       ("seven_day_opus", "7-day Opus"), ("seven_day_sonnet", "7-day Sonnet")):
        w = data.get(key)
        if isinstance(w, dict) and w.get("utilization") is not None:
            sections.append({"title": title, "used": min(100, max(0, round(w["utilization"]))),
                              "resets": when(w.get("resets_at"))})
    if not sections:
        return None
    return result("Claude", sections, f"Updated {datetime.fromtimestamp(fetched).strftime('%H:%M')}")


# ---------------------------------------------------------------- Antigravity

def ag_servers(procs):
    """[(pid, csrf_token, [(port, scheme)])] for every running Antigravity server."""
    servers = []
    alive = {pid for pid, _, _ in procs}
    # The standalone app writes a discovery file for local clients: ~/.gemini/<app>/daemon/hub_<port>.json
    gemini = os.path.join(HOME, ".gemini")
    for app in (os.listdir(gemini) if os.path.isdir(gemini) else []):
        daemon = os.path.join(gemini, app, "daemon")
        for f in (os.listdir(daemon) if os.path.isdir(daemon) else []):
            try:
                with open(os.path.join(daemon, f), encoding="utf-8") as fh:
                    d = json.load(fh)
            except (OSError, ValueError):
                continue
            if str(d.get("pid")) in alive and d.get("csrfToken"):
                ports = [(d[k], s) for k, s in (("httpsPort", "https"), ("httpPort", "http")) if d.get(k)]
                servers.append((str(d["pid"]), d["csrfToken"], ports))
    if WIN:
        return servers
    # Antigravity IDE (Linux) starts `agy --hub --hub-port=N --csrf_token=...` without a discovery file.
    listening = None
    for pid, name, argv in procs:
        cmd = " ".join(argv)
        m = re.search(r"--csrf_token[ =](\S+)", cmd)
        if not m or not re.search(r"antigravity|agy|language_server", cmd, re.I):
            continue
        hub = re.search(r"--hub-port[ =](\d+)", cmd)
        if hub:
            ports = [int(hub.group(1))]
        else:
            if listening is None:
                listening = run(["ss", "-ltnpH"])
            ports = sorted({int(p) for p in re.findall(rf"127\.0\.0\.1:(\d+)\s.*pid={pid},", listening)})
        if pid not in {s[0] for s in servers}:
            servers.append((pid, m.group(1), [(p, s) for p in ports for s in ("http", "https")]))
    return servers


def ag_query(port, scheme, token):
    body = json.dumps({"metadata": {"ideName": "antigravity", "extensionName": "antigravity",
                                    "locale": "en"}}).encode()
    req = urllib.request.Request(f"{scheme}://127.0.0.1:{port}{AG_PATH}", body, {
        "Content-Type": "application/json", "Connect-Protocol-Version": "1",
        "X-Codeium-Csrf-Token": token})
    ctx = ssl._create_unverified_context() if scheme == "https" else None  # self-signed, localhost only
    with urllib.request.urlopen(req, timeout=4, context=ctx) as r:
        return json.load(r)


def antigravity():
    procs = processes()
    seen = load("antigravity.json")  # pid -> [port, scheme] that answered last time (no secrets)
    status = None
    for pid, token, ports in ag_servers(procs):
        known = tuple(seen.get(pid) or ())
        tries = ([known] if known else []) + [t for t in ports if t != known]
        for port, scheme in tries:
            try:
                status = ag_query(port, scheme, token).get("userStatus")
            except (OSError, ValueError):
                continue
            save("antigravity.json", {pid: [port, scheme]})
            break
        if status:
            break
    if not status:
        return None
    families = {}
    for m in status.get("cascadeModelConfigData", {}).get("clientModelConfigs", []):
        q = m.get("quotaInfo")
        if q is None or m.get("disabled"):  # disabled = not on this plan
            continue
        left = float(q.get("remainingFraction", 0))  # proto3 JSON leaves out zero, so missing = 0
        name = re.sub(r"\s*\([^)]*\)$", "", m.get("label", "?"))
        if name not in families or left < families[name][0]:
            families[name] = (left, q.get("resetTime"))
    if not families:
        return None
    sections = [{"title": n, "used": min(100, max(0, round((1 - l) * 100))), "resets": when(r)}
                for n, (l, r) in sorted(families.items(), key=lambda kv: (kv[1][0], kv[0]))]
    return result("Antigravity", sections, "Most-used model shown in the bar")


def result(name, sections, footer):
    """Bar label (first section = the one shown), tooltip, and the sections for the dropdowns."""
    lines = [f"{s['title']}: {s['used']}% used, resets {s['resets']}" for s in sections]
    return {"text": f"{name} {sections[0]['used']}% used", "tooltip": "\n".join(lines),
            "title": f"{name} usage", "sections": sections, "footer": footer}


def main():
    which = next((a for a in sys.argv[1:] if not a.startswith("-")), "")
    if which == "claude":
        result = claude() if claude_running(processes()) else None
    elif which == "antigravity":
        result = antigravity()
    else:
        sys.exit("usage: ai_usage.py claude|antigravity [--text]")
    if result:
        # --text: just the label. YASB's hide_empty only works with plain-text output (an empty JSON
        # result breaks its '{data[...]}' label formatting before it gets to hiding the widget).
        print(result["text"] if "--text" in sys.argv else json.dumps(result))


if __name__ == "__main__":
    main()
