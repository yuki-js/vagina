import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vagina/core/app/app_container.dart';
import 'package:vagina/feat/call/models/text_agent_info.dart';

final textAgentsProvider = FutureProvider<List<TextAgentInfo>>((ref) async {
  final repo = AppContainer.config;
  return repo.getAllTextAgents();
});
