# UI File Migration Table (Proposal)

This table reflects the updated naming rules:

- Route/app destinations: `*Screen` in `.../screens/`
- Tab surfaces: `*Tab` in `.../tabs/`
- Pane surfaces (split / PageView / multi-column): `*Pane` in `.../panes/`
- Segment surfaces (segmented-control but tab-like): `*Segment` in `.../segments/`
- Non-surface UI: `*` in `.../widgets/` (feature-scoped) or shared widgets in `lib/widgets/`
- Files under `.../screens/` do **not** need `_screen` in the file name

Path note:
- Feature root is `lib/feat/` (not `lib/features/`).

Terminology note:
- I will use **Widget** as the generic term.
- The directory currently named [`lib/components`](../lib/components:1) will be renamed to `lib/widgets/` as part of this refactor.

## 1) Surfaces: Screens / Tabs / Panes / Segments

### 1.1 Home

| Current | Target | Rename | Notes |
|---|---|---|---|
| [`lib/screens/home/home_screen.dart`](../lib/screens/home/home_screen.dart:1) | [`lib/feat/home/screens/home.dart`](../lib/feat/home/screens/home.dart:1) | none | `HomeScreen` is the route surface. It imports tabs from `.../tabs/` |
| [`lib/screens/home/speed_dial_tab.dart`](../lib/screens/home/speed_dial_tab.dart:1) | [`lib/feat/home/tabs/speed_dial.dart`](../lib/feat/home/tabs/speed_dial.dart:1) | none | Keep `SpeedDialTab` |
| [`lib/screens/home/sessions_tab.dart`](../lib/screens/home/sessions_tab.dart:1) | [`lib/feat/home/tabs/sessions.dart`](../lib/feat/home/tabs/sessions.dart:1) | none | Keep `SessionsTab` |
| [`lib/screens/home/tools_tab.dart`](../lib/screens/home/tools_tab.dart:1) | [`lib/feat/home/tabs/tools.dart`](../lib/feat/home/tabs/tools.dart:1) | none | Keep `ToolsTab` |
| [`lib/screens/home/agents_tab.dart`](../lib/screens/home/agents_tab.dart:1) | [`lib/feat/home/tabs/agents.dart`](../lib/feat/home/tabs/agents.dart:1) | none | Keep `AgentsTab` |

### 1.2 Call

| Current | Target | Rename | Notes |
|---|---|---|---|
| [`lib/screens/call/call_screen.dart`](../lib/screens/call/call_screen.dart:1) | [`lib/feat/call/screens/call.dart`](../lib/feat/call/screens/call.dart:1) | none | Stays `CallScreen` |
| [`lib/screens/call/chat_page.dart`](../lib/screens/call/chat_page.dart:1) | [`lib/feat/call/panes/chat.dart`](../lib/feat/call/panes/chat.dart:1) | `ChatPage` -> `ChatPane` | Pane surface (PageView / 3-column) |
| [`lib/screens/call/call_page.dart`](../lib/screens/call/call_page.dart:1) | [`lib/feat/call/panes/call.dart`](../lib/feat/call/panes/call.dart:1) | `CallPage` -> `CallPane` | Center pane surface |
| [`lib/screens/call/notepad_page.dart`](../lib/screens/call/notepad_page.dart:1) | [`lib/feat/call/panes/notepad.dart`](../lib/feat/call/panes/notepad.dart:1) | `NotepadPage` -> `NotepadPane` | Right pane surface |

### 1.3 OOBE

