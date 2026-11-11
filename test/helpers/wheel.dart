import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fare tekerleği: [at] noktasına gelir, dikeyde [dy] kaydırır, bir kare çizer ve işaretçiyi kaldırır
/// (gerçek olay, AGENTS.md §11.4).
Future<void> wheel(WidgetTester tester, Offset at, {double dy = 300}) async {
  final pointer = TestPointer(1, PointerDeviceKind.mouse);
  await tester.sendEventToBinding(pointer.hover(at));
  await tester.sendEventToBinding(pointer.scroll(Offset(0, dy)));
  await tester.pump();
  await tester.sendEventToBinding(pointer.removePointer());
}
