# VAGINA Codebase Architecture Research Report

**Project:** VAGINA (Voice AGI Notepad Agent)  
**Research Date:** 2026-01-18  
**Purpose:** Understand voice agent system architecture for implementing text agent support

---

## Executive Summary

VAGINA is a Flutter-based cross-platform voice assistant application that uses Azure OpenAI's Realtime API for voice interactions. The codebase follows a feature-first architecture with clear separation of concerns. Currently, the app supports **voice agents only** through a "SpeedDial" system (character presets), and the Agents tab UI is marked as "under construction" (工事中).

### Key Findings
- **Voice Agent Implementation:** Fully functional using `CallService` and `RealtimeApiClient`
- **Text Agent Support:** Not yet implemented; Agents tab is a placeholder
- **Tool System:** Mature and extensible tool/function calling infrastructure
- **Architecture:** Clean, modular design with Riverpod state management
- **Issue #88:** No direct references found in codebase or git history

---

## 1. Technology Stack

### Core Framework
| Technology | Version | Purpose |
|------------|---------|---------|
| Flutter | 3.27.1 | Cross-platform UI framework |
| Dart | >=3.6.0 <4.0.0 | Programming language |
| Flutter Riverpod | 3.1.0 | State management & DI |

### Key Dependencies
| Package | Purpose |
|---------|---------|
| `record` (6.1.2) | Audio recording (microphone input) |
| `just_audio` / `taudio` | Audio playback |
| `web_socket_channel` (3.0.3) | WebSocket for Realtime API |
| `flutter_markdown` | Markdown rendering in notepad |
| `diff_match_patch` | Document patching tools |
| `path_provider` | File system access |
| `permission_handler` | Runtime permissions |
| `window_manager` | Desktop window management |

### API Integration
- **Azure OpenAI Realtime API** (GPT-4o with Realtime capabilities)
- WebSocket-based bidirectional audio streaming
- Function calling support for tools

---

## 2. Project Structure Overview

```
lib/
├── main.dart                   # Application entry point
├── core/                       # Core infrastructure
│   ├── config/                 # App configuration
│   ├── data/                   # Storage implementations
│   ├── state/                  # Global state providers
│   └── theme/                  # App theming
├── feat/                       # Feature-first organization
│   ├── home/                   # Home screen with tabs
│   │   ├── screens/            # HomeScreen
│   │   └── tabs/               # SpeedDial, Sessions, Tools, Agents
│   ├── call/                   # Voice call feature
│   │   ├── screens/            # CallScreen
│   │   ├── panes/              # Call, Chat, Notepad panes
│   │   ├── widgets/            # UI components
│   │   └── state/              # Call state management
│   ├── session/                # Historical sessions
│   │   ├── screens/            # SessionDetailScreen
│   │   ├── segments/           # Chat, Info, Notepad views
│   │   └── widgets/            # History widgets
│   ├── settings/               # App settings
│   ├── oobe/                   # Out-of-box experience (onboarding)
│   └── speed_dial/             # SpeedDial configuration
├── models/                     # Data models
├── services/                   # Business logic layer
│   ├── call_service.dart       # Main call orchestration
│   ├── realtime_api_client.dart # Azure OpenAI client
│   ├── tool_service.dart       # Tool management
│   ├── notepad_service.dart    # Notepad operations
│   ├── realtime/               # Realtime API handlers
│   ├── tools_runtime/          # Tool execution sandbox
│   └── chat/                   # Chat message management
├── repositories/               # Data persistence layer
├── interfaces/                 # Repository interfaces
├── tools/                      # Tool implementations
│   └── builtin/                # Built-in tools
├── widgets/                    # Shared UI components
└── utils/                      # Utility functions
```

### Architecture Pattern: Feature-First

The codebase follows a **feature-first** organization:
- Each feature has its own directory under `lib/feat/`
- Features contain: `screens/`, `tabs/`, `panes/`, `segments/`, `widgets/`, `state/`
- Shared code lives in top-level directories: `models/`, `services/`, `repositories/`

---

## 3. Voice Agent System Architecture

### 3.1 Call Flow Architecture

