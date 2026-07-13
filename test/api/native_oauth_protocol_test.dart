import 'package:flutter_test/flutter_test.dart';
import 'package:vagina/api/native_oauth_protocol_io.dart';

void main() {
  group('shouldRegisterNativeOAuthProtocol', () {
    test('uses the per-user registry for unpackaged Windows execution', () {
      expect(
        shouldRegisterNativeOAuthProtocol(
          isWindows: true,
          hasPackageIdentity: false,
        ),
        isTrue,
      );
    });

    test('never writes the registry for packaged Windows execution', () {
      expect(
        shouldRegisterNativeOAuthProtocol(
          isWindows: true,
          hasPackageIdentity: true,
        ),
        isFalse,
      );
    });

    test('does not register the Windows protocol on another platform', () {
      expect(
        shouldRegisterNativeOAuthProtocol(
          isWindows: false,
          hasPackageIdentity: false,
        ),
        isFalse,
      );
    });
  });
}
