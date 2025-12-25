import '../utils/platform_compat.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

/// Provider for always-on-top state
final alwaysOnTopProvider = NotifierProvider<AlwaysOnTopNotifier, bool>(AlwaysOnTopNotifier.new);

class AlwaysOnTopNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  Future<void> toggle() async {
    final newState = !state;
    await windowManager.setAlwaysOnTop(newState);
    state = newState;
  }

  Future<void> set(bool value) async {
    await windowManager.setAlwaysOnTop(value);
    state = value;
  }
}

/// Custom title bar for desktop platforms with immersive design
/// 
/// Provides:
/// - Minimize, maximize, close buttons
/// - Always-on-top toggle button
/// - Draggable window area
/// - Platform-specific layout (Windows vs macOS)
class CustomTitleBar extends ConsumerWidget {
  final String title;
  final Color? backgroundColor;
  
  const CustomTitleBar({
    super.key,
    this.title = 'VAGINA',
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Only show on desktop platforms
    if (!PlatformCompat.isWindows && !PlatformCompat.isMacOS && !PlatformCompat.isLinux) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final bgColor = backgroundColor ?? theme.scaffoldBackgroundColor;
    final isAlwaysOnTop = ref.watch(alwaysOnTopProvider);
    
    // macOS uses left-side buttons, Windows uses right-side
    final isMacOS = PlatformCompat.isMacOS;

    return Container(
      height: 32,
      color: bgColor,
      child: Row(
        children: [
          if (isMacOS) ...[
            // macOS buttons on the left
            _buildMacOSButtons(context, isAlwaysOnTop, ref),
            const SizedBox(width: 8),
            _buildTitle(context),
            Expanded(child: _buildDraggableArea()),
          ] else ...[
            // Windows/Linux layout
            const SizedBox(width: 8),
            _buildTitle(context),
            Expanded(child: _buildDraggableArea()),
            _buildWindowsButtons(context, isAlwaysOnTop, ref),
          ],
        ],
      ),
    );
  }

  Widget _buildTitle(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildDraggableArea() {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onPanStart: (_) => windowManager.startDragging(),
      onDoubleTap: () async {
        if (await windowManager.isMaximized()) {
          await windowManager.unmaximize();
        } else {
          await windowManager.maximize();
        }
      },
    );
  }

  Widget _buildMacOSButtons(BuildContext context, bool isAlwaysOnTop, WidgetRef ref) {
    return Row(
      children: [
        _TitleBarButton(
          icon: Icons.close,
          color: Colors.red.shade400,
          onPressed: () => windowManager.close(),
          size: 12,
        ),
        const SizedBox(width: 8),
        _TitleBarButton(
          icon: Icons.minimize,
          color: Colors.yellow.shade700,
          onPressed: () => windowManager.minimize(),
          size: 12,
        ),
        const SizedBox(width: 8),
        _TitleBarButton(
          icon: Icons.crop_square,
          color: Colors.green.shade400,
          onPressed: () async {
            if (await windowManager.isMaximized()) {
              await windowManager.unmaximize();
            } else {
              await windowManager.maximize();
            }
          },
          size: 12,
        ),
        const SizedBox(width: 8),
        _TitleBarButton(
          icon: Icons.push_pin,
          color: isAlwaysOnTop ? Colors.blue.shade400 : Colors.grey.shade600,
          onPressed: () => ref.read(alwaysOnTopProvider.notifier).toggle(),
          size: 12,
          isToggled: isAlwaysOnTop,
        ),
      ],
    );
  }

  Widget _buildWindowsButtons(BuildContext context, bool isAlwaysOnTop, WidgetRef ref) {
    return Row(
      children: [
        _TitleBarButton(
          icon: Icons.push_pin,
          color: isAlwaysOnTop ? Colors.blue.shade400 : Colors.grey.shade400,
          onPressed: () => ref.read(alwaysOnTopProvider.notifier).toggle(),
          size: 16,
          isToggled: isAlwaysOnTop,
          tooltip: isAlwaysOnTop ? '常に最前面を解除' : '常に最前面に表示',
        ),
        _TitleBarButton(
          icon: Icons.minimize,
          color: Colors.grey.shade400,
          hoverColor: Colors.grey.shade600,
          onPressed: () => windowManager.minimize(),
          size: 16,
          tooltip: '最小化',
        ),
        _TitleBarButton(
          icon: Icons.crop_square,
          color: Colors.grey.shade400,
          hoverColor: Colors.grey.shade600,
          onPressed: () async {
            if (await windowManager.isMaximized()) {
              await windowManager.unmaximize();
            } else {
              await windowManager.maximize();
            }
          },
          size: 16,
          tooltip: '最大化',
        ),
        _TitleBarButton(
          icon: Icons.close,
          color: Colors.grey.shade400,
          hoverColor: Colors.red.shade400,
          onPressed: () => windowManager.close(),
          size: 16,
          tooltip: '閉じる',
        ),
      ],
    );
  }
}

class _TitleBarButton extends StatefulWidget {
  final IconData icon;
  final Color color;
  final Color? hoverColor;
  final VoidCallback onPressed;
  final double size;
  final bool isToggled;
  final String? tooltip;

  const _TitleBarButton({
    required this.icon,
    required this.color,
    this.hoverColor,
    required this.onPressed,
    this.size = 12,
    this.isToggled = false,
    this.tooltip,
  });

  @override
  State<_TitleBarButton> createState() => _TitleBarButtonState();
}

class _TitleBarButtonState extends State<_TitleBarButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final button = MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: _isHovered
                ? (widget.hoverColor ?? widget.color).withValues(alpha: 0.2)
                : (widget.isToggled ? widget.color.withValues(alpha: 0.2) : Colors.transparent),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Icon(
            widget.icon,
            size: widget.size,
            color: _isHovered
                ? (widget.hoverColor ?? widget.color)
                : widget.color,
          ),
        ),
      ),
    );

    if (widget.tooltip != null) {
      return Tooltip(
        message: widget.tooltip!,
        waitDuration: const Duration(milliseconds: 500),
        child: button,
      );
    }

    return button;
  }
}
