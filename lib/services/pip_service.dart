import 'dart:io';
import 'package:flutter/services.dart';
import 'log_service.dart';

/// Service for managing Picture-in-Picture (PiP) mode on mobile platforms
/// 
/// This service provides:
/// - Android PiP support using platform channels
/// - iOS PiP support (system-managed)
/// - Seamless integration with call functionality
class PiPService {
  static const _tag = 'PiPService';
  static const _channel = MethodChannel('com.example.vagina/pip');
  
  bool _isPiPEnabled = false;
  bool _isPiPActive = false;

  bool get isPiPEnabled => _isPiPEnabled;
  bool get isPiPActive => _isPiPActive;

  /// Check if PiP is available on this platform
  Future<bool> isPiPAvailable() async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return false;
    }
    
    try {
      if (Platform.isAndroid) {
        // Android 8.0+ (API 26+) supports PiP
        final bool? available = await _channel.invokeMethod('isPiPAvailable');
        logService.info(_tag, 'PiP available on Android: $available');
        return available ?? false;
      } else {
        // iOS supports PiP on iPad with iOS 9+
        logService.info(_tag, 'PiP is available on iOS (system-managed)');
        return true;
      }
    } catch (e) {
      logService.error(_tag, 'Error checking PiP availability: $e');
      return false;
    }
  }

  /// Enable PiP mode
  Future<bool> enablePiP() async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      logService.warn(_tag, 'PiP not supported on this platform');
      return false;
    }
    
    try {
      logService.info(_tag, 'Enabling PiP mode');
      _isPiPEnabled = true;
      logService.info(_tag, 'PiP mode enabled successfully');
      return true;
    } catch (e) {
      logService.error(_tag, 'Error enabling PiP: $e');
      return false;
    }
  }

  /// Disable PiP mode
  Future<void> disablePiP() async {
    try {
      logService.info(_tag, 'Disabling PiP mode');
      _isPiPEnabled = false;
      _isPiPActive = false;
      logService.info(_tag, 'PiP mode disabled');
    } catch (e) {
      logService.error(_tag, 'Error disabling PiP: $e');
    }
  }

  /// Enter PiP mode immediately (Android only)
  Future<bool> enterPiPMode() async {
    if (!Platform.isAndroid) {
      logService.warn(_tag, 'Immediate PiP entry only supported on Android');
      return false;
    }
    
    try {
      logService.info(_tag, 'Entering PiP mode');
      
      // Call native Android PiP
      final bool? success = await _channel.invokeMethod('enterPiPMode', {
        'aspectRatio': [16, 9],
      });
      
      _isPiPActive = success ?? false;
      logService.info(_tag, 'Entered PiP mode: $success');
      return _isPiPActive;
    } catch (e) {
      logService.error(_tag, 'Error entering PiP: $e');
      return false;
    }
  }

  /// Exit PiP mode
  Future<void> exitPiPMode() async {
    try {
      logService.info(_tag, 'Exiting PiP mode');
      _isPiPActive = false;
      logService.info(_tag, 'Exited PiP mode');
    } catch (e) {
      logService.error(_tag, 'Error exiting PiP: $e');
    }
  }

  /// Dispose resources
  void dispose() {
    logService.info(_tag, 'Disposing PiP service');
    _isPiPEnabled = false;
    _isPiPActive = false;
  }
}
