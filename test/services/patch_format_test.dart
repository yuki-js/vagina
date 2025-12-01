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

    /// Helper function to create a document and apply a patch, returns final content
    Future<String?> applyPatchAndGetResult(
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
        return notepadService.getTabContent(tabId);
      }
      return null;
    }

    setUp(() {
      notepadService = NotepadService();
      patchTool = DocumentPatchTool(notepadService: notepadService);
      overwriteTool = DocumentOverwriteTool(notepadService: notepadService);
    });

    tearDown(() {
      notepadService.dispose();
    });

    // ==================== Japanese Text Tests (Main Issue) ====================
    
    test('1. Japanese: simple replacement with parentheses', () async {
      const input = '夏は、夜。\n';
      const patch = '''@@ -1 +1 @@
-夏は、夜。
+夏は、夜（よる）。
''';
      const expected = '夏は、夜（よる）。\n';
      
      final result = await applyPatchAndGetResult(input, patch);
      expect(result, equals(expected), reason: 'Input: $input\nPatch applied should produce exact expected output');
    });

    test('2. Japanese: add brackets 【】', () async {
      const input = '原文\n';
      const patch = '''@@ -1 +1 @@
-原文
+【原文】
''';
      const expected = '【原文】\n';
      
      final result = await applyPatchAndGetResult(input, patch);
      expect(result, equals(expected));
    });

    test('3. Japanese: add line after existing', () async {
      const input = '春は、あけぼの。\n';
      const patch = '''@@ -1 +1,2 @@
 春は、あけぼの。
+夏は、夜。
''';
      const expected = '春は、あけぼの。\n夏は、夜。\n';
      
      final result = await applyPatchAndGetResult(input, patch);
      expect(result, equals(expected));
    });

    test('4. Japanese: multiple additions', () async {
      const input = 'こんにちは\n';
      const patch = '''@@ -1 +1,3 @@
 こんにちは
+お元気ですか
+さようなら
''';
      const expected = 'こんにちは\nお元気ですか\nさようなら\n';
      
      final result = await applyPatchAndGetResult(input, patch);
      expect(result, equals(expected));
    });

    test('5. Japanese: deletion', () async {
      const input = '行1\n行2\n行3\n';
      const patch = '''@@ -1,3 +1,2 @@
 行1
-行2
 行3
''';
      const expected = '行1\n行3\n';
      
      final result = await applyPatchAndGetResult(input, patch);
      expect(result, equals(expected));
    });

    test('6. Japanese: replacement in middle', () async {
      const input = '春\n夏\n秋\n冬\n';
      const patch = '''@@ -1,4 +1,4 @@
 春
-夏
+夏（なつ）
 秋
 冬
''';
      const expected = '春\n夏（なつ）\n秋\n冬\n';
      
      final result = await applyPatchAndGetResult(input, patch);
      expect(result, equals(expected));
    });

    test('7. Japanese: add empty line between content', () async {
      const input = '段落1\n段落2\n';
      const patch = '''@@ -1,2 +1,3 @@
 段落1
+
 段落2
''';
      const expected = '段落1\n\n段落2\n';
      
      final result = await applyPatchAndGetResult(input, patch);
      expect(result, equals(expected));
    });

    test('8. Japanese: multiple empty lines', () async {
      const input = '開始\n終了\n';
      const patch = '''@@ -1,2 +1,4 @@
 開始
+
+
 終了
''';
      const expected = '開始\n\n\n終了\n';
      
      final result = await applyPatchAndGetResult(input, patch);
      expect(result, equals(expected));
    });

    test('9. Japanese: with emoji', () async {
      const input = '今日は良い天気\n';
      const patch = '''@@ -1 +1 @@
-今日は良い天気
+今日は良い天気☀️
''';
      const expected = '今日は良い天気☀️\n';
      
      final result = await applyPatchAndGetResult(input, patch);
      expect(result, equals(expected));
    });

    test('10. Japanese: with numbers', () async {
      const input = '2024年1月1日\n';
      const patch = '''@@ -1 +1 @@
-2024年1月1日
+2024年12月31日
''';
      const expected = '2024年12月31日\n';
      
      final result = await applyPatchAndGetResult(input, patch);
      expect(result, equals(expected));
    });

    // ==================== Issue Reproduction Tests ====================
    
    test('11. Issue case 1: Makura no Soshi addition without blank lines', () async {
      const input = '''【原文】
春は、あけぼの。やうやう白くなりゆく山ぎは、少し明かりて、紫だちたる雲の細くたなびきたる。

【現代語訳】
春は、夜明けが一番美しい。だんだんと白んでいく山際が、少し明るくなって、ほんのり紫がかった雲が細くたなびいている様子が趣深い。
''';
      const patch = '''@@ -1,5 +1,7 @@
 【原文】
 春は、あけぼの。やうやう白くなりゆく山ぎは、少し明かりて、紫だちたる雲の細くたなびきたる。
+夏は、夜（よる）。月のころはさらなり、闇もなお、蛍の多く飛びちがひたる。
 
 【現代語訳】
 春は、夜明けが一番美しい。だんだんと白んでいく山際が、少し明るくなって、ほんのり紫がかった雲が細くたなびいている様子が趣深い。
+夏は、夜が良い。月の出ている時は言うまでもなく、闇夜でもなお、多くの蛍が飛び交っている様子が風情を感じさせる。
''';
      const expected = '''【原文】
春は、あけぼの。やうやう白くなりゆく山ぎは、少し明かりて、紫だちたる雲の細くたなびきたる。
夏は、夜（よる）。月のころはさらなり、闇もなお、蛍の多く飛びちがひたる。

【現代語訳】
春は、夜明けが一番美しい。だんだんと白んでいく山際が、少し明るくなって、ほんのり紫がかった雲が細くたなびいている様子が趣深い。
夏は、夜が良い。月の出ている時は言うまでもなく、闇夜でもなお、多くの蛍が飛び交っている様子が風情を感じさせる。
''';
      
      final result = await applyPatchAndGetResult(input, patch);
      expect(result, equals(expected));
    });

    test('12. Issue case 2: Makura no Soshi addition with blank lines', () async {
      const input = '''【原文】
春は、あけぼの。やうやう白くなりゆく山ぎは、少し明かりて、紫だちたる雲の細くたなびきたる。

【現代語訳】
春は、夜明けが一番美しい。だんだんと白んでいく山際が、少し明るくなって、ほんのり紫がかった雲が細くたなびいている様子が趣深い。
''';
      const patch = '''@@ -1,6 +1,9 @@
 【原文】
 春は、あけぼの。やうやう白くなりゆく山ぎは、少し明かりて、紫だちたる雲の細くたなびきたる。
+
+夏は、夜（よる）。月のころはさらなり、闇もなお、蛍の多く飛びちがひたる。
 
 【現代語訳】
 春は、夜明けが一番美しい。だんだんと白んでいく山際が、少し明るくなって、ほんのり紫がかった雲が細くたなびいている様子が趣深い。
+
+夏は、夜が良い。月の出ている時は言うまでもなく、闇夜でもなお、多くの蛍が飛び交っている様子が風情を感じさせる。
''';
      const expected = '''【原文】
春は、あけぼの。やうやう白くなりゆく山ぎは、少し明かりて、紫だちたる雲の細くたなびきたる。

夏は、夜（よる）。月のころはさらなり、闇もなお、蛍の多く飛びちがひたる。

【現代語訳】
春は、夜明けが一番美しい。だんだんと白んでいく山際が、少し明るくなって、ほんのり紫がかった雲が細くたなびいている様子が趣深い。

夏は、夜が良い。月の出ている時は言うまでもなく、闇夜でもなお、多くの蛍が飛び交っている様子が風情を感じさせる。
''';
      
      final result = await applyPatchAndGetResult(input, patch);
      expect(result, equals(expected));
    });

    // ==================== Multi-byte Character Tests ====================
    
    test('13. Chinese: simple replacement', () async {
      const input = '你好世界\n';
      const patch = '''@@ -1 +1 @@
-你好世界
+你好中国
''';
      const expected = '你好中国\n';
      
      final result = await applyPatchAndGetResult(input, patch);
      expect(result, equals(expected));
    });

    test('14. Korean: add line', () async {
      const input = '안녕하세요\n';
      const patch = '''@@ -1 +1,2 @@
 안녕하세요
+감사합니다
''';
      const expected = '안녕하세요\n감사합니다\n';
      
      final result = await applyPatchAndGetResult(input, patch);
      expect(result, equals(expected));
    });

    test('15. Russian: replacement', () async {
      const input = 'Привет\n';
      const patch = '''@@ -1 +1 @@
-Привет
+Привет мир
''';
      const expected = 'Привет мир\n';
      
      final result = await applyPatchAndGetResult(input, patch);
      expect(result, equals(expected));
    });

    test('16. Arabic: add line', () async {
      const input = 'مرحبا\n';
      const patch = '''@@ -1 +1,2 @@
 مرحبا
+شكرا
''';
      const expected = 'مرحبا\nشكرا\n';
      
      final result = await applyPatchAndGetResult(input, patch);
      expect(result, equals(expected));
    });

    test('17. Mixed Japanese and English', () async {
      const input = 'Hello 世界\n';
      const patch = '''@@ -1 +1 @@
-Hello 世界
+Hello World 世界
''';
      const expected = 'Hello World 世界\n';
      
      final result = await applyPatchAndGetResult(input, patch);
      expect(result, equals(expected));
    });

    // ==================== Japanese Punctuation Tests ====================
    
    test('18. Japanese: various punctuation marks', () async {
      const input = '「こんにちは」と言った。\n';
      const patch = '''@@ -1 +1 @@
-「こんにちは」と言った。
+『こんにちは！』と言った…。
''';
      const expected = '『こんにちは！』と言った…。\n';
      
      final result = await applyPatchAndGetResult(input, patch);
      expect(result, equals(expected));
    });

    test('19. Japanese: percent sign in content', () async {
      const input = '進捗: 50%\n';
      const patch = '''@@ -1 +1 @@
-進捗: 50%
+進捗: 100%
''';
      const expected = '進捗: 100%\n';
      
      final result = await applyPatchAndGetResult(input, patch);
      expect(result, equals(expected));
    });

    test('20. Japanese: four seasons replacement', () async {
      const input = '''春は、あけぼの。
夏は、夜。
秋は、夕暮れ。
冬は、つとめて。
''';
      const patch = '''@@ -1,4 +1,4 @@
 春は、あけぼの。
-夏は、夜。
+夏は、夜（よる）。
 秋は、夕暮れ。
-冬は、つとめて。
+冬は、つとめて（早朝）。
''';
      const expected = '''春は、あけぼの。
夏は、夜（よる）。
秋は、夕暮れ。
冬は、つとめて（早朝）。
''';
      
      final result = await applyPatchAndGetResult(input, patch);
      expect(result, equals(expected));
    });

    // ==================== Edge Cases ====================
    
    test('21. Empty patch returns error', () async {
      final createResult = await overwriteTool.execute({
        'content': 'Line 1\nLine 2',
      });
      final tabId = createResult['tabId'] as String;
      
      final patchResult = await patchTool.execute({
        'tabId': tabId,
        'patch': '',
      });
      
      expect(patchResult['success'], isFalse);
      expect(patchResult['error'], contains('No valid patches'));
    });

    test('22. Tab not found returns error', () async {
      final patchResult = await patchTool.execute({
        'tabId': 'non_existent_tab',
        'patch': '''@@ -1 +1 @@
-old
+new
''',
      });
      
      expect(patchResult['success'], isFalse);
      expect(patchResult['error'], contains('Tab not found'));
    });

    // ==================== Additional Japanese Tests ====================
    
    test('23. Japanese: single character addition', () async {
      const input = 'あ\n';
      const patch = '''@@ -1 +1,2 @@
 あ
+い
''';
      const expected = 'あ\nい\n';
      
      final result = await applyPatchAndGetResult(input, patch);
      expect(result, equals(expected));
    });

    test('24. Japanese: hiragana to katakana', () async {
      const input = 'こんにちは\n';
      const patch = '''@@ -1 +1 @@
-こんにちは
+コンニチハ
''';
      const expected = 'コンニチハ\n';
      
      final result = await applyPatchAndGetResult(input, patch);
      expect(result, equals(expected));
    });

    test('25. Japanese: long text addition', () async {
      const input = '吾輩は猫である。\n';
      const patch = '''@@ -1 +1,2 @@
 吾輩は猫である。
+名前はまだ無い。
''';
      const expected = '吾輩は猫である。\n名前はまだ無い。\n';
      
      final result = await applyPatchAndGetResult(input, patch);
      expect(result, equals(expected));
    });

    test('26. Japanese: delete middle line', () async {
      const input = '一\n二\n三\n';
      const patch = '''@@ -1,3 +1,2 @@
 一
-二
 三
''';
      const expected = '一\n三\n';
      
      final result = await applyPatchAndGetResult(input, patch);
      expect(result, equals(expected));
    });

    test('27. Japanese: replace first line', () async {
      const input = '古い行\n残る行\n';
      const patch = '''@@ -1,2 +1,2 @@
-古い行
+新しい行
 残る行
''';
      const expected = '新しい行\n残る行\n';
      
      final result = await applyPatchAndGetResult(input, patch);
      expect(result, equals(expected));
    });

    test('28. Japanese: replace last line', () async {
      const input = '残る行\n古い行\n';
      const patch = '''@@ -1,2 +1,2 @@
 残る行
-古い行
+新しい行
''';
      const expected = '残る行\n新しい行\n';
      
      final result = await applyPatchAndGetResult(input, patch);
      expect(result, equals(expected));
    });

    test('29. Japanese: add at beginning', () async {
      const input = '既存の行\n';
      const patch = '''@@ -1 +1,2 @@
+新しい行
 既存の行
''';
      const expected = '新しい行\n既存の行\n';
      
      final result = await applyPatchAndGetResult(input, patch);
      expect(result, equals(expected));
    });

    test('30. Japanese: complex multi-line edit', () async {
      const input = '''第一章
内容1
内容2
第二章
''';
      const patch = '''@@ -1,4 +1,5 @@
 第一章
-内容1
+内容1（修正済み）
 内容2
+内容3
 第二章
''';
      const expected = '''第一章
内容1（修正済み）
内容2
内容3
第二章
''';
      
      final result = await applyPatchAndGetResult(input, patch);
      expect(result, equals(expected));
    });
  });
}
