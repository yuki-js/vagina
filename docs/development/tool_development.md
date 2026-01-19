# Tool Development Guide

## Overview

This guide explains how to develop and integrate new tools into the VAGINA voice agent system. The new text agent tools serve as reference implementations.

## Table of Contents

1. [Tool Architecture](#tool-architecture)
2. [Creating a New Tool](#creating-a-new-tool)
3. [Host API Integration](#host-api-integration)
4. [Testing Tools](#testing-tools)
5. [Tool Registration](#tool-registration)
6. [Best Practices](#best-practices)

## Tool Architecture

Tools in VAGINA run in an isolated sandbox environment for security and stability:

```
┌──────────────────────────────────────────┐
│          Voice Agent (Main)              │
│  ┌────────────────────────────────────┐  │
│  │     ToolSandboxManager             │  │
│  │  Manages tool runtime              │  │
│  └───────────┬────────────────────────┘  │
│              │ Host Call Protocol        │
│  ┌───────────▼────────────────────────┐  │
│  │       Host APIs                    │  │
│  │  - CallHostApi                     │  │
│  │  - TextAgentHostApi                │  │
│  │  - NotepadHostApi                  │  │
│  │  - MemoryHostApi                   │  │
│  └────────────────────────────────────┘  │
└──────────────────────────────────────────┘
                  │
                  │ Isolate Boundary
                  │
┌─────────────────▼─────────────────────────┐
│          Tool Sandbox (Isolate)           │
│  ┌────────────────────────────────────┐   │
│  │    Tool Implementations            │   │
│  │  - EndCallTool                     │   │
│  │  - QueryTextAgentTool              │   │
│  │  - GetTextAgentResponseTool        │   │
│  │  - ListAvailableAgentsTool         │   │
│  └────────────────────────────────────┘   │
│  ┌────────────────────────────────────┐   │
│  │    API Clients                     │   │
│  │  - CallApiClient                   │   │
│  │  - TextAgentApiClient              │   │
│  │  - NotepadApiClient                │   │
│  │  - MemoryApiClient                 │   │
│  └────────────────────────────────────┘   │
└───────────────────────────────────────────┘
```

## Creating a New Tool

### Step 1: Define the Tool

Create a new tool class implementing the `Tool` interface:

```dart
// lib/tools/builtin/my_new_tool.dart
import 'dart:convert';
import 'package:vagina/services/tools_runtime/tool.dart';
import 'package:vagina/services/tools_runtime/tool_context.dart';
import 'package:vagina/services/tools_runtime/tool_definition.dart';

class MyNewTool extends Tool {
  static const String toolKeyName = 'my_new_tool';
  
  
  
  @override
  ToolDefinition get definition => const ToolDefinition(
    toolKey: toolKeyName,
    displayName: '新しいツール',  // Japanese name
    displayDescription: 'ツールの説明',  // Japanese description
    categoryKey: 'custom',  // Category: system, memory, notepad, text_agent, call, custom
    iconKey: 'settings',  // Material icon name
    sourceKey: 'builtin',  // builtin, mcp, custom
    description: 'English description for AI. Explain when and how to use this tool.',
    parametersSchema: {
      'type': 'object',
      'properties': {
        'param1': {
          'type': 'string',
          'description': 'Description of param1',
        },
        'param2': {
          'type': 'number',
          'description': 'Description of param2',
        },
      },
      'required': ['param1'],
    },
  );
  
  @override
  Future<void> init() => _initOnce.run(() async {
    // Initialize tool (load resources, etc.)
    // This runs once when the tool is first created
  });
  
  @override
  Future<String> execute(Map<String, dynamic> args) async {
    // 1. Validate parameters
    final param1 = args['param1'] as String?;
    if (param1 == null || param1.isEmpty) {
      return jsonEncode({
        'success': false,
        'error': 'Missing required parameter: param1',
      });
    }
    
    final param2 = args['param2'] as num? ?? 0;
    
    // 2. Execute tool logic
    try {
      // Use context APIs for privileged operations
      final result = await _doWork(param1, param2, context);
      
      // 3. Return result as JSON string
      return jsonEncode({
        'success': true,
        'result': result,
      });
    } catch (e) {
      return jsonEncode({
        'success': false,
        'error': 'Tool execution failed: $e',
      });
    }
  }
  
  Future<dynamic> _doWork(String param1, num param2, ToolContext context) async {
    // Tool-specific implementation
    // Can use context APIs:
    // - context.notepadApi
    // - context.memoryApi
    // - context.textAgentApi
    // - context.callApi
    return 'Result';
  }
}
```

### Step 2: Create Host API (if needed)

If your tool needs privileged access not available in existing APIs, create a host API:

```dart
// lib/services/tools_runtime/apis/my_api.dart

/// Abstract API for tools
abstract class MyApi {
  Future<Map<String, dynamic>> doSomething(String param);
}

/// Client implementation (runs in isolate)
class MyApiClient implements MyApi {
  final Future<Map<String, dynamic>> Function(String method, Map<String, dynamic> args) hostCall;
  
  MyApiClient({required this.hostCall});
  
  @override
  Future<Map<String, dynamic>> doSomething(String param) async {
    try {
      final result = await hostCall('doSomething', {'param': param});
      
      if (result['success'] == true) {
        return result['data'] as Map<String, dynamic>;
      }
      
      throw result['error'] ?? 'Unknown error';
    } catch (e) {
      throw Exception('Error in doSomething: $e');
    }
  }
}
```

```dart
// lib/services/tools_runtime/host/my_host_api.dart

/// Host-side implementation (runs in main isolate)
class MyHostApi {
  final MyService _myService;
  
  MyHostApi(this._myService);
  
  Future<Map<String, dynamic>> handleCall(
    String method,
    Map<String, dynamic> args,
  ) async {
    try {
      switch (method) {
        case 'doSomething':
          return await _handleDoSomething(args);
        default:
          return {
            'success': false,
            'error': 'Unknown method: $method',
          };
      }
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }
  
  Future<Map<String, dynamic>> _handleDoSomething(
    Map<String, dynamic> args,
  ) async {
    final param = args['param'] as String;
    
    // Call service method
    final result = await _myService.doSomething(param);
    
    return {
      'success': true,
      'data': {'result': result},
    };
  }
}
```

### Step 3: Update ToolContext

Add your new API to the tool context:

```dart
// lib/services/tools_runtime/tool_context.dart

class ToolContext {
  final NotepadApi notepadApi;
  final MemoryApi memoryApi;
  final TextAgentApi textAgentApi;
  final CallApi callApi;
  final MyApi myApi;  // Add your new API
  
  ToolContext({
    required this.notepadApi,
    required this.memoryApi,
    required this.textAgentApi,
    required this.callApi,
    required this.myApi,  // Add to constructor
  });
}
```

### Step 4: Register in ToolSandboxManager

Update the sandbox manager to include your host API:

```dart
// lib/services/tools_runtime/tool_sandbox_manager.dart

class ToolSandboxManager {
  final MyService _myService;  // Add service
  MyHostApi? _myHostApi;  // Add host API
  
  ToolSandboxManager({
    required MyService myService,  // Add to constructor
    // ... other parameters
  }) : _myService = myService;
  
  Future<void> start() async {
    // Create host APIs
    _myHostApi = MyHostApi(_myService);
    
    // ... rest of initialization
  }
  
  Future<Map<String, dynamic>> _handleHostCall(...) async {
    switch (api) {
      case 'my':
        return await _myHostApi!.handleCall(method, args);
      // ... other cases
    }
  }
}
```

Update worker initialization:

```dart
// In _spawnWorker or similar
final context = ToolContext(
  notepadApi: NotepadApiClient(hostCall: _createHostCallFunction('notepad')),
  memoryApi: MemoryApiClient(hostCall: _createHostCallFunction('memory')),
  textAgentApi: TextAgentApiClient(hostCall: _createHostCallFunction('textAgent')),
  callApi: CallApiClient(hostCall: _createHostCallFunction('call')),
  myApi: MyApiClient(hostCall: _createHostCallFunction('my')),  // Add this
);
```

### Step 5: Register Tool in Catalog

Add your tool to the builtin catalog:

```dart
// lib/tools/builtin/builtin_tool_catalog.dart

import 'my_new_tool.dart';

class BuiltinToolCatalog {
  static List<ToolDefinition> listDefinitions() {
    return [
      // ... existing tools
      MyNewTool().definition,
    ];
  }
  
  static Tool? createTool(String toolKey) {
    switch (toolKey) {
      // ... existing cases
      case MyNewTool.toolKeyName:
        return MyNewTool();
      default:
        return null;
    }
  }
}
```

## Testing Tools

### Unit Test

```dart
// test/tools/my_new_tool_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:vagina/tools/builtin/my_new_tool.dart';

void main() {
  group('MyNewTool', () {
    late MyNewTool tool;
    late MockToolContext mockContext;
    
    setUp(() async {
      tool = MyNewTool();
      mockContext = MockToolContext();
      await tool.init();
    });
    
    test('executes successfully with valid parameters', () async {
      final result = await tool.execute({
        'param1': 'test',
        'param2': 42,
      }, mockContext);
      
      final data = jsonDecode(result) as Map<String, dynamic>;
      expect(data['success'], isTrue);
      expect(data['result'], isNotNull);
    });
    
    test('returns error for missing required parameter', () async {
      final result = await tool.execute({}, mockContext);
      
      final data = jsonDecode(result) as Map<String, dynamic>;
      expect(data['success'], isFalse);
      expect(data['error'], contains('param1'));
    });
  });
}
```

### Integration Test

```dart
// test/integration/my_tool_integration_test.dart

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MyNewTool Integration', () {
    test('end-to-end workflow', () async {
      // Setup real services with mock dependencies
      final service = MyService(/* dependencies */);
      final hostApi = MyHostApi(service);
      
      // Create tool with real API client
      final tool = MyNewTool();
      final context = ToolContext(
        myApi: MyApiClient(
          hostCall: (method, args) => hostApi.handleCall(method, args),
        ),
        // ... other APIs
      );
      
      // Execute tool
      final result = await tool.execute({
        'param1': 'integration test',
      }, context);
      
      // Verify
      final data = jsonDecode(result);
      expect(data['success'], isTrue);
    });
  });
}
```

## Tool Registration

Tools are registered automatically when the `ToolSandboxManager` starts. The registration flow:

1. `ToolService.initialize()` - Called at app startup
2. `ToolRegistry.registerFactory()` - Registers tool factories
3. `BuiltinToolCatalog.listDefinitions()` - Provides tool metadata
4. `ToolSandboxManager.start()` - Creates sandbox and initializes tools
5. Tools become available to voice agents

## Best Practices

### 1. Always Validate Parameters

```dart
Future<String> execute(Map<String, dynamic> args) async {
  // Validate all parameters before use
  final param = args['param'] as String?;
  if (param == null || param.isEmpty) {
    return jsonEncode({'success': false, 'error': 'Missing param'});
  }
  
  // ... use param safely
}
```

### 2. Use Consistent Response Format

```dart
// Success
return jsonEncode({
  'success': true,
  'data': result,
});

// Error
return jsonEncode({
  'success': false,
  'error': 'Error description',
});
```

### 3. Handle Errors Gracefully

```dart
try {
  final result = await doWork();
  return jsonEncode({'success': true, 'result': result});
} catch (e) {
  return jsonEncode({'success': false, 'error': 'Failed: $e'});
}
```

### 4. Keep Tools Stateless

Tools should not maintain state between executions. Use services or repositories for state.

### 5. Write Clear Descriptions

```dart
description: 'Clear description of what the tool does. '
             'Include when the AI should use it. '
             'Provide examples if helpful.'
```

### 6. Use Appropriate Categories

- `system`: System utilities (time, calculator)
- `memory`: Long-term storage
- `notepad`: Document operations
- `text_agent`: Text AI operations
- `call`: Call control
- `custom`: Custom tools

### 7. Implement Timeouts

```dart
final result = await Future.any([
  doWork(),
  Future.delayed(Duration(seconds: 30), () => throw TimeoutException()),
]);
```

### 8. Log Tool Execution

```dart
final logService = LogService();
logService.info('MyNewTool', 'Executing with param: $param');
```

## Example: The Four New Tools

### EndCallTool

**Purpose**: Programmatic call termination  
**Complexity**: Simple  
**Host API**: CallApi  
**Key Feature**: No parameters required

**Implementation Highlights**:
- Minimal validation
- Single API call
- Optional context parameter

### QueryTextAgentTool

**Purpose**: Query text agents  
**Complexity**: Medium  
**Host API**: TextAgentApi  
**Key Features**: 
- Three latency modes
- Async token handling
- Parameter validation

**Implementation Highlights**:
- Validates agent_id exists
- Validates expect_latency enum
- Returns different formats based on latency

### GetTextAgentResponseTool

**Purpose**: Retrieve async results  
**Complexity**: Simple  
**Host API**: TextAgentApi  
**Key Feature**: Token-based retrieval

**Implementation Highlights**:
- Token validation
- Status checking
- Multiple return formats

### ListAvailableAgentsTool

**Purpose**: List text agents  
**Complexity**: Simple  
**Host API**: TextAgentApi  
**Key Feature**: No parameters

**Implementation Highlights**:
- No validation needed
- Simple data transformation
- Always succeeds or throws

## Common Patterns

### Pattern 1: Simple Query Tool

```dart
@override
Future<String> execute(Map<String, dynamic> args) async {
  try {
    final result = await context.myApi.doSomething();
    return jsonEncode({'success': true, 'data': result});
  } catch (e) {
    return jsonEncode({'success': false, 'error': '$e'});
  }
}
```

### Pattern 2: Validated Input Tool

```dart
@override
Future<String> execute(Map<String, dynamic> args) async {
  // Validate
  final input = args['input'] as String?;
  if (input == null || input.isEmpty) {
    return jsonEncode({'success': false, 'error': 'Missing input'});
  }
  
  // Execute
  try {
    final result = await context.myApi.process(input);
    return jsonEncode({'success': true, 'result': result});
  } catch (e) {
    return jsonEncode({'success': false, 'error': '$e'});
  }
}
```

### Pattern 3: Async Operation Tool

```dart
@override
Future<String> execute(Map<String, dynamic> args) async {
  final mode = args['mode'] as String? ?? 'sync';
  
  if (mode == 'sync') {
    // Wait for result
    final result = await context.myApi.doWork();
    return jsonEncode({'success': true, 'result': result});
  } else {
    // Return token
    final token = await context.myApi.startWork();
    return jsonEncode({'success': true, 'token': token});
  }
}
```

## Debugging Tools

### Enable Tool Logging

In `lib/services/log_service.dart`:

```dart
logService.info('ToolName', 'Executing with args: ${args}');
logService.debug('ToolName', 'Result: $result');
```

### Test in Isolation

Create a standalone test that doesn't require the full app:

```dart
void main() async {
  final tool = MyNewTool();
  await tool.init();
  
  final mockContext = MockToolContext();
  final result = await tool.execute({'param': 'test'}, mockContext);
  
  print(result);
}
```

### Use Tool Tab

The Tools tab in the app shows all registered tools. Verify your tool appears with correct metadata.

## Related Documentation

- [Text Agent Architecture](text_agent_architecture.md)
- [Voice Agent Tools](../features/voice_agent_tools.md)
- [API Reference](../api/text_agent_api.md)

---

**Last Updated**: 2026-01-18  
**Version**: 1.0.0
