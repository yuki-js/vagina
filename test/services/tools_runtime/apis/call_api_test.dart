import 'package:flutter_test/flutter_test.dart';
import 'package:vagina/services/tools_runtime/apis/call_api.dart';

void main() {
  group('CallApiClient', () {
    test('endCall forwards method and args', () async {
      String? calledMethod;
      Map<String, dynamic>? calledArgs;

      final client = CallApiClient(
        hostCall: (method, args) async {
          calledMethod = method;
          calledArgs = args;
          return null;
        },
      );

      await client.endCall(endContext: 'done');

      expect(calledMethod, 'end');
      expect(calledArgs, {'endContext': 'done'});
    });
  });
}
