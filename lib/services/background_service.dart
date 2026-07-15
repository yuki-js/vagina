import 'background_io/background_service_stub.dart'
    if (dart.library.io) 'background_io/background_service_io.dart';

enum BackgroundServiceType { microphone }

final class BackgroundServiceConfig {
  final String channelId;
  final int serviceId;
  final String iconMetadataName;
  final String channelName;
  final String channelDescription;
  final String notificationTitle;
  final String notificationText;
  final String notificationActionButtonText;
  final BackgroundServiceType serviceType;
  final Future<void> Function() onStopRequested;

  const BackgroundServiceConfig({
    required this.channelId,
    required this.serviceId,
    required this.iconMetadataName,
    required this.channelName,
    required this.channelDescription,
    required this.notificationTitle,
    required this.notificationText,
    required this.notificationActionButtonText,
    required this.serviceType,
    required this.onStopRequested,
  });
}

abstract interface class BackgroundService {
  Future<void> start();

  Future<void> dispose();
}

BackgroundService createBackgroundService(BackgroundServiceConfig config) =>
    createPlatformBackgroundService(config);
