import 'package:flutter_test/flutter_test.dart';
import 'package:vagina/utils/utils.dart';

void main() {
  group('Utils', () {
    test('generateId creates unique IDs', () {
      final id1 = Utils.generateId();
      final id2 = Utils.generateId();
      
      expect(id1, isNotEmpty);
      expect(id2, isNotEmpty);
      expect(id1, isNot(equals(id2)));
    });

    test('tryParseJson parses valid JSON', () {
      final result = Utils.tryParseJson('{"key": "value"}');
      expect(result, isNotNull);
      expect(result!['key'], equals('value'));
    });

    test('tryParseJson returns null for invalid JSON', () {
      final result = Utils.tryParseJson('invalid json');
      expect(result, isNull);
    });

    test('truncate shortens long strings', () {
      final result = Utils.truncate('This is a long string', 10);
      expect(result, equals('This is...'));
      expect(result.length, equals(10));
    });

    test('truncate preserves short strings', () {
      final result = Utils.truncate('Short', 10);
      expect(result, equals('Short'));
    });

    test('isNullOrEmpty checks correctly', () {
      expect(Utils.isNullOrEmpty(null), isTrue);
      expect(Utils.isNullOrEmpty(''), isTrue);
      expect(Utils.isNullOrEmpty('text'), isFalse);
    });

    test('isNullOrWhitespace checks correctly', () {
      expect(Utils.isNullOrWhitespace(null), isTrue);
      expect(Utils.isNullOrWhitespace(''), isTrue);
      expect(Utils.isNullOrWhitespace('   '), isTrue);
      expect(Utils.isNullOrWhitespace('text'), isFalse);
    });

    test('safeDivide handles division by zero', () {
      expect(Utils.safeDivide(10, 2), equals(5.0));
      expect(Utils.safeDivide(10, 0), equals(0.0));
      expect(Utils.safeDivide(10, 0, defaultValue: -1.0), equals(-1.0));
    });

    test('clamp restricts values to range', () {
      expect(Utils.clamp(5, 0, 10), equals(5));
      expect(Utils.clamp(-5, 0, 10), equals(0));
      expect(Utils.clamp(15, 0, 10), equals(10));
    });

    test('formatBytes converts bytes to human readable format', () {
      expect(Utils.formatBytes(0), equals('0 B'));
      expect(Utils.formatBytes(1024), equals('1.00 KB'));
      expect(Utils.formatBytes(1024 * 1024), equals('1.00 MB'));
      expect(Utils.formatBytes(1536, decimals: 0), equals('2 KB'));
    });

    test('deepCopyMap creates independent copy', () {
      final original = {'key': 'value', 'nested': {'inner': 'data'}};
      final copy = Utils.deepCopyMap(original);
      
      // Modify copy
      copy['key'] = 'modified';
      (copy['nested'] as Map<String, dynamic>)['inner'] = 'changed';
      
      // Original should be unchanged
      expect(original['key'], equals('value'));
      expect((original['nested'] as Map<String, dynamic>)['inner'], equals('data'));
    });

    test('listsEqual compares lists correctly', () {
      expect(Utils.listsEqual([1, 2, 3], [1, 2, 3]), isTrue);
      expect(Utils.listsEqual([1, 2, 3], [3, 2, 1]), isTrue); // Order independent
      expect(Utils.listsEqual([1, 2], [1, 2, 3]), isFalse);
      expect(Utils.listsEqual(null, null), isTrue);
      expect(Utils.listsEqual([1], null), isFalse);
    });

    test('capitalize converts first letter to uppercase', () {
      expect(Utils.capitalize('hello'), equals('Hello'));
      expect(Utils.capitalize('HELLO'), equals('HELLO'));
      expect(Utils.capitalize(''), equals(''));
    });

    test('camelToSnake converts camelCase to snake_case', () {
      expect(Utils.camelToSnake('camelCase'), equals('camel_case'));
      expect(Utils.camelToSnake('myVariableName'), equals('my_variable_name'));
      expect(Utils.camelToSnake('simple'), equals('simple'));
    });

    test('snakeToCamel converts snake_case to camelCase', () {
      expect(Utils.snakeToCamel('snake_case'), equals('snakeCase'));
      expect(Utils.snakeToCamel('my_variable_name'), equals('myVariableName'));
      expect(Utils.snakeToCamel('simple'), equals('simple'));
    });

    test('retry succeeds on first attempt', () async {
      var attempts = 0;
      final result = await Utils.retry(() async {
        attempts++;
        return 'success';
      });
      
      expect(result, equals('success'));
      expect(attempts, equals(1));
    });

    test('retry retries on failure and eventually succeeds', () async {
      var attempts = 0;
      final result = await Utils.retry(
        () async {
          attempts++;
          if (attempts < 3) throw Exception('Fail');
          return 'success';
        },
        maxAttempts: 5,
        initialDelay: const Duration(milliseconds: 10),
      );
      
      expect(result, equals('success'));
      expect(attempts, equals(3));
    });

    test('retry throws after max attempts', () async {
      var attempts = 0;

      try {
        await Utils.retry(
          () async {
            attempts++;
            throw Exception('Always fail');
          },
          maxAttempts: 3,
          initialDelay: const Duration(milliseconds: 10),
        );
        // ignore: dead_code
        fail('Should have thrown an exception');
      } catch (e) {
        expect(attempts, equals(3));
        expect(e, isA<Exception>());
      }
    });
  });
}
