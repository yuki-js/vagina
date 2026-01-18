/// Platform-specific protocol validation for Web (pseudo-isolate)
library sandbox_protocol_platform;

import 'web_pseudo_isolate.dart' show WebSendPort;

/// Validate if a value is a valid replyTo port
bool isValidReplyTo(Object? value) {
  return value is WebSendPort;
}

/// Get the type name for error messages
String replyToTypeName() => 'WebSendPort';

/// Type alias for port (for type safety at call sites)
typedef ReplyToPort = WebSendPort;
