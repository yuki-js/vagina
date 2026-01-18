import 'package:vagina/interfaces/memory_repository.dart';
import 'package:vagina/services/notepad_service.dart';
import 'package:vagina/services/tools_runtime/apis/memory_api.dart';
import 'package:vagina/services/tools_runtime/apis/notepad_api.dart';

/// Minimal in-memory MemoryRepository for testing
class InMemoryRepository implements MemoryRepository {
  final Map<String, String> _store = {};

  @override
  Future<void> save(String key, String value) async {
    _store[key] = value;
  }

  @override
  Future<String?> get(String key) async {
    return _store[key];
  }

  @override
  Future<bool> delete(String key) async {
    return _store.remove(key) != null;
  }

  @override
  Future<Map<String, dynamic>> getAll() async {
    return Map.from(_store);
  }

  @override
  Future<void> deleteAll() async {
    _store.clear();
  }
}

/// Test wrapper for NotepadApi that delegates to NotepadService
class TestNotepadApi implements NotepadApi {
  final NotepadService notepadService;

  TestNotepadApi(this.notepadService);

  @override
  Future<List<Map<String, dynamic>>> listTabs() async {
    return notepadService.listTabs();
  }

  @override
  Future<Map<String, dynamic>?> getTab(String id) async {
    final tab = notepadService.getTab(id);
    if (tab == null) return null;
    return {
      'id': tab.id,
      'title': tab.title,
      'mimeType': tab.mimeType,
      'content': tab.content,
    };
  }

  @override
  Future<String> createTab({
    required String content,
    required String mimeType,
    String? title,
  }) async {
    return notepadService.createTab(
      content: content,
      mimeType: mimeType,
      title: title,
    );
  }

  @override
  Future<bool> updateTab(
    String id, {
    String? content,
    String? title,
    String? mimeType,
  }) async {
    return notepadService.updateTab(
      id,
      content: content,
      title: title,
      mimeType: mimeType,
    );
  }

  @override
  Future<bool> closeTab(String id) async {
    return notepadService.closeTab(id);
  }
}

/// Test wrapper for MemoryApi that delegates to MemoryRepository
class TestMemoryApi implements MemoryApi {
  final MemoryRepository memoryRepository;

  TestMemoryApi(this.memoryRepository);

  @override
  Future<bool> save(
    String key,
    String value, {
    Map<String, dynamic>? metadata,
  }) async {
    await memoryRepository.save(key, value);
    return true;
  }

  @override
  Future<String?> recall(String key) async {
    return await memoryRepository.get(key);
  }

  @override
  Future<bool> delete(String key) async {
    return await memoryRepository.delete(key);
  }

  @override
  Future<Map<String, dynamic>> list() async {
    return await memoryRepository.getAll();
  }
}
