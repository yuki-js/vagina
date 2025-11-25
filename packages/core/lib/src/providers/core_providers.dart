import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/secure_storage_service.dart';

/// Provider for the secure storage service
final secureStorageServiceProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageService();
});

/// Provider for checking if API key exists
final hasApiKeyProvider = FutureProvider<bool>((ref) async {
  final storage = ref.read(secureStorageServiceProvider);
  return await storage.hasApiKey();
});

/// Provider for the API key
final apiKeyProvider = FutureProvider<String?>((ref) async {
  final storage = ref.read(secureStorageServiceProvider);
  return await storage.getApiKey();
});
