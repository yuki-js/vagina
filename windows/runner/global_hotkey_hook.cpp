#include "global_hotkey_hook.h"

#include <atomic>

namespace {

// The binding is packed into a single word so the hook procedure can read it
// whole without taking a lock. Blocking inside a low-level keyboard hook risks
// hitting LowLevelHooksTimeout, after which Windows silently drops the hook.
// Bits 0-15 hold the primary virtual key code, bits 16-19 the required
// modifiers.
constexpr std::uint32_t kPrimaryKeyMask = 0x0000FFFFu;
constexpr std::uint32_t kRequiresControlBit = 1u << 16;
constexpr std::uint32_t kRequiresShiftBit = 1u << 17;
constexpr std::uint32_t kRequiresAltBit = 1u << 18;
constexpr std::uint32_t kRequiresMetaBit = 1u << 19;

// File-scope state shared across all hook instances.
std::atomic<std::uint32_t> g_packed_binding{0};
std::atomic<HWND> g_target_window{nullptr};

// Whether the binding was satisfied the last time it was evaluated. Events are
// only reported on a change of this value.
std::atomic<bool> g_binding_satisfied{false};

std::uint32_t PackBinding(const GlobalHotKeyHook::KeyBinding& binding) {
  std::uint32_t packed = binding.primary_virtual_key_code & kPrimaryKeyMask;
  if (binding.requires_control) {
    packed |= kRequiresControlBit;
  }
  if (binding.requires_shift) {
    packed |= kRequiresShiftBit;
  }
  if (binding.requires_alt) {
    packed |= kRequiresAltBit;
  }
  if (binding.requires_meta) {
    packed |= kRequiresMetaBit;
  }
  return packed;
}

GlobalHotKeyHook::KeyBinding UnpackBinding(std::uint32_t packed) {
  GlobalHotKeyHook::KeyBinding binding;
  binding.primary_virtual_key_code = packed & kPrimaryKeyMask;
  binding.requires_control = (packed & kRequiresControlBit) != 0;
  binding.requires_shift = (packed & kRequiresShiftBit) != 0;
  binding.requires_alt = (packed & kRequiresAltBit) != 0;
  binding.requires_meta = (packed & kRequiresMetaBit) != 0;
  return binding;
}

// Whether one concrete virtual key code is currently held down. The key that
// produced the current hook event is answered from the event itself: the
// asynchronous key state table is not updated until after low-level hooks
// return, so GetAsyncKeyState() still reports the pre-event state for it.
bool IsSpecificKeyHeld(std::uint32_t virtual_key, DWORD event_key,
                       bool event_is_key_up) {
  if (virtual_key == event_key) {
    return !event_is_key_up;
  }
  return (GetAsyncKeyState(static_cast<int>(virtual_key)) & 0x8000) != 0;
}

// Whether |virtual_key| is currently held down. Generic modifier codes resolve
// to their left/right variants, which is what the low-level hook reports.
bool IsKeyHeld(std::uint32_t virtual_key, DWORD event_key,
               bool event_is_key_up) {
  switch (virtual_key) {
    case VK_CONTROL:
      return IsSpecificKeyHeld(VK_LCONTROL, event_key, event_is_key_up) ||
             IsSpecificKeyHeld(VK_RCONTROL, event_key, event_is_key_up);
    case VK_SHIFT:
      return IsSpecificKeyHeld(VK_LSHIFT, event_key, event_is_key_up) ||
             IsSpecificKeyHeld(VK_RSHIFT, event_key, event_is_key_up);
    case VK_MENU:
      return IsSpecificKeyHeld(VK_LMENU, event_key, event_is_key_up) ||
             IsSpecificKeyHeld(VK_RMENU, event_key, event_is_key_up);
    default:
      return IsSpecificKeyHeld(virtual_key, event_key, event_is_key_up);
  }
}

// Reports a release for a binding that is still held while the state backing it
// is torn down or replaced. Without this the listener would keep a "down" that
// never gets its matching "up", leaving the microphone open forever.
void ReleaseHeldBinding() {
  HWND target_window = g_target_window.load();
  if (g_binding_satisfied.exchange(false) && target_window != nullptr) {
    PostMessage(target_window, kHotKeyEventMessage, kHotKeyEventUp, 0);
  }
}

}  // namespace

GlobalHotKeyHook::GlobalHotKeyHook() = default;

GlobalHotKeyHook::~GlobalHotKeyHook() {
  Uninstall();
}

