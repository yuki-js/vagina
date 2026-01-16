import 'package:flutter/material.dart';
import '../../../models/notepad_tab.dart';
import 'notepad_tab_item.dart';

/// Tab bar showing notepad tabs
class NotepadTabBar extends StatelessWidget {
  final List<NotepadTab> tabs;
  final String? selectedTabId;
  final void Function(String) onTabSelected;
  final void Function(String) onTabClosed;

  const NotepadTabBar({
    super.key,
    required this.tabs,
    required this.selectedTabId,
    required this.onTabSelected,
    required this.onTabClosed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: tabs.length,
        itemBuilder: (context, index) {
          final tab = tabs[index];
          final isSelected = tab.id == selectedTabId;

          return Padding(
            padding: const EdgeInsets.only(right: 4),
            child: NotepadTabItem(
              tab: tab,
              isSelected: isSelected,
              onTap: () => onTabSelected(tab.id),
              onClose: () => onTabClosed(tab.id),
            ),
          );
        },
      ),
    );
  }
}
