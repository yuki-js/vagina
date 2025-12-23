import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Picture-in-Picture service for Android and iOS
/// 
/// This service provides PiP functionality using platform channels.
/// - Android 8.0+ (API 26+): Full PiP support with aspect ratio control
/// - iOS 9.0+: Basic PiP support (system-managed)
class PiPService {
  static const _channel = MethodChannel('com.example.vagina/pip');
  
  bool _isEnabled = false;
  bool _isInPiPMode = false;

  bool get isEnabled => _isEnabled;
  bool get isInPiPMode => _isInPiPMode;

  /// Check if PiP is available on this platform
  Future<bool> isPiPAvailable() async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return false;
    }

    try {
      final bool? available = await _channel.invokeMethod('isPiPAvailable');
      return available ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Enable PiP mode
  Future<void> enablePiP() async {
    if (!await isPiPAvailable()) {
      return;
    }

    try {
      await _channel.invokeMethod('enablePiP');
      _isEnabled = true;
    } catch (e) {
      // Handle error
    }
  }

  /// Disable PiP mode
  Future<void> disablePiP() async {
    try {
      await _channel.invokeMethod('disablePiP');
      _isEnabled = false;
      _isInPiPMode = false;
    } catch (e) {
      // Handle error
    }
  }

  /// Enter PiP mode immediately (Android only)
  Future<bool> enterPiPMode({
    double aspectRatio = 16.0 / 9.0,
  }) async {
    if (!Platform.isAndroid) {
      return false;
    }

    try {
      final bool? result = await _channel.invokeMethod('enterPiPMode', {
        'aspectRatio': aspectRatio,
      });
      
      if (result == true) {
        _isInPiPMode = true;
      }
      
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Exit PiP mode
  Future<void> exitPiPMode() async {
    try {
      await _channel.invokeMethod('exitPiPMode');
      _isInPiPMode = false;
    } catch (e) {
      // Handle error
    }
  }

  /// Setup PiP state listener
  void setupListener(Function(bool) onPiPModeChanged) {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onPiPModeChanged') {
        final bool isInPiP = call.arguments as bool;
        _isInPiPMode = isInPiP;
        onPiPModeChanged(isInPiP);
      }
    });
  }
}

/// Provider for PiP service
final pipServiceProvider = Provider<PiPService>((ref) {
  return PiPService();
});
