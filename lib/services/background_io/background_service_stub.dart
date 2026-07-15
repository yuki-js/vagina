import '../background_service.dart';

BackgroundService createPlatformBackgroundService(
  BackgroundServiceConfig config,
) => NoOpBackgroundService(config);

final class NoOpBackgroundService implements BackgroundService {
  final BackgroundServiceConfig config;

  const NoOpBackgroundService(this.config);

  @override
  Future<void> start() async {}

  @override
  Future<void> dispose() async {}
}
