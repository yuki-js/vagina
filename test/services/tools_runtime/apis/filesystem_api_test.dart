import 'package:flutter_test/flutter_test.dart';
import 'package:vagina/services/tools_runtime/apis/filesystem_api.dart';

void main() {
  group('FilesystemApiClient', () {
    test('read returns map payload', () async {
      final client = FilesystemApiClient(
        hostCall: (method, args) async {
          expect(method, 'read');
          expect(args['path'], '/a.txt');
          return {'path': '/a.txt', 'content': 'hello'};
        },
      );

      final result = await client.read('/a.txt');
      expect(result, isNotNull);
      expect(result!['path'], '/a.txt');
      expect(result['content'], 'hello');
    });

    test('list returns string list', () async {
      final client = FilesystemApiClient(
        hostCall: (method, args) async {
          expect(method, 'list');
          expect(args['path'], '/');
          expect(args['recursive'], true);
          return ['docs/', 'a.txt'];
        },
      );

      final result = await client.list('/', recursive: true);
      expect(result, ['docs/', 'a.txt']);
    });

    test('listActiveFiles returns map list', () async {
      final client = FilesystemApiClient(
        hostCall: (method, args) async {
          expect(method, 'listActiveFiles');
          return [
            {'path': '/a.txt', 'content': 'hello'}
          ];
        },
      );

      final result = await client.listActiveFiles();
      expect(result, hasLength(1));
      expect(result.first['path'], '/a.txt');
      expect(result.first['content'], 'hello');
    });

    test('read throws on invalid payload shape', () async {
      final client = FilesystemApiClient(
        hostCall: (_, __) async => 'invalid',
      );

      expect(
        () => client.read('/a.txt'),
        throwsA(isA<StateError>()),
      );
    });
  });
}
