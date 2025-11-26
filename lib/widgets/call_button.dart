import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// A stylish call button with pulse animation
class CallButton extends StatefulWidget {
  /// Whether the call is active
  final bool isCallActive;

  /// Called when the button is pressed
  final VoidCallback? onPressed;

  /// The size of the button
  final double size;

  const CallButton({
    super.key,
    this.isCallActive = false,
    this.onPressed,
    this.size = 80,
  });

  @override
  State<CallButton> createState() => _CallButtonState();
}

class _CallButtonState extends State<CallButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    if (widget.isCallActive) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(CallButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isCallActive && !oldWidget.isCallActive) {
      _pulseController.repeat(reverse: true);
    } else if (!widget.isCallActive && oldWidget.isCallActive) {
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final buttonColor =
        widget.isCallActive ? AppTheme.errorColor : AppTheme.successColor;

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: widget.isCallActive ? _pulseAnimation.value : 1.0,
          child: child,
        );
      },
      child: GestureDetector(
        onTap: widget.onPressed,
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: buttonColor,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: buttonColor.withOpacity(0.4),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Icon(
            widget.isCallActive ? Icons.call_end : Icons.call,
            color: Colors.white,
            size: widget.size * 0.4,
          ),
        ),
      ),
    );
  }
}
