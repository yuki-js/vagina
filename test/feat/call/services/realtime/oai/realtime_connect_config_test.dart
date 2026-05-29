import 'package:flutter_test/flutter_test.dart';
import 'package:vagina/feat/call/services/realtime/oai/realtime_connect_config.dart';

void main() {
  group('resolveRealtimeEndpoint', () {
    const cases = <({String input, String expected})>[
      (
        input:
            'http://localhost:11451/services/realtime-system/anthropic/v1?model=sonnet&machine=claude-realtime',
        expected:
            'ws://localhost:11451/services/realtime-system/anthropic/v1/realtime?model=sonnet&machine=claude-realtime',
      ),
      (
        input: 'https://default-msf-resource.services.ai.azure.com/v1',
        expected:
            'wss://default-msf-resource.services.ai.azure.com/v1/realtime',
      ),
      (
        input:
            'wss://my-eastus2-openai-resource.openai.azure.com/openai/v1?model=gpt-realtime-deployment-name',
        expected:
            'wss://my-eastus2-openai-resource.openai.azure.com/openai/v1/realtime?model=gpt-realtime-deployment-name',
      ),
      (
        input: 'https://myservice.com/v1?sysid=k',
        expected: 'wss://myservice.com/v1/realtime?sysid=k',
      ),
      (
        input:
            'https://my-resource.openai.azure.com/openai/deployments/my-model?deployment=my-model&api-version=2024-04-01-preview',
        expected:
            'wss://my-resource.openai.azure.com/openai/deployments/my-model/realtime?deployment=my-model&api-version=2024-04-01-preview',
      ),
    ];

    for (final testCase in cases) {
      test('resolves ${testCase.input}', () {
        final resolved = resolveRealtimeEndpoint(Uri.parse(testCase.input));
        expect(resolved.toString(), testCase.expected);
      });
    }

    test('normalizes endpoint fragments without a leading slash', () {
      final resolved = resolveRealtimeEndpoint(
        Uri.parse('https://example.com/v1/'),
        epFragment: 'events',
      );

      expect(resolved.toString(), 'wss://example.com/v1/events');
    });
  });
}
