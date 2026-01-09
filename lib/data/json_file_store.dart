import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'key_value_store.dart';
import '../utils/platform_compat.dart';
import '../services/log_service.dart';

/// File-based JSON key-value store implementation
class JsonFileStore implements KeyValueStore {
  static const _tag = 'JsonFileStore';
  
  final String fileName;
  final String? folderName;
  File? _file;
  Map<String, dynamic> _cache = {};
  bool _initialized = false;

  JsonFileStore({
    required this.fileName,
    this.folderName,
  });

  @override
  Future<void> initialize() async {
    if (_initialized) return;
    
    _file = await _getFile();
    _cache = await _loadFromFile();
    _initialized = true;
    
    logService.debug(_tag, 'Initialized with ${_cache.keys.length} keys');
  }

  Future<File> _getFile() async {
    Directory? directory;
    
    if (PlatformCompat.isAndroid && folderName != null) {
      // Try to use external storage for persistence
      try {
        directory = Directory('/storage/emulated/0/Documents/$folderName');
        if (!await directory.exists()) {
          await directory.create(recursive: true);
        }
        logService.info(_tag, 'Using external directory: ${directory.path}');
      } catch (e) {
        logService.warn(_tag, 'Cannot access external storage: $e');
        directory = null;
      }
    }
    
    if (directory == null) {
      // Fallback to app documents directory
      if (kIsWeb) {
        // Web doesn't use files
        return File('');
      } else if (PlatformCompat.isIOS || PlatformCompat.isMacOS) {
        directory = await getApplicationDocumentsDirectory();
      } else {
        directory = await getApplicationDocumentsDirectory();
      }
      logService.info(_tag, 'Using app directory: ${directory.path}');
    }
    
    final file = File('${directory.path}/$fileName');
    logService.info(_tag, 'Storage file: ${file.path}');
    return file;
  }

  Future<Map<String, dynamic>> _loadFromFile() async {
    if (kIsWeb) {
      return _loadFromWebStorage();
    }
    
    if (_file == null || !await _file!.exists()) {
      return {};
    }
    
    try {
      final contents = await _file!.readAsString();
      if (contents.isEmpty) return {};
      
      final data = jsonDecode(contents) as Map<String, dynamic>;
      logService.debug(_tag, 'Loaded ${data.keys.length} keys from file');
      return data;
    } catch (e) {
      logService.error(_tag, 'Error loading file: $e');
      return {};
    }
  }

  Future<void> _saveToFile(Map<String, dynamic> data) async {
    if (kIsWeb) {
      await _saveToWebStorage(data);
      return;
    }
    
    if (_file == null) return;
    
    try {
      final json = jsonEncode(data);
      await _file!.writeAsString(json);
      logService.debug(_tag, 'Saved ${data.keys.length} keys to file');
    } catch (e) {
      logService.error(_tag, 'Error saving file: $e');
      rethrow;
    }
  }

  Map<String, dynamic> _loadFromWebStorage() {
    if (!kIsWeb) return {};
    
    // Web storage implementation is different - we'll store the whole config as a single JSON string
    // For simplicity, we don't support web storage in this implementation
    // Web users will lose data on refresh, but this is acceptable for now
    return {};
  }

  Future<void> _saveToWebStorage(Map<String, dynamic> data) async {
    if (!kIsWeb) return;
    
    // Web storage not fully supported - data won't persist on refresh
    // This is acceptable as the app is primarily designed for mobile/desktop
  }

  void _ensureInitialized() {
    if (!_initialized) {
      throw StateError('Store not initialized. Call initialize() first.');
    }
  }

  @override
  Future<Map<String, dynamic>> load() async {
    _ensureInitialized();
    return Map.from(_cache);
  }

  @override
  Future<void> save(Map<String, dynamic> data) async {
    _ensureInitialized();
    _cache = Map.from(data);
    await _saveToFile(_cache);
  }

  @override
  Future<dynamic> get(String key) async {
    _ensureInitialized();
    return _cache[key];
  }

  @override
  Future<void> set(String key, dynamic value) async {
    _ensureInitialized();
    _cache[key] = value;
    await _saveToFile(_cache);
  }

  @override
  Future<void> delete(String key) async {
    _ensureInitialized();
    _cache.remove(key);
    await _saveToFile(_cache);
  }

  @override
  Future<bool> contains(String key) async {
    _ensureInitialized();
    return _cache.containsKey(key);
  }

  @override
  Future<void> clear() async {
    _ensureInitialized();
    _cache.clear();
    await _saveToFile(_cache);
  }

  @override
  Future<String> getFilePath() async {
    if (_file == null) {
      await initialize();
    }
    return _file?.path ?? 'web-localStorage';
  }
}