```
┌─────────────────────────────────────────────────────┐
│              UI Layer (CallScreen)                  │
│   - Control Panel (mute, end call)                  │
│   - Audio Visualizer                                │
│   - Chat Pane (text messages)                       │
│   - Notepad Pane (AI-editable documents)            │
└─────────────────┬───────────────────────────────────┘
                  │
┌─────────────────▼───────────────────────────────────┐
│        State Management (Riverpod Providers)        │
│  - callServiceProvider                              │
│  - callStateStreamProvider                          │
│  - chatStreamProvider                               │
│  - notepadTabsProvider                              │
└─────────────────┬───────────────────────────────────┘
                  │
┌─────────────────▼───────────────────────────────────┐
│          Business Logic (CallService)               │
│  - Orchestrates entire call lifecycle               │
│  - Manages audio recording/playback                 │
│  - Handles tool execution                           │
│  - Manages chat & notepad state                     │
└─────┬─────────────────────────────────┬─────────────┘
      │                                 │
      ▼                                 ▼
┌─────────────────────┐   ┌─────────────────────────┐
│ RealtimeApiClient   │   │ ToolSandboxManager      │
│ - WebSocket conn    │   │ - Tool runtime          │
│ - Audio streaming   │   │ - Isolated execution    │
│ - Event routing     │   │ - API providers         │
│ - Function calling  │   │   (notepad, memory)     │
└──────────┬──────────┘   └───────────┬─────────────┘
           │                          │
           ▼                          ▼
┌──────────────────────┐   ┌─────────────────────────┐
│ Azure OpenAI         │   │ Built-in Tools          │
│ Realtime API         │   │ - get_current_time      │
│ (GPT-4o)             │   │ - calculator            │
└──────────────────────┘   │ - memory_save/recall    │
                           │ - document_read/write   │
                           │ - notepad operations    │
                           └─────────────────────────┘
```

### 3.2 Core Service: CallService

**Location:** [`lib/services/call_service.dart`](lib/services/call_service.dart:1)

**Responsibilities:**
- Call lifecycle management (idle → connecting → connected → error)
- Audio recording via [`AudioRecorderService`](lib/services/audio_recorder_service.dart:1)
- Audio playback via [`AudioPlayerService`](lib/services/audio_player_service.dart:1)
- WebSocket connection to Azure OpenAI
- Tool execution via [`ToolSandboxManager`](lib/services/tools_runtime/tool_sandbox_manager.dart:1)
- Chat message management
- Notepad operations
- Session persistence

**Key Methods:**
```dart
Future<void> startCall()          // Initialize call with Azure OpenAI
Future<void> endCall()            // End call and save session
void sendTextMessage(String text) // Send text input during call
void setMuted(bool muted)         // Toggle microphone mute
void setSpeedDialId(String id)    // Set active character preset
void setAssistantConfig(...)      // Configure voice & instructions
```

**State Streams:**
- `stateStream` - Call state changes
- `chatStream` - Chat message updates
- `amplitudeStream` - Audio level visualization
- `durationStream` - Call duration timer
- `errorStream` - Error notifications
- `sessionSavedStream` - Session save notifications

### 3.3 Azure OpenAI Integration

**Location:** [`lib/services/realtime/realtime_api_client.dart`](lib/services/realtime/realtime_api_client.dart:1)

**WebSocket Protocol:**
- URL: `wss://{resource}.openai.azure.com/openai/realtime?api-version=YYYY-MM-DD&deployment=...`
- Authentication: API key via query parameter
- Audio format: PCM 24kHz mono
- Encoding: Base64 for audio transmission

**Event Handling Architecture:**
- [`RealtimeEventRouter`](lib/services/realtime/realtime_event_router.dart:1) - Routes 36 server event types
- [`SessionHandlers`](lib/services/realtime/session_handlers.dart:1) - Session lifecycle events
- [`ResponseHandlers`](lib/services/realtime/response_handlers.dart:1) - AI response events
- [`RealtimeStreams`](lib/services/realtime/realtime_streams.dart:1) - Broadcast streams for events
- [`RealtimeState`](lib/services/realtime/realtime_state.dart:1) - Connection state management

**Key Features:**
- Bidirectional audio streaming
- Voice Activity Detection (VAD)
- Function calling / tool use
- Audio interruption handling
- Transcript streaming
- Session configuration (voice, instructions, tools)

---

## 4. Current Agent Management: SpeedDial System

### 4.1 SpeedDial Model

**Location:** [`lib/models/speed_dial.dart`](lib/models/speed_dial.dart:1)

The current "agent" system is implemented as **SpeedDial** - quick-access character presets:

