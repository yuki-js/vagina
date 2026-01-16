import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';

/// Material/Cupertino共通化のためのアダプティブウィジェット
/// useCupertinoStyleProviderの値に応じてMaterialまたはCupertinoウィジェットを返す

/// アダプティブスイッチ
class AdaptiveSwitch extends ConsumerWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  final Color? activeColor;

  const AdaptiveSwitch({
    super.key,
    required this.value,
    this.onChanged,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final useCupertino = ref.watch(useCupertinoStyleProvider);

    if (useCupertino) {
      return CupertinoSwitch(
        value: value,
        onChanged: onChanged,
        activeTrackColor: activeColor ?? AppTheme.primaryColor,
      );
    }

    return Switch(
      value: value,
      onChanged: onChanged,
      activeColor: activeColor ?? AppTheme.primaryColor,
      activeTrackColor: activeColor ?? AppTheme.primaryColor,
    );
  }
}

/// アダプティブボタン（プライマリ）
class AdaptiveButton extends ConsumerWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final EdgeInsetsGeometry? padding;

  const AdaptiveButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.backgroundColor,
    this.foregroundColor,
    this.padding,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final useCupertino = ref.watch(useCupertinoStyleProvider);

    if (useCupertino) {
      return CupertinoButton.filled(
        onPressed: onPressed,
        padding:
            padding ?? const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: child,
      );
    }

    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor ?? AppTheme.primaryColor,
        foregroundColor: foregroundColor ?? Colors.white,
        padding:
            padding ?? const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: child,
    );
  }
}

/// アダプティブテキストボタン
class AdaptiveTextButton extends ConsumerWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final Color? foregroundColor;

  const AdaptiveTextButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.foregroundColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final useCupertino = ref.watch(useCupertinoStyleProvider);

    if (useCupertino) {
      return CupertinoButton(
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        child: DefaultTextStyle(
          style: TextStyle(color: foregroundColor ?? AppTheme.primaryColor),
          child: child,
        ),
      );
    }

    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: foregroundColor ?? AppTheme.primaryColor,
      ),
      child: child,
    );
  }
}

/// アダプティブアイコンボタン
class AdaptiveIconButton extends ConsumerWidget {
  final VoidCallback? onPressed;
  final Widget icon;
  final String? tooltip;
  final Color? color;

  const AdaptiveIconButton({
    super.key,
    required this.onPressed,
    required this.icon,
    this.tooltip,
    this.color,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final useCupertino = ref.watch(useCupertinoStyleProvider);

    if (useCupertino) {
      return CupertinoButton(
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        minimumSize: const Size.square(44),
        child: IconTheme(
          data: IconThemeData(color: color),
          child: icon,
        ),
      );
    }

    return IconButton(
      onPressed: onPressed,
      icon: icon,
      tooltip: tooltip,
      color: color,
    );
  }
}

/// アダプティブテキストフィールド
class AdaptiveTextField extends ConsumerWidget {
  final TextEditingController? controller;
  final String? placeholder;
  final String? labelText;
  final bool obscureText;
  final TextInputType? keyboardType;
  final int? maxLines;
  final Widget? suffix;
  final ValueChanged<String>? onChanged;

  const AdaptiveTextField({
    super.key,
    this.controller,
    this.placeholder,
    this.labelText,
    this.obscureText = false,
    this.keyboardType,
    this.maxLines = 1,
    this.suffix,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final useCupertino = ref.watch(useCupertinoStyleProvider);

    if (useCupertino) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (labelText != null) ...[
            Text(
              labelText!,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
          ],
          CupertinoTextField(
            controller: controller,
            placeholder: placeholder,
            obscureText: obscureText,
            keyboardType: keyboardType,
            maxLines: maxLines,
            suffix: suffix != null
                ? Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: suffix,
                  )
                : null,
            onChanged: onChanged,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: CupertinoColors.systemGrey6,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ],
      );
    }

    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      maxLines: maxLines,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: labelText,
        hintText: placeholder,
        suffixIcon: suffix,
      ),
    );
  }
}

/// アダプティブスライダー
class AdaptiveSlider extends ConsumerWidget {
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final ValueChanged<double>? onChanged;
  final Color? activeColor;

