import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vagina/repositories/repository_factory.dart';
import 'package:vagina/feat/call/models/text_agent_info.dart';

final textAgentsProvider = FutureProvider<List<TextAgentInfo>>((ref) async {
  final repo = RepositoryFactory.config;
  return repo.getAllTextAgents();
});
