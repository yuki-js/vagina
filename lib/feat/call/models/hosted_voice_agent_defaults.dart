/// Default values for the VAGINA hosted realtime voice agent.
///
/// The [defaultModelId] is the only model currently registered in the
/// server's `vagina.realtime.models.*` registry (application.properties).
/// Sending an unknown modelId results in a `session.unknown_model` error from
/// the server.
///
/// TODO(P1): Expose the full model list from the server registry endpoint so
/// the client can present a proper picker instead of this single constant.
/// Align with `vagina.realtime.models.*` in application.properties whenever
/// the registry is expanded.
class HostedVoiceAgentDefaults {
  HostedVoiceAgentDefaults._();

  /// The canonical modelId for the production hosted voice-agent model.
  ///
  /// Corresponds to the `voice-agent-prod` key in
  /// `server/src/main/resources/application.properties`:
  /// ```
  /// vagina.realtime.models.voice-agent-prod.provider=oai
  /// ```
  static const String defaultModelId = 'voice-agent-prod';
}
