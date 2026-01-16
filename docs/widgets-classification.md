# Classification rules for migrating [`lib/components`](lib/components:1) to `lib/widgets` and `lib/feat/*`

You requested that we do not blindly move everything to `lib/widgets/`.

This document defines the **classification criteria** and the **proposed destination** for each existing file under [`lib/components`](lib/components:1).

## 1) Classification criteria

### C1. Feature-owned widgets
Move a widget to `lib/feat/<feature>/widgets/` when it is used only by one feature surface.

How we decide “one feature”:
- We use the direct importers list from [`scripts/component-usage-map.pretty.md`](scripts/component-usage-map.pretty.md:1).
- We map importers located under [`lib/screens/<feature>`](lib/screens:1) to that `<feature>`.
- If all importers map to the same feature (after following dependencies), the widget is **feature-owned**.

### C2. Shared widgets
Keep a widget in `lib/widgets/` when it is used by **two or more features**.

### C3. Unused or unclear widgets
If a file has **no importers** (or only a dead barrel file), it is **unused** today.

Proposed handling:
- Keep it temporarily under `lib/widgets/_legacy/` so we do not lose code during the refactor.
- After the refactor compiles and tests pass, we can delete `_legacy/` items that remain unused.

## 2) Proposed classification for each file

Source data: [`scripts/component-usage-map.pretty.md`](scripts/component-usage-map.pretty.md:1)

### 2.1 Shared widgets (go to `lib/widgets/`)

| Current | Target | Rename | Notes |
|---|---|---|---|
| [`lib/components/adaptive_widgets.dart`](lib/components/adaptive_widgets.dart:1) | [`lib/widgets/adaptive_widgets.dart`](lib/widgets/adaptive_widgets.dart:1) | none | Used across session + settings (and likely more), so shared |
| [`lib/components/chat_bubble.dart`](lib/components/chat_bubble.dart:1) | [`lib/widgets/chat_bubble.dart`](lib/widgets/chat_bubble.dart:1) | none | Used by call chat + session historical chat via [`HistoricalChatView`](lib/components/historical_chat_view.dart:1) |
| [`lib/components/tool_details_sheet.dart`](lib/components/tool_details_sheet.dart:1) | [`lib/widgets/tool_details_sheet.dart`](lib/widgets/tool_details_sheet.dart:1) | none | Used by [`ChatBubble`](lib/components/chat_bubble.dart:1), so keep with it |

### 2.2 Call feature widgets (go to `lib/feat/call/widgets/`)

| Current | Target | Rename | Notes |
|---|---|---|---|
| [`lib/components/audio_level_visualizer.dart`](lib/components/audio_level_visualizer.dart:1) | [`lib/feat/call/widgets/audio_level_visualizer.dart`](lib/feat/call/widgets/audio_level_visualizer.dart:1) | none | Used by call UI only via [`CallMainContent`](lib/components/call_main_content.dart:1) |
| [`lib/components/call_main_content.dart`](lib/components/call_main_content.dart:1) | [`lib/feat/call/widgets/call_main_content.dart`](lib/feat/call/widgets/call_main_content.dart:1) | none | Call-only extraction already implied by file comment |
| [`lib/components/control_button.dart`](lib/components/control_button.dart:1) | [`lib/feat/call/widgets/control_button.dart`](lib/feat/call/widgets/control_button.dart:1) | none | Used by call control panel |
| [`lib/components/control_panel.dart`](lib/components/control_panel.dart:1) | [`lib/feat/call/widgets/control_panel.dart`](lib/feat/call/widgets/control_panel.dart:1) | none | Call-only |
| [`lib/components/chat_empty_state.dart`](lib/components/chat_empty_state.dart:1) | [`lib/feat/call/widgets/chat_empty_state.dart`](lib/feat/call/widgets/chat_empty_state.dart:1) | none | Call chat pane only today |
| [`lib/components/chat_input.dart`](lib/components/chat_input.dart:1) | [`lib/feat/call/widgets/chat_input.dart`](lib/feat/call/widgets/chat_input.dart:1) | none | Call chat pane only today |
| [`lib/components/notepad_action_bar.dart`](lib/components/notepad_action_bar.dart:1) | [`lib/feat/call/widgets/notepad_action_bar.dart`](lib/feat/call/widgets/notepad_action_bar.dart:1) | none | Used by notepad pane |
| [`lib/components/notepad_content_renderer.dart`](lib/components/notepad_content_renderer.dart:1) | [`lib/feat/call/widgets/notepad_content_renderer.dart`](lib/feat/call/widgets/notepad_content_renderer.dart:1) | none | Used by notepad pane |
| [`lib/components/notepad_empty_state.dart`](lib/components/notepad_empty_state.dart:1) | [`lib/feat/call/widgets/notepad_empty_state.dart`](lib/feat/call/widgets/notepad_empty_state.dart:1) | none | Used by notepad pane |
| [`lib/components/notepad_html_content.dart`](lib/components/notepad_html_content.dart:1) | [`lib/feat/call/widgets/notepad_html_content.dart`](lib/feat/call/widgets/notepad_html_content.dart:1) | none | Notepad renderer dependency |
| [`lib/components/notepad_markdown_content.dart`](lib/components/notepad_markdown_content.dart:1) | [`lib/feat/call/widgets/notepad_markdown_content.dart`](lib/feat/call/widgets/notepad_markdown_content.dart:1) | none | Notepad renderer dependency |
| [`lib/components/notepad_plain_text_content.dart`](lib/components/notepad_plain_text_content.dart:1) | [`lib/feat/call/widgets/notepad_plain_text_content.dart`](lib/feat/call/widgets/notepad_plain_text_content.dart:1) | none | Notepad renderer dependency |

