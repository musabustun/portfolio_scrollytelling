import 'package:flutter/services.dart';
import 'package:portfolio_scrollytelling/theme/theme.dart';

/// Gerçek Inter'i (dört ağırlık) yükler; `setUpAll(loadInterFont)` ile çağrılır.
///
/// Test fontu ~2 kat geniş, sığma yanlış ölçülür. Yan etki: dosyadaki tüm testler Inter ile çizilir.
Future<void> loadInterFont() async {
  final loader = FontLoader(AppFonts.family);
  for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
    loader.addFont(rootBundle.load('assets/fonts/Inter-$weight.ttf'));
  }
  await loader.load();
}
