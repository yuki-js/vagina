/// Platform-specific protocol validation for Native (dart:isolate)
library sandbox_protocol_platform;

import 'dart:isolate' show SendPort;

/// Validate if a value is a valid replyTo port
bool isValidReplyTo(Object? value) {
  return value is SendPort;
}

/// Get the type name for error messages
String replyToTypeName() => 'SendPort';

/// Type alias for port (for type safety at call sites)
typedef ReplyToPort = SendPort;
