import 'package:flutter_riverpod/legacy.dart';

/// Holds the current app locale override language code.
///
/// A `null` value means the app should follow the system locale.
final appLocaleCodeProvider = StateProvider<String?>((ref) => null);
