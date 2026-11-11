// Gemini ayarları; model adı yalnızca burada geçer (AGENTS.md §2 karar 6, §6).
//
// `gemini-3.5-flash-lite`: Firebase AI Logic'in en ucuz genel modeli (yüksek hacim, düşük
// maliyet; faturalama gerekmez). Desteklenen modeller: firebase.google.com/docs/ai-logic/models.
// Maliyet öncelikli olduğu için aşağıdaki sınırlar dar tutulur.
// `temperature`, `topP`, `topK` verilmez: firebase_ai'de deprecated, Gemini 3+ yok sayar.

import 'package:firebase_ai/firebase_ai.dart';

/// Persona modelinin sabitleri; `PersonaService` okur.
abstract final class AiConfig {
  /// Firebase AI Logic model adı.
  static const String model = 'gemini-3.5-flash-lite';

  /// Tek cevabın üst sınırı (token); kısa cevap kuralını donanımla da sınırlar.
  static const int maxOutputTokens = 300;

  /// Oturum geçmişinde tutulan en fazla mesaj (user + model); aşınca en eskiler atılır.
  static const int maxHistory = 10;

  /// Ziyaretçi sorusunun üst sınırı, karakter (grapheme) cinsinden; uzun jailbreak metinlerini keser.
  static const int maxQuestionChars = 200;

  /// İçerik filtresi: dört kategoride orta ve üstü olasılıklı içerik engellenir
  /// (`BLOCK_MEDIUM_AND_ABOVE`); engellenen cevap panelde `aiBlocked` olur.
  ///
  /// `SafetySetting`'in `const` kurucusu yok, bu yüzden `final`. Üçüncü argüman (`method`)
  /// `null` kalır: Gemini Developer API (`FirebaseAI.googleAI()`) onu desteklemez, verilirse
  /// istek kurulurken hata atar.
  static final List<SafetySetting> safetySettings = List.unmodifiable([
    SafetySetting(HarmCategory.harassment, HarmBlockThreshold.medium, null),
    SafetySetting(HarmCategory.hateSpeech, HarmBlockThreshold.medium, null),
    SafetySetting(
      HarmCategory.sexuallyExplicit,
      HarmBlockThreshold.medium,
      null,
    ),
    SafetySetting(
      HarmCategory.dangerousContent,
      HarmBlockThreshold.medium,
      null,
    ),
  ]);
}
