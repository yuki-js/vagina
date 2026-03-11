# Agent Filesystem: Tool / Host API Structure — Before State / Diff Strategy / After State (Diff Applied without diff)

## Before State

### Tool definition / registration (flat)

- Tool metadata model: [`ToolDefinition`](lib/services/tools_runtime/tool_definition.dart:5)
- Tool runtime interface: [`Tool`](lib/services/tools_runtime/tool.dart:25)
- Per-tool dependency container: [`ToolContext`](lib/services/tools_runtime/tool_context.dart:18)
- Tool catalog entrypoint (flat list): [`RootToolbox.create()`](lib/tools/tools.dart:44)

### AI-facing tool list (no categorization)

Registered by [`RootToolbox.create()`](lib/tools/tools.dart:44) (1 global list; schemas are embedded in each tool’s [`Tool.definition`](lib/services/tools_runtime/tool.dart:26)).

1. `calculator` → [`CalculatorTool`](lib/tools/builtin/calculation/calculator_tool.dart:6)
2. `document_overwrite` → [`DocumentOverwriteTool`](lib/tools/builtin/document/document_overwrite_tool.dart:15)
3. `document_patch` → [`DocumentPatchTool`](lib/tools/builtin/document/document_patch_tool.dart:201)
4. `document_read` → [`DocumentReadTool`](lib/tools/builtin/document/document_read_tool.dart:6)
5. `get_current_time` → [`GetCurrentTimeTool`](lib/tools/builtin/system/get_current_time_tool.dart:7)
6. `memory_delete` → [`MemoryDeleteTool`](lib/tools/builtin/memory/memory_delete_tool.dart:11)
7. `memory_recall` → [`MemoryRecallTool`](lib/tools/builtin/memory/memory_recall_tool.dart:6)
8. `memory_save` → [`MemorySaveTool`](lib/tools/builtin/memory/memory_save_tool.dart:6)
9. `notepad_close_tab` → [`NotepadCloseTabTool`](lib/tools/builtin/notepad/notepad_close_tab_tool.dart:6)
10. `notepad_get_content` → [`NotepadGetContentTool`](lib/tools/builtin/notepad/notepad_get_content_tool.dart:6)
11. `notepad_get_metadata` → [`NotepadGetMetadataTool`](lib/tools/builtin/notepad/notepad_get_metadata_tool.dart:6)
12. `notepad_list_tabs` → [`NotepadListTabsTool`](lib/tools/builtin/notepad/notepad_list_tabs_tool.dart:6)
13. `end_call` → [`EndCallTool`](lib/tools/builtin/call/end_call_tool.dart:6)
14. `spreadsheet_add_rows` → [`SpreadsheetAddRowsTool`](lib/tools/builtin/spreadsheet/spreadsheet_add_rows_tool.dart:7)
15. `spreadsheet_delete_rows` → [`SpreadsheetDeleteRowsTool`](lib/tools/builtin/spreadsheet/spreadsheet_delete_rows_tool.dart:7)
16. `spreadsheet_update_rows` → [`SpreadsheetUpdateRowsTool`](lib/tools/builtin/spreadsheet/spreadsheet_update_rows_tool.dart:7)
17. `list_available_agents` → [`ListAvailableAgentsTool`](lib/tools/builtin/text_agent/list_available_agents_tool.dart:6)
18. `query_text_agent` → [`QueryTextAgentTool`](lib/tools/builtin/text_agent/query_text_agent_tool.dart:8)

### Content handle + invariants

- Primary handle is `tabId` (artifact tab id)
  - Read: [`DocumentReadTool.execute()`](lib/tools/builtin/document/document_read_tool.dart:33) → [`NotepadApi.getTab()`](lib/services/tools_runtime/apis/notepad_api.dart:23)
  - Patch: [`DocumentPatchTool.execute()`](lib/tools/builtin/document/document_patch_tool.dart:260) → [`NotepadApi.updateTab()`](lib/services/tools_runtime/apis/notepad_api.dart:48)
  - Spreadsheet mutation: [`SpreadsheetAddRowsTool.execute()`](lib/tools/builtin/spreadsheet/spreadsheet_add_rows_tool.dart:44) → parse with [`TabularData.parse()`](lib/models/tabular_data.dart:1) → [`NotepadApi.updateTab()`](lib/services/tools_runtime/apis/notepad_api.dart:48)

- MIME type is first-class and used for validation (tabular types)
  - Validation lives in [`NotepadService.updateTab()`](lib/services/notepad_service.dart:112)
  - Tabular MIME check lives in [`NotepadService`](lib/services/notepad_service.dart:6)

### Sandbox boundary: worker isolate ↔ host (hostCall)

#### Worker side (creates API clients and injects into context)

