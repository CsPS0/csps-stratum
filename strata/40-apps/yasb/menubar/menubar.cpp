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
#ifndef UNICODE
#define UNICODE
#endif
#include <windows.h>
#include <windowsx.h>
#include <dwmapi.h>
#include <shellapi.h>
#include <powrprof.h>
#include <string>
#include <vector>

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
enum Kind { K_LOGO, K_APP, K_MENU };
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
};

static std::vector<Strip> g_strips;
static HWND g_target;
static HMONITOR g_activeMon;
static std::wstring g_ini, g_appKey, g_appName;
static std::vector<Menu> g_menus;
static HINSTANCE g_inst;

static const COLORREF BG = RGB(0, 0, 0), FG = RGB(230, 230, 230), DIM = RGB(110, 112, 116), HOVER = RGB(42, 43, 45);
static const int BAR_HEIGHT = 30;   // matches dimensions.height in the YASB config
static const wchar_t* LOGO = L"\xF17A"; // Windows logo in Nerd Fonts
static const wchar_t* CLASS_NAME = L"CspsMenuBar";
static const UINT WM_RESTORE_BAR = WM_APP + 1, WM_REBUILD = WM_APP + 2;

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
    if (Lower(BaseName(ExePath(h))) == L"yasb") return false;
    return GetWindowTextLengthW(h) > 0;
}

static Action ParseAction(const std::wstring& v) { Action a; if (!v.empty() && v[0] == L'@') a.cmd = v.substr(1); else a.keys = v; return a; }

static void LoadMenus()
{
    g_menus.clear();
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
    s.font = CreateFontW(-S(s, 13), 0, 0, 0, FW_NORMAL, 0, 0, 0, DEFAULT_CHARSET, 0, 0, CLEARTYPE_QUALITY, 0, L"Segoe UI Variable Text");
    s.bold = CreateFontW(-S(s, 13), 0, 0, 0, FW_SEMIBOLD, 0, 0, 0, DEFAULT_CHARSET, 0, 0, CLEARTYPE_QUALITY, 0, L"Segoe UI Variable Text");
    s.logo = CreateFontW(-S(s, 15), 0, 0, 0, FW_NORMAL, 0, 0, 0, DEFAULT_CHARSET, 0, 0, CLEARTYPE_QUALITY, 0, L"JetBrainsMono NF");
}

static HFONT FontFor(const Strip& s, const Slot& sl) { return sl.kind == K_LOGO ? s.logo : sl.kind == K_APP ? s.bold : s.font; }

