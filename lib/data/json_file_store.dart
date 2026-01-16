import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:vagina/interfaces/key_value_store.dart';
import 'package:vagina/services/log_service.dart';
import 'package:vagina/services/platform/platform_storage_service.dart';

// Conditional import for web support
import 'web_storage_stub.dart'
    if (dart.library.html) 'dart:html' as html;

/// File-based JSON key-value store implementation
class JsonFileStore implements KeyValueStore {
  static const _tag = 'JsonFileStore';
  
  final String fileName;
  final String? folderName;
  final PlatformStorageService _storageService;
  final LogService _logService;
  File? _file;
  Map<String, dynamic> _cache = {};
  bool _initialized = false;

  JsonFileStore({
    required this.fileName,
    this.folderName,
    PlatformStorageService? storageService,
    LogService? logService,
  })  : _storageService = storageService ?? PlatformStorageService(),
        _logService = logService ?? LogService();

  @override
  Future<void> initialize() async {
    if (_initialized) return;
    
    _file = await _getFile();
    _cache = await _loadFromFile();
    _initialized = true;
    
    _logService.debug(_tag, 'Initialized with ${_cache.keys.length} keys');
  }

  Future<File> _getFile() async {
    if (kIsWeb) {
      // Web doesn't use files
      return File('');
    }

    final directory = await _storageService.getStorageDirectory(folderName: folderName);
    final file = File('${directory.path}/$fileName');
    _logService.info(_tag, 'Storage file: ${file.path}');
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
      _logService.debug(_tag, 'Loaded ${data.keys.length} keys from file');
      return data;
    } catch (e) {
      _logService.error(_tag, 'Error loading file: $e');
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
      _logService.debug(_tag, 'Saved ${data.keys.length} keys to file');
    } catch (e) {
      _logService.error(_tag, 'Error saving file: $e');
      rethrow;
    }
  }

  Map<String, dynamic> _loadFromWebStorage() {
    if (!kIsWeb) return {};
    
    try {
      final storage = html.window.localStorage;
      final key = 'vagina_${fileName}_data';
      final value = storage[key];
      
      if (value == null || value.isEmpty) {
        _logService.debug(_tag, 'No web storage data found');
        return {};
      }
      
      final data = jsonDecode(value) as Map<String, dynamic>;
      _logService.debug(_tag, 'Loaded ${data.keys.length} keys from web storage');
      return data;
    } catch (e) {
      _logService.error(_tag, 'Error loading from web storage: $e');
      return {};
    }
  }

  Future<void> _saveToWebStorage(Map<String, dynamic> data) async {
    if (!kIsWeb) return;
    
    try {
      final storage = html.window.localStorage;
      final key = 'vagina_${fileName}_data';
      final json = jsonEncode(data);
      storage[key] = json;
      
      _logService.debug(_tag, 'Saved ${data.keys.length} keys to web storage');
    } catch (e) {
      _logService.error(_tag, 'Error saving to web storage: $e');
      rethrow;
    }
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
