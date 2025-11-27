/// Simple arithmetic expression evaluator
class ExpressionEvaluator {
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
    
    var value = double.parse(expr.substring(pos, end));
    if (negative) value = -value;
    
    return (value, end);
  }
}
