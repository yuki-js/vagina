import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:vagina/feat/call/models/realtime/realtime_thread.dart';
import 'package:vagina/feat/call/models/realtime/realtime_thread_json_codec.dart';
import 'package:vagina/feat/call/widgets/realtime_thread_renderer.dart';
import 'package:vagina/l10n/app_localizations.dart';

void main() {
  testWidgets('renders saved thread text read-only without input controls', (
    tester,
  ) async {
    final items = <RealtimeThreadItem>[
      RealtimeThreadItem(
        id: 'assistant-message',
        type: RealtimeThreadItemType.message,
        role: RealtimeThreadItemRole.assistant,
        status: RealtimeThreadItemStatus.completed,
        content: <RealtimeThreadContentPart>[
          RealtimeThreadTextPart(text: 'Saved assistant reply', isDone: true),
        ],
      ),
      RealtimeThreadItem(
        id: 'user-message',
        type: RealtimeThreadItemType.message,
        role: RealtimeThreadItemRole.user,
        status: RealtimeThreadItemStatus.completed,
        content: <RealtimeThreadContentPart>[
          RealtimeThreadTextPart(text: 'Saved user message', isDone: true),
        ],
      ),
    ];

    await tester.pumpWidget(
      _LocalizedApp(child: RealtimeThreadView(items: items)),
    );

    expect(find.text('Saved assistant reply'), findsOneWidget);
    expect(find.text('Saved user message'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.byIcon(Icons.send), findsNothing);
  });

  testWidgets(
    'renders function call badge without tap chevron when read-only',
    (tester) async {
      final items = <RealtimeThreadItem>[
        RealtimeThreadItem(
          id: 'tool-call',
          type: RealtimeThreadItemType.functionCall,
          status: RealtimeThreadItemStatus.completed,
          name: 'lookupNote',
          callId: 'call-1',
          arguments: '{}',
        ),
        RealtimeThreadItem(
          id: 'tool-output',
          type: RealtimeThreadItemType.functionCallOutput,
          status: RealtimeThreadItemStatus.completed,
          callId: 'call-1',
          output: 'ok',
        ),
      ];

      await tester.pumpWidget(
        _LocalizedApp(child: RealtimeThreadView(items: items)),
      );

      expect(find.text('lookupNote'), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsNothing);
    },
  );
  testWidgets('leading content scrolls away before later thread messages', (
    tester,
  ) async {
    final items = List<RealtimeThreadItem>.generate(
      20,
      (index) => RealtimeThreadItem(
        id: 'message-$index',
        type: RealtimeThreadItemType.message,
        role: RealtimeThreadItemRole.assistant,
        status: RealtimeThreadItemStatus.completed,
        content: <RealtimeThreadContentPart>[
          RealtimeThreadTextPart(
            text: 'Historical message $index',
            isDone: true,
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      _LocalizedApp(
        child: RealtimeThreadView(
          items: items,
          leading: const SizedBox(
            height: 300,
            child: Center(child: Text('Session information')),
          ),
        ),
      ),
    );

    expect(find.text('Session information'), findsOneWidget);
    expect(find.text('Historical message 0'), findsOneWidget);
    expect(find.text('Historical message 19'), findsNothing);

    await tester.drag(find.byType(ListView), const Offset(0, -1200));
    await tester.pumpAndSettle();

    expect(find.text('Session information'), findsNothing);
    expect(find.text('Historical message 19'), findsOneWidget);
  });

  testWidgets('renders product-usable saved multi-turn tool history', (
    tester,
  ) async {
    final thread = RealtimeThreadJsonCodec.fromJson(_savedHistoryThreadJson());

    await tester.pumpWidget(
      _LocalizedApp(child: RealtimeThreadView(items: thread.items)),
    );

    expect(find.text('Ask the first saved-history question.'), findsOneWidget);
    expect(find.text('SESSION_HISTORY_FIRST_ANSWER'), findsOneWidget);
    expect(find.text('Use the history tool twice.'), findsOneWidget);
    expect(find.text('vhrp_history_probe'), findsNWidgets(2));
    expect(find.text('SESSION_HISTORY_FINAL_ANSWER'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.byIcon(Icons.send), findsNothing);
  });
}

Map<String, Object?> _savedHistoryThreadJson() {
  return {
    'id': 't_saved_history',
    'conversationId': 'cc_saved_history',
    'items': [
      {
        'id': 'user-1',
        'type': 'message',
        'role': 'user',
        'status': 'completed',
        'displayState': 'visible',
        'content': [
          {
            'type': 'text',
            'text': 'Ask the first saved-history question.',
            'isDone': true,
          },
        ],
      },
      {
        'id': 'assistant-1',
        'type': 'message',
        'role': 'assistant',
        'status': 'completed',
        'displayState': 'visible',
        'content': [
          {
            'type': 'audio',
            'transcript': 'SESSION_HISTORY_FIRST_ANSWER',
            'isDone': true,
          },
        ],
      },
      {
        'id': 'user-2',
        'type': 'message',
        'role': 'user',
        'status': 'completed',
        'displayState': 'visible',
        'content': [
          {
            'type': 'text',
            'text': 'Use the history tool twice.',
            'isDone': true,
          },
        ],
      },
      {
        'id': 'tool-call-1',
        'type': 'functionCall',
        'status': 'completed',
        'callId': 'call-1',
        'name': 'vhrp_history_probe',
        'arguments': '{}',
      },
      {
        'id': 'tool-output-1',
        'type': 'functionCallOutput',
        'status': 'completed',
        'callId': 'call-1',
        'output': 'TOOL_RESULT_ONE',
        'toolOutputDisposition': 'success',
      },
      {
        'id': 'tool-call-2',
        'type': 'functionCall',
        'status': 'completed',
        'callId': 'call-2',
        'name': 'vhrp_history_probe',
        'arguments': '{}',
      },
      {
        'id': 'tool-output-2',
        'type': 'functionCallOutput',
        'status': 'completed',
        'callId': 'call-2',
        'output': 'TOOL_RESULT_TWO',
        'toolOutputDisposition': 'success',
      },
      {
        'id': 'assistant-final',
        'type': 'message',
        'role': 'assistant',
        'status': 'completed',
        'displayState': 'visible',
        'content': [
          {
            'type': 'audio',
            'transcript': 'SESSION_HISTORY_FINAL_ANSWER',
            'isDone': true,
          },
        ],
      },
    ],
  };
}

class _LocalizedApp extends StatelessWidget {
  final Widget child;

  const _LocalizedApp({required this.child});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    );
  }
}
