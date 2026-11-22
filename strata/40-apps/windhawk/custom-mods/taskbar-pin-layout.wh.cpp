// ==WindhawkMod==
// @id              taskbar-pin-layout
// @name            Taskbar Pin Layout
// @description     Pins a list of apps to the taskbar in a set order (a macOS-style full dock)
// @version         1.5
// @author          CsPS
// @include         explorer.exe
// @architecture    x86-64
// @compilerOptions -lole32 -loleaut32 -lshell32 -lshlwapi -luuid
// ==/WindhawkMod==

// ==WindhawkModReadme==
/*
# Taskbar Pin Layout

Windows 11 only lets Explorer itself pin apps to the taskbar, so a script can't
lay out the dock. This mod runs inside Explorer and does it there: it pins every
app in the list that isn't pinned yet, then puts the list in order at the start
of the taskbar. Pins that aren't in the list (like a separator from "Taskbar Icon
Separators") keep their order after the listed ones.

It applies the list once, and again only when you change the list or update the
mod, so apps you unpin or move by hand afterwards stay that way. Each run writes
what it did to `%TEMP%\taskbar-pin-layout.log`.

Each entry is one of:
- a program (`.exe`) or shortcut (`.lnk`) path; `%ProgramFiles%`, `%LOCALAPPDATA%` and
  other environment variables work, and one `*` in a folder name picks the newest
  match (`%ProgramFiles%\JetBrains\JetBrains Rider *\bin\rider64.exe` follows updates),
- `shell:AppsFolder\<AppUserModelID>` for Store apps (see `Get-StartApps`),
- `pinned:<name>` for a pinned shortcut without a program, like `pinned:File Explorer`,
- `separator` for a slot taken by a "Taskbar Icon Separators" separator: the
  separators are placed into the slots in the order they were added. Add them from
  the taskbar's right-click menu first; extra slots are left empty.

Apps are matched to what's pinned by the program the pinned shortcut starts (or,
if that differs, by the program's file name when only one pin has it), because
Windows renames the pinned shortcuts (`Brave (10).lnk`) whenever it rewrites a pin.

Uses the same private PinManager interface as "Taskbar Icon Separators".
Windows 11 only.
*/
// ==/WindhawkModReadme==

// ==WindhawkModSettings==
/*
- dock:
  - 'pinned:File Explorer'
  - '%ProgramFiles%\BraveSoftware\Brave-Browser\Application\brave.exe'
  - '%ProgramFiles%\LibreOffice\program\soffice.exe'
  - '%ProgramFiles%\LocalSend\localsend_app.exe'
  - 'separator'
  - '%LOCALAPPDATA%\Discord\Discord.exe'
  - '%LOCALAPPDATA%\element-desktop\Element.exe'
  - '%ProgramFiles%\Sonora\sonora.exe'
  - 'separator'
  - '%LOCALAPPDATA%\Programs\Zed\Zed.exe'
  - '%LOCALAPPDATA%\Programs\Microsoft VS Code Insiders\Code - Insiders.exe'
  - '%ProgramData%\Microsoft\Windows\Start Menu\Programs\Visual Studio Insiders.lnk'
  - '%ProgramFiles%\JetBrains\JetBrains Rider *\bin\rider64.exe'
  - '%ProgramFiles%\WezTerm\wezterm-gui.exe'
  - 'shell:AppsFolder\Microsoft.WindowsTerminal_8wekyb3d8bbwe!App'
  - '%LOCALAPPDATA%\GitHubDesktop\GitHubDesktop.exe'
  - 'shell:AppsFolder\Claude_pzs8sxrjxfjjc!Claude'
  - '%LOCALAPPDATA%\Programs\antigravity\Antigravity.exe'
  - '%APPDATA%\Microsoft\Windows\Start Menu\Programs\Figma.lnk'
  - '%ProgramFiles%\Zeal\zeal.exe'
  - '%ProgramFiles%\Oracle\VirtualBox\VirtualBox.exe'
  - '%APPDATA%\Microsoft\Windows\Start Menu\Programs\Roblox\Roblox Studio.lnk'
  - 'separator'
  - '%ProgramFiles(x86)%\Steam\steam.exe'
  - '%ProgramFiles%\Heroic\Heroic.exe'
  - '%ProgramFiles(x86)%\Ubisoft\Ubisoft Game Launcher\UbisoftConnect.exe'
  - '%ProgramFiles%\HoYoPlay\launcher.exe'
  - '%LOCALAPPDATA%\Programs\Horizon Launcher\horizon-launcher.exe'
  - '%LOCALAPPDATA%\Programs\PrismLauncher\prismlauncher.exe'
  - '%ProgramData%\Microsoft\Windows\Start Menu\Programs\Mod Organizer\Mod Organizer.lnk'
  - 'separator'
  - '%ProgramFiles%\Windhawk\windhawk.exe'
  - 'shell:AppsFolder\11413PtruceanBogdan.Wintoys_ankwhmsh70gj6!Wintoys'
  - '%ProgramFiles(x86)%\Steam\steamapps\common\wallpaper_engine\launcher.exe'
  - '%ProgramFiles%\UniGetUI\UniGetUI.exe'
  - '%ProgramFiles%\VS Revo Group\Revo Uninstaller\RevoUnin.exe'
  - '%ProgramFiles%\WinDirStat\WinDirStat.exe'
  - '%ProgramFiles%\HWiNFO64\HWiNFO64.EXE'
  - 'separator'
  $name: Pinned apps and separators, in order
  $description: One program, shortcut, shell:AppsFolder\AppID, pinned:<name> or separator per entry.
- reapply: false
  $name: Apply again
  $description: >-
    Turn on and save to re-apply the list even though it didn't change (for
    example after unpinning something by mistake); turn it off again afterwards.
*/
// ==/WindhawkModSettings==