```dart
class SpeedDial {
  final String id;              // Unique identifier
  final String name;            // Display name
  final String systemPrompt;    // AI instructions
  final String? iconEmoji;      // Emoji icon
  final String voice;           // Voice ID (alloy/echo/shimmer)
  final DateTime? createdAt;    // Creation timestamp
  
  bool get isDefault => id == 'default';
}
```

**Key Characteristics:**
- Voice-only agents (no text chat mode)
- System prompt customization
- Voice selection (alloy, echo, shimmer)
- Emoji icon for visual identity
- Default preset cannot be deleted
- Stored in JSON file via `SpeedDialRepository`

### 4.2 SpeedDial UI

**Location:** [`lib/feat/home/tabs/speed_dial.dart`](lib/feat/home/tabs/speed_dial.dart:1)

- Grid layout of speed dial cards
- Each card shows: emoji icon, name, system prompt preview
- Tap to start voice call with that character
- Long press for edit/delete options
- Add button to create new speed dials

### 4.3 Agents Tab (Placeholder)

**Location:** [`lib/feat/home/tabs/agents.dart`](lib/feat/home/tabs/agents.dart:1)

```dart
class AgentsTab extends ConsumerWidget {
  // Shows construction icon with Japanese text "工事中" (Under Construction)
  // "このページは現在工事中です" (This page is currently under construction)
}
```

**Status:** Not implemented - empty placeholder screen

---

## 5. Tool/Function Calling System

### 5.1 Tool Architecture

The tool system supports OpenAI's function calling protocol with a clean, extensible architecture:

```
ToolService (App-level registry)
    ↓
ToolRegistry (Factory-based registration)
    ↓
ToolSandboxManager (Per-call runtime)
    ↓
Tool instances (Execute in isolated context)
```

### 5.2 Tool Definition Structure

**Location:** [`lib/services/tools_runtime/tool_definition.dart`](lib/services/tools_runtime/tool_definition.dart:1)

```dart
class ToolDefinition {
  final String toolKey;              // Runtime identifier
  final String displayName;          // UI label (Japanese)
  final String displayDescription;   // UI description (Japanese)
  final String categoryKey;          // Category (system/memory/notepad)
  final String iconKey;              // Material icon name
  final String sourceKey;            // Source (builtin/mcp/custom)
  final String? mcpServerUrl;        // Optional MCP server URL
  final String description;          // AI-facing description (English)
  final Map<String, dynamic> parametersSchema; // JSON Schema
}
```

### 5.3 Tool Interface

**Location:** [`lib/services/tools_runtime/tool.dart`](lib/services/tools_runtime/tool.dart:1)

```dart
abstract class Tool {
  ToolDefinition get definition;
  Future<void> init();
  Future<String> execute(ToolArgs args, ToolContext context);
}
```

**ToolContext provides:**
- `notepadApi` - Notepad operations (read, write, patch)
- `memoryApi` - Long-term memory operations
- Additional APIs can be added for future tools

### 5.4 Built-in Tools

**Location:** [`lib/tools/builtin/`](lib/tools/builtin/)

| Tool Key | Display Name | Category | Description |
|----------|--------------|----------|-------------|
| `get_current_time` | 現在時刻 | system | Get current date/time |
| `calculator` | 計算機 | system | Perform calculations |
| `memory_save` | メモリ保存 | memory | Save to long-term memory |
| `memory_recall` | メモリ呼び出し | memory | Retrieve from memory |
| `memory_delete` | メモリ削除 | memory | Delete memory entry |
| `document_read` | 文書読み込み | notepad | Read notepad document |
| `document_overwrite` | 文書上書き | notepad | Overwrite document |
| `document_patch` | 文書パッチ | notepad | Apply diff patch |
| `notepad_list_tabs` | タブ一覧 | notepad | List all notepad tabs |
| `notepad_get_metadata` | メタデータ取得 | notepad | Get tab metadata |
| `notepad_get_content` | 内容取得 | notepad | Get tab content |
| `notepad_close_tab` | タブ閉じる | notepad | Close notepad tab |

**Tool Example:**

