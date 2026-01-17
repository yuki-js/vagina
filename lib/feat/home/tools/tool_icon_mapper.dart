import 'package:flutter/material.dart';
import 'package:vagina/services/tools/tool_metadata.dart';

/// Flutter-only icon resolver for tool metadata keys.
///
/// Tools declare icon keys as stable strings to avoid Flutter dependency.
/// UI resolves keys into [IconData] here.
class ToolIconMapper {
  static const String fallbackIconKey = 'help_outline';

  static const Map<String, IconData> _iconByKey = {
    // Tool icon keys
    'access_time': Icons.access_time,
    'calculate': Icons.calculate,
    'save': Icons.save,
    'search': Icons.search,
    'delete': Icons.delete,
    'visibility': Icons.visibility,
    'edit_document': Icons.edit_document,
    'edit': Icons.edit,
    'article': Icons.article,
    'info': Icons.info,
    'close': Icons.close,
    'list': Icons.list,

    // Category icon keys
    'settings': Icons.settings,
    'memory': Icons.memory,
    'description': Icons.description,
    'note': Icons.note,
    'cloud': Icons.cloud,
    'extension': Icons.extension,

    // Fallback
    fallbackIconKey: Icons.help_outline,
  };

  static IconData iconForKey(String? iconKey) {
    return _iconByKey[iconKey] ?? _iconByKey[fallbackIconKey]!;
  }

  static IconData iconForCategory(ToolCategory category) {
    return iconForKey(category.iconKey);
  }

  static IconData iconForMetadata(ToolMetadata metadata) {
    return iconForKey(metadata.iconKey);
  }
}
