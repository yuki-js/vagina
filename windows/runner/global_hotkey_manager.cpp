#include "global_hotkey_manager.h"

#include <utility>

// Available since Windows 7; defined here so the runner also builds against an
// SDK configured for an older target.
#ifndef MOD_NOREPEAT
#define MOD_NOREPEAT 0x4000
#endif

namespace {

// Timer used to detect the release of a hold-to-talk hotkey. The value only has
// to be unique among the timers of the runner window.
constexpr UINT_PTR kReleasePollTimerId = 0x5647484B;

// Poll interval while a release-tracking hotkey is held. Short enough that the
// end of an utterance is not clipped, long enough to stay free.
constexpr UINT kReleasePollIntervalMs = 25;

// Highest hotkey id an application may pass to RegisterHotKey.
constexpr int kMaxHotkeyId = 0xBFFF;

bool IsKeyDown(UINT virtual_key_code) {
  return (::GetAsyncKeyState(static_cast<int>(virtual_key_code)) & 0x8000) != 0;
}

}  // namespace

GlobalHotkeyManager::GlobalHotkeyManager(HWND window, EventCallback on_pressed,
                                         EventCallback on_released)
    : window_(window),
      on_pressed_(std::move(on_pressed)),
      on_released_(std::move(on_released)) {}

GlobalHotkeyManager::~GlobalHotkeyManager() { Clear(); }

std::vector<std::string> GlobalHotkeyManager::Replace(
    const std::vector<Registration>& registrations) {
  Clear();

  std::vector<std::string> rejected_ids;
  for (const Registration& registration : registrations) {
    if (registration.virtual_key_code == 0) {
      rejected_ids.push_back(registration.id);
      continue;
    }
    if (next_hotkey_id_ > kMaxHotkeyId) {
      rejected_ids.push_back(registration.id);
      continue;
    }

    const int hotkey_id = next_hotkey_id_;
    // MOD_NOREPEAT keeps a held key from producing a stream of presses, so a
    // press maps to exactly one WM_HOTKEY for both toggle and hold actions.
    if (!::RegisterHotKey(window_, hotkey_id,
                          registration.modifiers | MOD_NOREPEAT,
                          registration.virtual_key_code)) {
      rejected_ids.push_back(registration.id);
      continue;
    }

    next_hotkey_id_++;
    Hotkey hotkey;
    hotkey.id = registration.id;
    hotkey.modifiers = registration.modifiers;
    hotkey.virtual_key_code = registration.virtual_key_code;
    hotkey.tracks_release = registration.tracks_release;
    hotkeys_[hotkey_id] = std::move(hotkey);
  }

  return rejected_ids;
}

void GlobalHotkeyManager::Clear() {
  StopReleasePolling();
  held_hotkey_ids_.clear();
  for (const auto& entry : hotkeys_) {
    ::UnregisterHotKey(window_, entry.first);
  }
  hotkeys_.clear();
  next_hotkey_id_ = 1;
}

bool GlobalHotkeyManager::HandleWindowMessage(UINT message, WPARAM wparam,
                                              LPARAM lparam) {
  switch (message) {
    case WM_HOTKEY:
      OnHotkeyPressed(static_cast<int>(wparam));
      return true;
    case WM_TIMER:
      if (wparam == kReleasePollTimerId) {
        PollTrackedReleases();
        return true;
      }
      return false;
    default:
      return false;
  }
}

void GlobalHotkeyManager::OnHotkeyPressed(int hotkey_id) {
  const auto entry = hotkeys_.find(hotkey_id);
  if (entry == hotkeys_.end()) {
    return;
  }

  if (entry->second.tracks_release) {
    held_hotkey_ids_.insert(hotkey_id);
    StartReleasePolling();
  }

  if (on_pressed_) {
    on_pressed_(entry->second.id);
  }
}

void GlobalHotkeyManager::PollTrackedReleases() {
  std::vector<std::string> released_ids;
  for (auto held = held_hotkey_ids_.begin(); held != held_hotkey_ids_.end();) {
    const auto entry = hotkeys_.find(*held);
    if (entry == hotkeys_.end()) {
      held = held_hotkey_ids_.erase(held);
      continue;
    }
    if (IsHotkeyStillHeld(entry->second)) {
      ++held;
      continue;
    }

    released_ids.push_back(entry->second.id);
    held = held_hotkey_ids_.erase(held);
  }

  if (held_hotkey_ids_.empty()) {
    StopReleasePolling();
  }

  if (on_released_) {
    for (const std::string& released_id : released_ids) {
      on_released_(released_id);
    }
  }
}

bool GlobalHotkeyManager::IsHotkeyStillHeld(const Hotkey& hotkey) const {
  if (!IsKeyDown(hotkey.virtual_key_code)) {
    return false;
  }
  if ((hotkey.modifiers & MOD_CONTROL) != 0 && !IsKeyDown(VK_CONTROL)) {
    return false;
  }
  if ((hotkey.modifiers & MOD_SHIFT) != 0 && !IsKeyDown(VK_SHIFT)) {
    return false;
  }
  if ((hotkey.modifiers & MOD_ALT) != 0 && !IsKeyDown(VK_MENU)) {
    return false;
  }
  if ((hotkey.modifiers & MOD_WIN) != 0 && !IsKeyDown(VK_LWIN) &&
      !IsKeyDown(VK_RWIN)) {
    return false;
  }
  return true;
}

void GlobalHotkeyManager::StartReleasePolling() {
  if (release_polling_active_) {
    return;
  }
  if (::SetTimer(window_, kReleasePollTimerId, kReleasePollIntervalMs,
                 nullptr) == 0) {
    return;
  }
  release_polling_active_ = true;
}

void GlobalHotkeyManager::StopReleasePolling() {
  if (!release_polling_active_) {
    return;
  }
  ::KillTimer(window_, kReleasePollTimerId);
  release_polling_active_ = false;
}
