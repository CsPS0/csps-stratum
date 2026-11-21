"""Click-open details for the YASB usage widgets (Windows): a dropdown under the mouse, styled like
YASB's own popups, with a bar and reset time per limit.

    pythonw popup.py claude|antigravity

Closes when it loses focus, on Esc, or when the widget is clicked again. Standard library only.
"""
import ctypes
import os
import sys
import tempfile
import time
import tkinter as tk
from ctypes import wintypes

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ai_usage  # noqa: E402

BG, BORDER, LINE = "#0A0A0A", "#35373A", "#1E1F21"
TEXT, MUTED, DIM = "#E6E6E6", "#B4B6B8", "#8E9194"
FONT = "Segoe UI Variable Text" if os.name == "nt" else "sans-serif"
WIDTH, BAR_H, GAP = 300, 30, 6
STAMP = os.path.join(tempfile.gettempdir(), "ai-usage-popup-{}.closed")


def level(used):
    return (TEXT, "#FFFFFF") if used >= 80 else (MUTED, "#B4B6B8") if used >= 50 else (DIM, DIM)


def anchor(width, height, scale):
    """Top-left for the popup: under the bar, centred on the mouse, kept on the mouse's monitor."""
    pt = wintypes.POINT()
    ctypes.windll.user32.GetCursorPos(ctypes.byref(pt))

    class MONITORINFO(ctypes.Structure):
        _fields_ = [("cbSize", wintypes.DWORD), ("rcMonitor", wintypes.RECT),
                    ("rcWork", wintypes.RECT), ("dwFlags", wintypes.DWORD)]

    mi = MONITORINFO(cbSize=ctypes.sizeof(MONITORINFO))
    mon = ctypes.windll.user32.MonitorFromPoint(pt, 2)
    ctypes.windll.user32.GetMonitorInfoW(mon, ctypes.byref(mi))
    r = mi.rcMonitor
    x = min(max(pt.x - width // 2, r.left + 8), r.right - width - 8)
    return x, r.top + round((BAR_H + GAP) * scale)


def main():
    which = sys.argv[-1]
    if which not in ("claude", "antigravity"):
        sys.exit("usage: popup.py claude|antigravity")
    stamp = STAMP.format(which)
    # A click on the widget while the popup is open first closes it (focus lost); don't reopen it then.
    try:
        if time.time() - os.path.getmtime(stamp) < 0.8:
            return
    except OSError:
        pass
    # One popup per app: a second click while one is starting or open does nothing.
    mutex = ctypes.windll.kernel32.CreateMutexW(None, False, f"Local\\ai-usage-popup-{which}")
    if ctypes.windll.kernel32.GetLastError() == 183:  # ERROR_ALREADY_EXISTS
        return
    try:
        ctypes.windll.shcore.SetProcessDpiAwareness(2)
    except (AttributeError, OSError):
        pass

    data = ai_usage.claude() if which == "claude" else ai_usage.antigravity()

    root = tk.Tk()
    root.withdraw()
    root.overrideredirect(True)
    root.attributes("-topmost", True)
    root.configure(bg=BORDER)
    scale = root.winfo_fpixels("1i") / 96
    px = lambda v: round(v * scale)  # noqa: E731

    body = tk.Frame(root, bg=BG)
    body.pack(fill="both", expand=True, padx=1, pady=1)
    head = tk.Frame(body, bg=BG)
    head.pack(fill="x")
    tk.Label(head, text=(data or {}).get("title", f"{which.title()} usage"), bg=BG, fg=TEXT,
             font=(FONT, 10, "bold"), anchor="w").pack(side="left", padx=px(14), pady=px(10))
    tk.Frame(body, bg=LINE, height=1).pack(fill="x")

    if not data:
        tk.Label(body, text="No usage data right now.", bg=BG, fg=DIM, font=(FONT, 9),
                 anchor="w").pack(fill="x", padx=px(14), pady=px(12))
    for s in (data or {}).get("sections", []):
        fg, fill = level(s["used"])
        sec = tk.Frame(body, bg=BG)
        sec.pack(fill="x", padx=px(14), pady=(px(10), px(2)))
        row = tk.Frame(sec, bg=BG)
        row.pack(fill="x")
        tk.Label(row, text=s["title"], bg=BG, fg=TEXT, font=(FONT, 9, "bold")).pack(side="left")
        tk.Label(row, text=f"{s['used']}% used", bg=BG, fg=fg,
                 font=(FONT, 8, "bold" if s["used"] >= 80 else "normal")).pack(side="right")
        track = tk.Frame(sec, bg=LINE, height=px(6))
        track.pack(fill="x", pady=(px(6), px(4)))
        if s["used"]:
            tk.Frame(track, bg=fill).place(relx=0, rely=0, relheight=1, relwidth=s["used"] / 100)
        tk.Label(sec, text=f"Resets {s['resets']}", bg=BG, fg=DIM, font=(FONT, 8),
                 anchor="w").pack(fill="x")
    if data and data.get("footer"):
        tk.Frame(body, bg=LINE, height=1).pack(fill="x", pady=(px(8), 0))
        tk.Label(body, text=data["footer"], bg=BG, fg=DIM, font=(FONT, 8), anchor="w").pack(
            fill="x", padx=px(14), pady=px(8))

    def close(_=None):
        try:
            with open(stamp, "w"):
                pass
        except OSError:
            pass
        root.destroy()

    root.update_idletasks()
    w, h = px(WIDTH), root.winfo_reqheight()
    x, y = anchor(w, h, scale)
    root.geometry(f"{w}x{h}+{x}+{y}")
    root.deiconify()
    root.bind("<Escape>", close)
    root.bind("<FocusOut>", lambda e: close() if e.widget is root else None)
    root.after(50, lambda: (root.focus_force(), root.lift()))
    root.mainloop()


if __name__ == "__main__":
    main()