| Current | Target | Rename | Notes |
|---|---|---|---|
| [`lib/screens/oobe/oobe_flow.dart`](../lib/screens/oobe/oobe_flow.dart:1) | [`lib/feat/oobe/screens/oobe_flow.dart`](../lib/feat/oobe/screens/oobe_flow.dart:1) | `OOBEFlow` -> `OobeFlowScreen` | Route-level coordinator surface |
| [`lib/screens/oobe/welcome_screen.dart`](../lib/screens/oobe/welcome_screen.dart:1) | [`lib/feat/oobe/screens/welcome.dart`](../lib/feat/oobe/screens/welcome.dart:1) | none | `WelcomeScreen` stays `*Screen` |
| [`lib/screens/oobe/authentication_screen.dart`](../lib/screens/oobe/authentication_screen.dart:1) | [`lib/feat/oobe/screens/authentication.dart`](../lib/feat/oobe/screens/authentication.dart:1) | none | `AuthenticationScreen` stays `*Screen` (but see extraction for `AuthProvider`) |
| [`lib/screens/oobe/manual_setup_screen.dart`](../lib/screens/oobe/manual_setup_screen.dart:1) | [`lib/feat/oobe/screens/manual_setup.dart`](../lib/feat/oobe/screens/manual_setup.dart:1) | none | `ManualSetupScreen` stays `*Screen` |
| [`lib/screens/oobe/permissions_screen.dart`](../lib/screens/oobe/permissions_screen.dart:1) | [`lib/feat/oobe/screens/permissions.dart`](../lib/feat/oobe/screens/permissions.dart:1) | none | `PermissionsScreen` stays `*Screen` |
| [`lib/screens/oobe/dive_in_screen.dart`](../lib/screens/oobe/dive_in_screen.dart:1) | [`lib/feat/oobe/screens/dive_in.dart`](../lib/feat/oobe/screens/dive_in.dart:1) | none | `DiveInScreen` stays `*Screen` |

### 1.4 Settings

| Current | Target | Rename | Notes |
|---|---|---|---|
| [`lib/screens/settings/settings_screen.dart`](../lib/screens/settings/settings_screen.dart:1) | [`lib/feat/settings/screens/settings.dart`](../lib/feat/settings/screens/settings.dart:1) | none | `SettingsScreen` stays `*Screen` |
| [`lib/screens/settings/log_screen.dart`](../lib/screens/settings/log_screen.dart:1) | [`lib/feat/settings/screens/log.dart`](../lib/feat/settings/screens/log.dart:1) | none | `LogScreen` stays `*Screen` |

### 1.5 Session

| Current | Target | Rename | Notes |
|---|---|---|---|
| [`lib/screens/session/session_detail_screen.dart`](../lib/screens/session/session_detail_screen.dart:1) | [`lib/feat/session/screens/session_detail.dart`](../lib/feat/session/screens/session_detail.dart:1) | none | `SessionDetailScreen` stays `*Screen` |

Segment surfaces (segmented-control but tab-like) created under `lib/feat/session/segments/`:

| Current | Target | Rename | Notes |
|---|---|---|---|
| (part of [`SessionDetailScreen`](../lib/screens/session/session_detail_screen.dart:1)) | [`lib/feat/session/segments/info.dart`](../lib/feat/session/segments/info.dart:1) | `_SessionInfoView` -> `SessionDetailInfoSegment` | Large-scope segmented content treated as surface |
| (part of [`SessionDetailScreen`](../lib/screens/session/session_detail_screen.dart:1)) | [`lib/feat/session/segments/chat.dart`](../lib/feat/session/segments/chat.dart:1) | new: `SessionDetailChatSegment` | Wraps historical chat viewer |
| (part of [`SessionDetailScreen`](../lib/screens/session/session_detail_screen.dart:1)) | [`lib/feat/session/segments/notepad.dart`](../lib/feat/session/segments/notepad.dart:1) | new: `SessionDetailNotepadSegment` | Wraps historical notepad viewer |

### 1.6 Speed dial

| Current | Target | Rename | Notes |
|---|---|---|---|
| [`lib/screens/speed_dial/speed_dial_config_screen.dart`](../lib/screens/speed_dial/speed_dial_config_screen.dart:1) | [`lib/feat/speed_dial/screens/config.dart`](../lib/feat/speed_dial/screens/config.dart:1) | none | `SpeedDialConfigScreen` stays `*Screen` |

### 1.7 About