- Worker entrypoint / controller: [`toolSandboxWorker()`](lib/services/tools_runtime/tool_sandbox_worker.dart:30)
- API clients are created in [`_WorkerController._createApiClients()`](lib/services/tools_runtime/tool_sandbox_worker.dart:214)
- Tools are instantiated and each gets a [`ToolContext`](lib/services/tools_runtime/tool_context.dart:18) in [`_WorkerController._initializeToolRegistry()`](lib/services/tools_runtime/tool_sandbox_worker.dart:189)

#### Host side (routes hostCall)

- Host router: [`ToolSandboxManager._handleHostCall()`](lib/services/tools_runtime/tool_sandbox_manager.dart:455)
- Routing keys (string `api`):
  - `notepad` → [`NotepadHostApi.handleCall()`](lib/services/tools_runtime/host/notepad_host_api.dart:17)
  - `call` → [`CallHostApi.handleCall()`](lib/services/tools_runtime/host/call_host_api.dart:21)
  - `toolStorage` → [`ToolStorageHostApi.handleCall()`](lib/services/tools_runtime/host/tool_storage_host_api.dart:36)

### Sandbox APIs (Before)

#### notepad

- Worker interface + client: [`NotepadApi`](lib/services/tools_runtime/apis/notepad_api.dart:5) / [`NotepadApiClient`](lib/services/tools_runtime/apis/notepad_api.dart:65)
- Host adapter: [`NotepadHostApi`](lib/services/tools_runtime/host/notepad_host_api.dart:8)
- Backing service: [`NotepadService`](lib/services/notepad_service.dart:22)
- Exposed methods (complete):
  - `listTabs()` ([`NotepadApi.listTabs()`](lib/services/tools_runtime/apis/notepad_api.dart:17))
  - `getTab(id)` ([`NotepadApi.getTab()`](lib/services/tools_runtime/apis/notepad_api.dart:23))
  - `createTab(content, mimeType, title?)` ([`NotepadApi.createTab()`](lib/services/tools_runtime/apis/notepad_api.dart:33))
  - `updateTab(id, content?, title?, mimeType?)` ([`NotepadApi.updateTab()`](lib/services/tools_runtime/apis/notepad_api.dart:48))
  - `closeTab(id)` ([`NotepadApi.closeTab()`](lib/services/tools_runtime/apis/notepad_api.dart:61))

#### call

- Worker interface + client: [`CallApi`](lib/services/tools_runtime/apis/call_api.dart:5) / [`CallApiClient`](lib/services/tools_runtime/apis/call_api.dart:16)
- Host adapter: [`CallHostApi`](lib/services/tools_runtime/host/call_host_api.dart:9)
- Backing service: [`CallService`](lib/services/call_service.dart:1)
- Exposed methods (complete):
  - `endCall(endContext?)` ([`CallApi.endCall()`](lib/services/tools_runtime/apis/call_api.dart:12))

#### toolStorage

- Worker interface + client: [`ToolStorageApi`](lib/services/tools_runtime/apis/tool_storage_api.dart:6) / [`ToolStorageApiClient`](lib/services/tools_runtime/apis/tool_storage_api.dart:45)
- Host adapter: [`ToolStorageHostApi`](lib/services/tools_runtime/host/tool_storage_host_api.dart:8)
- Backing repository: [`ToolStorage`](lib/interfaces/tool_storage.dart:1)
- Host router injects current toolKey context via [`ToolSandboxManager.execute()`](lib/services/tools_runtime/tool_sandbox_manager.dart:217)
- Exposed methods (complete):
  - `save(key, value)` ([`ToolStorageApi.save()`](lib/services/tools_runtime/apis/tool_storage_api.dart:14))
  - `get(key)` ([`ToolStorageApi.get()`](lib/services/tools_runtime/apis/tool_storage_api.dart:22))
  - `list()` ([`ToolStorageApi.list()`](lib/services/tools_runtime/apis/tool_storage_api.dart:27))
  - `delete(key)` ([`ToolStorageApi.delete()`](lib/services/tools_runtime/apis/tool_storage_api.dart:35))
  - `deleteAll()` ([`ToolStorageApi.deleteAll()`](lib/services/tools_runtime/apis/tool_storage_api.dart:41))

### Realtime tool registration (host)

- Call start registers the enabled subset once in [`CallService._initializeToolsForCall()`](lib/services/call_service.dart:283)
- Push happens via [`RealtimeApiClient.setTools()`](lib/services/realtime/realtime_api_client.dart:141) + [`RealtimeApiClient.updateSessionConfig()`](lib/services/realtime/realtime_api_client.dart:161)

---

## Diff Strategy

This section is the “diff” (change list) expressed as operations/rules, not as patch (+/-).

### A) Universal handle change

