import 'package:vagina/services/call_feedback_service.dart';

/// Backward-compatible wrapper for historical `CallAudioFeedbackService`.
///
/// The codebase has been consolidated into [`CallFeedbackService`](lib/services/call_feedback_service.dart:1)
/// (audio + haptics). Some tests and legacy call sites still expect this class name.
class CallAudioFeedbackService extends CallFeedbackService {
  CallAudioFeedbackService({super.logService});
}
