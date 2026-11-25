// menubar: a macOS-style one-line application menu for the Windows top bar.
//
// Sits on the left end of the YASB bar on every screen and shows
//    [Windows logo]  App name  File  Edit  View  Go  Window
// for whichever app has focus. Like macOS, every screen shows the menus; the screen without the
// focused app shows them dimmed. Clicking a title opens that menu; picking an item refocuses the
// app and sends it the item's keyboard shortcut (or a minimise / maximise / close command).
// Menus come from menubar.ini next to the exe. Plain Win32, so it stays at a couple of MB.
//
// Build: Build-MenuBar.ps1 (Visual C++ build tools).

#define WIN32_LEAN_AND_MEAN
#define NOMINMAX
#ifndef UNICODE
#define UNICODE
#endif
#include <windows.h>
#include <windowsx.h>
#include <dwmapi.h>
#include <shellapi.h>
#include <powrprof.h>
#include <mmdeviceapi.h>
#include <audioclient.h>
#include <algorithm>
#include <atomic>
#include <climits>
#include <cmath>
#include <complex>
#include <mutex>
#include <string>
#include <thread>
#include <vector>
#include <winrt/Windows.Foundation.h>
#include <winrt/Windows.Foundation.Collections.h>
#include <winrt/Windows.Media.Control.h>

#pragma comment(lib, "windowsapp.lib")
#pragma comment(lib, "ole32.lib")
#pragma comment(lib, "user32.lib")
#pragma comment(lib, "gdi32.lib")
#pragma comment(lib, "dwmapi.lib")
#pragma comment(lib, "shell32.lib")
#pragma comment(lib, "version.lib")
#pragma comment(lib, "powrprof.lib")
#pragma comment(lib, "advapi32.lib")

struct Action { std::wstring keys, cmd; };
struct Item { std::wstring label, hint; Action act; bool sep = false; };
struct Menu { std::wstring title; std::vector<Item> items; };
// K_DESK: one virtual desktop dot; K_NOTE / K_TITLE / K_MEDIA / K_VIZ: what's playing, its buttons
// and the visualizer
enum Kind { K_LOGO, K_APP, K_MENU, K_DESK, K_NOTE, K_TITLE, K_MEDIA, K_VIZ };
struct Slot { Kind kind; std::wstring text; int menu; RECT rc; };

// One strip per screen
struct Strip
{
    HWND hwnd = nullptr;
    HMONITOR mon = nullptr;
    RECT monRect = {};
    UINT dpi = 96;
    HFONT font = nullptr, bold = nullptr, logo = nullptr;
    std::vector<Slot> slots;
    int hover = -1, pressed = -1;
    bool hidden = false; // a full-screen app covers this screen
    HWND line = nullptr;  // separator along the bar's bottom edge
    bool maxed = false;   // a maximised window sits under the bar on this screen
    bool noBar = false;   // no YASB bar on this screen (YASB closed): the strip would sit over windows
    std::vector<HWND> hiddenBars; // YASB bars hidden while a full-screen app covers this screen
};

static std::vector<Strip> g_strips;
static HWND g_target;
static HMONITOR g_activeMon;
static std::wstring g_ini, g_appKey, g_appName;
static std::vector<Menu> g_menus;
static bool g_showLogo = true, g_showMenus = true; // menubar.ini [bar] logo = 0 / menus = 0 leave just the app name
static HINSTANCE g_inst;
static HWND g_msgWnd; // message-only window the media thread posts to (strips come and go)

// Virtual desktops (Explorer keeps the list in the registry); dots show only with 2 or more
static int g_deskCount = 1, g_deskCurrent = 0;
static const wchar_t* DESKTOPS_KEY = L"Software\\Microsoft\\Windows\\CurrentVersion\\Explorer\\VirtualDesktops";

// What's playing, as the UI thread last saw it; empty while nothing plays
static std::wstring g_mediaTitle;

// Visualizer: VIZ_BARS levels (0..1) from the audio thread, which runs only while something plays
static const int VIZ_BARS = 12;
static std::atomic<float> g_viz[VIZ_BARS];
static std::atomic<bool> g_vizWanted{ false };
static HANDLE g_vizWake;

// Room left free just before the clock bar for YASB's own left-side widgets (CPU, RAM, GPU,
// weather), in px; menubar.ini [bar] reserve
static int g_reserve = 290;
static const COLORREF MUTED = RGB(142, 145, 148), SOFT = RGB(180, 182, 184);

static const COLORREF BG = RGB(0, 0, 0), FG = RGB(230, 230, 230), DIM = RGB(110, 112, 116), HOVER = RGB(42, 43, 45), SEP = RGB(42, 42, 42);
// The YASB bars float: BAR_GAP from the screen's top and sides (and below, in the reserved space),
// BAR_HEIGHT tall with BAR_RADIUS corners and a 1 px outline. Must match config.yaml and styles.css.
static const int BAR_HEIGHT = 32, BAR_GAP = 6, BAR_RADIUS = 10;
static const wchar_t* FONT = L"JetBrainsMono NF"; // the bar's font (styles.css)
static const wchar_t* LOGO = L"\xF17A"; // Windows logo in Nerd Fonts
static const wchar_t* CLASS_NAME = L"CspsMenuBar";
static const wchar_t* LINE_CLASS = L"CspsMenuBarLine";
static const UINT WM_RESTORE_BAR = WM_APP + 1, WM_REBUILD = WM_APP + 2, WM_APPBAR = WM_APP + 3, WM_OPEN_MENU = WM_APP + 4, WM_MEDIA = WM_APP + 5, WM_DESKTOPS = WM_APP + 6, WM_VIZ = WM_APP + 7;
static const ULONG_PTR COPY_MENU = 0x4D454E55; // WM_COPYDATA tag for "--menu <section>"
static const UINT_PTR RAISE_TIMER = 1, MAXED_TIMER = 2, ORDER_TIMER = 3;

static int S(const Strip& s, int v) { return MulDiv(v, (int)s.dpi, 96); }

static std::wstring Trim(const std::wstring& s)
{
    size_t a = s.find_first_not_of(L" \t"), b = s.find_last_not_of(L" \t");
    return a == std::wstring::npos ? L"" : s.substr(a, b - a + 1);
}

static std::vector<std::wstring> Split(const std::wstring& s, wchar_t sep)
{
    std::vector<std::wstring> out;
    size_t start = 0;
    for (size_t i = 0; i <= s.size(); i++)
        if (i == s.size() || s[i] == sep) { std::wstring t = Trim(s.substr(start, i - start)); if (!t.empty()) out.push_back(t); start = i + 1; }
    return out;
}

static std::wstring IniValue(const std::wstring& section, const wchar_t* key)
{
    wchar_t buf[1024];
    GetPrivateProfileStringW(section.c_str(), key, L"", buf, 1024, g_ini.c_str());
    return buf;
}

static std::vector<std::wstring> IniSection(const std::wstring& section)
{
    std::vector<wchar_t> buf(32768);
    GetPrivateProfileSectionW(section.c_str(), buf.data(), (DWORD)buf.size(), g_ini.c_str());
    std::vector<std::wstring> lines;
    for (wchar_t* p = buf.data(); *p; p += wcslen(p) + 1)
        if (*p != L';' && *p != L'#') lines.push_back(p);
    return lines;
}

// ---------- the focused app ----------

static std::wstring ExePath(HWND h)
{
    DWORD pid = 0; GetWindowThreadProcessId(h, &pid);
    std::wstring path;
    HANDLE p = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE, pid);
    if (p) { wchar_t buf[MAX_PATH]; DWORD n = MAX_PATH; if (QueryFullProcessImageNameW(p, 0, buf, &n)) path = buf; CloseHandle(p); }
    return path;
}

static std::wstring BaseName(const std::wstring& path)
{
    size_t s = path.find_last_of(L"\\/"); std::wstring f = s == std::wstring::npos ? path : path.substr(s + 1);
    size_t d = f.find_last_of(L'.'); return d == std::wstring::npos ? f : f.substr(0, d);
}

static std::wstring Lower(std::wstring s) { if (!s.empty()) CharLowerBuffW(&s[0], (DWORD)s.size()); return s; }

static std::wstring ClassOf(HWND h) { wchar_t c[128] = {}; GetClassNameW(h, c, 128); return c; }

static std::wstring FileDescription(const std::wstring& path)
{
    DWORD dummy, size = GetFileVersionInfoSizeW(path.c_str(), &dummy);
    if (!size) return L"";
    std::vector<BYTE> data(size);
    if (!GetFileVersionInfoW(path.c_str(), 0, size, data.data())) return L"";
    struct { WORD lang, cp; } *tr; UINT len;
    if (!VerQueryValueW(data.data(), L"\\VarFileInfo\\Translation", (void**)&tr, &len) || len < 4) return L"";
    wchar_t q[64]; swprintf_s(q, L"\\StringFileInfo\\%04x%04x\\FileDescription", tr->lang, tr->cp);
    wchar_t* v; if (!VerQueryValueW(data.data(), q, (void**)&v, &len) || !len) return L"";
    return Trim(v);
}

