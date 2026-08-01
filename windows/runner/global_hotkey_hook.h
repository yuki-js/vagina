#ifndef RUNNER_GLOBAL_HOTKEY_HOOK_H_
#define RUNNER_GLOBAL_HOTKEY_HOOK_H_

#include <windows.h>

#include <cstdint>

// Custom window message posted by the low-level keyboard hook whenever the
// global hotkey binding transitions between satisfied and unsatisfied. The
// WM_APP base is 0x8000. |wparam| carries kHotKeyEventDown or kHotKeyEventUp.
constexpr UINT kHotKeyEventMessage = WM_APP + 1;
constexpr WPARAM kHotKeyEventDown = 1;
constexpr WPARAM kHotKeyEventUp = 0;

// Manages a global low-level keyboard hook for PTT (Push-to-Talk) functionality.
// Provides a safe, lightweight interface for registering a single hotkey
// binding. Only one binding is tracked process-wide.
class GlobalHotKeyHook {
 public:
  // Represents the key binding configuration.
  //
  // The requires_* flags follow subset-matching semantics, mirroring
  // PushToTalkKeyBinding.matchesPressedKeys on the Dart side: true means the
  // modifier must be held, false means the modifier is not inspected at all
  // (it is "don't care", not "must not be held"). This is what keeps a
  // modifier-only binding such as "Left Ctrl" — which carries no required
  // modifiers — able to fire.
  struct KeyBinding {
    // Win32 virtual key code (e.g., VK_SPACE = 0x20).
    std::uint32_t primary_virtual_key_code = 0;
    // Modifier flags: whether Ctrl must be pressed.
    bool requires_control = false;
    // Whether Shift must be pressed.
    bool requires_shift = false;
    // Whether Alt must be pressed.
    bool requires_alt = false;
    // Whether Windows key must be pressed.
    bool requires_meta = false;
  };

  GlobalHotKeyHook();
  ~GlobalHotKeyHook();

  // Install the low-level keyboard hook. Must be called with the HWND of the
  // window that will receive hotkey events. Calling Install() when a hook is
  // already installed will uninstall the old hook first, then install the new
  // one (reset-before-set pattern for robustness).
  //
  // Returns true if the hook was successfully installed, false otherwise.
  bool Install(HWND target_window);

  // Uninstall the keyboard hook. Safe to call multiple times. If the binding is
  // currently held down, a release is reported before the hook goes away so the
  // listener never keeps a "down" without its matching "up".
  void Uninstall();

  // Set the key binding to match. Calling this updates the active binding that
  // the hook will check against. If the previous binding is currently held
  // down, a release is reported before the new binding takes over. Thread-safe.
  void SetKeyBinding(const KeyBinding& binding);

  // Get the current key binding. Thread-safe.
  KeyBinding GetKeyBinding() const;

 private:
  // Static hook procedure. Matches the WH_KEYBOARD_LL callback signature.
  static LRESULT CALLBACK LowLevelKeyboardProc(int nCode, WPARAM wParam,
                                                LPARAM lParam);

  // Instance hook handle.
  HHOOK hook_handle_ = nullptr;
};

#endif  // RUNNER_GLOBAL_HOTKEY_HOOK_H_
