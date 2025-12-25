import 'dart:io' as io;
import 'package:flutter/foundation.dart';

/// Flutter Web 対応の Platform ラッパークラス
///
/// Webプラットフォーム上では全てのプラットフォーム判定が false を返し、
/// 環境変数はEmpty Mapを返す。
/// ネイティブプラットフォーム上では dart:io.Platform と同じ結果を返す。
class PlatformCompat {
  /// Windows プラットフォームかどうか
  static bool get isWindows {
    if (kIsWeb) return false;
    return io.Platform.isWindows;
  }

  /// macOS プラットフォームかどうか
  static bool get isMacOS {
    if (kIsWeb) return false;
    return io.Platform.isMacOS;
  }

  /// Linux プラットフォームかどうか
  static bool get isLinux {
    if (kIsWeb) return false;
    return io.Platform.isLinux;
  }

  /// Android プラットフォームかどうか
  static bool get isAndroid {
    if (kIsWeb) return false;
    return io.Platform.isAndroid;
  }

  /// iOS プラットフォームかどうか
  static bool get isIOS {
    if (kIsWeb) return false;
    return io.Platform.isIOS;
  }

  /// 環境変数へのアクセス
  /// Web上ではEmpty Mapを返す
  static Map<String, String> get environment {
    if (kIsWeb) return {};
    return io.Platform.environment;
  }

  /// デスクトッププラットフォームか（Windows/macOS/Linux）
  static bool get isDesktop {
    return isWindows || isMacOS || isLinux;
  }

  /// モバイルプラットフォームか（Android/iOS）
  static bool get isMobile {
    return isAndroid || isIOS;
  }

  /// ネイティブプラットフォーム（Web以外）か
  static bool get isNative {
    return !kIsWeb;
  }
}