static bool IsAppWindow(HWND h)
{
    if (!h || !IsWindowVisible(h) || IsIconic(h)) return false;
    if (GetWindowLongW(h, GWL_EXSTYLE) & WS_EX_TOOLWINDOW) return false;
    int cloaked = 0; DwmGetWindowAttribute(h, DWMWA_CLOAKED, &cloaked, sizeof cloaked); if (cloaked) return false;
    DWORD pid = 0; GetWindowThreadProcessId(h, &pid); if (pid == GetCurrentProcessId()) return false;
    std::wstring cls = ClassOf(h);
    if (cls == L"Shell_TrayWnd" || cls == L"Shell_SecondaryTrayWnd" || cls == L"#32768") return false;
    if (cls == L"Progman" || cls == L"WorkerW") return true; // the desktop
    // YASB's own windows, and the lock screen: after a restart with sign-in and lock it's the first
    // focused window, and unlocking doesn't always report a new one, so it stuck as "LockApp.exe"
    std::wstring exe = Lower(BaseName(ExePath(h)));
    if (exe == L"yasb" || exe == L"lockapp") return false;
    return GetWindowTextLengthW(h) > 0;
}

static Action ParseAction(const std::wstring& v) { Action a; if (!v.empty() && v[0] == L'@') a.cmd = v.substr(1); else a.keys = v; return a; }

static void LoadMenus()
{
    g_menus.clear();
    g_showLogo = IniValue(L"bar", L"logo") != L"0";
    g_showMenus = IniValue(L"bar", L"menus") != L"0";
    if (std::wstring r = IniValue(L"bar", L"reserve"); !r.empty()) g_reserve = _wtoi(r.c_str());
    if (!g_showMenus) return;
    const std::wstring keys[] = { g_appKey, L"*" };
    for (const auto& k : keys)
        for (const auto& title : Split(IniValue(L"app:" + k, L"menus"), L'|'))
        {
            Menu m; m.title = title;
            for (const auto& line : IniSection(k + L"." + title))
            {
                size_t eq = line.find(L'=');
                Item it;
                it.label = Trim(eq == std::wstring::npos ? line : line.substr(0, eq));
                if (it.label == L"-") { it.sep = true; m.items.push_back(it); continue; }
                auto parts = Split(eq == std::wstring::npos ? L"" : line.substr(eq + 1), L'|');
                if (parts.empty()) continue;
                it.act = ParseAction(parts[0]);
                if (parts.size() > 1) it.hint = parts[1];
                m.items.push_back(it);
            }
            g_menus.push_back(m);
        }
}

// ---------- strips: layout and painting ----------

static Strip* StripOf(HWND h)
{
    for (auto& s : g_strips) if (s.hwnd == h) return &s;
    return nullptr;
}

static void MakeFonts(Strip& s)
{
    if (s.font) { DeleteObject(s.font); DeleteObject(s.bold); DeleteObject(s.logo); }
    s.font = CreateFontW(-S(s, 12), 0, 0, 0, FW_NORMAL, 0, 0, 0, DEFAULT_CHARSET, 0, 0, CLEARTYPE_QUALITY, 0, FONT);
    s.bold = CreateFontW(-S(s, 12), 0, 0, 0, FW_BOLD, 0, 0, 0, DEFAULT_CHARSET, 0, 0, CLEARTYPE_QUALITY, 0, FONT);
    s.logo = CreateFontW(-S(s, 15), 0, 0, 0, FW_NORMAL, 0, 0, 0, DEFAULT_CHARSET, 0, 0, CLEARTYPE_QUALITY, 0, FONT);
}

static HFONT FontFor(const Strip& s, const Slot& sl) { return sl.kind == K_LOGO ? s.logo : sl.kind == K_APP ? s.bold : s.font; }

// A 1 px line along the bottom of the bar's reserved space (just above a maximised window's top
// edge), shown only while a maximised window is there. It takes no space and lets clicks through.
static void PlaceLine(Strip& s)
{
    if (!s.line) return;
    bool show = s.maxed && !s.hidden && !s.noBar;
    int h = S(s, 1) > 1 ? S(s, 1) : 1;
    SetWindowPos(s.line, HWND_TOPMOST, s.monRect.left, s.monRect.top + S(s, BAR_GAP * 2 + BAR_HEIGHT) - h,
                 s.monRect.right - s.monRect.left, h, SWP_NOACTIVATE | (show ? SWP_SHOWWINDOW : SWP_HIDEWINDOW));
}

static int StripRight(const Strip& s);

static void Layout(Strip& s)
{
    s.slots.clear();
    if (g_showLogo) s.slots.push_back({ K_LOGO, LOGO, -1, {} });
    s.slots.push_back({ K_APP, g_appName, -1, {} });
    for (int i = 0; i < (int)g_menus.size(); i++) s.slots.push_back({ K_MENU, g_menus[i].title, i, {} });
    // Virtual desktops, like the video's workspace dots: a pill for the current one, rings for the rest
    if (g_deskCount >= 2)
        for (int i = 0; i < g_deskCount; i++) s.slots.push_back({ K_DESK, L"", i, {} });
    // What's playing, only while something plays: note, title, previous / pause / next, visualizer
    size_t titleAt = 0;
    if (!g_mediaTitle.empty())
    {
        s.slots.push_back({ K_NOTE, L"\xF001", -1, {} });
        titleAt = s.slots.size();
        s.slots.push_back({ K_TITLE, g_mediaTitle.size() > 32 ? g_mediaTitle.substr(0, 31) + L"\x2026" : g_mediaTitle, -1, {} });
        s.slots.push_back({ K_MEDIA, L"\xF048", 0, {} });
        s.slots.push_back({ K_MEDIA, L"\xF04C", 1, {} });
        s.slots.push_back({ K_MEDIA, L"\xF051", 2, {} });
        s.slots.push_back({ K_VIZ, L"", -1, {} });
    }
    // The strip may run from the bar's left corner to just before the clock bar, less the room kept
    // for YASB's own left-side widgets (CPU, RAM, GPU, weather); the title is shortened to fit
    int left = s.monRect.left + S(s, BAR_GAP + BAR_RADIUS);
    int width = StripRight(s) - left;
    HDC dc = GetDC(s.hwnd);
    int h = S(s, BAR_HEIGHT) - 2; // inside the bar's 1 px outline
    auto widthOf = [&](const Slot& sl) {
        if (sl.kind == K_DESK) return S(s, sl.menu == g_deskCurrent ? 26 : 14);
        if (sl.kind == K_VIZ) return S(s, VIZ_BARS * 4 + 10);
        if (sl.kind == K_TITLE && sl.text.empty()) return 0;
        SelectObject(dc, FontFor(s, sl));
        SIZE sz; GetTextExtentPoint32W(dc, sl.text.c_str(), (int)sl.text.size(), &sz);
        return (int)sz.cx + S(s, sl.kind == K_LOGO ? 22 : sl.kind == K_MEDIA || sl.kind == K_NOTE ? 12 : 18);
    };
    auto gapBefore = [&](size_t i) {
        Kind k = s.slots[i].kind;
        return i > 0 && (k == K_DESK || k == K_NOTE || k == K_VIZ) && s.slots[i - 1].kind != k ? S(s, 8) : 0;
    };
    auto totalWidth = [&]() { int w = S(s, 2); for (size_t i = 0; i < s.slots.size(); i++) w += gapBefore(i) + widthOf(s.slots[i]); return w; };

    // Shorten the title until everything fits (at least 6 characters, else drop it)
    if (titleAt)
    {
        std::wstring full = s.slots[titleAt].text;
        size_t n = full.size();
        while (totalWidth() + S(s, 12) > width && n > 6)
            s.slots[titleAt].text = full.substr(0, --n) + L"\x2026";
        if (totalWidth() + S(s, 12) > width) s.slots[titleAt].text.clear();
    }

    int x = S(s, 2);
    for (size_t i = 0; i < s.slots.size(); i++) { x += gapBefore(i); int w = widthOf(s.slots[i]); s.slots[i].rc = { x, 0, x + w, h }; x += w; }
    ReleaseDC(s.hwnd, dc);

    // Sits inside the floating bar, right of its rounded left corner, so the corner and outline show
    SetWindowPos(s.hwnd, HWND_TOPMOST, left, s.monRect.top + S(s, BAR_GAP) + 1,
                 x + S(s, 4), h, SWP_NOACTIVATE | (s.hidden || s.noBar ? SWP_HIDEWINDOW : SWP_SHOWWINDOW));
    InvalidateRect(s.hwnd, nullptr, FALSE);
    PlaceLine(s);
}

static void LayoutAll() { for (auto& s : g_strips) Layout(s); }

