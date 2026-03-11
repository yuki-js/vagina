import 'package:flutter_test/flutter_test.dart';
import 'package:vagina/models/virtual_file.dart';

void main() {
  group('VirtualFile', () {
    test('extension returns regular extension', () {
      const file = VirtualFile(path: '/documents/notes.txt', content: 'hello');
      expect(file.extension, '.txt');
    });

    test('extension returns double extension for v2d files', () {
      const file = VirtualFile(
        path: '/data/sales.v2d.csv',
        content: 'name,revenue\nAlice,100',
      );
      expect(file.extension, '.v2d.csv');
    });

    test('extension detects double extension for uppercase v2d files', () {
      const file = VirtualFile(
        path: '/data/sales.V2D.JSON',
        content: '[{"name":"Alice"}]',
      );
      expect(file.extension, '.V2D.JSON');
    });

    test('extension returns empty string when no extension exists', () {
      const file = VirtualFile(path: '/documents/README', content: 'hello');
      expect(file.extension, '');
    });

    test('toJson and fromJson round-trip preserves data', () {
      const original = VirtualFile(
        path: '/docs/plan.md',
        content: '# Plan',
      );

      final restored = VirtualFile.fromJson(original.toJson());
      expect(restored.path, original.path);
      expect(restored.content, original.content);
    });
  });
}
