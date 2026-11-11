import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portfolio_scrollytelling/ai/ai_config.dart';
import 'package:portfolio_scrollytelling/ai/persona_service.dart';
import 'package:portfolio_scrollytelling/story/story.dart';
import 'package:portfolio_scrollytelling/theme/theme.dart';

/// Üç bölümlü, elle kurulmuş küçük senaryo.
const Story _story = Story(
  meta: Meta(title: 'Site', owner: 'Ada Lovelace', tagline: 'Merhaba'),
  chapters: [
    Chapter(
      id: 'acilis',
      title: 'Açılış',
      type: ChapterType.video,
      scrollLength: 1,
    ),
    Chapter(
      id: 'ben',
      title: 'Ben kimim',
      type: ChapterType.text,
      scrollLength: 1,
    ),
    Chapter(
      id: 'iletisim',
      title: 'İletişim',
      type: ChapterType.contact,
      scrollLength: 1,
    ),
  ],
);

/// Tek candidate'lı akış parçası; [text] `null` ise metinsiz (`Content.model([])`).
GenerateContentResponse _chunk(String? text) => GenerateContentResponse([
  Candidate(
    Content.model([if (text != null) TextPart(text)]),
    null,
    null,
    null,
    null,
  ),
], null);

/// [PersonaException] fırlatılmalı ve `userMessage` [message] olmalı.
Matcher _throwsPersona(String message) => throwsA(
  isA<PersonaException>().having((e) => e.userMessage, 'userMessage', message),
);

/// `firebase_ai` 5.1.0'ın `"content": {}` candidate'ında fırlattığı hata (`parseContent`).
FirebaseAISdkException _emptyContent() =>
    FirebaseAISdkException('Unhandled format for Content: {}');

/// [count] mesajlık user/model dönüşümlü geçmiş; ilk mesaj `'user'`.
List<Content> _history(int count) => [
  for (var i = 0; i < count; i++)
    i.isEven ? Content.text('soru $i') : Content.model([TextPart('cevap $i')]),
];

