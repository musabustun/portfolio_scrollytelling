import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portfolio_scrollytelling/ai/ai_config.dart';
import 'package:portfolio_scrollytelling/ai/chat_controller.dart';
import 'package:portfolio_scrollytelling/ai/chat_message.dart';
import 'package:portfolio_scrollytelling/ai/chat_panel.dart';
import 'package:portfolio_scrollytelling/stage/track.dart';
import 'package:portfolio_scrollytelling/story/scroll_progress.dart';
import 'package:portfolio_scrollytelling/theme/theme.dart';
import 'package:portfolio_scrollytelling/widgets/label_text.dart';
import 'package:portfolio_scrollytelling/widgets/pill_button.dart';
import 'package:portfolio_scrollytelling/widgets/typing_dots.dart';

import 'helpers/fake_ask.dart';
import 'helpers/inter_font.dart';
import 'helpers/wheel.dart';

/// ChatPanel ve ChatController: aç/kapat, sahte cevap akışı, "yazıyor" göstergesi, hata satırı,
/// Firebase'siz kart, soru sınırı, panelin tekerleği Ray'a sızdırmaması (AGENTS.md §11.4) ve panel
/// yeniden kurulunca sohbetin kalması.
void main() {
  late ValueNotifier<bool> isOpen;
  late ScrollProgress scrollProgress;

  /// Son `pumpPanel`'in controller'ı; testin sonunda dispose edilir.
  late ChatController chat;

  const owner = 'Ada';
  final title = find.text(upperTr(AppStrings.chatTitle));
  final button = find.text(AppStrings.chatButton);
  final panel = find.byType(BackdropFilter);
  final empty = find.text(AppStrings.chatEmptyFor(owner));
  final closeIcon = find.byIcon(Icons.close);
  final words = fakeReply.split(' ');

  // Panel düzeni (yapay zekâ notu dahil) gerçek yazı genişliğiyle ölçülür.
  setUpAll(loadInterFont);

  setUp(() {
    isOpen = ValueNotifier(false);
    scrollProgress = ScrollProgress(scrollLengths: const [1, 1, 1]);
  });

  tearDown(() {
    isOpen.dispose();
    scrollProgress.dispose();
  });

  /// Gerçek düzen: altta Ray (Track), üstte [chat]'i gösteren ChatPanel.
  /// [panelKey] değişince panel yeni State ile kurulur (ekran dönünce olduğu gibi).
  Widget site(Size screen, {Key? panelKey}) => ScreenUtilInit(
    designSize: AppBreakpoints.designSizeFor(screen.width),
    builder: (_, _) => MaterialApp(
      theme: AppTheme.build(),
      home: Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            Track(scrollProgress: scrollProgress),
            ChatPanel(
              key: panelKey,
              isOpen: isOpen,
              controller: chat,
              owner: owner,
            ),
          ],
        ),
      ),
    ),
  );

  /// Yeni [chat] kurar ve [site]'ı çizer; ekran 1:1 tasarım boyutunda.
  Future<void> pumpPanel(
    WidgetTester tester, {
    AskFn? ask = fakeAsk,
    Size screen = const Size(1440, 900),
  }) async {
    tester.view.physicalSize = screen;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    chat = ChatController(ask: ask);
    addTearDown(chat.dispose);
    await tester.pumpWidget(site(screen));
    await tester.pumpAndSettle();
  }

  Future<void> submit(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField), text);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
  }

  /// Sahte cevabı sonuna kadar akıtır (gecikme + kelime başına bir aralık).
  Future<void> drainFakeReply(WidgetTester tester) async {
    await tester.pump(fakeReplyDelay);
    for (var i = 0; i <= words.length; i++) {
      await tester.pump(fakeWordInterval);
    }
  }

  String inputText(WidgetTester tester) =>
      tester.widget<TextField>(find.byType(TextField)).controller!.text;

  Finder inList(String text) =>
      find.descendant(of: find.byType(ListView), matching: find.text(text));

  test('ChatMessage: isUser ve copyWith', () {
    const m = ChatMessage(role: ChatRole.user, text: 'a');
    expect(m.isUser, isTrue);
    expect(m.copyWith(text: 'b').text, 'b');
    expect(m.copyWith(text: 'b').role, ChatRole.user);
    expect(m.copyWith().text, 'a');
    expect(
      const ChatMessage(role: ChatRole.assistant, text: '').isUser,
      isFalse,
    );
  });

  /// Pill'in zemin rengi (dolu: `accent`, çizgili: şeffaf).
  Color? pillColor(WidgetTester tester) {
    final box = tester.widget<AnimatedContainer>(
      find.descendant(
        of: find.byType(PillButton),
        matching: find.byType(AnimatedContainer),
      ),
    );
    return (box.decoration! as BoxDecoration).color;
  }

  testWidgets('kapalı: sağ altta çizgili pill, panel yok; tıklayınca panel '
      'açılır', (tester) async {
    await pumpPanel(tester);
    expect(button, findsOneWidget);
    expect(title, findsNothing);
    expect(panel, findsNothing);
    final pillBottomRight = tester.getBottomRight(find.byType(PillButton));
    expect(pillBottomRight.dx, closeTo(1440 - AppSpacing.gutter, 1e-6));
    expect(pillBottomRight.dy, closeTo(900 - AppSpacing.gutter, 1e-6));
    expect(tester.widget<PillButton>(find.byType(PillButton)).filled, isFalse);
    expect(pillColor(tester), AppColors.transparent);

    await tester.tap(button);
    expect(isOpen.value, isTrue);
    await tester.pumpAndSettle();
    expect(title, findsOneWidget);
    expect(empty, findsOneWidget);
    expect(button, findsNothing);
    expect(panel, findsOneWidget);
  });

  testWidgets('kapalı pill ekran okuyucuda "Sohbeti aç" butonu', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpPanel(tester);
    final pill = find.bySemanticsLabel(AppStrings.openChat);
    expect(pill, findsOneWidget);
    expect(find.bySemanticsLabel(AppStrings.chatButton), findsNothing);
    expect(
      tester.getSemantics(pill),
      isSemantics(
        label: AppStrings.openChat,
        isButton: true,
        hasTapAction: true,
      ),
    );
    handle.dispose();
  });

  testWidgets('mobil kapalı: pill sağ üstte, üst yarıda ve dolu (accent); '
      'tıklayınca panel açılır', (tester) async {
    const mobile = Size(390, 844);
    await pumpPanel(tester, screen: mobile);
    expect(AppBreakpoints.isMobile, isTrue);
    final pill = find.byType(PillButton);
    expect(tester.getTopLeft(pill).dy, lessThan(mobile.height / 2));
    final topRight = tester.getTopRight(pill);
    expect(topRight.dx, closeTo(mobile.width - AppSpacing.gutter, 1e-6));
    expect(topRight.dy, closeTo(AppSpacing.gutter, 1e-6));
    expect(tester.widget<PillButton>(pill).filled, isTrue);
    expect(pillColor(tester), AppColors.accent);

    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(title, findsOneWidget);
    expect(empty, findsOneWidget);
    expect(button, findsNothing);
  });

  testWidgets('masaüstü: panel 380×560, sağ alt gutter içinde', (tester) async {
    isOpen.value = true;
    await pumpPanel(tester);
    expect(tester.getSize(panel).width, closeTo(AppSizes.chatPanelWidth, 1e-6));
    expect(
      tester.getSize(panel).height,
      closeTo(AppSizes.chatPanelHeight, 1e-6),
    );
    final bottomRight = tester.getBottomRight(panel);
    expect(bottomRight.dx, closeTo(1440 - AppSpacing.gutter, 1e-6));
    expect(bottomRight.dy, closeTo(900 - AppSpacing.gutter, 1e-6));
  });

  testWidgets('mobil: panel gutter içinde tam ekran, taşma yok', (
    tester,
  ) async {
    isOpen.value = true;
    await pumpPanel(tester, screen: const Size(390, 844));
    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(panel).width,
      closeTo(390 - 2 * AppSpacing.gutter, 1e-6),
    );
    expect(
      tester.getSize(panel).height,
      closeTo(844 - 2 * AppSpacing.gutter, 1e-6),
    );
  });

  testWidgets('dışarıdan isOpen = true paneli açar (kapaktaki "▸ Sohbet")', (
    tester,
  ) async {
    await pumpPanel(tester);
    isOpen.value = true;
    await tester.pumpAndSettle();
    expect(title, findsOneWidget);
  });

  testWidgets('gönder: kullanıcı balonu, sahte cevap kelime kelime akar', (
    tester,
  ) async {
    isOpen.value = true;
    await pumpPanel(tester);
    await submit(tester, 'merhaba');
    expect(inList('merhaba'), findsOneWidget);
    expect(inputText(tester), isEmpty);
    expect(empty, findsNothing);

    await tester.pump(fakeReplyDelay);
    await tester.pump(fakeWordInterval);
    await tester.pump(fakeWordInterval);
    expect(find.text('${words[0]} ${words[1]}'), findsOneWidget);

    // Akış sürerken gönderim yok sayılır: metin kutuda kalır, balon olmaz.
    await submit(tester, 'ikinci');
    expect(inputText(tester), 'ikinci');
    expect(inList('ikinci'), findsNothing);

    await drainFakeReply(tester);
    expect(find.text(fakeReply), findsOneWidget);
  });

  group('"yazıyor" göstergesi', () {
    final typing = find.descendant(
      of: find.byType(ListView),
      matching: find.byType(TypingDots),
    );

    /// Paneli açar ya da kapatır ve crossfade'i bitirir (gösterge dönerken `pumpAndSettle` durulmaz).
    /// Animasyon süre tam dolunca değil aşılınca biter; çıkan çocuk bir kare sonra ağaçtan kalkar.
    Future<void> setOpen(WidgetTester tester, {required bool open}) async {
      isOpen.value = open;
      await tester.pump();
      await tester.pump(AppDurations.crossfade * 2);
      await tester.pump();
    }

    testWidgets('gönderince asistan satırında görünür, ilk parça gelince '
        'kalkar; solda, ilk kelimeyle aynı satırda', (tester) async {
      isOpen.value = true;
      await pumpPanel(tester);
      expect(typing, findsNothing);

      await submit(tester, 'merhaba');
      expect(typing, findsOneWidget);
      final dots = tester.getRect(typing);
      final list = tester.getRect(find.byType(ListView));
      expect(dots.left, closeTo(list.left + AppSpacing.md, 1e-6));
      expect(dots.top, greaterThan(tester.getRect(inList('merhaba')).bottom));

      // Cevap gecikmesi boyunca durur.
      await tester.pump(fakeReplyDelay);
      expect(typing, findsOneWidget);

      await tester.pump(fakeWordInterval);
      expect(typing, findsNothing);
      final first = tester.getRect(inList(words.first));
      expect(first.left, closeTo(dots.left, 1e-6));
      expect(first.center.dy, closeTo(dots.center.dy, 1));

      await drainFakeReply(tester);
      expect(find.text(fakeReply), findsOneWidget);
      expect(typing, findsNothing);
    });

    testWidgets('hata gelince kalkar, yerinde hata satırı', (tester) async {
      final replies = StreamController<String>();
      isOpen.value = true;
      await pumpPanel(tester, ask: (_) async => replies.stream);
      await submit(tester, 'soru');
      expect(typing, findsOneWidget);

      replies.addError(Exception('kota\nstack'));
      await tester.pump();
      expect(typing, findsNothing);
      expect(inList('Exception: kota'), findsOneWidget);
      expect(chat.isStreaming, isFalse);
    });

    testWidgets('panel kapatılıp açılınca: ilk parça hâlâ bekleniyorsa '
        'gösterge yine görünür, kapalıyken geldiyse metin görünür', (
      tester,
    ) async {
      final replies = StreamController<String>();
      isOpen.value = true;
      await pumpPanel(tester, ask: (_) async => replies.stream);
      await submit(tester, 'soru');
      expect(typing, findsOneWidget);

      await setOpen(tester, open: false);
      expect(panel, findsNothing);
      expect(typing, findsNothing);
      await setOpen(tester, open: true);
      expect(chat.isStreaming, isTrue);
      expect(typing, findsOneWidget);

      await setOpen(tester, open: false);
      replies.add('Merhaba');
      await tester.pump();
      await setOpen(tester, open: true);
      expect(chat.isStreaming, isTrue);
      expect(typing, findsNothing);
      expect(inList('Merhaba'), findsOneWidget);

      unawaited(replies.close());
      await tester.pump();
      expect(chat.isStreaming, isFalse);
      expect(typing, findsNothing);
      expect(inList('Merhaba'), findsOneWidget);
    });
  });

  testWidgets('akış bitince gönder butonu yeniden çalışır', (tester) async {
    isOpen.value = true;
    await pumpPanel(tester);
    await submit(tester, 'bir');
    await drainFakeReply(tester);

    await tester.enterText(find.byType(TextField), 'iki');
    await tester.tap(find.byIcon(Icons.arrow_upward));
    await tester.pump();
    expect(inList('iki'), findsOneWidget);
    expect(inputText(tester), isEmpty);
    await drainFakeReply(tester);
    expect(find.text(fakeReply), findsNWidgets(2));
  });

  testWidgets('hata: asistan satırında tek satır mesaj, gönder açılır', (
    tester,
  ) async {
    isOpen.value = true;
    await pumpPanel(
      tester,
      ask: (_) async => Stream<String>.error(Exception('kota\nstack')),
    );
    await submit(tester, 'soru');
    await tester.pump();
    expect(find.text('Exception: kota'), findsOneWidget);

    await submit(tester, 'tekrar');
    expect(inList('tekrar'), findsOneWidget);
    await tester.pump();
    expect(find.text('Exception: kota'), findsNWidgets(2));
  });

  testWidgets('× ikonu "Kapat" etiketli buton; "KAPAT" yazısı yok', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    isOpen.value = true;
    await pumpPanel(tester);
    expect(closeIcon, findsOneWidget);
    expect(find.text(upperTr(AppStrings.close)), findsNothing);
    expect(find.bySemanticsLabel(AppStrings.close), findsOneWidget);
    expect(
      tester.getSemantics(find.bySemanticsLabel(AppStrings.close)),
      isSemantics(label: AppStrings.close, isButton: true, hasTapAction: true),
    );
    semantics.dispose();
  });

  testWidgets('× paneli kapatır; geçmiş yeniden açınca durur', (tester) async {
    isOpen.value = true;
    await pumpPanel(tester);
    await submit(tester, 'merhaba');
    await drainFakeReply(tester);

    await tester.tap(closeIcon);
    expect(isOpen.value, isFalse);
    await tester.pumpAndSettle();
    expect(title, findsNothing);
    expect(panel, findsNothing);
    expect(button, findsOneWidget);

    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.text('merhaba'), findsOneWidget);
    expect(find.text(fakeReply), findsOneWidget);
  });

  testWidgets('işaretçi: açık panel üstünde tekerlek Ray\'ı kaydırmaz, '
      'kapalıyken kaydırır', (tester) async {
    isOpen.value = true;
    await pumpPanel(tester);
    final center = tester.getCenter(panel);

    await wheel(tester, center);
    expect(scrollProgress.value.progress, 0);

    // Mesaj listesi varken de (kısa liste, kendisi kaymaz) sızma yok.
    await submit(tester, 'merhaba');
    await drainFakeReply(tester);
    await wheel(tester, center);
    expect(scrollProgress.value.progress, 0);

    isOpen.value = false;
    await tester.pumpAndSettle();
    expect(panel, findsNothing);
    await wheel(tester, center);
    expect(scrollProgress.value.progress, greaterThan(0));
  });

  testWidgets('Firebase bağlı değil (ask null): kart var, giriş kutusu ve '
      'gönder yok', (tester) async {
    isOpen.value = true;
    await pumpPanel(tester, ask: null);
    expect(find.text(upperTr(AppStrings.notConnectedTitle)), findsOneWidget);
    expect(find.text(AppStrings.notConnectedBody), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.byIcon(Icons.arrow_upward), findsNothing);
    expect(empty, findsNothing);
    expect(title, findsOneWidget);
    expect(closeIcon, findsOneWidget);

    await tester.tap(closeIcon);
    expect(isOpen.value, isFalse);
    await tester.pumpAndSettle();
    expect(panel, findsNothing);
    expect(title, findsNothing);
    expect(button, findsOneWidget);
  });

  testWidgets('işaretçi: kartlı açık panelde tekerlek Ray\'ı kaydırmaz', (
    tester,
  ) async {
    isOpen.value = true;
    await pumpPanel(tester, ask: null);
    final card = tester.getCenter(find.text(AppStrings.notConnectedBody));
    // Giriş kutusunun boş kalan yeri: panelin alt şeridi, kartın dışı.
    final bottom = tester.getBottomLeft(panel) + const Offset(40, -20);

    await wheel(tester, card);
    await wheel(tester, bottom);
    expect(scrollProgress.value.progress, 0);

    isOpen.value = false;
    await tester.pumpAndSettle();
    await wheel(tester, card);
    expect(scrollProgress.value.progress, greaterThan(0));
  });

  group('yapay zekâ notu', () {
    final disclaimer = find.text(AppStrings.chatDisclaimer);

    for (final screen in const [
      Size(1440, 900),
      Size(1100, 700),
      Size(390, 844),
      Size(375, 667),
      Size(360, 740),
    ]) {
      final name = '${screen.width.toInt()}×${screen.height.toInt()}';
      testWidgets('$name: bağlıyken giriş kutusunun altında, ortalı, iki '
          'satıra kırpılmadan sığar; taşma yok', (tester) async {
        isOpen.value = true;
        await pumpPanel(tester, screen: screen);
        expect(tester.takeException(), isNull);
        expect(disclaimer, findsOneWidget);

        final text = tester.widget<Text>(disclaimer);
        expect(text.maxLines, 2);
        expect(text.textAlign, TextAlign.center);
        expect(text.style?.color, AppColors.textMuted);
        expect(text.style?.fontSize, AppTextStyles.button.fontSize);
        expect(
          tester.renderObject<RenderParagraph>(disclaimer).didExceedMaxLines,
          isFalse,
          reason: 'not kesilmeden iki satıra sığmalı',
        );

        final note = tester.getRect(disclaimer);
        final frame = tester.getRect(panel);
        expect(
          note.top,
          greaterThanOrEqualTo(tester.getRect(find.byType(TextField)).bottom),
        );
        expect(note.bottom, lessThanOrEqualTo(frame.bottom));
        expect(note.center.dx, closeTo(frame.center.dx, 1));
      });
    }

    testWidgets('bağlı değilken (kart) çizilmez', (tester) async {
      isOpen.value = true;
      await pumpPanel(tester, ask: null);
      expect(find.text(AppStrings.notConnectedBody), findsOneWidget);
      expect(disclaimer, findsNothing);
    });

    testWidgets('panel kapalıyken çizilmez', (tester) async {
      await pumpPanel(tester);
      expect(disclaimer, findsNothing);
    });
  });

  testWidgets('giriş kutusu AiConfig.maxQuestionChars karakterde durur', (
    tester,
  ) async {
    isOpen.value = true;
    await pumpPanel(tester);
    await tester.enterText(
      find.byType(TextField),
      'a' * (AiConfig.maxQuestionChars + 100),
    );
    await tester.pump();
    expect(inputText(tester), hasLength(AiConfig.maxQuestionChars));
  });

  group('giriş kutusu yazı boyutu (iOS odak yakınlaştırması)', () {
    /// iOS Safari bu boyutun altındaki girişe odaklanınca sayfayı yakınlaştırır.
    const iosZoomThreshold = 16.0;

    double? inputFontSize(WidgetTester tester) =>
        tester.widget<EditableText>(find.byType(EditableText)).style.fontSize;

    double? hintFontSize(WidgetTester tester) =>
        tester.widget<Text>(find.text(AppStrings.chatHint)).style?.fontSize;

    for (final screen in const [Size(390, 844), Size(375, 600)]) {
      final name = '${screen.width.toInt()}×${screen.height.toInt()}';
      testWidgets('$name: telefonda giriş ve ipucu yazısı en az 16 px', (
        tester,
      ) async {
        isOpen.value = true;
        await pumpPanel(tester, screen: screen);
        expect(tester.takeException(), isNull);
        expect(AppBreakpoints.isMobile, isTrue);
        expect(inputFontSize(tester), greaterThanOrEqualTo(iosZoomThreshold));
        expect(hintFontSize(tester), greaterThanOrEqualTo(iosZoomThreshold));
      });
    }

    testWidgets('375×600: body 16 px altına iner, giriş kutusu inmez', (
      tester,
    ) async {
      isOpen.value = true;
      await pumpPanel(tester, screen: const Size(375, 600));
      expect(AppTextStyles.body.fontSize, lessThan(iosZoomThreshold));
      expect(inputFontSize(tester), iosZoomThreshold);
    });

    testWidgets('1440×900: giriş kutusu body ile aynı boyutta', (tester) async {
      isOpen.value = true;
      await pumpPanel(tester);
      expect(inputFontSize(tester), AppTextStyles.body.fontSize);
      expect(hintFontSize(tester), AppTextStyles.body.fontSize);
    });
  });

  testWidgets('işaretçi: açık panelde sürükleme Ray\'ı kaydırmaz, '
      'kapalıyken aynı noktada kaydırır', (tester) async {
    isOpen.value = true;
    await pumpPanel(tester);
    final center = tester.getCenter(panel);
    await tester.dragFrom(center, const Offset(0, -300));
    await tester.pump();
    expect(scrollProgress.value.progress, 0);

    isOpen.value = false;
    await tester.pumpAndSettle();
    await tester.dragFrom(center, const Offset(0, -300));
    await tester.pump();
    expect(scrollProgress.value.progress, greaterThan(0));
  });

  testWidgets('panel yeniden kurulunca (ekran döndü) mesajlar durur, süren '
      'akış kesilmez', (tester) async {
    isOpen.value = true;
    await pumpPanel(tester);
    await submit(tester, 'merhaba');
    await tester.pump(fakeReplyDelay);
    await tester.pump(fakeWordInterval);
    expect(find.text(words.first), findsOneWidget);
    final before = tester.state(find.byType(ChatPanel));

    await tester.pumpWidget(
      site(const Size(1440, 900), panelKey: const ValueKey('yeni')),
    );
    expect(tester.state(find.byType(ChatPanel)), isNot(same(before)));
    expect(title, findsOneWidget);
    expect(inList('merhaba'), findsOneWidget);
    expect(find.text(words.first), findsOneWidget);
    expect(chat.isStreaming, isTrue);

    await drainFakeReply(tester);
    expect(find.text(fakeReply), findsOneWidget);
    expect(chat.isStreaming, isFalse);
  });

  testWidgets('kapalı panelde akış sürer; açınca tam cevap görünür', (
    tester,
  ) async {
    isOpen.value = true;
    await pumpPanel(tester);
    await submit(tester, 'merhaba');
    await tester.pump(fakeReplyDelay);

    await tester.tap(closeIcon);
    await drainFakeReply(tester);
    await tester.pumpAndSettle();
    expect(panel, findsNothing);
    expect(chat.isStreaming, isFalse);

    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(inList('merhaba'), findsOneWidget);
    expect(find.text(fakeReply), findsOneWidget);
  });

  group('ChatController', () {
    test('bağlı değilse, soru boşsa ya da akış sürerken send false; '
        'liste değişmez', () async {
      final offline = ChatController(ask: null);
      addTearDown(offline.dispose);
      expect(offline.isConnected, isFalse);
      expect(offline.send('merhaba'), isFalse);
      expect(offline.messages, isEmpty);

      final asked = <String>[];
      final replies = StreamController<String>();
      final online = ChatController(
        ask: (question) async {
          asked.add(question);
          return asked.length == 1 ? replies.stream : const Stream.empty();
        },
      );
      addTearDown(online.dispose);
      expect(online.isConnected, isTrue);
      expect(online.send('   '), isFalse);
      expect(online.messages, isEmpty);

      expect(online.send('  bir  '), isTrue);
      expect(online.send('iki'), isFalse);
      expect(online.messages.map((m) => m.text), ['bir', '']);
      await pumpEventQueue();
      expect(asked, ['bir']);

      // Akış bitince yeni soru kabul edilir.
      await replies.close();
      await pumpEventQueue();
      expect(online.isStreaming, isFalse);
      expect(online.send('iki'), isTrue);
      await pumpEventQueue();
      expect(asked, ['bir', 'iki']);
      expect(online.messages.map((m) => m.text), ['bir', '', 'iki', '']);
      expect(online.isStreaming, isFalse);
    });

    test('send: kullanıcı + boş asistan mesajı; parçalar asistan mesajına '
        'akar, akış bitince isStreaming false', () async {
      final replies = StreamController<String>();
      final controller = ChatController(ask: (_) async => replies.stream);
      addTearDown(controller.dispose);
      var notified = 0;
      controller.addListener(() => notified++);

      expect(controller.send('soru'), isTrue);
      expect(controller.isStreaming, isTrue);
      expect(notified, 1);
      expect(controller.messages, hasLength(2));
      expect(controller.messages.first.isUser, isTrue);
      expect(controller.messages.first.text, 'soru');
      expect(controller.messages.last.isUser, isFalse);
      expect(controller.messages.last.text, isEmpty);
      expect(
        () => controller.messages.add(
          const ChatMessage(role: ChatRole.user, text: 'x'),
        ),
        throwsUnsupportedError,
      );

      replies
        ..add('Mer')
        ..add('haba');
      await pumpEventQueue();
      expect(controller.messages.last.text, 'Merhaba');
      expect(controller.isStreaming, isTrue);

      await replies.close();
      await pumpEventQueue();
      expect(controller.isStreaming, isFalse);
      expect(controller.messages.last.text, 'Merhaba');
      expect(notified, 4);
    });

    test('soru AiConfig.maxQuestionChars harfe (grapheme) kırpılır', () async {
      final asked = <String>[];
      final controller = ChatController(
        ask: (question) async {
          asked.add(question);
          return const Stream<String>.empty();
        },
      );
      addTearDown(controller.dispose);
      const emoji = '👍🏽';
      expect(controller.send(emoji * (AiConfig.maxQuestionChars + 5)), isTrue);
      expect(controller.messages.first.text, emoji * AiConfig.maxQuestionChars);
      expect(
        controller.messages.first.text.characters.length,
        AiConfig.maxQuestionChars,
      );
      await pumpEventQueue();
      expect(asked, [emoji * AiConfig.maxQuestionChars]);
      expect(controller.isStreaming, isFalse);
    });

    test('hata: asistan mesajı hatanın ilk satırı, akış biter', () async {
      final controller = ChatController(
        ask: (_) async => throw Exception('kota\nstack'),
      );
      addTearDown(controller.dispose);
      expect(controller.send('soru'), isTrue);
      await pumpEventQueue();
      expect(controller.messages.last.text, 'Exception: kota');
      expect(controller.isStreaming, isFalse);
    });

    test('akış sürerken dispose: sonraki parça yok sayılır, abonelik '
        'kapanır', () async {
      final replies = StreamController<String>();
      final controller = ChatController(ask: (_) async => replies.stream);
      expect(controller.send('soru'), isTrue);
      await pumpEventQueue();
      expect(replies.hasListener, isTrue);

      controller.dispose();
      replies.add('geç');
      await pumpEventQueue();
      expect(replies.hasListener, isFalse);
      expect(controller.messages.last.text, isEmpty);
    });
  });
}