#include <windows.h>
#include <shlobj.h>
#include <shlwapi.h>

#include <algorithm>
#include <atomic>
#include <cstdarg>
#include <cstdio>
#include <string>
#include <vector>

// Private taskbar PinManager COM ABI (as used by the Taskbar Icon Separators mod).
static const CLSID CLSID_PinManager = {
    0xA5C8D635, 0xB4ED, 0x452B, {0x81, 0x09, 0x95, 0x01, 0x78, 0x10, 0x96, 0xD1}};
static const IID IID_IPinManagerInterop2 = {
    0x87D9E034, 0x56D0, 0x4F8C, {0xBE, 0x59, 0x99, 0x7B, 0x01, 0x75, 0x47, 0x10}};
static const IID IID_IPinManagerInterop3 = {
    0x27216D91, 0x78B8, 0x406D, {0x85, 0xC4, 0x5F, 0xDB, 0xF5, 0x1C, 0xD1, 0x6B}};

enum PINNEDLISTMODIFYCALLER : int {
    PMC_TASKBANDPIN = 25,
    PMC_TASKBANDREORDER = 27,
};

struct IPinManagerInterop2 : IUnknown {
    virtual HRESULT STDMETHODCALLTYPE PinItemToTaskbarShim(PCUIDLIST_ABSOLUTE, PINNEDLISTMODIFYCALLER) = 0;
    virtual HRESULT STDMETHODCALLTYPE PinItemFromTrustedCaller(PCUIDLIST_ABSOLUTE, PINNEDLISTMODIFYCALLER) = 0;
    virtual HRESULT STDMETHODCALLTYPE ApplyPrependDefaultTaskbarLayout() = 0;
    virtual HRESULT STDMETHODCALLTYPE ApplyAppendDefaultTaskbarLayout() = 0;
    virtual HRESULT STDMETHODCALLTYPE ApplyInPlaceTaskbarLayout(int) = 0;
    virtual HRESULT STDMETHODCALLTYPE ApplyReorderTaskbarLayout(int, int) = 0;
    virtual HRESULT STDMETHODCALLTYPE UnpinTaskbarItem(PCUIDLIST_ABSOLUTE, PINNEDLISTMODIFYCALLER) = 0;
    virtual HRESULT STDMETHODCALLTYPE UpdatePinnedTaskbarItem(PCUIDLIST_ABSOLUTE, PCUIDLIST_ABSOLUTE,
                                                              PINNEDLISTMODIFYCALLER) = 0;
};

struct IPinManagerInterop3 : IPinManagerInterop2 {
    virtual HRESULT STDMETHODCALLTYPE MoveTaskbarPin(PCUIDLIST_ABSOLUTE, int, PINNEDLISTMODIFYCALLER) = 0;
};

static HANDLE g_thread = nullptr;
static FILE* g_log = nullptr;

static void Log(PCWSTR fmt, ...) {
    WCHAR buf[1024];
    va_list args;
    va_start(args, fmt);
    vswprintf_s(buf, fmt, args);
    va_end(args);
    Wh_Log(L"%s", buf);
    if (g_log) {
        fwprintf(g_log, L"%s\n", buf);
        fflush(g_log);
    }
}

