import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portfolio_scrollytelling/chapters/projects_chapter.dart';
import 'package:portfolio_scrollytelling/chapters/text_chapter.dart';
import 'package:portfolio_scrollytelling/story/scroll_progress.dart';
import 'package:portfolio_scrollytelling/story/story.dart';
import 'package:portfolio_scrollytelling/theme/theme.dart';
import 'package:portfolio_scrollytelling/widgets/index_label.dart';
import 'package:portfolio_scrollytelling/widgets/label_text.dart';
import 'package:portfolio_scrollytelling/widgets/pill_button.dart';
import 'package:portfolio_scrollytelling/widgets/reveal_text.dart';
import 'package:portfolio_scrollytelling/widgets/step_counter.dart';

import 'helpers/inter_font.dart';
import 'helpers/pump_chapter.dart';

/// Text ve Projects bölümleri: aktif proje ve panel açıklığı hesabı, tıklamalar (AGENTS.md §11.4)
/// ve iki tasarım boyutunda taşmasız düzen.
void main() {
  const desktop = Size(1440, 900);
  // Masaüstü düzeninin dar ve kısa ucu: ölçek genişlikten gelir, açık panel en dar haliyle.
  const smallDesktop = Size(1100, 700);
  const mobile = Size(390, 844);

  // Gerçek Inter: mobil sığma test fontuyla yanlış ölçülür.
  setUpAll(loadInterFont);

  const textChapter = Chapter(
    id: 'ben-kimim',
    title: 'Ben kimim?',
    type: ChapterType.text,
    scrollLength: 1,
    body: 'Mobil ve web için **Flutter** ile ürün geliştiriyorum.',
  );

  const projectsChapter = Chapter(
    id: 'projeler',
    title: 'Projeler',
    type: ChapterType.projects,
    scrollLength: 1,
    projects: [
      Project(
        name: 'Birinci',
        description: 'Ne yapar, kim kullanır, neyi çözer — iki cümle.',
        tags: ['Flutter', 'Firebase'],
        url: 'https://example.com/bir',
      ),
      Project(name: 'İkinci', description: 'İkinci açıklama.', tags: ['Dart']),
      Project(
        name: 'Üçüncü',
        description: 'Üçüncü açıklama.',
        url: 'https://example.com/uc',
      ),
    ],
  );

  late ScrollProgress scrollProgress;
  late List<String> openedUrls;

  setUp(() {
    scrollProgress = ScrollProgress(scrollLengths: const [1, 1, 1]);
    openedUrls = [];
  });

  tearDown(() => scrollProgress.dispose());

  /// Bölüm 0'ı aktif yapıp ilerlemesini [progress]'e ayarlar.
  void setProgress(double progress) => scrollProgress.value = ScrollState(
    chapterIndex: 0,
    progress: progress,
    globalProgress: progress / 3,
  );

  /// Verilen projelerle bölüm.
  Widget projectsOf(List<Project> list) => ProjectsChapter(
    chapter: Chapter(
      id: 'projeler',
      title: 'Projeler',
      type: ChapterType.projects,
      scrollLength: 1,
      projects: list,
    ),
    index: 0,
    scrollProgress: scrollProgress,
    openUrl: openedUrls.add,
  );

  Widget projects() => projectsOf(projectsChapter.projects);

  /// Tek projelik bölüm; link pill'lerini ayrı ayrı denemek için (panel hep tam açık).
  Widget singleProject(Project project) => projectsOf([project]);

  /// Proje adının durduğu panel kutusu: adın en yakın `Container` atası.
  Finder panelOf(String name) => find
      .ancestor(of: find.text(name), matching: find.byType(Container))
      .first;

  /// Açıklama paragrafı kırpılmamış: satır sınırı aşılmamış ve verilen yükseklik metnin o
  /// genişlikteki doğal yüksekliğinden az değil.
  void expectDescriptionFits(WidgetTester tester, String description) {
    final paragraph = tester.renderObject<RenderParagraph>(
      find.text(description),
    );
    expect(paragraph.didExceedMaxLines, isFalse);
    expect(
      paragraph.size.height,
      greaterThanOrEqualTo(
        paragraph.getMaxIntrinsicHeight(paragraph.size.width),
      ),
      reason: 'açıklama verilen yüksekliğe sığmalı, kırpılmamalı',
    );
  }

  group('activeProjectIndex', () {
    test('başta ilk proje', () {
      expect(activeProjectIndex(progress: 0, count: 3), 0);
    });

    test('1/3 eşiğini geçince ikinci proje', () {
      expect(activeProjectIndex(progress: 0.34, count: 3), 1);
    });

    test('sona yakın son proje', () {
      expect(activeProjectIndex(progress: 0.99, count: 3), 2);
    });

    test('progress 1 son projede kalır, taşmaz', () {
      expect(activeProjectIndex(progress: 1, count: 3), 2);
    });

    test('proje yoksa 0', () {
      expect(activeProjectIndex(progress: 0.5, count: 0), 0);
    });

    test('negatif ve NaN progress 0', () {
      expect(activeProjectIndex(progress: -0.1, count: 3), 0);
      expect(activeProjectIndex(progress: double.nan, count: 3), 0);
    });
  });

  group('panelOpenness', () {
    /// Bütün panellerin açıklığı, sırayla.
    List<double> all(double progress, {int count = 3}) => [
      for (var i = 0; i < count; i++)
        panelOpenness(progress: progress, index: i, count: count),
    ];

    test('başta ilk panel açık, diğerleri kapalı', () {
      expect(all(0), [1, 0, 0]);
    });

    test('dilim ortasında aktif panel 1, diğerleri 0', () {
      expect(all(0.5 / 3), [1, 0, 0]);
      expect(all(1.5 / 3), [0, 1, 0]);
      expect(all(2.5 / 3), [0, 0, 1]);
    });

    test('geçiş: dilimin son çeyreğinde iki panel doğrusal, toplam 1', () {
      // p = 0.75: geçiş başlar, ilk panel hâlâ tam açık.
      expect(all(0.75 / 3), [1, 0, 0]);
      // p = 0.875: geçişin ortası.
      final mid = all(0.875 / 3);
      expect(mid[0], closeTo(0.5, 1e-9));
      expect(mid[1], closeTo(0.5, 1e-9));
      expect(mid[2], 0);
      // p = 1.95: ikinciden üçüncüye geçişin %80'i.
      final late = all(1.95 / 3);
      expect(late[0], 0);
      expect(late[1], closeTo(0.2, 1e-9));
      expect(late[2], closeTo(0.8, 1e-9));
    });

    test('progress 1 → son panel açık kalır', () {
      expect(all(1), [0, 0, 1]);
    });

    test('NaN, negatif progress ve proje yok → ilk panel 1', () {
      expect(all(double.nan), [1, 0, 0]);
      expect(all(-0.2), [1, 0, 0]);
      expect(panelOpenness(progress: 0.5, index: 0, count: 0), 1);
      expect(panelOpenness(progress: 0.5, index: 1, count: 0), 0);
    });

    test('her progress\'te açıklıklar 0..1 arası, toplamı 1', () {
      for (var count = 1; count <= 5; count++) {
        for (var step = 0; step <= 200; step++) {
          final progress = step / 200;
          final values = all(progress, count: count);
          final where = 'count $count, progress $progress';
          for (final value in values) {
            expect(value, inInclusiveRange(0, 1), reason: where);
          }
          expect(
            values.fold<double>(0, (sum, value) => sum + value),
            closeTo(1, 1e-9),
            reason: where,
          );
        }
      }
    });
  });

  group('TextChapter', () {
    Widget text() => TextChapter(
      chapter: textChapter,
      index: 0,
      scrollProgress: scrollProgress,
    );

    /// RevealText'in kelime span'leri (Text.rich kökünün çocukları).
    List<InlineSpan> wordSpans(WidgetTester tester) =>
        (tester
                    .widget<Text>(
                      find.descendant(
                        of: find.byType(RevealText),
                        matching: find.byType(Text),
                      ),
                    )
                    .textSpan!
                as TextSpan)
            .children!;

    testWidgets('etiket "— BAŞLIK", cümle tek RichText', (tester) async {
      await pumpChapter(tester, text());
      expect(find.text('— BEN KİMİM?'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(RevealText),
          matching: find.byType(RichText),
        ),
        findsOneWidget,
      );
      expect(wordSpans(tester), hasLength(8));
    });

    testWidgets('progress ile kelimeler dolar, vurgulu kelime accent olur', (
      tester,
    ) async {
      await pumpChapter(tester, text());
      expect(
        wordSpans(tester).first.style?.color,
        isSameColorAs(AppColors.textDim),
      );
      setProgress(1);
      await tester.pump();
      expect(
        wordSpans(tester).first.style?.color,
        isSameColorAs(AppColors.text),
      );
      expect(
        wordSpans(tester)[4].style?.color,
        isSameColorAs(AppColors.accent),
      );
    });

    for (final size in [desktop, mobile]) {
      testWidgets('${size.width.toInt()}: taşma yok', (tester) async {
        await pumpChapter(tester, text(), size: size);
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('ProjectsChapter', () {
    final names = [for (final p in projectsChapter.projects) p.name];
    final descriptions = [
      for (final p in projectsChapter.projects) p.description,
    ];

    /// Üç projede, panel [from]'dan sonrakine geçerken sonraki panelin açıklığı [next] olduğu
    /// progress (geçiş, dilimin son çeyreği).
    double blendProgress(int from, double next) {
      final progress = (from + 0.75 + 0.25 * next) / 3;
      expect(
        panelOpenness(progress: progress, index: from + 1, count: 3),
        closeTo(next, 1e-9),
      );
      return progress;
    }

    for (final size in [desktop, mobile]) {
      final w = size.width.toInt();
      final isMobile = AppBreakpoints.isMobileWidth(size.width);

      /// Panelin açılma eksenindeki boyu: masaüstünde genişlik, mobilde yükseklik.
      double extentOf(WidgetTester tester, String name) {
        final panel = tester.getSize(panelOf(name));
        return isMobile ? panel.height : panel.width;
      }

      testWidgets('$w: bütün proje adları aynı anda ağaçta, yalnızca aktif '
          'panelin açıklaması görünür', (tester) async {
        await pumpChapter(tester, projects(), size: size);
        expect(tester.takeException(), isNull);
        for (final name in names) {
          expect(find.text(name), findsOneWidget);
        }
        expect(find.text(descriptions[0]), findsOneWidget);
        expect(find.text(descriptions[1]), findsNothing);
        expect(find.text(descriptions[2]), findsNothing);
      });

      testWidgets('$w: aktif panelin linki openUrl\'i url ile çağırır; kapalı '
          'panelin linki kurulmaz', (tester) async {
        await pumpChapter(tester, projects(), size: size);
        // Üçüncü de url'li ama paneli kapalı: tek "Projeyi aç" Birinci'nin.
        expect(find.textContaining(AppStrings.openProject), findsOneWidget);
        await tester.tap(find.textContaining(AppStrings.openProject));
        expect(openedUrls, ['https://example.com/bir']);
      });

      testWidgets('$w: progress ilerleyince aktif panel değişir ve en büyük o '
          'olur; animasyonsuz, tek karede', (tester) async {
        await pumpChapter(tester, projects(), size: size);
        expect(
          extentOf(tester, 'Birinci'),
          greaterThan(extentOf(tester, 'İkinci')),
        );

        setProgress(0.5);
        await tester.pump();
        expect(tester.hasRunningAnimations, isFalse);
        expect(find.text(descriptions[1]), findsOneWidget);
        expect(find.text(descriptions[0]), findsNothing);
        expect(find.text('02 / 03'), findsOneWidget);
        final open = extentOf(tester, 'İkinci');
        expect(open, greaterThan(extentOf(tester, 'Birinci')));
        expect(open, greaterThan(extentOf(tester, 'Üçüncü')));
        expect(
          extentOf(tester, 'Birinci'),
          closeTo(extentOf(tester, 'Üçüncü'), 0.01),
          reason: 'kapalı paneller eşit',
        );
      });

      testWidgets('$w: yarıdan az açık panelin linki tıklanmaz, yarıyı geçince '
          'tıklanır', (tester) async {
        // Masaüstünde "Projeyi aç" alt şeridin sağ ucunda, yarı açık panelde kırpılır; eşik orada
        // sol sütundaki ilk link satırıyla denenir (dört link → link satırları).
        final rowLinks = [
          for (var i = 1; i <= 4; i++)
            ContactLink(label: 'Site $i', url: 'https://example.com/site$i'),
        ];
        await pumpChapter(
          tester,
          isMobile
              ? projects()
              : projectsOf([
                  ...projectsChapter.projects.take(2),
                  Project(
                    name: 'Üçüncü',
                    description: 'Üçüncü açıklama.',
                    links: rowLinks,
                  ),
                ]),
          size: size,
        );
        final link = isMobile
            ? find.textContaining(AppStrings.openProject)
            : find.text(rowLinks.first.label);

        setProgress(blendProgress(1, 0.45));
        await tester.pump();
        // Birinci kapalı (kurulmaz), İkinci'nin linki yok: bu Üçüncü'nün linki.
        expect(link, findsOneWidget);
        expect(
          tester.getRect(panelOf('Üçüncü')).contains(tester.getCenter(link)),
          isTrue,
          reason: 'link panelin görünen alanında',
        );
        await tester.tap(link, warnIfMissed: false);
        expect(openedUrls, isEmpty);

        setProgress(blendProgress(1, 0.55));
        await tester.pump();
        await tester.tap(link);
        expect(openedUrls, [
          isMobile ? 'https://example.com/uc' : rowLinks.first.url,
        ]);
      });

      testWidgets('$w: geçişte açık yüz tam açık ölçüde dizilir, metin '
          'yeniden sarılmaz', (tester) async {
        await pumpChapter(tester, projects(), size: size);

        /// Üçüncü panelin açık yüzündeki içerik sütunu.
        Size detailsSize() => tester.getSize(
          find
              .descendant(
                of: find.descendant(
                  of: panelOf('Üçüncü'),
                  matching: find.byType(OverflowBox),
                ),
                matching: find.byType(Column),
              )
              .first,
        );

        setProgress(1);
        await tester.pump();
        final full = detailsSize();

        setProgress(blendProgress(1, 0.45));
        await tester.pump();
        final partial = detailsSize();
        expect(partial.width, closeTo(full.width, 0.01));
        expect(partial.height, closeTo(full.height, 0.01));
        expect(
          extentOf(tester, 'Üçüncü'),
          lessThan(isMobile ? full.height : full.width),
          reason: 'panel içerikten küçük: içerik kırpılır, sarılmaz',
        );
      });

      testWidgets('$w: geçişlerde ve uçlarda taşma yok', (tester) async {
        await pumpChapter(tester, projects(), size: size);
        for (final progress in [
          0.0,
          blendProgress(0, 0.5),
          0.5,
          blendProgress(1, 0.3),
          0.95,
          1.0,
        ]) {
          setProgress(progress);
          await tester.pump();
          expect(tester.takeException(), isNull, reason: 'progress $progress');
        }
      });
    }

    testWidgets('masaüstü: paneller yan yana, nav\'ın altında başlar', (
      tester,
    ) async {
      await pumpChapter(tester, projects());
      final rects = [for (final name in names) tester.getRect(panelOf(name))];
      expect(rects[0].right, lessThan(rects[1].left));
      expect(rects[1].right, lessThan(rects[2].left));
      for (final rect in rects) {
        expect(rect.top, closeTo(rects[0].top, 0.01));
        expect(rect.height, closeTo(rects[0].height, 0.01));
      }
      expect(rects[0].top, greaterThan(AppSizes.navHeight));
    });

    testWidgets('mobil: paneller alt alta, sohbet pill\'inin altında başlar; '
        'kapalı panel sabit yükseklikte', (tester) async {
      await pumpChapter(tester, projects(), size: mobile);
      final rects = [for (final name in names) tester.getRect(panelOf(name))];
      // Sağ üstteki sohbet pill'i gutter içinde, buton yüksekliğinde: ilk panele binmez.
      expect(
        rects[0].top,
        greaterThanOrEqualTo(AppSpacing.gutter + AppSizes.buttonHeight),
      );
      expect(rects[0].bottom, lessThan(rects[1].top));
      expect(rects[1].bottom, lessThan(rects[2].top));
      for (final rect in rects) {
        expect(rect.left, closeTo(rects[0].left, 0.01));
        expect(rect.width, closeTo(rects[0].width, 0.01));
      }
      expect(
        rects[1].height,
        closeTo(AppSizes.projectPanelCollapsedHeight, 0.01),
      );
      expect(
        rects[2].height,
        closeTo(AppSizes.projectPanelCollapsedHeight, 0.01),
      );
    });

    testWidgets('adım sayacı progress\'i doğrudan çizer', (tester) async {
      await pumpChapter(tester, projects());
      setProgress(0.2);
      await tester.pump();
      final counter = tester.widget<StepCounter>(find.byType(StepCounter));
      expect(counter.current, 1);
      expect(counter.total, 3);
      expect(counter.progress, 0.2);
    });

    group('links', () {
      const appStore = ContactLink(
        label: 'App Store',
        url: 'https://apps.example.com/bir',
      );
      const googlePlay = ContactLink(
        label: 'Google Play',
        url: 'https://play.example.com/bir',
      );

      for (final size in [desktop, mobile]) {
        testWidgets('${size.width.toInt()}: url yok, iki link → iki pill, '
            'her biri kendi url\'i ile', (tester) async {
          await pumpChapter(
            tester,
            singleProject(
              const Project(
                name: 'Birinci',
                description: 'Kısa açıklama.',
                tags: ['Flutter'],
                links: [appStore, googlePlay],
              ),
            ),
            size: size,
          );
          expect(tester.takeException(), isNull);
          expect(find.byType(PillButton), findsNWidgets(2));
          expect(find.textContaining(AppStrings.openProject), findsNothing);
          await tester.tap(find.text('Google Play →'));
          await tester.tap(find.text('App Store →'));
          expect(openedUrls, [googlePlay.url, appStore.url]);
        });
      }

      testWidgets('url + bir link → "Projeyi aç" ve link pill\'i birlikte', (
        tester,
      ) async {
        await pumpChapter(
          tester,
          singleProject(
            const Project(
              name: 'Birinci',
              description: 'Kısa açıklama.',
              url: 'https://example.com/bir',
              links: [appStore],
            ),
          ),
        );
        expect(find.byType(PillButton), findsNWidgets(2));
        final openProject = find.text('${AppStrings.openProject} →');
        final store = find.text('App Store →');
        expect(
          tester.getCenter(openProject).dx,
          lessThan(tester.getCenter(store).dx),
          reason: '"Projeyi aç" önce gelir',
        );
        await tester.tap(store);
        await tester.tap(openProject);
        expect(openedUrls, [appStore.url, 'https://example.com/bir']);
      });

      group('3\'ten fazla link → link satırı (masaüstü) / mini pill (mobil)', () {
        const manyLinks = [
          ContactLink(label: 'Kulüp Sitesi', url: 'https://example.com/1'),
          ContactLink(label: 'Ajans', url: 'https://example.com/2'),
          ContactLink(label: 'Mimarlık Ofisi', url: 'https://example.com/3'),
          ContactLink(label: 'Bağ Evi Oteli', url: 'https://example.com/4'),
          ContactLink(
            label: 'Araç Kiralama Firması',
            url: 'https://example.com/5',
          ),
          ContactLink(label: 'Mağaza Bir', url: 'https://example.com/6'),
          ContactLink(label: 'Spor Mağazası', url: 'https://example.com/7'),
          ContactLink(label: 'Kutu Atölye', url: 'https://example.com/8'),
        ];
        const description =
            'Kurumlar, ajanslar ve küçük işletmeler için tasarlayıp '
            'geliştirdiğim, hızlı açılan ve arama motorlarında rahat bulunan '
            'tanıtım siteleri.';
        const compactProject = Project(
          name: 'Siteler',
          description: description,
          tags: ['Next.js', 'Web'],
          links: manyLinks,
        );

        /// Kompakt linkin ekranda görünen yazısı: Türkçe BÜYÜK HARF + ok.
        String compactText(ContactLink link) => '${upperTr(link.label)} →';

        testWidgets('1440: 8 link → iki sütunlu link satırları, mini pill yok; '
            'her satır kendi url\'i ile; taşma yok, açıklama kırpılmaz', (
          tester,
        ) async {
          await pumpChapter(tester, singleProject(compactProject));
          expect(tester.takeException(), isNull);
          expect(find.byType(PillButton), findsNothing);
          for (final link in manyLinks) {
            expect(find.text(compactText(link)), findsNothing);
            expect(find.text(link.label), findsOneWidget);
            await tester.tap(find.text(link.label));
          }
          expect(openedUrls, [for (final link in manyLinks) link.url]);
          // Izgara: linkler sırayla sol, sağ, sol…
          Rect rowOf(int i) => tester.getRect(find.text(manyLinks[i].label));
          expect(rowOf(1).top, closeTo(rowOf(0).top, 0.01));
          expect(rowOf(0).right, lessThan(rowOf(1).left));
          expect(rowOf(2).left, closeTo(rowOf(0).left, 0.01));
          expect(rowOf(2).top, greaterThan(rowOf(0).bottom));
          expectDescriptionFits(tester, description);
        });

        testWidgets('1440: link satırları + url → sağda yalnızca dolu "Projeyi '
            'aç"; öne çıkanlar çizilmez', (tester) async {
          await pumpChapter(
            tester,
            singleProject(
              const Project(
                name: 'Siteler',
                description: description,
                highlights: ['Öne çıkan madde'],
                url: 'https://example.com/siteler',
                links: manyLinks,
              ),
            ),
          );
          expect(tester.takeException(), isNull);
          expect(find.text('Öne çıkan madde'), findsNothing);
          expect(find.text(manyLinks.last.label), findsOneWidget);
          final button = tester.widget<PillButton>(find.byType(PillButton));
          expect(button.label, AppStrings.openProject);
          expect(button.filled, isTrue);
        });

        testWidgets('390: 8 link → mini pill, her biri kendi url\'i ile; taşma '
            'yok, açıklama kırpılmaz', (tester) async {
          await pumpChapter(
            tester,
            singleProject(compactProject),
            size: mobile,
          );
          expect(tester.takeException(), isNull);
          expect(find.byType(PillButton), findsNothing);
          for (final link in manyLinks) {
            expect(find.text(compactText(link)), findsOneWidget);
            await tester.tap(find.text(compactText(link)));
          }
          expect(openedUrls, [for (final link in manyLinks) link.url]);
          expectDescriptionFits(tester, description);
        });

        for (final size in [desktop, smallDesktop, mobile]) {
          final isMobile = AppBreakpoints.isMobileWidth(size.width);
          testWidgets(
            '${size.width.toInt()}: sekiz linkli, uzun açıklamalı kart '
            'dört projelik bölümde açıkken kırpılmadan sığar',
            (tester) async {
              // Dört projenin üçüncüsü: açık panelin boyu proje sayısına bağlı.
              const webDescription =
                  'Bir ajansta müşteriler için Next.js ile geliştirdiğim 8 '
                  'kurumsal site. Dernekten mimarlığa, gıdadan ulaşıma '
                  've turizme farklı sektörler.';
              const webLabels = [
                'Dernek Sitesi',
                'Ajans',
                'Mimarlık Ofis',
                'Bağ Evi Sitesi',
                'Araç Kiralama Bir',
                'Mağaza Bir',
                'Spor Salonu Üç',
                'Site Dört',
              ];
              await pumpChapter(
                tester,
                projectsOf([
                  const Project(name: 'Birinci', description: 'Kısa açıklama.'),
                  const Project(name: 'İkinci', description: 'Kısa açıklama.'),
                  Project(
                    name: 'Web siteleri',
                    description: webDescription,
                    tags: const ['Next.js', 'Web'],
                    links: [
                      for (final (i, label) in webLabels.indexed)
                        ContactLink(
                          label: label,
                          url: 'https://example.com/$i',
                        ),
                    ],
                  ),
                  const Project(
                    name: 'Dördüncü',
                    description: 'Kısa açıklama.',
                  ),
                ]),
                size: size,
              );
              setProgress(2.5 / 4);
              await tester.pump();
              expect(tester.takeException(), isNull);
              expect(find.byType(PillButton), findsNothing);
              for (final label in webLabels) {
                expect(
                  find.text(isMobile ? '${upperTr(label)} →' : label),
                  findsOneWidget,
                );
              }
              expectDescriptionFits(tester, webDescription);
            },
          );
        }

        testWidgets('tam 3 link → üç PillButton (eşik sınırı)', (tester) async {
          final threeLinks = manyLinks.sublist(0, 3);
          await pumpChapter(
            tester,
            singleProject(
              Project(
                name: 'Siteler',
                description: 'Kısa açıklama.',
                links: threeLinks,
              ),
            ),
          );
          expect(tester.takeException(), isNull);
          expect(find.byType(PillButton), findsNWidgets(3));
          expect(find.text(compactText(threeLinks.first)), findsNothing);
          expect(find.text('${threeLinks.first.label} →'), findsOneWidget);
        });

        for (final size in [desktop, mobile]) {
          testWidgets('${size.width.toInt()}: semantics: link satırı / mini '
              'pill oksuz label okunan buton', (tester) async {
            final handle = tester.ensureSemantics();
            await pumpChapter(
              tester,
              singleProject(compactProject),
              size: size,
            );
            final link = manyLinks.first;
            final node = find.bySemanticsLabel(link.label);
            expect(node, findsOneWidget);
            expect(find.bySemanticsLabel(compactText(link)), findsNothing);
            expect(find.bySemanticsLabel('${link.label} →'), findsNothing);
            expect(
              tester.getSemantics(node),
              isSemantics(
                label: link.label,
                isButton: true,
                hasTapAction: true,
              ),
            );
            handle.dispose();
          });
        }
      });

      testWidgets('url ve links yok → pill de link satırı da yok', (
        tester,
      ) async {
        await pumpChapter(
          tester,
          singleProject(
            const Project(name: 'Birinci', description: 'Kısa açıklama.'),
          ),
        );
        expect(find.byType(PillButton), findsNothing);
        expect(
          find.descendant(
            of: find.byType(ProjectsChapter),
            matching: find.byType(Wrap),
          ),
          findsNothing,
        );
      });
    });

    group('açık panel: öne çıkanlar ve alt şerit', () {
      // Öne çıkanlı, iki mağaza linkli kart. Uzun açıklama (~200 karakter) katılımcının daha uzun
      // yazdığı durumu dener.
      const description =
          'Kullanıcılar için örnek takip uygulaması: ekipteki herkesin işleri '
          'tek ekranda, avucunda. Mobil uygulamayı baştan sona ben '
          'geliştirdim.';
      const longDescription =
          'Kullanıcılar için örnek takip uygulaması: ekipteki herkesin işleri '
          'tek ekranda, avucunda. Mobil uygulamayı baştan sona ben '
          'geliştirdim; mağaza yayınını, bildirimleri ve bakımını da ben '
          'yürütüyorum.';
      const highlights = [
        'Davet kodu ya da e-posta ile saniyeler içinde gir',
        'Projeyi adım adım gez: plan, görevler, notlar, dosya',
        'Tek görsel tam ekran ya da dörtlü ızgara',
        'Son çalıştığın projeler, tek dokunuşta',
      ];
      const appStore = ContactLink(
        label: 'App Store',
        url: 'https://apps.example.com/ornek',
      );
      const googlePlay = ContactLink(
        label: 'Google Play',
        url: 'https://play.example.com/ornek',
      );

      /// Bölümdeki gibi dört projenin ilki, açık: açık panelin genişliği proje sayısına bağlı.
      Widget sampleApp({String text = description}) => projectsOf([
        Project(
          name: 'Örnek Proje',
          description: text,
          highlights: highlights,
          tags: const ['Flutter', 'iOS', 'Android'],
          links: const [appStore, googlePlay],
        ),
        const Project(name: 'İkinci', description: 'Kısa açıklama.'),
        const Project(name: 'Üçüncü', description: 'Kısa açıklama.'),
        const Project(name: 'Dördüncü', description: 'Kısa açıklama.'),
      ]);

      Finder panel() => panelOf('Örnek Proje');

      /// Açık panelin iç yüksekliği: kenarlık ve `lg` iç boşluk düşülür.
      double innerHeight(WidgetTester tester) =>
          tester.getRect(panel()).height -
          2 * (AppSizes.borderWidth + AppSpacing.lg);

      for (final size in [desktop, smallDesktop]) {
        final w = size.width.toInt();

        testWidgets('$w: dört öne çıkan madde sırayla, numaraları 01..04', (
          tester,
        ) async {
          await pumpChapter(tester, sampleApp(), size: size);
          expect(tester.takeException(), isNull);
          Rect? previous;
          for (final (i, text) in highlights.indexed) {
            final row = tester.getRect(find.text(text));
            final number = find.descendant(
              of: panel(),
              matching: find.text(twoDigits(i + 1)),
            );
            expect(number, findsOneWidget);
            final numberRect = tester.getRect(number);
            expect(numberRect.right, lessThanOrEqualTo(row.left + 0.01));
            expect(numberRect.center.dy, inInclusiveRange(row.top, row.bottom));
            if (previous != null) {
              expect(row.top, greaterThan(previous.bottom), reason: text);
            }
            previous = row;
          }
        });

        testWidgets('$w: iki link alt şeritte, sağda; ilk pill dolu, tag\'ler '
            'solda aynı satırda', (tester) async {
          await pumpChapter(tester, sampleApp(), size: size);
          PillButton pill(ContactLink link) => tester.widget<PillButton>(
            find.ancestor(
              of: find.text('${link.label} →'),
              matching: find.byType(PillButton),
            ),
          );
          expect(find.byType(PillButton), findsNWidgets(2));
          expect(pill(appStore).filled, isTrue);
          expect(pill(googlePlay).filled, isFalse);

          final panelRect = tester.getRect(panel());
          final store = tester.getRect(find.text('${appStore.label} →'));
          final play = tester.getRect(find.text('${googlePlay.label} →'));
          final tag = tester.getRect(find.text(upperTr('Flutter')));
          final lastHighlight = tester.getRect(find.text(highlights.last));
          expect(store.right, lessThan(play.left), reason: 'sırayla');
          expect(store.left, greaterThan(panelRect.center.dx), reason: 'sağda');
          expect(tag.right, lessThan(panelRect.center.dx), reason: 'solda');
          expect(tag.center.dy, closeTo(store.center.dy, 0.5));
          expect(store.top, greaterThan(lastHighlight.bottom));

          await tester.tap(find.text('${googlePlay.label} →'));
          await tester.tap(find.text('${appStore.label} →'));
          expect(openedUrls, [googlePlay.url, appStore.url]);
        });

        testWidgets('$w: içerik panelin iç yüksekliğinin en az %80\'ine '
            'yayılır', (tester) async {
          await pumpChapter(tester, sampleApp(), size: size);
          final top = tester
              .getRect(
                find.descendant(of: panel(), matching: find.byType(IndexLabel)),
              )
              .top;
          final pills = find.descendant(
            of: panel(),
            matching: find.byType(PillButton),
          );
          final bottom = [
            for (var i = 0; i < pills.evaluate().length; i++)
              tester.getRect(pills.at(i)).bottom,
          ].reduce(math.max);
          expect(
            (bottom - top) / innerHeight(tester),
            greaterThanOrEqualTo(0.8),
          );
        });

        for (final text in [description, longDescription]) {
          testWidgets('$w×${size.height.toInt()}: ${text.length} karakterlik '
              'açıklamayla taşma yok, açıklama kırpılmaz', (tester) async {
            await pumpChapter(tester, sampleApp(text: text), size: size);
            expect(tester.takeException(), isNull);
            expectDescriptionFits(tester, text);
            for (final highlight in highlights) {
              expect(find.text(highlight), findsOneWidget);
            }
          });
        }
      }

      testWidgets('390: öne çıkanlar mobilde çizilmez; taşma yok', (
        tester,
      ) async {
        await pumpChapter(tester, sampleApp(), size: mobile);
        expect(tester.takeException(), isNull);
        expect(find.text(description), findsOneWidget);
        for (final highlight in highlights) {
          expect(find.text(highlight), findsNothing);
        }
      });
    });
  });
}
