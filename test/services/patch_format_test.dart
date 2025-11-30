import 'package:flutter_test/flutter_test.dart';
import 'package:diff_match_patch/diff_match_patch.dart';

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
      print('\n\nProper patch format (URL-encoded):');
      print(properPatchText);
      
      // Now parse it back - this should work
      final parsedPatches = patchFromText(properPatchText);
      expect(parsedPatches, isNotEmpty);
    });
  });
}
