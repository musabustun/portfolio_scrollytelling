import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portfolio_scrollytelling/story/scroll_progress.dart';
import 'package:portfolio_scrollytelling/theme/theme.dart';

// örnek bölüm uzunlukları (story.json'dan bağımsız); toplam 14 viewport.
const lengths = <double>[4, 1.5, 4, 2, 1.5, 1];
const vh = 900.0;
const eps = 1e-9;

ScrollState stateAt(double offset) => computeScrollState(
  offset: offset,
  viewportHeight: vh,
  scrollLengths: lengths,
);

void expectState(
  ScrollState state, {
  required int chapter,
  required double progress,
  required double global,
}) {
  expect(state.chapterIndex, chapter, reason: '$state');
  expect(state.progress, closeTo(progress, eps), reason: '$state');
  expect(state.globalProgress, closeTo(global, eps), reason: '$state');
}

double startOf(int index) => chapterStartOffset(
  index: index,
  viewportHeight: vh,
  scrollLengths: lengths,
);

/// ScrollProgress (AGENTS.md §4): offset → bölüm ve progress hesabı, bölüm başlangıçları,
/// controller bağlama ve animateToChapter.
void main() {
  group('computeScrollState', () {
    test('boş liste → initial', () {
      expect(
        computeScrollState(offset: 500, viewportHeight: vh, scrollLengths: []),
        ScrollState.initial,
      );
    });

    test('viewportHeight <= 0 → initial', () {
      expect(
        computeScrollState(
          offset: 500,
          viewportHeight: 0,
          scrollLengths: lengths,
        ),
        ScrollState.initial,
      );
      expect(
        computeScrollState(
          offset: 500,
          viewportHeight: -10,
          scrollLengths: lengths,
        ),
        ScrollState.initial,
      );
    });

    test('offset 0 → bölüm 0, progress 0, global 0', () {
      expectState(stateAt(0), chapter: 0, progress: 0, global: 0);
    });

    test('offset 2·vh → bölüm 0 ortası', () {
      expectState(stateAt(2 * vh), chapter: 0, progress: 0.5, global: 2 / 14);
    });

    test('offset 4·vh tam sınır → bölüm 1 başı', () {
      expectState(stateAt(4 * vh), chapter: 1, progress: 0, global: 4 / 14);
    });

    test('offset 4.75·vh → bölüm 1 ortası', () {
      expectState(
        stateAt(4.75 * vh),
        chapter: 1,
        progress: 0.5,
        global: 4.75 / 14,
      );
    });

    test('her bölüm başı sınırında o bölüm progress 0 ile aktif', () {
      for (var i = 0; i < lengths.length; i++) {
        final start = startOf(i);
        expectState(
          stateAt(start),
          chapter: i,
          progress: 0,
          global: start / vh / 14,
        );
      }
    });

    test('negatif offset → 0’a kırpılır', () {
      expectState(stateAt(-300), chapter: 0, progress: 0, global: 0);
    });

    test('offset toplam (14·vh) → son bölüm, progress 1, global 1', () {
      expectState(stateAt(14 * vh), chapter: 5, progress: 1, global: 1);
    });

    test('offset toplamı aşınca (99·vh) → son bölümde kırpılır', () {
      expectState(stateAt(99 * vh), chapter: 5, progress: 1, global: 1);
    });

    test('son bölüm ortası (13.5·vh)', () {
      expectState(
        stateAt(13.5 * vh),
        chapter: 5,
        progress: 0.5,
        global: 13.5 / 14,
      );
    });

    test('globalProgress ve chapterIndex offset ile monoton artar', () {
      const offsets = <double>[
        -100,
        0,
        450,
        1800,
        3600,
        3601,
        4275,
        4950,
        8000,
        9000,
        11700,
        12600,
        20000,
      ];
      var previous = stateAt(offsets.first);
      for (final offset in offsets.skip(1)) {
        final current = stateAt(offset);
        expect(
          current.globalProgress,
          greaterThanOrEqualTo(previous.globalProgress),
          reason: 'offset $offset',
        );
        expect(
          current.chapterIndex,
          greaterThanOrEqualTo(previous.chapterIndex),
          reason: 'offset $offset',
        );
        previous = current;
      }
      expect(stateAt(offsets.first).globalProgress, 0);
      expect(stateAt(offsets.last).globalProgress, 1);
    });

    test('NaN offset → başa düşer', () {
      expectState(stateAt(double.nan), chapter: 0, progress: 0, global: 0);
    });
  });

  group('chapterStartOffset', () {
    test('kümülatif başlangıçlar, indeks 0..n-1’e kırpılır', () {
      expect(startOf(0), closeTo(0, eps));
      expect(startOf(1), closeTo(4 * vh, eps));
      expect(startOf(2), closeTo(5.5 * vh, eps));
      expect(startOf(5), closeTo(13 * vh, eps));
      expect(startOf(99), closeTo(13 * vh, eps));
      expect(startOf(-1), closeTo(0, eps));
    });

    test('boş liste → 0', () {
      expect(
        chapterStartOffset(index: 3, viewportHeight: vh, scrollLengths: []),
        0,
      );
    });
  });

  group('offsetFor', () {
    double offsetAt(int chapter, double progress, {double height = vh}) =>
        offsetFor(
          chapterIndex: chapter,
          progress: progress,
          viewportHeight: height,
          scrollLengths: lengths,
        );

    test('bölüm başı + ilerleme × bölüm uzunluğu', () {
      expect(offsetAt(0, 0), closeTo(0, eps));
      expect(offsetAt(0, 0.5), closeTo(2 * vh, eps));
      expect(offsetAt(1, 0), closeTo(4 * vh, eps));
      expect(offsetAt(1, 0.5), closeTo(4.75 * vh, eps));
      expect(offsetAt(5, 0.5), closeTo(13.5 * vh, eps));
      expect(offsetAt(5, 1), closeTo(14 * vh, eps));
    });

    test('indeks 0..n-1’e, ilerleme 0..1’e kırpılır; NaN ilerleme 0', () {
      expect(offsetAt(-3, 0.5), closeTo(2 * vh, eps));
      expect(offsetAt(99, 0.5), closeTo(13.5 * vh, eps));
      expect(offsetAt(1, -1), closeTo(4 * vh, eps));
      expect(offsetAt(1, 2), closeTo(5.5 * vh, eps));
      expect(offsetAt(1, double.nan), closeTo(4 * vh, eps));
    });

    test('boş liste ya da viewportHeight <= 0 → 0', () {
      expect(
        offsetFor(
          chapterIndex: 2,
          progress: 0.5,
          viewportHeight: vh,
          scrollLengths: [],
        ),
        0,
      );
      expect(offsetAt(2, 0.5, height: 0), 0);
      expect(offsetAt(2, 0.5, height: -10), 0);
    });

    test('gidiş-dönüş: offsetFor ∘ computeScrollState offset’i geri verir', () {
      for (var offset = 0.0; offset <= 14 * vh; offset += 137) {
        final state = stateAt(offset);
        expect(
          offsetAt(state.chapterIndex, state.progress),
          closeTo(offset, 1e-6),
          reason: 'offset $offset',
        );
      }
      final end = stateAt(14 * vh);
      expect(offsetAt(end.chapterIndex, end.progress), closeTo(14 * vh, 1e-6));
    });

    test('gidiş-dönüş: computeScrollState ∘ offsetFor bölümü ve ilerlemeyi '
        'geri verir; viewport yüksekliği değişse de (ekran döndü)', () {
      for (final height in [vh, 390.0, 844.0, 1280.0]) {
        for (var i = 0; i < lengths.length; i++) {
          for (final p in [0.0, 0.25, 0.5, 0.99]) {
            final state = computeScrollState(
              offset: offsetAt(i, p, height: height),
              viewportHeight: height,
              scrollLengths: lengths,
            );
            final reason = 'yükseklik $height, bölüm $i, ilerleme $p';
            expect(state.chapterIndex, i, reason: reason);
            expect(state.progress, closeTo(p, 1e-9), reason: reason);
          }
        }
        final last = computeScrollState(
          offset: offsetAt(lengths.length - 1, 1, height: height),
          viewportHeight: height,
          scrollLengths: lengths,
        );
        expectState(last, chapter: 5, progress: 1, global: 1);
      }
    });
  });

  group('ScrollState', () {
    test('progressFor: geçilen 1, aktif progress, gelecek 0', () {
      const state = ScrollState(
        chapterIndex: 2,
        progress: 0.3,
        globalProgress: 0.4,
      );
      expect(state.progressFor(0), 1);
      expect(state.progressFor(1), 1);
      expect(state.progressFor(2), closeTo(0.3, eps));
      expect(state.progressFor(3), 0);
      expect(state.progressFor(5), 0);
    });

    test('initial ve değer eşitliği', () {
      expect(ScrollState.initial.chapterIndex, 0);
      expect(ScrollState.initial.progress, 0);
      expect(ScrollState.initial.globalProgress, 0);
      const a = ScrollState(
        chapterIndex: 1,
        progress: 0.5,
        globalProgress: 0.2,
      );
      const b = ScrollState(
        chapterIndex: 1,
        progress: 0.5,
        globalProgress: 0.2,
      );
      const c = ScrollState(
        chapterIndex: 1,
        progress: 0.6,
        globalProgress: 0.2,
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
    });
  });

  group('ScrollProgress', () {
    // Test viewport'u sabit; içerik Track gibi sonda bir viewport boşluk taşır.
    const testVh = 500.0;
    const total = 14.0;

    /// [key] değişince yeni bir Scrollable (yeni pozisyon, offset 0) kurulur: yeniden kurulan Ray gibi.
    Widget host(
      ScrollController controller, {
      double height = testVh,
      Key? key,
    }) => Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: SizedBox(
          width: 300,
          height: height,
          child: CustomScrollView(
            key: key,
            controller: controller,
            slivers: [
              SliverToBoxAdapter(child: SizedBox(height: (total + 1) * height)),
            ],
          ),
        ),
      ),
    );

    test('scrollLengths değiştirilemez kopya, chapterCount', () {
      final source = List<double>.of(lengths);
      final progress = ScrollProgress(scrollLengths: source);
      source[0] = 99;
      expect(progress.scrollLengths, lengths);
      expect(progress.chapterCount, 6);
      expect(() => progress.scrollLengths.add(1), throwsUnsupportedError);
      progress.dispose();
    });

    test('controller yokken refresh ve animateToChapter no-op', () async {
      final progress = ScrollProgress(scrollLengths: lengths);
      progress.refresh();
      await progress.animateToChapter(3);
      expect(progress.value, ScrollState.initial);

      final orphan = ScrollController();
      progress.attachScroller(orphan);
      await progress.animateToChapter(3);
      expect(progress.value, ScrollState.initial);
      progress.dispose();
      orphan.dispose();
    });

    testWidgets('bağlanınca scroll konumunu yayınlar', (tester) async {
      final controller = ScrollController();
      final progress = ScrollProgress(scrollLengths: lengths);
      await tester.pumpWidget(host(controller));

      progress.attachScroller(controller);
      expect(progress.value, ScrollState.initial);

      controller.jumpTo(4.75 * testVh);
      expectState(
        progress.value,
        chapter: 1,
        progress: 0.5,
        global: 4.75 / total,
      );

      controller.jumpTo(total * testVh);
      expectState(progress.value, chapter: 5, progress: 1, global: 1);

      progress.dispose();
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    });

    testWidgets('animateToChapter navScroll süresince kaydırır', (
      tester,
    ) async {
      final controller = ScrollController();
      final progress = ScrollProgress(scrollLengths: lengths);
      await tester.pumpWidget(host(controller));
      progress.attachScroller(controller);

      final done = progress.animateToChapter(2);
      await tester.pump();
      await tester.pump(AppDurations.navScroll ~/ 2);
      expect(controller.offset, greaterThan(0));
      expect(controller.offset, lessThan(5.5 * testVh));
      await tester.pumpAndSettle();
      await done;
      expect(controller.offset, closeTo(5.5 * testVh, eps));
      expectState(progress.value, chapter: 2, progress: 0, global: 5.5 / total);

      final toLast = progress.animateToChapter(99);
      await tester.pumpAndSettle();
      await toLast;
      expect(controller.offset, closeTo(13 * testVh, eps));
      expect(progress.value.chapterIndex, 5);

      final toTop = progress.animateToChapter(-1);
      await tester.pumpAndSettle();
      await toTop;
      expect(controller.offset, closeTo(0, eps));
      expectState(progress.value, chapter: 0, progress: 0, global: 0);

      progress.dispose();
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    });

    testWidgets('detachScroller dinlemeyi bırakır', (tester) async {
      final controller = ScrollController();
      final progress = ScrollProgress(scrollLengths: lengths);
      await tester.pumpWidget(host(controller));
      progress.attachScroller(controller);
      controller.jumpTo(2 * testVh);
      final before = progress.value;

      progress.detachScroller();
      controller.jumpTo(10 * testVh);
      expect(progress.value, before);

      await progress.animateToChapter(0);
      await tester.pumpAndSettle();
      expect(controller.offset, closeTo(10 * testVh, eps));

      progress.dispose();
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    });

    testWidgets('yeni Ray bağlanınca restorePosition aynı bölüm ve ilerlemeye '
        'döner; offset yeni viewport yüksekliğiyle', (tester) async {
      final first = ScrollController();
      final progress = ScrollProgress(scrollLengths: lengths);
      await tester.pumpWidget(host(first, key: const ValueKey('ilk')));
      progress.attachScroller(first);
      first.jumpTo(4.75 * testVh);
      expectState(
        progress.value,
        chapter: 1,
        progress: 0.5,
        global: 4.75 / total,
      );

      // Ekran döndü: yeni Ray (yeni controller, offset 0, farklı yükseklik) eskisi ayrılmadan
      // bağlanır; eskisinin ayrılması yeni bağlantıyı koparmaz.
      const newVh = 300.0;
      final second = ScrollController();
      await tester.pumpWidget(
        host(second, height: newVh, key: const ValueKey('ikinci')),
      );
      expect(second.offset, 0);
      progress
        ..attachScroller(second)
        ..detachScroller(first)
        ..restorePosition();
      expect(second.offset, closeTo(4.75 * newVh, eps));
      expectState(
        progress.value,
        chapter: 1,
        progress: 0.5,
        global: 4.75 / total,
      );

      second.jumpTo(2 * newVh);
      expectState(progress.value, chapter: 0, progress: 0.5, global: 2 / total);

      // Saklı durum bir kez uygulanır.
      progress.restorePosition();
      expect(second.offset, closeTo(2 * newVh, eps));

      progress.dispose();
      await tester.pumpWidget(const SizedBox());
      first.dispose();
      second.dispose();
    });

    testWidgets(
      'pozisyon hazır değilken restorePosition bekler; Ray yerleşince '
      'uygular (Track akışı)',
      (tester) async {
        final controller = ScrollController();
        final progress = ScrollProgress(scrollLengths: lengths)
          ..value = const ScrollState(
            chapterIndex: 2,
            progress: 0.25,
            globalProgress: 6.5 / total,
          );
        progress
          ..attachScroller(controller)
          ..restorePosition();
        expect(progress.value.chapterIndex, 2);

        await tester.pumpWidget(host(controller));
        expect(controller.offset, 0);
        progress.restorePosition();
        expect(controller.offset, closeTo(6.5 * testVh, eps));
        expectState(
          progress.value,
          chapter: 2,
          progress: 0.25,
          global: 6.5 / total,
        );

        progress.dispose();
        await tester.pumpWidget(const SizedBox());
        controller.dispose();
      },
    );

    testWidgets(
      'holdPosition: aynı Ray\'da yükseklik değişince restorePosition '
      'aynı bölüm ve ilerlemeye döner; bir kez uygulanır',
      (tester) async {
        final controller = ScrollController();
        final progress = ScrollProgress(scrollLengths: lengths);
        await tester.pumpWidget(host(controller));
        progress.attachScroller(controller);
        controller.jumpTo(4.75 * testVh);

        // Track'in sırası: build'de sakla, yeni yükseklikte yerleş, kare sonrası geri yükle.
        progress.holdPosition();
        const newVh = 300.0;
        await tester.pumpWidget(host(controller, height: newVh));
        progress.restorePosition();
        expect(controller.offset, closeTo(4.75 * newVh, eps));
        expectState(
          progress.value,
          chapter: 1,
          progress: 0.5,
          global: 4.75 / total,
        );

        controller.jumpTo(2 * newVh);
        progress.restorePosition();
        expect(controller.offset, closeTo(2 * newVh, eps));

        progress.dispose();
        await tester.pumpWidget(const SizedBox());
        controller.dispose();
      },
    );

    testWidgets('holdPosition: bekleyen geri yüklemeyi ezmez; sayfa başında ve '
        'controller yokken no-op', (tester) async {
      final controller = ScrollController();
      final progress = ScrollProgress(scrollLengths: lengths);
      progress.holdPosition();
      await tester.pumpWidget(host(controller));
      progress.attachScroller(controller);

      // Sayfa başı saklanmaz: sonradan kaydırılan konum geri alınmaz.
      progress.holdPosition();
      controller.jumpTo(3 * testVh);
      progress.restorePosition();
      expect(controller.offset, closeTo(3 * testVh, eps));

      // İlk saklanan kalır; ikinci çağrı onu ezmez.
      progress.holdPosition();
      controller.jumpTo(10 * testVh);
      progress
        ..holdPosition()
        ..restorePosition();
      expect(controller.offset, closeTo(3 * testVh, eps));

      progress.dispose();
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    });

    testWidgets('ilk açılış (bölüm 0, ilerleme 0): restorePosition no-op', (
      tester,
    ) async {
      final controller = ScrollController();
      final progress = ScrollProgress(scrollLengths: lengths);
      await tester.pumpWidget(host(controller));
      progress.attachScroller(controller);
      controller.jumpTo(3 * testVh);
      progress.restorePosition();
      expect(controller.offset, closeTo(3 * testVh, eps));

      progress.dispose();
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    });

    testWidgets('detachScroller(başka controller) bağlı olanı ayırmaz', (
      tester,
    ) async {
      final controller = ScrollController();
      final other = ScrollController();
      final progress = ScrollProgress(scrollLengths: lengths);
      await tester.pumpWidget(host(controller));
      progress
        ..attachScroller(controller)
        ..detachScroller(other);
      controller.jumpTo(2 * testVh);
      expectState(progress.value, chapter: 0, progress: 0.5, global: 2 / total);

      progress.detachScroller(controller);
      controller.jumpTo(10 * testVh);
      expect(progress.value.chapterIndex, 0);

      progress.dispose();
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
      other.dispose();
    });

    testWidgets('dispose controller’ı dispose etmez', (tester) async {
      final controller = ScrollController();
      final progress = ScrollProgress(scrollLengths: lengths);
      await tester.pumpWidget(host(controller));
      progress.attachScroller(controller);

      progress.dispose();
      controller.jumpTo(3 * testVh);
      expect(controller.offset, closeTo(3 * testVh, eps));
      void noop() {}
      controller
        ..addListener(noop)
        ..removeListener(noop);

      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    });
  });
}
