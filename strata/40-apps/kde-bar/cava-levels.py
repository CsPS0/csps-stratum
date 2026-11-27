#!/usr/bin/env python3
"""Audio levels for the top bar's visualizer (org.csps.media).

Runs cava with raw ASCII output and serves its latest frame on http://127.0.0.1:<port>/ as
"12;50;100;..." (one value 0-100 per bar). The widget starts this while a player is playing and
asks about 20 times a second; with no request for --idle seconds it stops cava and exits. A second
copy exits at once when the port is taken. Without cava it serves zeros.

    python3 cava-levels.py [--port 47836] [--bars 12] [--idle 5] [--self-test]
"""
import argparse
import http.server
import os
import shutil
import subprocess
import sys
import tempfile
import threading
import time
import urllib.request

CONFIG = """[general]
bars = {bars}
framerate = 30
[output]
method = raw
raw_target = /dev/stdout
data_format = ascii
ascii_max_range = 100
bar_delimiter = 59
frame_delimiter = 10
channels = mono
"""


def parse(line, bars):
    """'12;50;100;' -> [12, 50, 100], padded or cut to `bars` values, each clamped to 0-100."""
    vals = []
    for part in line.strip().strip(";").split(";"):
        try:
            vals.append(max(0, min(100, int(part))))
        except ValueError:
            vals.append(0)
    return (vals + [0] * bars)[:bars]


class Levels:
    def __init__(self, bars):
        self.bars = bars
        self.frame = [0] * bars
        self.last_request = time.monotonic()
        self.proc = None

    def start_cava(self):
        exe = shutil.which("cava")
        if not exe:
            return
        fd, self.config = tempfile.mkstemp(prefix="cava-levels-", suffix=".conf")
        with os.fdopen(fd, "w") as fh:
            fh.write(CONFIG.format(bars=self.bars))
        self.proc = subprocess.Popen([exe, "-p", self.config], stdout=subprocess.PIPE,
                                     stderr=subprocess.DEVNULL, text=True)
        threading.Thread(target=self.read, daemon=True).start()

    def read(self):
        for line in self.proc.stdout:
            self.frame = parse(line, self.bars)

    def stop(self):
        if self.proc:
            self.proc.terminate()
            try:
                self.proc.wait(timeout=2)
            except subprocess.TimeoutExpired:
                self.proc.kill()
            os.unlink(self.config)


def serve(port, bars, idle, ready=None):
    levels = Levels(bars)

    class Handler(http.server.BaseHTTPRequestHandler):
        def do_GET(self):
            levels.last_request = time.monotonic()
            body = ";".join(map(str, levels.frame)).encode()
            self.send_response(200)
            self.send_header("Content-Type", "text/plain")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        def log_message(self, *args):
            pass

    try:
        server = http.server.HTTPServer(("127.0.0.1", port), Handler)
    except OSError:
        return 0  # already running
    levels.start_cava()

    def watchdog():
        while time.monotonic() - levels.last_request < idle:
            time.sleep(0.5)
        server.shutdown()

    threading.Thread(target=watchdog, daemon=True).start()
    if ready:
        ready(server.server_address[1])
    try:
        server.serve_forever()
    finally:
        server.server_close()
        levels.stop()
    return 0


def self_test():
    assert parse("12;50;100;\n", 3) == [12, 50, 100]
    assert parse("12;x;300;", 4) == [12, 0, 100, 0]
    assert parse("1;2;3;4;5;", 2) == [1, 2]
    got = {}
    t = threading.Thread(target=serve, args=(0, 4, 1.5), kwargs={"ready": lambda p: got.setdefault("port", p)})
    start = time.monotonic()
    t.start()
    while "port" not in got and time.monotonic() - start < 3:
        time.sleep(0.05)
    with urllib.request.urlopen(f"http://127.0.0.1:{got['port']}/", timeout=2) as r:
        assert len(r.read().decode().split(";")) == 4
    t.join(timeout=6)
    assert not t.is_alive(), "did not exit when idle"
    print("ok")
    return 0


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--port", type=int, default=47836)
    ap.add_argument("--bars", type=int, default=12)
    ap.add_argument("--idle", type=float, default=5)
    ap.add_argument("--self-test", action="store_true")
    a = ap.parse_args()
    return self_test() if a.self_test else serve(a.port, a.bars, a.idle)


if __name__ == "__main__":
    sys.exit(main())
