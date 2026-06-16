import 'package:vagina/api/api_exception.dart';
import 'package:vagina/api/generated/models/json_rpc_version.dart';
import 'package:vagina/api/generated/models/vfs_method.dart';
import 'package:vagina/api/generated/models/vfs_rpc_params.dart';
import 'package:vagina/api/generated/models/vfs_rpc_request.dart';
import 'package:vagina/api/generated/models/vfs_rpc_result.dart';
import 'package:vagina/api/generated/responses/vfs_rpc_response.dart';
import 'package:vagina/api/vagina_api_client.dart';
import 'package:vagina/interfaces/virtual_filesystem_repository.dart';
import 'package:vagina/models/virtual_file.dart';
import 'package:vagina/services/log_service.dart';

class ApiVirtualFilesystemRepository implements VirtualFilesystemRepository {
  static const _tag = 'ApiVirtualFsRepo';
  static const _rpcFileNotFoundCode = -32004;

  final VaginaApiClient _apiClient;
  final LogService _logService;
  int _requestSequence = 0;

  ApiVirtualFilesystemRepository({
    required VaginaApiClient apiClient,
    LogService? logService,
  }) : _apiClient = apiClient,
       _logService = logService ?? LogService();

  @override
  Future<void> initialize() async {
    _logService.debug(_tag, 'Initializing remote VFS repository');
  }

  @override
  Future<VirtualFile?> read(String path) async {
    final request = _newRequest(
      method: VfsMethod.vfsRead,
      params: VfsRpcParams(path: path),
    );
    final response = await _apiClient.vfs.vfsRpc(body: request);

    switch (response) {
      case VfsRpcResponseSuccess(:final data):
        final error = data.error;
        if (error != null) {
          if (error.code == _rpcFileNotFoundCode) {
            return null;
          }
          throw StateError(error.message);
        }

        final file = data.result?.file;
        if (file == null) {
          return null;
        }
        return VirtualFile(path: file.path, content: file.content);
      case VfsRpcResponseBadRequest(:final data):
        throw ApiException.badRequest(data.message, operation: 'VFS read');
      case VfsRpcResponseForbidden(:final data):
        throw ApiException.forbidden(data.message, operation: 'VFS read');
      case VfsRpcResponseServerError(:final data):
        throw ApiException.serverError(data.message, operation: 'VFS read');
      case VfsRpcResponseUnknown(:final statusCode, :final body):
        throw _unknownResponseError(
          operation: 'VFS read',
          statusCode: statusCode,
          body: body,
        );
    }
  }

  @override
  Future<void> write(VirtualFile file) async {
    final result = await _execute(
      method: VfsMethod.vfsWrite,
      params: VfsRpcParams(path: file.path, content: file.content),
    );
    if (result.file == null) {
      throw StateError('VFS write failed: missing file in response.');
    }
  }

  @override
  Future<void> delete(String path) async {
    final request = _newRequest(
      method: VfsMethod.vfsDelete,
      params: VfsRpcParams(path: path),
    );
    final response = await _apiClient.vfs.vfsRpc(body: request);

    switch (response) {
      case VfsRpcResponseSuccess(:final data):
        final error = data.error;
        if (error == null) {
          return;
        }
        if (error.code == _rpcFileNotFoundCode) {
          return;
        }
        throw StateError(error.message);
      case VfsRpcResponseBadRequest(:final data):
        throw ApiException.badRequest(data.message, operation: 'VFS delete');
      case VfsRpcResponseForbidden(:final data):
        throw ApiException.forbidden(data.message, operation: 'VFS delete');
      case VfsRpcResponseServerError(:final data):
        throw ApiException.serverError(data.message, operation: 'VFS delete');
      case VfsRpcResponseUnknown(:final statusCode, :final body):
        throw _unknownResponseError(
          operation: 'VFS delete',
          statusCode: statusCode,
          body: body,
        );
    }
  }

  @override
  Future<void> move(String fromPath, String toPath) async {
    final result = await _execute(
      method: VfsMethod.vfsMove,
      params: VfsRpcParams(fromPath: fromPath, toPath: toPath),
    );
    if (result.fromPath == null || result.toPath == null) {
      throw StateError('VFS move failed: missing path fields in response.');
    }
  }

  @override
  Future<List<String>> list(String path, {bool recursive = false}) async {
    final result = await _execute(
      method: VfsMethod.vfsList,
      params: VfsRpcParams(path: path, recursive: recursive),
    );

    return result.entries ?? const <String>[];
  }

  Future<VfsRpcResult> _execute({
    required VfsMethod method,
    required VfsRpcParams params,
  }) async {
    final request = _newRequest(method: method, params: params);
    final response = await _apiClient.vfs.vfsRpc(body: request);

    switch (response) {
      case VfsRpcResponseSuccess(:final data):
        final error = data.error;
        if (error != null) {
          throw StateError(error.message);
        }
        final result = data.result;
        if (result == null) {
          throw StateError('VFS RPC failed: missing result.');
        }
        return result;
      case VfsRpcResponseBadRequest(:final data):
        throw ApiException.badRequest(data.message, operation: 'VFS RPC');
      case VfsRpcResponseForbidden(:final data):
        throw ApiException.forbidden(data.message, operation: 'VFS RPC');
      case VfsRpcResponseServerError(:final data):
        throw ApiException.serverError(data.message, operation: 'VFS RPC');
      case VfsRpcResponseUnknown(:final statusCode, :final body):
        throw _unknownResponseError(
          operation: 'VFS RPC',
          statusCode: statusCode,
          body: body,
        );
    }
  }

  VfsRpcRequest _newRequest({
    required VfsMethod method,
    required VfsRpcParams params,
  }) {
    _requestSequence++;
    return VfsRpcRequest(
      jsonrpc: JsonRpcVersion.value20,
      id: 'req-$_requestSequence',
      method: method,
      params: params,
    );
  }

  ApiException _unknownResponseError({
    required String operation,
    required int statusCode,
    required dynamic body,
  }) {
    return ApiException.unknown(
      _extractMessage(
        body,
        fallback: '$operation failed (status: $statusCode).',
      ),
      statusCode: statusCode,
      operation: operation,
    );
  }

  String _extractMessage(dynamic body, {required String fallback}) {
    if (body is Map) {
      final message = body['message'];
      if (message is String && message.trim().isNotEmpty) {
        return message;
      }
    }
    return fallback;
  }
}
