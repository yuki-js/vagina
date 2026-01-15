import 'package:flutter_test/flutter_test.dart';
import 'package:vagina/models/speed_dial.dart';
import 'package:vagina/repositories/json_speed_dial_repository.dart';
import 'package:vagina/interfaces/key_value_store.dart';

// Mock KeyValueStore for testing
class MockKeyValueStore implements KeyValueStore {
  final Map<String, dynamic> _data = {};

  @override
  Future<void> initialize() async {}

  @override
  Future<void> set(String key, dynamic value) async {
    _data[key] = value;
  }

  @override
  Future<dynamic> get(String key) async {
    return _data[key];
  }

  @override
  Future<void> delete(String key) async {
    _data.remove(key);
  }

  @override
  Future<void> clear() async {
    _data.clear();
  }
}

void main() {
  group('JsonSpeedDialRepository', () {
    late MockKeyValueStore store;
    late JsonSpeedDialRepository repository;

    setUp(() {
      store = MockKeyValueStore();
      repository = JsonSpeedDialRepository(store);
    });

    test('should ensure default speed dial exists on first getAll', () async {
      final speedDials = await repository.getAll();
      
      expect(speedDials.length, equals(1));
      expect(speedDials.first.isDefault, isTrue);
      expect(speedDials.first.id, equals(SpeedDial.defaultId));
    });

    test('should not duplicate default speed dial', () async {
      await repository.getAll(); // First call creates default
      final speedDials = await repository.getAll(); // Second call
      
      expect(speedDials.length, equals(1));
      expect(speedDials.first.isDefault, isTrue);
    });

    test('should save and retrieve speed dial', () async {
      final speedDial = SpeedDial(
        id: 'test-1',
        name: 'Test Character',
        systemPrompt: 'Test prompt',
        voice: 'echo',
        iconEmoji: '🎭',
      );

      await repository.save(speedDial);
      final speedDials = await repository.getAll();
      
      expect(speedDials.length, equals(2)); // Default + new one
      expect(speedDials.any((s) => s.id == 'test-1'), isTrue);
    });

    test('should not allow deleting default speed dial', () async {
      final result = await repository.delete(SpeedDial.defaultId);
      
      expect(result, isFalse);
      
      final speedDials = await repository.getAll();
      expect(speedDials.any((s) => s.isDefault), isTrue);
    });

    test('should allow deleting custom speed dial', () async {
      final speedDial = SpeedDial(
        id: 'test-1',
        name: 'Test',
        systemPrompt: 'Test',
        voice: 'alloy',
      );

      await repository.save(speedDial);
      
      final result = await repository.delete('test-1');
      
      expect(result, isTrue);
      
      final speedDials = await repository.getAll();
      expect(speedDials.any((s) => s.id == 'test-1'), isFalse);
    });
  });
}
