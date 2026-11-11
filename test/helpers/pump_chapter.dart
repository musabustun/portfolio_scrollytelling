import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portfolio_scrollytelling/theme/theme.dart';

/// Bölümü `app.dart`'taki gibi çizer: ekran [size] → tasarım boyutu, `ScreenUtilInit` →
/// `MaterialApp`; bölüm Sahne'deki gibi tam ekran. Ekran testin sonunda sıfırlanır.
Future<void> pumpChapter(
  WidgetTester tester,
  Widget chapter, {
  Size size = const Size(1440, 900),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ScreenUtilInit(
      designSize: AppBreakpoints.designSizeFor(size.width),
      minTextAdapt: true,
      fontSizeResolver: FontSizeResolvers.radius,
      builder: (_, _) => MaterialApp(
        theme: AppTheme.build(),
        home: Scaffold(body: SizedBox.expand(child: chapter)),
      ),
    ),
  );
}