static void Paint(Strip& s, HDC dc)
{
    RECT rc; GetClientRect(s.hwnd, &rc);
    HDC mem = CreateCompatibleDC(dc);
    HBITMAP bmp = CreateCompatibleBitmap(dc, rc.right, rc.bottom);
    HGDIOBJ oldBmp = SelectObject(mem, bmp);
    HBRUSH bg = CreateSolidBrush(BG); FillRect(mem, &rc, bg); DeleteObject(bg);
    SetBkMode(mem, TRANSPARENT);
    bool active = s.mon == g_activeMon;
    HBRUSH hover = CreateSolidBrush(HOVER);
    HGDIOBJ oldPen = SelectObject(mem, GetStockObject(NULL_PEN));
    for (int i = 0; i < (int)s.slots.size(); i++)
    {
        const Slot& sl = s.slots[i];
        if (i == s.hover || i == s.pressed)
        {
            HGDIOBJ ob = SelectObject(mem, hover);
            RoundRect(mem, sl.rc.left + S(s, 2), sl.rc.top + S(s, 4), sl.rc.right - S(s, 2), sl.rc.bottom - S(s, 4), S(s, 8), S(s, 8));
            SelectObject(mem, ob);
        }
        // Only the app name, its menus and the desktops dim on the screen without the focused app;
        // what's playing and CPU / RAM / GPU are the same everywhere
        bool lit = active || (sl.kind != K_APP && sl.kind != K_MENU && sl.kind != K_DESK) || i == s.hover || i == s.pressed;
        if (sl.kind == K_VIZ)
        {
            int bw = S(s, 3), gap = S(s, 1), maxH = S(s, 14), base = (sl.rc.top + sl.rc.bottom) / 2 + maxH / 2;
            int x0 = sl.rc.left + S(s, 5);
            HBRUSH b = CreateSolidBrush(SOFT);
            for (int k = 0; k < VIZ_BARS; k++)
            {
                int bh = (int)(g_viz[k].load() * maxH);
                if (bh < S(s, 1)) bh = S(s, 1);
                RECT bar = { x0 + k * (bw + gap), base - bh, x0 + k * (bw + gap) + bw, base };
                FillRect(mem, &bar, b);
            }
            DeleteObject(b);
            continue;
        }
        if (sl.kind == K_DESK)
        {
            int cy = (sl.rc.top + sl.rc.bottom) / 2, cx = (sl.rc.left + sl.rc.right) / 2;
            if (sl.menu == g_deskCurrent)
            {
                HBRUSH b = CreateSolidBrush(lit ? FG : DIM); HGDIOBJ ob = SelectObject(mem, b);
                RoundRect(mem, cx - S(s, 9), cy - S(s, 4), cx + S(s, 9), cy + S(s, 4), S(s, 8), S(s, 8));
                SelectObject(mem, ob); DeleteObject(b);
            }
            else
            {
                HPEN p = CreatePen(PS_SOLID, S(s, 1) > 1 ? S(s, 1) : 1, i == s.hover ? FG : lit ? MUTED : DIM);
                HGDIOBJ op = SelectObject(mem, p), ob = SelectObject(mem, GetStockObject(NULL_BRUSH));
                Ellipse(mem, cx - S(s, 4), cy - S(s, 4), cx + S(s, 4), cy + S(s, 4));
                SelectObject(mem, ob); SelectObject(mem, op); DeleteObject(p);
            }
            continue;
        }
        // like macOS: the screen without the focused app shows the menus dimmed (the logo stays bright)
        COLORREF c = !lit ? DIM : i == s.hover ? FG : sl.kind == K_NOTE || sl.kind == K_TITLE ? MUTED : sl.kind == K_MEDIA ? SOFT : FG;
        SetTextColor(mem, c);
        SelectObject(mem, FontFor(s, sl));
        RECT r = sl.rc;
        DrawTextW(mem, sl.text.c_str(), (int)sl.text.size(), &r, DT_CENTER | DT_VCENTER | DT_SINGLELINE | DT_NOPREFIX);
    }
    SelectObject(mem, oldPen);
    DeleteObject(hover);
    BitBlt(dc, 0, 0, rc.right, rc.bottom, mem, 0, 0, SRCCOPY);
    SelectObject(mem, oldBmp); DeleteObject(bmp); DeleteDC(mem);
}

// ---------- following focus ----------

static bool IsBarWindow(HWND h);

// YASB's hide_on_fullscreen only sends its bars to the bottom of the window stack, where they can
// still turn up over a game (and keep a window composited over it). Really hide the bars on that
// screen while the full-screen app has focus, and bring them back on top afterwards.
static BOOL CALLBACK HideBar(HWND h, LPARAM lp)
{
    Strip& s = *(Strip*)lp;
    if (IsWindowVisible(h) && !StripOf(h) && IsBarWindow(h) && MonitorFromWindow(h, MONITOR_DEFAULTTONEAREST) == s.mon)
    {
        SetWindowPos(h, nullptr, 0, 0, 0, 0, SWP_HIDEWINDOW | SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE);
        s.hiddenBars.push_back(h);
    }
    return TRUE;
}

static void SetBarsHidden(Strip& s, bool hide)
{
    if (hide) { EnumWindows(HideBar, (LPARAM)&s); return; }
    for (HWND b : s.hiddenBars)
        if (IsWindow(b)) SetWindowPos(b, HWND_TOPMOST, 0, 0, 0, 0, SWP_SHOWWINDOW | SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE);
    s.hiddenBars.clear(); // showing them raises the strips again (OnShow)
}

// Walk the windows on one screen from the top down: the screen counts as full-screen when the first
// app window that covers it comes before any ordinary window. Small always-on-top windows (a
// picture-in-picture video, an overlay) float over everything, so they are looked past.
struct ScreenScan { const Strip* s; bool fullscreen; };

static BOOL CALLBACK ScanScreen(HWND h, LPARAM lp)
{
    ScreenScan& c = *(ScreenScan*)lp;
    if (StripOf(h) || !IsAppWindow(h) || MonitorFromWindow(h, MONITOR_DEFAULTTONEAREST) != c.s->mon) return TRUE;
    // click-through overlays spanning the screen (the Claude app draws one) aren't apps you look at
    if (GetWindowLongW(h, GWL_EXSTYLE) & (WS_EX_TRANSPARENT | WS_EX_NOACTIVATE)) return TRUE;
    std::wstring cls = ClassOf(h);
    if (cls == L"Progman" || cls == L"WorkerW") return FALSE; // reached the desktop
    RECT wr = {}; GetWindowRect(h, &wr);
    const RECT& m = c.s->monRect;
    if (wr.left <= m.left && wr.top <= m.top && wr.right >= m.right && wr.bottom >= m.bottom) { c.fullscreen = true; return FALSE; }
    return (GetWindowLongW(h, GWL_EXSTYLE) & WS_EX_TOPMOST) ? TRUE : FALSE;
}

// Hide a strip and its screen's bars while a full-screen app (a game, a video) is on top of that
// screen, whether or not it has focus, so clicking something on the other screen keeps them hidden
static void UpdateHidden(bool force)
{
    bool changed = force;
    for (auto& s : g_strips)
    {
        ScreenScan c = { &s, false };
        EnumWindows(ScanScreen, (LPARAM)&c);
        if (c.fullscreen != s.hidden) { s.hidden = c.fullscreen; SetBarsHidden(s, c.fullscreen); changed = true; }
    }
    if (changed) LayoutAll();
}

// Which screens have a maximised window under the bar (for the separator line)
static std::vector<HMONITOR> g_maxMons;
static bool g_maxPending;

static BOOL CALLBACK FindMaximized(HWND h, LPARAM)
{
    if (IsZoomed(h) && IsAppWindow(h)) g_maxMons.push_back(MonitorFromWindow(h, MONITOR_DEFAULTTONEAREST));
    return TRUE;
}

static void UpdateMaximized()
{
    g_maxMons.clear();
    EnumWindows(FindMaximized, 0);
    for (auto& s : g_strips)
    {
        bool m = std::find(g_maxMons.begin(), g_maxMons.end(), s.mon) != g_maxMons.end();
        if (m != s.maxed) { s.maxed = m; PlaceLine(s); }
    }
}

// Windows move, maximise, minimise and close in bursts; check at most every 120 ms
static void QueueMaximized()
{
    if (g_maxPending || g_strips.empty()) return;
    g_maxPending = true;
    SetTimer(g_strips[0].hwnd, MAXED_TIMER, 120, nullptr);
}

static void SetTarget(HWND h)
{
    g_target = h;
    std::wstring cls = ClassOf(h), path = ExePath(h);
    bool desktop = cls == L"Progman" || cls == L"WorkerW";
    g_appKey = cls == L"CabinetWClass" ? L"explorer" : desktop ? L"desktop" : Lower(BaseName(path));
    g_appName = IniValue(L"app:" + g_appKey, L"name");
    if (g_appName.empty()) g_appName = FileDescription(path);
    if (g_appName.empty()) g_appName = BaseName(path);
    LoadMenus();

    // The desktop spans every screen; keep the focus marker on the screen under the cursor then
    POINT pt; GetCursorPos(&pt);
    HMONITOR mon = desktop ? MonitorFromPoint(pt, MONITOR_DEFAULTTOPRIMARY) : MonitorFromWindow(h, MONITOR_DEFAULTTONEAREST);
    g_activeMon = mon;
    UpdateHidden(true);
}

