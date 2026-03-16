import 'package:vagina/models/virtual_file.dart';
import 'package:vagina/services/tools_runtime/tool_definition.dart';

const List<String> kTextDocumentExtensions = <String>[
  '.txt',
  '.md',
  '.html',
  '.v2d.csv', // can also r/w as text
  '.v2d.json', // can also r/w as text
  '.v2d.jsonl',
];

const List<String> kTabularDocumentExtensions = <String>[
  '.v2d.csv',
  '.v2d.json',
  '.v2d.jsonl',
];

const List<String> kReadableDocumentExtensions = <String>[
  '.txt',
  '.md',
  '.html',
  '.v2d.csv',
  '.v2d.json',
  '.v2d.jsonl',
];

String normalizedExtensionFromPath(String path) {
  return VirtualFile(path: path, content: '').extension.toLowerCase();
}

bool isPathSupportedByActivation(
  String path,
  ToolActivation activation,
) {
  return activation.isEnabledForExtensions({
    normalizedExtensionFromPath(path),
  });
}

bool isTabularExtension(String extension) {
  return kTabularDocumentExtensions.contains(extension.toLowerCase());
}

bool isTabularPath(String path) {
  return isTabularExtension(normalizedExtensionFromPath(path));
}