```dart
class GetCurrentTimeTool implements Tool {
  static const String toolKeyName = 'get_current_time';
  
  @override
  ToolDefinition get definition => const ToolDefinition(
    toolKey: toolKeyName,
    displayName: '現在時刻',
    displayDescription: '現在の日時を取得します',
    categoryKey: 'system',
    iconKey: 'access_time',
    sourceKey: 'builtin',
    description: 'Get the current date and time. Use this when the user asks about the current time or date.',
    parametersSchema: {
      'type': 'object',
      'properties': {
        'timezone': {
          'type': 'string',
          'description': 'Timezone name (e.g., "Asia/Tokyo", "UTC").',
        },
      },
      'required': [],
    },
  );
  
  @override
  Future<String> execute(ToolArgs args, ToolContext context) async {
    final now = DateTime.now();
    return jsonEncode({
      'current_time': now.toIso8601String(),
      'formatted': DurationFormatter.formatJapaneseDateTime(now),
      'timezone': args['timezone'] ?? 'local',
      'unix_timestamp': now.millisecondsSinceEpoch ~/ 1000,
    });
  }
}
```

### 5.5 Tool Registry & Factory Pattern

**ToolRegistry:** [`lib/services/tools_runtime/tool_registry.dart`](lib/services/tools_runtime/tool_registry.dart:1)
- Manages tool factories at app scope
- Caches tool definitions (lazy instantiation)
- Invalidation mechanism for cache updates

**ToolFactory:** [`lib/services/tools_runtime/tool_factory.dart`](lib/services/tools_runtime/tool_factory.dart:1)
- Creates tool instances on demand
- Supports dependency injection
- Simple factory for stateless tools

**ToolSandboxManager:** [`lib/services/tools_runtime/tool_sandbox_manager.dart`](lib/services/tools_runtime/tool_sandbox_manager.dart:1)
- Per-call tool runtime
- Initializes tools with context (notepad, memory APIs)
- Executes tools in isolated context
- Emits tool definition changes

### 5.6 Tool Service

**Location:** [`lib/services/tool_service.dart`](lib/services/tool_service.dart:1)

Application-level tool management:
- Registers all built-in tools
- Provides tool metadata for UI
- Manages tool enable/disable state (via ConfigRepository)
- Groups tools by category
- Future MCP (Model Context Protocol) integration foundation

**Key Methods:**
```dart
void initialize()                              // Register built-in tools
List<Map<String, dynamic>> get toolDefinitions // Get all tool definitions
List<({String name, ToolMetadata metadata})> get allToolsWithMetadata
Map<ToolCategory, List<ToolMetadata>> get toolsByCategory
Future<bool> isToolEnabled(String toolName)
Future<void> toggleTool(String toolName)
ToolMetadata? getToolMetadata(String name)
```

---

## 6. UI Components & Navigation

### 6.1 Home Screen with Tab Bar

**Location:** [`lib/feat/home/screens/home.dart`](lib/feat/home/screens/home.dart:1)

**Tab Structure:**
1. **スピードダイヤル (Speed Dial)** - Character presets
2. **セッション (Sessions)** - Call history
3. **ツール (Tools)** - Tool management
4. **エージェント (Agents)** - Under construction

**Navigation:**
- Bottom navigation bar (5 slots: 4 tabs + center FAB)
- Center FAB: Phone icon → start voice call
- Swipeable PageView for tab content
- Context-sensitive add button (visible on Speed Dial tab)
- Settings button (top-right)

### 6.2 Call Screen Architecture

**Location:** [`lib/feat/call/screens/call.dart`](lib/feat/call/screens/call.dart:1)

**Panes:**
- [`call.dart`](lib/feat/call/panes/call.dart:1) - Main call interface (visualizer, controls)
- [`chat.dart`](lib/feat/call/panes/chat.dart:1) - Chat message view
- [`notepad.dart`](lib/feat/call/panes/notepad.dart:1) - Multi-tab notepad

**Control Panel:**
- Mute button
- End call button
- Audio level visualizer
- Duration timer

**Chat Pane:**
- Message bubbles (user/assistant/tool calls)
- Text input for sending messages during call
- Auto-scroll to latest message
- Scroll to bottom button

**Notepad Pane:**
- Tab bar for multiple documents
- Content renderer (Plain Text / Markdown / HTML)
- Action bar (share, format selection)
- Real-time AI editing via tools

### 6.3 Session History

**Location:** [`lib/feat/session/`](lib/feat/session/)

**SessionDetailScreen segments:**
- Info - Session metadata (duration, timestamp, speed dial)
- Chat - Historical chat messages
- Notepad - Historical notepad tabs

