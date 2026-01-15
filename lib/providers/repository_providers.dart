import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../interfaces/config_repository.dart';
import '../repositories/repository_factory.dart';

final configRepositoryProvider = Provider<ConfigRepository>((ref) {
  return RepositoryFactory.config;
});
