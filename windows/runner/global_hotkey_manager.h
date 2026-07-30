#ifndef RUNNER_GLOBAL_HOTKEY_MANAGER_H_
#define RUNNER_GLOBAL_HOTKEY_MANAGER_H_

#include <windows.h>

#include <functional>
#include <map>
#include <set>
#include <string>
#include <vector>

// Registers system-wide hotkeys with the OS so voice input can be driven while
// another application owns keyboard focus.
//
// Registration goes through RegisterHotKey rather than a low-level keyboard
// hook: the OS delivers only the combinations this app asked for, so keystrokes
// aimed at other applications never reach this process, and a combination
// already owned by another application fails to register instead of being
// silently stolen.
//
// RegisterHotKey reports presses only. Releases are needed for hold-to-talk, so
// while a release-tracking hotkey is down the manager polls that one hotkey's
// keys with GetAsyncKeyState. Nothing else on the keyboard is observed.
class GlobalHotkeyManager {
 public:
  // Reports a hotkey press or release for the caller-supplied hotkey id.
  using EventCallback = std::function<void(const std::string& hotkey_id)>;

  struct Registration {
    std::string id;
    // Win32 MOD_* mask; may be 0 for a bare key.
    UINT modifiers = 0;
    // Win32 VK_* code of the primary key.
    UINT virtual_key_code = 0;
    // Whether the release of this hotkey has to be reported.
    bool tracks_release = false;
  };

  GlobalHotkeyManager(HWND window, EventCallback on_pressed,
                      EventCallback on_released);
  ~GlobalHotkeyManager();

  GlobalHotkeyManager(const GlobalHotkeyManager&) = delete;
  GlobalHotkeyManager& operator=(const GlobalHotkeyManager&) = delete;

  // Replaces every registered hotkey with |registrations|.
  //
  // Returns the ids the OS refused, which is how a conflict with another
  // application surfaces. Accepted hotkeys stay registered even when a sibling
  // registration fails.
  std::vector<std::string> Replace(
      const std::vector<Registration>& registrations);

  // Releases every registered hotkey and stops release tracking.
  //
  // A hotkey that is still held is dropped without reporting its release; the
  // caller is discarding the bindings and owns settling its own state.
  void Clear();

  // Handles WM_HOTKEY and the release-tracking timer.
  //
  // Returns true when |message| was consumed.
  bool HandleWindowMessage(UINT message, WPARAM wparam, LPARAM lparam);

 private:
  struct Hotkey {
    std::string id;
    UINT modifiers = 0;
    UINT virtual_key_code = 0;
    bool tracks_release = false;
  };

  void OnHotkeyPressed(int hotkey_id);
  void PollTrackedReleases();
  bool IsHotkeyStillHeld(const Hotkey& hotkey) const;
  void StartReleasePolling();
  void StopReleasePolling();

  HWND window_ = nullptr;
  EventCallback on_pressed_;
  EventCallback on_released_;

  // Win32 hotkey id -> hotkey. Ids are assigned by this manager.
  std::map<int, Hotkey> hotkeys_;
  // Win32 hotkey ids that are currently held down and awaiting a release.
  std::set<int> held_hotkey_ids_;
  int next_hotkey_id_ = 1;
  bool release_polling_active_ = false;
};

#endif  // RUNNER_GLOBAL_HOTKEY_MANAGER_H_
