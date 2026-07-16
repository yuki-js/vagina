import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:vagina/api/auth_exception.dart';
import 'package:vagina/api/generated/clients/auth_api_client.dart';
import 'package:vagina/api/generated/clients/sessions_api_client.dart';
import 'package:vagina/api/generated/clients/speed_dials_api_client.dart';
import 'package:vagina/api/generated/clients/text_agent_models_api_client.dart';
import 'package:vagina/api/generated/clients/text_agents_api_client.dart';
import 'package:vagina/api/generated/clients/vfs_api_client.dart';
import 'package:vagina/api/generated/clients/voice_agents_api_client.dart';
import 'package:vagina/core/config/app_config.dart';

typedef AuthTokenSupplier = Future<String> Function({bool forceRefresh});

/// Builds API clients backed by florval-generated clients and models.
class VaginaApiClient {
  static const String _authRetryExtraKey = 'vagina.auth.retry';
  static const Duration _textAgentQueryTimeout = Duration(minutes: 30);

  final Dio dio;
  final AuthApiClient auth;
  final SpeedDialsApiClient speedDials;
  final SessionsApiClient sessions;
  final TextAgentModelsApiClient textAgentModels;
  final TextAgentsApiClient textAgents;
  final VfsApiClient vfs;
  final VoiceAgentsApiClient voiceAgents;

  VaginaApiClient._({
    required this.dio,
    required this.auth,
    required this.speedDials,
    required this.sessions,
    required this.textAgentModels,
    required this.textAgents,
    required this.vfs,
    required this.voiceAgents,
  });

  factory VaginaApiClient({
    AuthTokenSupplier? getAccessToken,
    Future<void> Function()? onAuthenticationFailure,
    Dio? dioOverride,
  }) {
    final dio =
        dioOverride ??
        Dio(
          BaseOptions(
            baseUrl: _resolveApiBaseUrl(),
            connectTimeout: const Duration(milliseconds: 30000),
            receiveTimeout: const Duration(milliseconds: 30000),
            sendTimeout: const Duration(milliseconds: 30000),
          ),
        );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (_isTextAgentQuery(options.path)) {
            options.sendTimeout = _textAgentQueryTimeout;
            options.receiveTimeout = _textAgentQueryTimeout;
          }
          handler.next(options);
        },
      ),
    );

    if (getAccessToken != null) {
      final retryDio = _buildRetryDio(dio);
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) async {
            if (!_shouldAttachAuthorization(options.path)) {
              handler.next(options);
              return;
            }

            try {
              final token = await getAccessToken.call();
              _attachBearerToken(options, token);
              handler.next(options);
            } on AuthException catch (error) {
              handler.reject(
                DioException(
                  requestOptions: options,
                  type: DioExceptionType.unknown,
                  error: error,
                  message: error.message,
                ),
              );
            }
          },
          onError: (error, handler) async {
            if (!_shouldRecoverFromUnauthorized(error)) {
              handler.next(error);
              return;
            }

            final retryRequest = _cloneForAuthRetry(error.requestOptions);

            try {
              final token = await getAccessToken.call(forceRefresh: true);
              _attachBearerToken(retryRequest, token);
              final response = await retryDio.fetch<dynamic>(retryRequest);
              handler.resolve(response);
            } on AuthException catch (authError) {
              await onAuthenticationFailure?.call();
              handler.reject(
                DioException(
                  requestOptions: retryRequest,
                  type: DioExceptionType.unknown,
                  error: authError,
                  message: authError.message,
                ),
              );
            } on DioException catch (retryError) {
              if (retryError.response?.statusCode == 401) {
                await onAuthenticationFailure?.call();
              }
              handler.reject(retryError);
            } catch (retryError) {
              handler.reject(
                DioException(
                  requestOptions: retryRequest,
                  type: DioExceptionType.unknown,
                  error: retryError,
                  message: retryError.toString(),
                ),
              );
            }
          },
        ),
      );
    }

    return VaginaApiClient._(
      dio: dio,
      auth: AuthApiClient(dio),
      speedDials: SpeedDialsApiClient(dio),
      sessions: SessionsApiClient(dio),
      textAgentModels: TextAgentModelsApiClient(dio),
      textAgents: TextAgentsApiClient(dio),
      vfs: VfsApiClient(dio),
      voiceAgents: VoiceAgentsApiClient(dio),
    );
  }

  static Dio _buildRetryDio(Dio source) {
    final retryDio = Dio(source.options.copyWith());
    retryDio.httpClientAdapter = source.httpClientAdapter;
    retryDio.transformer = source.transformer;
    return retryDio;
  }

  static RequestOptions _cloneForAuthRetry(RequestOptions source) {
    return source.copyWith(
      headers: Map<String, dynamic>.from(source.headers),
      extra: <String, dynamic>{...source.extra, _authRetryExtraKey: true},
    );
  }

  static bool _isTextAgentQuery(String path) {
    final segments = Uri.parse(path).pathSegments;
    return segments.length == 3 &&
        segments.first == 'text-agents' &&
        segments.last == 'query' &&
        segments[1].isNotEmpty;
  }

  static bool _shouldAttachAuthorization(String path) {
    return !path.startsWith('/auth/oidc/') &&
        path != '/auth/refresh' &&
        path != '/auth/logout';
  }

  static bool _shouldRecoverFromUnauthorized(DioException error) {
    final statusCode = error.response?.statusCode;
    final request = error.requestOptions;
    if (statusCode != 401) {
      return false;
    }
    if (!_shouldAttachAuthorization(request.path)) {
      return false;
    }
    return request.extra[_authRetryExtraKey] != true;
  }

  static void _attachBearerToken(RequestOptions options, String token) {
    options.headers['Authorization'] = 'Bearer ${token.trim()}';
  }

  static String _resolveApiBaseUrl() {
    return AppConfig.resolveApiBaseUrl(isDebugMode: kDebugMode);
  }
}
