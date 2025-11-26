import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Service for securely storing sensitive data like API keys
class SecureStorageService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
    ),
  );

  static const _apiKeyKey = 'azure_api_key';
  static const _realtimeUrlKey = 'azure_realtime_url';

  /// Save the Azure OpenAI API key
  Future<void> saveApiKey(String apiKey) async {
    await _storage.write(key: _apiKeyKey, value: apiKey);
  }

  /// Get the stored Azure OpenAI API key
  Future<String?> getApiKey() async {
    return await _storage.read(key: _apiKeyKey);
  }

  /// Delete the stored API key
  Future<void> deleteApiKey() async {
    await _storage.delete(key: _apiKeyKey);
  }

  /// Check if API key is stored
  Future<bool> hasApiKey() async {
    final key = await getApiKey();
    return key != null && key.isNotEmpty;
  }

  /// Save Azure Realtime URL (contains endpoint, deployment, api-version)
  Future<void> saveRealtimeUrl(String url) async {
    await _storage.write(key: _realtimeUrlKey, value: url);
  }

  /// Get Azure Realtime URL
  Future<String?> getRealtimeUrl() async {
    return await _storage.read(key: _realtimeUrlKey);
  }

  /// Delete Azure Realtime URL
  Future<void> deleteRealtimeUrl() async {
    await _storage.delete(key: _realtimeUrlKey);
  }

  /// Parse Realtime URL to extract components
  /// Returns null if URL is invalid
  static Map<String, String>? parseRealtimeUrl(String url) {
    try {
      final uri = Uri.parse(url);
      
      // Expected format: https://{resource}.openai.azure.com/openai/realtime?api-version=YYYY-MM-DD&deployment=...
      if (!uri.host.endsWith('.openai.azure.com')) {
        return null;
      }
      
      final deployment = uri.queryParameters['deployment'];
      final apiVersion = uri.queryParameters['api-version'];
      
      if (deployment == null || deployment.isEmpty) {
        return null;
      }
      
      // Build the endpoint (base URL without path/query)
      final endpoint = '${uri.scheme}://${uri.host}';
      
      return {
        'endpoint': endpoint,
        'deployment': deployment,
        'apiVersion': apiVersion ?? '2024-10-01-preview',
      };
    } catch (e) {
      return null;
    }
  }

  /// Check if all Azure settings are configured
  Future<bool> hasAzureConfig() async {
    final apiKey = await getApiKey();
    final realtimeUrl = await getRealtimeUrl();
    
    if (apiKey == null || apiKey.isEmpty) return false;
    if (realtimeUrl == null || realtimeUrl.isEmpty) return false;
    
    // Validate URL format
    final parsed = parseRealtimeUrl(realtimeUrl);
    return parsed != null;
  }

  /// Clear all settings
  Future<void> clearAll() async {
    await _storage.delete(key: _apiKeyKey);
    await _storage.delete(key: _realtimeUrlKey);
  }
}
