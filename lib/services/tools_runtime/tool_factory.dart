import 'tool.dart';

/// Factory that creates a new [Tool] instance.
abstract interface class ToolFactory {
  Tool createTool();
}

/// A lightweight [ToolFactory] backed by a closure.
///
/// Kept Flutter-free so it can be used in pure Dart runtime wiring.
class SimpleToolFactory implements ToolFactory {
  final Tool Function() _create;

  SimpleToolFactory({required Tool Function() create}) : _create = create;

  @override
  Tool createTool() => _create();
}
