import 'dart:convert';

/// Exception thrown when tabular data validation fails.
class TabularDataException implements Exception {
  final String message;
  const TabularDataException(this.message);

  @override
  String toString() => 'TabularDataException: $message';
}

/// Parsed tabular data with columns and rows.
///
/// All rows have exactly the same key set as [columns].
/// Values are primitives only (String, num, bool, or null).
class TabularData {
  /// Ordered column names.
  final List<String> columns;

  /// Row data. Each map has exactly the keys in [columns].
  final List<Map<String, dynamic>> rows;

  const TabularData({required this.columns, required this.rows});

  /// Parse [content] as the given file [extension] and return a [TabularData].
  ///
  /// [extension] must be one of:
  /// - `.v2d.csv`
  /// - `.v2d.json`
  /// - `.v2d.jsonl`
  ///
  /// Throws [TabularDataException] on any validation error.
  static TabularData parse(String content, String extension) {
    final lower = extension.toLowerCase();
    switch (lower) {
      case '.v2d.csv':
        return _parseCsv(content);
      case '.v2d.json':
        return _parseJson2d(content);
      case '.v2d.jsonl':
        return _parseJsonl2d(content);
      default:
        throw TabularDataException('Unsupported extension: $extension');
    }
  }

  /// Validate [content] for the given file [extension].
  ///
  /// Throws [TabularDataException] on any validation error.
  /// Returns normally if valid.
  static void validate(String content, String extension) {
    parse(content, extension);
  }

  /// Serialize this [TabularData] back to a string in the given file [extension].
  ///
  /// [extension] must be one of:
  /// - `.v2d.csv`
  /// - `.v2d.json`
  /// - `.v2d.jsonl`
  String serialize(String extension) {
    final lower = extension.toLowerCase();
    switch (lower) {
      case '.v2d.csv':
        return _serializeCsv();
      case '.v2d.json':
        return _serializeJson2d();
      case '.v2d.jsonl':
        return _serializeJsonl2d();
      default:
        throw TabularDataException('Unsupported extension: $extension');
    }
  }

  /// Return a new [TabularData] with [newRows] appended.
  ///
  /// Validates that all new rows have exactly the same keys as [columns].
  TabularData addRows(List<Map<String, dynamic>> newRows) {
    for (var i = 0; i < newRows.length; i++) {
      _validateRowKeys(newRows[i], columns, 'new row $i');
      _validateRowValues(newRows[i], 'new row $i');
    }
    return TabularData(
      columns: columns,
      rows: [...rows, ...newRows],
    );
  }

  /// Return a new [TabularData] with rows updated based on a lookup condition.
  ///
  /// Each update specifies a `where` condition (column name and value to match)
  /// and a `set` map of column-value pairs to update.
  ///
  /// Example:
  /// ```dart
  /// data.updateRows([
  ///   {
  ///     'where': {'column': 'name', 'value': 'Alice'},
  ///     'set': {'age': 31, 'city': 'Tokyo'},
  ///   }
  /// ]);
  /// ```
  ///
  /// By default, updates the first matching row. Set `updateAll: true` in the
  /// update map to update all matching rows.
  TabularData updateRows(List<Map<String, dynamic>> updates) {
    final newRows = rows.map((r) => Map<String, dynamic>.from(r)).toList();

    for (final update in updates) {
      final where = update['where'] as Map<String, dynamic>?;
      if (where == null) {
        throw const TabularDataException(
          'Missing "where" condition in update',
        );
      }

      final lookupColumn = where['column'] as String?;
      final lookupValue = where['value'];
      if (lookupColumn == null) {
        throw const TabularDataException(
          'Missing "column" in where condition',
        );
      }

      if (!columns.contains(lookupColumn)) {
        throw TabularDataException(
          'Lookup column "$lookupColumn" not found. Available: $columns',
        );
      }

      final setValues = update['set'] as Map<String, dynamic>?;
      if (setValues == null || setValues.isEmpty) {
        throw const TabularDataException(
          'Missing or empty "set" values in update',
        );
      }

      // Validate set columns exist
      for (final col in setValues.keys) {
        if (!columns.contains(col)) {
          throw TabularDataException(
            'Column "$col" in set not found. Available: $columns',
          );
        }
      }

      // Validate set values are primitives
      for (final entry in setValues.entries) {
        _validatePrimitiveValue(entry.value, 'set["${entry.key}"]');
      }

      final updateAll = update['updateAll'] == true;
      var matchCount = 0;

      for (var i = 0; i < newRows.length; i++) {
        if (newRows[i][lookupColumn] == lookupValue) {
          // Found matching row
          for (final entry in setValues.entries) {
            newRows[i][entry.key] = entry.value;
          }
          matchCount++;

          if (!updateAll) {
            break; // Only update first match
          }
        }
      }

      if (matchCount == 0) {
        throw TabularDataException(
          'No row found where "$lookupColumn" = $lookupValue',
        );
      }
    }

    return TabularData(columns: columns, rows: newRows);
  }

