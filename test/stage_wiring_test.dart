import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portfolio_scrollytelling/ai/chat_controller.dart';
import 'package:portfolio_scrollytelling/ai/chat_panel.dart';
import 'package:portfolio_scrollytelling/stage/chapter_indicator.dart';
import 'package:portfolio_scrollytelling/stage/track.dart';
import 'package:portfolio_scrollytelling/story/scroll_progress.dart';
import 'package:portfolio_scrollytelling/story/story.dart';
import 'package:portfolio_scrollytelling/theme/theme.dart';
import 'package:portfolio_scrollytelling/widgets/label_text.dart';

import 'helpers/fake_ask.dart';
import 'helpers/wheel.dart';

/// `_Site` bağlaması (app.dart), Sahne hariç: Ray + pill nav + sohbet paneli aynı Stack'te; durum
/// (scroll, sohbet açık/kapalı, mesajlar) app.dart'taki gibi `_Scaled`'in üstünde yaşar.
///
/// `stage.dart` VM'de derlenmez (video → `dart:ui_web`); Sahne'nin `GlobalKey` taşıması
/// tarayıcıda doğrulanır. Burada katmanların işaretçi paylaşımı ve ekran 720 eşiğini geçince
/// durumun korunması test edilir (AGENTS.md §11.3, §11.4).
void main() {
  const story = Story(
    meta: Meta(title: 'Test', owner: 'Sahip', tagline: 'Merhaba'),
    chapters: [
      Chapter(id: 'a', title: 'Bir', type: ChapterType.text, scrollLength: 2),
      Chapter(id: 'b', title: 'İki', type: ChapterType.text, scrollLength: 2),
      Chapter(id: 'c', title: 'Üç', type: ChapterType.contact, scrollLength: 1),
    ],
  );
  const desktop = Size(1440, 900);

  /// Panel dışında, nav'ın altında, Ray'ın açık kalan bir noktası.
  const onTrack = Offset(200, 450);

  late ValueNotifier<bool> chatOpen;
  late ScrollProgress scrollProgress;
  late ChatController chat;

  final panel = find.descendant(
    of: find.byType(ChatPanel),
    matching: find.byType(BackdropFilter),
  );
  final title = find.text(upperTr(AppStrings.chatTitle));
  final words = fakeReply.split(' ');

  setUp(() {
    chatOpen = ValueNotifier(false);
    scrollProgress = ScrollProgress(scrollLengths: story.scrollLengths);
    chat = ChatController(ask: fakeAsk);
  });

  tearDown(() {
    chatOpen.dispose();
    scrollProgress.dispose();
    chat.dispose();
  });

  /// app.dart'taki `_Scaled` + `_SiteState.build`'in Sahne'siz kopyası: LayoutBuilder →
  /// ScreenUtilInit(key: mobil mi) → MaterialApp → Stack. Notifier'lar ve controller bu ağacın
  /// üstünde (test değişkenlerinde) yaşar; 720 eşiği geçilince yalnızca ağaç yeniden kurulur.
  Future<void> pumpSite(WidgetTester tester, {Size screen = desktop}) async {
    tester.view.physicalSize = screen;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          return ScreenUtilInit(
            key: ValueKey<bool>(AppBreakpoints.isMobileWidth(width)),
            designSize: AppBreakpoints.designSizeFor(width),
            minTextAdapt: true,
            splitScreenMode: false,
            fontSizeResolver: FontSizeResolvers.radius,
            builder: (_, _) => MaterialApp(
              theme: AppTheme.build(),
              home: Scaffold(
                body: Stack(
                  fit: StackFit.expand,
                  children: [
                    Track(scrollProgress: scrollProgress),
                    ChapterIndicator(
                      story: story,
                      scrollProgress: scrollProgress,
                    ),
                    ChatPanel(
                      isOpen: chatOpen,
                      controller: chat,
                      owner: story.meta.owner,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Ekranı yeniden boyutlar (telefonu çevirme, pencere daraltma). İlk kare ağacı yeniden kurar,
  /// kare sonrası Ray konumu geri yükler; ikinci kare sonucu çizer. `pumpAndSettle` değil: süren
  /// sohbet akışı ortada kalsın.
  Future<void> resize(WidgetTester tester, Size screen) async {
    tester.view.physicalSize = screen;
    await tester.pump();
    await tester.pump();
    expect(tester.takeException(), isNull);
  }

  Future<void> submit(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField), text);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
  }

  /// Sahte cevabı sonuna kadar akıtır (gecikme + kelime başına bir aralık).
  Future<void> drainFakeReply(WidgetTester tester) async {
    for (var i = 0; i <= words.length; i++) {
      await tester.pump(fakeWordInterval);
    }
  }

  Finder inList(String text) =>
      find.descendant(of: find.byType(ListView), matching: find.text(text));

  void expectPosition(int chapter, double progress) {
    expect(scrollProgress.value.chapterIndex, chapter);
    expect(scrollProgress.value.progress, closeTo(progress, 0.02));
  }

  testWidgets('sohbet kapalı: Ray üzerinde tekerlek kaydırır', (tester) async {
    await pumpSite(tester);
    expect(title, findsNothing);
    await wheel(tester, onTrack);
    expect(scrollProgress.value.progress, greaterThan(0));
  });

  testWidgets('isOpen = true (Sahne\'nin onOpenChat\'ı) paneli açar, '
      'scroll konumu değişmez', (tester) async {
    await pumpSite(tester);
    chatOpen.value = true;
    await tester.pumpAndSettle();
    expect(title, findsOneWidget);
    expect(
      find.text(AppStrings.chatEmptyFor(story.meta.owner)),
      findsOneWidget,
    );
    expect(find.text(AppStrings.chatButton), findsNothing);
    expect(scrollProgress.value.progress, 0);
  });

  testWidgets('sohbet açık: panel üstünde tekerlek kaydırmaz, '
      'panel dışında kaydırır', (tester) async {
    chatOpen.value = true;
    await pumpSite(tester);
    await wheel(tester, tester.getCenter(panel));
    expect(scrollProgress.value.progress, 0);

    await wheel(tester, onTrack);
    expect(scrollProgress.value.progress, greaterThan(0));
  });

  testWidgets('sohbet açıkken nav tıklaması Ray\'ı bölüme kaydırır', (
    tester,
  ) async {
    chatOpen.value = true;
    await pumpSite(tester);
    await tester.tap(find.text(upperTr(story.chapters.last.title)));
    await tester.pumpAndSettle();
    expect(scrollProgress.value.chapterIndex, story.chapters.length - 1);
    expect(title, findsOneWidget);
  });

  testWidgets('semantics: nav öğeleri "Bölüm N: başlık" butonu, aktif olan '
      'seçili', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpSite(tester);
    final first = find.bySemanticsLabel(RegExp('^Bölüm 1: '));
    final last = find.bySemanticsLabel(
      AppStrings.chapterNavLabel(
        story.chapters.length,
        story.chapters.last.title,
      ),
    );
    expect(first, findsOneWidget);
    expect(last, findsOneWidget);
    expect(
      tester.getSemantics(first),
      isSemantics(
        label: AppStrings.chapterNavLabel(1, story.chapters.first.title),
        isButton: true,
        hasTapAction: true,
        isSelected: true,
      ),
    );
    expect(tester.getSemantics(last), isSemantics(isSelected: false));

    await tester.tap(find.text(upperTr(story.chapters.last.title)));
    await tester.pumpAndSettle();
    expect(tester.getSemantics(first), isSemantics(isSelected: false));
    expect(tester.getSemantics(last), isSemantics(isSelected: true));
    handle.dispose();
  });

  testWidgets('klavye: sohbet kutusu odaklıyken PageDown kaydırmaz', (
    tester,
  ) async {
    Future<void> pageDown() async {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.pageDown);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.pageDown);
      await tester.pumpAndSettle();
    }

    await pumpSite(tester);
    chatOpen.value = true;
    await tester.pump();
    await tester.tap(find.byType(TextField));
    await tester.pump();
    await pageDown();
    expect(scrollProgress.value.chapterIndex, 0);
    expect(scrollProgress.value.progress, 0);

    chatOpen.value = false;
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    await pageDown();
    expect(scrollProgress.value.chapterIndex, 1);
  });

  group('ekran 720 eşiğini geçince durum korunur', () {
    double offsetIn(int chapter, double progress, Size screen) => offsetFor(
      chapterIndex: chapter,
      progress: progress,
      viewportHeight: screen.height,
      scrollLengths: story.scrollLengths,
    );

    testWidgets('daralt ve genişlet (1000×800 ↔ 600×800): aynı bölüm ve '
        'ilerleme, sohbet açık, mesajlar duruyor, akış kesilmiyor', (
      tester,
    ) async {
      const wide = Size(1000, 800);
      const narrow = Size(600, 800);
      await pumpSite(tester, screen: wide);
      expect(AppBreakpoints.isMobile, isFalse);

      await wheel(tester, onTrack, dy: offsetIn(2, 0.5, wide));
      expectPosition(2, 0.5);

      await tester.tap(find.text(AppStrings.chatButton));
      await tester.pumpAndSettle();
      await submit(tester, 'merhaba');
      await tester.pump(fakeReplyDelay);
      await tester.pump(fakeWordInterval);
      // Akış ortada: yalnızca ilk kelime geldi.
      expect(find.text(words.first), findsOneWidget);
      final trackBefore = tester.state(find.byType(Track));
      final panelBefore = tester.state(find.byType(ChatPanel));

      await resize(tester, narrow);
      expect(AppBreakpoints.isMobile, isTrue);
      // Ağaç gerçekten yeniden kuruldu (yeni State'ler), durum yine de yerinde.
      expect(tester.state(find.byType(Track)), isNot(same(trackBefore)));
      expect(tester.state(find.byType(ChatPanel)), isNot(same(panelBefore)));
      expectPosition(2, 0.5);
      expect(chatOpen.value, isTrue);
      expect(title, findsOneWidget);
      expect(inList('merhaba'), findsOneWidget);
      expect(find.text(words.first), findsOneWidget);
      expect(chat.isStreaming, isTrue);

      await drainFakeReply(tester);
      expect(inList(fakeReply), findsOneWidget);
      expect(chat.isStreaming, isFalse);

      await resize(tester, wide);
      expect(AppBreakpoints.isMobile, isFalse);
      expectPosition(2, 0.5);
      expect(chatOpen.value, isTrue);
      expect(title, findsOneWidget);
      expect(inList('merhaba'), findsOneWidget);
      expect(inList(fakeReply), findsOneWidget);

      // Yeni Ray bağlı kaldı (eski Ray'ın dispose'u koparmadı): tekerlek hâlâ yazıyor.
      await wheel(tester, onTrack, dy: -wide.height * 0.25);
      expectPosition(2, 0.25);
    });

    testWidgets('telefon döner (390×844 ↔ 844×390): viewport yüksekliği '
        'değişir, bölüm ve ilerleme korunur, sohbet kapalı kalır', (
      tester,
    ) async {
      const portrait = Size(390, 844);
      const landscape = Size(844, 390);
      const onMobileTrack = Offset(100, 400);
      await pumpSite(tester, screen: portrait);
      expect(AppBreakpoints.isMobile, isTrue);

      await wheel(tester, onMobileTrack, dy: offsetIn(1, 0.25, portrait));
      expectPosition(1, 0.25);

      await resize(tester, landscape);
      expect(AppBreakpoints.isMobile, isFalse);
      expectPosition(1, 0.25);
      expect(chatOpen.value, isFalse);
      expect(title, findsNothing);
      expect(find.text(AppStrings.chatButton), findsOneWidget);

      await resize(tester, portrait);
      expect(AppBreakpoints.isMobile, isTrue);
      expectPosition(1, 0.25);

      await wheel(tester, onMobileTrack, dy: portrait.height);
      expectPosition(1, 0.75);
    });

    testWidgets('sayfa başındayken daraltınca başta kalır', (tester) async {
      await pumpSite(tester, screen: const Size(1000, 800));
      await resize(tester, const Size(600, 800));
      expect(scrollProgress.value, ScrollState.initial);
    });
  });
}