**Model:** [`CallSession`](lib/models/call_session.dart:1)
```dart
class CallSession {
  final String id;
  final DateTime startTime;
  final DateTime endTime;
  final int duration;
  final List<String> chatMessages;        // JSON serialized
  final List<SessionNotepadTab>? notepadTabs;
  final String speedDialId;               // Which character was used
}
```

---

## 7. State Management

### 7.1 Riverpod Architecture

**Pattern:** Provider-based state management with code generation

**Core Providers:**
- **Repository Providers** ([`lib/core/state/repository_providers.dart`](lib/core/state/repository_providers.dart:1))
  - `callSessionRepositoryProvider`
  - `speedDialRepositoryProvider`
  - `memoryRepositoryProvider`
  - `configRepositoryProvider`
  - `preferencesRepositoryProvider`

- **Service Providers** ([`lib/feat/call/state/call_service_providers.dart`](lib/feat/call/state/call_service_providers.dart:1))
  - `callServiceProvider`
  - `toolServiceProvider`
  - `notepadServiceProvider`

- **Stream Providers** ([`lib/feat/call/state/call_stream_providers.dart`](lib/feat/call/state/call_stream_providers.dart:1))
  - `callStateStreamProvider`
  - `chatStreamProvider`
  - `callDurationStreamProvider`
  - `amplitudeStreamProvider`

- **UI State Providers** ([`lib/feat/call/state/call_ui_state_providers.dart`](lib/feat/call/state/call_ui_state_providers.dart:1))
  - `currentPaneIndexProvider`
  - `selectedNotepadTabProvider`

### 7.2 State Patterns

**Service Pattern:**
```dart
@Riverpod(keepAlive: true)
CallService callService(Ref ref) {
  return CallService(
    recorder: AudioRecorderService(),
    player: AudioPlayerService(),
    apiClient: RealtimeApiClient(),
    config: ref.watch(configRepositoryProvider),
    // ... dependencies
  );
}
```

**Stream Provider Pattern:**
```dart
@riverpod
Stream<CallState> callStateStream(Ref ref) {
  final service = ref.watch(callServiceProvider);
  return service.stateStream;
}
```

**UI State Pattern:**
```dart
@riverpod
class CurrentPaneIndex extends _$CurrentPaneIndex {
  @override
  int build() => 0; // Initial state
  void setIndex(int index) => state = index;
}
```

---

## 8. Data Persistence Layer

### 8.1 Repository Pattern

**Interfaces:** [`lib/interfaces/`](lib/interfaces/)
- `CallSessionRepository` - Session history CRUD
- `SpeedDialRepository` - Character preset management
- `MemoryRepository` - Long-term memory storage
- `ConfigRepository` - App settings & configuration
- `KeyValueStore` - Abstract storage interface

**Implementations:** [`lib/repositories/`](lib/repositories/)
- `JsonCallSessionRepository`
- `JsonSpeedDialRepository`
- `JsonMemoryRepository`
- `JsonConfigRepository`
- `PreferencesRepository`

### 8.2 Storage Backend

**Location:** [`lib/core/data/json_file_store.dart`](lib/core/data/json_file_store.dart:1)

**JsonFileStore:**
- Single JSON file: `vagina_config.json`
- Platform-specific directory (via `path_provider`)
- Folder name: `VAGINA`
- Atomic read/write operations
- In-memory fallback for tests

**Data Structure:**
```json
{
  "call_sessions": {...},
  "speed_dials": {...},
  "memories": {...},
  "config": {
    "azure_realtime_url": "...",
    "azure_api_key": "...",
    "tool_enabled": {...}
  },
  "preferences": {...}
}
```

### 8.3 RepositoryFactory

**Location:** [`lib/repositories/repository_factory.dart`](lib/repositories/repository_factory.dart:1)

Centralized factory for repository instances:
- Singleton pattern for shared storage
- Lazy initialization
- Test-friendly (in-memory store option)
- Consistent initialization

```dart
await RepositoryFactory.initialize();
final speedDials = RepositoryFactory.speedDials;
final config = RepositoryFactory.config;
```

---

## 9. Configuration & Settings

### 9.1 App Configuration

**Location:** [`lib/core/config/app_config.dart`](lib/core/config/app_config.dart:1)

Static configuration values:
- Audio settings (sample rate, channels)
- Logging configuration
- Silence timeout for auto-hangup
- WebSocket parameters

