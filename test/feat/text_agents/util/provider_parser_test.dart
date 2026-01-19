import 'package:flutter_test/flutter_test.dart';
import 'package:vagina/feat/text_agents/util/provider_parser.dart';
import 'package:vagina/feat/text_agents/model/text_agent_provider.dart';

void main() {
  group('ProviderParser.detectProvider', () {
    test('detects OpenAI from api.openai.com URL', () {
      final provider =
          ProviderParser.detectProvider('https://api.openai.com/v1/chat/completions');
      expect(provider, TextAgentProvider.openai);
    });

    test('detects Azure from azure URL', () {
      final provider = ProviderParser.detectProvider(
          'https://myresource.openai.azure.com/openai/deployments/gpt-4/chat/completions?api-version=2024-10-01-preview');
      expect(provider, TextAgentProvider.azure);
    });

    test('defaults to custom for unrecognized URL', () {
      final provider =
          ProviderParser.detectProvider('https://example.com/v1/chat/completions');
      expect(provider, TextAgentProvider.custom);
    });

    test('defaults to custom for invalid URL', () {
      final provider = ProviderParser.detectProvider('not-a-url');
      expect(provider, TextAgentProvider.custom);
    });

    test('handles case-insensitive detection', () {
      final provider = ProviderParser.detectProvider('https://MYRESOURCE.OPENAI.AZURE.COM');
      expect(provider, TextAgentProvider.azure);
    });
  });

  group('ProviderParser.validateUrl', () {
    test('accepts valid HTTPS OpenAI URL', () {
      final error = ProviderParser.validateUrl('https://api.openai.com', TextAgentProvider.openai);
      expect(error, isNull);
    });

    test('accepts valid HTTPS Azure URL', () {
      final error = ProviderParser.validateUrl(
          'https://myresource.openai.azure.com', TextAgentProvider.azure);
      expect(error, isNull);
    });

    test('rejects empty URL', () {
      final error = ProviderParser.validateUrl('', TextAgentProvider.openai);
      expect(error, isNotNull);
      expect(error, contains('URLを入力してください'));
    });

    test('rejects invalid URL format', () {
      final error =
          ProviderParser.validateUrl('not-a-url', TextAgentProvider.openai);
      expect(error, isNotNull);
      expect(error, contains('有効なURLを入力してください'));
    });

    test('accepts HTTP for localhost', () {
      final error = ProviderParser.validateUrl(
          'http://localhost:4000', TextAgentProvider.litellm);
      expect(error, isNull);
    });

    test('rejects FTP URL', () {
      final error = ProviderParser.validateUrl(
          'ftp://example.com', TextAgentProvider.custom);
      expect(error, isNotNull);
      expect(error, contains('HTTP/HTTPSのURLを入力してください'));
    });

    test('warns about non-Azure URL for Azure provider', () {
      final error = ProviderParser.validateUrl(
          'https://example.com', TextAgentProvider.azure);
      expect(error, isNotNull);
      expect(error, contains('Azure'));
    });
  });

  group('ProviderParser.parseAzureUrl', () {
    test('extracts resource, deployment, and version from complete Azure URL', () {
      const url =
          'https://myresource.openai.azure.com/openai/deployments/gpt-4/chat/completions?api-version=2024-10-01-preview';
      final parsed = ProviderParser.parseAzureUrl(url);

      expect(parsed['resource'], 'myresource');
      expect(parsed['deployment'], 'gpt-4');
      expect(parsed['version'], '2024-10-01-preview');
    });

    test('handles URL without deployment in path', () {
      const url = 'https://myresource.openai.azure.com';
      final parsed = ProviderParser.parseAzureUrl(url);

      expect(parsed['resource'], 'myresource');
      expect(parsed['deployment'], isNull);
      expect(parsed['version'], isNull);
    });

    test('handles URL without query parameters', () {
      const url = 'https://myresource.openai.azure.com/openai/deployments/gpt-4/chat/completions';
      final parsed = ProviderParser.parseAzureUrl(url);

      expect(parsed['resource'], 'myresource');
      expect(parsed['deployment'], 'gpt-4');
      expect(parsed['version'], isNull);
    });

    test('handles invalid URL gracefully', () {
      final parsed = ProviderParser.parseAzureUrl('not-a-url');

      expect(parsed['resource'], isNull);
      expect(parsed['deployment'], isNull);
      expect(parsed['version'], isNull);
    });

    test('extracts version with different formats', () {
      const url =
          'https://test.openai.azure.com/openai/deployments/deploy1/chat/completions?api-version=2024-08-01-preview';
      final parsed = ProviderParser.parseAzureUrl(url);

      expect(parsed['version'], '2024-08-01-preview');
    });
  });

  group('ProviderParser.getProviderHelpText', () {
    test('returns OpenAI help text', () {
      final text = ProviderParser.getProviderHelpText(TextAgentProvider.openai);
      expect(text, contains('OpenAI'));
      expect(text, contains('api.openai.com'));
    });

    test('returns Azure help text', () {
      final text = ProviderParser.getProviderHelpText(TextAgentProvider.azure);
      expect(text, contains('Azure'));
    });

    test('returns LiteLLM help text', () {
      final text = ProviderParser.getProviderHelpText(TextAgentProvider.litellm);
      expect(text, contains('LiteLLM'));
    });

    test('returns Custom help text', () {
      final text = ProviderParser.getProviderHelpText(TextAgentProvider.custom);
      expect(text, contains('OpenAI互換'));
    });
  });

  group('ProviderParser.getExampleUrl', () {
    test('returns model name for OpenAI', () {
      final example = ProviderParser.getExampleUrl(TextAgentProvider.openai);
      expect(example, 'gpt-4o');
    });

    test('returns Azure endpoint example', () {
      final example = ProviderParser.getExampleUrl(TextAgentProvider.azure);
      expect(example, contains('openai.azure.com'));
    });

    test('returns localhost for LiteLLM', () {
      final example = ProviderParser.getExampleUrl(TextAgentProvider.litellm);
      expect(example, contains('localhost'));
    });

    test('returns generic example for Custom', () {
      final example = ProviderParser.getExampleUrl(TextAgentProvider.custom);
      expect(example, contains('example.com'));
    });
  });

  group('ProviderParser.isEndpointUrl', () {
    test('recognizes valid endpoint URLs', () {
      expect(ProviderParser.isEndpointUrl('https://api.example.com'), true);
      expect(ProviderParser.isEndpointUrl('http://localhost:4000'), true);
      expect(ProviderParser.isEndpointUrl('https://test.openai.azure.com'), true);
    });

    test('rejects non-URL strings', () {
      expect(ProviderParser.isEndpointUrl('gpt-4o'), false);
      expect(ProviderParser.isEndpointUrl('not-a-url'), false);
      expect(ProviderParser.isEndpointUrl(''), false);
    });
  });

  group('ProviderParser.normalizeUrl', () {
    test('removes trailing slashes', () {
      expect(
        ProviderParser.normalizeUrl('https://api.example.com/'),
        'https://api.example.com',
      );
    });

    test('removes whitespace', () {
      expect(
        ProviderParser.normalizeUrl('  https://api.example.com  '),
        'https://api.example.com',
      );
    });

    test('handles multiple trailing slashes', () {
      expect(
        ProviderParser.normalizeUrl('https://api.example.com///'),
        'https://api.example.com',
      );
    });

    test('preserves path segments', () {
      expect(
        ProviderParser.normalizeUrl('https://api.example.com/v1/chat/'),
        'https://api.example.com/v1/chat',
      );
    });
  });
}