  /// Return a new [TabularData] with the specified rows removed.
  ///
  /// [indices] are 0-based row indices. Duplicate indices are ignored.
  TabularData deleteRows(List<int> indices) {
    final toRemove = indices.toSet();
    for (final idx in toRemove) {
      if (idx < 0 || idx >= rows.length) {
        throw TabularDataException(
          'Row index $idx out of range (0..${rows.length - 1})',
        );
      }
    }
    final newRows = <Map<String, dynamic>>[];
    for (var i = 0; i < rows.length; i++) {
      if (!toRemove.contains(i)) {
        newRows.add(rows[i]);
      }
    }
    return TabularData(columns: columns, rows: newRows);
  }

  // ---------------------------------------------------------------------------
  // CSV Parsing (RFC 4180 compliant)
  // ---------------------------------------------------------------------------

  static TabularData _parseCsv(String content) {
    final records = _parseCsvRecords(content);

    if (records.isEmpty) {
      // Empty content → empty table
      return const TabularData(columns: [], rows: []);
    }

    final columns = records.first;
    if (columns.isEmpty) {
      throw const TabularDataException(
          'CSV header row must have at least one column');
    }

    // Check for duplicate column names
    final seen = <String>{};
    for (final col in columns) {
      if (!seen.add(col)) {
        throw TabularDataException(
            'Duplicate column name in CSV header: "$col"');
      }
    }

    final rows = <Map<String, dynamic>>[];
    for (var i = 1; i < records.length; i++) {
      final record = records[i];
      if (record.length != columns.length) {
        throw TabularDataException(
          'CSV row ${i + 1} has ${record.length} fields, expected ${columns.length}',
        );
      }
      final row = <String, dynamic>{};
      for (var j = 0; j < columns.length; j++) {
        row[columns[j]] = record[j];
      }
      rows.add(row);
    }

    return TabularData(columns: columns, rows: rows);
  }

  /// RFC 4180 CSV parser. Returns a list of records (each record is a list of fields).
  static List<List<String>> _parseCsvRecords(String content) {
    if (content.trim().isEmpty) return [];

    final records = <List<String>>[];
    var fields = <String>[];
    final buf = StringBuffer();
    var inQuotes = false;
    var i = 0;

    while (i < content.length) {
      final c = content[i];

      if (inQuotes) {
        if (c == '"') {
          // Check for escaped quote
          if (i + 1 < content.length && content[i + 1] == '"') {
            buf.write('"');
            i += 2;
          } else {
            inQuotes = false;
            i++;
          }
        } else {
          buf.write(c);
          i++;
        }
      } else {
        if (c == '"') {
          inQuotes = true;
          i++;
        } else if (c == ',') {
          fields.add(buf.toString());
          buf.clear();
          i++;
        } else if (c == '\r') {
          // Handle \r\n or bare \r
          fields.add(buf.toString());
          buf.clear();
          records.add(fields);
          fields = <String>[];
          i++;
          if (i < content.length && content[i] == '\n') {
            i++;
          }
        } else if (c == '\n') {
          fields.add(buf.toString());
          buf.clear();
          records.add(fields);
          fields = <String>[];
          i++;
        } else {
          buf.write(c);
          i++;
        }
      }
    }

    // Handle last field/record
    if (buf.isNotEmpty || fields.isNotEmpty) {
      fields.add(buf.toString());
      records.add(fields);
    }

    // Remove trailing empty record (e.g., trailing newline)
    if (records.isNotEmpty &&
        records.last.length == 1 &&
        records.last[0].isEmpty) {
      // Only remove if it was caused by a trailing newline, not a real single-field row
      // Check: if header has more than 1 column and last row is just [''], remove it
      if (records.length > 1 && records.first.length > 1) {
        records.removeLast();
      }
    }

    return records;
  }

  // ---------------------------------------------------------------------------
  // JSON 2D Parsing
  // ---------------------------------------------------------------------------

  static TabularData _parseJson2d(String content) {
    final trimmed = content.trim();

    dynamic decoded;
    try {
      decoded = jsonDecode(trimmed);
    } catch (e) {
      throw TabularDataException('Invalid JSON: $e');
    }

    if (decoded is! List) {
      throw const TabularDataException(
        'application/vagina-2d+json must be a JSON array at top level',
      );
    }

    if (decoded.isEmpty) {
      return const TabularData(columns: [], rows: []);
    }

    // Determine columns from first element
    if (decoded[0] is! Map) {
      throw const TabularDataException(
        'Each element in the array must be a JSON object',
      );
    }
    final firstObj = Map<String, dynamic>.from(decoded[0] as Map);
    final columns = firstObj.keys.toList();

    if (columns.isEmpty) {
      throw const TabularDataException(
        'JSON objects must have at least one key',
      );
    }

    final expectedKeys = columns.toSet();

    final rows = <Map<String, dynamic>>[];
    for (var i = 0; i < decoded.length; i++) {
      final element = decoded[i];
      if (element is! Map) {
        throw TabularDataException(
          'Element at index $i is not a JSON object',
        );
      }
      final obj = Map<String, dynamic>.from(element);
      _validateRowKeys(obj, columns, 'element at index $i', expectedKeys);
      _validateRowValues(obj, 'element at index $i');
      rows.add(obj);
    }

    return TabularData(columns: columns, rows: rows);
  }

