import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vagina/core/app/app_container.dart';
import 'package:vagina/feat/call/screens/call.dart';
import 'package:vagina/interfaces/key_value_store.dart';
import 'package:vagina/interfaces/speed_dial_repository.dart';
import 'package:vagina/l10n/app_localizations.dart';
import 'package:vagina/models/speed_dial.dart';
import 'package:vagina/utils/call_navigation_utils.dart';

void main() {
  setUp(() async {
    AppContainer.reset();
    await AppContainer.initialize(store: _MemoryKeyValueStore());
  });

  tearDown(() {
    AppContainer.reset();
  });

  testWidgets(
    'navigateToCallWithDefault passes the persisted default speed dial to CallScreen',
    (tester) async {
      final persistedDefault = SpeedDial(
        id: SpeedDial.defaultId,
        name: 'Default',
        systemPrompt: 'Persisted default prompt',
        description: 'Persisted default description',
        iconEmoji: '🦄',
        voice: 'verse',
        enabledTools: const {
          'document_read': false,
          'calculator': true,
        },
        reasoningEffort: SpeedDialReasoningEffort.high,
        toolChoiceRequired: true,
        createdAt: DateTime.utc(2026, 1, 2, 3, 4, 5),
      );
      AppContainer.setOverridesForTesting(
        speedDials: _FakeSpeedDialRepository(defaultSpeedDial: persistedDefault),
      );

      final observer = _RouteCaptureObserver();

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          navigatorObservers: [observer],
          home: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () => CallNavigationUtils.navigateToCallWithDefault(
                  context: context,
                ),
                child: const Text('Call default'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Call default'));
      await tester.pump();

      final route = observer.callScreenRoute;
      expect(route, isA<MaterialPageRoute<void>>());
      final widget = (route as MaterialPageRoute<void>).builder(
        tester.element(find.byType(Navigator)),
      );
      expect(widget, isA<CallScreen>());
      final callScreen = widget as CallScreen;
      expect(callScreen.speedDial, same(persistedDefault));
    },
  );

  testWidgets(
    'navigateToCallWithDefault fails instead of falling back when the persisted default is missing',
    (tester) async {
      AppContainer.setOverridesForTesting(
        speedDials: _FakeSpeedDialRepository(defaultSpeedDial: null),
      );

      late BuildContext capturedContext;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              capturedContext = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      await expectLater(
        CallNavigationUtils.navigateToCallWithDefault(context: capturedContext),
        throwsA(isA<StateError>()),
      );
    },
  );
}

class _RouteCaptureObserver extends NavigatorObserver {
  Route<dynamic>? callScreenRoute;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (previousRoute != null &&
        route is MaterialPageRoute<void> &&
        callScreenRoute == null) {
      callScreenRoute = route;
    }
    super.didPush(route, previousRoute);
  }
}

class _FakeSpeedDialRepository implements SpeedDialRepository {
  _FakeSpeedDialRepository({required this.defaultSpeedDial});

  final SpeedDial? defaultSpeedDial;
  final Map<String, SpeedDial> _saved = {};

  @override
  Future<void> save(SpeedDial speedDial) async {
    _saved[speedDial.id] = speedDial;
  }

  @override
  Future<List<SpeedDial>> getAll() async {
    return [
      if (defaultSpeedDial != null) defaultSpeedDial!,
      ..._saved.values.where((speedDial) => !speedDial.isDefault),
    ];
  }

  @override
  Future<SpeedDial?> getById(String id) async {
    if (id == SpeedDial.defaultId) {
      return defaultSpeedDial;
    }
    return _saved[id];
  }

  @override
  Future<bool> update(SpeedDial speedDial) async {
    if (speedDial.id == SpeedDial.defaultId) {
      return defaultSpeedDial != null &&
          (identical(speedDial, defaultSpeedDial) ||
              speedDial == defaultSpeedDial);
    }
    _saved[speedDial.id] = speedDial;
    return true;
  }

  @override
  Future<bool> delete(String id) async {
    if (id == SpeedDial.defaultId) {
      return false;
    }
    return _saved.remove(id) != null;
  }
}

class _MemoryKeyValueStore implements KeyValueStore {
  final Map<String, dynamic> _data = {};

  @override
  Future<void> initialize() async {}

  @override
  Future<Map<String, dynamic>> load() async {
    return Map<String, dynamic>.from(_data);
  }

  @override
  Future<void> save(Map<String, dynamic> data) async {
    _data
      ..clear()
      ..addAll(data);
  }

  @override
  Future<dynamic> get(String key) async {
    return _data[key];
  }

  @override
  Future<void> set(String key, dynamic value) async {
    _data[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _data.remove(key);
  }

  @override
  Future<bool> contains(String key) async {
    return _data.containsKey(key);
  }

  @override
  Future<void> clear() async {
    _data.clear();
  }

  @override
  Future<String> getFilePath() async {
    return 'memory://call_navigation_utils_test';
  }
}