- Replace the primary handle:
  - **Before**: `tabId`
  - **After**: `path` (absolute virtual filesystem path, e.g. `/documents/notes.md`)

### B) Replace Notepad-as-authority with Filesystem-as-authority

- Absorb Notepad runtime state into a filesystem “open files” runtime state (path → working content).
- Notepad becomes a UI view of open-file state (no longer an AI-facing storage API).

### C) Tool surface restructuring (flat → base + filesystem core + type-bound bundles)

- Add core filesystem tools (always available):
  - `fs_list(path)`
  - `fs_open(path)`
  - `fs_close(path)`
  - `fs_delete(path)`
  - `fs_move(fromPath, toPath)`

- Convert content tools from tabId-based to path-based and make them valid only for opened files:
  - `document_read(tabId)` → `document_read(path)`
  - `document_overwrite(tabId?, ...)` → `document_overwrite(path, ...)`
  - `document_patch(tabId, ...)` → `document_patch(path, ...)`
  - `spreadsheet_* (tabId, ...)` → `spreadsheet_* (path, ...)`

- Define type-bound tool bundles via extension/file type:
  - text-like: `.txt`, `.md`, `.html`
  - spreadsheet: `.v2d.csv`, `.v2d.json`, `.v2d.jsonl`

- Add open-set listing tool (always available):
  - `fs_active_files()` — list currently active/open filesystem paths (open-set)

- Implement dynamic tool injection/removal on open/close:
  - active tools = base tools ∪ (tools for each open file type)
  - update the Realtime session via [`RealtimeApiClient.updateSessionConfig()`](lib/services/realtime/realtime_api_client.dart:161)

### D) Sandbox API restructuring (minimize host-call surface)

- Add new host-call API channel: `filesystem`
- Remove host-call API channel: `notepad`
- Remove host-call API channel: `toolStorage`

Rationale:
- tools should be “FS-centric”; host is reduced to filesystem + call control.
- if secrecy is needed, the tool encrypts content before writing to filesystem.

### E) Explicit deletions (what disappears)

#### Deleted AI-facing tools

- `notepad_list_tabs`
- `notepad_get_content`
- `notepad_get_metadata`
- `notepad_close_tab`

#### Deleted AI-facing tools (because toolStorage is removed)

- `memory_save`
- `memory_recall`
- `memory_delete`

#### Deleted sandbox APIs

- `toolStorage` API:
  - [`ToolStorageApi`](lib/services/tools_runtime/apis/tool_storage_api.dart:6)
  - [`ToolStorageHostApi`](lib/services/tools_runtime/host/tool_storage_host_api.dart:8)
  - [`ToolStorage`](lib/interfaces/tool_storage.dart:1)

- `notepad` API:
  - [`NotepadApi`](lib/services/tools_runtime/apis/notepad_api.dart:5)
  - [`NotepadHostApi`](lib/services/tools_runtime/host/notepad_host_api.dart:8)

### F) ToolContext change

- Replace `ToolContext.notepadApi` with `ToolContext.filesystemApi` (concept aligns with the revised design in [`agent-filesystem-design.md`](docs/plans/agent-filesystem-design.md:278)).
- Remove `ToolContext.toolStorageApi`.

---

## After State (Diff Applied without diff)

### Tool definition / registration (bundle-by-file-type)

- The active tool palette is not a single immutable list.
- Tools are selected dynamically as:
  - base tools
  - + filesystem core tools
  - + type-bound tools for each currently opened file

This requires metadata beyond [`ToolDefinition`](lib/services/tools_runtime/tool_definition.dart:5) to represent activation policy and supported types/extensions.

### AI-facing tool list (After)

#### Always available (base)

- `calculator` → [`CalculatorTool`](lib/tools/builtin/calculation/calculator_tool.dart:6)
- `get_current_time` → [`GetCurrentTimeTool`](lib/tools/builtin/system/get_current_time_tool.dart:7)
- `end_call` → [`EndCallTool`](lib/tools/builtin/call/end_call_tool.dart:6)
- `list_available_agents` → [`ListAvailableAgentsTool`](lib/tools/builtin/text_agent/list_available_agents_tool.dart:6)
- `query_text_agent` → [`QueryTextAgentTool`](lib/tools/builtin/text_agent/query_text_agent_tool.dart:8)

#### Always available (filesystem core)

Defined conceptually in [`agent-filesystem-design.md`](docs/plans/agent-filesystem-design.md:610):

- `fs_list(path)`
- `fs_open(path)`
- `fs_close(path)`
- `fs_delete(path)`
- `fs_move(fromPath, toPath)`
- `fs_active_files()`

#### Injected only when a matching file type is opened (type-bound)

1) Text-like files (`.txt`, `.md`, `.html` per [`agent-filesystem-design.md`](docs/plans/agent-filesystem-design.md:314)):