static void CALLBACK OnForeground(HWINEVENTHOOK, DWORD, HWND h, LONG obj, LONG, DWORD, DWORD)
{
    if (obj == OBJID_WINDOW && IsAppWindow(h)) SetTarget(h);
    QueueMaximized();
}

// Games often take focus while still windowed and go fullscreen a moment later, so check again
// whenever the focused window moves or resizes. Any window maximising or restoring moves too.
static void CALLBACK OnLocationChange(HWINEVENTHOOK, DWORD, HWND h, LONG obj, LONG child, DWORD, DWORD)
{
    if (obj != OBJID_WINDOW || child != CHILDID_SELF || !h) return;
    if (h == g_target) UpdateHidden(false);
    if (GetAncestor(h, GA_ROOT) == h) QueueMaximized();
}

// A maximised window that closes, hides or comes back from the taskbar
static void CALLBACK OnWindowChange(HWINEVENTHOOK, DWORD, HWND h, LONG obj, LONG child, DWORD, DWORD)
{
    if (obj == OBJID_WINDOW && child == CHILDID_SELF && h && !StripOf(h)) QueueMaximized();
}

// When something focuses Windows' desktop window (window managers such as Komorebi do on empty
// workspaces), Windows minimises tool windows such as the YASB bars and these strips. Put them
// straight back.
static bool IsBarWindow(HWND h)
{
    if (StripOf(h)) return true;
    wchar_t title[32] = {};
    GetWindowTextW(h, title, 32);
    return wcscmp(title, L"YasbBar") == 0 && Lower(BaseName(ExePath(h))) == L"yasb";
}

static void CALLBACK OnMinimize(HWINEVENTHOOK, DWORD, HWND h, LONG obj, LONG, DWORD, DWORD)
{
    if (obj == OBJID_WINDOW && IsBarWindow(h) && !g_strips.empty()) PostMessageW(g_strips[0].hwnd, WM_RESTORE_BAR, 0, (LPARAM)h);
    if (obj == OBJID_WINDOW) QueueMaximized();
}

// The YASB bars are topmost too, and one that (re)appears lands above the strips. Raise the strips
// again shortly after, once YASB has finished placing it.
static void CALLBACK OnShow(HWINEVENTHOOK, DWORD, HWND h, LONG obj, LONG, DWORD, DWORD)
{
    if (obj == OBJID_WINDOW && !StripOf(h) && IsBarWindow(h) && !g_strips.empty())
        SetTimer(g_strips[0].hwnd, RAISE_TIMER, 300, nullptr);
}

// A main bar spans (nearly) its screen; the floating ones stop BAR_GAP short of each side. The
// centre bar is far narrower than half the screen.
static bool IsWideBar(HWND h, HMONITOR mon)
{
    RECT r; MONITORINFO mi = { sizeof(mi) };
    return GetWindowRect(h, &r) && GetMonitorInfoW(mon, &mi)
        && (r.right - r.left) * 2 > mi.rcMonitor.right - mi.rcMonitor.left;
}

// Where the strip has to stop on its screen: the clock bar's left edge (or the screen's middle while
// it's hidden), less the room kept for YASB's left-side widgets
struct ClockFind { HMONITOR mon; int left; };

static BOOL CALLBACK FindClockBar(HWND h, LPARAM lp)
{
    ClockFind& f = *(ClockFind*)lp;
    if (!IsWindowVisible(h) || StripOf(h) || !IsBarWindow(h)) return TRUE;
    HMONITOR mon = MonitorFromWindow(h, MONITOR_DEFAULTTONEAREST);
    RECT r;
    if (mon == f.mon && !IsWideBar(h, mon) && GetWindowRect(h, &r)) { f.left = r.left; return FALSE; }
    return TRUE;
}

static int StripRight(const Strip& s)
{
    ClockFind f = { s.mon, INT_MAX };
    EnumWindows(FindClockBar, (LPARAM)&f);
    int right = f.left != INT_MAX ? f.left : (s.monRect.left + s.monRect.right) / 2 - S(s, 280);
    return right - S(s, g_reserve);
}

// A reappearing full-width bar also lands above YASB's narrow centre bar (date, time, next event)
// and hides it. Put every visible narrow YASB bar back on top.
static BOOL CALLBACK RaiseNarrowBar(HWND h, LPARAM)
{
    if (!IsWindowVisible(h) || StripOf(h) || !IsBarWindow(h)) return TRUE;
    if (!IsWideBar(h, MonitorFromWindow(h, MONITOR_DEFAULTTONEAREST)))
        SetWindowPos(h, HWND_TOPMOST, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE);
    return TRUE;
}

// YASB also re-tops its bars without showing them again (when a full-screen app closes, when its
// app bars re-register), which can leave the full-width bar over the centre bar. Windows sends no
// event for a change in stacking alone, so this also runs once a second (one pass over the window
// list) and only re-stacks when the order is wrong.
struct BarOrder { std::vector<HMONITOR> fullAbove; bool wrong; };

static BOOL CALLBACK CheckBar(HWND h, LPARAM lp)
{
    BarOrder& o = *(BarOrder*)lp;
    if (!IsWindowVisible(h) || StripOf(h) || !IsBarWindow(h)) return TRUE;
    HMONITOR mon = MonitorFromWindow(h, MONITOR_DEFAULTTONEAREST);
    if (IsWideBar(h, mon)) o.fullAbove.push_back(mon);
    else if (std::find(o.fullAbove.begin(), o.fullAbove.end(), mon) != o.fullAbove.end()) { o.wrong = true; return FALSE; }
    return TRUE;
}

static void FixBarOrder()
{
    BarOrder o = { {}, false };
    EnumWindows(CheckBar, (LPARAM)&o); // top of the stack first
    if (o.wrong) { EnumWindows(RaiseNarrowBar, 0); LayoutAll(); }
}

// The strips only make sense on a YASB bar. While YASB is closed (or not started yet) nothing
// reserves the space, so a strip would sit over the top of maximised windows; hide it until a bar
// is back. Bars this program hid for a full-screen app still count.
static std::vector<HMONITOR> g_barMons;

static BOOL CALLBACK SeeBar(HWND h, LPARAM)
{
    if (!IsWindowVisible(h) || StripOf(h) || !IsBarWindow(h)) return TRUE;
    HMONITOR mon = MonitorFromWindow(h, MONITOR_DEFAULTTONEAREST);
    if (IsWideBar(h, mon)) g_barMons.push_back(mon);
    return TRUE;
}

static bool UpdateBarPresence()
{
    g_barMons.clear();
    EnumWindows(SeeBar, 0);
    bool changed = false;
    for (auto& s : g_strips)
    {
        bool none = s.hiddenBars.empty() && std::find(g_barMons.begin(), g_barMons.end(), s.mon) == g_barMons.end();
        if (none != s.noBar) { s.noBar = none; changed = true; }
    }
    return changed;
}

// ---------- actions ----------

static WORD NamedKey(const std::wstring& n, bool& ext)
{
    std::wstring k = Lower(n);
    ext = false;
    struct { const wchar_t* name; WORD vk; bool ext; } map[] = {
        { L"enter", VK_RETURN, false }, { L"del", VK_DELETE, true }, { L"delete", VK_DELETE, true },
        { L"left", VK_LEFT, true }, { L"right", VK_RIGHT, true }, { L"up", VK_UP, true }, { L"down", VK_DOWN, true },
        { L"home", VK_HOME, true }, { L"end", VK_END, true }, { L"tab", VK_TAB, false }, { L"esc", VK_ESCAPE, false },
        { L"backspace", VK_BACK, false }, { L"bs", VK_BACK, false }, { L"space", VK_SPACE, false }, { L"lwin", VK_LWIN, true } };
    for (auto& m : map) if (k == m.name) { ext = m.ext; return m.vk; }
    if (k.size() >= 2 && k[0] == L'f') { int f = _wtoi(k.c_str() + 1); if (f >= 1 && f <= 24) return (WORD)(VK_F1 + f - 1); }
    return 0;
}

static void Key(std::vector<INPUT>& in, WORD vk, bool up, bool ext = false)
{
    INPUT i = {}; i.type = INPUT_KEYBOARD; i.ki.wVk = vk;
    i.ki.dwFlags = (up ? KEYEVENTF_KEYUP : 0) | (ext ? KEYEVENTF_EXTENDEDKEY : 0);
    in.push_back(i);
}

// WinForms SendKeys-style spec: ^ Ctrl, + Shift, % Alt, then one key or {NAME}
static void SendKeySpec(const std::wstring& spec)
{
    std::vector<WORD> mods; size_t i = 0;
    while (i < spec.size() && (spec[i] == L'^' || spec[i] == L'+' || spec[i] == L'%'))
        mods.push_back(spec[i] == L'^' ? VK_CONTROL : spec[i] == L'+' ? VK_SHIFT : VK_MENU), i++;
    if (i >= spec.size()) return;
    WORD vk = 0; bool ext = false;
    if (spec[i] == L'{') { size_t e = spec.find(L'}', i); vk = NamedKey(spec.substr(i + 1, e - i - 1), ext); }
    else { SHORT r = VkKeyScanW(spec[i]); if (r == -1) return; vk = LOBYTE(r); if (HIBYTE(r) & 1) mods.push_back(VK_SHIFT); }
    if (!vk) return;
    std::vector<INPUT> in;
    for (WORD m : mods) Key(in, m, false);
    Key(in, vk, false, ext); Key(in, vk, true, ext);
    for (auto it = mods.rbegin(); it != mods.rend(); ++it) Key(in, *it, true);
    SendInput((UINT)in.size(), in.data(), sizeof(INPUT));
}

