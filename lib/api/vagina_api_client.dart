import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:vagina/core/config/app_config.dart';
import 'package:vagina/api/generated/clients/auth_api_client.dart';
import 'package:vagina/api/generated/clients/speed_dials_api_client.dart';
import 'package:vagina/api/generated/clients/vfs_api_client.dart';

/// Builds API clients backed by florval-generated clients and models.
class VaginaApiClient {
  static const String _retryFlagKey = 'auth_retry_attempted';

  final Dio dio;
  final AuthApiClient auth;
  final SpeedDialsApiClient speedDials;
  final VfsApiClient vfs;

  VaginaApiClient._({
    required this.dio,
    required this.auth,
    required this.speedDials,
    required this.vfs,
  });

  factory VaginaApiClient({
    Future<String?> Function()? accessTokenProvider,
    Future<String?> Function()? onUnauthorizedRefresh,
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

    if (accessTokenProvider != null) {
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) async {
            if (_shouldAttachAuthorization(options.path)) {
              final token = await accessTokenProvider.call();
              if (token != null && token.trim().isNotEmpty) {
                options.headers['Authorization'] = 'Bearer ${token.trim()}';
              }
            }
            handler.next(options);
          },
          onError: (error, handler) async {
            if (onUnauthorizedRefresh == null ||
                !_shouldRetryUnauthorized(error)) {
              handler.next(error);
              return;
            }

            try {
              final refreshedToken = await onUnauthorizedRefresh.call();
              final normalized = refreshedToken?.trim();
              if (normalized == null || normalized.isEmpty) {
                handler.next(error);
                return;
              }

              final requestOptions = error.requestOptions;
              final retryHeaders = Map<String, dynamic>.from(
                requestOptions.headers,
              );
              retryHeaders['Authorization'] = 'Bearer $normalized';

              final retryExtra = Map<String, dynamic>.from(
                requestOptions.extra,
              );
              retryExtra[_retryFlagKey] = true;

              final retryRequest = requestOptions.copyWith(
                headers: retryHeaders,
                extra: retryExtra,
              );
              final retryResponse = await dio.fetch<dynamic>(retryRequest);
              handler.resolve(retryResponse);
            } catch (_) {
              handler.next(error);
            }
          },
        ),
      );
    }

    return VaginaApiClient._(
      dio: dio,
      auth: AuthApiClient(dio),
      speedDials: SpeedDialsApiClient(dio),
      vfs: VfsApiClient(dio),
    );
  }

  static bool _shouldAttachAuthorization(String path) {
    return !path.startsWith('/auth/oidc/') &&
        path != '/auth/refresh' &&
        path != '/auth/logout';
  }

  static bool _shouldRetryUnauthorized(DioException error) {
    final requestOptions = error.requestOptions;
    return error.response?.statusCode == 401 &&
        _shouldAttachAuthorization(requestOptions.path) &&
        requestOptions.extra[_retryFlagKey] != true;
  }

  static String _resolveApiBaseUrl() {
    return AppConfig.resolveApiBaseUrl(isDebugMode: kDebugMode);
  }
}
