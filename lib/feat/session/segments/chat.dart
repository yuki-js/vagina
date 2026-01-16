import 'package:flutter/material.dart';

import 'package:vagina/feat/session/widgets/historical_chat_view.dart';

/// Session detail segment - chat history view.
class SessionDetailChatSegment extends StatelessWidget {
  final List<String> chatMessages;

  const SessionDetailChatSegment({
    super.key,
    required this.chatMessages,
  });

  @override
  Widget build(BuildContext context) {
    return HistoricalChatView(chatMessages: chatMessages);
  }
}
