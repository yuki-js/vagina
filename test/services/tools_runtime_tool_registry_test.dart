import 'package:flutter_test/flutter_test.dart';
import 'package:vagina/services/notepad_service.dart';
import 'package:vagina/services/tools_runtime/tool.dart';
import 'package:vagina/services/tools_runtime/tool_context.dart';
import 'package:vagina/services/tools_runtime/tool_definition.dart';
import 'package:vagina/services/tools_runtime/tool_factory.dart';
import 'package:vagina/services/tools_runtime/tool_registry.dart';

class _TrackingTool implements Tool {
  final int instanceId;
  final void Function(int instanceId)? onInitCalled;

  _TrackingTool({
    required this.instanceId,
    required this.onInitCalled,
  });

  @override
  ToolDefinition get definition => ToolDefinition(
        toolKey: 'tracking_tool',
        displayName: 'Tracking',
        displayDescription: 'Tracking tool',
        categoryKey: 'custom',
        iconKey: 'extension',
        sourceKey: 'custom',
        description: 'Tracking tool',
        parametersSchema: const {
          'type': 'object',
          'properties': {},
        },
      );

  @override
  Future<void> init() async {
    onInitCalled?.call(instanceId);
  }

  @override
  Future<String> execute(ToolArgs args, ToolContext context) async {
    return '{"ok":true}';
  }
}

class _TrackingToolFactory implements ToolFactory {
  int createToolCallCount = 0;
  final List<_TrackingTool> createdInstances = <_TrackingTool>[];
  final void Function(int instanceId)? onInitCalled;

  _TrackingToolFactory({this.onInitCalled});

  @override
  Tool createTool() {
    createToolCallCount++;
    final tool = _TrackingTool(
      instanceId: createToolCallCount,
      onInitCalled: onInitCalled,
    );
    createdInstances.add(tool);
    return tool;
  }
}

class _OtherTool implements Tool {
  @override
  ToolDefinition get definition => const ToolDefinition(
        toolKey: 'other_tool',
        displayName: 'Other',
        displayDescription: 'Other tool',
        categoryKey: 'custom',
        iconKey: 'extension',
        sourceKey: 'custom',
        description: 'Other tool',
        parametersSchema: {
          'type': 'object',
          'properties': {},
        },
      );

  @override
  Future<void> init() async {}

  @override
  Future<String> execute(ToolArgs args, ToolContext context) async => '{}';
}

class _OtherToolFactory implements ToolFactory {
  int createToolCallCount = 0;

  @override
  Tool createTool() {
    createToolCallCount++;
    return _OtherTool();
  }
}

void main() {
  group('ToolRegistry (tools_runtime)', () {
    test('listDefinitions caches definitions and only instantiates tools once', () {
      final registry = ToolRegistry();
      registry.invalidateCache();

      final f1 = _TrackingToolFactory();
      final f2 = _OtherToolFactory();
      registry.registerFactory(f1);
      registry.registerFactory(f2);

      final first = registry.listDefinitions();
      expect(first, hasLength(2));
      expect(f1.createToolCallCount, 1);
      expect(f2.createToolCallCount, 1);

      final second = registry.listDefinitions();
      expect(identical(first, second), isTrue, reason: 'cached list instance should be reused');
      expect(f1.createToolCallCount, 1, reason: 'should not instantiate again on cache hit');
      expect(f2.createToolCallCount, 1, reason: 'should not instantiate again on cache hit');
    });

    test('invalidateCache causes re-instantiation on next listDefinitions()', () {
      final registry = ToolRegistry();
      registry.invalidateCache();

      final f1 = _TrackingToolFactory();
      final f2 = _OtherToolFactory();
      registry.registerFactory(f1);
      registry.registerFactory(f2);

      registry.listDefinitions();
      expect(f1.createToolCallCount, 1);
      expect(f2.createToolCallCount, 1);

      registry.invalidateCache();

      registry.listDefinitions();
      expect(f1.createToolCallCount, 2);
      expect(f2.createToolCallCount, 2);
    });

    test('buildRuntimeForCall creates fresh instances per call (not cached ones)', () {
      final registry = ToolRegistry();
      registry.invalidateCache();

      final f1 = _TrackingToolFactory();
      registry.registerFactory(f1);

      // This should create one instance for definition caching.
      registry.listDefinitions();
      expect(f1.createToolCallCount, 1);
      final cachedInstance = f1.createdInstances.single;

      final ctx = ToolContext(notepadService: NotepadService());

      final runtime1 = registry.buildRuntimeForCall(ctx);
      final runtimeTool1 = runtime1.getTool('tracking_tool');
      expect(runtimeTool1, isNotNull);
      expect(identical(runtimeTool1, cachedInstance), isFalse);

      final runtime2 = registry.buildRuntimeForCall(ctx);
      final runtimeTool2 = runtime2.getTool('tracking_tool');
      expect(runtimeTool2, isNotNull);
      expect(identical(runtimeTool2, runtimeTool1), isFalse, reason: 'each call must get a new tool instance');

      expect(f1.createToolCallCount, 3, reason: '1 for listDefinitions + 1 per buildRuntimeForCall');
    });

    test('listDefinitions never calls Tool.init()', () {
      final initCalled = <int>[];
      final registry = ToolRegistry();
      registry.invalidateCache();

      final f1 = _TrackingToolFactory(onInitCalled: initCalled.add);
      registry.registerFactory(f1);

      registry.listDefinitions();

      expect(initCalled, isEmpty);
    });
  });
}
