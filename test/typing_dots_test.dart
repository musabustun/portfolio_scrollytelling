import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portfolio_scrollytelling/theme/theme.dart';
import 'package:portfolio_scrollytelling/widgets/typing_dots.dart';

/// TypingDots: üç nokta, sırayla dalgalanan opaklık, hareketi azalt (AGENTS.md §10.6), ekran okuyucu
/// etiketi ve dispose.
void main() {
  final dots = find.descendant(
    of: find.byType(TypingDots),
    matching: find.byType(DecoratedBox),
  );

  /// [reduceMotion] işletim sistemi "hareketi azalt" ayarını taklit eder (`disableAnimations`).
  Widget host({bool reduceMotion = false}) => ScreenUtilInit(
    designSize: AppBreakpoints.desktopDesignSize,
    builder: (_, _) => MaterialApp(
      theme: AppTheme.build(),
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(disableAnimations: reduceMotion),
          child: const Scaffold(body: Center(child: TypingDots())),
        ),
      ),
    ),
  );

  /// Noktaların opaklığı soldan sağa.
  List<double> opacities(WidgetTester tester) => [
    for (final box in tester.widgetList<DecoratedBox>(dots))
      (box.decoration as BoxDecoration).color!.a,
  ];

  group('typingDotOpacityAt', () {
    test('0.3 ↔ 1 arasında kalır; tur başında en düşük, ortasında en '
        'yüksek', () {
      for (var i = 0; i < 3; i++) {
        for (var v = 0.0; v <= 1; v += 0.05) {
          final o = typingDotOpacityAt(value: v, index: i);
          expect(o, inInclusiveRange(0.3, 1.0));
        }
      }
      expect(typingDotOpacityAt(value: 0, index: 0), closeTo(0.3, 1e-9));
      expect(typingDotOpacityAt(value: 0.5, index: 0), closeTo(1, 1e-9));
    });

    test('her nokta bir öncekinden 1/3 tur geride', () {
      for (var v = 0.0; v <= 1; v += 0.1) {
        expect(
          typingDotOpacityAt(value: v + 1 / 3, index: 1),
          closeTo(typingDotOpacityAt(value: v, index: 0), 1e-9),
        );
        expect(
          typingDotOpacityAt(value: v + 2 / 3, index: 2),
          closeTo(typingDotOpacityAt(value: v, index: 0), 1e-9),
        );
      }
    });
  });

  testWidgets('yan yana üç textMuted daire, AppSizes ölçüsünde', (
    tester,
  ) async {
    await tester.pumpWidget(host());
    expect(dots, findsNWidgets(3));
    final boxes = tester.widgetList<DecoratedBox>(dots).toList();
    for (final box in boxes) {
      final decoration = box.decoration as BoxDecoration;
      expect(decoration.shape, BoxShape.circle);
      expect(decoration.color!.withValues(alpha: 1), AppColors.textMuted);
    }
    final rects = [for (var i = 0; i < 3; i++) tester.getRect(dots.at(i))];
    for (var i = 0; i < 3; i++) {
      expect(rects[i].width, closeTo(AppSizes.typingDotSize, 1e-6));
      expect(rects[i].height, closeTo(AppSizes.typingDotSize, 1e-6));
      expect(rects[i].center.dy, closeTo(rects[0].center.dy, 1e-6));
      if (i > 0) {
        expect(
          rects[i].left - rects[i - 1].right,
          closeTo(AppSizes.typingDotGap, 1e-6),
        );
      }
    }
  });

  testWidgets('zaman geçtikçe opaklıklar değişir, noktalar sırayla (aynı anda '
      'farklı)', (tester) async {
    await tester.pumpWidget(host());
    expect(tester.hasRunningAnimations, isTrue);
    // Tur başında 2. ve 3. nokta simetrik (aynı opaklık); biraz ilerleyince üçü ayrışır.
    await tester.pump(AppDurations.typing ~/ 12);
    final start = opacities(tester);
    expect(start.toSet(), hasLength(3), reason: 'fazlar 1/3 kaydırılmış');

    await tester.pump(AppDurations.typing ~/ 4);
    final later = opacities(tester);
    for (var i = 0; i < 3; i++) {
      expect(later[i], isNot(closeTo(start[i], 1e-3)));
      expect(later[i], inInclusiveRange(0.3, 1.0));
    }

    // Bir tur sonra başa döner.
    await tester.pump(AppDurations.typing * 3 ~/ 4);
    final lap = opacities(tester);
    for (var i = 0; i < 3; i++) {
      expect(lap[i], closeTo(start[i], 1e-3));
    }
  });

  testWidgets('hareketi azalt: noktalar sabit 0.6, bekleyen ticker yok', (
    tester,
  ) async {
    await tester.pumpWidget(host(reduceMotion: true));
    expect(dots, findsNWidgets(3));
    expect(opacities(tester), everyElement(closeTo(0.6, 1e-3)));
    expect(tester.hasRunningAnimations, isFalse);
    expect(tester.binding.transientCallbackCount, 0);

    await tester.pump(AppDurations.typing ~/ 3);
    expect(opacities(tester), everyElement(closeTo(0.6, 1e-3)));
    // Dalga dönseydi hiç durulmazdı.
    await tester.pumpAndSettle();
  });

  testWidgets('hareketi azalt sonradan açılınca dalga durur, kapanınca '
      'yeniden başlar', (tester) async {
    await tester.pumpWidget(host());
    expect(tester.hasRunningAnimations, isTrue);

    await tester.pumpWidget(host(reduceMotion: true));
    expect(tester.hasRunningAnimations, isFalse);
    expect(opacities(tester), everyElement(closeTo(0.6, 1e-3)));

    await tester.pumpWidget(host());
    expect(tester.hasRunningAnimations, isTrue);
  });

  testWidgets('ekran okuyucu "Yazıyor…" okur (canlı bölge), noktalar '
      'okunmaz', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(host());
    final label = find.bySemanticsLabel(AppStrings.typing);
    expect(label, findsOneWidget);
    expect(
      tester.getSemantics(label),
      isSemantics(label: AppStrings.typing, isLiveRegion: true),
    );
    semantics.dispose();
  });

  testWidgets('sökülünce dalga kapanır', (tester) async {
    await tester.pumpWidget(host());
    expect(tester.hasRunningAnimations, isTrue);
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
    expect(tester.hasRunningAnimations, isFalse);
  });
}
