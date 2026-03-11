import 'package:vagina/models/virtual_file.dart';
import 'package:vagina/services/tools_runtime/tool_definition.dart';

const List<String> kTextDocumentExtensions = <String>[
  '.txt',
  '.md',
  '.html',
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

const Map<String, String> _kTabularMimeTypeByExtension = <String, String>{
  '.v2d.csv': 'text/csv',
  '.v2d.json': 'application/vagina-2d+json',
  '.v2d.jsonl': 'application/vagina-2d+jsonl',
};

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

String? tabularMimeTypeFromPath(String path) {
  return _kTabularMimeTypeByExtension[normalizedExtensionFromPath(path)];
}

bool isTabularPath(String path) {
  return tabularMimeTypeFromPath(path) != null;
}
