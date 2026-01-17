import 'package:vagina/services/tools/base_tool.dart';
import 'package:vagina/services/tools/tool_metadata.dart';

/// 計算機ツール
class CalculatorTool extends BaseTool {
  final _ExpressionEvaluator _evaluator = _ExpressionEvaluator();

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
            'description':
                'Mathematical expression to evaluate (e.g., "2 + 3 * 4", "100 / 5")',
          },
        },
        'required': ['expression'],
      };

  @override
  ToolMetadata get metadata => const ToolMetadata(
        name: 'calculator',
        displayName: '計算機',
        displayDescription: '数式を計算します',
        description:
            'Perform basic arithmetic calculations. Use this for mathematical operations.',
        iconKey: 'calculate',
        category: ToolCategory.calculation,
      );

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

/// Simple arithmetic expression evaluator
/// Private to this file - only used by CalculatorTool
class _ExpressionEvaluator {
  /// Evaluate a mathematical expression
  double evaluate(String expression) {
    expression = expression.replaceAll(' ', '');
    return _parseAddSub(expression, 0).$1;
  }

  (double, int) _parseAddSub(String expr, int pos) {
    var (left, newPos) = _parseMulDiv(expr, pos);
    
    while (newPos < expr.length) {
      final op = expr[newPos];
      if (op != '+' && op != '-') break;
      
      final (right, nextPos) = _parseMulDiv(expr, newPos + 1);
      left = op == '+' ? left + right : left - right;
      newPos = nextPos;
    }
    
    return (left, newPos);
  }

  (double, int) _parseMulDiv(String expr, int pos) {
    var (left, newPos) = _parseNumber(expr, pos);
    
    while (newPos < expr.length) {
      final op = expr[newPos];
      if (op != '*' && op != '/') break;
      
      final (right, nextPos) = _parseNumber(expr, newPos + 1);
      left = op == '*' ? left * right : left / right;
      newPos = nextPos;
    }
    
    return (left, newPos);
  }

  (double, int) _parseNumber(String expr, int pos) {
    // Handle parentheses
    if (pos < expr.length && expr[pos] == '(') {
      final (value, endPos) = _parseAddSub(expr, pos + 1);
      return (value, endPos + 1);
    }
    
    // Handle negative numbers
    var negative = false;
    if (pos < expr.length && expr[pos] == '-') {
      negative = true;
      pos++;
    }
    
    // Parse number
    var end = pos;
    while (end < expr.length && '0123456789.'.contains(expr[end])) {
      end++;
    }
    
    if (end == pos) {
      throw FormatException('Expected number at position $pos');
    }
    
    final numberStr = expr.substring(pos, end);
    final value = double.tryParse(numberStr);
    if (value == null) {
      throw FormatException('Invalid number format: $numberStr');
    }
    
    return (negative ? -value : value, end);
  }
}
