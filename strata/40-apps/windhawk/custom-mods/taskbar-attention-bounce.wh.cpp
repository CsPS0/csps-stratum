// ==WindhawkMod==
// @id              taskbar-attention-bounce
// @name            Taskbar Attention Bounce
// @description     Bounces a taskbar icon like the macOS Dock while its app asks for attention
// @version         1.0
// @author          CsPS
// @include         explorer.exe
// @architecture    x86-64
// @compilerOptions -lole32 -loleaut32 -lruntimeobject
// ==/WindhawkMod==

// ==WindhawkModReadme==
/*
# Taskbar Attention Bounce

When an app asks for attention (a new message, a prompt, a finished download: the
taskbar button Windows would otherwise just turn orange), its icon keeps hopping
like on the macOS Dock until you switch to the app.

- Works with Windows 11's own taskbar and with "Taskbar Dock Animation": the hop
  uses the icon's composition translation, not its render transform, so the two
  don't fight over the icon.
- Settings: how high the icon jumps and how long one hop cycle takes.

Windows 11 only.
*/
// ==/WindhawkModReadme==

// ==WindhawkModSettings==
/*
- height: 12
  $name: Bounce height (px)
  $description: How far the icon jumps up on the first hop.
- period: 1600
  $name: Cycle length (ms)
  $description: One hop, a smaller hop and a pause.
*/
// ==/WindhawkModSettings==

#include <windhawk_utils.h>

#undef GetCurrentTime  // windows.h macro clashes with the XAML animation headers

#include <winrt/Windows.Foundation.h>
#include <winrt/Windows.Foundation.Collections.h>
#include <winrt/Windows.Foundation.Numerics.h>
#include <winrt/Windows.UI.Composition.h>
#include <winrt/Windows.UI.Xaml.h>
#include <winrt/Windows.UI.Xaml.Controls.h>
#include <winrt/Windows.UI.Xaml.Hosting.h>
#include <winrt/Windows.UI.Xaml.Media.h>

#include <atomic>
#include <chrono>
#include <mutex>
#include <unordered_map>

namespace wux = winrt::Windows::UI::Xaml;
namespace wuxm = winrt::Windows::UI::Xaml::Media;
namespace wuc = winrt::Windows::UI::Composition;
using wux::Hosting::ElementCompositionPreview;

struct {
    float height;
    int period;
} g_settings;

std::atomic<bool> g_unloading{false};
std::atomic<bool> g_taskbarViewDllLoaded{false};

// Icons that are bouncing right now, keyed by their ABI pointer (UI thread only).
std::unordered_map<void*, winrt::weak_ref<wux::FrameworkElement>> g_bouncing;

void LoadSettings() {
    int h = Wh_GetIntSetting(L"height");
    int p = Wh_GetIntSetting(L"period");
    g_settings.height = (float)(h < 2 ? 2 : h > 40 ? 40 : h);
    g_settings.period = p < 600 ? 600 : p > 5000 ? 5000 : p;
}

wux::FrameworkElement ElementFromThis(void* pThis) {
    winrt::Windows::Foundation::IUnknown unknown;
    winrt::copy_from_abi(unknown, (void**)pThis + 3);
    return unknown.try_as<wux::FrameworkElement>();
}

// Depth-first search for a descendant matching pred.
template <typename Pred>
wux::FrameworkElement FindDescendant(wux::DependencyObject const& root, Pred pred, int depth = 0) {
    if (depth > 8) return nullptr;
    int n = wuxm::VisualTreeHelper::GetChildrenCount(root);
    for (int i = 0; i < n; i++) {
        auto child = wuxm::VisualTreeHelper::GetChild(root, i);
        if (auto fe = child.try_as<wux::FrameworkElement>()) {
            if (pred(fe)) return fe;
        }
        if (auto found = FindDescendant(child, pred, depth + 1)) return found;
    }
    return nullptr;
}

bool IsRequestingAttention(wux::FrameworkElement const& button) {
    bool attention = false;
    FindDescendant(button, [&](wux::FrameworkElement const& fe) {
        for (auto group : wux::VisualStateManager::GetVisualStateGroups(fe)) {
            if (group.Name() != L"RunningIndicatorStates") continue;
            if (auto state = group.CurrentState()) {
                attention = state.Name() == L"RequestingAttentionRunningIndicator";
            }
            return true;  // found the group, stop searching
        }
        return false;
    });
    return attention;
}

wux::FrameworkElement FindIcon(wux::FrameworkElement const& button) {
    return FindDescendant(button, [](wux::FrameworkElement const& fe) {
        return fe.Name() == L"Icon" && fe.try_as<wux::Controls::Image>() != nullptr;
    });
}

void StartBounce(wux::FrameworkElement const& icon) {
    ElementCompositionPreview::SetIsTranslationEnabled(icon, true);
    auto visual = ElementCompositionPreview::GetElementVisual(icon);
    auto compositor = visual.Compositor();

    auto up = compositor.CreateCubicBezierEasingFunction({0.2f, 0.0f}, {0.4f, 1.0f});
    auto down = compositor.CreateCubicBezierEasingFunction({0.6f, 0.0f}, {0.8f, 1.0f});
    float h = g_settings.height;

    auto anim = compositor.CreateScalarKeyFrameAnimation();
    anim.InsertKeyFrame(0.00f, 0.0f);
    anim.InsertKeyFrame(0.17f, -h, up);
    anim.InsertKeyFrame(0.34f, 0.0f, down);
    anim.InsertKeyFrame(0.45f, -h * 0.45f, up);
    anim.InsertKeyFrame(0.56f, 0.0f, down);
    anim.InsertKeyFrame(1.00f, 0.0f);
    anim.Duration(std::chrono::milliseconds(g_settings.period));
    anim.IterationBehavior(wuc::AnimationIterationBehavior::Forever);
    visual.StartAnimation(L"Translation.Y", anim);
}

void StopBounce(wux::FrameworkElement const& icon) {
    auto visual = ElementCompositionPreview::GetElementVisual(icon);
    visual.StopAnimation(L"Translation.Y");
    visual.Properties().InsertVector3(L"Translation", {0.0f, 0.0f, 0.0f});
}

// Runs after every TaskListButton::UpdateVisualStates, on the taskbar's UI thread.
void OnButtonUpdated(void* pThis) {
    if (g_unloading) return;
    try {
        auto button = ElementFromThis(pThis);
        if (!button) return;
        auto icon = FindIcon(button);
        if (!icon) return;
        void* key = winrt::get_abi(icon);
        bool attention = IsRequestingAttention(button);
        bool bouncing = g_bouncing.count(key) > 0;
        if (attention && !bouncing) {
            StartBounce(icon);
            g_bouncing[key] = winrt::make_weak(icon);
        } else if (!attention && bouncing) {
            StopBounce(icon);
            g_bouncing.erase(key);
        }
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

void StopAllBounces(void*) {
    for (auto& [key, weak] : g_bouncing) {
        try {
            if (auto icon = weak.get()) StopBounce(icon);
        } catch (...) {
        }
    }
    g_bouncing.clear();
}

BOOL Wh_ModInit() {
    LoadSettings();
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
        RunFromWindowThread(taskbar, StopAllBounces, nullptr);
    }
}

void Wh_ModSettingsChanged() {
    LoadSettings();
    // Restart running bounces with the new height and speed on their next update.
    if (HWND taskbar = FindWindow(L"Shell_TrayWnd", nullptr)) {
        RunFromWindowThread(taskbar, StopAllBounces, nullptr);
    }
}
