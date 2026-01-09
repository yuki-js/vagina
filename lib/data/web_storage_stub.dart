/// Stub for web storage when not running on web
class _Storage {
  String? operator [](String key) => null;
  void operator []=(String key, String value) {}
}

class _Window {
  final _Storage localStorage = _Storage();
}

final window = _Window();