  const AdaptiveSlider({
    super.key,
    required this.value,
    this.min = 0.0,
    this.max = 1.0,
    this.divisions,
    this.onChanged,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final useCupertino = ref.watch(useCupertinoStyleProvider);

    if (useCupertino) {
      return CupertinoSlider(
        value: value,
        min: min,
        max: max,
        divisions: divisions,
        onChanged: onChanged,
        activeColor: activeColor ?? AppTheme.primaryColor,
      );
    }

    return Slider(
      value: value,
      min: min,
      max: max,
      divisions: divisions,
      onChanged: onChanged,
      activeColor: activeColor ?? AppTheme.primaryColor,
    );
  }
}

/// アダプティブアクションシート
class AdaptiveActionSheet {
  /// アクションシートを表示
  static Future<T?> show<T>({
    required BuildContext context,
    required WidgetRef ref,
    String? title,
    String? message,
    required List<AdaptiveAction<T>> actions,
    AdaptiveAction<T>? cancelAction,
  }) async {
    final useCupertino = ref.read(useCupertinoStyleProvider);

    if (useCupertino) {
      return showCupertinoModalPopup<T>(
        context: context,
        builder: (context) => CupertinoActionSheet(
          title: title != null ? Text(title) : null,
          message: message != null ? Text(message) : null,
          actions: actions
              .map((action) => CupertinoActionSheetAction(
                    onPressed: () => Navigator.of(context).pop(action.value),
                    isDestructiveAction: action.isDestructive,
                    child: Text(action.label),
                  ))
              .toList(),
          cancelButton: cancelAction != null
              ? CupertinoActionSheetAction(
                  onPressed: () =>
                      Navigator.of(context).pop(cancelAction.value),
                  child: Text(cancelAction.label),
                )
              : null,
        ),
      );
    }

    return showModalBottomSheet<T>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (title != null || message != null) ...[
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    if (title != null)
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    if (message != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        message,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Divider(height: 1),
            ],
            ...actions.map((action) => ListTile(
                  title: Text(
                    action.label,
                    style: TextStyle(
                      color: action.isDestructive ? Colors.red : null,
                    ),
                  ),
                  leading: action.icon != null
                      ? Icon(
                          action.icon,
                          color: action.isDestructive ? Colors.red : null,
                        )
                      : null,
                  onTap: () => Navigator.of(context).pop(action.value),
                )),
            if (cancelAction != null) ...[
              const Divider(height: 1),
              ListTile(
                title: Text(cancelAction.label),
                onTap: () => Navigator.of(context).pop(cancelAction.value),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// アクションシートのアクション
class AdaptiveAction<T> {
  final String label;
  final T value;
  final IconData? icon;
  final bool isDestructive;

  const AdaptiveAction({
    required this.label,
    required this.value,
    this.icon,
    this.isDestructive = false,
  });
}

/// アダプティブアラートダイアログ
class AdaptiveAlertDialog {
  /// アラートダイアログを表示
  static Future<bool?> show({
    required BuildContext context,
    required WidgetRef ref,
    required String title,
    String? content,
    String? confirmLabel,
    String? cancelLabel,
    bool isDestructive = false,
  }) async {
    final useCupertino = ref.read(useCupertinoStyleProvider);

    if (useCupertino) {
      return showCupertinoDialog<bool>(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: Text(title),
          content: content != null ? Text(content) : null,
          actions: [
            if (cancelLabel != null)
              CupertinoDialogAction(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(cancelLabel),
              ),
            CupertinoDialogAction(
              onPressed: () => Navigator.of(context).pop(true),
              isDestructiveAction: isDestructive,
              child: Text(confirmLabel ?? 'OK'),
            ),
          ],
        ),
      );
    }

    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: content != null ? Text(content) : null,
        actions: [
          if (cancelLabel != null)
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(cancelLabel),
            ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: isDestructive
                ? TextButton.styleFrom(foregroundColor: Colors.red)
                : null,
            child: Text(confirmLabel ?? 'OK'),
          ),
        ],
      ),
    );
  }
}

/// アダプティブプログレスインジケーター
class AdaptiveProgressIndicator extends ConsumerWidget {
  final double? value;
  final Color? color;

  const AdaptiveProgressIndicator({
    super.key,
    this.value,
    this.color,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final useCupertino = ref.watch(useCupertinoStyleProvider);

    if (useCupertino) {
      return CupertinoActivityIndicator(
        color: color,
      );
    }

    return CircularProgressIndicator(
      value: value,
      color: color ?? AppTheme.primaryColor,
    );
  }
}

/// アダプティブセグメントコントロール
class AdaptiveSegmentedControl<T extends Object> extends ConsumerWidget {
  final Map<T, Widget> children;
  final T groupValue;
  final ValueChanged<T> onValueChanged;

  const AdaptiveSegmentedControl({
    super.key,
    required this.children,
    required this.groupValue,
    required this.onValueChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final useCupertino = ref.watch(useCupertinoStyleProvider);

    if (useCupertino) {
      return CupertinoSegmentedControl<T>(
        children: children,
        groupValue: groupValue,
        onValueChanged: onValueChanged,
      );
    }

    // Material版はSegmentedButtonを使用
    return SegmentedButton<T>(
      segments: children.entries
          .map((entry) => ButtonSegment<T>(
                value: entry.key,
                label: entry.value,
              ))
          .toList(),
      selected: {groupValue},
      onSelectionChanged: (selected) {
        if (selected.isNotEmpty) {
          onValueChanged(selected.first);
        }
      },
    );
  }
}
