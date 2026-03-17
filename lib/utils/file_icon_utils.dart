import 'package:flutter/material.dart';
import 'package:vagina/tools/builtin/shared/file_type_support.dart';

/// Get the appropriate Flutter icon for a given file extension.
///
/// Directly maps file extensions to icons without intermediate MIME type conversion.
/// Distinguishes between custom VAGINA 2D formats (.v2d.*) and standard text formats.
IconData iconForExtension(String extension) {
  final lower = extension.toLowerCase();

  // Custom VAGINA 2D tabular formats only
  if (lower == '.v2d.csv' || lower == '.v2d.json' || lower == '.v2d.jsonl') {
    return Icons.table_chart;
  }

  // Standard readable document formats (all treated as text)
  switch (lower) {
    case '.md':
    case '.markdown':
      return Icons.article;
    case '.html':
    case '.htm':
      return Icons.code;
    case '.txt':
    case '.text':
    case '.csv':
    case '.json':
    case '.jsonl':
      return Icons.description;
    default:
      return Icons.description;
  }
}

/// Get the appropriate Flutter icon for a given file path.
IconData iconForPath(String path) {
  return iconForExtension(normalizedExtensionFromPath(path));
}

/// Get the appropriate color for a given file extension.
///
/// Returns a color that represents the file type visually.
Color colorForExtension(String extension) {
  final lower = extension.toLowerCase();

  // Custom VAGINA 2D tabular formats
  if (lower == '.v2d.csv' || lower == '.v2d.json' || lower == '.v2d.jsonl') {
    return Colors.green;
  }

  // Standard readable document formats
  switch (lower) {
    case '.md':
    case '.markdown':
      return Colors.blue;
    case '.html':
    case '.htm':
      return Colors.orange;
    case '.txt':
    case '.text':
      return Colors.grey;
    case '.csv':
      return Colors.teal;
    case '.json':
    case '.jsonl':
      return Colors.cyan;
    default:
      return Colors.blueGrey;
  }
}

/// Get the appropriate color for a given file path.
Color colorForPath(String path) {
  return colorForExtension(normalizedExtensionFromPath(path));
}