static bool Confirm(HWND owner, const wchar_t* text) { return MessageBoxW(owner, text, L"Menu bar", MB_YESNO | MB_ICONQUESTION | MB_TOPMOST) == IDYES; }

// Restart / shut down like Start: no prompt, and with Automatic Restart Sign-On (SHUTDOWN_ARSO), meant
// to sign back in and lock on the next boot so it shows your own lock screen (a plain restart stops
// at the pre-sign-in screen with its stale Spotlight picture). Apps registered for restart (Brave
// with its last tabs) are only asked back (SHUTDOWN_RESTARTAPPS) when Windows' "Restart apps"
// setting (Winlogon RestartApps) is on; shutdown /g and /sg always asked them back.
static void PowerOff(bool restart)
{
    HANDLE tok;
    if (OpenProcessToken(GetCurrentProcess(), TOKEN_ADJUST_PRIVILEGES | TOKEN_QUERY, &tok))
    {
        TOKEN_PRIVILEGES tp = { 1 };
        tp.Privileges[0].Attributes = SE_PRIVILEGE_ENABLED;
        if (LookupPrivilegeValueW(nullptr, SE_SHUTDOWN_NAME, &tp.Privileges[0].Luid)) AdjustTokenPrivileges(tok, FALSE, &tp, 0, nullptr, nullptr);
        CloseHandle(tok);
    }
    DWORD restartApps = 0, size = sizeof restartApps;
    RegGetValueW(HKEY_CURRENT_USER, L"Software\\Microsoft\\Windows NT\\CurrentVersion\\Winlogon", L"RestartApps",
                 RRF_RT_REG_DWORD, nullptr, &restartApps, &size);
    DWORD flags = (restart ? SHUTDOWN_RESTART : SHUTDOWN_POWEROFF) | SHUTDOWN_ARSO | (restartApps ? SHUTDOWN_RESTARTAPPS : 0);
    DWORD err = InitiateShutdownW(nullptr, nullptr, 0, flags, SHTDN_REASON_MAJOR_OTHER | SHTDN_REASON_MINOR_OTHER | SHTDN_REASON_FLAG_PLANNED);
    if (err != ERROR_SUCCESS) // fall back to a plain restart / shutdown
        ShellExecuteW(nullptr, L"open", L"shutdown.exe", restart ? L"/r /t 0" : L"/s /t 0", nullptr, SW_HIDE);
}

static void Run(HWND owner, const Action& a)
{
    if (!IsWindow(g_target)) SetTarget(GetShellWindow());
    const std::wstring& c = a.cmd;
    if (c == L"minimize") PostMessageW(g_target, WM_SYSCOMMAND, SC_MINIMIZE, 0);
    else if (c == L"maximize") PostMessageW(g_target, WM_SYSCOMMAND, IsZoomed(g_target) ? SC_RESTORE : SC_MAXIMIZE, 0);
    else if (c == L"close") PostMessageW(g_target, WM_SYSCOMMAND, SC_CLOSE, 0);
    else if (c.rfind(L"open:", 0) == 0) ShellExecuteW(nullptr, L"open", c.substr(5).c_str(), nullptr, nullptr, SW_SHOWNORMAL);
    else if (c == L"start") SendKeySpec(L"{LWIN}");
    else if (c == L"lock") LockWorkStation();
    else if (c == L"sleep") SetSuspendState(FALSE, FALSE, FALSE);
    else if (c == L"restart") PowerOff(true);
    else if (c == L"shutdown") PowerOff(false);
    else if (c == L"logoff") { if (Confirm(owner, L"Sign out now?")) ExitWindowsEx(EWX_LOGOFF, 0); }
    else if (!a.keys.empty()) { SetForegroundWindow(g_target); Sleep(60); SendKeySpec(a.keys); }
}

// ---------- virtual desktops ----------

// Explorer lists the desktops in VirtualDesktopIDs (16 bytes per desktop, in order) and the
// current one in CurrentVirtualDesktop. A worker thread waits on a registry change event and posts
// WM_DESKTOPS, so this runs only when desktops are added, removed or switched.
static bool ReadDesktops()
{
    BYTE ids[16 * 64]; DWORD size = sizeof ids;
    LSTATUS st = RegGetValueW(HKEY_CURRENT_USER, DESKTOPS_KEY, L"VirtualDesktopIDs", RRF_RT_REG_BINARY, nullptr, ids, &size);
    if (st != ERROR_SUCCESS || size < 16) return false; // keep what we had (Explorer may be mid-write)
    DWORD n = size / 16;
    BYTE cur[16]; DWORD cs = sizeof cur; int idx = 0;
    if (RegGetValueW(HKEY_CURRENT_USER, DESKTOPS_KEY, L"CurrentVirtualDesktop", RRF_RT_REG_BINARY, nullptr, cur, &cs) == ERROR_SUCCESS && cs == 16)
        for (DWORD i = 0; i < n; i++) if (!memcmp(ids + 16 * i, cur, 16)) idx = (int)i;
    bool changed = (int)n != g_deskCount || idx != g_deskCurrent;
    g_deskCount = (int)n; g_deskCurrent = idx;
    return changed;
}

static void DesktopsThread()
{
    HKEY key;
    if (RegOpenKeyExW(HKEY_CURRENT_USER, DESKTOPS_KEY, 0, KEY_NOTIFY, &key) != ERROR_SUCCESS) return;
    HANDLE ev = CreateEventW(nullptr, FALSE, FALSE, nullptr);
    while (ev && RegNotifyChangeKeyValue(key, FALSE, REG_NOTIFY_CHANGE_LAST_SET, ev, TRUE) == ERROR_SUCCESS
           && WaitForSingleObject(ev, INFINITE) == WAIT_OBJECT_0)
        if (g_msgWnd) PostMessageW(g_msgWnd, WM_DESKTOPS, 0, 0);
}

// There's no public call to switch desktops, so press Ctrl+Win+Left/Right as many times as needed
static void SwitchDesktop(int target)
{
    int d = target - g_deskCurrent;
    WORD arrow = d > 0 ? VK_RIGHT : VK_LEFT;
    for (int i = 0; i < (d > 0 ? d : -d); i++)
    {
        std::vector<INPUT> in;
        Key(in, VK_CONTROL, false); Key(in, VK_LWIN, false, true);
        Key(in, arrow, false, true); Key(in, arrow, true, true);
        Key(in, VK_LWIN, true, true); Key(in, VK_CONTROL, true);
        SendInput((UINT)in.size(), in.data(), sizeof(INPUT));
        Sleep(60);
    }
}

// ---------- what's playing ----------

// Windows' media controls (the same ones the volume flyout shows). A worker thread follows every
// player's sessions through events and posts WM_MEDIA when the playing title changes; the strip
// shows it only while something is actually playing, so a paused tab or player disappears.
namespace wmc = winrt::Windows::Media::Control;
static std::mutex g_mediaLock;
static wmc::GlobalSystemMediaTransportControlsSessionManager g_mediaMgr{ nullptr };
static wmc::GlobalSystemMediaTransportControlsSession g_mediaSession{ nullptr }; // the playing one
static std::wstring g_mediaShared; // its title, for the UI thread
static std::vector<wmc::GlobalSystemMediaTransportControlsSession::PlaybackInfoChanged_revoker> g_playRevokers;
static std::vector<wmc::GlobalSystemMediaTransportControlsSession::MediaPropertiesChanged_revoker> g_propRevokers;

static void RefreshMedia()
{
    wmc::GlobalSystemMediaTransportControlsSession playing{ nullptr };
    std::wstring title;
    try
    {
        auto mgr = g_mediaMgr;
        if (!mgr) return;
        auto isPlaying = [](const wmc::GlobalSystemMediaTransportControlsSession& s) {
            auto info = s.GetPlaybackInfo();
            return info && info.PlaybackStatus() == wmc::GlobalSystemMediaTransportControlsSessionPlaybackStatus::Playing;
        };
        if (auto cur = mgr.GetCurrentSession(); cur && isPlaying(cur)) playing = cur;
        if (!playing)
            for (const auto& s : mgr.GetSessions()) if (isPlaying(s)) { playing = s; break; }
        if (playing)
        {
            auto props = playing.TryGetMediaPropertiesAsync().get();
            title = props.Title().c_str();
            if (title.empty()) title = props.Artist().c_str();
            if (title.empty()) title = L"Playing";
        }
    }
    catch (...) { playing = nullptr; title.clear(); }
    {
        std::lock_guard<std::mutex> lock(g_mediaLock);
        if (title == g_mediaShared && playing == g_mediaSession) return;
        g_mediaSession = playing; g_mediaShared = title;
    }
    if (g_msgWnd) PostMessageW(g_msgWnd, WM_MEDIA, 0, 0);
}

