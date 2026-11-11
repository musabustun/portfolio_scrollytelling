import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portfolio_scrollytelling/chapters/contact_chapter.dart';
import 'package:portfolio_scrollytelling/story/story.dart';
import 'package:portfolio_scrollytelling/theme/theme.dart';
import 'package:portfolio_scrollytelling/widgets/label_text.dart';
import 'package:portfolio_scrollytelling/widgets/pill_button.dart';

import 'helpers/inter_font.dart';
import 'helpers/pump_chapter.dart';

/// İletişim bölümü: `body` bölme, büyük e-posta, link pill'leri, footer; tıklamalar gerçek olayla
/// (AGENTS.md §11.4) ve iki tasarım boyutunda taşmasız düzen.
void main() {
  const desktop = Size(1440, 900);
  const mobile = Size(390, 844);

  // Gerçek Inter: mobil sığma test fontuyla yanlış ölçülür.
  setUpAll(loadInterFont);

  const headline = 'Birlikte bir şey yapalım.';
  const detail =
      'Freelance iş, konuşma ya da eğitim daveti için yaz; sohbet de hep açık.';

  /// İki satırlı gövde, bir e-posta, üç link.
  const contactChapter = Chapter(
    id: 'iletisim',
    title: 'İletişim',
    type: ChapterType.contact,
    scrollLength: 1,
    body: '$headline\n$detail',
    links: [
      ContactLink(label: 'E-posta', url: 'mailto:ben@example.com'),
      ContactLink(label: 'GitHub', url: 'https://github.com/ben'),
      ContactLink(label: 'LinkedIn', url: 'https://www.linkedin.com/in/ben/'),
      ContactLink(label: 'Instagram', url: 'https://www.instagram.com/ben/'),
    ],
  );

  const meta = Meta(
    title: 'Site',
    owner: 'Uzun Bir Site Sahibi Adı',
    tagline: 'Kaydır.',
  );

  late List<String> openedUrls;
  late int backToTopTaps;

  setUp(() {
    openedUrls = [];
    backToTopTaps = 0;
  });

  Widget contact([Chapter chapter = contactChapter]) => ContactChapter(
    chapter: chapter,
    meta: meta,
    openUrl: openedUrls.add,
    onBackToTop: () => backToTopTaps++,
  );

  /// [contactChapter] ile aynı başlık ve gövde, farklı linkler.
  Chapter withLinks(List<ContactLink> links) => Chapter(
    id: contactChapter.id,
    title: contactChapter.title,
    type: ChapterType.contact,
    scrollLength: 1,
    body: contactChapter.body,
    links: links,
  );

  group('splitContactBody', () {
    test('tek satır: başlık, detay yok', () {
      final split = splitContactBody('Yaz bana.', fallback: 'İletişim');
      expect(split.headline, 'Yaz bana.');
      expect(split.detail, isNull);
    });

    test('iki satır: ilk satır başlık, ikincisi detay', () {
      final split = splitContactBody('$headline\n$detail', fallback: 'X');
      expect(split.headline, headline);
      expect(split.detail, detail);
    });

    test('ikiden fazla satır: ilk satırdan sonrası tek detay', () {
      final split = splitContactBody('Bir\nİki\nÜç', fallback: 'X');
      expect(split.headline, 'Bir');
      expect(split.detail, 'İki\nÜç');
    });

    test('boş, yalnızca boşluk ya da null: başlık fallback, detay yok', () {
      for (final body in [null, '', '  \n ']) {
        final split = splitContactBody(body, fallback: 'İletişim');
        expect(split.headline, 'İletişim');
        expect(split.detail, isNull);
      }
    });

    test('ikinci satır boşsa detay yok', () {
      final split = splitContactBody('Yaz bana.\n   ', fallback: 'X');
      expect(split.headline, 'Yaz bana.');
      expect(split.detail, isNull);
    });
  });

  group('ContactChapter', () {
    testWidgets('etiket, başlık ve detay görünür', (tester) async {
      await pumpChapter(tester, contact());
      expect(find.text(upperTr(contactChapter.title)), findsOneWidget);
      expect(find.text(headline), findsOneWidget);
      expect(find.text(detail), findsOneWidget);
      expect(
        tester.widget<Text>(find.text(detail)).style?.color,
        AppColors.textMuted,
      );
    });

    testWidgets('gövde yoksa başlık bölüm adı', (tester) async {
      await pumpChapter(
        tester,
        contact(
          const Chapter(
            id: 'iletisim',
            title: 'İletişim',
            type: ChapterType.contact,
            scrollLength: 1,
          ),
        ),
      );
      expect(find.text('İletişim'), findsOneWidget);
      expect(find.text('İLETİŞİM'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('e-posta adresin kendisi, tıklanınca mailto url ile openUrl', (
      tester,
    ) async {
      await pumpChapter(tester, contact());
      final email = find.text('ben@example.com →');
      expect(email, findsOneWidget);
      await tester.tap(email);
      expect(openedUrls, ['mailto:ben@example.com']);
    });

    testWidgets('e-posta pill olarak ikinci kez çizilmez', (tester) async {
      await pumpChapter(tester, contact());
      expect(find.text('E-posta'), findsNothing);
      expect(find.text('E-posta →'), findsNothing);
      expect(find.byType(PillButton), findsNWidgets(3));
      expect(
        find.byWidgetPredicate((w) => w is PillButton && w.label == 'E-posta'),
        findsNothing,
      );
    });

    testWidgets('e-posta: ekran okuyucu linkin label\'ını buton olarak okur', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpChapter(tester, contact());
      final node = find.bySemanticsLabel('E-posta');
      expect(node, findsOneWidget);
      expect(find.bySemanticsLabel('ben@example.com →'), findsNothing);
      expect(
        tester.getSemantics(node),
        isSemantics(label: 'E-posta', isButton: true, hasTapAction: true),
      );
      handle.dispose();
    });

    testWidgets(
      'mailto sorgusu (?subject=) adreste görünmez, url aynen gider',
      (tester) async {
        await pumpChapter(
          tester,
          contact(
            withLinks(const [
              ContactLink(
                label: 'E-posta',
                url: 'mailto:ben@example.com?subject=Merhaba',
              ),
            ]),
          ),
        );
        await tester.tap(find.text('ben@example.com →'));
        expect(openedUrls, ['mailto:ben@example.com?subject=Merhaba']);
        expect(find.byType(PillButton), findsNothing);
      },
    );

    testWidgets('diğer link pill\'leri oklu, tıklanınca doğru url', (
      tester,
    ) async {
      await pumpChapter(tester, contact());
      await tester.tap(find.text('GitHub →'));
      await tester.tap(find.text('LinkedIn →'));
      await tester.tap(find.text('Instagram →'));
      expect(openedUrls, [
        'https://github.com/ben',
        'https://www.linkedin.com/in/ben/',
        'https://www.instagram.com/ben/',
      ]);
    });

    testWidgets('mailto yoksa bütün linkler pill, büyük e-posta yok', (
      tester,
    ) async {
      await pumpChapter(
        tester,
        contact(
          withLinks(const [
            ContactLink(label: 'GitHub', url: 'https://github.com/ben'),
            ContactLink(label: 'Blog', url: 'https://blog.example.com'),
          ]),
        ),
      );
      expect(find.byType(PillButton), findsNWidgets(2));
      expect(find.textContaining('@'), findsNothing);
      await tester.tap(find.text('Blog →'));
      expect(openedUrls, ['https://blog.example.com']);
    });

    testWidgets('"YUKARI ↑" tıklanınca onBackToTop', (tester) async {
      await pumpChapter(tester, contact());
      await tester.tap(find.text(AppStrings.backToTop));
      expect(backToTopTaps, 1);
      expect(openedUrls, isEmpty);
    });

    testWidgets('"YUKARI ↑" ekran okuyucuda dokunma eylemli buton', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpChapter(tester, contact());
      expect(
        tester.getSemantics(find.bySemanticsLabel(AppStrings.backToTop)),
        isSemantics(
          label: AppStrings.backToTop,
          isButton: true,
          hasTapAction: true,
        ),
      );
      tester.semantics.tap(find.semantics.byLabel(AppStrings.backToTop));
      expect(backToTopTaps, 1);
      handle.dispose();
    });

    testWidgets('footer: "SAHİP · YIL"', (tester) async {
      await pumpChapter(tester, contact());
      expect(
        find.text('UZUN BİR SİTE SAHİBİ ADI · ${DateTime.now().year}'),
        findsOneWidget,
      );
    });

    for (final size in [desktop, mobile]) {
      testWidgets('${size.width.toInt()}: taşma yok, footer ekranın altında', (
        tester,
      ) async {
        await pumpChapter(tester, contact(), size: size);
        expect(tester.takeException(), isNull);
        final footer = find.text(
          'UZUN BİR SİTE SAHİBİ ADI · ${DateTime.now().year}',
        );
        expect(tester.getBottomLeft(footer).dy, lessThan(size.height));
        expect(
          tester.getRect(find.text(headline)).left,
          closeTo(AppSpacing.gutter, 0.5),
        );
      });
    }

    testWidgets('390: 23 karakterlik e-posta tek satır ve ekran içinde', (
      tester,
    ) async {
      const address = 'ben.uzun@ornek-site.com';
      expect(address.length, 23);
      await pumpChapter(
        tester,
        contact(
          withLinks(const [
            ContactLink(label: 'E-posta', url: 'mailto:$address'),
            ContactLink(label: 'GitHub', url: 'https://github.com/ben'),
          ]),
        ),
        size: mobile,
      );
      expect(tester.takeException(), isNull);
      final email = find.text('$address →');
      final rect = tester.getRect(email);
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(mobile.width));
      expect(
        rect.right,
        lessThanOrEqualTo(mobile.width - AppSpacing.gutter + 0.5),
      );
      final style = tester.widget<Text>(email).style!;
      final lineHeight = style.fontSize! * style.height!;
      expect(
        tester.renderObject<RenderParagraph>(email).size.height,
        lessThan(lineHeight * 1.5),
      );
    });
  });
}
