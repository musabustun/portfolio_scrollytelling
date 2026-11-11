import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';

import 'ai/persona_service.dart';
import 'app.dart';
import 'firebase_options.dart';
import 'story/story_loader.dart';

/// reCAPTCHA Enterprise (Fraud Defense) site key; Google Cloud konsolu → Security → reCAPTCHA'dan
/// alınır; `--dart-define=RECAPTCHA_SITE_KEY=...` ile verilir, dosyaya yazılmaz.
const String _recaptchaSiteKey = String.fromEnvironment('RECAPTCHA_SITE_KEY');

/// Bootstrap: binding, Firebase (varsa), story yüklemesi, persona, runApp. Widget tanımı yok
/// (AGENTS.md §11.1). Story `runApp` öncesi beklenir: ilk kare story hazırken çizilir, `index.html`
/// yükleme ekranı o ana kadar kalır. Persona App Check etkin değilse (Firebase yok, site key boş ya
/// da başlatma hatası) ya da story bozuksa `null`; sohbet paneli o zaman "Firebase bağlı değil"
/// kartını gösterir (fail-closed).
/// Semantics ağacı baştan açılır: web'de Lighthouse ve ekran okuyucu "erişilebilirliği
/// etkinleştir" adımı olmadan görür (handle saklanmaz, uygulama ömrü boyunca açık kalır).
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized().ensureSemantics();
  final appCheckActive = await _initFirebase();
  final story = await StoryLoader.load();
  final persona = story is StoryLoaded
      ? await PersonaService.create(
          story: story.story,
          appCheckActive: appCheckActive,
        )
      : null;
  runApp(App(story: story, persona: persona));
}

/// Placeholder ise Firebase'e dokunmaz; değilse initializeApp + (site key varsa) App Check.
///
/// Yalnızca App Check başarıyla etkinleştiyse `true` döner; placeholder, boş site key ya da hata
/// `false`'tur ve sohbet kapalı kalır. Hata loglanır, uygulama devam eder: scroll deneyimi
/// Firebase'siz de tam çalışır (AGENTS.md §6).
Future<bool> _initFirebase() async {
  final options = DefaultFirebaseOptions.currentPlatform;
  if (options.apiKey == 'PLACEHOLDER') {
    debugPrint('Firebase bağlı değil — README adım 2');
    return false;
  }
  try {
    await Firebase.initializeApp(options: options);
    if (_recaptchaSiteKey.isEmpty) {
      debugPrint('RECAPTCHA_SITE_KEY boş — App Check etkinleştirilmedi');
      return false;
    }
    await FirebaseAppCheck.instance.activate(
      providerWeb: ReCaptchaEnterpriseProvider(_recaptchaSiteKey),
    );
    return true;
  } on Object catch (e) {
    debugPrint('Firebase başlatılamadı: $e');
    return false;
  }
}