### 9.2 Assistant Configuration

**Location:** [`lib/models/assistant_config.dart`](lib/models/assistant_config.dart:1)

```dart
class AssistantConfig {
  final String name;         // Assistant name
  final String instructions; // System prompt
  final String voice;        // Voice ID
  
  static const List<String> availableVoices = [
    'alloy', 'echo', 'shimmer'
  ];
  
  static const String defaultInstructions = '''
    あなたは「VAGINA」（Voice AGI Notepad Agent）という名前の音声AIアシスタントです。
    ...
  ''';
}
```

### 9.3 Realtime Session Config

**Location:** [`lib/models/realtime_session_config.dart`](lib/models/realtime_session_config.dart:1)

Azure OpenAI session parameters:
- Modalities (text, audio)
- Voice selection
- System instructions
- Turn detection settings
- Tool definitions
- Temperature & max tokens
- Noise reduction (far/near field)

---

## 10. Platform Support

### Supported Platforms
- ✅ Android
- ✅ iOS  
- ✅ Windows (desktop)
- ✅ macOS (desktop)
- ✅ Linux (desktop)
- ✅ Web (PWA)

### Platform-Specific Code

**Audio:**
- Windows: `taudio` package (custom audio backend)
- Other platforms: `just_audio`
- Recording: `record` package (cross-platform)

**Window Management:**
- Desktop platforms: `window_manager` package
- Conditional initialization based on platform

**Platform Detection:**
- [`lib/utils/platform_compat.dart`](lib/utils/platform_compat.dart:1)

---

## 11. Testing Infrastructure

### Test Structure
```
test/
├── feat/call/state/
│   └── notepad_controller_test.dart
├── mocks/
│   ├── mock_apis.dart
│   └── mock_repositories.dart
├── models/
│   ├── call_session_test.dart
│   └── speed_dial_test.dart
└── repositories/
    └── json_speed_dial_repository_test.dart
```

### Testing Tools
- `flutter_test` - Widget & unit testing
- `integration_test` - E2E testing
- `mockito` - Mocking framework
- In-memory storage for repository tests

---

## 12. Key Design Patterns

### 12.1 Feature-First Architecture
- Features organized by user-facing functionality
- Each feature is self-contained with screens, widgets, state
- Promotes cohesion, reduces coupling

### 12.2 Repository Pattern
- Abstract interfaces in `interfaces/`
- Implementations in `repositories/`
- Allows easy swapping of storage backends
- Test-friendly with in-memory implementations

### 12.3 Service Layer
- Business logic isolated from UI
- Services injected via Riverpod
- Manages complex orchestration (CallService)

### 12.4 Stream-Based Communication
- Reactive UI updates via streams
- Clean separation of data flow
- Broadcast streams for multiple listeners

### 12.5 Factory Pattern
- ToolFactory for tool instantiation
- RepositoryFactory for data layer
- Enables dependency injection

### 12.6 Sandbox/Isolation
- Tool execution in isolated context
- ToolContext provides controlled API access
- Prevents tools from directly accessing app state

---

## 13. Current Limitations & Gaps

### 13.1 Text Agent Support
**Status:** Not implemented

**Current State:**
- Only voice agents exist (via SpeedDial)
- Agents tab shows "under construction" placeholder
- No text-only chat interface
- No agent management beyond SpeedDial

**Missing Components:**
- Text agent model (separate from SpeedDial)
- Text chat UI (non-voice conversation)
- Agent CRUD operations
- Agent-specific tool assignments
- Multi-agent conversations

### 13.2 Issue #88
**Status:** No direct references found in codebase

**Search Results:**
- No code comments mentioning "#88" or "issue 88"
- Git history shows branches but no issue references
- May be documented in external issue tracker (GitHub Issues, etc.)

### 13.3 MCP Integration
**Status:** Infrastructure exists, not implemented

**Current State:**
- Tool system has `mcpServerUrl` field in ToolDefinition
- ToolSource enum includes 'mcp' option
- No actual MCP client implementation
- No MCP server configuration UI

---

## 14. Recommendations for New Features

### 14.1 Text Agent Implementation

**Recommended Location:** `lib/feat/agents/`

