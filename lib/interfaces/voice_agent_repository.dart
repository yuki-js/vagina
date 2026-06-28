import 'package:vagina/models/voice_agent.dart';

abstract class VoiceAgentRepository {
  Future<List<VoiceAgent>> listVoiceAgents();
}
