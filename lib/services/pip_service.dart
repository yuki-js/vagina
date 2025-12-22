import 'dart:io';
import 'package:floating/floating.dart';
import 'log_service.dart';

/// Service for managing Picture-in-Picture (PiP) mode on mobile platforms
/// 
/// This service provides:
/// - Android PiP support with automatic aspect ratio
/// - iOS PiP support (when available)
/// - Seamless integration with call functionality
class PiPService {
  static const _tag = 'PiPService';
  
  final Floating _floating = Floating();
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
      final available = await _floating.isPipAvailable;
      logService.info(_tag, 'PiP available: $available');
      return available == true;
    } catch (e) {
      logService.error(_tag, 'Error checking PiP availability: $e');
      return false;
    }
  }

  /// Enable PiP mode
  /// 
  /// This should be called when the user wants to enable PiP.
  /// The actual PiP mode will activate when the app goes to background.
  Future<bool> enablePiP({
    int aspectRatioNumerator = 16,
    int aspectRatioDenominator = 9,
  }) async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      logService.warn(_tag, 'PiP not supported on this platform');
      return false;
    }
    
    try {
      logService.info(_tag, 'Enabling PiP mode');
      
      final pipEnabled = await _floating.enable(
        aspectRatio: Rational(aspectRatioNumerator, aspectRatioDenominator),
      ) as bool?;
      
      _isPiPEnabled = pipEnabled == true;
      
      if (_isPiPEnabled) {
        logService.info(_tag, 'PiP mode enabled successfully');
      } else {
        logService.warn(_tag, 'Failed to enable PiP mode');
      }
      
      return _isPiPEnabled;
    } catch (e) {
      logService.error(_tag, 'Error enabling PiP: $e');
      return false;
    }
  }

  /// Enter PiP mode immediately (Android only)
  /// 
  /// This will move the app to PiP mode right away.
  /// On iOS, PiP is typically handled by the system.
  Future<bool> enterPiPMode() async {
    if (!Platform.isAndroid) {
      logService.warn(_tag, 'Immediate PiP entry only supported on Android');
      return false;
    }
    
    try {
      logService.info(_tag, 'Entering PiP mode');
      
      // Enable PiP if not already enabled
      if (!_isPiPEnabled) {
        await enablePiP();
      }
      
      // Enter PiP mode (this will minimize the app to PiP)
      final result = await _floating.enable(
        aspectRatio: const Rational(16, 9),
      ) as bool?;
      
      _isPiPActive = result == true;
      
      if (_isPiPActive) {
        logService.info(_tag, 'Entered PiP mode successfully');
      }
      
      return _isPiPActive;
    } catch (e) {
      logService.error(_tag, 'Error entering PiP mode: $e');
      return false;
    }
  }

  /// Disable PiP mode
  Future<void> disablePiP() async {
    try {
      logService.info(_tag, 'Disabling PiP mode');
      
      _floating.dispose();
      
      _isPiPEnabled = false;
      _isPiPActive = false;
      
      logService.info(_tag, 'PiP mode disabled');
    } catch (e) {
      logService.error(_tag, 'Error disabling PiP: $e');
    }
  }

  /// Get PiP status
  /// Note: The floating package doesn't expose a status stream,
  /// so we track status internally
  bool get isPiPCurrentlyActive => _isPiPActive;

  /// Dispose the service
  Future<void> dispose() async {
    await disablePiP();
    logService.info(_tag, 'PiPService disposed');
  }
}