static void Layout(Strip& s)
{
    s.slots.clear();
    s.slots.push_back({ K_LOGO, LOGO, -1, {} });
    s.slots.push_back({ K_APP, g_appName, -1, {} });
    for (int i = 0; i < (int)g_menus.size(); i++) s.slots.push_back({ K_MENU, g_menus[i].title, i, {} });

    HDC dc = GetDC(s.hwnd);
    int x = S(s, 6), h = S(s, BAR_HEIGHT);
    for (auto& sl : s.slots)
    {
        SelectObject(dc, FontFor(s, sl));
        SIZE sz; GetTextExtentPoint32W(dc, sl.text.c_str(), (int)sl.text.size(), &sz);
        int w = sz.cx + S(s, sl.kind == K_LOGO ? 22 : 18);
        sl.rc = { x, 0, x + w, h };
        x += w;
    }
    ReleaseDC(s.hwnd, dc);

    SetWindowPos(s.hwnd, HWND_TOPMOST, s.monRect.left, s.monRect.top, x + S(s, 4), h,
                 SWP_NOACTIVATE | (s.hidden ? SWP_HIDEWINDOW : SWP_SHOWWINDOW));
    InvalidateRect(s.hwnd, nullptr, FALSE);
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
        // like macOS: the screen without the focused app shows the menus dimmed (the logo stays bright)
        SetTextColor(mem, active || sl.kind == K_LOGO || i == s.hover || i == s.pressed ? FG : DIM);
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

// Hide a strip while the focused app covers its whole screen (games, videos), like the bar does
static void UpdateHidden(bool force)
{
    HWND h = g_target;
    std::wstring cls = ClassOf(h);
    bool desktop = cls == L"Progman" || cls == L"WorkerW";
    HMONITOR mon = MonitorFromWindow(h, MONITOR_DEFAULTTONEAREST);
    RECT wr = {}; GetWindowRect(h, &wr);
    bool changed = force;
    for (auto& s : g_strips)
    {
        bool covers = wr.left <= s.monRect.left && wr.top <= s.monRect.top && wr.right >= s.monRect.right && wr.bottom >= s.monRect.bottom;
        bool hide = !desktop && !IsIconic(h) && s.mon == mon && covers;
        if (hide != s.hidden) { s.hidden = hide; changed = true; }
    }
    if (changed) LayoutAll();
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
}

// Games often take focus while still windowed and go fullscreen a moment later, so check again
// whenever the focused window moves or resizes
static void CALLBACK OnLocationChange(HWINEVENTHOOK, DWORD, HWND h, LONG obj, LONG, DWORD, DWORD)
{
    if (obj == OBJID_WINDOW && h && h == g_target) UpdateHidden(false);
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
    else if (c == L"restart") { if (Confirm(owner, L"Restart the computer now?")) ShellExecuteW(nullptr, L"open", L"shutdown.exe", L"/r /t 0", nullptr, SW_HIDE); }
    else if (c == L"shutdown") { if (Confirm(owner, L"Shut down the computer now?")) ShellExecuteW(nullptr, L"open", L"shutdown.exe", L"/s /t 0", nullptr, SW_HIDE); }
    else if (c == L"logoff") { if (Confirm(owner, L"Sign out now?")) ExitWindowsEx(EWX_LOGOFF, 0); }
    else if (!a.keys.empty()) { SetForegroundWindow(g_target); Sleep(60); SendKeySpec(a.keys); }
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

static void OpenSlot(Strip& s, int i)
{
    const Slot sl = s.slots[i];
    HWND hwnd = s.hwnd;
    g_actions.clear();
    HMENU m = CreatePopupMenu();
    std::vector<Item> items;
    if (sl.kind == K_LOGO)
    {
        for (const auto& line : IniSection(L"system"))
        {
            size_t eq = line.find(L'='); Item it; it.label = Trim(line.substr(0, eq));
            if (it.label == L"-") it.sep = true; else { auto p = Split(line.substr(eq + 1), L'|'); if (p.empty()) continue; it.act = ParseAction(p[0]); if (p.size() > 1) it.hint = p[1]; }
            items.push_back(it);
        }
    }
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
    case WM_LBUTTONDOWN: if (s) { int i = HitTest(*s, GET_X_LPARAM(lp)); if (i >= 0) OpenSlot(*s, i); } return 0;
    case WM_RBUTTONUP: OpenOwnMenu(h); return 0;
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
    }
    for (auto& o : old) { DestroyWindow(o.hwnd); DeleteObject(o.font); DeleteObject(o.bold); DeleteObject(o.logo); }
    HWND fg = GetForegroundWindow();
    SetTarget(IsWindow(g_target) && IsAppWindow(g_target) ? g_target : IsAppWindow(fg) ? fg : GetShellWindow());
}

int WINAPI wWinMain(HINSTANCE inst, HINSTANCE, PWSTR, int)
{
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

    CreateStrips();
    HWINEVENTHOOK hook = SetWinEventHook(EVENT_SYSTEM_FOREGROUND, EVENT_SYSTEM_FOREGROUND, nullptr, OnForeground, 0, 0, WINEVENT_OUTOFCONTEXT);
    HWINEVENTHOOK minHook = SetWinEventHook(EVENT_SYSTEM_MINIMIZESTART, EVENT_SYSTEM_MINIMIZESTART, nullptr, OnMinimize, 0, 0, WINEVENT_OUTOFCONTEXT);
    HWINEVENTHOOK moveHook = SetWinEventHook(EVENT_OBJECT_LOCATIONCHANGE, EVENT_OBJECT_LOCATIONCHANGE, nullptr, OnLocationChange, 0, 0, WINEVENT_OUTOFCONTEXT);

    MSG m;
    while (GetMessageW(&m, nullptr, 0, 0) > 0) { TranslateMessage(&m); DispatchMessageW(&m); }
    UnhookWinEvent(moveHook);
    UnhookWinEvent(minHook);
    UnhookWinEvent(hook);
    for (auto& s : g_strips) DestroyWindow(s.hwnd);
    if (mutex) CloseHandle(mutex);
    return 0;
}