static void HookSessions()
{
    try
    {
        auto mgr = g_mediaMgr;
        std::vector<wmc::GlobalSystemMediaTransportControlsSession::PlaybackInfoChanged_revoker> play;
        std::vector<wmc::GlobalSystemMediaTransportControlsSession::MediaPropertiesChanged_revoker> prop;
        for (const auto& s : mgr.GetSessions())
        {
            play.push_back(s.PlaybackInfoChanged(winrt::auto_revoke, [](auto&&, auto&&) { RefreshMedia(); }));
            prop.push_back(s.MediaPropertiesChanged(winrt::auto_revoke, [](auto&&, auto&&) { RefreshMedia(); }));
        }
        {
            std::lock_guard<std::mutex> lock(g_mediaLock);
            g_playRevokers.swap(play); g_propRevokers.swap(prop);
        }
        // play / prop now hold the old handlers, revoked here outside the lock
    }
    catch (...) {}
}

static void MediaThread()
{
    winrt::init_apartment(winrt::apartment_type::multi_threaded);
    try
    {
        g_mediaMgr = wmc::GlobalSystemMediaTransportControlsSessionManager::RequestAsync().get();
        g_mediaMgr.SessionsChanged([](auto&&, auto&&) { HookSessions(); RefreshMedia(); });
        g_mediaMgr.CurrentSessionChanged([](auto&&, auto&&) { RefreshMedia(); });
        HookSessions();
        RefreshMedia();
    }
    catch (...) {}
    // the events above arrive on Windows' thread pool; this thread only had to set them up
}

// ---------- visualizer ----------

// Captures what the speakers play (WASAPI loopback on the default output), only while something is
// playing, and turns the last 1024 samples into VIZ_BARS log-spaced bands about 30 times a second.
static void Fft(std::vector<std::complex<float>>& a)
{
    size_t n = a.size();
    for (size_t i = 1, j = 0; i < n; i++)
    {
        size_t bit = n >> 1;
        for (; j & bit; bit >>= 1) j ^= bit;
        j ^= bit;
        if (i < j) std::swap(a[i], a[j]);
    }
    for (size_t len = 2; len <= n; len <<= 1)
    {
        float ang = -2.0f * 3.14159265f / (float)len;
        std::complex<float> wl(std::cos(ang), std::sin(ang));
        for (size_t i = 0; i < n; i += len)
        {
            std::complex<float> w(1.0f, 0.0f);
            for (size_t k = 0; k < len / 2; k++, w *= wl)
            {
                auto u = a[i + k], v = a[i + k + len / 2] * w;
                a[i + k] = u + v; a[i + k + len / 2] = u - v;
            }
        }
    }
}

static void Analyse(const float* ring, size_t pos, UINT rate)
{
    const size_t N = 1024;
    std::vector<std::complex<float>> a(N);
    for (size_t i = 0; i < N; i++)
    {
        float hann = 0.5f - 0.5f * std::cos(2.0f * 3.14159265f * i / (N - 1));
        a[i] = ring[(pos + i) % N] * hann;
    }
    Fft(a);
    for (int k = 0; k < VIZ_BARS; k++)
    {
        double lo = 50.0 * std::pow(12000.0 / 50.0, (double)k / VIZ_BARS), hi = 50.0 * std::pow(12000.0 / 50.0, (double)(k + 1) / VIZ_BARS);
        size_t b0 = (size_t)(lo * N / rate), b1 = (size_t)(hi * N / rate);
        if (b1 <= b0) b1 = b0 + 1;
        float mag = 0;
        for (size_t b = b0; b < b1 && b < N / 2; b++) mag = std::max(mag, std::abs(a[b]) / (N / 4.0f));
        float level = (20.0f * std::log10(mag + 1e-9f) + 60.0f) / 50.0f; // -60 dB .. -10 dB
        level = std::min(1.0f, std::max(0.0f, level));
        float old = g_viz[k].load();
        g_viz[k] = level > old ? level : old * 0.82f; // jump up, fall back slowly
    }
}

static void Capture()
{
    IMMDeviceEnumerator* en = nullptr; IMMDevice* dev = nullptr; IAudioClient* ac = nullptr; IAudioCaptureClient* cc = nullptr;
    WAVEFORMATEX* wf = nullptr;
    static const GUID FLOAT_FORMAT = { 0x00000003, 0x0000, 0x0010, { 0x80, 0x00, 0x00, 0xaa, 0x00, 0x38, 0x9b, 0x71 } };
    if (SUCCEEDED(CoCreateInstance(__uuidof(MMDeviceEnumerator), nullptr, CLSCTX_ALL, __uuidof(IMMDeviceEnumerator), (void**)&en))
        && SUCCEEDED(en->GetDefaultAudioEndpoint(eRender, eConsole, &dev))
        && SUCCEEDED(dev->Activate(__uuidof(IAudioClient), CLSCTX_ALL, nullptr, (void**)&ac))
        && SUCCEEDED(ac->GetMixFormat(&wf)))
    {
        bool isFloat = wf->wBitsPerSample == 32 && (wf->wFormatTag == WAVE_FORMAT_IEEE_FLOAT
            || (wf->wFormatTag == WAVE_FORMAT_EXTENSIBLE && IsEqualGUID(((WAVEFORMATEXTENSIBLE*)wf)->SubFormat, FLOAT_FORMAT)));
        if (isFloat && SUCCEEDED(ac->Initialize(AUDCLNT_SHAREMODE_SHARED, AUDCLNT_STREAMFLAGS_LOOPBACK, 1000000 /* 100 ms */, 0, wf, nullptr))
            && SUCCEEDED(ac->GetService(__uuidof(IAudioCaptureClient), (void**)&cc)) && SUCCEEDED(ac->Start()))
        {
            float ring[1024] = {}; size_t pos = 0;
            DWORD last = GetTickCount();
            bool ok = true;
            while (ok && g_vizWanted)
            {
                Sleep(15);
                UINT32 pkt = 0;
                while (ok && SUCCEEDED(cc->GetNextPacketSize(&pkt)) && pkt)
                {
                    BYTE* data; UINT32 frames; DWORD flags;
                    if (FAILED(cc->GetBuffer(&data, &frames, &flags, nullptr, nullptr))) { ok = false; break; }
                    const float* f = (const float*)data;
                    for (UINT32 i = 0; i < frames; i++)
                    {
                        float v = 0;
                        if (!(flags & AUDCLNT_BUFFERFLAGS_SILENT)) for (WORD c = 0; c < wf->nChannels; c++) v += f[i * wf->nChannels + c];
                        ring[pos] = v / wf->nChannels; pos = (pos + 1) % 1024;
                    }
                    cc->ReleaseBuffer(frames);
                }
                if (FAILED(cc->GetNextPacketSize(&pkt))) ok = false; // device gone: start over
                if (GetTickCount() - last >= 33)
                {
                    last = GetTickCount();
                    Analyse(ring, pos, wf->nSamplesPerSec);
                    if (g_msgWnd) PostMessageW(g_msgWnd, WM_VIZ, 0, 0);
                }
            }
            ac->Stop();
        }
    }
    if (cc) cc->Release();
    if (wf) CoTaskMemFree(wf);
    if (ac) ac->Release();
    if (dev) dev->Release();
    if (en) en->Release();
}

static void VizThread()
{
    CoInitializeEx(nullptr, COINIT_MULTITHREADED);
    for (;;)
    {
        while (!g_vizWanted) WaitForSingleObject(g_vizWake, INFINITE);
        Capture();
        for (auto& v : g_viz) v = 0.0f;
        if (g_msgWnd) PostMessageW(g_msgWnd, WM_VIZ, 0, 0);
        if (g_vizWanted) Sleep(1000); // capture failed (device changed?): try again shortly
    }
}

static void MediaCommand(int which)
{
    wmc::GlobalSystemMediaTransportControlsSession s{ nullptr };
    { std::lock_guard<std::mutex> lock(g_mediaLock); s = g_mediaSession; }
    if (!s) return;
    try
    {
        if (which == 0) s.TrySkipPreviousAsync();
        else if (which == 1) s.TryTogglePlayPauseAsync();
        else s.TrySkipNextAsync();
    }
    catch (...) {}
}

static std::vector<Action> g_actions;

static void Append(HMENU m, const Item& it)
{
    if (it.sep) { AppendMenuW(m, MF_SEPARATOR, 0, nullptr); return; }
    std::wstring text = it.label;
    if (it.act.cmd == L"maximize" && IsZoomed(g_target)) text = L"Restore";
    if (!it.hint.empty()) text += L"\t" + it.hint;
    g_actions.push_back(it.act);
    AppendMenuW(m, MF_STRING, g_actions.size(), text.c_str());
}

