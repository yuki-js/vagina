import 'dart:async';
import 'dart:io';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import '../background_service.dart';

const String _stopAction = 'stop';
const String _actionDataKey = 'action';

BackgroundService createPlatformBackgroundService(
  BackgroundServiceConfig config,
) {
  if (!Platform.isAndroid) {
    return _NoOpBackgroundService(config);
  }
  return AndroidBackgroundService(config);
}

final class AndroidBackgroundService implements BackgroundService {
  final BackgroundServiceConfig _config;
  Future<void> Function()? _onStopRequested;
  bool _initialized = false;
  bool _running = false;
  bool _stopping = false;

  AndroidBackgroundService(this._config);

  void _initialize() {
    if (_initialized) {
      return;
    }

    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: _config.channelId,
        channelName: _config.channelName,
        channelDescription: _config.channelDescription,
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        onlyAlertOnce: true,
        playSound: false,
        enableVibration: false,
        showWhen: false,
        showBadge: false,
        visibility: NotificationVisibility.VISIBILITY_PUBLIC,
      ),
      iosNotificationOptions: const IOSNotificationOptions(),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        autoRunOnBoot: false,
        autoRunOnMyPackageReplaced: false,
        allowWakeLock: true,
        allowWifiLock: false,
        allowAutoRestart: false,
        stopWithTask: true,
      ),
    );
    FlutterForegroundTask.addTaskDataCallback(_onTaskData);
    _initialized = true;
  }

  @override
  Future<void> start() async {
    if (_running) {
      return;
    }

    _onStopRequested = _config.onStopRequested;
    _initialize();
    final result = await FlutterForegroundTask.startService(
      serviceId: _config.serviceId,
      notificationTitle: _config.notificationTitle,
      notificationText: _config.notificationText,
      notificationIcon: NotificationIcon(
        metaDataName: _config.iconMetadataName,
      ),
      notificationButtons: [
        NotificationButton(
          id: _stopAction,
          text: _config.notificationActionButtonText,
        ),
      ],
      callback: backgroundServiceTaskCallback,
      serviceTypes: [_toForegroundServiceType(_config.serviceType)],
    );
    if (result is ServiceRequestFailure) {
      throw StateError('Failed to start background service: ${result.error}');
    }
    _running = true;
  }

  void _onTaskData(Object data) {
    if (data is! Map || data[_actionDataKey] != _stopAction || _stopping) {
      return;
    }

    final onStopRequested = _onStopRequested;
    if (onStopRequested == null) {
      return;
    }

    _stopping = true;
    unawaited(
      onStopRequested().whenComplete(() {
        _stopping = false;
      }),
    );
  }

  @override
  Future<void> dispose() async {
    _onStopRequested = null;
    if (!_running) {
      return;
    }

    _running = false;
    await FlutterForegroundTask.stopService();
  }
}

ForegroundServiceTypes _toForegroundServiceType(BackgroundServiceType type) {
  return switch (type) {
    BackgroundServiceType.microphone => ForegroundServiceTypes.microphone,
  };
}

@pragma('vm:entry-point')
void backgroundServiceTaskCallback() {
  FlutterForegroundTask.setTaskHandler(_BackgroundServiceTaskHandler());
}

final class _BackgroundServiceTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    // With stopWithTask enabled, removing the Android task explicitly stops
    // this service. The main isolate may already be terminating, so server
    // notification, note persistence, and normal call cleanup are best effort;
    // this callback intentionally does not pretend those steps are guaranteed.
  }

  @override
  void onReceiveData(Object data) {}

  @override
  void onNotificationButtonPressed(String id) {
    if (id == _stopAction) {
      FlutterForegroundTask.sendDataToMain({_actionDataKey: _stopAction});
    }
  }
}

final class _NoOpBackgroundService implements BackgroundService {
  final BackgroundServiceConfig config;

  const _NoOpBackgroundService(this.config);

  @override
  Future<void> start() async {}

  @override
  Future<void> dispose() async {}
}
