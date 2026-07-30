# Windows system-wide hotkeys

Voice input can be driven from the keyboard while another application owns
keyboard focus, so a call does not have to be brought to the foreground to start
an utterance, send it, or interrupt the assistant. Every combination is assigned
by the user; the app ships no default binding and recommends no particular key.

Windows is the only platform that implements this today. `GlobalHotkeyService`
reports `isSupportedPlatform == false` elsewhere, and the settings section is
hidden there rather than being shown as inert.

## Why RegisterHotKey

`RegisterHotKey` is the OS hotkey table. The app names the combinations it wants
and Windows delivers `WM_HOTKEY` only for those.

The alternatives were rejected:

- A low-level keyboard hook (`WH_KEYBOARD_LL`) receives *every* keystroke on the
  desktop, including passwords typed into other applications. That is the shape
  of a keylogger, it drags the whole desktop's input latency through this
  process, and it interferes with IME composition. A feature that needs five
  combinations does not justify reading everything.
- `GetAsyncKeyState` polling as the primary mechanism would mean scanning the
  keyboard continuously whether or not the user pressed anything, and it cannot
  tell which application the keystroke was meant for.
- UI Automation and the accessibility APIs address a different problem; they do
  not offer a hotkey contract.

`RegisterHotKey` also gives honest conflict behavior: if another application
already owns a combination, registration fails instead of silently stealing the
key. That failure is surfaced to the user (see below) rather than leaving a
shortcut that quietly does nothing.

## Release tracking for hold-to-talk

`RegisterHotKey` reports presses only, and hold-to-talk needs the release to know
when the utterance ended. While a release-tracking hotkey is held,
`GlobalHotkeyManager` runs a 25 ms timer that checks that one hotkey's keys with
`GetAsyncKeyState`; the release is reported when the primary key or any required
modifier goes up. The timer exists only between the press and the release of a
hotkey that was already delivered to this app, so no other key is ever observed.

Hotkeys are registered with `MOD_NOREPEAT`, so holding a key produces one press
rather than a stream of them.

## Lifetime

Hotkeys are registered while the call screen is mounted and released when it is
disposed. Outside a call the combinations belong to the rest of the system again,
which keeps the window in which this app can shadow another application's
shortcut as narrow as the feature allows.

The settings screen registers the saved set briefly when it opens and after each
change, purely to find out which combinations the OS refuses, then releases them
again.

## Wire protocol

Channel `app.aoki.yuki.vagina/global_hotkeys`, standard method codec.

Dart to platform:

| Method | Arguments | Result |
| --- | --- | --- |
| `setHotkeys` | list of `{id, virtualKeyCode, modifiers, tracksRelease}` | list of `id`s the OS refused |
| `clearHotkeys` | none | none |

`id` is the `GlobalHotkeyAction` name, `virtualKeyCode` is a Win32 `VK_*` value,
and `modifiers` is a combined `MOD_*` mask. `setHotkeys` replaces the whole set;
a rejected entry does not prevent its siblings from registering.

Platform to Dart, with the `id` as the sole argument:

| Method | Meaning |
| --- | --- |
| `onHotkeyPressed` | the combination was pressed |
| `onHotkeyReleased` | a `tracksRelease` combination was released |

## Actions

| Action | Behavior |
| --- | --- |
| `pushToTalk` | records while held, sends on release |
| `pushToTalkToggle` | first press starts recording, next press sends |
| `cancelInput` | discards the turn being recorded |
| `interrupt` | interrupts assistant playback |
| `muteToggle` | toggles the microphone mute state |

The three input actions act on a manual audio turn, which only exists in
push-to-talk mode; in hands-free mode the microphone is already open and a press
is ignored. `interrupt` and `muteToggle` apply in both modes.

## Bare keys

A combination with no modifier registers, but it takes that key away from every
other application for as long as the call lasts. Settings records it and warns,
rather than refusing: which key is worth that trade is the user's call. A bare
modifier press is not a valid hotkey at all — `RegisterHotKey` needs a
non-modifier primary key — so the recorder keeps waiting until a usable key
arrives.
