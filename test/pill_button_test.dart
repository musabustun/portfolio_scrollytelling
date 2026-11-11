import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portfolio_scrollytelling/theme/theme.dart';
import 'package:portfolio_scrollytelling/widgets/pill_button.dart';

/// PillButton: dolu/çizgili görünüm, tıklama ve fare hover'ı (AGENTS.md §11.4).
void main() {
  late int taps;

  setUp(() => taps = 0);

  /// [reduceMotion] işletim sistemi "hareketi azalt" ayarını taklit eder (`disableAnimations`).
  Future<void> pumpButton(
    WidgetTester tester, {
    bool filled = false,
    bool arrow = false,
    bool reduceMotion = false,
    String? semanticsLabel,
  }) async {
    final button = PillButton(
      label: 'İletişim',
      filled: filled,
      arrow: arrow,
      semanticsLabel: semanticsLabel,
      onTap: () => taps++,
    );
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: AppBreakpoints.desktopDesignSize,
        builder: (_, _) => MaterialApp(
          theme: AppTheme.build(),
          home: Scaffold(
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (reduceMotion)
                  MediaQuery(
                    data: const MediaQueryData(disableAnimations: true),
                    child: button,
                  )
                else
                  button,
              ],
            ),
          ),
        ),
      ),
    );
  }

  BoxDecoration decorationOf(WidgetTester tester) =>
      tester
              .widget<DecoratedBox>(
                find.descendant(
                  of: find.byType(PillButton),
                  matching: find.byType(DecoratedBox),
                ),
              )
              .decoration
          as BoxDecoration;

  Text textOf(WidgetTester tester) => tester.widget<Text>(
    find.descendant(of: find.byType(PillButton), matching: find.byType(Text)),
  );

  Future<TestPointer> hover(WidgetTester tester, Offset at) async {
    final pointer = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(pointer.hover(at));
    await tester.pumpAndSettle();
    return pointer;
  }

  testWidgets('tıklanınca onTap çağrılır', (tester) async {
    await pumpButton(tester);
    await tester.tap(find.byType(PillButton));
    expect(taps, 1);
  });

  testWidgets('çizgili: şeffaf zemin, border kenarlık, text yazı', (
    tester,
  ) async {
    await pumpButton(tester);
    final decoration = decorationOf(tester);
    expect(decoration.color, AppColors.transparent);
    expect(decoration.border, isNotNull);
    expect(decoration.borderRadius, AppRadii.pill);
    expect(textOf(tester).style?.color, AppColors.text);
  });

  testWidgets('dolu: accent zemin, kenarlıksız, onAccent yazı', (tester) async {
    await pumpButton(tester, filled: true);
    final decoration = decorationOf(tester);
    expect(decoration.color, AppColors.accent);
    expect(decoration.border, isNull);
    expect(textOf(tester).style?.color, AppColors.onAccent);
  });

  testWidgets('arrow: yazının sonuna " →" eklenir', (tester) async {
    await pumpButton(tester, arrow: true);
    expect(find.text('İletişim →'), findsOneWidget);
  });

  testWidgets('semantics: etiket verilmezse görünen yazı (oksuz), buton', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpButton(tester, arrow: true);
    final node = find.bySemanticsLabel('İletişim');
    expect(node, findsOneWidget);
    expect(find.bySemanticsLabel('İletişim →'), findsNothing);
    expect(
      tester.getSemantics(node),
      isSemantics(label: 'İletişim', isButton: true, hasTapAction: true),
    );
    handle.dispose();
  });

  testWidgets('semantics: ekran okuyucunun dokunma eylemi onTap\'i çağırır', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpButton(tester, arrow: true);
    tester.semantics.tap(find.semantics.byLabel('İletişim'));
    await tester.pump();
    expect(taps, 1);
    handle.dispose();
  });

  testWidgets('semantics: semanticsLabel görünen yazının yerine okunur', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpButton(tester, semanticsLabel: 'Sohbeti aç');
    expect(find.bySemanticsLabel('Sohbeti aç'), findsOneWidget);
    expect(find.bySemanticsLabel('İletişim'), findsNothing);
    expect(find.text('İletişim'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('Column içinde tam genişliğe yayılmaz, yükseklik 44', (
    tester,
  ) async {
    await pumpButton(tester);
    final size = tester.getSize(find.byType(PillButton));
    final screen = tester.getSize(find.byType(Scaffold));
    expect(size.width, lessThan(screen.width / 2));
    expect(size.height, closeTo(AppSizes.buttonHeight, 1e-6));
  });

  testWidgets('fare hover: çizgili zemin açılır, çıkınca geri döner', (
    tester,
  ) async {
    await pumpButton(tester);
    final pointer = await hover(
      tester,
      tester.getCenter(find.byType(PillButton)),
    );
    expect(decorationOf(tester).color, isSameColorAs(AppColors.hoverOverlay));
    expect(decorationOf(tester).color, isNot(AppColors.transparent));
    expect(
      RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(1),
      SystemMouseCursors.click,
    );

    // Buton dışı bir nokta: 800×600 varsayılan test ekranının sağ alt köşesi.
    await tester.sendEventToBinding(pointer.hover(const Offset(790, 590)));
    await tester.pumpAndSettle();
    expect(decorationOf(tester).color, AppColors.transparent);
    await tester.sendEventToBinding(pointer.removePointer());
  });

  testWidgets('fare hover: dolu zeminin üstüne %10 text biner', (tester) async {
    await pumpButton(tester, filled: true);
    final pointer = await hover(
      tester,
      tester.getCenter(find.byType(PillButton)),
    );
    expect(
      decorationOf(tester).color,
      isSameColorAs(Color.alphaBlend(AppColors.hoverOverlay, AppColors.accent)),
    );
    await tester.sendEventToBinding(pointer.removePointer());
  });

  testWidgets('hover varsayılan: renk 150 ms\'de geçer, tek karede varmaz', (
    tester,
  ) async {
    await pumpButton(tester);
    final pointer = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(
      pointer.hover(tester.getCenter(find.byType(PillButton))),
    );
    await tester.pump();
    expect(decorationOf(tester).color, AppColors.transparent);
    await tester.pumpAndSettle();
    expect(decorationOf(tester).color, isSameColorAs(AppColors.hoverOverlay));
    await tester.sendEventToBinding(pointer.removePointer());
  });

  testWidgets('reduced-motion: hover sonrası tek karede renk hedefte', (
    tester,
  ) async {
    await pumpButton(tester, filled: true, reduceMotion: true);
    final pointer = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(
      pointer.hover(tester.getCenter(find.byType(PillButton))),
    );
    await tester.pump();
    expect(
      decorationOf(tester).color,
      isSameColorAs(Color.alphaBlend(AppColors.hoverOverlay, AppColors.accent)),
    );
    expect(tester.hasRunningAnimations, isFalse);

    await tester.sendEventToBinding(pointer.hover(const Offset(790, 590)));
    await tester.pump();
    expect(decorationOf(tester).color, AppColors.accent);
    await tester.sendEventToBinding(pointer.removePointer());
  });
}
