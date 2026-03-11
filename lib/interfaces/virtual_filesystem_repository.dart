import 'package:vagina/models/virtual_file.dart';

/// Persistence contract for the virtual filesystem.
///
/// Paths are expected to be normalized absolute paths.
abstract class VirtualFilesystemRepository {
  Future<void> initialize();

  /// Read a file at [path]. Returns null if not found.
  Future<VirtualFile?> read(String path);

  /// Create or overwrite a file.
  Future<void> write(VirtualFile file);

  /// Delete a file by path.
  Future<void> delete(String path);

  /// Move or rename a file.
  Future<void> move(String fromPath, String toPath);

  /// List entries under [path].
  ///
  /// - `recursive: false` returns immediate child basenames.
  /// - `recursive: true` returns all descendant paths relative to [path].
  Future<List<String>> list(String path, {bool recursive = false});
}