// A whole menu from one ini section ([system] for the Windows logo, [power] for the bar's power button)
static std::vector<Item> IniItems(const std::wstring& section)
{
    std::vector<Item> items;
    for (const auto& line : IniSection(section))
    {
        size_t eq = line.find(L'='); Item it; it.label = Trim(line.substr(0, eq));
        if (it.label == L"-") it.sep = true; else { auto p = Split(line.substr(eq + 1), L'|'); if (p.empty()) continue; it.act = ParseAction(p[0]); if (p.size() > 1) it.hint = p[1]; }
        items.push_back(it);
    }
    return items;
}

// `menubar.exe --menu <section>` (the YASB power button) opens that section's menu under the
// cursor, just below the bar, using the same actions as the strips (restart with sign-in and lock).
static std::wstring g_requestedMenu;

static void OpenIniMenu(const std::wstring& section)
{
    if (g_strips.empty()) return;
    POINT pt; GetCursorPos(&pt);
    HMONITOR mon = MonitorFromPoint(pt, MONITOR_DEFAULTTONEAREST);
    Strip* s = &g_strips[0];
    for (auto& st : g_strips) if (st.mon == mon) s = &st;
    HWND hwnd = s->hwnd;
    g_actions.clear();
    HMENU m = CreatePopupMenu();
    for (const auto& it : IniItems(section)) Append(m, it);
    pt.y = s->monRect.top + S(*s, BAR_GAP + BAR_HEIGHT + 4);
    SetForegroundWindow(hwnd);
    int id = (int)TrackPopupMenuEx(m, TPM_RETURNCMD | TPM_RIGHTALIGN | TPM_TOPALIGN | TPM_NONOTIFY, pt.x, pt.y, hwnd, nullptr);
    PostMessageW(hwnd, WM_NULL, 0, 0);
    DestroyMenu(m);
    if (id > 0 && id <= (int)g_actions.size()) Run(hwnd, g_actions[id - 1]);
}

static void OpenSlot(Strip& s, int i)
{
    const Slot sl = s.slots[i];
    HWND hwnd = s.hwnd;
    g_actions.clear();
    HMENU m = CreatePopupMenu();
    std::vector<Item> items;
    if (sl.kind == K_LOGO) items = IniItems(L"system");
    else if (sl.kind == K_APP)
    {
        Item hide; hide.label = L"Hide " + g_appName; hide.act.cmd = L"minimize"; items.push_back(hide);
        Item sep; sep.sep = true; items.push_back(sep);
        Item quit; quit.label = L"Quit " + g_appName; quit.act.cmd = L"close"; quit.hint = L"Alt+F4"; items.push_back(quit);
    }
    else items = g_menus[sl.menu].items;
    for (const auto& it : items) Append(m, it);

    s.pressed = i; s.hover = -1; InvalidateRect(hwnd, nullptr, FALSE); UpdateWindow(hwnd);
    POINT pt = { sl.rc.left, sl.rc.bottom }; ClientToScreen(hwnd, &pt);
    SetForegroundWindow(hwnd);
    int id = (int)TrackPopupMenuEx(m, TPM_RETURNCMD | TPM_LEFTALIGN | TPM_TOPALIGN | TPM_NONOTIFY, pt.x, pt.y, hwnd, nullptr);
    PostMessageW(hwnd, WM_NULL, 0, 0);
    DestroyMenu(m);
    if (Strip* again = StripOf(hwnd)) { again->pressed = -1; InvalidateRect(hwnd, nullptr, FALSE); }
    if (id > 0 && id <= (int)g_actions.size()) Run(hwnd, g_actions[id - 1]);
    else if (IsWindow(g_target)) SetForegroundWindow(g_target);
}

static void OpenOwnMenu(HWND hwnd)
{
    HMENU m = CreatePopupMenu();
    AppendMenuW(m, MF_STRING, 1, L"Edit menus");
    AppendMenuW(m, MF_STRING, 2, L"Reload menus");
    AppendMenuW(m, MF_SEPARATOR, 0, nullptr);
    AppendMenuW(m, MF_STRING, 3, L"Quit menu bar");
    POINT pt; GetCursorPos(&pt);
    SetForegroundWindow(hwnd);
    int id = (int)TrackPopupMenuEx(m, TPM_RETURNCMD | TPM_NONOTIFY, pt.x, pt.y, hwnd, nullptr);
    PostMessageW(hwnd, WM_NULL, 0, 0);
    DestroyMenu(m);
    if (id == 1) ShellExecuteW(nullptr, L"open", L"notepad.exe", (L"\"" + g_ini + L"\"").c_str(), nullptr, SW_SHOWNORMAL);
    else if (id == 2) SetTarget(IsWindow(g_target) ? g_target : GetShellWindow());
    else if (id == 3) PostQuitMessage(0);
}

static int HitTest(const Strip& s, int x)
{
    for (int i = 0; i < (int)s.slots.size(); i++) if (x >= s.slots[i].rc.left && x < s.slots[i].rc.right) return i;
    return -1;
}

// ---------- creating one strip per screen ----------

static void CreateStrips();

static LRESULT CALLBACK WndProc(HWND h, UINT msg, WPARAM wp, LPARAM lp)
{
    Strip* s = StripOf(h);
    switch (msg)
    {
    case WM_PAINT: { PAINTSTRUCT ps; HDC dc = BeginPaint(h, &ps); if (s) Paint(*s, dc); EndPaint(h, &ps); return 0; }
    case WM_ERASEBKGND: return 1;
    case WM_MOUSEMOVE:
        if (s)
        {
            int i = HitTest(*s, GET_X_LPARAM(lp));
            if (i != s->hover) { s->hover = i; InvalidateRect(h, nullptr, FALSE); }
            TRACKMOUSEEVENT t = { sizeof t, TME_LEAVE, h, 0 }; TrackMouseEvent(&t);
        }
        return 0;
    case WM_MOUSELEAVE: if (s) { s->hover = -1; InvalidateRect(h, nullptr, FALSE); } return 0;
    case WM_LBUTTONDOWN:
        if (s)
        {
            int i = HitTest(*s, GET_X_LPARAM(lp));
            if (i < 0) return 0;
            const Slot sl = s->slots[i];
            if (sl.kind == K_DESK) SwitchDesktop(sl.menu);
            else if (sl.kind == K_MEDIA) MediaCommand(sl.menu);
            else if (sl.kind == K_NOTE || sl.kind == K_TITLE || sl.kind == K_VIZ) MediaCommand(1); // click the title to pause            else OpenSlot(*s, i);
        }
        return 0;
    case WM_DESKTOPS: if (ReadDesktops()) LayoutAll(); return 0;
    case WM_MEDIA:
    {
        std::wstring t;
        { std::lock_guard<std::mutex> lock(g_mediaLock); t = g_mediaShared; }
        if (t != g_mediaTitle) { g_mediaTitle = t; LayoutAll(); }
        bool want = !t.empty(); // the visualizer listens only while something plays
        if (want != g_vizWanted) { g_vizWanted = want; if (want) SetEvent(g_vizWake); }
        return 0;
    }
    case WM_VIZ:
        for (auto& st : g_strips)
            for (auto& sl : st.slots)
                if (sl.kind == K_VIZ) InvalidateRect(st.hwnd, &sl.rc, FALSE);
        return 0;
    case WM_RBUTTONUP: OpenOwnMenu(h); return 0;
    case WM_COPYDATA:
    {
        // Answer the second process straight away and open the menu afterwards
        auto* cd = (COPYDATASTRUCT*)lp;
        if (cd && cd->dwData == COPY_MENU && cd->lpData)
        {
            const wchar_t* text = (const wchar_t*)cd->lpData;
            g_requestedMenu.assign(text, wcsnlen(text, cd->cbData / sizeof(wchar_t)));
            PostMessageW(h, WM_OPEN_MENU, 0, 0);
            return TRUE;
        }
        return FALSE;
    }
    case WM_OPEN_MENU: OpenIniMenu(g_requestedMenu); return 0;
    case WM_MOUSEACTIVATE: return MA_NOACTIVATE;
    case WM_RESTORE_BAR:
    {
        HWND bar = (HWND)lp;
        if (IsWindow(bar) && IsIconic(bar)) ShowWindow(bar, SW_SHOWNOACTIVATE);
        if (Strip* bs = StripOf(bar)) Layout(*bs);
        return 0;
    }
    case WM_SIZE:
        if (wp == SIZE_MINIMIZED) PostMessageW(h, WM_RESTORE_BAR, 0, (LPARAM)h);
        return 0;
    case WM_DPICHANGED: if (s) { s->dpi = HIWORD(wp); MakeFonts(*s); Layout(*s); } return 0;
    case WM_DISPLAYCHANGE: PostMessageW(h, WM_REBUILD, 0, 0); return 0;
    case WM_REBUILD: CreateStrips(); return 0;
    case WM_TIMER:
        if (wp == RAISE_TIMER) { KillTimer(h, RAISE_TIMER); UpdateBarPresence(); EnumWindows(RaiseNarrowBar, 0); LayoutAll(); }
        else if (wp == MAXED_TIMER)
        {
            KillTimer(h, MAXED_TIMER); g_maxPending = false;
            if (UpdateBarPresence()) LayoutAll();
            UpdateHidden(false); UpdateMaximized(); FixBarOrder();
        }
        else if (wp == ORDER_TIMER) { if (UpdateBarPresence()) LayoutAll(); FixBarOrder(); }        return 0;
    // Each strip is registered as an app bar (without reserving space) only to hear what YASB hears:
    // when a full-screen app opens or closes, YASB re-tops its bars, so check the stacking after it
    case WM_APPBAR:
        if (wp == ABN_FULLSCREENAPP || wp == ABN_POSCHANGED) { SetTimer(g_strips[0].hwnd, RAISE_TIMER, 300, nullptr); QueueMaximized(); }
        return 0;
    case WM_SETTINGCHANGE: if (s) Layout(*s); return 0;
    }
    return DefWindowProcW(h, msg, wp, lp);
}

