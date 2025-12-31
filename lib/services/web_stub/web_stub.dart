// Stub file for non-web platforms
// This file provides empty implementations for web-only functionality

library web_stub;

// Dummy class to prevent compilation errors on non-web platforms
class Window {
  Storage get localStorage => Storage();
}

class Storage {
  String? operator [](String key) => null;
  void operator []=(String key, String value) {}
  void removeItem(String key) {}
}

final window = Window();
