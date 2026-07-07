import 'package:vagina/models/file_type_support.dart';
import 'package:vagina/services/tools_runtime/tool_definition.dart';

bool isPathSupportedByActivation(String path, ToolActivation activation) {
  return activation.isEnabledForExtensions({normalizedExtensionFromPath(path)});
}
