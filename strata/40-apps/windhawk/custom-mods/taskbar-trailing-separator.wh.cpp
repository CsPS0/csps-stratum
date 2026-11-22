// ==WindhawkMod==
// @id              taskbar-trailing-separator
// @name            Taskbar Trailing Separator
// @description     Shows the last "Taskbar Icon Separators" separator only while an unpinned app is open
// @version         1.0
// @author          CsPS
// @include         explorer.exe
// @architecture    x86-64
// @compilerOptions -lole32 -loleaut32 -lruntimeobject
// ==/WindhawkMod==

// ==WindhawkModReadme==
/*
# Taskbar Trailing Separator

Like the macOS Dock's divider before recent apps: the last separator (from "Taskbar
Icon Separators") is hidden while nothing follows it, and appears as soon as an app
that isn't pinned is open (Windows always puts those after the pinned ones).

The hidden separator keeps its place in the taskbar's layout but takes no room
(opacity 0, a negative right margin of its own width, no hit testing), so the mod
can still tell what comes after it. The separator mod keeps managing its width and
position. Windows 11 only.
*/
// ==/WindhawkModReadme==

#include <windhawk_utils.h>

#undef GetCurrentTime  // windows.h macro clashes with the XAML animation headers

#include <winrt/Windows.Foundation.h>
#include <winrt/Windows.UI.Xaml.h>
#include <winrt/Windows.UI.Xaml.Automation.h>
#include <winrt/Windows.UI.Xaml.Media.h>

#include <atomic>
#include <string>
#include <unordered_map>
#include <vector>

namespace wux = winrt::Windows::UI::Xaml;
namespace wuxm = winrt::Windows::UI::Xaml::Media;

std::atomic<bool> g_unloading{false};
std::atomic<bool> g_taskbarViewDllLoaded{false};

// UI thread only: separators this mod hid (with what to restore), and the lists it listens to.
struct Hidden {
    winrt::weak_ref<wux::FrameworkElement> element;
    double opacity;
    wux::Thickness margin;
    bool hitTest;
};
std::unordered_map<void*, Hidden> g_hidden;
struct Watched {
    winrt::weak_ref<wux::FrameworkElement> repeater;
    winrt::event_token token;
};
std::unordered_map<void*, Watched> g_repeaters;
bool g_evaluating = false;

wux::FrameworkElement ElementFromThis(void* pThis) {
    winrt::Windows::Foundation::IUnknown unknown;
    winrt::copy_from_abi(unknown, (void**)pThis + 3);
    return unknown.try_as<wux::FrameworkElement>();
}

bool IsTaskButton(wux::FrameworkElement const& e) {
    return winrt::get_class_name(e) == L"Taskbar.TaskListButton";
}

bool IsSeparator(wux::FrameworkElement const& e) {
    std::wstring id{wux::Automation::AutomationProperties::GetAutomationId(e)};
    return id.find(L"WindhawkSeparator") != std::wstring::npos;
}

void Restore(Hidden const& h, wux::FrameworkElement const& e) {
    e.Opacity(h.opacity);
    e.Margin(h.margin);
    e.IsHitTestVisible(h.hitTest);
}

void Show(wux::FrameworkElement const& e) {
    auto it = g_hidden.find(winrt::get_abi(e));
    if (it == g_hidden.end()) return;
    Restore(it->second, e);
    g_hidden.erase(it);
}

void Hide(wux::FrameworkElement const& e) {
    void* key = winrt::get_abi(e);
    if (g_hidden.count(key)) return;
    g_hidden[key] = {winrt::make_weak(e), e.Opacity(), e.Margin(), e.IsHitTestVisible()};
    auto m = e.Margin();
    m.Right -= e.ActualWidth();  // the next button moves over it: no gap
    e.Margin(m);
    e.Opacity(0);
    e.IsHitTestVisible(false);
}

// Hide the last separator while no visible app button comes after it. Order comes from each
// button's position in the list; a hidden separator keeps its position (see Hide), and the
// button after it starts at the same x, so "after" means x >= the separator's x.
void Evaluate(wux::FrameworkElement const& repeater) {
    if (g_unloading || g_evaluating) return;
    g_evaluating = true;
    try {
        struct Item {
            wux::FrameworkElement element{nullptr};
            float x;
            bool separator;
        };
        std::vector<Item> items;
        int n = wuxm::VisualTreeHelper::GetChildrenCount(repeater);
        for (int i = 0; i < n; i++) {
            auto fe = wuxm::VisualTreeHelper::GetChild(repeater, i).try_as<wux::FrameworkElement>();
            if (!fe || !IsTaskButton(fe)) continue;
            if (fe.Visibility() != wux::Visibility::Visible) {
                Show(fe);  // a recycled or collapsed container: never leave it hidden by us
                continue;
            }
            items.push_back({fe, fe.ActualOffset().x, IsSeparator(fe)});
        }

        const Item* last = nullptr;
        for (auto& it : items)
            if (it.separator && (!last || it.x > last->x)) last = &it;

        bool anythingAfter = false;
        if (last) {
            for (auto& it : items) {
                if (&it != last && !it.separator && it.x >= last->x - 0.5f) {
                    anythingAfter = true;
                    break;
                }
            }
        }

        for (auto& it : items) {
            if (last && &it == last && !anythingAfter) Hide(it.element);
            else Show(it.element);
        }
    } catch (...) {
    }
    g_evaluating = false;
}