static void OpenLog() {
    WCHAR path[MAX_PATH];
    DWORD n = GetTempPath(MAX_PATH, path);
    if (!n || n > MAX_PATH - 32) return;
    wcscat_s(path, L"taskbar-pin-layout.log");
    _wfopen_s(&g_log, path, L"w, ccs=UTF-8");
}
static std::atomic<bool> g_stop{false};

static std::wstring Expand(PCWSTR s) {
    WCHAR buf[2048];
    DWORD n = ExpandEnvironmentStrings(s, buf, ARRAYSIZE(buf));
    return (n && n <= ARRAYSIZE(buf)) ? std::wstring(buf) : std::wstring(s);
}

static std::wstring Lower(std::wstring s) {
    for (auto& c : s) c = towlower(c);
    return s;
}

// The program a shortcut starts (empty for shell links such as File Explorer).
static std::wstring ShortcutTarget(const std::wstring& lnk) {
    std::wstring result;
    IShellLinkW* link = nullptr;
    if (FAILED(CoCreateInstance(CLSID_ShellLink, nullptr, CLSCTX_INPROC_SERVER, IID_IShellLinkW, (void**)&link)))
        return result;
    IPersistFile* file = nullptr;
    if (SUCCEEDED(link->QueryInterface(IID_IPersistFile, (void**)&file))) {
        WCHAR path[MAX_PATH] = L"";
        if (SUCCEEDED(file->Load(lnk.c_str(), STGM_READ)) &&
            SUCCEEDED(link->GetPath(path, MAX_PATH, nullptr, SLGP_RAWPATH)) && *path) {
            result = Expand(path);
        }
        file->Release();
    }
    link->Release();
    return result;
}

struct PinnedShortcut {
    std::wstring path;      // the .lnk in User Pinned\TaskBar
    std::wstring target;    // lower-case full program path
    std::wstring exeName;   // lower-case program file name
    std::wstring baseName;  // lower-case shortcut name without " (n)" and .lnk
};

static std::vector<PinnedShortcut> ScanPinned() {
    std::vector<PinnedShortcut> out;
    std::wstring dir = Expand(L"%APPDATA%\\Microsoft\\Internet Explorer\\Quick Launch\\User Pinned\\TaskBar\\");
    WIN32_FIND_DATAW fd;
    HANDLE h = FindFirstFileW((dir + L"*.lnk").c_str(), &fd);
    if (h == INVALID_HANDLE_VALUE) return out;
    do {
        PinnedShortcut s;
        s.path = dir + fd.cFileName;
        s.target = Lower(ShortcutTarget(s.path));
        s.exeName = s.target.empty() ? L"" : Lower(PathFindFileNameW(s.target.c_str()));
        std::wstring base = fd.cFileName;
        base = base.substr(0, base.size() - 4);  // .lnk
        size_t paren = base.rfind(L" (");
        if (paren != std::wstring::npos && base.back() == L')') base = base.substr(0, paren);
        s.baseName = Lower(base);
        out.push_back(s);
    } while (FindNextFileW(h, &fd));
    FindClose(h);
    return out;
}

// The "Taskbar Icon Separators" shortcuts, in the order they were added.
static std::vector<std::wstring> ScanSeparators() {
    std::vector<std::pair<ULONGLONG, std::wstring>> found;
    std::wstring dir = Expand(L"%APPDATA%\\Microsoft\\Internet Explorer\\Quick Launch\\User Pinned\\TaskBar\\");
    WIN32_FIND_DATAW fd;
    HANDLE h = FindFirstFileW((dir + L"WindhawkSeparator.*.lnk").c_str(), &fd);
    if (h != INVALID_HANDLE_VALUE) {
        do {
            ULONGLONG created = ((ULONGLONG)fd.ftCreationTime.dwHighDateTime << 32) | fd.ftCreationTime.dwLowDateTime;
            found.push_back({created, dir + fd.cFileName});
        } while (FindNextFileW(h, &fd));
        FindClose(h);
    }
    std::sort(found.begin(), found.end());
    std::vector<std::wstring> out;
    for (auto& f : found) out.push_back(f.second);
    return out;
}

static bool IsSeparatorSlot(const std::wstring& entry) {
    return _wcsicmp(entry.c_str(), L"separator") == 0;
}

