import 'tool.dart';
import 'tool_factory.dart';

/// A lightweight [ToolFactory] backed by a closure.
class SimpleToolFactory implements ToolFactory {
  final Tool Function() _create;

  SimpleToolFactory({required Tool Function() create}) : _create = create;

  @override
  Tool createTool() => _create();
}
