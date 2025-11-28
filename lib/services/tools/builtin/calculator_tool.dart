import '../base_tool.dart';
import '../expression_evaluator.dart';

/// Tool for performing arithmetic calculations
class CalculatorTool extends BaseTool {
  final ExpressionEvaluator _evaluator = ExpressionEvaluator();
  
  @override
  String get name => 'calculator';
  
  @override
  String get description => 
      'Perform basic arithmetic calculations. Use this for mathematical operations.';
  
  @override
  Map<String, dynamic> get parameters => {
    'type': 'object',
    'properties': {
      'expression': {
        'type': 'string',
        'description': 'Mathematical expression to evaluate (e.g., "2 + 3 * 4", "100 / 5")',
      },
    },
    'required': ['expression'],
  };

  @override
  Future<Map<String, dynamic>> execute(Map<String, dynamic> arguments) async {
    final expression = arguments['expression'] as String;
    
    try {
      final result = _evaluator.evaluate(expression);
      return {
        'success': true,
        'expression': expression,
        'result': result,
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'Failed to evaluate expression: $e',
      };
    }
  }
}
