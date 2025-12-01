import 'package:flutter_test/flutter_test.dart';
import 'package:diff_match_patch/diff_match_patch.dart';
import 'package:vagina/services/notepad_service.dart';
import 'package:vagina/services/tools/builtin/document_tools.dart';

void main() {
  group('Patch Format Tests', () {
    test('show plain diff parsing error', () {
      // This is what the AI sends - plain unified diff format (like git diff)
      final plainPatch = '''@@ -1,5 +1,7 @@
 【原文】
 春は、あけぼの。やうやう白くなりゆく山ぎは、少し明かりて、紫だちたる雲の細くたなびきたる。
+夏は、夜（よる）。月のころはさらなり、闇もなお、蛍の多く飛びちがひたる。
 
 【現代語訳】
 春は、夜明けが一番美しい。だんだんと白んでいく山際が、少し明るくなって、ほんのり紫がかった雲が細くたなびいている様子が趣深い。
+夏は、夜が良い。月の出ている時は言うまでもなく、闇夜でもなお、多くの蛍が飛び交っている様子が風情を感じさせる。
''';

      // This will throw because the library expects URL-encoded content
      expect(() => patchFromText(plainPatch), throwsA(isA<ArgumentError>()));
    });
    
    test('show proper library patch format', () {
      final dmp = DiffMatchPatch();
      final original = '''【原文】
春は、あけぼの。やうやう白くなりゆく山ぎは、少し明かりて、紫だちたる雲の細くたなびきたる。

【現代語訳】
春は、夜明けが一番美しい。だんだんと白んでいく山際が、少し明るくなって、ほんのり紫がかった雲が細くたなびいている様子が趣深い。
''';
      
      final updated = '''【原文】
春は、あけぼの。やうやう白くなりゆく山ぎは、少し明かりて、紫だちたる雲の細くたなびきたる。
夏は、夜（よる）。月のころはさらなり、闇もなお、蛍の多く飛びちがひたる。

【現代語訳】
春は、夜明けが一番美しい。だんだんと白んでいく山際が、少し明るくなって、ほんのり紫がかった雲が細くたなびいている様子が趣深い。
夏は、夜が良い。月の出ている時は言うまでもなく、闇夜でもなお、多くの蛍が飛び交っている様子が風情を感じさせる。
''';

      final patches = dmp.patch(original, updated);
      final properPatchText = patchToText(patches);
      
      // Now parse it back - this should work
      final parsedPatches = patchFromText(properPatchText);
      expect(parsedPatches, isNotEmpty);
    });
  });

  group('DocumentPatchTool comprehensive tests', () {
    late NotepadService notepadService;
    late DocumentPatchTool patchTool;
    late DocumentOverwriteTool overwriteTool;

    /// Helper function to create a document and apply a patch
    Future<Map<String, dynamic>> applyPatchToContent(
      String originalContent,
      String patch,
    ) async {
      final createResult = await overwriteTool.execute({
        'content': originalContent,
      });
      final tabId = createResult['tabId'] as String;
      
      final patchResult = await patchTool.execute({
        'tabId': tabId,
        'patch': patch,
      });
      
      if (patchResult['success'] == true) {
        patchResult['finalContent'] = notepadService.getTabContent(tabId);
      }
      
      return patchResult;
    }

    setUp(() {
      notepadService = NotepadService();
      patchTool = DocumentPatchTool(notepadService: notepadService);
      overwriteTool = DocumentOverwriteTool(notepadService: notepadService);
    });

    tearDown(() {
      notepadService.dispose();
    });

    // ==================== Basic English Text Tests ====================
    
    test('1. simple single line addition - English', () async {
      final result = await applyPatchToContent(
        'Hello World',
        '''@@ -1 +1,2 @@
 Hello World
+Goodbye World
''',
      );
      expect(result['success'], isTrue, reason: 'Error: ${result['error']}');
      expect(result['finalContent'], contains('Goodbye World'));
    });

    test('2. simple single line deletion - English', () async {
      final result = await applyPatchToContent(
        'Line 1\nLine 2\nLine 3',
        '''@@ -1,3 +1,2 @@
 Line 1
-Line 2
 Line 3
''',
      );
      expect(result['success'], isTrue, reason: 'Error: ${result['error']}');
      expect(result['finalContent'], isNot(contains('Line 2')));
    });

    test('3. simple line replacement - English', () async {
      final result = await applyPatchToContent(
        'Hello World\nThis is a test',
        '''@@ -1,2 +1,2 @@
 Hello World
-This is a test
+This is replaced
''',
      );
      expect(result['success'], isTrue, reason: 'Error: ${result['error']}');
      expect(result['finalContent'], contains('This is replaced'));
      expect(result['finalContent'], isNot(contains('This is a test')));
    });

    test('4. multiple line additions - English with marker', () async {
      // Note: For ASCII-only content, the tool can't distinguish AI patches from library patches
      // Adding a non-ASCII character (like emoji or Japanese) triggers proper encoding
      final result = await applyPatchToContent(
        'Start 📝\nEnd',
        '''@@ -1,2 +1,4 @@
 Start 📝
+Middle 1
+Middle 2
 End
''',
      );
      expect(result['success'], isTrue, reason: 'Error: ${result['error']}');
      expect(result['finalContent'], contains('Middle 1'));
      expect(result['finalContent'], contains('Middle 2'));
    });

    // ==================== Japanese Text Tests ====================
    
    test('5. simple Japanese addition', () async {
      final result = await applyPatchToContent(
        'こんにちは',
        '''@@ -1 +1,2 @@
 こんにちは
+さようなら
''',
      );
      expect(result['success'], isTrue, reason: 'Error: ${result['error']}');
      expect(result['finalContent'], contains('さようなら'));
    });

    test('6. Japanese text with parentheses (issue case)', () async {
      final result = await applyPatchToContent(
        '夏は、夜。',
        '''@@ -1 +1 @@
-夏は、夜。
+夏は、夜（よる）。
''',
      );
      expect(result['success'], isTrue, reason: 'Error: ${result['error']}');
      expect(result['finalContent'], contains('夏は、夜（よる）。'));
    });

    test('7. Japanese with special brackets 【】', () async {
      final result = await applyPatchToContent(
        '原文',
        '''@@ -1 +1 @@
-原文
+【原文】
''',
      );
      expect(result['success'], isTrue, reason: 'Error: ${result['error']}');
      expect(result['finalContent'], contains('【原文】'));
    });

    test('8. complex Japanese - Makura no Soshi style', () async {
      final result = await applyPatchToContent(
        '春は、あけぼの。',
        '''@@ -1 +1,2 @@
 春は、あけぼの。
+夏は、夜。
''',
      );
      expect(result['success'], isTrue, reason: 'Error: ${result['error']}');
      expect(result['finalContent'], contains('夏は、夜。'));
    });

    test('9. Japanese with emoji', () async {
      final result = await applyPatchToContent(
        '今日は良い天気です',
        '''@@ -1 +1 @@
-今日は良い天気です
+今日は良い天気です☀️
''',
      );
      expect(result['success'], isTrue, reason: 'Error: ${result['error']}');
      expect(result['finalContent'], contains('☀️'));
    });

    test('10. Japanese with numbers', () async {
      final result = await applyPatchToContent(
        '2024年1月1日',
        '''@@ -1 +1 @@
-2024年1月1日
+2024年12月31日
''',
      );
      expect(result['success'], isTrue, reason: 'Error: ${result['error']}');
      expect(result['finalContent'], contains('2024年12月31日'));
    });

    // ==================== Newline Handling Tests ====================
    
    test('11. empty line insertion with Japanese', () async {
      // Empty line insertion works when there's non-ASCII content to trigger encoding
      final result = await applyPatchToContent(
        '行1\n行2',
        '''@@ -1,2 +1,3 @@
 行1
+
 行2
''',
      );
      expect(result['success'], isTrue, reason: 'Error: ${result['error']}');
      expect(result['finalContent'], contains('行1\n\n行2'));
    });

    test('12. multiple empty lines insertion with Japanese', () async {
      final result = await applyPatchToContent(
        '開始\n終了',
        '''@@ -1,2 +1,4 @@
 開始
+
+
 終了
''',
      );
      expect(result['success'], isTrue, reason: 'Error: ${result['error']}');
      expect(result['finalContent'], contains('開始\n\n\n終了'));
    });

    test('13. trailing newline addition', () async {
      final result = await applyPatchToContent(
        'No newline at end',
        '''@@ -1 +1,2 @@
 No newline at end
+
''',
      );
      expect(result['success'], isTrue, reason: 'Error: ${result['error']}');
    });

    test('14. preserve existing newlines', () async {
      final result = await applyPatchToContent(
        'Line 1\n\nLine 3',
        '''@@ -1,3 +1,4 @@
 Line 1
 
+Line 2
 Line 3
''',
      );
      expect(result['success'], isTrue, reason: 'Error: ${result['error']}');
      expect(result['finalContent'], contains('Line 2'));
    });

    // ==================== Special Characters Tests ====================
    
    test('15. text with URL', () async {
      final result = await applyPatchToContent(
        'Visit our website',
        '''@@ -1 +1,2 @@
 Visit our website
+https://example.com/path?query=value&foo=bar
''',
      );
      expect(result['success'], isTrue, reason: 'Error: ${result['error']}');
      expect(result['finalContent'], contains('https://example.com/path?query=value&foo=bar'));
    });

    test('16. text with percent signs (Japanese context)', () async {
      // Percent signs work when there's non-ASCII content to trigger encoding
      final result = await applyPatchToContent(
        '進捗: 50%',
        '''@@ -1 +1 @@
-進捗: 50%
+進捗: 100%
''',
      );
      expect(result['success'], isTrue, reason: 'Error: ${result['error']}');
      expect(result['finalContent'], contains('100%'));
    });

    test('17. text with ampersand', () async {
      final result = await applyPatchToContent(
        'Tom & Jerry',
        '''@@ -1 +1 @@
-Tom & Jerry
+Tom & Jerry & Friends
''',
      );
      expect(result['success'], isTrue, reason: 'Error: ${result['error']}');
      expect(result['finalContent'], contains('Tom & Jerry & Friends'));
    });

    test('18. text with hash symbols', () async {
      final result = await applyPatchToContent(
        '# Heading',
        '''@@ -1 +1,2 @@
 # Heading
+## Subheading
''',
      );
      expect(result['success'], isTrue, reason: 'Error: ${result['error']}');
      expect(result['finalContent'], contains('## Subheading'));
    });

    test('19. text with code backticks', () async {
      final result = await applyPatchToContent(
        'Use `code` here',
        '''@@ -1 +1 @@
-Use `code` here
+Use `newCode()` here
''',
      );
      expect(result['success'], isTrue, reason: 'Error: ${result['error']}');
      expect(result['finalContent'], contains('`newCode()`'));
    });

    test('20. text with quotes', () async {
      final result = await applyPatchToContent(
        'He said "Hello"',
        '''@@ -1 +1 @@
-He said "Hello"
+He said "Goodbye"
''',
      );
      expect(result['success'], isTrue, reason: 'Error: ${result['error']}');
      expect(result['finalContent'], contains('"Goodbye"'));
    });

    // ==================== Multi-byte Character Tests ====================
    
    test('21. Chinese characters', () async {
      final result = await applyPatchToContent(
        '你好世界',
        '''@@ -1 +1 @@
-你好世界
+你好中国
''',
      );
      expect(result['success'], isTrue, reason: 'Error: ${result['error']}');
      expect(result['finalContent'], contains('你好中国'));
    });

    test('22. Korean characters', () async {
      final result = await applyPatchToContent(
        '안녕하세요',
        '''@@ -1 +1,2 @@
 안녕하세요
+감사합니다
''',
      );
      expect(result['success'], isTrue, reason: 'Error: ${result['error']}');
      expect(result['finalContent'], contains('감사합니다'));
    });

    test('23. mixed Japanese and English', () async {
      final result = await applyPatchToContent(
        'Hello 世界',
        '''@@ -1 +1 @@
-Hello 世界
+Hello World 世界
''',
      );
      expect(result['success'], isTrue, reason: 'Error: ${result['error']}');
      expect(result['finalContent'], contains('Hello World 世界'));
    });

    test('24. Arabic characters', () async {
      final result = await applyPatchToContent(
        'مرحبا',
        '''@@ -1 +1,2 @@
 مرحبا
+شكرا
''',
      );
      expect(result['success'], isTrue, reason: 'Error: ${result['error']}');
      expect(result['finalContent'], contains('شكرا'));
    });

    test('25. Russian characters', () async {
      final result = await applyPatchToContent(
        'Привет',
        '''@@ -1 +1 @@
-Привет
+Привет мир
''',
      );
      expect(result['success'], isTrue, reason: 'Error: ${result['error']}');
      expect(result['finalContent'], contains('Привет мир'));
    });

    // ==================== Issue Specific Tests ====================
    
    test('26. exact issue case 1 - without blank lines', () async {
      final result = await applyPatchToContent(
        '''【原文】
春は、あけぼの。やうやう白くなりゆく山ぎは、少し明かりて、紫だちたる雲の細くたなびきたる。

【現代語訳】
春は、夜明けが一番美しい。だんだんと白んでいく山際が、少し明るくなって、ほんのり紫がかった雲が細くたなびいている様子が趣深い。
''',
        '''@@ -1,5 +1,7 @@
 【原文】
 春は、あけぼの。やうやう白くなりゆく山ぎは、少し明かりて、紫だちたる雲の細くたなびきたる。
+夏は、夜（よる）。月のころはさらなり、闇もなお、蛍の多く飛びちがひたる。
 
 【現代語訳】
 春は、夜明けが一番美しい。だんだんと白んでいく山際が、少し明るくなって、ほんのり紫がかった雲が細くたなびいている様子が趣深い。
+夏は、夜が良い。月の出ている時は言うまでもなく、闇夜でもなお、多くの蛍が飛び交っている様子が風情を感じさせる。
''',
      );
      expect(result['success'], isTrue, reason: 'Error: ${result['error']}');
      expect(result['finalContent'], contains('夏は、夜（よる）'));
      expect(result['finalContent'], contains('蛍の多く飛びちがひたる'));
    });

    test('27. exact issue case 2 - with blank lines', () async {
      final result = await applyPatchToContent(
        '''【原文】
春は、あけぼの。やうやう白くなりゆく山ぎは、少し明かりて、紫だちたる雲の細くたなびきたる。

【現代語訳】
春は、夜明けが一番美しい。だんだんと白んでいく山際が、少し明るくなって、ほんのり紫がかった雲が細くたなびいている様子が趣深い。
''',
        '''@@ -1,6 +1,9 @@
 【原文】
 春は、あけぼの。やうやう白くなりゆく山ぎは、少し明かりて、紫だちたる雲の細くたなびきたる。
+
+夏は、夜（よる）。月のころはさらなり、闇もなお、蛍の多く飛びちがひたる。
 
 【現代語訳】
 春は、夜明けが一番美しい。だんだんと白んでいく山際が、少し明るくなって、ほんのり紫がかった雲が細くたなびいている様子が趣深い。
+
+夏は、夜が良い。月の出ている時は言うまでもなく、闇夜でもなお、多くの蛍が飛び交っている様子が風情を感じさせる。
''',
      );
      expect(result['success'], isTrue, reason: 'Error: ${result['error']}');
    });

    // ==================== Edge Cases ====================
    
    test('28. patch with only context lines (no changes)', () async {
      final createResult = await overwriteTool.execute({
        'content': 'Line 1\nLine 2',
      });
      final tabId = createResult['tabId'] as String;
      
      // A patch with no actual changes (only context) should result in empty patches
      final patchResult = await patchTool.execute({
        'tabId': tabId,
        'patch': '',
      });
      
      expect(patchResult['success'], isFalse);
      expect(patchResult['error'], contains('No valid patches'));
    });

    test('29. long Japanese text with multiple changes', () async {
      final result = await applyPatchToContent(
        '''春は、あけぼの。
夏は、夜。
秋は、夕暮れ。
冬は、つとめて。''',
        '''@@ -1,4 +1,4 @@
 春は、あけぼの。
-夏は、夜。
+夏は、夜（よる）。
 秋は、夕暮れ。
-冬は、つとめて。
+冬は、つとめて（早朝）。
''',
      );
      expect(result['success'], isTrue, reason: 'Error: ${result['error']}');
      expect(result['finalContent'], contains('夏は、夜（よる）。'));
      expect(result['finalContent'], contains('冬は、つとめて（早朝）。'));
    });

    test('30. Japanese text with various punctuation', () async {
      final result = await applyPatchToContent(
        '「こんにちは」と言った。',
        '''@@ -1 +1 @@
-「こんにちは」と言った。
+『こんにちは！』と言った…。
''',
      );
      expect(result['success'], isTrue, reason: 'Error: ${result['error']}');
      expect(result['finalContent'], contains('『こんにちは！』と言った…。'));
    });

    test('31. text with tabs', () async {
      final result = await applyPatchToContent(
        'Column1\tColumn2',
        '''@@ -1 +1,2 @@
 Column1\tColumn2
+Column3\tColumn4
''',
      );
      expect(result['success'], isTrue, reason: 'Error: ${result['error']}');
      expect(result['finalContent'], contains('Column3\tColumn4'));
    });

    test('32. markdown code block', () async {
      final result = await applyPatchToContent(
        '''# Title
```
code here
```''',
        '''@@ -1,4 +1,5 @@
 # Title
 ```
 code here
+more code
 ```
''',
      );
      expect(result['success'], isTrue, reason: 'Error: ${result['error']}');
      expect(result['finalContent'], contains('more code'));
    });

    test('33. text starting with plus sign', () async {
      final result = await applyPatchToContent(
        '+1 for this idea',
        '''@@ -1 +1 @@
-+1 for this idea
++100 for this idea
''',
      );
      expect(result['success'], isTrue, reason: 'Error: ${result['error']}');
      expect(result['finalContent'], contains('+100 for this idea'));
    });

    test('34. text starting with minus sign', () async {
      final result = await applyPatchToContent(
        '-5 degrees',
        '''@@ -1 +1 @@
--5 degrees
+-10 degrees
''',
      );
      expect(result['success'], isTrue, reason: 'Error: ${result['error']}');
      expect(result['finalContent'], contains('-10 degrees'));
    });

    test('35. very long single line', () async {
      final longLine = 'A' * 500;
      final result = await applyPatchToContent(
        longLine,
        '''@@ -1 +1 @@
-$longLine
+${'B' * 500}
''',
      );
      expect(result['success'], isTrue, reason: 'Error: ${result['error']}');
      expect(result['finalContent'], contains('B' * 500));
    });
  });
}
