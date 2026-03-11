import 'package:flutter_test/flutter_test.dart';
import 'package:vagina/tools/builtin/document/document_overwrite_tool.dart';
import 'package:vagina/tools/builtin/document/document_patch_tool.dart';
import 'package:vagina/tools/builtin/document/document_read_tool.dart';
import 'package:vagina/tools/builtin/shared/file_type_support.dart';
import 'package:vagina/tools/builtin/spreadsheet/spreadsheet_add_rows_tool.dart';
import 'package:vagina/tools/builtin/spreadsheet/spreadsheet_delete_rows_tool.dart';
import 'package:vagina/tools/builtin/spreadsheet/spreadsheet_update_rows_tool.dart';

void main() {
  group('Tool activation metadata', () {
    test('document_read supports both text and spreadsheet extensions', () {
      final activation = DocumentReadTool().definition.activation;
      expect(activation.alwaysAvailable, isFalse);
      expect(
        activation.extensions.toSet(),
        kReadableDocumentExtensions.toSet(),
      );
    });

    test('document_overwrite and document_patch are text-only', () {
      final overwrite = DocumentOverwriteTool().definition.activation;
      final patch = DocumentPatchTool().definition.activation;

      expect(overwrite.extensions.toSet(), kTextDocumentExtensions.toSet());
      expect(patch.extensions.toSet(), kTextDocumentExtensions.toSet());
    });

    test('spreadsheet tools are tabular-only', () {
      final expected = kTabularDocumentExtensions.toSet();
      expect(
        SpreadsheetAddRowsTool().definition.activation.extensions.toSet(),
        expected,
      );
      expect(
        SpreadsheetUpdateRowsTool().definition.activation.extensions.toSet(),
        expected,
      );
      expect(
        SpreadsheetDeleteRowsTool().definition.activation.extensions.toSet(),
        expected,
      );
    });
  });
}
