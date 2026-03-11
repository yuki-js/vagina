import 'package:flutter/material.dart';

import 'package:vagina/feat/call/widgets/open_files_tab_item.dart';
import 'package:vagina/models/open_file_tab.dart';

/// Tab bar showing currently open files.
class OpenFilesTabBar extends StatelessWidget {
  final List<OpenFileTab> tabs;
  final String? selectedTabId;
  final void Function(String) onTabSelected;
  final void Function(String) onTabClosed;

  const OpenFilesTabBar({
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
            child: OpenFilesTabItem(
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
