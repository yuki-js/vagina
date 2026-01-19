import 'dart:convert';

/// Abstract API for call control operations
///
/// This API allows tools running in isolates to control call behavior.
/// All operations are asynchronous and return sendable types (Map, List, primitives).
abstract class CallApi {
  /// End the current call
  ///
  /// Arguments:
  /// - endContext: Optional context string about why the call is ending
  ///
  /// Returns true if successful, false otherwise
  Future<bool> endCall({String? endContext});
}

/// Client implementation of CallApi that uses hostCall for isolate communication
class CallApiClient implements CallApi {
  static const _tag = 'CallApiClient';
  final Future<Map<String, dynamic>> Function(String method, Map<String, dynamic> args) hostCall;
  
  CallApiClient({required this.hostCall});
  
  @override
  Future<bool> endCall({String? endContext}) async {
     try {
       final args = <String, dynamic>{};
       if (endContext != null) {
         args['endContext'] = endContext;
       }
       
       final result = await hostCall('end', args);
       
       // Null check
       if (result == null) {
         print('[TOOL:GUEST] $_tag - Received null response from host');
         throw Exception('Received null response from host');
       }
       
       final status = result['status'] as String?;
       if (status == 'success') {
         return true;
       }
       
       // Handle error
       if (status == 'error') {
         final error = result['error'] as String? ?? 'Unknown error';
         print('[TOOL:GUEST] $_tag - Failed to end call');
         print('Error: $error');
         print('Request Payload: ${jsonEncode(args)}');
         throw Exception('Failed to end call: $error');
       }
       
       // Unexpected status
       throw Exception('Unexpected response status: $status');
     } catch (e) {
       print('[TOOL:GUEST] $_tag.endCall - Error: $e');
       rethrow;
     }
   }
}