- `document_read(path)` → refactor from [`DocumentReadTool`](lib/tools/builtin/document/document_read_tool.dart:6)
- `document_overwrite(path, content)` → refactor from [`DocumentOverwriteTool`](lib/tools/builtin/document/document_overwrite_tool.dart:15)
- `document_patch(path, patch)` → refactor from [`DocumentPatchTool`](lib/tools/builtin/document/document_patch_tool.dart:201)

2) Spreadsheet files (`.v2d.csv`, `.v2d.json`, `.v2d.jsonl` per [`agent-filesystem-design.md`](docs/plans/agent-filesystem-design.md:320)):

- `spreadsheet_add_rows(path, rows)` → refactor from [`SpreadsheetAddRowsTool`](lib/tools/builtin/spreadsheet/spreadsheet_add_rows_tool.dart:7)
- `spreadsheet_update_rows(path, updates)` → refactor from [`SpreadsheetUpdateRowsTool`](lib/tools/builtin/spreadsheet/spreadsheet_update_rows_tool.dart:7)
- `spreadsheet_delete_rows(path, rowIndices)` → refactor from [`SpreadsheetDeleteRowsTool`](lib/tools/builtin/spreadsheet/spreadsheet_delete_rows_tool.dart:7)

### Content handle + invariants (After)

- Primary handle is `path` (absolute virtual filesystem path).
- A content tool operates only on an opened file:
  - read working content from open-file runtime state
  - write back to open-file runtime state
  - persistence boundary is `fs_close(path)` only

### Sandbox boundary: worker isolate ↔ host (hostCall)

#### Worker side (After)

- Worker entrypoint / controller remains: [`toolSandboxWorker()`](lib/services/tools_runtime/tool_sandbox_worker.dart:30)
- API clients created in [`_WorkerController._createApiClients()`](lib/services/tools_runtime/tool_sandbox_worker.dart:214) include:
  - `filesystem` → `FilesystemApiClient` (NEW; mirrors [`NotepadApiClient`](lib/services/tools_runtime/apis/notepad_api.dart:65))
  - `call` → [`CallApiClient`](lib/services/tools_runtime/apis/call_api.dart:16)
  - `textAgent` remains worker-local (HTTP) via [`TextAgentApiClient`](lib/services/tools_runtime/apis/text_agent_api.dart:148)

- Per-tool context is now conceptually:
  - `toolKey`
  - `filesystemApi`
  - `callApi`
  - `textAgentApi`

(no `notepadApi`, no `toolStorageApi`).

#### Host side (After)

- Host router: [`ToolSandboxManager._handleHostCall()`](lib/services/tools_runtime/tool_sandbox_manager.dart:455)
- Routing keys (string `api`):
  - `filesystem` → `FilesystemHostApi` (NEW; mirrors [`NotepadHostApi`](lib/services/tools_runtime/host/notepad_host_api.dart:8))
  - `call` → [`CallHostApi.handleCall()`](lib/services/tools_runtime/host/call_host_api.dart:21)

### Sandbox APIs (After)

#### filesystem (NEW, primary)

This is the single authority for storage + open-file runtime + tool palette updates.

1) Persistent storage operations (repo-backed; persisted to [`KeyValueStore`](lib/interfaces/key_value_store.dart:2)):
- `read(path)`
- `write(path, content)`
- `delete(path)`
- `move(fromPath, toPath)`
- `list(path, recursive?)`

2) Open-file runtime operations (not persisted):
- `openFile(path, content)`
- `getOpenFile(path)`
- `updateOpenFile(path, content)`
- `closeFile(path)`
- `listOpenFiles()`

3) Tool palette updates (host-only concern):
- On open/close, host computes the active tool set (base ∪ file-type bundles) and updates the Realtime session via [`RealtimeApiClient.updateSessionConfig()`](lib/services/realtime/realtime_api_client.dart:161).

#### call (unchanged, minimal)

- Worker interface + client: [`CallApi`](lib/services/tools_runtime/apis/call_api.dart:5) / [`CallApiClient`](lib/services/tools_runtime/apis/call_api.dart:16)
- Host adapter: [`CallHostApi`](lib/services/tools_runtime/host/call_host_api.dart:9)
- Exposed methods:
  - `endCall(endContext?)` ([`CallApi.endCall()`](lib/services/tools_runtime/apis/call_api.dart:12))

### Realtime tool registration (host)

- Host updates the tool list dynamically during a call:
  - base tools
  - ∪(type tools for each open file)
  - and pushes via [`RealtimeApiClient.setTools()`](lib/services/realtime/realtime_api_client.dart:141) + [`RealtimeApiClient.updateSessionConfig()`](lib/services/realtime/realtime_api_client.dart:161)
