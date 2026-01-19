import 'dart:convert';
import 'package:vagina/services/call_service.dart';

/// Host-side adapter for handling call control API calls from the isolate sandbox
///
/// Routes hostCall messages from the isolate to appropriate CallService
/// methods and converts responses to sendable Maps
class CallHostApi {
   static const _tag = 'CallHostApi';
   final CallService _callService;

   CallHostApi(this._callService);

   /// Handle API calls from the isolate
   ///
   /// Routes to appropriate CallService methods based on [method] parameter
   /// and returns serializable response Maps
   Future<Map<String, dynamic>> handleCall(
     String method,
     Map<String, dynamic> args,
   ) async {
     try {
       switch (method) {
         case 'end':
           return await _handleEnd(args);
         default:
           print('[$_tag:HOST] Unknown method: $method');
           print('Request Payload: ${jsonEncode(args)}');
           return {
             'success': false,
             'error': 'Unknown method: $method',
           };
       }
     } catch (e) {
       print('[$_tag:HOST] Error handling method: $method');
       print('Error: $e');
       print('Request Payload: ${jsonEncode(args)}');
       return {
         'success': false,
         'error': e.toString(),
       };
     }
   }

   Future<Map<String, dynamic>> _handleEnd(Map<String, dynamic> args) async {
     try {
       final endContext = args['endContext'] as String?;
       
       // Store end context if provided for call resumption purposes
       if (endContext != null && endContext.isNotEmpty) {
         _callService.setEndContext(endContext);
       }
       
       // Call endCall asynchronously (wait for completion)
       // This ensures the call ends properly before returning
       await _callService.endCall(endContext: endContext);
       
       return {
         'status': 'success',
         'message': 'Call ended successfully',
         'endContext': endContext,
       };
     } catch (e) {
       print('[$_tag:HOST] _handleEnd - Error: $e');
       print('Request Payload: ${jsonEncode(args)}');
       return {
         'status': 'error',
         'error': e.toString(),
       };
     }
   }
}