### 2.3 Session feature widgets (go to `lib/feat/session/widgets/`)

These are used by session surfaces (including session segments). They remain in `widgets/` because they are non-surface building blocks.

| Current | Target | Rename | Notes |
|---|---|---|---|
| [`lib/components/historical_chat_view.dart`](lib/components/historical_chat_view.dart:1) | [`lib/feat/session/widgets/historical_chat_view.dart`](lib/feat/session/widgets/historical_chat_view.dart:1) | none | Used by `SessionDetail*Segment` surfaces |
| [`lib/components/historical_notepad_view.dart`](lib/components/historical_notepad_view.dart:1) | [`lib/feat/session/widgets/historical_notepad_view.dart`](lib/feat/session/widgets/historical_notepad_view.dart:1) | none | Used by `SessionDetail*Segment` surfaces |

### 2.4 OOBE feature widgets (go to `lib/feat/oobe/widgets/`)

| Current | Target | Rename | Notes |
|---|---|---|---|
| [`lib/components/oobe_background.dart`](lib/components/oobe_background.dart:1) | [`lib/feat/oobe/widgets/oobe_background.dart`](lib/feat/oobe/widgets/oobe_background.dart:1) | none | Used by [`OOBEFlow`](lib/screens/oobe/oobe_flow.dart:13) |
| [`lib/components/permission_card.dart`](lib/components/permission_card.dart:1) | [`lib/feat/oobe/widgets/permission_card.dart`](lib/feat/oobe/widgets/permission_card.dart:1) | none | Used only by OOBE screens |

### 2.5 Settings feature widgets (go to `lib/feat/settings/widgets/`)

| Current | Target | Rename | Notes |
|---|---|---|---|
| [`lib/components/settings_card.dart`](lib/components/settings_card.dart:1) | [`lib/feat/settings/widgets/settings_card.dart`](lib/feat/settings/widgets/settings_card.dart:1) | none | Used inside settings-only sections and [`SettingsScreen`](lib/screens/settings/settings_screen.dart:14) |
| [`lib/components/settings/android_audio_section.dart`](lib/components/settings/android_audio_section.dart:1) | [`lib/feat/settings/widgets/android_audio_section.dart`](lib/feat/settings/widgets/android_audio_section.dart:1) | none | Settings only |
| [`lib/components/settings/azure_config_section.dart`](lib/components/settings/azure_config_section.dart:1) | [`lib/feat/settings/widgets/azure_config_section.dart`](lib/feat/settings/widgets/azure_config_section.dart:1) | none | Settings only |
| [`lib/components/settings/developer_section.dart`](lib/components/settings/developer_section.dart:1) | [`lib/feat/settings/widgets/developer_section.dart`](lib/feat/settings/widgets/developer_section.dart:1) | none | Settings only |
| [`lib/components/settings/ui_preferences_section.dart`](lib/components/settings/ui_preferences_section.dart:1) | [`lib/feat/settings/widgets/ui_preferences_section.dart`](lib/feat/settings/widgets/ui_preferences_section.dart:1) | none | Settings only |
| [`lib/components/settings/voice_settings_section.dart`](lib/components/settings/voice_settings_section.dart:1) | [`lib/feat/settings/widgets/voice_settings_section.dart`](lib/feat/settings/widgets/voice_settings_section.dart:1) | none | Settings only |