void Watch(wux::FrameworkElement const& repeater) {
    void* key = winrt::get_abi(repeater);
    if (g_repeaters.count(key)) return;
    winrt::weak_ref<wux::FrameworkElement> weak = repeater;
    auto token = repeater.LayoutUpdated([weak](auto const&, auto const&) {
        if (auto r = weak.get()) Evaluate(r);
    });
    g_repeaters[key] = {weak, token};
}

void OnButtonUpdated(void* pThis) {
    if (g_unloading) return;
    try {
        auto button = ElementFromThis(pThis);
        if (!button) return;
        auto parent = wuxm::VisualTreeHelper::GetParent(button);
        auto repeater = parent ? parent.try_as<wux::FrameworkElement>() : nullptr;
        if (!repeater || winrt::get_class_name(repeater) != L"Microsoft.UI.Xaml.Controls.ItemsRepeater") return;
        Watch(repeater);
        Evaluate(repeater);
    } catch (...) {
    }
}

using VoidMethod_t = void(WINAPI*)(void* pThis);
VoidMethod_t TaskListButton_UpdateVisualStates_Original;
void WINAPI TaskListButton_UpdateVisualStates_Hook(void* pThis) {
    TaskListButton_UpdateVisualStates_Original(pThis);
    OnButtonUpdated(pThis);
}

HMODULE GetTaskbarViewModuleHandle() {
    HMODULE module = GetModuleHandle(L"Taskbar.View.dll");
    if (!module) module = GetModuleHandle(L"ExplorerExtensions.dll");
    return module;
}

bool HookTaskbarViewDllSymbols(HMODULE module) {
    WindhawkUtils::SYMBOL_HOOK hooks[] = {
        {
            {LR"(private: void __cdecl winrt::Taskbar::implementation::TaskListButton::UpdateVisualStates(void))"},
            &TaskListButton_UpdateVisualStates_Original,
            TaskListButton_UpdateVisualStates_Hook,
        },
    };
    if (!WindhawkUtils::HookSymbols(module, hooks, ARRAYSIZE(hooks))) {
        Wh_Log(L"HookSymbols failed");
        return false;
    }
    return true;
}

using LoadLibraryExW_t = decltype(&LoadLibraryExW);
LoadLibraryExW_t LoadLibraryExW_Original;
HMODULE WINAPI LoadLibraryExW_Hook(LPCWSTR name, HANDLE file, DWORD flags) {
    HMODULE module = LoadLibraryExW_Original(name, file, flags);
    if (module && !g_taskbarViewDllLoaded && GetTaskbarViewModuleHandle() == module &&
        !g_taskbarViewDllLoaded.exchange(true)) {
        if (HookTaskbarViewDllSymbols(module)) Wh_ApplyHookOperations();
    }
    return module;
}

using RunProc_t = void (*)(void*);
bool RunFromWindowThread(HWND hWnd, RunProc_t proc, void* param) {
    static const UINT msg = RegisterWindowMessage(L"Windhawk_RunFromWindowThread_" WH_MOD_ID);
    struct Call {
        RunProc_t proc;
        void* param;
    };
    DWORD tid = GetWindowThreadProcessId(hWnd, nullptr);
    if (!tid) return false;
    if (tid == GetCurrentThreadId()) {
        proc(param);
        return true;
    }
    HHOOK hook = SetWindowsHookEx(
        WH_CALLWNDPROC,
        [](int code, WPARAM w, LPARAM l) -> LRESULT {
            if (code == HC_ACTION) {
                auto cwp = (const CWPSTRUCT*)l;
                if (cwp->message == msg) {
                    auto c = (Call*)cwp->lParam;
                    c->proc(c->param);
                }
            }
            return CallNextHookEx(nullptr, code, w, l);
        },
        nullptr, tid);
    if (!hook) return false;
    Call c{proc, param};
    SendMessage(hWnd, msg, 0, (LPARAM)&c);
    UnhookWindowsHookEx(hook);
    return true;
}

void RestoreAll(void*) {
    for (auto& [key, w] : g_repeaters) {
        try {
            if (auto r = w.repeater.get()) r.LayoutUpdated(w.token);
        } catch (...) {
        }
    }
    g_repeaters.clear();
    for (auto& [key, h] : g_hidden) {
        try {
            if (auto e = h.element.get()) Restore(h, e);
        } catch (...) {
        }
    }
    g_hidden.clear();
}

BOOL Wh_ModInit() {
    if (HMODULE module = GetTaskbarViewModuleHandle()) {
        g_taskbarViewDllLoaded = true;
        if (!HookTaskbarViewDllSymbols(module)) return FALSE;
    } else {
        auto kernelBase = GetModuleHandle(L"kernelbase.dll");
        auto pLoadLibraryExW = (LoadLibraryExW_t)GetProcAddress(kernelBase, "LoadLibraryExW");
        WindhawkUtils::SetFunctionHook(pLoadLibraryExW, LoadLibraryExW_Hook, &LoadLibraryExW_Original);
    }
    return TRUE;
}

void Wh_ModBeforeUninit() {
    g_unloading = true;
    if (HWND taskbar = FindWindow(L"Shell_TrayWnd", nullptr)) {
        RunFromWindowThread(taskbar, RestoreAll, nullptr);
    }
}
