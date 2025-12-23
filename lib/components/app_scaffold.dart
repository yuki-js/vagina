import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'title_bar.dart' show CustomTitleBar;

/// App scaffold wrapper that provides consistent title bar across all screens
/// 
/// This widget follows the SafeArea pattern:
/// - Desktop (Windows/macOS/Linux): Custom title bar at the top
/// - Mobile (Android/iOS/Web): Standard AppBar within SafeArea
class AppScaffold extends ConsumerWidget {
  final Widget body;
  final String? title;
  final List<Widget>? actions;
  final Widget? leading;
  final bool showBackButton;
  final PreferredSizeWidget? bottom;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  
  const AppScaffold({
    super.key,
    required this.body,
    this.title,
    this.actions,
    this.leading,
    this.showBackButton = true,
    this.bottom,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDesktop = Platform.isWindows || Platform.isMacOS || Platform.isLinux;

    if (isDesktop) {
      // Desktop: Custom title bar with SafeArea pattern
      return Column(
        children: [
          // Custom title bar (replaces OS title bar)
          const CustomTitleBar(),
          // Main content below title bar
          Expanded(
            child: Scaffold(
              appBar: title != null
                  ? AppBar(
                      title: Text(title!),
                      leading: leading,
                      actions: actions,
                      bottom: bottom,
                      automaticallyImplyLeading: showBackButton,
                    )
                  : null,
              body: body,
              floatingActionButton: floatingActionButton,
              floatingActionButtonLocation: floatingActionButtonLocation,
            ),
          ),
        ],
      );
    } else {
      // Mobile/Web: Standard AppBar within SafeArea
      return Scaffold(
        appBar: AppBar(
          title: title != null ? Text(title!) : null,
          leading: leading,
          actions: actions,
          bottom: bottom,
          automaticallyImplyLeading: showBackButton,
        ),
        body: SafeArea(
          child: body,
        ),
        floatingActionButton: floatingActionButton,
        floatingActionButtonLocation: floatingActionButtonLocation,
      );
    }
  }
}
