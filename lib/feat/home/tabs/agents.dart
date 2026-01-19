import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vagina/feat/text_agents/ui/screens/agents_screen.dart';

/// Agents tab - Text agent management
class AgentsTab extends ConsumerWidget {
  const AgentsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const AgentsScreen();
  }
}
