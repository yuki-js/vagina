/// Opaque provider-extension identifiers for session-level realtime updates.
///
/// These are application-level extension keys and payload shapes. Individual
/// adapters translate them into provider-native configuration payloads.
abstract final class RealtimeProviderExtensions {
  static const String inputNoiseReductionSelection =
      'session.input_noise_reduction_selection';

  static const String selectionKey = 'selection';
}