**Proposed Structure:**
```
lib/feat/agents/
├── screens/
│   ├── agents_screen.dart       # Replace current placeholder
│   ├── agent_detail.dart        # Agent configuration
│   └── agent_chat.dart          # Text chat interface
├── tabs/
│   └── agents.dart              # Update existing file
├── widgets/
│   ├── agent_card.dart          # Agent list item
│   ├── agent_form.dart          # Create/edit form
│   └── chat_bubble.dart         # Reuse from call/chat?
├── state/
│   ├── agents_repository.dart
│   ├── text_chat_service.dart
│   └── agent_providers.dart
└── models/
    └── text_agent.dart
```

**New Data Model:**
```dart
class TextAgent {
  final String id;
  final String name;
  final String? iconEmoji;
  final String systemPrompt;
  final String model;              // e.g., "gpt-4o"
  final List<String> enabledTools; // Tool keys
  final DateTime createdAt;
  final DateTime? updatedAt;
}
```

**New Repository Interface:**
```dart
abstract class TextAgentRepository {
  Future<List<TextAgent>> getAll();
  Future<TextAgent?> getById(String id);
  Future<void> save(TextAgent agent);
  Future<void> delete(String id);
}
```

### 14.2 Text Chat Service

**Location:** `lib/services/text_chat_service.dart`

**Responsibilities:**
- Use Azure OpenAI Chat Completions API (non-realtime)
- Manage conversation history
- Handle tool calling in text mode
- Support streaming responses
- Session persistence

**Key Differences from CallService:**
- HTTP-based (not WebSocket)
- No audio recording/playback
- Text-only input/output
- Different API endpoint

### 14.3 Agent Management UI

**Update:** [`lib/feat/home/tabs/agents.dart`](lib/feat/home/tabs/agents.dart:1)

**Proposed Features:**
- List view of all text agents
- Search/filter agents
- Create new agent button
- Edit/delete agent actions
- Agent selection for chat

**Agent Detail Screen:**
- Name and icon configuration
- System prompt editor (with templates)
- Tool selection (checkboxes)
- Model selection dropdown
- Test chat button

### 14.4 Integration Points

**Reusable Components:**
- Tool system (ToolService, ToolRegistry, etc.)
- Repository pattern (add TextAgentRepository)
- UI components (chat bubbles, etc.)
- Theme and styling

**New Components Needed:**
- Text-only chat interface
- Agent configuration forms
- HTTP-based OpenAI client (separate from RealtimeApiClient)
- Text chat state management
- Agent session history

### 14.5 Tool Assignment Strategy

**Option 1: Per-Agent Tool Configuration**
- Each TextAgent has `List<String> enabledTools`
- More granular control
- Better for specialized agents

**Option 2: Global Tool Enable/Disable**
- Use existing ConfigRepository tool toggles
- Simpler implementation
- Consistent across agents

**Recommendation:** Option 1 for flexibility

### 14.6 API Strategy

**Voice Agents (Existing):**
- Azure OpenAI Realtime API
- WebSocket connection
- Real-time audio streaming

**Text Agents (Proposed):**
- Azure OpenAI Chat Completions API
- HTTP REST requests
- Text-based messages

**Shared:**
- Same Azure resource
- Function calling protocol
- Tool definitions

---

## 15. Architecture Strengths

### 15.1 Modularity
- Clear separation of concerns
- Feature-first organization scales well
- Easy to add new features without affecting existing code

### 15.2 Testability
- Repository interfaces enable mocking
- In-memory storage for tests
- Service layer can be tested independently

### 15.3 Extensibility
- Tool system designed for plugins
- MCP foundation ready for future integration
- Factory pattern allows easy addition of new components

### 15.4 Platform Support
- Cross-platform codebase
- Platform-specific code isolated
- Desktop, mobile, and web support

### 15.5 State Management
- Riverpod provides clean dependency injection
- Stream-based reactivity
- Code generation reduces boilerplate

---

## 16. Code Quality Observations

### Positive Aspects
✅ Consistent naming conventions  
✅ Clear code organization  
✅ Comprehensive error handling  
✅ Detailed logging throughout  
✅ TypeScript-like type safety with Dart  
✅ Extensive inline documentation  
✅ Separation of business logic from UI  

### Areas for Improvement
⚠️ Some large service classes (CallService ~657 lines)  
⚠️ Limited test coverage  
⚠️ Agents tab placeholder needs implementation  
⚠️ Documentation could be more comprehensive  

---

## 17. Documentation Resources

