import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vagina/feat/text_agents/model/text_agent.dart';
import 'package:vagina/feat/text_agents/model/text_agent_config.dart';
import 'package:vagina/feat/text_agents/model/text_agent_provider.dart';
import 'package:vagina/feat/text_agents/ui/screens/agent_form_screen.dart';
import 'package:vagina/interfaces/text_agent_repository.dart';
import 'package:vagina/core/state/repository_providers.dart';

/// Mock repository for testing
class MockTextAgentRepository implements TextAgentRepository {
  final List<TextAgent> _agents = [];
  String? _selectedId;

  @override
  Future<List<TextAgent>> getAll() async => List.from(_agents);

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
  Future<String?> getSelectedAgentId() async => _selectedId;

  @override
  Future<void> setSelectedAgentId(String? id) async {
    _selectedId = id;
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

  TextAgent createTestAgent({String? name}) {
    return TextAgent(
      id: 'test_agent_1',
      name: name ?? 'Test Agent',
      description: 'Test Description',
      config: const TextAgentConfig(
        provider: TextAgentProvider.azure,
        apiKey: 'test-key',
        apiIdentifier: 'https://test.openai.azure.com',
      ),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  group('AgentFormScreen - Create Mode', () {
    testWidgets('displays correct title for new agent',
        (WidgetTester tester) async {
      await tester.pumpWidget(createTestApp(const AgentFormScreen()));
      await tester.pumpAndSettle();

      expect(find.text('エージェントを追加'), findsOneWidget);
    });

    testWidgets('displays all required form fields',
        (WidgetTester tester) async {
      await tester.pumpWidget(createTestApp(const AgentFormScreen()));
      await tester.pumpAndSettle();

      // Basic fields
      expect(find.widgetWithText(TextFormField, 'エージェント名 *'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, '説明 (オプション)'), findsOneWidget);

      // Configuration fields
      expect(find.text('プロバイダー *'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'モデル *'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'APIキー *'), findsOneWidget);
    });

    testWidgets('has OpenAI as default provider',
        (WidgetTester tester) async {
      await tester.pumpWidget(createTestApp(const AgentFormScreen()));
      await tester.pumpAndSettle();

      // Check that OpenAI is selected and model field is shown
      expect(find.text('OpenAI'), findsWidgets);
      expect(find.widgetWithText(TextFormField, 'モデル *'), findsOneWidget);
    });

    testWidgets('provider dropdown shows all options',
        (WidgetTester tester) async {
      await tester.pumpWidget(createTestApp(const AgentFormScreen()));
      await tester.pumpAndSettle();

      // Tap provider dropdown
      await tester.tap(find.byType(DropdownButtonFormField<TextAgentProvider>));
      await tester.pumpAndSettle();

      // Check all providers are shown
      expect(find.text('OpenAI'), findsWidgets);
      expect(find.text('Azure OpenAI'), findsOneWidget);
      expect(find.text('LiteLLM Proxy'), findsOneWidget);
      expect(find.text('Custom Endpoint'), findsOneWidget);
    });

    testWidgets('changing provider updates endpoint label',
        (WidgetTester tester) async {
      await tester.pumpWidget(createTestApp(const AgentFormScreen()));
      await tester.pumpAndSettle();

      // Default is OpenAI with "モデル" label
      expect(find.widgetWithText(TextFormField, 'モデル *'), findsOneWidget);

      // Change to Azure
      await tester.tap(find.byType(DropdownButtonFormField<TextAgentProvider>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Azure OpenAI'));
      await tester.pumpAndSettle();

      // Should now show "エンドポイント" label
      expect(find.widgetWithText(TextFormField, 'エンドポイント *'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'モデル *'), findsNothing);
    });
  });

  group('AgentFormScreen - Edit Mode', () {
    testWidgets('displays correct title for editing',
        (WidgetTester tester) async {
      final agent = createTestAgent();
      await tester.pumpWidget(createTestApp(AgentFormScreen(agent: agent)));
      await tester.pumpAndSettle();

      expect(find.text('エージェントを編集'), findsOneWidget);
    });

    testWidgets('populates form with existing agent data',
        (WidgetTester tester) async {
      final agent = createTestAgent(name: 'Existing Agent');
      await tester.pumpWidget(createTestApp(AgentFormScreen(agent: agent)));
      await tester.pumpAndSettle();

      // Check that fields are populated
      expect(find.text('Existing Agent'), findsOneWidget);
      expect(find.text('Test Description'), findsOneWidget);
      expect(find.text('https://test.openai.azure.com'), findsOneWidget);
      expect(find.text('Azure OpenAI'), findsWidgets);
    });
  });

  group('AgentFormScreen - Validation', () {
    testWidgets('validates required agent name', (WidgetTester tester) async {
      await tester.pumpWidget(createTestApp(const AgentFormScreen()));
      await tester.pumpAndSettle();

      // Try to save without entering name
      await tester.tap(find.byIcon(Icons.save));
      await tester.pumpAndSettle();

      expect(find.text('エージェント名を入力してください'), findsOneWidget);
    });

    testWidgets('validates required endpoint/model',
        (WidgetTester tester) async {
      await tester.pumpWidget(createTestApp(const AgentFormScreen()));
      await tester.pumpAndSettle();

      // Enter name only
      await tester.enterText(
        find.widgetWithText(TextFormField, 'エージェント名 *'),
        'Test Agent',
      );

      // Try to save
      await tester.tap(find.byIcon(Icons.save));
      await tester.pumpAndSettle();

      expect(find.text('エンドポイント/モデルを入力してください'), findsOneWidget);
    });

    testWidgets('validates URL format for non-OpenAI providers',
        (WidgetTester tester) async {
      await tester.pumpWidget(createTestApp(const AgentFormScreen()));
      await tester.pumpAndSettle();

      // Change to Azure
      await tester.tap(find.byType(DropdownButtonFormField<TextAgentProvider>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Azure OpenAI'));
      await tester.pumpAndSettle();

      // Enter name and invalid URL
      await tester.enterText(
        find.widgetWithText(TextFormField, 'エージェント名 *'),
        'Test Agent',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'エンドポイント *'),
        'not-a-url',
      );

      await tester.tap(find.byIcon(Icons.save));
      await tester.pumpAndSettle();

      expect(find.text('有効なURLを入力してください'), findsOneWidget);
    });

    testWidgets('validates required API key', (WidgetTester tester) async {
      await tester.pumpWidget(createTestApp(const AgentFormScreen()));
      await tester.pumpAndSettle();

      // Enter name and model only
      await tester.enterText(
        find.widgetWithText(TextFormField, 'エージェント名 *'),
        'Test Agent',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'モデル *'),
        'gpt-4o',
      );

      await tester.tap(find.byIcon(Icons.save));
      await tester.pumpAndSettle();

      expect(find.text('APIキーを入力してください'), findsOneWidget);
    });

    testWidgets('allows saving with valid data (OpenAI)',
        (WidgetTester tester) async {
      await tester.pumpWidget(createTestApp(const AgentFormScreen()));
      await tester.pumpAndSettle();

      // Fill in required fields
      await tester.enterText(
        find.widgetWithText(TextFormField, 'エージェント名 *'),
        'Test Agent',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'モデル *'),
        'gpt-4o',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'APIキー *'),
        'sk-test-key',
      );

      // Save
      await tester.tap(find.byIcon(Icons.save));
      await tester.pumpAndSettle();

      // Verify agent was saved
      final agents = await mockRepo.getAll();
      expect(agents.length, 1);
      expect(agents[0].name, 'Test Agent');
      expect(agents[0].config.apiIdentifier, 'gpt-4o');
      expect(agents[0].config.provider, TextAgentProvider.openai);
    });

    testWidgets('allows saving with valid data (Azure)',
        (WidgetTester tester) async {
      await tester.pumpWidget(createTestApp(const AgentFormScreen()));
      await tester.pumpAndSettle();

      // Change to Azure
      await tester.tap(find.byType(DropdownButtonFormField<TextAgentProvider>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Azure OpenAI'));
      await tester.pumpAndSettle();

      // Fill in required fields
      await tester.enterText(
        find.widgetWithText(TextFormField, 'エージェント名 *'),
        'Azure Agent',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'エンドポイント *'),
        'https://test.openai.azure.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'APIキー *'),
        'azure-key',
      );

      // Save
      await tester.tap(find.byIcon(Icons.save));
      await tester.pumpAndSettle();

      // Verify agent was saved
      final agents = await mockRepo.getAll();
      expect(agents.length, 1);
      expect(agents[0].name, 'Azure Agent');
      expect(agents[0].config.apiIdentifier, 'https://test.openai.azure.com');
      expect(agents[0].config.provider, TextAgentProvider.azure);
    });
  });

  group('AgentFormScreen - Save Operation', () {
    testWidgets('creates new agent with valid data',
        (WidgetTester tester) async {
      await tester.pumpWidget(createTestApp(const AgentFormScreen()));
      await tester.pumpAndSettle();

      // Fill in all required fields
      await tester.enterText(
        find.widgetWithText(TextFormField, 'エージェント名 *'),
        'New Agent',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, '説明 (オプション)'),
        'New Description',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'モデル *'),
        'gpt-4o',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'APIキー *'),
        'new-api-key',
      );

      // Save
      await tester.tap(find.byIcon(Icons.save));
      await tester.pumpAndSettle();

      // Verify agent was saved
      final agents = await mockRepo.getAll();
      expect(agents.length, 1);
      expect(agents[0].name, 'New Agent');
      expect(agents[0].description, 'New Description');
      expect(agents[0].config.apiIdentifier, 'gpt-4o');
      expect(agents[0].config.provider, TextAgentProvider.openai);
    });

    testWidgets('updates existing agent', (WidgetTester tester) async {
      final agent = createTestAgent();
      await mockRepo.save(agent);

      await tester.pumpWidget(createTestApp(AgentFormScreen(agent: agent)));
      await tester.pumpAndSettle();

      // Update name
      await tester.enterText(
        find.widgetWithText(TextFormField, 'エージェント名 *'),
        'Updated Agent',
      );

      // Save
      await tester.tap(find.byIcon(Icons.save));
      await tester.pumpAndSettle();

      // Verify agent was updated
      final agents = await mockRepo.getAll();
      expect(agents.length, 1);
      expect(agents[0].name, 'Updated Agent');
      expect(agents[0].id, agent.id); // ID should remain the same
    });

    testWidgets('saves agent and closes form',
        (WidgetTester tester) async {
      await tester.pumpWidget(createTestApp(const AgentFormScreen()));
      await tester.pumpAndSettle();

      // Fill required fields
      await tester.enterText(
        find.widgetWithText(TextFormField, 'エージェント名 *'),
        'Test',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'モデル *'),
        'gpt-4o',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'APIキー *'),
        'key',
      );

      // Save
      await tester.tap(find.byIcon(Icons.save));
      await tester.pumpAndSettle();

      // Verify agent was saved
      final agents = await mockRepo.getAll();
      expect(agents.length, 1);
      expect(agents[0].name, 'Test');
    });
  });

  group('AgentFormScreen - Help Text', () {
    testWidgets('displays provider-specific help text', (WidgetTester tester) async {
      await tester.pumpWidget(createTestApp(const AgentFormScreen()));
      await tester.pumpAndSettle();

      // OpenAI help text should be visible
      expect(find.textContaining('OpenAIの公式API'), findsOneWidget);

      // Change to Azure
      await tester.tap(find.byType(DropdownButtonFormField<TextAgentProvider>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Azure OpenAI'));
      await tester.pumpAndSettle();

      // Azure help text should be visible
      expect(find.textContaining('Azure OpenAI Service'), findsOneWidget);
    });
  });
}