### 2.6 About feature widgets (go to `lib/feat/about/widgets/`)

| Current | Target | Rename | Notes |
|---|---|---|---|
| [`lib/components/constellation_painter.dart`](lib/components/constellation_painter.dart:1) | [`lib/feat/about/widgets/constellation_painter.dart`](lib/feat/about/widgets/constellation_painter.dart:1) | none | Used only by [`ConstellationGame`](lib/screens/about/constellation_game.dart:8) |

### 2.7 Speed dial feature widgets (go to `lib/feat/speed_dial/widgets/`)

| Current | Target | Rename | Notes |
|---|---|---|---|
| [`lib/components/emoji_picker.dart`](lib/components/emoji_picker.dart:1) | [`lib/feat/speed_dial/widgets/emoji_picker.dart`](lib/feat/speed_dial/widgets/emoji_picker.dart:1) | none | Used only by [`SpeedDialConfigScreen`](lib/screens/speed_dial/speed_dial_config_screen.dart:11) |

### 2.8 Legacy or unused (go to `lib/widgets/_legacy/` temporarily)

These have no real importers today or only depend on the unused barrel file.

| Current | Target | Rename | Notes |
|---|---|---|---|
| [`lib/components/components.dart`](lib/components/components.dart:1) | [`lib/widgets/_legacy/widgets.dart`](lib/widgets/_legacy/widgets.dart:1) | none | Appears unused in the codebase; likely safe to delete later |
| [`lib/components/circular_icon_button.dart`](lib/components/circular_icon_button.dart:1) | [`lib/widgets/_legacy/circular_icon_button.dart`](lib/widgets/_legacy/circular_icon_button.dart:1) | none | No importers besides the unused barrel |
| [`lib/components/notepad_edit_button.dart`](lib/components/notepad_edit_button.dart:1) | [`lib/widgets/_legacy/notepad_edit_button.dart`](lib/widgets/_legacy/notepad_edit_button.dart:1) | none | No importers; confirm removal after migration |
| [`lib/components/speed_dial_indicator.dart`](lib/components/speed_dial_indicator.dart:1) | [`lib/widgets/_legacy/speed_dial_indicator.dart`](lib/widgets/_legacy/speed_dial_indicator.dart:1) | none | No importers besides the unused barrel |
| [`lib/components/settings/about_section.dart`](lib/components/settings/about_section.dart:1) | [`lib/widgets/_legacy/about_section.dart`](lib/widgets/_legacy/about_section.dart:1) | none | Not imported by settings screen today |
| [`lib/components/settings/pip_settings_section.dart`](lib/components/settings/pip_settings_section.dart:1) | [`lib/widgets/_legacy/pip_settings_section.dart`](lib/widgets/_legacy/pip_settings_section.dart:1) | none | Not imported by settings screen today |

## 3) Decision needed (confirm before Code mode)

Confirm that you accept these two decisions:

1) `Settings` sections stay feature-owned (moved to `lib/feat/settings/widgets/`), not shared.
2) Unused items go to `lib/widgets/_legacy/` temporarily (not deleted immediately).

Once confirmed, we can switch to implementation and perform:
- Component classification moves + import rewrites
- Then `lib/screens` -> `lib/feat/*` migration per [`docs/ui-migration-table.md`](docs/ui-migration-table.md:1)