**Available Documentation:**
- [`README.md`](README.md:1) - Project overview, setup instructions (Japanese)
- [`CHANGELOG.md`](CHANGELOG.md:1) - Version history
- [`SECURITY.md`](SECURITY.md:1) - Security policy
- [`docs/`](docs/) - Additional documentation directory
- [`plans/`](plans/) - Planning documents

**Code Documentation:**
- Most classes have doc comments
- Key methods documented
- Event streams documented
- Tool definitions self-documenting

---

## 18. Next Steps for Implementation

### Phase 1: Foundation (Text Agent Core)
1. Create `TextAgent` model
2. Implement `TextAgentRepository` interface
3. Add JSON storage implementation
4. Create Riverpod providers

### Phase 2: Service Layer
1. Implement `TextChatService`
2. Add HTTP-based OpenAI client for Chat Completions API
3. Integrate with existing `ToolSandboxManager`
4. Add conversation history management

### Phase 3: UI Implementation
1. Update Agents tab (remove construction placeholder)
2. Create agent list view
3. Implement agent create/edit forms
4. Build text chat interface

### Phase 4: Integration
1. Connect UI to services
2. Add session persistence
3. Implement agent selection flow
4. Add tool assignment UI

### Phase 5: Polish
1. Add tests
2. Update documentation
3. Performance optimization
4. User feedback integration

---

## Conclusion

The VAGINA codebase demonstrates a well-architected Flutter application with clear separation of concerns, extensible design patterns, and robust voice agent implementation. The existing tool system and architecture provide an excellent foundation for adding text agent support.

**Key Takeaways:**
- **Voice agents are mature** - Fully implemented via SpeedDial and CallService
- **Text agents need implementation** - Agents tab is a placeholder waiting for development
- **Tool system is ready** - Extensible architecture supports both voice and text agents
- **Architecture is solid** - Feature-first, repository pattern, service layer, Riverpod state management
- **Clear path forward** - Recommended structure for implementing text agents

**Implementation Complexity:** Medium
- Requires new models, repository, service, and UI
- Can leverage existing patterns and components
- Clean architecture makes integration straightforward
- Well-defined interfaces reduce coupling

**Estimated Effort:** 2-3 weeks for full text agent implementation

---

## Appendix: Key File Reference

| Category | Key Files | Purpose |
|----------|-----------|---------|
| **Entry Point** | [`lib/main.dart`](lib/main.dart:1) | Application initialization |
| **Voice Agents** | [`lib/services/call_service.dart`](lib/services/call_service.dart:1) | Call orchestration |
| | [`lib/services/realtime/realtime_api_client.dart`](lib/services/realtime/realtime_api_client.dart:1) | Azure OpenAI WebSocket client |
| | [`lib/models/speed_dial.dart`](lib/models/speed_dial.dart:1) | Character preset model |
| **Tools** | [`lib/services/tool_service.dart`](lib/services/tool_service.dart:1) | Tool management |
| | [`lib/services/tools_runtime/tool_registry.dart`](lib/services/tools_runtime/tool_registry.dart:1) | Tool factory registry |
| | [`lib/services/tools_runtime/tool_sandbox_manager.dart`](lib/services/tools_runtime/tool_sandbox_manager.dart:1) | Tool execution runtime |
| | [`lib/tools/builtin/`](lib/tools/builtin/) | Built-in tool implementations |
| **UI** | [`lib/feat/home/screens/home.dart`](lib/feat/home/screens/home.dart:1) | Main screen with tabs |
| | [`lib/feat/home/tabs/agents.dart`](lib/feat/home/tabs/agents.dart:1) | Agents tab (placeholder) |
| | [`lib/feat/call/screens/call.dart`](lib/feat/call/screens/call.dart:1) | Voice call interface |
| **Data** | [`lib/repositories/repository_factory.dart`](lib/repositories/repository_factory.dart:1) | Repository factory |
| | [`lib/core/data/json_file_store.dart`](lib/core/data/json_file_store.dart:1) | JSON storage backend |
| **State** | [`lib/core/state/repository_providers.dart`](lib/core/state/repository_providers.dart:1) | Repository providers |
| | [`lib/feat/call/state/call_service_providers.dart`](lib/feat/call/state/call_service_providers.dart:1) | Service providers |

---

**Report Generated:** 2026-01-18  
**Codebase Version:** 1.0.0+1  
**Flutter Version:** 3.27.1
