import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portfolio_scrollytelling/stage/track.dart';
import 'package:portfolio_scrollytelling/story/scroll_progress.dart';

/// Ray (Track): tekerlek/trackpad ve dokunmatik sürükleme kaydırır, tıklamalar alttaki Sahne'ye
/// geçer (AGENTS.md §4 tekerlek tuzağı, §11.4).
void main() {
  const lengths = [4.0, 1.5, 4.0, 2.0, 1.5, 1.0];

  late ScrollProgress scrollProgress;
  late int taps;

  setUp(() {
    scrollProgress = ScrollProgress(scrollLengths: lengths);
    taps = 0;
  });

  tearDown(() => scrollProgress.dispose());

  /// [reduceMotion] işletim sistemi "hareketi azalt" ayarını taklit eder (`disableAnimations`).
  Future<void> pumpTrack(
    WidgetTester tester, {
    bool reduceMotion = false,
  }) async {
    final site = Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => taps++,
            child: const SizedBox.expand(),
          ),
          Track(scrollProgress: scrollProgress),
        ],
      ),
    );
    await tester.pumpWidget(
      reduceMotion
          ? MediaQuery(
              data: const MediaQueryData(disableAnimations: true),
              child: site,
            )
          : site,
    );
  }

  Future<void> wheel(
    WidgetTester tester,
    TestPointer pointer,
    double dy,
  ) async {
    await tester.sendEventToBinding(pointer.scroll(Offset(0, dy)));
    await tester.pump();
  }

  Future<TestPointer> hoverMouse(WidgetTester tester) async {
    final pointer = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(
      pointer.hover(tester.getCenter(find.byType(Track))),
    );
    return pointer;
  }

  testWidgets('tekerlek aşağı kaydırır', (tester) async {
    await pumpTrack(tester);
    final pointer = await hoverMouse(tester);
    await wheel(tester, pointer, 300);
    expect(scrollProgress.value.chapterIndex, 0);
    expect(scrollProgress.value.progress, greaterThan(0));
  });

  testWidgets('tekerlekle sona kadar: son bölüm progress 1', (tester) async {
    await pumpTrack(tester);
    final pointer = await hoverMouse(tester);
    await wheel(tester, pointer, 1e6);
    expect(scrollProgress.value.chapterIndex, lengths.length - 1);
    expect(scrollProgress.value.progress, closeTo(1, 1e-9));
    expect(scrollProgress.value.globalProgress, closeTo(1, 1e-9));
  });

  testWidgets('tekerlek yukarı geri gider', (tester) async {
    await pumpTrack(tester);
    final pointer = await hoverMouse(tester);
    await wheel(tester, pointer, 1e6);
    await wheel(tester, pointer, -300);
    expect(scrollProgress.value.chapterIndex, lengths.length - 1);
    expect(scrollProgress.value.progress, lessThan(1));
    expect(scrollProgress.value.globalProgress, lessThan(1));
  });

  testWidgets('tıklama Ray üzerinden alttaki widget\'a geçer', (tester) async {
    await pumpTrack(tester);
    await tester.tap(find.byType(Track), warnIfMissed: false);
    expect(taps, 1);
  });

  testWidgets('dokunmatik sürükleme kaydırır', (tester) async {
    await pumpTrack(tester);
    await tester.drag(find.byType(Track), const Offset(0, -300));
    await tester.pump();
    expect(scrollProgress.value.progress, greaterThan(0));
  });

  testWidgets('animateToChapter varsayılan: animasyonlu, tek karede varmaz', (
    tester,
  ) async {
    await pumpTrack(tester);
    expect(scrollProgress.reduceMotion, isFalse);
    var done = false;
    scrollProgress.animateToChapter(1).then((_) => done = true);
    await tester.pump();
    expect(scrollProgress.value.chapterIndex, 0);
    expect(done, isFalse);
    await tester.pumpAndSettle();
    expect(scrollProgress.value.chapterIndex, 1);
    expect(done, isTrue);
  });

  testWidgets('reduced-motion: animateToChapter tek karede varır', (
    tester,
  ) async {
    await pumpTrack(tester, reduceMotion: true);
    expect(scrollProgress.reduceMotion, isTrue);
    var done = false;
    scrollProgress.animateToChapter(1).then((_) => done = true);
    await tester.pump();
    expect(scrollProgress.value.chapterIndex, 1);
    expect(scrollProgress.value.progress, 0);
    expect(done, isTrue);
    expect(tester.hasRunningAnimations, isFalse);

    scrollProgress.animateToChapter(lengths.length - 1);
    await tester.pump();
    expect(scrollProgress.value.chapterIndex, lengths.length - 1);
  });

  testWidgets('Ray yeniden kurulunca (yeni State, farklı yükseklik) aynı bölüm '
      've ilerlemeye döner; eski Ray\'ın dispose\'u bağlantıyı koparmaz', (
    tester,
  ) async {
    Widget site(String key, double height) => Directionality(
      textDirection: TextDirection.ltr,
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: 400,
          height: height,
          child: Track(key: ValueKey(key), scrollProgress: scrollProgress),
        ),
      ),
    );
    double offsetIn(double height) => offsetFor(
      chapterIndex: 2,
      progress: 0.4,
      viewportHeight: height,
      scrollLengths: lengths,
    );

    await tester.pumpWidget(site('ilk', 600));
    // İlk açılış: geri yüklenecek bir şey yok, sayfa başında.
    expect(scrollProgress.value, ScrollState.initial);
    final pointer = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(pointer.hover(const Offset(200, 100)));
    await wheel(tester, pointer, offsetIn(600));
    expect(scrollProgress.value.chapterIndex, 2);
    expect(scrollProgress.value.progress, closeTo(0.4, 1e-9));
    final before = tester.state(find.byType(Track));

    // Farklı key ve yükseklik: yeni State, yeni controller (offset 0); eskisi sonra dispose edilir.
    await tester.pumpWidget(site('ikinci', 300));
    expect(tester.state(find.byType(Track)), isNot(same(before)));
    expect(scrollProgress.value.chapterIndex, 2);
    expect(scrollProgress.value.progress, closeTo(0.4, 1e-9));

    // Yeni Ray bağlı: tekerlek ilerlemeyi değiştirir (bölüm 2 = 4 viewport; 120 px = 0.1).
    await wheel(tester, pointer, 120);
    expect(scrollProgress.value.chapterIndex, 2);
    expect(scrollProgress.value.progress, closeTo(0.5, 1e-9));
    expect(tester.takeException(), isNull);
  });

  testWidgets('yüzey yüksekliği değişince (aynı Ray, ör. 375×667 ↔ 667×375) '
      'aynı bölüm ve ilerlemede kalır', (tester) async {
    Widget site(double height) => Directionality(
      textDirection: TextDirection.ltr,
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: 400,
          height: height,
          child: Track(scrollProgress: scrollProgress),
        ),
      ),
    );
    void expectMiddleOfThird() {
      expect(scrollProgress.value.chapterIndex, 2);
      expect(scrollProgress.value.progress, closeTo(0.5, 0.02));
    }

    // Yüzey en yüksek değere (900) de sığsın; varsayılan test ekranı 800×600.
    tester.view.physicalSize = const Size(1000, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(site(667));
    final pointer = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(pointer.hover(const Offset(200, 100)));
    await wheel(
      tester,
      pointer,
      offsetFor(
        chapterIndex: 2,
        progress: 0.5,
        viewportHeight: 667,
        scrollLengths: lengths,
      ),
    );
    expectMiddleOfThird();
    final track = tester.state(find.byType(Track));

    for (final height in [375.0, 667.0, 900.0]) {
      await tester.pumpWidget(site(height));
      await tester.pump();
      // Aynı State (Ray yeniden kurulmadı); konum yalnızca yükseklik değişiminden geri yüklendi.
      expect(tester.state(find.byType(Track)), same(track));
      expectMiddleOfThird();
    }

    // Geri yükleme bir kez uygulanır; sonra tekerlek yine yazar (bölüm 2 = 4 viewport).
    await wheel(tester, pointer, 900 * 4 * 0.1);
    expect(scrollProgress.value.chapterIndex, 2);
    expect(scrollProgress.value.progress, closeTo(0.6, 0.02));
    expect(tester.takeException(), isNull);
  });
}
