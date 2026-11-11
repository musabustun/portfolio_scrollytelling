import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portfolio_scrollytelling/widgets/tap_target.dart';

/// TapTarget: gerçek tıklama (AGENTS.md §11.4), el imleci, semantics etiketi ve seçim durumu.
void main() {
  late int taps;

  setUp(() => taps = 0);

  Future<void> pumpTarget(WidgetTester tester, {bool? selected}) =>
      tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: TapTarget(
                label: 'GitHub',
                selected: selected,
                onTap: () => taps++,
                child: const Text('GITHUB →'),
              ),
            ),
          ),
        ),
      );

  testWidgets('tıklama onTap\'i bir kez çağırır', (tester) async {
    await pumpTarget(tester);
    await tester.tap(find.text('GITHUB →'));
    expect(taps, 1);
  });

  testWidgets('opak: yazının dışındaki boşluk da tıklanır', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: TapTarget(
              label: 'Boşluk',
              onTap: () => taps++,
              child: const SizedBox.square(dimension: 80),
            ),
          ),
        ),
      ),
    );
    await tester.tapAt(tester.getCenter(find.byType(TapTarget)));
    expect(taps, 1);
  });

  testWidgets('fare üstündeyken el imleci', (tester) async {
    await pumpTarget(tester);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: tester.getCenter(find.text('GITHUB →')));
    await tester.pump();
    expect(
      RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(1),
      SystemMouseCursors.click,
    );
  });

  testWidgets('semantics: yalnızca etiket okunur, buton; seçim durumu yok', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpTarget(tester);
    final node = find.bySemanticsLabel('GitHub');
    expect(node, findsOneWidget);
    expect(find.bySemanticsLabel('GITHUB →'), findsNothing);
    expect(
      tester.getSemantics(node),
      isSemantics(
        label: 'GitHub',
        isButton: true,
        hasTapAction: true,
        hasSelectedState: false,
      ),
    );
    handle.dispose();
  });

  testWidgets('semantics: ekran okuyucunun dokunma eylemi onTap\'i çağırır', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpTarget(tester);
    final node = find.semantics.byLabel('GitHub');
    expect(
      tester.getSemantics(find.bySemanticsLabel('GitHub')),
      isSemantics(hasTapAction: true),
    );
    tester.semantics.tap(node);
    await tester.pump();
    expect(taps, 1);
    handle.dispose();
  });

  testWidgets('semantics: selected verilirse seçili / seçili değil okunur', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpTarget(tester, selected: true);
    expect(
      tester.getSemantics(find.bySemanticsLabel('GitHub')),
      isSemantics(isButton: true, hasSelectedState: true, isSelected: true),
    );
    await pumpTarget(tester, selected: false);
    expect(
      tester.getSemantics(find.bySemanticsLabel('GitHub')),
      isSemantics(isButton: true, hasSelectedState: true, isSelected: false),
    );
    handle.dispose();
  });
}