// Store apps (shell:AppsFolder\...) are used as they are; everything else is matched to a
// pinned shortcut. Returns what to move, or empty when the app isn't pinned (yet).
static std::wstring FindPinned(const std::wstring& entry, const std::vector<PinnedShortcut>& pinned) {
    if (_wcsnicmp(entry.c_str(), L"shell:", 6) == 0) return entry;
    if (_wcsnicmp(entry.c_str(), L"pinned:", 7) == 0) {
        std::wstring name = Lower(entry.substr(7));
        for (auto& s : pinned)
            if (s.baseName == name) return s.path;
        return L"";
    }
    std::wstring target =
        _wcsicmp(PathFindExtensionW(entry.c_str()), L".lnk") == 0 ? ShortcutTarget(entry) : entry;
    if (target.empty()) return L"";
    target = Lower(target);
    for (auto& s : pinned)
        if (s.target == target) return s.path;
    // Versioned installs (Figma, Roblox) point the Start shortcut and the pin at different
    // folders; fall back to the program's file name when exactly one pin has it.
    std::wstring exe = Lower(PathFindFileNameW(target.c_str()));
    const PinnedShortcut* only = nullptr;
    for (auto& s : pinned) {
        if (s.exeName != exe) continue;
        if (only) return L"";
        only = &s;
    }
    return only ? only->path : L"";
}

// "C:\Program Files\JetBrains\JetBrains Rider *\bin\rider64.exe": the * picks the newest
// (highest-sorting) folder that matches, so versioned installs keep resolving after updates.
static std::wstring ResolveWildcard(const std::wstring& path) {
    size_t star = path.find(L'*');
    if (star == std::wstring::npos) return path;
    size_t dirStart = path.rfind(L'\\', star);
    size_t dirEnd = path.find(L'\\', star);
    if (dirStart == std::wstring::npos) return path;
    std::wstring parent = path.substr(0, dirStart + 1);
    std::wstring pattern = path.substr(dirStart + 1, (dirEnd == std::wstring::npos ? path.size() : dirEnd) - dirStart - 1);
    std::wstring rest = dirEnd == std::wstring::npos ? L"" : path.substr(dirEnd);
    std::wstring best;
    WIN32_FIND_DATAW fd;
    HANDLE h = FindFirstFileW((parent + pattern).c_str(), &fd);
    if (h == INVALID_HANDLE_VALUE) return path;
    do {
        std::wstring candidate = parent + fd.cFileName + rest;
        if (GetFileAttributesW(candidate.c_str()) != INVALID_FILE_ATTRIBUTES &&
            (best.empty() || StrCmpLogicalW(fd.cFileName, best.c_str()) > 0)) {
            best = fd.cFileName;
        }
    } while (FindNextFileW(h, &fd));
    FindClose(h);
    return best.empty() ? path : parent + best + rest;
}

static std::vector<std::wstring> ReadPins() {
    std::vector<std::wstring> pins;
    for (int i = 0;; i++) {
        PCWSTR raw = Wh_GetStringSetting(L"dock[%d]", i);
        bool done = !*raw;
        if (!done) pins.push_back(ResolveWildcard(Expand(raw)));
        Wh_FreeStringSetting(raw);
        if (done) break;
    }
    return pins;
}

static std::wstring Signature(const std::vector<std::wstring>& pins) {
    std::wstring s = WH_MOD_VERSION;
    for (auto& p : pins) s += L"|" + p;
    // A short hash keeps the stored value small.
    unsigned long long h = 1469598103934665603ULL;
    for (wchar_t c : s) h = (h ^ (unsigned)c) * 1099511628211ULL;
    WCHAR out[32];
    swprintf_s(out, L"%016llx", h);
    return out;
}

