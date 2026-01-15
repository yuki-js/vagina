import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../interfaces/config_repository.dart';
import '../repositories/repository_factory.dart';

// ============================================================================
// Repository Providers - Only config repository is exposed
// Other repositories should be accessed via RepositoryFactory directly
// ============================================================================

final configRepositoryProvider = Provider<ConfigRepository>((ref) {
  return RepositoryFactory.config;
});