static BOOL CALLBACK AddMonitor(HMONITOR mon, HDC, LPRECT, LPARAM)
{
    MONITORINFO mi = { sizeof mi };
    GetMonitorInfoW(mon, &mi);
    Strip s; s.mon = mon; s.monRect = mi.rcMonitor;
    g_strips.push_back(s);
    return TRUE;
}

static void CreateStrips()
{
    // (Re)build after a monitor change: drop the old windows first
    std::vector<Strip> old; old.swap(g_strips);
    EnumDisplayMonitors(nullptr, nullptr, AddMonitor, 0);
    for (auto& s : g_strips)
    {
        s.hwnd = CreateWindowExW(WS_EX_TOOLWINDOW | WS_EX_TOPMOST | WS_EX_NOACTIVATE, CLASS_NAME, L"Menu bar",
                                 WS_POPUP, s.monRect.left, s.monRect.top, 10, 10, nullptr, nullptr, g_inst, nullptr);
        int corner = 1; DwmSetWindowAttribute(s.hwnd, 33 /* DWMWA_WINDOW_CORNER_PREFERENCE */, &corner, sizeof corner); // square
        s.dpi = GetDpiForWindow(s.hwnd);
        MakeFonts(s);
        s.line = CreateWindowExW(WS_EX_TOOLWINDOW | WS_EX_TOPMOST | WS_EX_NOACTIVATE | WS_EX_LAYERED | WS_EX_TRANSPARENT, LINE_CLASS,
                                 L"Menu bar line", WS_POPUP, s.monRect.left, s.monRect.top, 1, 1, nullptr, nullptr, g_inst, nullptr);
        SetLayeredWindowAttributes(s.line, 0, 255, LWA_ALPHA); // layered + transparent: clicks go through to the bar
        APPBARDATA abd = { sizeof abd }; abd.hWnd = s.hwnd; abd.uCallbackMessage = WM_APPBAR;
        SHAppBarMessage(ABM_NEW, &abd);
    }
    for (auto& o : old)
    {
        SetBarsHidden(o, false);
        APPBARDATA abd = { sizeof abd }; abd.hWnd = o.hwnd; SHAppBarMessage(ABM_REMOVE, &abd);
        DestroyWindow(o.hwnd); DestroyWindow(o.line);
        DeleteObject(o.font); DeleteObject(o.bold); DeleteObject(o.logo);
    }
    UpdateBarPresence();
    HWND fg = GetForegroundWindow();
    SetTarget(IsWindow(g_target) && IsAppWindow(g_target) ? g_target : IsAppWindow(fg) ? fg : GetShellWindow());
    UpdateMaximized();
    FixBarOrder();
    if (!g_strips.empty()) SetTimer(g_strips[0].hwnd, ORDER_TIMER, 1000, nullptr);
}

int WINAPI wWinMain(HINSTANCE inst, HINSTANCE, PWSTR cmdLine, int)
{
    // menubar.exe --menu <section>: ask the running copy to open that menu, then exit
    std::wstring args = Trim(cmdLine ? cmdLine : L"");
    if (args.rfind(L"--menu", 0) == 0)
    {
        std::wstring section = Trim(args.substr(6));
        if (HWND running = FindWindowW(CLASS_NAME, nullptr))
        {
            AllowSetForegroundWindow(ASFW_ANY); // the click on the bar lets this process pass focus on
            COPYDATASTRUCT cd = { COPY_MENU, (DWORD)((section.size() + 1) * sizeof(wchar_t)), (void*)section.c_str() };
            SendMessageW(running, WM_COPYDATA, 0, (LPARAM)&cd);
        }
        return 0;
    }

    HANDLE mutex = CreateMutexW(nullptr, TRUE, L"Local\\csps-stratum-menubar");
    if (GetLastError() == ERROR_ALREADY_EXISTS) return 0;
    SetProcessDpiAwarenessContext(DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2);
    g_inst = inst;

    // Dark popup menus (uxtheme SetPreferredAppMode = ordinal 135, FlushMenuThemes = 136)
    if (HMODULE ux = LoadLibraryExW(L"uxtheme.dll", nullptr, LOAD_LIBRARY_SEARCH_SYSTEM32))
    {
        auto setMode = (int(WINAPI*)(int))GetProcAddress(ux, MAKEINTRESOURCEA(135));
        auto flush = (void(WINAPI*)())GetProcAddress(ux, MAKEINTRESOURCEA(136));
        if (setMode) setMode(2);
        if (flush) flush();
    }

    wchar_t exe[MAX_PATH]; GetModuleFileNameW(nullptr, exe, MAX_PATH);
    g_ini = exe; g_ini = g_ini.substr(0, g_ini.find_last_of(L'.')) + L".ini";

    WNDCLASSEXW wc = { sizeof wc };
    wc.lpfnWndProc = WndProc; wc.hInstance = inst; wc.hCursor = LoadCursorW(nullptr, IDC_ARROW);
    wc.lpszClassName = CLASS_NAME;
    RegisterClassExW(&wc);
    WNDCLASSEXW lc = { sizeof lc };
    lc.lpfnWndProc = DefWindowProcW; lc.hInstance = inst; lc.hbrBackground = CreateSolidBrush(SEP);
    lc.lpszClassName = LINE_CLASS;
    RegisterClassExW(&lc);

    winrt::init_apartment(winrt::apartment_type::single_threaded); // for the media buttons
    g_msgWnd = CreateWindowExW(0, CLASS_NAME, L"", 0, 0, 0, 0, 0, HWND_MESSAGE, nullptr, inst, nullptr);
    ReadDesktops();
    g_vizWake = CreateEventW(nullptr, FALSE, FALSE, nullptr);
    std::thread(DesktopsThread).detach();
    std::thread(MediaThread).detach();
    std::thread(VizThread).detach();

    CreateStrips();
    HWINEVENTHOOK hook = SetWinEventHook(EVENT_SYSTEM_FOREGROUND, EVENT_SYSTEM_FOREGROUND, nullptr, OnForeground, 0, 0, WINEVENT_OUTOFCONTEXT);
    HWINEVENTHOOK minHook = SetWinEventHook(EVENT_SYSTEM_MINIMIZESTART, EVENT_SYSTEM_MINIMIZESTART, nullptr, OnMinimize, 0, 0, WINEVENT_OUTOFCONTEXT);
    HWINEVENTHOOK moveHook = SetWinEventHook(EVENT_OBJECT_LOCATIONCHANGE, EVENT_OBJECT_LOCATIONCHANGE, nullptr, OnLocationChange, 0, 0, WINEVENT_OUTOFCONTEXT);
    HWINEVENTHOOK showHook = SetWinEventHook(EVENT_OBJECT_SHOW, EVENT_OBJECT_SHOW, nullptr, OnShow, 0, 0, WINEVENT_OUTOFCONTEXT);
    HWINEVENTHOOK goneHook = SetWinEventHook(EVENT_OBJECT_DESTROY, EVENT_OBJECT_HIDE, nullptr, OnWindowChange, 0, 0, WINEVENT_OUTOFCONTEXT);
    HWINEVENTHOOK restoreHook = SetWinEventHook(EVENT_SYSTEM_MINIMIZEEND, EVENT_SYSTEM_MINIMIZEEND, nullptr, OnWindowChange, 0, 0, WINEVENT_OUTOFCONTEXT);

    MSG m;
    while (GetMessageW(&m, nullptr, 0, 0) > 0) { TranslateMessage(&m); DispatchMessageW(&m); }
    for (auto& s : g_strips) SetBarsHidden(s, false); // never leave the bars hidden behind us
    UnhookWinEvent(restoreHook);
    UnhookWinEvent(goneHook);
    UnhookWinEvent(showHook);
    UnhookWinEvent(moveHook);
    UnhookWinEvent(minHook);
    UnhookWinEvent(hook);
    for (auto& s : g_strips)
    {
        APPBARDATA abd = { sizeof abd }; abd.hWnd = s.hwnd; SHAppBarMessage(ABM_REMOVE, &abd);
        DestroyWindow(s.hwnd); DestroyWindow(s.line);
    }
    if (mutex) CloseHandle(mutex);
    return 0;
}
