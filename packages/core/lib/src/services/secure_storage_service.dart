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
  static const _azureEndpointKey = 'azure_endpoint';
  static const _azureDeploymentKey = 'azure_deployment';

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

  /// Save Azure endpoint URL
  Future<void> saveAzureEndpoint(String endpoint) async {
    await _storage.write(key: _azureEndpointKey, value: endpoint);
  }

  /// Get Azure endpoint URL
  Future<String?> getAzureEndpoint() async {
    return await _storage.read(key: _azureEndpointKey);
  }

  /// Delete Azure endpoint
  Future<void> deleteAzureEndpoint() async {
    await _storage.delete(key: _azureEndpointKey);
  }

  /// Save Azure deployment name
  Future<void> saveAzureDeployment(String deployment) async {
    await _storage.write(key: _azureDeploymentKey, value: deployment);
  }

  /// Get Azure deployment name
  Future<String?> getAzureDeployment() async {
    return await _storage.read(key: _azureDeploymentKey);
  }

  /// Delete Azure deployment name
  Future<void> deleteAzureDeployment() async {
    await _storage.delete(key: _azureDeploymentKey);
  }

  /// Check if all Azure settings are configured
  Future<bool> hasAzureConfig() async {
    final apiKey = await getApiKey();
    final endpoint = await getAzureEndpoint();
    final deployment = await getAzureDeployment();
    return apiKey != null && 
           apiKey.isNotEmpty && 
           endpoint != null && 
           endpoint.isNotEmpty &&
           deployment != null &&
           deployment.isNotEmpty;
  }
}
