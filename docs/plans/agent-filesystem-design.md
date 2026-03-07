# Agent Virtual Filesystem Architecture Design (Revised)

**Project**: VAGINA - Voice AGI Notepad Agent  
**Feature**: Persistent Virtual Filesystem with Object-Oriented File Access  
**Date**: 2026-03-07  
**Author**: Architecture Team  
**Status**: Design Phase — Revised Architecture

---

## Executive Summary

This document defines the architecture for a **persistent virtual filesystem** that serves as both:

1. **Persistent storage layer** — Files survive across sessions, stored in [`KeyValueStore`](../lib/interfaces/key_value_store.dart:2)
2. **Object namespace layer** — Files are typed objects that expose different operations based on their file extension

### Core Design Philosophy

> **"This is not about building a robust filesystem, but about providing AI with an intuitive, file-based view of typed objects."**

The filesystem acts as a **persistent object bus** where:
- **Files are typed objects** identified by extension (`.md`, `.v2d.csv`, `.txt`)
- **`open(path)` instantiates objects** as Notepad tabs (runtime layer)
- **AI's toolset dynamically adapts** based on opened file types
- **Existing specialized tools** (document_*, spreadsheet_*) become methods on file objects

---

## Table of Contents

1. [Current Architecture & Limitations](#1-current-architecture--limitations)
2. [Design Goals & Requirements](#2-design-goals--requirements)
3. [Core Architecture: Storage vs Runtime](#3-core-architecture-storage-vs-runtime)
4. [File Type System & Extension Semantics](#4-file-type-system--extension-semantics)
5. [Data Model & Persistence](#5-data-model--persistence)
6. [Dynamic Tool Injection Architecture](#6-dynamic-tool-injection-architecture)
7. [Builtin Filesystem Operations](#7-builtin-filesystem-operations)
8. [Security & Path Normalization](#8-security--path-normalization)
9. [Notepad Integration](#9-notepad-integration)
10. [Files Browser UI](#10-files-browser-ui)
11. [Session History Integration](#11-session-history-integration)
12. [Implementation Phases](#12-implementation-phases)
13. [Testing Strategy](#13-testing-strategy)
14. [Agent Usage Patterns](#14-agent-usage-patterns)

---

## 1. Current Architecture & Limitations

### 1.1 Current Notepad System

```
┌─────────────────────────────────────────────────────┐
│ NotepadService (per-call, ephemeral)                │
│ ────────────────────────────────────────────────    │
│ • Tabs stored in-memory: List<NotepadTab>          │
│ • Lifecycle: created when call starts               │
│ • Destroyed: when call ends                         │
│ • Persistence: serialized to CallSession.notepadTabs│
│ • Limitations:                                       │
│   - No cross-session access                         │
│   - No hierarchical organization                    │
│   - No persistent identity (tabs are snapshots)     │
└─────────────────────────────────────────────────────┘
```

### 1.2 Problems with Current Approach

1. **Ephemeral**: Tabs only exist during active call
2. **No Cross-Session Memory**: Agent cannot access previous documents
3. **No Organization**: Flat list, no folders/categories
4. **Snapshot-Only History**: Session history captures final state, not evolution
5. **No Persistent Object Identity**: Cannot reference "that file from last week"

### 1.3 Design Insight: Two-Layer Architecture

The solution is to separate **persistence** from **runtime**:

```
Filesystem (Storage)          Notepad (Runtime)
┌──────────────────┐         ┌──────────────────┐
│ /docs/plan.md    │  open   │ Tab: plan.md     │
│ /data/sales.v2d  │  ────→  │ Tab: sales.v2d   │
│ (persistent)     │         │ (live object)    │
└──────────────────┘         └──────────────────┘
```

**Filesystem** =永続的な名前空間（ストレージ）  
**Notepad** = ランタイムオブジェクト（作業領域）  
**`open`** = インスタンス化の橋渡し

---

## 2. Design Goals & Requirements

### 2.1 Core Objective

**Provide AI with a file-based view for managing typed, persistent objects—NOT to build a complete POSIX filesystem.**

Focus:
- ✅ Simple, intuitive for AI
- ✅ Persistent across sessions
- ✅ Type-aware (extension-based polymorphism)
- ✅ Leverage existing Notepad + specialized tools
- ❌ NOT comprehensive OS-level filesystem features

### 2.2 Functional Requirements

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-1 | Files persist across app restarts | Critical |
| FR-2 | Files persist across call sessions | Critical |
| FR-3 | Hierarchical directory structure | Critical |
| FR-4 | Path-based addressing (`/dir/file.txt`) | High |
| FR-5 | `open` operation loads file into Notepad tab | Critical |
| FR-6 | File type determines available operations | Critical |
| FR-7 | Dynamic tool injection based on file type | Critical |
| FR-8 | Text file support (UTF-8) | Critical |
| FR-9 | 2D table support (`.v2d.*` extensions) | High |
| FR-10 | File search/find capability | Medium |
| FR-11 | Path normalization and security | Critical |

### 2.3 Non-Functional Requirements

| ID | Requirement | Target |
|----|-------------|--------|
| NFR-1 | Filesystem initialization time | < 500ms |
| NFR-2 | File read/write latency (small files) | < 100ms |
| NFR-3 | Maximum total filesystem size | 100MB |
| NFR-4 | **Maximum single file size** | **1MB** (AI-manageable) |
| NFR-5 | Maximum directory depth | 20 levels |
| NFR-6 | Concurrent access safety | Serialized operations |

**Changes from initial design:**
- NFR-4: Reduced from 10MB → 1MB (AI context limits)
- FR-13 (Atomic writes): Downgraded to Medium priority
- Removed "Future Considerations" (out of scope)

### 2.4 Constraints & Non-Goals

**What We WON'T Support:**

- ❌ File permissions/ownership
- ❌ Symbolic links / hard links
- ❌ File locking / concurrent writes
- ❌ File streaming (must fit in memory)
- ❌ Extended attributes
- ❌ Compression / encryption
- ❌ Empty directories (automatically created/deleted with files)
- ❌ Explicit `mkdir` tool (dirs created automatically)

---

## 3. System Implementation Architecture

This section covers the **internal system design** of the virtual filesystem — how data is persisted, how services are composed, and how tool calls flow through the system. AI-facing tool design and concepts are covered in later sections.

### 3.1 Virtual Filesystem Implementation

**Core components:**

```
┌─────────────────────────────────────────────────────┐
│                 KeyValueStore                       │
│  (JsonFileStore on native / localStorage on web)    │
│  Key: "virtual_fs_root" → entire filesystem as JSON │
└──────────────────────┬──────────────────────────────┘
                       ↑
┌──────────────────────┴──────────────────────────────┐
│         VirtualFilesystemRepository                 │
│  - In-memory cache: Map<String, VirtualFSNode>      │
│  - Load from KVStore on init                        │
│  - Persist to KVStore on every write                │
│  - Flat map keyed by absolute path → O(1) lookup    │
└──────────────────────┬──────────────────────────────┘
                       ↑
┌──────────────────────┴──────────────────────────────┐
│           VirtualFilesystemService                  │
│  - Path normalization & validation                  │
│  - Quota enforcement (100MB total, 1MB per file)    │
│  - Extension → type resolution (FileTypeRegistry)   │
│  - CRUD: read, write, delete, move, list, search    │
│  - Auto-create parent dirs on file write            │
│  - Auto-delete empty dirs on file delete            │
└─────────────────────────────────────────────────────┘
```

**Initialization flow:**

1. `RepositoryFactory.initialize()` creates `KeyValueStore`
2. `VirtualFilesystemRepository` loads `"virtual_fs_root"` key into memory
3. If key absent, initializes with root directory `/` only
4. All subsequent operations work on in-memory `Map<String, VirtualFSNode>`
5. Every mutation persists the entire map back to `KeyValueStore`

**Node storage format:**

```json
{
  "virtual_fs_root": {
    "version": "1.0",
    "nodes": {
      "/": { "type": "directory", "path": "/" },
      "/documents": { "type": "directory", "path": "/documents" },
      "/documents/notes.txt": {
        "type": "file",
        "path": "/documents/notes.txt",
        "content": "My notes..."
      }
    }
  }
}
```

Nodes are minimal: files have `path` + `content` only. Type is derived from extension at runtime via `FileTypeRegistry`. No timestamps or metadata stored.

### 3.2 Data Flow: Tool Call → Filesystem

When AI invokes a filesystem tool, the call travels through the existing tool sandbox architecture:

```
AI (Realtime API)
  │
  │  function_call: fs_list({path: "/"})
  ▼
CallService
  │  dispatches to ToolSandboxManager
  ▼
ToolSandboxManager
  │  routes to worker isolate
  ▼
ToolSandboxWorker (isolate)
  │  tool.execute(args)
  │  tool uses context.filesystemApi.list("/")
  ▼
FilesystemApiClient (in isolate)
  │  hostCall("list", {path: "/"})
  │  ── message passing via SendPort/ReceivePort ──
  ▼
FilesystemHostApi (main isolate)
  │  delegates to VirtualFilesystemService
  ▼
VirtualFilesystemService
  │  normalizes path, validates, calls repository
  ▼
VirtualFilesystemRepository
  │  reads from in-memory cache
  │  (on write: updates cache + persists to KVStore)
  ▼
KeyValueStore (JsonFileStore)
  │  writes JSON to disk / localStorage
```

**Key points:**
- Same isolate-based sandbox pattern as existing [`NotepadHostApi`](../lib/services/tools_runtime/host/notepad_host_api.dart:8) and [`ToolStorageHostApi`](../lib/services/tools_runtime/host/tool_storage_host_api.dart:8)
- `FilesystemApiClient` mirrors [`NotepadApiClient`](../lib/services/tools_runtime/apis/notepad_api.dart:65) design
- `FilesystemHostApi` mirrors [`NotepadHostApi`](../lib/services/tools_runtime/host/notepad_host_api.dart:8) design
- All filesystem calls are serialized through the host isolate (no concurrent write issues)

### 3.3 Integration Points

**RepositoryFactory:**

```dart
// Add to RepositoryFactory
static VirtualFilesystemRepository? _filesystemRepo;

static VirtualFilesystemRepository get filesystem {
  _ensureInitialized();
  return _filesystemRepo ??=
      JsonVirtualFilesystemRepository(_store!, logService: _logService);
}
```

**ToolContext extension:**

```dart
class ToolContext {
  final String toolKey;
  final CallApi callApi;
  final TextAgentApi textAgentApi;
  final ToolStorageApi toolStorageApi;
  final FilesystemApi filesystemApi;  // NEW (replaces NotepadApi)
}
```

**ToolSandboxManager routing:**

```dart
// In _handleHostCall():
switch (api) {
  case 'notepad':
    result = await _notepadHostApi.handleCall(method, args);
  case 'filesystem':  // NEW
    result = await _filesystemHostApi.handleCall(method, args);
  case 'call':
    result = await _callHostApi.handleCall(method, args);
  // ...
}
```

---

## 4. File Type System & Extension Semantics

### 4.1 Extension-Based Type System

**MIME types are eliminated.** File type is determined solely by extension.

```
Extension → Type → Available Operations
──────────────────────────────────────────
.txt      → text        → read, overwrite, patch
.md       → markdown    → read, overwrite, patch, (future: headings)
.json     → json        → read, write, (future: query)
.html     → html        → read, write
.csv      → csv         → read, write

.v2d.csv  → spreadsheet → read, add_rows, update_rows, delete_rows
.v2d.json → spreadsheet → read, add_rows, update_rows, delete_rows
.v2d.jsonl→ spreadsheet → read, add_rows, update_rows, delete_rows
```

### 4.2 Double Extension for 2D Tables

**Vagina 2D Table** extensions:

- `.v2d.csv` — CSV format 2D table
- `.v2d.json` — JSON array format 2D table
- `.v2d.jsonl` — JSON Lines format 2D table

**Rationale:** Explicit declaration that file is a structured table, not just raw CSV/JSON.

**Changes from initial design:**
- Removed Python (`.py`) support
- Removed XML (`.xml`) support
- Focused on text and tabular data only

### 4.3 Type Registration & Tool Mapping

```dart
// Pseudo-code type registry

class FileTypeRegistry {
  static Map<String, FileType> _types = {
    '.txt': FileType(
      name: 'text',
      tools: ['document_read', 'document_overwrite', 'document_patch'],
    ),
    '.md': FileType(
      name: 'markdown',
      tools: ['document_read', 'document_overwrite', 'document_patch'],
    ),
    '.v2d.csv': FileType(
      name: 'spreadsheet',
      tools: [
        'document_read',
        'spreadsheet_add_rows',
        'spreadsheet_update_rows',
        'spreadsheet_delete_rows',
      ],
    ),
    // ... extensible
  };
  
  static FileType? getType(String path) {
    // Match double extension first, then single
    if (path.endsWith('.v2d.csv')) return _types['.v2d.csv'];
    if (path.endsWith('.v2d.json')) return _types['.v2d.json'];
    // ... single extensions
    final ext = path.substring(path.lastIndexOf('.'));
    return _types[ext];
  }
}
```

---

## 5. Data Model & Persistence

### 5.1 Node Schema

**Design decisions:**
- ❌ Removed `createdAt`, `modifiedAt`, `size` metadata
- ❌ Removed `mimeType` field (use extension instead)
- ❌ Removed `VirtualDirectory` — directories are implicit (derived from file paths)
- ✅ Minimal data: path + content only
- ✅ Only files are stored; a directory exists iff any file has that path prefix

```dart
/// The only node type in the virtual filesystem.
class VirtualFile {
  final String path;           // e.g., "/documents/notes.txt"
  final String content;        // UTF-8 text

  const VirtualFile({
    required this.path,
    required this.content,
  });
  
  /// Derive type from extension (supports double extensions like .v2d.csv)
  String get extension {
    if (path.contains('.v2d.')) {
      final parts = path.split('.');
      if (parts.length >= 3) {
        return '.${parts[parts.length - 2]}.${parts[parts.length - 1]}';
      }
    }
    return path.substring(path.lastIndexOf('.'));
  }
  
  Map<String, dynamic> toJson() => {
    'path': path,
    'content': content,
  };
}
```

### 5.2 Storage Layout

**Single-key storage** in [`KeyValueStore`](../lib/interfaces/key_value_store.dart:2):

```json
{
  "virtual_fs_root": {
    "version": "1.0",
    "files": {
      "/documents/notes.txt": {
        "path": "/documents/notes.txt",
        "content": "My notes..."
      },
      "/data/sales.v2d.csv": {
        "path": "/data/sales.v2d.csv",
        "content": "name,revenue\nAlice,100\nBob,200"
      }
    }
  }
}
```

**Design principles:**
- Flat map keyed by path → O(1) file lookup
- Atomic read/write of entire filesystem
- **No directory nodes** — directories are derived at runtime by scanning path prefixes
- No empty directories (a directory vanishes when its last file is deleted)

### 5.3 Repository Interface

```dart
abstract class VirtualFilesystemRepository {
  Future<void> initialize();
  
  /// Read a file. Returns null if not found.
  Future<VirtualFile?> read(String path);
  
  /// Write (create or overwrite) a file.
  Future<void> write(VirtualFile file);
  
  /// Delete a file.
  Future<void> delete(String path);
  
  /// Move / rename a file.
  Future<void> move(String fromPath, String toPath);
  
  /// List immediate children of [path].
  /// Returns basenames only. Directories have trailing '/'.
  /// e.g. list('/documents') → ['notes.txt', 'projects/']
  /// When [recursive] is true, returns all descendant paths (relative).
  Future<List<String>> list(String path, {bool recursive = false});
  
  // No mkdir/rmdir — directories are implicit.
  // No search — can be built on top of list(recursive: true) if needed.
}
```

---

## 6. Dynamic Tool Injection Architecture

### 6.1 The Core Innovation

**Problem:** AI needs to know which operations are valid for each file type, but file types are extensible and operations vary.

**Solution:** `open(path)` dynamically injects type-specific tools into AI's session.

### 6.2 Mechanism: session.update

Leverages existing [`RealtimeApiClient.updateSessionConfig()`](../lib/services/realtime/realtime_api_client.dart:161):

```dart
// In RealtimeApiClient

void setTools(List<Tool> tools) {
  _tools = tools;
}

void updateSessionConfig() {
  if (!isConnected) return;
  _configureSession(); // Sends session.update event
}
```

This can be called **multiple times during a session** to change the tool list.

### 6.3 Open Workflow

```
┌─────────────────────────────────────────────────────┐
│ AI calls: open({path: "/data/sales.v2d.csv"})       │
└──────────────────┬──────────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────────┐
│ 1. FilesystemService reads file from storage        │
│ 2. Determines type from extension (.v2d.csv)        │
│ 3. Creates Notepad tab with content                 │
│ 4. Gets type-specific tools from FileTypeRegistry   │
│    → [spreadsheet_add_rows, spreadsheet_update_rows,│
│       spreadsheet_delete_rows, document_read]       │
└──────────────────┬──────────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────────┐
│ 5. CallService.addToolsForOpenedFile(path, tools)   │
│    - Adds tools to _activeTools set                 │
│    - Calls apiClient.setTools(_activeTools)         │
│    - Calls apiClient.updateSessionConfig()          │
│      → Sends session.update to AI                   │
└──────────────────┬──────────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────────┐
│ 6. AI receives updated tool list                    │
│    - spreadsheet_add_rows now available             │
│    - AI can call it with path as handle             │
└─────────────────────────────────────────────────────┘
```

### 6.4 Close Workflow

```
┌─────────────────────────────────────────────────────┐
│ AI calls: close({path: "/data/sales.v2d.csv"})      │
└──────────────────┬──────────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────────┐
│ 1. NotepadService gets tab content                  │
│ 2. FilesystemService writes back to storage         │
│ 3. NotepadService destroys tab                      │
└──────────────────┬──────────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────────┐
│ 4. CallService.removeToolsForClosedFile(path)       │
│    - Removes type-specific tools from _activeTools  │
│    - Calls apiClient.setTools(_activeTools)         │
│    - Calls apiClient.updateSessionConfig()          │
│      → Sends session.update to AI                   │
└──────────────────┬──────────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────────┐
│ 5. AI's tool palette updated                        │
│    - spreadsheet_* tools no longer available        │
└─────────────────────────────────────────────────────┘
```

### 6.5 Implementation Sketch

```dart
// In CallService

final Set<Tool> _baseTools = {};        // Always available
final Map<String, Set<Tool>> _fileTools = {};  // Per open file

void _handleOpenFile(String path, List<Tool> typeTools) {
  _fileTools[path] = typeTools.toSet();
  _updateToolSet();
}

void _handleCloseFile(String path) {
  _fileTools.remove(path);
  _updateToolSet();
}

void _updateToolSet() {
  // Merge base tools + all active file tools
  final allTools = <Tool>{
    ..._baseTools,
    for (final tools in _fileTools.values) ...tools,
  };
  
  _apiClient.setTools(allTools.toList());
  _apiClient.updateSessionConfig();  // Sends session.update
}
```

### 6.6 Why This Works

1. **Existing infrastructure** — `session.update` already implemented
2. **Token efficient** — Only active file tools are in context
3. **AI-friendly** — Tools appear/disappear naturally
4. **Extensible** — New file types = new tool mappings
5. **Type-safe** — AI can only call valid operations for file type

---

## 7. Builtin Filesystem Operations

### 7.1 Minimal Core Tools

**Unlike traditional fs_read/fs_write design, core operations are minimal:**

| Tool | Description | Always Available |
|------|-------------|------------------|
| `fs_list` | List directory contents | ✅ |
| `fs_open` | Open file into Notepad tab | ✅ |
| `fs_close` | Close tab and write back to FS | ✅ |
| `fs_delete` | Delete file/directory | ✅ |
| `fs_move` | Move/rename file | ✅ |

**Notable absences:**
- ❌ No `fs_read` — use `fs_open` + `document_read` instead
- ❌ No `fs_write` — use `fs_open` + `document_overwrite` + `fs_close` instead
- ❌ No `fs_mkdir` — directories created automatically

### 7.2 Type-Specific Tools (Injected on open)

**Text files** (`.txt`, `.md`, `.html`):
- `document_read(path)` — Read content
- `document_overwrite(path, content)` — Replace content
- `document_patch(path, patches)` — Apply diffs

**Spreadsheet files** (`.v2d.csv`, `.v2d.json`, `.v2d.jsonl`):
- `document_read(path)` — Read as structured data
- `spreadsheet_add_rows(path, rows)` — Add rows
- `spreadsheet_update_rows(path, rows)` — Update rows
- `spreadsheet_delete_rows(path, rowIndices)` — Delete rows

### 7.3 Tool: fs_list

```dart
class FsListTool extends Tool {
  static const String toolKeyName = 'fs_list';
  
  @override
  ToolDefinition get definition => ToolDefinition(
    toolKey: toolKeyName,
    displayName: 'ディレクトリ一覧',
    displayDescription: 'ディレクトリの内容を一覧表示します',
    categoryKey: 'filesystem',
    iconKey: 'folder',
    jsonSchema: {
      'type': 'object',
      'properties': {
        'path': {
          'type': 'string',
          'description': 'Directory path (default: /)',
        },
      },
    },
  );
  
  @override
  Future<String> execute(Map<String, dynamic> args) async {
    final path = args['path'] as String? ?? '/';
    
    try {
      final entries = await context.filesystemApi.list(path);
      // Returns basenames: ["notes.txt", "projects/"]
      
      return jsonEncode({
        'success': true,
        'path': path,
        'entries': entries,
      });
    } catch (e) {
      return jsonEncode({'success': false, 'error': e.toString()});
    }
  }
}
```

### 7.4 Tool: fs_open

```dart
class FsOpenTool extends Tool {
  static const String toolKeyName = 'fs_open';
  
  @override
  ToolDefinition get definition => ToolDefinition(
    toolKey: toolKeyName,
    displayName: 'ファイルを開く',
    displayDescription: 'ファイルをNotepadタブとして開きます',
    categoryKey: 'filesystem',
    iconKey: 'file_open',
    jsonSchema: {
      'type': 'object',
      'properties': {
        'path': {
          'type': 'string',
          'description': 'File path to open (e.g., /data/sales.v2d.csv)',
        },
      },
      'required': ['path'],
    },
  );
  
  @override
  Future<String> execute(Map<String, dynamic> args) async {
    final path = args['path'] as String;
    
    try {
      // 1. Read from filesystem
      final file = await context.filesystemApi.read(path);
      if (file == null) {
        return jsonEncode({'success': false, 'error': 'File not found'});
      }
      
      // 2. Register as open file (Notepad UI will observe this)
      await context.filesystemApi.openFile(path, file.content);
      
      // 3. Get file type and available tools
      final fileType = FileTypeRegistry.getType(path);
      final toolNames = fileType?.tools ?? ['document_read'];
      
      // 4. Trigger tool injection (via internal event)
      await context.callApi.injectToolsForFile(path, toolNames);
      
      return jsonEncode({
        'success': true,
        'path': path,
        'type': fileType?.name ?? 'unknown',
        'available_tools': toolNames,
        'note': 'File opened as Notepad tab. You can now use the listed tools.',
      });
    } catch (e) {
      return jsonEncode({'success': false, 'error': e.toString()});
    }
  }
}
```

### 7.5 Tool: fs_close

```dart
class FsCloseTool extends Tool {
  static const String toolKeyName = 'fs_close';
  
  @override
  ToolDefinition get definition => ToolDefinition(
    toolKey: toolKeyName,
    displayName: 'ファイルを閉じる',
    displayDescription: 'Notepadタブを閉じてファイルシステムに保存します',
    categoryKey: 'filesystem',
    iconKey: 'close',
    jsonSchema: {
      'type': 'object',
      'properties': {
        'path': {
          'type': 'string',
          'description': 'File path to close',
        },
      },
      'required': ['path'],
    },
  );
  
  @override
  Future<String> execute(Map<String, dynamic> args) async {
    final path = args['path'] as String;
    
    try {
      // 1. Get open file state
      final openFile = await context.filesystemApi.getOpenFile(path);
      if (openFile == null) {
        return jsonEncode({'success': false, 'error': 'File not open'});
      }
      
      // 2. Write back to filesystem
      await context.filesystemApi.write(VirtualFile(
        path: path,
        content: openFile.content,
      ));
      
      // 3. Close open file (Notepad UI will observe removal)
      await context.filesystemApi.closeFile(path);
      
      // 4. Remove injected tools
      await context.callApi.removeToolsForFile(path);
      
      return jsonEncode({
        'success': true,
        'path': path,
        'note': 'File closed and saved to filesystem.',
      });
    } catch (e) {
      return jsonEncode({'success': false, 'error': e.toString()});
    }
  }
}
```

---

## 8. Security & Path Normalization

### 8.1 Path Normalization Algorithm

```dart
String _normalizePath(String path) {
  // 1. Ensure absolute path
  if (!path.startsWith('/')) {
    throw FilesystemException('Path must be absolute: $path');
  }
  
  // 2. Remove trailing slash (except root)
  if (path != '/' && path.endsWith('/')) {
    path = path.substring(0, path.length - 1);
  }
  
  // 3. Normalize components
  final parts = path.split('/').where((p) => p.isNotEmpty && p != '.').toList();
  final normalized = <String>[];
  
  for (final part in parts) {
    if (part == '..') {
      if (normalized.isNotEmpty) {
        normalized.removeLast();  // Go up one level
      }
      // Ignore .. at root
    } else {
      normalized.add(part);
    }
  }
  
  return normalized.isEmpty ? '/' : '/${normalized.join('/')}';
}
```

**Examples:**

```dart
_normalizePath('/documents/../notes.txt')     → '/notes.txt'
_normalizePath('/documents/./notes.txt')      → '/documents/notes.txt'
_normalizePath('/documents//notes.txt')       → '/documents/notes.txt'
_normalizePath('/../../../etc/passwd')        → '/etc/passwd' (jailed to /)
```

### 8.2 Root Jail

All paths are confined to the virtual root `/`. There is no way to escape to the host OS filesystem.

### 8.3 Reserved Paths (Dynamic)

**Changes from initial design:** No hardcoded reserved paths list.

Instead, **runtime checks** prevent conflicts:

```dart
// System can dynamically reserve paths
final _systemPaths = <String>{};  // Populated at runtime

void _reservePath(String path) {
  _systemPaths.add(path);
}

void _checkReservedPath(String path) {
  if (_systemPaths.contains(path) || 
      path.startsWith('/system/') ||
      path.startsWith('/tmp/')) {
    throw FilesystemException('Access denied: reserved path');
  }
}
```

### 8.4 Size Quotas

```dart
// In write():
final currentSize = await _repository.getTotalSize();
final newSize = currentSize + content.length;

if (newSize > 100 * 1024 * 1024) {  // 100MB
  throw FilesystemException('Filesystem quota exceeded');
}

if (content.length > 1024 * 1024) {  // 1MB per file
  throw FilesystemException('File too large (max 1MB)');
}
```

### 8.5 Path Validation

```dart
void _validatePath(String path) {
  if (path.length > 512) {
    throw FilesystemException('Path too long (max 512 chars)');
  }
  
  if (path.contains('\x00')) {
    throw FilesystemException('Path contains null byte');
  }
  
  final normalized = _normalizePath(path);
  _checkReservedPath(normalized);
  
  return normalized;
}
```

---

## 9. Notepad Integration

### 9.1 Notepad = Human View of Open Files

**Notepad is not a separate API layer.** It is purely a **UI rendering concern** — the human-visible representation of files that the AI has opened via `fs_open`.

The former Notepad API is fully absorbed into the Filesystem API. There is no `NotepadApi` interface.

```
Filesystem API (single authority)
┌─────────────────────────────────────────┐
│ VirtualFilesystemRepository             │
│   read / write / delete / move / list   │
│                                         │
│ Open file tracking (runtime state)      │
│   openFiles: Map<path, OpenFileState>   │
│                                         │
│   fs_open  → loads file, adds to open   │
│   fs_close → saves content, removes     │
└─────────────────────────────────────────┘
         │
         ▼ (UI observes)
┌─────────────────────────────────────────┐
│ Notepad UI (human view)                 │
│   Renders open files as tabs            │
│   File type derived from extension      │
│   No mimeType, no timestamps            │
└─────────────────────────────────────────┘
```

### 9.2 Open File State

```dart
/// Runtime state for a file currently opened by the AI.
/// Not persisted — reconstructed on session start if needed.
class OpenFileState {
  final String path;       // filesystem path = unique key
  final String content;    // current working content (may differ from persisted)

  const OpenFileState({
    required this.path,
    required this.content,
  });

  /// Display name derived from path
  String get title => path.split('/').last;

  /// File type derived from extension (for UI rendering)
  String get extension {
    if (path.contains('.v2d.')) {
      final parts = path.split('.');
      if (parts.length >= 3) {
        return '.${parts[parts.length - 2]}.${parts[parts.length - 1]}';
      }
    }
    return path.substring(path.lastIndexOf('.'));
  }
}
```

### 9.3 What Happened to Notepad API?

| Old Notepad API method | New location |
|---|---|
| `createTab(content, mimeType, title)` | `fs_open(path)` — content from filesystem, type from extension |
| `updateTab(tabId, content)` | `document_overwrite(path, content)` / `document_patch(path, patches)` |
| `closeTab(tabId)` | `fs_close(path)` |
| `listTabs()` | Query `openFiles` map in FilesystemService |
| `getTab(tabId)` | `document_read(path)` |
| `getTabByPath(fsPath)` | Direct lookup in `openFiles` map by path |

**Key insight:** Tab ID is replaced by filesystem path. Path is the universal handle.

---

## 10. Files Browser UI

> **Out of scope for initial implementation.** The Files Browser UI (top-level screen for browsing/managing filesystem outside of calls) is deferred to a future phase. The AI interacts with the filesystem exclusively through tools during calls.

---

## 11. Session History Integration

> **Out of scope for initial implementation.** Session-level file activity tracking and history rollback are deferred to a future phase. Files persist across sessions via the filesystem; no per-session snapshots or references are recorded initially.

---

## 12. Implementation Phases

### Phase 1: Core Filesystem

**Deliverables:**
- [ ] `VirtualFile` model (no `VirtualDirectory` — directories are implicit)
- [ ] `VirtualFilesystemRepository` implementation
- [ ] `VirtualFilesystemService` with path normalization
- [ ] Integration with `RepositoryFactory`
- [ ] Unit tests (path ops, validation, quotas)

**Files:**
```
lib/models/virtual_file.dart
lib/interfaces/virtual_filesystem_repository.dart
lib/repositories/json_virtual_filesystem_repository.dart
lib/services/virtual_filesystem_service.dart
```

### Phase 2: Filesystem API for Tools

**Deliverables:**
- [ ] `FilesystemApi` abstract interface
- [ ] `FilesystemApiClient` for isolates
- [ ] `FilesystemHostApi` for host side
- [ ] Wire into `ToolContext` and `ToolSandboxManager`
- [ ] Integration tests

**Files:**
```
lib/services/tools_runtime/apis/filesystem_api.dart
lib/services/tools_runtime/host/filesystem_host_api.dart
```

### Phase 3: Core Filesystem Tools

**Deliverables:**
- [ ] `fs_list`, `fs_open`, `fs_close` tools
- [ ] `fs_delete`, `fs_move` tools
- [ ] File type registry
- [ ] Tool injection logic in `CallService`
- [ ] Unit tests for each tool

**Files:**
```
lib/tools/builtin/filesystem/fs_list_tool.dart
lib/tools/builtin/filesystem/fs_open_tool.dart
lib/tools/builtin/filesystem/fs_close_tool.dart
lib/tools/builtin/filesystem/fs_delete_tool.dart
lib/tools/builtin/filesystem/fs_move_tool.dart
lib/services/file_type_registry.dart
```

### Phase 4: Tool Integration & Open/Close Wiring

**Deliverables:**
- [ ] `OpenFileState` runtime model
- [ ] Update `document_*` tools to work with filesystem paths
- [ ] Update `spreadsheet_*` tools to work with filesystem paths
- [ ] Dynamic tool injection on `fs_open`
- [ ] Tool removal on `fs_close`
- [ ] Notepad UI observes open files (rendering only)
- [ ] Integration tests

**Files:**
```
lib/models/open_file_state.dart
lib/tools/builtin/document/* (modify)
lib/tools/builtin/spreadsheet/* (modify)
lib/services/call_service.dart (modify)
```

---

## 13. Testing Strategy

### 13.1 Approach

Testing is organized **per-layer**, with special attention to migration-critical boundaries where Notepad API is absorbed into the Filesystem API and existing tools are rewired.

No data model tests — `VirtualFile` is a trivial value class with no logic worth testing independently.

### 13.2 Unit Tests: Persistence Layer

**`VirtualFilesystemRepository` / `JsonVirtualFilesystemRepository`:**
```dart
test('write then read returns same file')
test('write creates file at given path')
test('read returns null for nonexistent path')
test('delete removes file')
test('delete nonexistent path is a no-op')
test('move renames file path')
test('move to existing path overwrites')
test('list returns basenames of direct children')
test('list returns trailing / for implicit directories')
test('list with recursive=true returns all descendants')
test('list on empty directory returns empty list')
test('write enforces 1MB per-file size limit')
test('write enforces 100MB total quota')
test('persistence: write, reload from KVS, read succeeds')
```

### 13.3 Unit Tests: Service Layer

**`VirtualFilesystemService` (path normalization, validation):**
```dart
test('normalizePath removes double slashes')
test('normalizePath resolves .. references')
test('normalizePath resolves . references')
test('normalizePath prevents escape from root via ..')
test('normalizePath strips trailing slash except root')
test('validatePath rejects paths over 512 chars')
test('validatePath rejects null bytes')
test('validatePath rejects reserved paths (/system/*, /tmp/*)')
```

**`FileTypeRegistry`:**
```dart
test('getType returns text for .txt')
test('getType returns markdown for .md')
test('getType returns spreadsheet for .v2d.csv')
test('getType matches double extension before single')
test('getType returns correct tool list per type')
test('getType returns null for unknown extension')
```

### 13.4 Tool Behavior Tests

Simulate AI tool calls (mock the isolate boundary) and verify correct responses:

**Core filesystem tools:**
```dart
test('fs_list returns basenames with trailing / for dirs')
test('fs_list with recursive=true returns full tree')
test('fs_list on nonexistent path returns error')
test('fs_open on existing file returns success + available_tools')
test('fs_open on nonexistent path returns error')
test('fs_open creates OpenFileState entry')
test('fs_close saves content back to repository')
test('fs_close removes OpenFileState entry')
test('fs_close on unopened file returns error')
test('fs_delete removes file from repository')
test('fs_move renames file in repository')
```

**Type-specific tools (after fs_open):**
```dart
test('document_read returns content of opened file')
test('document_read on unopened file returns error')
test('document_overwrite replaces content of opened file')
test('document_patch applies diff to opened file')
test('spreadsheet_add_rows appends to opened .v2d.csv')
test('spreadsheet_update_rows modifies rows in opened .v2d.csv')
test('spreadsheet_delete_rows removes rows from opened .v2d.csv')
```

### 13.5 Tool Set Update Tests

Verify that `session.update` is triggered correctly when tools are injected/removed:

```dart
test('fs_open injects type-specific tools into session')
test('fs_open for .txt injects document_read, document_overwrite, document_patch')
test('fs_open for .v2d.csv injects spreadsheet_* tools')
test('fs_close removes injected tools from session')
test('opening two files = union of both tool sets')
test('closing one file keeps other files tools')
test('closing all files leaves only base tools')
test('session.update called exactly once per open/close')
```

### 13.6 Migration-Critical Tests

These tests specifically cover the **Notepad API → FS API absorption** and the **existing tool API rewiring**. These boundaries are high-risk because:
- UI layer previously connected to NotepadApi; now connects to FS open-file state
- Existing document/spreadsheet tools previously used tab IDs; now use filesystem paths
- Open status check is a new precondition for tool execution

**Notepad → Filesystem migration:**
```dart
test('Notepad UI observes openFiles map, not NotepadApi')
test('Opening file via fs_open makes it visible in Notepad UI')
test('Closing file via fs_close removes it from Notepad UI')
test('Notepad tab renders content from OpenFileState')
test('Notepad tab title derived from path, not explicit title field')
test('Notepad tab type derived from extension, not mimeType')
```

**Existing tool API rewiring:**
```dart
test('document_read accepts path parameter instead of tabId')
test('document_overwrite accepts path parameter instead of tabId')
test('document_patch accepts path parameter instead of tabId')
test('spreadsheet_add_rows accepts path parameter instead of tabId')
test('tools reject calls when file is not open (no OpenFileState)')
test('tools work correctly after fs_open creates OpenFileState')
test('tools reflect changes in OpenFileState content, not repository')
test('fs_close persists OpenFileState content changes to repository')
```

### 13.7 Performance Tests

```dart
test('filesystem initializes under 500ms with 100 files')
test('file write completes under 100ms')
test('fs_open + tool injection under 200ms')
```

---

## 14. Agent Usage Patterns

### 14.1 Basic File Management

```javascript
// List files
fs_list({path: "/"})
→ {entries: [{path: "/notes.txt", type: "file"}, ...]}

// Open file (injects tools)
fs_open({path: "/notes.txt"})
→ {success: true, type: "text", available_tools: ["document_read", "document_overwrite", "document_patch"]}

// Read content
document_read({path: "/notes.txt"})
→ {content: "My notes..."}

// Edit content
document_patch({path: "/notes.txt", patches: [...]})

// Close (saves to filesystem)
fs_close({path: "/notes.txt"})
→ {success: true}
```

### 14.2 Working with Spreadsheets

```javascript
// Open spreadsheet (injects spreadsheet_* tools)
fs_open({path: "/data/sales.v2d.csv"})
→ {
    success: true,
    type: "spreadsheet",
    available_tools: [
      "document_read",
      "spreadsheet_add_rows",
      "spreadsheet_update_rows",
      "spreadsheet_delete_rows"
    ]
  }

// Read as structured data
document_read({path: "/data/sales.v2d.csv"})
→ {content: "name,revenue\nAlice,100\nBob,200"}

// Add rows
spreadsheet_add_rows({
  path: "/data/sales.v2d.csv",
  rows: [{name: "Charlie", revenue: 300}]
})

// Close
fs_close({path: "/data/sales.v2d.csv"})
```

### 14.3 Organizing Knowledge Base

```javascript
// Create hierarchy by writing files (dirs auto-created)
fs_open({path: "/knowledge/programming/python_tips.md"})
// ... edit ...
fs_close({path: "/knowledge/programming/python_tips.md"})

fs_open({path: "/knowledge/languages/japanese.md"})
// ... edit ...
fs_close({path: "/knowledge/languages/japanese.md"})

```

### 14.4 System Instructions Update

Add to [`AssistantConfig.defaultInstructions`](../lib/models/assistant_config.dart:20):

```markdown
## Filesystem Access

You have access to a persistent filesystem that survives across conversations.

### Core Operations

- `fs_list(path)` — List directory contents
- `fs_open(path)` — Open file as Notepad tab (enables type-specific tools)
- `fs_close(path)` — Close tab and save to filesystem
- `fs_delete(path)` — Delete file or directory
- `fs_move(fromPath, toPath)` — Move/rename

### Workflow

1. **List files**: `fs_list({path: "/documents"})`
2. **Open file**: `fs_open({path: "/documents/notes.txt"})`
   - This loads the file into Notepad and gives you type-specific tools
3. **Edit**: Use `document_read`, `document_overwrite`, `document_patch`, `spreadsheet_add_rows`, etc.
   - Available tools depend on file type (extension)
4. **Close**: `fs_close({path: "/documents/notes.txt"})`
   - Saves changes back to filesystem

### File Types

- `.txt`, `.md`, `.html` → text files (document_* tools)
- `.v2d.csv`, `.v2d.json`, `.v2d.jsonl` → spreadsheets (spreadsheet_* tools)

### Path Conventions

- All paths are absolute (start with `/`)
- Use forward slashes: `/documents/notes.txt`
- Directories created automatically when you create files
- No empty directories

The filesystem is shared across all conversations. Files you create will be available in future sessions.
```

---

## Conclusion

This revised design provides a **persistent, type-aware filesystem** that:

✅ **Leverages existing infrastructure** (Notepad, specialized tools, session.update)  
✅ **Provides object-oriented semantics for AI** via extension-based polymorphism  
✅ **Dynamically adapts AI capabilities** based on opened file types  
✅ **Maintains simplicity** — focus on AI usability, not POSIX completeness  
✅ **Backwards compatible** — existing tools become methods on file objects  
✅ **Extensible** — new file types = new tool mappings  

**Key Innovation:** `open(path)` is not just I/O—it's **object instantiation** that dynamically injects type-specific capabilities into the AI's session.

The filesystem transforms from a passive storage layer into an active **object bus** that mediates between persistent data and runtime operations, enabling agents to build true long-term memory with rich, typed interactions.

---

**Next Steps:**

1. Review and approve revised design
2. Create implementation tasks
3. Start Phase 1: Core Filesystem
4. Iterate based on learnings

**Estimated Timeline:** 7 weeks for full implementation

**Total Files to Create:** ~35  
**Total Files to Modify:** ~15  
**Total Tests:** ~60+