| Current | Target | Rename | Notes |
|---|---|---|---|
| [`lib/screens/about/about_screen.dart`](../lib/screens/about/about_screen.dart:1) | [`lib/feat/about/screens/about.dart`](../lib/feat/about/screens/about.dart:1) | none | `AboutScreen` stays `*Screen` |
| [`lib/screens/about/constellation_game.dart`](../lib/screens/about/constellation_game.dart:1) | [`lib/feat/about/screens/constellation_game.dart`](../lib/feat/about/screens/constellation_game.dart:1) | `ConstellationGame` -> `ConstellationGameScreen` | Treated as a route-level surface |
| [`lib/screens/about/voice_visualizer_game.dart`](../lib/screens/about/voice_visualizer_game.dart:1) | [`lib/feat/about/screens/voice_visualizer_game.dart`](../lib/feat/about/screens/voice_visualizer_game.dart:1) | `VoiceVisualizerGame` -> `VoiceVisualizerGameScreen` | Treated as a route-level surface; painters extracted |

## 2) Extractions: move non-surface widgets and helper classes out of surfaces

| Extracted from | Target | Rename | Notes |
|---|---|---|---|
| [`_ChatHeader`](../lib/screens/call/chat_page.dart:138) | [`lib/feat/call/widgets/chat_header.dart`](../lib/feat/call/widgets/chat_header.dart:1) | `_ChatHeader` -> `ChatHeader` | Pane imports this widget |
| [`_ScrollToBottomButton`](../lib/screens/call/chat_page.dart:189) | [`lib/feat/call/widgets/scroll_to_bottom_button.dart`](../lib/feat/call/widgets/scroll_to_bottom_button.dart:1) | `_ScrollToBottomButton` -> `ScrollToBottomButton` | Pane imports this widget |
| [`_NotepadHeader`](../lib/screens/call/notepad_page.dart:158) | [`lib/feat/call/widgets/notepad_header.dart`](../lib/feat/call/widgets/notepad_header.dart:1) | `_NotepadHeader` -> `NotepadHeader` | Pane imports this widget |
| [`_NotepadTabBar`](../lib/screens/call/notepad_page.dart:239) | [`lib/feat/call/widgets/notepad_tab_bar.dart`](../lib/feat/call/widgets/notepad_tab_bar.dart:1) | `_NotepadTabBar` -> `NotepadTabBar` | Pane imports this widget |
| [`_NotepadTabItem`](../lib/screens/call/notepad_page.dart:280) | [`lib/feat/call/widgets/notepad_tab_item.dart`](../lib/feat/call/widgets/notepad_tab_item.dart:1) | `_NotepadTabItem` -> `NotepadTabItem` | Used by `NotepadTabBar` |
| [`_SessionInfoView`](../lib/screens/session/session_detail_screen.dart:161) | [`lib/feat/session/segments/info.dart`](../lib/feat/session/segments/info.dart:1) | `_SessionInfoView` -> `SessionDetailInfoSegment` | Move helper builders into this surface file |
| [`_SetupSection`](../lib/screens/settings/settings_screen.dart:84) | [`lib/feat/settings/widgets/setup_section.dart`](../lib/feat/settings/widgets/setup_section.dart:1) | `_SetupSection` -> `SetupSection` | Screen imports this widget |
| `AuthProvider` | [`lib/feat/oobe/models/auth_provider.dart`](../lib/feat/oobe/models/auth_provider.dart:1) | none | `screens/` must not contain model classes |
| Painters such as `VoiceVisualizerBackgroundPainter` | [`lib/feat/about/widgets/voice_visualizer_painters.dart`](../lib/feat/about/widgets/voice_visualizer_painters.dart:1) | none | `screens/` must not contain painter/helper classes |
| [`_TabInfo`](../lib/screens/home/home_screen.dart:259) | [`lib/feat/home/widgets/tab_info.dart`](../lib/feat/home/widgets/tab_info.dart:1) | `_TabInfo` -> `TabInfo` | HomeScreen imports this widget/model |

## 3) Primary import update points (examples)

- [`lib/main.dart`](../lib/main.dart:1) imports `HomeScreen` from [`lib/feat/home/screens/home.dart`](../lib/feat/home/screens/home.dart:1) and `OobeFlowScreen` from [`lib/feat/oobe/screens/oobe_flow.dart`](../lib/feat/oobe/screens/oobe_flow.dart:1)
- Navigation helpers like [`CallNavigationUtils`](../lib/utils/call_navigation_utils.dart:1) update `CallScreen` import path

