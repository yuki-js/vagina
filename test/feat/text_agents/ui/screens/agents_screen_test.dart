import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vagina/feat/text_agents/model/text_agent.dart';
import 'package:vagina/feat/text_agents/model/text_agent_config.dart';
import 'package:vagina/feat/text_agents/model/text_agent_provider.dart';
import 'package:vagina/feat/text_agents/ui/screens/agents_screen.dart';
import 'package:vagina/feat/text_agents/ui/widgets/empty_agents_view.dart';
import 'package:vagina/feat/text_agents/ui/widgets/agent_card.dart';
import 'package:vagina/feat/text_agents/ui/widgets/agent_list_tile.dart';
import 'package:vagina/feat/text_agents/state/text_agent_providers.dart';
import 'package:vagina/core/state/repository_providers.dart';
import 'package:vagina/interfaces/text_agent_repository.dart';

/// Mock repository for testing
class MockTextAgentRepository implements TextAgentRepository {
  final List<TextAgent> _agents = [];
  String? _selectedId;

  @override
  Future<List<TextAgent>> getAll() async {
    return List.from(_agents);
  }

  @override
  Future<TextAgent?> getById(String id) async {
    try {
      return _agents.firstWhere((agent) => agent.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> save(TextAgent agent) async {
    final index = _agents.indexWhere((a) => a.id == agent.id);
    if (index >= 0) {
      _agents[index] = agent;
    } else {
      _agents.add(agent);
    }
  }

  @override
  Future<void> delete(String id) async {
    _agents.removeWhere((agent) => agent.id == id);
  }

  @override
  Future<String?> getSelectedAgentId() async {
    return _selectedId;
  }

  @override
  Future<void> setSelectedAgentId(String? id) async {
    _selectedId = id;
  }

  // Helper methods for testing
  void addAgent(TextAgent agent) {
    _agents.add(agent);
  }

  void clear() {
    _agents.clear();
    _selectedId = null;
  }
}

void main() {
  late MockTextAgentRepository mockRepo;

  setUp(() {
    mockRepo = MockTextAgentRepository();
  });

  tearDown(() {
    mockRepo.clear();
  });

  TextAgent createTestAgent({
    String? id,
    String? name,
    String? description,
  }) {
    return TextAgent(
      id: id ?? 'test_agent_1',
      name: name ?? 'Test Agent',
      description: description,
      config: const TextAgentConfig(
        provider: TextAgentProvider.azure,
        apiKey: 'test-key',
        apiIdentifier: 'https://test.openai.azure.com',
      ),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  Widget createTestApp(Widget child) {
    return ProviderScope(
      overrides: [
        textAgentRepositoryProvider.overrideWithValue(mockRepo),
      ],
      child: MaterialApp(
        home: child,
      ),
    );
  }

  group('EmptyAgentsView', () {
    testWidgets('displays empty state message', (WidgetTester tester) async {
      bool createAgentCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmptyAgentsView(
              onCreateAgent: () => createAgentCalled = true,
            ),
          ),
        ),
      );

      expect(find.text('テキストエージェントがありません'), findsOneWidget);
      expect(find.text('最初のエージェントを作成'), findsOneWidget);
      expect(find.byIcon(Icons.smart_toy_outlined), findsOneWidget);
    });

    testWidgets('calls onCreateAgent when button is tapped',
        (WidgetTester tester) async {
      bool createAgentCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmptyAgentsView(
              onCreateAgent: () => createAgentCalled = true,
            ),
          ),
        ),
      );

      await tester.tap(find.text('最初のエージェントを作成'));
      expect(createAgentCalled, isTrue);
    });
  });

  group('AgentCard', () {
    testWidgets('displays agent information', (WidgetTester tester) async {
      final agent = createTestAgent(
        name: 'Test Agent',
        description: 'Test Description',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AgentCard(
              agent: agent,
              isSelected: false,
              onTap: () {},
              onEdit: () {},
              onDelete: () {},
            ),
          ),
        ),
      );

      expect(find.text('Test Agent'), findsOneWidget);
      expect(find.text('Test Description'), findsOneWidget);
      // Config display string will show provider info for Azure
      expect(
        find.textContaining('Azure'),
        findsOneWidget,
      );
    });

    testWidgets('shows selected indicator when selected',
        (WidgetTester tester) async {
      final agent = createTestAgent();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AgentCard(
              agent: agent,
              isSelected: true,
              onTap: () {},
              onEdit: () {},
              onDelete: () {},
            ),
          ),
        ),
      );

      expect(find.text('選択中'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });

    testWidgets('calls callbacks when buttons are tapped',
        (WidgetTester tester) async {
      final agent = createTestAgent();
      bool tapCalled = false;
      bool editCalled = false;
      bool deleteCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AgentCard(
              agent: agent,
              isSelected: false,
              onTap: () => tapCalled = true,
              onEdit: () => editCalled = true,
              onDelete: () => deleteCalled = true,
            ),
          ),
        ),
      );

      // Tap card
      await tester.tap(find.byType(InkWell).first);
      expect(tapCalled, isTrue);

      // Tap edit button
      await tester.tap(find.byIcon(Icons.edit));
      expect(editCalled, isTrue);

      // Tap delete button
      await tester.tap(find.byIcon(Icons.delete));
      expect(deleteCalled, isTrue);
    });
  });

  group('AgentListTile', () {
    testWidgets('displays agent information in compact view',
        (WidgetTester tester) async {
      final agent = createTestAgent(
        name: 'Test Agent',
        description: 'Test Description',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AgentListTile(
              agent: agent,
              isSelected: false,
              onTap: () {},
              onEdit: () {},
              onDelete: () {},
            ),
          ),
        ),
      );

      expect(find.text('Test Agent'), findsOneWidget);
      expect(find.text('Test Description'), findsOneWidget);
      expect(find.byIcon(Icons.smart_toy), findsOneWidget);
    });

    testWidgets('shows selected badge when selected',
        (WidgetTester tester) async {
      final agent = createTestAgent();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AgentListTile(
              agent: agent,
              isSelected: true,
              onTap: () {},
              onEdit: () {},
              onDelete: () {},
            ),
          ),
        ),
      );

      expect(find.text('選択中'), findsOneWidget);
    });
  });

  group('AgentsScreen', () {
    testWidgets('shows empty state when no agents exist',
        (WidgetTester tester) async {
      await tester.pumpWidget(createTestApp(const AgentsScreen()));
      await tester.pumpAndSettle();

      expect(find.byType(EmptyAgentsView), findsOneWidget);
      expect(find.text('テキストエージェントがありません'), findsOneWidget);
    });

    testWidgets('displays list of agents when agents exist',
        (WidgetTester tester) async {
      mockRepo.addAgent(createTestAgent(
        id: 'agent1',
        name: 'Agent 1',
      ));
      mockRepo.addAgent(createTestAgent(
        id: 'agent2',
        name: 'Agent 2',
      ));

      await tester.pumpWidget(createTestApp(const AgentsScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Agent 1'), findsOneWidget);
      expect(find.text('Agent 2'), findsOneWidget);
      expect(find.byType(AgentCard), findsNWidgets(2));
    });

    testWidgets('toggles between grid and list view',
        (WidgetTester tester) async {
      mockRepo.addAgent(createTestAgent());

      await tester.pumpWidget(createTestApp(const AgentsScreen()));
      await tester.pumpAndSettle();

      // Should start in grid view
      expect(find.byType(GridView), findsOneWidget);
      expect(find.byType(AgentCard), findsOneWidget);

      // Toggle to list view
      await tester.tap(find.byIcon(Icons.view_list));
      await tester.pumpAndSettle();

      expect(find.byType(ListView), findsOneWidget);
      expect(find.byType(AgentListTile), findsOneWidget);

      // Toggle back to grid view
      await tester.tap(find.byIcon(Icons.grid_view));
      await tester.pumpAndSettle();

      expect(find.byType(GridView), findsOneWidget);
      expect(find.byType(AgentCard), findsOneWidget);
    });

    testWidgets('shows FAB for adding agent', (WidgetTester tester) async {
      await tester.pumpWidget(createTestApp(const AgentsScreen()));
      await tester.pumpAndSettle();

      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(find.byIcon(Icons.add), findsWidgets);
    });

    testWidgets('shows header with title and actions',
        (WidgetTester tester) async {
      await tester.pumpWidget(createTestApp(const AgentsScreen()));
      await tester.pumpAndSettle();

      expect(find.text('テキストエージェント'), findsOneWidget);
    });
  });

  group('Agent Selection', () {
   testWidgets('highlights selected agent', (WidgetTester tester) async {
     final agent = createTestAgent(id: 'agent1');
     mockRepo.addAgent(agent);
     await mockRepo.setSelectedAgentId('agent1');

     await tester.pumpWidget(createTestApp(const AgentsScreen()));
     await tester.pumpAndSettle();

     expect(find.text('選択中'), findsOneWidget);
   });
 });

  group('Agent Deletion', () {
    testWidgets('shows confirmation dialog before deleting',
        (WidgetTester tester) async {
      final agent = createTestAgent(id: 'agent1', name: 'Test Agent');
      mockRepo.addAgent(agent);

      await tester.pumpWidget(createTestApp(const AgentsScreen()));
      await tester.pumpAndSettle();

      // Tap delete button
      await tester.tap(find.byIcon(Icons.delete).first);
      await tester.pumpAndSettle();

      // Verify confirmation dialog
      expect(find.text('削除確認'), findsOneWidget);
      expect(find.text('「Test Agent」を削除しますか？'), findsOneWidget);
      expect(find.text('キャンセル'), findsOneWidget);
      expect(find.text('削除'), findsOneWidget);
    });

    testWidgets('cancels deletion when cancel is tapped',
        (WidgetTester tester) async {
      final agent = createTestAgent(id: 'agent1');
      mockRepo.addAgent(agent);

      await tester.pumpWidget(createTestApp(const AgentsScreen()));
      await tester.pumpAndSettle();

      // Tap delete button
      await tester.tap(find.byIcon(Icons.delete).first);
      await tester.pumpAndSettle();

      // Tap cancel
      await tester.tap(find.text('キャンセル'));
      await tester.pumpAndSettle();

      // Verify agent still exists
      expect(find.byType(AgentCard), findsOneWidget);
    });

    testWidgets('deletes agent when confirmed', (WidgetTester tester) async {
      final agent = createTestAgent(id: 'agent1');
      mockRepo.addAgent(agent);

      await tester.pumpWidget(createTestApp(const AgentsScreen()));
      await tester.pumpAndSettle();

      // Tap delete button
      await tester.tap(find.byIcon(Icons.delete).first);
      await tester.pumpAndSettle();

      // Tap delete
      await tester.tap(find.text('削除'));
      await tester.pumpAndSettle();

      // Verify snackbar and empty state
      expect(find.text('エージェントを削除しました'), findsOneWidget);
    });
  });

  group('Refresh Functionality', () {
    testWidgets('can refresh agents list', (WidgetTester tester) async {
      mockRepo.addAgent(createTestAgent());

      await tester.pumpWidget(createTestApp(const AgentsScreen()));
      await tester.pumpAndSettle();

      // Find RefreshIndicator and trigger refresh
      final refreshFinder = find.byType(RefreshIndicator);
      expect(refreshFinder, findsOneWidget);

      await tester.drag(refreshFinder, const Offset(0, 300));
      await tester.pumpAndSettle();

      // Verify list is still displayed
      expect(find.byType(AgentCard), findsOneWidget);
    });
  });
}
