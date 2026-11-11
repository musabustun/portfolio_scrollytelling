import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portfolio_scrollytelling/theme/theme.dart';
import 'package:portfolio_scrollytelling/widgets/reveal_text.dart';

/// Text bölümü reveal hesabı (AGENTS.md §10.5): kelime ayrıştırma, dolma oranı, renk.
void main() {
  group('parseRevealWords', () {
    test('**kelime** vurgulu olur, yıldızlar atılır', () {
      final words = parseRevealWords('Ben **Flutter** yazarım');
      expect(words.map((w) => w.text), ['Ben', 'Flutter', 'yazarım']);
      expect(words.map((w) => w.emphasized), [false, true, false]);
    });

    test('fazla boşluk ve satır sonu kelime üretmez', () {
      final words = parseRevealWords('  bir   iki\n üç  ');
      expect(words.map((w) => w.text), ['bir', 'iki', 'üç']);
    });

    test('yıldız dışındaki noktalama kelimede kalır', () {
      final words = parseRevealWords('**Flutter**, Dart');
      expect(words.first.text, 'Flutter,');
      expect(words.first.emphasized, isTrue);
    });

    test('**iki kelime** desteklenmez, yıldızlar olduğu gibi kalır', () {
      final words = parseRevealWords('**iki kelime**');
      expect(words.map((w) => w.text), ['**iki', 'kelime**']);
      expect(words.any((w) => w.emphasized), isFalse);
    });

    test('boş metin boş liste', () {
      expect(parseRevealWords('   '), isEmpty);
    });
  });

  group('wordRevealAt', () {
    const n = 4;

    test('progress 0: ilk kelime 0', () {
      expect(wordRevealAt(progress: 0, index: 0, count: n), 0);
    });

    test('progress 1: son kelime 1', () {
      expect(wordRevealAt(progress: 1, index: n - 1, count: n), 1);
    });

    test('i/n eşiğinde 0, hemen üstünde > 0', () {
      expect(wordRevealAt(progress: 2 / n, index: 2, count: n), 0);
      expect(
        wordRevealAt(progress: 2 / n + 1e-3, index: 2, count: n),
        greaterThan(0),
      );
    });

    test('i/n + 1/(1.5n) noktasında tam dolu', () {
      expect(
        wordRevealAt(progress: 2 / n + 1 / (1.5 * n), index: 2, count: n),
        closeTo(1, 1e-9),
      );
    });

    test('aralık dışı kırpılır; kelime yoksa 0', () {
      expect(wordRevealAt(progress: -1, index: 0, count: n), 0);
      expect(wordRevealAt(progress: 2, index: 0, count: n), 1);
      expect(wordRevealAt(progress: 0.5, index: 0, count: 0), 0);
    });
  });

  group('wordColorAt', () {
    const accent = Color(0xFF3366FF);

    test('t = 0: textDim', () {
      expect(
        wordColorAt(
          progress: 0,
          index: 1,
          count: 3,
          emphasized: true,
          accent: accent,
        ),
        AppColors.textDim,
      );
    });

    test('t = 1: düz kelime text', () {
      expect(
        wordColorAt(
          progress: 1,
          index: 2,
          count: 3,
          emphasized: false,
          accent: accent,
        ),
        AppColors.text,
      );
    });

    test('t = 1: vurgulu kelime accent', () {
      expect(
        wordColorAt(
          progress: 1,
          index: 2,
          count: 3,
          emphasized: true,
          accent: accent,
        ),
        accent,
      );
    });
  });

  testWidgets('RevealText tek RichText çizer; vurgulu kelime accent olur', (
    tester,
  ) async {
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: AppBreakpoints.desktopDesignSize,
        builder: (_, _) => MaterialApp(
          theme: AppTheme.build(),
          home: const Scaffold(
            body: RevealText(body: 'Ben **Flutter** yazarım', progress: 1),
          ),
        ),
      ),
    );
    final richText = find.descendant(
      of: find.byType(RevealText),
      matching: find.byType(RichText),
    );
    expect(richText, findsOneWidget);
    final text = tester.widget<Text>(
      find.descendant(of: find.byType(RevealText), matching: find.byType(Text)),
    );
    final spans = (text.textSpan! as TextSpan).children!.cast<TextSpan>();
    expect(spans.map((s) => s.text), ['Ben ', 'Flutter ', 'yazarım']);
    expect(spans.map((s) => s.style?.color), [
      AppColors.text,
      AppColors.accent,
      AppColors.text,
    ]);
    expect(tester.widget<RichText>(richText).textAlign, TextAlign.center);
  });
}