static void ApplyLayout() {
    auto pins = ReadPins();
    if (pins.empty()) return;

    bool force = Wh_GetIntSetting(L"reapply");
    std::wstring sig = Signature(pins);
    WCHAR stored[64] = L"";
    Wh_GetStringValue(L"appliedSignature", stored, ARRAYSIZE(stored));
    if (!force && sig == stored) {
        Log(L"Layout already applied");
        return;
    }

    IPinManagerInterop2* interop2 = nullptr;
    HRESULT hr = CoCreateInstance(CLSID_PinManager, nullptr, CLSCTX_INPROC_SERVER | CLSCTX_LOCAL_SERVER,
                                  IID_IPinManagerInterop2, (void**)&interop2);
    if (FAILED(hr)) {
        Log(L"PinManager unavailable hr=0x%08X", (unsigned)hr);
        return;
    }
    IPinManagerInterop3* pm = nullptr;
    hr = interop2->QueryInterface(IID_IPinManagerInterop3, (void**)&pm);
    interop2->Release();
    if (FAILED(hr)) {
        Log(L"IPinManagerInterop3 unavailable hr=0x%08X", (unsigned)hr);
        return;
    }

    int failed = 0;

    // Pass 1: pin what isn't pinned yet. Pinning finishes asynchronously, so all moves wait.
    auto pinned = ScanPinned();
    bool pinnedSomething = false;
    for (auto& entry : pins) {
        if (g_stop) break;
        if (IsSeparatorSlot(entry) || _wcsnicmp(entry.c_str(), L"pinned:", 7) == 0 ||
            !FindPinned(entry, pinned).empty())
            continue;
        PIDLIST_ABSOLUTE pidl = nullptr;
        if (FAILED(SHParseDisplayName(entry.c_str(), nullptr, &pidl, 0, nullptr)) || !pidl) {
            Log(L"not found: %s", entry.c_str());
            continue;
        }
        HRESULT hr = pm->PinItemFromTrustedCaller(pidl, PMC_TASKBANDPIN);
        CoTaskMemFree(pidl);
        Log(L"pin 0x%08X %s", (unsigned)hr, entry.c_str());
        pinnedSomething = true;
    }
    if (pinnedSomething) {
        for (int i = 0; i < 6 && !g_stop; i++) Sleep(500);
        pinned = ScanPinned();
    }

    // Pass 2: put every app at its position. The position always follows the list (a failed
    // move doesn't shift the ones after it); moving in ascending order pulls each into place.
    auto separators = ScanSeparators();
    size_t nextSeparator = 0;
    for (size_t i = 0; i < pins.size() && !g_stop; i++) {
        std::wstring target;
        if (IsSeparatorSlot(pins[i])) {
            if (nextSeparator >= separators.size()) {
                Log(L"move %d: no separator left for this slot (add one from the taskbar's menu)", (int)i);
                failed++;
                continue;
            }
            target = separators[nextSeparator++];
        } else {
            target = FindPinned(pins[i], pinned);
        }
        PIDLIST_ABSOLUTE pidl = nullptr;
        if (target.empty() || FAILED(SHParseDisplayName(target.c_str(), nullptr, &pidl, 0, nullptr)) || !pidl) {
            Log(L"move %d: not pinned %s", (int)i, pins[i].c_str());
            failed++;
            continue;
        }
        HRESULT hr = pm->MoveTaskbarPin(pidl, (int)i, PMC_TASKBANDREORDER);
        CoTaskMemFree(pidl);
        Log(L"move %d 0x%08X %s", (int)i, (unsigned)hr, target.c_str());
        if (FAILED(hr)) failed++;
        Sleep(80);  // let the taskbar catch up between changes
    }
    pm->Release();

    if (!g_stop) {
        Wh_SetStringValue(L"appliedSignature", sig.c_str());
        Log(L"Layout applied: %d of %d placed", (int)pins.size() - failed, (int)pins.size());
    }
}

static DWORD WINAPI Worker(LPVOID) {
    // Wait for the taskbar after an Explorer start.
    for (int i = 0; i < 120 && !g_stop && !FindWindow(L"Shell_TrayWnd", nullptr); i++) Sleep(500);
    for (int i = 0; i < 6 && !g_stop; i++) Sleep(500);
    if (g_stop) return 0;
    OpenLog();
    if (SUCCEEDED(CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED))) {
        ApplyLayout();
        CoUninitialize();
    }
    if (g_log) {
        fclose(g_log);
        g_log = nullptr;
    }
    return 0;
}

static void StartWorker() {
    if (g_thread) {
        WaitForSingleObject(g_thread, INFINITE);
        CloseHandle(g_thread);
    }
    g_stop = false;
    g_thread = CreateThread(nullptr, 0, Worker, nullptr, 0, nullptr);
}

BOOL Wh_ModInit() {
    return TRUE;
}

void Wh_ModAfterInit() {
    StartWorker();
}

void Wh_ModSettingsChanged() {
    StartWorker();
}

void Wh_ModUninit() {
    g_stop = true;
    if (g_thread) {
        WaitForSingleObject(g_thread, INFINITE);
        CloseHandle(g_thread);
        g_thread = nullptr;
    }
}