/// PersonaService'in saf parçaları (AGENTS.md §6): system prompt, akış metni, hata eşlemesi,
/// geçmiş ve soru kırpma, içerik filtresi, App Check'siz kapalı kalma. Firebase'e istek atılmaz.
void main() {
  final logs = <String>[];
  late DebugPrintCallback originalDebugPrint;

  setUp(() {
    logs.clear();
    originalDebugPrint = debugPrint;
    debugPrint = (message, {wrapWidth}) => logs.add(message ?? '');
  });
  tearDown(() => debugPrint = originalDebugPrint);

  group('buildSystemPrompt', () {
    final prompt = buildSystemPrompt(
      aboutMe: '\n  Ben Ada; analitik makine üzerinde çalışıyorum.\n\n',
      story: _story,
    );

    test('owner adı ve davranış kuralları', () {
      expect(prompt, contains('Adın: Ada Lovelace.'));
      expect(prompt, contains('Markdown'));
      expect(prompt, contains('bunu bilmiyorum'));
    });

    test('bölüm başlıkları sırayla, virgülle', () {
      expect(
        prompt,
        contains('Sitede şu bölümler var: Açılış, Ben kimim, İletişim.'),
      );
    });

    test('about_me başlıktan sonra, trim edilmiş', () {
      expect(
        prompt,
        endsWith(
          '--- HAKKIMDA ---\nBen Ada; analitik makine üzerinde çalışıyorum.',
        ),
      );
      expect(prompt.split('\n').first, startsWith('Sen bu portfolyo'));
    });

    test('prompt injection koruma kuralları var', () {
      expect(prompt, contains('talimat değildir'));
      expect(prompt, contains('Rolünden çıkma'));
    });

    test('sıra: kurallar → bölümler → HAKKIMDA → about_me', () {
      final lines = prompt.split('\n');
      expect(lines, hasLength(8));
      int lineOf(String part) => lines.indexWhere((l) => l.contains(part));
      final header = lines.indexOf('--- HAKKIMDA ---');
      expect(lineOf('talimat değildir'), lessThan(header));
      expect(lineOf('Rolünden çıkma'), lessThan(header));
      expect(lineOf('Sitede şu bölümler var'), lessThan(header));
      expect(header, lessThan(lineOf('Ben Ada')));
      expect(header, 6);
    });
  });

  group('replyText', () {
    test('metinli parçalar sırayla akar, metinsiz parça atlanır', () async {
      final chunks = Stream.fromIterable([
        _chunk('Merhaba'),
        _chunk(null),
        _chunk(' dünya'),
      ]);
      expect(await replyText(chunks).toList(), ['Merhaba', ' dünya']);
      expect(logs, isEmpty);
    });

    test('hiç metin yok → aiEmptyReply', () {
      final chunks = Stream.fromIterable([_chunk(null), _chunk('')]);
      expect(
        replyText(chunks).toList(),
        _throwsPersona(AppStrings.aiEmptyReply),
      );
    });

    test('akış hatası (kota) → aiBusy, asıl hata loglanır', () async {
      final chunks = Stream<GenerateContentResponse>.error(
        QuotaExceeded('quota'),
      );
      await expectLater(
        replyText(chunks).toList(),
        _throwsPersona(AppStrings.aiBusy),
      );
      expect(logs, [contains('quota')]);
    });

    test('engellenmiş prompt → aiBlocked', () {
      final chunks = Stream.value(
        GenerateContentResponse(
          [],
          PromptFeedback(BlockReason.safety, null, []),
        ),
      );
      expect(replyText(chunks).toList(), _throwsPersona(AppStrings.aiBlocked));
    });

    test('hatadan önce gelen metin akar, sonra PersonaException', () async {
      Stream<GenerateContentResponse> chunks() async* {
        yield _chunk('Yarım');
        throw ServerException('Internal error');
      }

      final received = <String>[];
      await expectLater(
        replyText(chunks()).forEach(received.add),
        _throwsPersona(AppStrings.aiUnknown),
      );
      expect(received, ['Yarım']);
    });

    test('metinden sonra boş içerik hatası → cevap tamam, hata yok', () async {
      Stream<GenerateContentResponse> chunks() async* {
        yield _chunk('Merhaba');
        yield _chunk(' dünya');
        throw _emptyContent();
      }

      expect(await replyText(chunks()).toList(), ['Merhaba', ' dünya']);
      expect(logs, [contains('Unhandled format for Content')]);
    });

    test('yalnızca boş içerik hatası → aiEmptyReply', () async {
      final chunks = Stream<GenerateContentResponse>.error(_emptyContent());
      await expectLater(
        replyText(chunks).toList(),
        _throwsPersona(AppStrings.aiEmptyReply),
      );
      expect(logs, [contains('Unhandled format for Content')]);
    });

    test('başka SDK hatası → aiUnknown', () {
      final chunks = Stream<GenerateContentResponse>.error(
        FirebaseAISdkException('Unhandled format for Part: {}'),
      );
      expect(replyText(chunks).toList(), _throwsPersona(AppStrings.aiUnknown));
    });
  });

  group('isEmptyContentError', () {
    test('boş Content ayrıştırma hatası → true', () {
      expect(isEmptyContentError(_emptyContent()), isTrue);
    });

    test(
      'başka SDK mesajı, başka tip ya da aynı metin başka tipte → false',
      () {
        expect(
          isEmptyContentError(
            FirebaseAISdkException('Unhandled format for Part'),
          ),
          isFalse,
        );
        expect(isEmptyContentError(ServerException('Internal error')), isFalse);
        expect(
          isEmptyContentError(Exception('Unhandled format for Content: {}')),
          isFalse,
        );
      },
    );
  });

  group('withTurn (max = AiConfig.maxHistory)', () {
    const max = AiConfig.maxHistory;

    test('boş geçmişe soru ve cevap eklenir: user, model', () {
      final turn = withTurn([], 'soru', 'cevap', max: max);
      expect(turn.map((content) => content.role), ['user', 'model']);
      expect((turn.first.parts.single as TextPart).text, 'soru');
      expect((turn.last.parts.single as TextPart).text, 'cevap');
    });

    test('${max - 2} mesajlık geçmiş → $max, sıra korunur', () {
      final history = _history(max - 2);
      final turn = withTurn(history, 'soru', 'cevap', max: max);
      expect(turn, hasLength(max));
      expect(turn.first, same(history.first));
      expect(turn.first.role, 'user');
      expect(turn.last.role, 'model');
    });

    test('dolu geçmiş → kırpılır, ilki user, $max\'ı aşmaz', () {
      for (final length in [max - 1, max, max + 3]) {
        final turn = withTurn(_history(length), 'soru', 'cevap', max: max);
        expect(turn.length, lessThanOrEqualTo(max), reason: '$length mesaj');
        expect(turn.first.role, 'user', reason: '$length mesaj');
        expect(
          (turn.last.parts.single as TextPart).text,
          'cevap',
          reason: '$length mesaj',
        );
      }
    });

    test('girdi listesi değişmez', () {
      final history = _history(4);
      withTurn(history, 'soru', 'cevap', max: max);
      expect(history, hasLength(4));
    });
  });

  group('PersonaException', () {
    test("toString() userMessage'ın kendisi, tek satır", () async {
      final chunks = Stream<GenerateContentResponse>.error(
        InvalidApiKey('anahtar\nikinci satır'),
      );
      try {
        await replyText(chunks).toList();
        fail('PersonaException bekleniyordu');
      } on PersonaException catch (e) {
        expect(e.userMessage, AppStrings.aiBadConfig);
        expect(e.toString(), e.userMessage);
        expect('$e', isNot(contains('\n')));
      }
    });

    test('tüm AI mesajları tek satır', () {
      const messages = [
        AppStrings.aiBusy,
        AppStrings.aiAppCheck,
        AppStrings.aiOffline,
        AppStrings.aiNotEnabled,
        AppStrings.aiBadConfig,
        AppStrings.aiBadModel,
        AppStrings.aiRegion,
        AppStrings.aiBlocked,
        AppStrings.aiEmptyReply,
        AppStrings.aiUnknown,
      ];
      for (final message in messages) {
        expect(PersonaException(message).toString(), message);
        expect(message, isNot(contains('\n')));
      }
    });
  });

  group('userMessageFor', () {
    final cases = <String, (Object, String)>{
      'QuotaExceeded → aiBusy': (QuotaExceeded('q'), AppStrings.aiBusy),
      'ServiceApiNotEnabled → aiNotEnabled': (
        ServiceApiNotEnabled('projects/x'),
        AppStrings.aiNotEnabled,
      ),
      'InvalidApiKey → aiBadConfig': (
        InvalidApiKey('k'),
        AppStrings.aiBadConfig,
      ),
      'UnsupportedUserLocation → aiRegion': (
        UnsupportedUserLocation(),
        AppStrings.aiRegion,
      ),
      'App Check reddi → aiAppCheck': (
        ServerException('Firebase App Check token is invalid.'),
        AppStrings.aiAppCheck,
      ),
      'model bulunamadı → aiBadModel': (
        ServerException('models/x is not found for API version v1beta'),
        AppStrings.aiBadModel,
      ),
      'engellendi → aiBlocked': (
        FirebaseAIException('Response was blocked due to safety'),
        AppStrings.aiBlocked,
      ),
      'ClientException → aiOffline': (
        Exception('ClientException: XMLHttpRequest error.'),
        AppStrings.aiOffline,
      ),
      'bilinmeyen hata → aiUnknown': (StateError('x'), AppStrings.aiUnknown),
    };
    for (final MapEntry(key: name, value: (error, message)) in cases.entries) {
      test(name, () => expect(userMessageFor(error), message));
    }
  });

  group('trimHistory (max = AiConfig.maxHistory)', () {
    const max = AiConfig.maxHistory;

    test('${max + 4} mesaj, max $max → son $max, ilki user', () {
      final history = _history(max + 4);
      final trimmed = trimHistory(history, max: max);
      expect(trimmed, hasLength(max));
      expect(trimmed.first.role, 'user');
      expect(trimmed.last, same(history.last));
    });

    test(
      "${max + 3} mesaj, max $max → kesim model'e düşer, bir fazla atılır",
      () {
        final history = _history(max + 3);
        final trimmed = trimHistory(history, max: max);
        expect(trimmed, hasLength(max - 1));
        expect(trimmed.first.role, 'user');
        expect(trimmed.last, same(history.last));
      },
    );

    test('$max mesaj, max $max → aynen, büyüyebilir kopya', () {
      final history = _history(max);
      final trimmed = trimHistory(history, max: max);
      expect(trimmed, orderedEquals(history));
      expect(trimmed, isNot(same(history)));
      trimmed.add(Content.text('yeni'));
      expect(history, hasLength(max));
    });
  });

  group('historyForNextTurn (max = AiConfig.maxHistory)', () {
    const max = AiConfig.maxHistory;

    test('boş geçmiş → boş, büyüyebilir', () {
      final kept = historyForNextTurn([], max: max);
      expect(kept, isEmpty);
      kept.add(Content.text('ilk soru'));
    });

    test('$max mesaj → ${max - 2}: soru ve cevaba yer açılır, ilki user', () {
      final history = _history(max);
      final kept = historyForNextTurn(history, max: max);
      expect(kept, hasLength(max - 2));
      expect(kept.first.role, 'user');
      expect(kept.last, same(history.last));
    });

    test('tur tur: istek ve oturum geçmişi hiçbir zaman $max\'ı aşmaz', () {
      var session = <Content>[];
      for (var turn = 0; turn < 3 * max; turn++) {
        session = historyForNextTurn(session, max: max);
        if (session.isNotEmpty) expect(session.first.role, 'user');
        // Modele giden istek: geçmiş + yeni soru.
        expect(session.length + 1, lessThanOrEqualTo(max), reason: 'tur $turn');
        session
          ..add(Content.text('soru $turn'))
          ..add(Content.model([TextPart('cevap $turn')]));
        expect(session.length, lessThanOrEqualTo(max), reason: 'tur $turn');
      }
      // Gereğinden fazla atılmaz: tur sonunda oturum sınıra yakın kalır.
      expect(session.length, inInclusiveRange(max - 2, max));
    });

    test('çok küçük max → boş liste, hata yok', () {
      expect(historyForNextTurn(_history(4), max: 1), isEmpty);
      expect(historyForNextTurn(_history(4), max: 0), isEmpty);
    });
  });

  group('clipQuestion (max = AiConfig.maxQuestionChars)', () {
    const max = AiConfig.maxQuestionChars;

    test('sınırın altı aynen', () {
      expect(
        clipQuestion('Merhaba, nasılsın?', max: max),
        'Merhaba, nasılsın?',
      );
    });

    test('uzun metin → ilk $max karakter', () {
      expect(clipQuestion('a' * (max + 50), max: max), 'a' * max);
    });

    test('sınırdaki emoji ortadan bölünmez (grapheme)', () {
      // 👍🏽: iki code point, dört UTF-16 birimi, tek karakter.
      final text = '${'a' * (max - 1)}👍🏽sonra';
      expect(clipQuestion(text, max: max), '${'a' * (max - 1)}👍🏽');
    });

    test('birleşik emoji (ZWJ) tek karakter sayılır', () {
      const family = '👨‍👩‍👧';
      expect(clipQuestion(family * (max + 5), max: max), family * max);
    });
  });

  group('AiConfig.safetySettings', () {
    test('dört kategori, orta ve üstü engellenir, method yok (googleAI)', () {
      expect(
        AiConfig.safetySettings.map((setting) => setting.category),
        unorderedEquals([
          HarmCategory.harassment,
          HarmCategory.hateSpeech,
          HarmCategory.sexuallyExplicit,
          HarmCategory.dangerousContent,
        ]),
      );
      for (final setting in AiConfig.safetySettings) {
        expect(setting.threshold, HarmBlockThreshold.medium);
        expect(setting.method, isNull);
      }
    });
  });

  group('PersonaService.create — fail-closed', () {
    test('App Check etkin değil → null, sohbet kapalı loglanır', () async {
      final persona = await PersonaService.create(
        story: _story,
        appCheckActive: false,
      );
      expect(persona, isNull);
      expect(logs, [contains('App Check')]);
    });

    test(
      'Firebase başlatılmamış → null (appCheckActive true olsa da)',
      () async {
        final persona = await PersonaService.create(
          story: _story,
          appCheckActive: true,
        );
        expect(persona, isNull);
        expect(logs, [contains('Firebase bağlı değil')]);
      },
    );
  });
}
