import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:diff_match_patch/diff_match_patch.dart';
import 'package:vagina/services/notepad_service.dart';
import 'package:vagina/services/tools_runtime/tool_context.dart';
import 'package:vagina/tools/builtin/builtin_tools.dart';

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
    late ToolContext ctx;
    late DocumentPatchTool patchTool;
    late DocumentOverwriteTool overwriteTool;

    /// Helper function to create a document and apply a patch, returns final content
    Future<String?> applyPatchAndGetResult(
      String originalContent,
      String patch,
    ) async {
      final createOut = await overwriteTool.execute({
        'content': originalContent,
      }, ctx);
      final createResult = jsonDecode(createOut) as Map<String, dynamic>;
      final tabId = createResult['tabId'] as String;

      final patchOut = await patchTool.execute({
        'tabId': tabId,
        'patch': patch,
      }, ctx);
      final patchResult = jsonDecode(patchOut) as Map<String, dynamic>;

      if (patchResult['success'] == true) {
        return notepadService.getTabContent(tabId);
      }
      return null;
    }

    setUp(() {
      notepadService = NotepadService();
      ctx = ToolContext(notepadService: notepadService);
      patchTool = DocumentPatchTool();
      overwriteTool = DocumentOverwriteTool();
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
      final createOut = await overwriteTool.execute({
        'content': 'Line 1\nLine 2',
      }, ctx);
      final createResult = jsonDecode(createOut) as Map<String, dynamic>;
      final tabId = createResult['tabId'] as String;

      final patchOut = await patchTool.execute({
        'tabId': tabId,
        'patch': '',
      }, ctx);
      final patchResult = jsonDecode(patchOut) as Map<String, dynamic>;

      expect(patchResult['success'], isFalse);
      expect(patchResult['error'], contains('No valid patches'));
    });

    test('22. Tab not found returns error', () async {
      final patchOut = await patchTool.execute({
        'tabId': 'non_existent_tab',
        'patch': '''@@ -1 +1 @@
-old
+new
''',
      }, ctx);
      final patchResult = jsonDecode(patchOut) as Map<String, dynamic>;

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

    // ==================== Needle in Haystack Tests ====================
    
    test('31. Needle in haystack: single word change in long Japanese text', () async {
      const input = '''むかしむかし、あるところにおじいさんとおばあさんがいました。
おじいさんは山へしばかりに、おばあさんは川へせんたくに行きました。
おばあさんが川でせんたくをしていると、大きなももが流れてきました。
おばあさんはそのももを持ち帰り、おじいさんと一緒に食べようとしました。
すると中から元気な男の子が生まれました。
二人はその子を桃太郎と名づけました。
''';
      const patch = '''@@ -1,6 +1,6 @@
 むかしむかし、あるところにおじいさんとおばあさんがいました。
 おじいさんは山へしばかりに、おばあさんは川へせんたくに行きました。
 おばあさんが川でせんたくをしていると、大きなももが流れてきました。
-おばあさんはそのももを持ち帰り、おじいさんと一緒に食べようとしました。
+おばあさんはその大きなももを持ち帰り、おじいさんと一緒に切ろうとしました。
 すると中から元気な男の子が生まれました。
 二人はその子を桃太郎と名づけました。
''';
      const expected = '''むかしむかし、あるところにおじいさんとおばあさんがいました。
おじいさんは山へしばかりに、おばあさんは川へせんたくに行きました。
おばあさんが川でせんたくをしていると、大きなももが流れてきました。
おばあさんはその大きなももを持ち帰り、おじいさんと一緒に切ろうとしました。
すると中から元気な男の子が生まれました。
二人はその子を桃太郎と名づけました。
''';
      
      final result = await applyPatchAndGetResult(input, patch);
      expect(result, equals(expected));
    });

    test('32. Needle in haystack: single change in 20-line document', () async {
      const input = '''行1：テスト
行2：テスト
行3：テスト
行4：テスト
行5：テスト
行6：テスト
行7：テスト
行8：テスト
行9：テスト
行10：これは古いテストです
行11：テスト
行12：テスト
行13：テスト
行14：テスト
行15：テスト
行16：テスト
行17：テスト
行18：テスト
行19：テスト
行20：テスト
''';
      const patch = '''@@ -8,5 +8,5 @@
 行8：テスト
 行9：テスト
-行10：これは古いテストです
+行10：これは新しいテストです
 行11：テスト
 行12：テスト
''';
      const expected = '''行1：テスト
行2：テスト
行3：テスト
行4：テスト
行5：テスト
行6：テスト
行7：テスト
行8：テスト
行9：テスト
行10：これは新しいテストです
行11：テスト
行12：テスト
行13：テスト
行14：テスト
行15：テスト
行16：テスト
行17：テスト
行18：テスト
行19：テスト
行20：テスト
''';
      
      final result = await applyPatchAndGetResult(input, patch);
      expect(result, equals(expected));
    });

    test('33. Needle in haystack: change one line at the end of long document', () async {
      final inputLines = List.generate(30, (i) => '段落${i + 1}');
      inputLines[29] = '最後の段落（旧）';
      final input = '${inputLines.join('\n')}\n';
      
      const patch = '''@@ -28,3 +28,3 @@
 段落28
 段落29
-最後の段落（旧）
+最後の段落（新）
''';
      
      final expectedLines = List.generate(30, (i) => '段落${i + 1}');
      expectedLines[29] = '最後の段落（新）';
      final expected = '${expectedLines.join('\n')}\n';
      
      final result = await applyPatchAndGetResult(input, patch);
      expect(result, equals(expected));
    });

    test('34. Needle in haystack: change one line at the beginning of long document', () async {
      final inputLines = ['最初の行（旧）'] + List.generate(29, (i) => '段落${i + 2}');
      final input = '${inputLines.join('\n')}\n';
      
      const patch = '''@@ -1,3 +1,3 @@
-最初の行（旧）
+最初の行（新）
 段落2
 段落3
''';
      
      final expectedLines = ['最初の行（新）'] + List.generate(29, (i) => '段落${i + 2}');
      final expected = '${expectedLines.join('\n')}\n';
      
      final result = await applyPatchAndGetResult(input, patch);
      expect(result, equals(expected));
    });

    // ==================== Long Content Tests ====================
    
    test('35. Long content: 15-line Japanese document with middle edit', () async {
      const input = '''最初の段落です。
二番目の段落です。
三番目の段落です。
四番目の段落です。
五番目の段落です。
六番目の段落です。
七番目の段落です。
八番目の段落（古い内容）です。
九番目の段落です。
十番目の段落です。
十一番目の段落です。
十二番目の段落です。
十三番目の段落です。
十四番目の段落です。
十五番目の段落です。
''';
      const patch = '''@@ -6,5 +6,5 @@
 六番目の段落です。
 七番目の段落です。
-八番目の段落（古い内容）です。
+八番目の段落（新しい内容）です。
 九番目の段落です。
 十番目の段落です。
''';
      const expected = '''最初の段落です。
二番目の段落です。
三番目の段落です。
四番目の段落です。
五番目の段落です。
六番目の段落です。
七番目の段落です。
八番目の段落（新しい内容）です。
九番目の段落です。
十番目の段落です。
十一番目の段落です。
十二番目の段落です。
十三番目の段落です。
十四番目の段落です。
十五番目の段落です。
''';
      
      final result = await applyPatchAndGetResult(input, patch);
      expect(result, equals(expected));
    });

    test('36. Long content: add line to 25-line document', () async {
      const input = '''行1
行2
行3
行4
行5
行6
行7
行8
行9
行10
行11
行12
行13
行14
行15
行16
行17
行18
行19
行20
行21
行22
行23
行24
行25
''';
      const patch = '''@@ -10,5 +10,6 @@
 行10
 行11
 行12
+新しい行
 行13
 行14
''';
      const expected = '''行1
行2
行3
行4
行5
行6
行7
行8
行9
行10
行11
行12
新しい行
行13
行14
行15
行16
行17
行18
行19
行20
行21
行22
行23
行24
行25
''';
      
      final result = await applyPatchAndGetResult(input, patch);
      expect(result, equals(expected));
    });

    test('37. Long content: very long single line (1000 chars)', () async {
      final longContent = 'あ' * 1000;
      final input = '$longContent\n';
      
      final newContent = 'あ' * 500 + 'い' * 500;
      final patch = '''@@ -1 +1 @@
-$longContent
+$newContent
''';
      final expected = '$newContent\n';
      
      final result = await applyPatchAndGetResult(input, patch);
      expect(result, equals(expected));
    });

    test('38. Long content: multiple long lines', () async {
      final line1 = '第一行：${'漢字' * 100}';
      final line2 = '第二行：${'ひらがな' * 100}';
      final line3 = '第三行：${'カタカナ' * 100}';
      final input = '$line1\n$line2\n$line3\n';
      
      final newLine2 = '第二行（修正）：${'ひらがな' * 100}';
      final patch = '''@@ -1,3 +1,3 @@
 $line1
-$line2
+$newLine2
 $line3
''';
      final expected = '$line1\n$newLine2\n$line3\n';
      
      final result = await applyPatchAndGetResult(input, patch);
      expect(result, equals(expected));
    });

    // ==================== Fine-grained Detail Tests ====================
    
    test('39. Detail: single character replacement in Japanese', () async {
      const input = '東京都\n';
      const patch = '''@@ -1 +1 @@
-東京都
+東京府
''';
      const expected = '東京府\n';
      
      final result = await applyPatchAndGetResult(input, patch);
      expect(result, equals(expected));
    });

    test('40. Detail: single punctuation change', () async {
      const input = 'こんにちは。\n';
      const patch = '''@@ -1 +1 @@
-こんにちは。
+こんにちは！
''';
      const expected = 'こんにちは！\n';
      
      final result = await applyPatchAndGetResult(input, patch);
      expect(result, equals(expected));
    });

    test('41. Detail: whitespace preservation', () async {
      const input = '　インデントされた行\n';  // Full-width space at start
      const patch = '''@@ -1 +1,2 @@
 　インデントされた行
+　別のインデント行
''';
      const expected = '　インデントされた行\n　別のインデント行\n';
      
      final result = await applyPatchAndGetResult(input, patch);
      expect(result, equals(expected));
    });

    test('42. Detail: mixed width characters', () async {
      const input = 'ABCあいうDEF\n';
      const patch = '''@@ -1 +1 @@
-ABCあいうDEF
+ABCかきくDEF
''';
      const expected = 'ABCかきくDEF\n';
      
      final result = await applyPatchAndGetResult(input, patch);
      expect(result, equals(expected));
    });

    test('43. Detail: special Unicode characters', () async {
      const input = '①②③\n';
      const patch = '''@@ -1 +1 @@
-①②③
+❶❷❸
''';
      const expected = '❶❷❸\n';
      
      final result = await applyPatchAndGetResult(input, patch);
      expect(result, equals(expected));
    });

    test('44. Detail: mathematical symbols with Japanese', () async {
      const input = 'x² + y² = r²\n';
      const patch = '''@@ -1 +1,2 @@
 x² + y² = r²
+（円の方程式）
''';
      const expected = 'x² + y² = r²\n（円の方程式）\n';
      
      final result = await applyPatchAndGetResult(input, patch);
      expect(result, equals(expected));
    });

    test('45. Detail: consecutive empty lines handling', () async {
      const input = '第一段落\n\n\n第二段落\n';
      const patch = '''@@ -1,4 +1,5 @@
 第一段落
 
 
+追加行
 第二段落
''';
      const expected = '第一段落\n\n\n追加行\n第二段落\n';
      
      final result = await applyPatchAndGetResult(input, patch);
      expect(result, equals(expected));
    });

    // ==================== Complex Scenario Tests ====================
    
    test('46. Complex: multiple scattered changes in document', () async {
      const input = '''章1：序章
内容A
内容B
章2：本編
内容C
内容D
章3：終章
内容E
内容F
''';
      // Note: This requires multiple hunks or separate patches
      // For simplicity, testing one hunk that changes multiple consecutive lines
      const patch = '''@@ -4,3 +4,3 @@
 章2：本編
-内容C
-内容D
+内容C（更新）
+内容D（更新）
''';
      const expected = '''章1：序章
内容A
内容B
章2：本編
内容C（更新）
内容D（更新）
章3：終章
内容E
内容F
''';
      
      final result = await applyPatchAndGetResult(input, patch);
      expect(result, equals(expected));
    });

    test('47. Complex: delete multiple consecutive lines', () async {
      const input = '''保持行1
削除行1
削除行2
削除行3
保持行2
''';
      const patch = '''@@ -1,5 +1,2 @@
 保持行1
-削除行1
-削除行2
-削除行3
 保持行2
''';
      const expected = '''保持行1
保持行2
''';
      
      final result = await applyPatchAndGetResult(input, patch);
      expect(result, equals(expected));
    });

    test('48. Complex: insert block of text', () async {
      const input = '''既存行1
既存行2
''';
      const patch = '''@@ -1,2 +1,5 @@
 既存行1
+挿入行1
+挿入行2
+挿入行3
 既存行2
''';
      const expected = '''既存行1
挿入行1
挿入行2
挿入行3
既存行2
''';
      
      final result = await applyPatchAndGetResult(input, patch);
      expect(result, equals(expected));
    });

    test('49. Complex: replace entire content', () async {
      const input = '''古い内容1
古い内容2
古い内容3
''';
      const patch = '''@@ -1,3 +1,3 @@
-古い内容1
-古い内容2
-古い内容3
+新しい内容A
+新しい内容B
+新しい内容C
''';
      const expected = '''新しい内容A
新しい内容B
新しい内容C
''';
      
      final result = await applyPatchAndGetResult(input, patch);
      expect(result, equals(expected));
    });

    test('50. Complex: interleaved additions and deletions', () async {
      const input = '''行1
行2
行3
行4
行5
''';
      const patch = '''@@ -1,5 +1,5 @@
 行1
-行2
+行2（変更）
 行3
-行4
+行4（変更）
 行5
''';
      const expected = '''行1
行2（変更）
行3
行4（変更）
行5
''';
      
      final result = await applyPatchAndGetResult(input, patch);
      expect(result, equals(expected));
    });
  });
}