  // ---------------------------------------------------------------------------
  // JSONL 2D Parsing
  // ---------------------------------------------------------------------------

  static TabularData _parseJsonl2d(String content) {
    final lines =
        content.split('\n').where((l) => l.trim().isNotEmpty).toList();

    if (lines.isEmpty) {
      return const TabularData(columns: [], rows: []);
    }

    // Parse first line to determine columns
    dynamic firstDecoded;
    try {
      firstDecoded = jsonDecode(lines[0]);
    } catch (e) {
      throw TabularDataException('Invalid JSON on line 1: $e');
    }

    if (firstDecoded is! Map) {
      throw const TabularDataException(
        'Each line in JSONL must be a JSON object',
      );
    }

    final firstObj = Map<String, dynamic>.from(firstDecoded);
    final columns = firstObj.keys.toList();

    if (columns.isEmpty) {
      throw const TabularDataException(
        'JSON objects must have at least one key',
      );
    }

    final expectedKeys = columns.toSet();

    final rows = <Map<String, dynamic>>[];
    _validateRowValues(firstObj, 'line 1');
    rows.add(firstObj);

    for (var i = 1; i < lines.length; i++) {
      dynamic decoded;
      try {
        decoded = jsonDecode(lines[i]);
      } catch (e) {
        throw TabularDataException('Invalid JSON on line ${i + 1}: $e');
      }

      if (decoded is! Map) {
        throw TabularDataException(
          'Line ${i + 1} is not a JSON object',
        );
      }

      final obj = Map<String, dynamic>.from(decoded);
      _validateRowKeys(obj, columns, 'line ${i + 1}', expectedKeys);
      _validateRowValues(obj, 'line ${i + 1}');
      rows.add(obj);
    }

    return TabularData(columns: columns, rows: rows);
  }

  // ---------------------------------------------------------------------------
  // Validation Helpers
  // ---------------------------------------------------------------------------

  static void _validateRowKeys(
    Map<String, dynamic> row,
    List<String> columns,
    String location, [
    Set<String>? expectedKeys,
  ]) {
    final expected = expectedKeys ?? columns.toSet();
    final actual = row.keys.toSet();

    if (actual.length != expected.length || !actual.containsAll(expected)) {
      final missing = expected.difference(actual);
      final extra = actual.difference(expected);
      final parts = <String>[];
      if (missing.isNotEmpty) parts.add('missing: $missing');
      if (extra.isNotEmpty) parts.add('extra: $extra');
      throw TabularDataException(
        'Key mismatch at $location. ${parts.join(', ')}',
      );
    }
  }

  static void _validateRowValues(Map<String, dynamic> row, String location) {
    for (final entry in row.entries) {
      _validatePrimitiveValue(entry.value, '$location, key "${entry.key}"');
    }
  }

  static void _validatePrimitiveValue(dynamic value, String location) {
    if (value == null || value is String || value is num || value is bool) {
      return;
    }
    throw TabularDataException(
      'Non-primitive value at $location: ${value.runtimeType}. '
      'Only String, num, bool, and null are allowed.',
    );
  }

  // ---------------------------------------------------------------------------
  // Serialization
  // ---------------------------------------------------------------------------

  String _serializeCsv() {
    final buf = StringBuffer();

    // Header
    buf.writeln(_csvEncodeRow(columns));

    // Data rows
    for (final row in rows) {
      final values = columns.map((col) => row[col]?.toString() ?? '').toList();
      buf.writeln(_csvEncodeRow(values));
    }

    return buf.toString().trimRight();
  }

  static String _csvEncodeRow(List<String> fields) {
    return fields.map(_csvEncodeField).join(',');
  }

  static String _csvEncodeField(String field) {
    if (field.contains(',') ||
        field.contains('"') ||
        field.contains('\n') ||
        field.contains('\r')) {
      return '"${field.replaceAll('"', '""')}"';
    }
    return field;
  }

  String _serializeJson2d() {
    final list = rows.map((row) {
      final ordered = <String, dynamic>{};
      for (final col in columns) {
        ordered[col] = row[col];
      }
      return ordered;
    }).toList();
    return const JsonEncoder.withIndent('  ').convert(list);
  }

  String _serializeJsonl2d() {
    final lines = rows.map((row) {
      final ordered = <String, dynamic>{};
      for (final col in columns) {
        ordered[col] = row[col];
      }
      return jsonEncode(ordered);
    });
    return lines.join('\n');
  }
}
