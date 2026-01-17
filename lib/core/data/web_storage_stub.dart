/// Stub file for web storage when not running on web platform.
///
/// This file is used in conditional imports to provide a fallback
/// implementation when the app is not running on web. The actual
/// web implementation uses `dart:html`.
///
/// Usage in `json_file_store.dart`:
/// ```dart
/// import 'web_storage_stub.dart'
///     if (dart.library.html) 'dart:html' as html;
/// ```
///
/// When running on web, `dart:html` is used with `html.window.localStorage`.
/// On other platforms, this stub is used to prevent compilation errors.
library;

/// Stub for web localStorage when not running on web
class _Storage {
  String? operator [](String key) => null;
  void operator []=(String key, String value) {}
}

/// Stub for web window object when not running on web
class _Window {
  final _Storage localStorage = _Storage();
}

/// Global window stub instance
final window = _Window();