bool GlobalHotKeyHook::Install(HWND target_window) {
  if (target_window == nullptr) {
    return false;
  }

  // Uninstall any existing hook first (reset-before-set pattern). This also
  // releases a binding that is held while the hook is being re-armed, which
  // happens on every call state change.
  Uninstall();

  g_target_window.store(target_window);

  // Install the low-level keyboard hook on the current thread.
  hook_handle_ = SetWindowsHookEx(WH_KEYBOARD_LL, LowLevelKeyboardProc,
                                   nullptr, 0);
  if (hook_handle_ == nullptr) {
    g_target_window.store(nullptr);
    return false;
  }

  return true;
}

void GlobalHotKeyHook::Uninstall() {
  if (hook_handle_ != nullptr) {
    UnhookWindowsHookEx(hook_handle_);
    hook_handle_ = nullptr;
  }

  ReleaseHeldBinding();
  g_target_window.store(nullptr);
}

void GlobalHotKeyHook::SetKeyBinding(const KeyBinding& binding) {
  ReleaseHeldBinding();
  g_packed_binding.store(PackBinding(binding));
}

GlobalHotKeyHook::KeyBinding GlobalHotKeyHook::GetKeyBinding() const {
  return UnpackBinding(g_packed_binding.load());
}

LRESULT CALLBACK GlobalHotKeyHook::LowLevelKeyboardProc(int nCode, WPARAM wParam,
                                                         LPARAM lParam) {
  // nCode < 0 means we must pass through immediately without processing.
  if (nCode < 0) {
    return CallNextHookEx(nullptr, nCode, wParam, lParam);
  }

  // Cast lParam to the hook struct. LLKHF_INJECTED is deliberately ignored so
  // synthesized input is accepted like physical input.
  const KBDLLHOOKSTRUCT* kbd = reinterpret_cast<const KBDLLHOOKSTRUCT*>(lParam);
  if (kbd == nullptr) {
    return CallNextHookEx(nullptr, nCode, wParam, lParam);
  }

  const HWND target_window = g_target_window.load();
  const std::uint32_t packed = g_packed_binding.load();
  const std::uint32_t primary_key = packed & kPrimaryKeyMask;

  // If no target window or no binding is configured, pass through. Both paths
  // that clear this state report the release themselves.
  if (target_window == nullptr || primary_key == 0) {
    return CallNextHookEx(nullptr, nCode, wParam, lParam);
  }

  const DWORD event_key = kbd->vkCode;
  const bool event_is_key_up = (wParam == WM_KEYUP || wParam == WM_SYSKEYUP);

  // Recompute whether the binding holds right now instead of branching on the
  // event being a press or a release, then report only transitions. A single
  // path means the release is still detected when a modifier is let go before
  // the primary key.
  //
  // Which window has the foreground is deliberately not consulted. This hook is
  // the only key route while it is installed, so there is no second reader to
  // stay out of the way of.
  bool is_satisfied = IsKeyHeld(primary_key, event_key, event_is_key_up);

  // Modifiers match as a subset: a required modifier must be held, while a
  // modifier that is not required is never inspected. Requiring absence here
  // would permanently break modifier-only bindings, whose primary key is itself
  // a modifier and which therefore carry no requirements at all.
  if (is_satisfied && (packed & kRequiresControlBit) != 0 &&
      !IsKeyHeld(VK_CONTROL, event_key, event_is_key_up)) {
    is_satisfied = false;
  }
  if (is_satisfied && (packed & kRequiresShiftBit) != 0 &&
      !IsKeyHeld(VK_SHIFT, event_key, event_is_key_up)) {
    is_satisfied = false;
  }
  if (is_satisfied && (packed & kRequiresAltBit) != 0 &&
      !IsKeyHeld(VK_MENU, event_key, event_is_key_up)) {
    is_satisfied = false;
  }
  if (is_satisfied && (packed & kRequiresMetaBit) != 0 &&
      !IsKeyHeld(VK_LWIN, event_key, event_is_key_up) &&
      !IsKeyHeld(VK_RWIN, event_key, event_is_key_up)) {
    is_satisfied = false;
  }

  // Only notify on a state change, which also swallows key auto-repeat. The
  // notification goes out via PostMessage because the hook procedure must
  // return promptly and must not touch the event sink directly.
  if (g_binding_satisfied.exchange(is_satisfied) != is_satisfied) {
    PostMessage(target_window, kHotKeyEventMessage,
                is_satisfied ? kHotKeyEventDown : kHotKeyEventUp, 0);
  }

  // Always pass the key through to other applications/handlers.
  return CallNextHookEx(nullptr, nCode, wParam, lParam);
}
