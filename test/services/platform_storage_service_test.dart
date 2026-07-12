import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:vagina/services/platform/platform_storage_service.dart';

void main() {
  group('PlatformStorageService', () {
    late Directory temporaryDirectory;

    setUp(() async {
      temporaryDirectory = await Directory.systemTemp.createTemp(
        'vagina-non-backup-storage-test-',
      );
    });

    tearDown(() async {
      if (await temporaryDirectory.exists()) {
        await temporaryDirectory.delete(recursive: true);
      }
    });

    test(
      'creates the requested folder below the native non-backup root',
      () async {
        final service = PlatformStorageService(
          nativeStorageRootProvider: () async => temporaryDirectory.path,
        );

        final directory = await service.getStorageDirectory(
          folderName: 'VAGINA',
        );

        expect(directory.path, path.join(temporaryDirectory.path, 'VAGINA'));
        expect(await directory.exists(), isTrue);
      },
    );

    test('builds file paths below the requested folder', () async {
      final service = PlatformStorageService(
        nativeStorageRootProvider: () async => temporaryDirectory.path,
      );

      final filePath = await service.getFilePath(
        'vagina_config.json',
        folderName: 'VAGINA',
      );

      expect(
        filePath,
        path.join(temporaryDirectory.path, 'VAGINA', 'vagina_config.json'),
      );
    });

    test('rejects an empty native storage root', () async {
      final service = PlatformStorageService(
        nativeStorageRootProvider: () async => '  ',
      );

      expect(
        () => service.getStorageDirectory(folderName: 'VAGINA'),
        throwsStateError,
      );
    });
  });
}
