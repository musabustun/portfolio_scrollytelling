import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portfolio_scrollytelling/story/story.dart';
import 'package:portfolio_scrollytelling/story/story_loader.dart';

/// Şema testleri için sabit örnek senaryo: `assets/story.json`'un yapısal kopyası,
/// içeriğinden bağımsız. Gerçek asset değişince bu dosyadaki değer testleri kırılmaz.
const String _fixtureJson = r'''
{
  "meta": {
    "title": "Örnek — Geliştirici",
    "owner": "Örnek",
    "tagline": "Selamlama",
    "accent": "#C8F04E",
    "background": "#0B0D12"
  },
  "chapters": [
    {
      "id": "acilis",
      "type": "video",
      "title": "Kapak",
      "scrollLength": 4,
      "video": "video/a.mp4",
      "poster": "video/a.jpg",
      "videoMobile": "video/a_mobile.mp4",
      "posterMobile": "video/a_mobile.jpg",
      "overlays": [
        { "at": [0.0, 0.25], "title": "Kapak", "body": "Gövde" },
        { "at": [0.35, 0.6], "body": "Gövde" },
        { "at": [0.7, 1.0], "body": "Gövde" }
      ]
    },
    {
      "id": "ben-kimim",
      "type": "text",
      "title": "Ben kimim?",
      "scrollLength": 1.5,
      "body": "Gövde **vurgu**."
    },
    {
      "id": "isler",
      "type": "video",
      "title": "İşler",
      "scrollLength": 4,
      "video": "video/b.mp4",
      "poster": "video/b.jpg",
      "overlays": [
        { "at": [0.0, 0.3], "title": "Başlık", "body": "Gövde" },
        { "at": [0.45, 0.8], "body": "Gövde" }
      ]
    },
    {
      "id": "projeler",
      "type": "projects",
      "title": "Projeler",
      "scrollLength": 2,
      "projects": [
        {
          "name": "Proje 1",
          "description": "Açıklama",
          "tags": ["Flutter", "Firebase"],
          "url": "https://example.com"
        },
        {
          "name": "Proje 2",
          "description": "Açıklama",
          "tags": ["Dart"],
          "url": null
        },
        {
          "name": "Proje 3",
          "description": "Açıklama",
          "tags": ["Web"],
          "url": null
        }
      ]
    },
    {
      "id": "nasil-calisiyorum",
      "type": "text",
      "title": "Nasıl çalışıyorum?",
      "scrollLength": 1.5,
      "body": "Gövde"
    },
    {
      "id": "iletisim",
      "type": "contact",
      "title": "İletişim",
      "scrollLength": 1,
      "body": "Gövde",
      "links": [
        { "label": "E-posta", "url": "mailto:ornek@example.com" },
        { "label": "GitHub", "url": "https://github.com/ornek" },
        { "label": "LinkedIn", "url": "https://linkedin.com/in/ornek" }
      ]
    }
  ]
}
''';

/// [_fixtureJson]'un taze, değiştirilebilir kopyası (her çağrıda yeniden ayrıştırılır).
Map<String, dynamic> _sampleJson() =>
    jsonDecode(_fixtureJson) as Map<String, dynamic>;

/// Metin `null` değil ve boşluktan ibaret değil.
bool _filled(String? text) => text != null && text.trim().isNotEmpty;

Map<String, dynamic> _chapter(Map<String, dynamic> json, int index) =>
    (json['chapters'] as List<dynamic>)[index] as Map<String, dynamic>;

/// Fixture'daki projeler bölümünün (`chapters[3]`) [index]'inci projesi.
Map<String, dynamic> _project(Map<String, dynamic> json, int index) =>
    (_chapter(json, 3)['projects'] as List<dynamic>)[index]
        as Map<String, dynamic>;

/// Fixture'daki iletişim bölümünün (`chapters[5]`) [index]'inci bağlantısı.
Map<String, dynamic> _contactLink(Map<String, dynamic> json, int index) =>
    (_chapter(json, 5)['links'] as List<dynamic>)[index]
        as Map<String, dynamic>;

/// İzin verilen bağlantı şemaları; gerçek `story.json` duman testi okur.
const List<String> _safeSchemes = ['https:', 'http:', 'mailto:'];

/// [StoryFormatException] fırlatılmalı ve mesaj tüm `parts`'ı içermeli.
Matcher _throwsStoryFormat(List<String> parts) => throwsA(
  isA<StoryFormatException>().having(
    (e) => e.message,
    'message',
    allOf([for (final part in parts) contains(part)]),
  ),
);

/// `loadString`'i verilen metinle (ya da hatayla) yanıtlayan sahte bundle.
class _FakeBundle extends CachingAssetBundle {
  _FakeBundle(this.content, {this.error});

  final String content;
  final Object? error;

  @override
  Future<ByteData> load(String key) async =>
      ByteData.sublistView(utf8.encode(await loadString(key)));

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    if (error case final Object error) throw error;
    return content;
  }
}

/// Story modeli: sabit fixture ile değer ve şema hatası testleri, gerçek `assets/story.json`
/// için yapısal duman testi, overlay opaklığı ve StoryLoader.
void main() {
  group('Story.fromJson — fixture', () {
    late final Story story;
    setUpAll(() => story = Story.fromJson(_sampleJson()));

    test('bölümler, sıra ve scrollLengths', () {
      expect(story.chapters.map((c) => c.id), [
        'acilis',
        'ben-kimim',
        'isler',
        'projeler',
        'nasil-calisiyorum',
        'iletisim',
      ]);
      expect(story.chapters.map((c) => c.type), [
        ChapterType.video,
        ChapterType.text,
        ChapterType.video,
        ChapterType.projects,
        ChapterType.text,
        ChapterType.contact,
      ]);
      expect(story.scrollLengths, <double>[4, 1.5, 4, 2, 1.5, 1]);
    });

    test('meta renkleri', () {
      expect(story.meta.accentColor, const Color(0xFFC8F04E));
      expect(story.meta.backgroundColor, const Color(0xFF0B0D12));
    });

    test('overlay, proje ve bağlantı listeleri', () {
      final intro = story.chapters[0];
      expect(intro.overlays.length, 3);
      expect(intro.overlays[0].from, 0.0);
      expect(intro.overlays[0].to, 0.25);
      expect(intro.overlays[1].title, isNull);
      expect(intro.video, 'video/a.mp4');
      expect(intro.poster, 'video/a.jpg');

      final projects = story.chapters[3].projects;
      expect(projects.length, 3);
      expect(projects[0].tags, ['Flutter', 'Firebase']);
      expect(projects[0].url, 'https://example.com');
      expect(projects[1].url, isNull);
      expect(projects[2].url, isNull);

      expect(story.chapters[5].links.length, 3);
      expect(story.chapters[5].links[1].label, 'GitHub');
    });

    test('bilinmeyen anahtar yok sayılır, hata vermez', () {
      final json = _sampleJson();
      ((_chapter(json, 3)['projects'] as List<dynamic>)[0]
              as Map<String, dynamic>)['bilinmeyen'] =
          'değer';
      final first = Story.fromJson(json).chapters[3].projects[0];
      expect(first.name, 'Proje 1');
      expect(first.url, 'https://example.com');
    });

    test('videoFor / posterFor: mobilde varsa dikey video, yoksa video', () {
      final intro = story.chapters[0];
      final work = story.chapters[2];
      expect(intro.videoMobile, 'video/a_mobile.mp4');
      expect(intro.posterMobile, 'video/a_mobile.jpg');
      expect(work.videoMobile, isNull);
      expect(work.posterMobile, isNull);

      expect(intro.videoFor(mobile: true), intro.videoMobile);
      expect(intro.posterFor(mobile: true), intro.posterMobile);
      expect(work.videoFor(mobile: true), 'video/b.mp4');
      expect(work.posterFor(mobile: true), 'video/b.jpg');
      for (final c in [intro, work]) {
        expect(c.videoFor(mobile: false), c.video);
        expect(c.posterFor(mobile: false), c.poster);
      }
    });

    test('masaüstünde videoMobile yok sayılır', () {
      const chapter = Chapter(
        id: 'x',
        title: 'X',
        type: ChapterType.video,
        scrollLength: 1,
        video: 'video/a.mp4',
        poster: 'video/a.jpg',
        videoMobile: 'video/a_mobile.mp4',
        posterMobile: 'video/a_mobile.jpg',
      );
      expect(chapter.videoFor(mobile: false), 'video/a.mp4');
      expect(chapter.posterFor(mobile: false), 'video/a.jpg');
      expect(chapter.videoFor(mobile: true), 'video/a_mobile.mp4');
      expect(chapter.posterFor(mobile: true), 'video/a_mobile.jpg');
    });

    test('listeler değiştirilemez', () {
      expect(() => story.chapters.removeLast(), throwsUnsupportedError);
      expect(() => story.chapters[0].overlays.clear(), throwsUnsupportedError);
    });
  });

  group('Story.fromJson — şema hataları', () {
    test('bilinmeyen type → bölüm id\'si ve "type" içeren mesaj', () {
      final json = _sampleJson();
      _chapter(json, 0)['type'] = 'gif';
      expect(
        () => Story.fromJson(json),
        _throwsStoryFormat(['acilis', 'type', 'gif']),
      );
    });

    test('scrollLength eksik → chapters[ ve scrollLength', () {
      final json = _sampleJson();
      _chapter(json, 2).remove('scrollLength');
      expect(
        () => Story.fromJson(json),
        _throwsStoryFormat(['chapters[2]', 'scrollLength']),
      );
    });

    test('scrollLength sıfır ya da negatif → hata', () {
      final json = _sampleJson();
      for (final invalid in <num>[0, -1.5]) {
        _chapter(json, 1)['scrollLength'] = invalid;
        expect(
          () => Story.fromJson(json),
          _throwsStoryFormat(['chapters[1]', 'scrollLength']),
        );
      }
    });

    test('video tipinde poster yok → hata', () {
      final json = _sampleJson();
      _chapter(json, 0).remove('poster');
      expect(
        () => Story.fromJson(json),
        _throwsStoryFormat(['chapters[0]', 'video', '"poster" zorunlu']),
      );
    });

    test('videoMobile ya da posterMobile tek başına → hata', () {
      final noPoster = _sampleJson();
      _chapter(noPoster, 0).remove('posterMobile');
      expect(
        () => Story.fromJson(noPoster),
        _throwsStoryFormat(['chapters[0]', 'videoMobile', 'posterMobile']),
      );

      final noVideo = _sampleJson();
      _chapter(noVideo, 0).remove('videoMobile');
      expect(
        () => Story.fromJson(noVideo),
        _throwsStoryFormat(['chapters[0]', 'videoMobile', 'posterMobile']),
      );
    });

    test('boş videoMobile / posterMobile → null sayılır', () {
      final bothBlank = _sampleJson();
      _chapter(bothBlank, 0)
        ..['videoMobile'] = ''
        ..['posterMobile'] = '  ';
      final intro = Story.fromJson(bothBlank).chapters[0];
      expect(intro.videoMobile, isNull);
      expect(intro.posterMobile, isNull);
      expect(intro.videoFor(mobile: true), intro.video);

      final oneBlank = _sampleJson();
      _chapter(oneBlank, 0)['posterMobile'] = '';
      expect(
        () => Story.fromJson(oneBlank),
        _throwsStoryFormat(['chapters[0]', 'videoMobile', 'posterMobile']),
      );
    });

    test('tipe göre zorunlu alanlar: text body, projects, contact links', () {
      final noBody = _sampleJson();
      _chapter(noBody, 1).remove('body');
      expect(() => Story.fromJson(noBody), _throwsStoryFormat(['"body"']));

      final noProjects = _sampleJson();
      _chapter(noProjects, 3)['projects'] = <dynamic>[];
      expect(
        () => Story.fromJson(noProjects),
        _throwsStoryFormat(['"projects"']),
      );

      final noLinks = _sampleJson();
      _chapter(noLinks, 5).remove('links');
      expect(() => Story.fromJson(noLinks), _throwsStoryFormat(['"links"']));
    });

    test('overlay "at" aralığı geçersiz → hata', () {
      final json = _sampleJson();
      final overlays = _chapter(json, 0)['overlays'] as List<dynamic>;
      (overlays[0] as Map<String, dynamic>)['at'] = <dynamic>[0.5, 0.2];
      expect(
        () => Story.fromJson(json),
        _throwsStoryFormat(['acilis', '"at"']),
      );
    });

    test('tekrar eden id → hata', () {
      final json = _sampleJson();
      _chapter(json, 4)['id'] = 'ben-kimim';
      expect(
        () => Story.fromJson(json),
        _throwsStoryFormat(['chapters[4]', 'ben-kimim']),
      );
    });

    test('boş chapters ve eksik meta alanı → hata', () {
      final noChapters = _sampleJson()..['chapters'] = <dynamic>[];
      expect(
        () => Story.fromJson(noChapters),
        _throwsStoryFormat(['"chapters"']),
      );

      final noTitle = _sampleJson();
      (noTitle['meta'] as Map<String, dynamic>).remove('title');
      expect(
        () => Story.fromJson(noTitle),
        _throwsStoryFormat(['meta', '"title"']),
      );
    });
  });

  group('Project.highlights — fixture', () {
    test('highlights yok ya da null → boş liste', () {
      final json = _sampleJson();
      _project(json, 1)['highlights'] = null;
      final projects = Story.fromJson(json).chapters[3].projects;
      expect(projects[0].highlights, isEmpty);
      expect(projects[1].highlights, isEmpty);
    });

    test('iki maddeli highlights → sırayla, değiştirilemez', () {
      final json = _sampleJson();
      _project(json, 0)['highlights'] = <dynamic>['Birinci madde', 'İkinci'];
      final first = Story.fromJson(json).chapters[3].projects[0];
      expect(first.highlights, ['Birinci madde', 'İkinci']);
      expect(() => first.highlights.clear(), throwsUnsupportedError);
    });

    test('highlights liste değil ya da metin dışı öğe → hata, mesajda yol', () {
      final notList = _sampleJson();
      _project(notList, 1)['highlights'] = 'Tek madde';
      expect(
        () => Story.fromJson(notList),
        _throwsStoryFormat(['projects[1]', '"highlights"']),
      );

      final notText = _sampleJson();
      _project(notText, 1)['highlights'] = <dynamic>['Madde', 2];
      expect(
        () => Story.fromJson(notText),
        _throwsStoryFormat(['projects[1]', '"highlights"']),
      );
    });
  });

  group('Project.links — fixture', () {
    test('links yok ya da null → boş liste, url aynen kalır', () {
      final json = _sampleJson();
      _project(json, 1)['links'] = null;
      final projects = Story.fromJson(json).chapters[3].projects;
      expect(projects[0].links, isEmpty);
      expect(projects[0].url, 'https://example.com');
      expect(projects[1].links, isEmpty);
      expect(projects[2].links, isEmpty);
    });

    test('iki öğeli links → etiket ve url sırayla, url ile birlikte', () {
      final json = _sampleJson();
      _project(json, 0)['links'] = <dynamic>[
        {'label': 'App Store', 'url': 'https://apps.example.com/a'},
        {'label': 'Google Play', 'url': 'https://play.example.com/a'},
      ];
      final first = Story.fromJson(json).chapters[3].projects[0];
      expect(first.url, 'https://example.com');
      expect(first.links.map((link) => link.label), [
        'App Store',
        'Google Play',
      ]);
      expect(first.links.map((link) => link.url), [
        'https://apps.example.com/a',
        'https://play.example.com/a',
      ]);
      expect(() => first.links.clear(), throwsUnsupportedError);
    });

    test('links liste değil ya da öğesinde url eksik → hata, mesajda yol', () {
      final notList = _sampleJson();
      _project(notList, 1)['links'] = 'https://apps.example.com/a';
      expect(
        () => Story.fromJson(notList),
        _throwsStoryFormat(['projects[1]', '"links"']),
      );

      final noUrl = _sampleJson();
      _project(noUrl, 1)['links'] = <dynamic>[
        {'label': 'App Store', 'url': 'https://apps.example.com/a'},
        {'label': 'Google Play'},
      ];
      expect(
        () => Story.fromJson(noUrl),
        _throwsStoryFormat(['projects[1]', 'links[1]', '"url"']),
      );

      final notObject = _sampleJson();
      _project(notObject, 1)['links'] = <dynamic>['https://apps.example.com/a'];
      expect(
        () => Story.fromJson(notObject),
        _throwsStoryFormat(['projects[1]', '"links[0]"']),
      );
    });
  });

  group('Bağlantı şeması — fixture', () {
    const unsafe = [
      'javascript:alert(1)',
      'data:text/html,<script>alert(1)</script>',
      ' JavaScript:alert(1)',
      'vbscript:msgbox(1)',
      'github.com/ornek',
    ];
    const schemeError = 'yalnızca https, http ya da mailto';

    test(
      'iletişim linkinde tehlikeli ya da eksik şema → hata, mesajda yol',
      () {
        for (final url in unsafe) {
          final json = _sampleJson();
          _contactLink(json, 0)['url'] = url;
          expect(
            () => Story.fromJson(json),
            _throwsStoryFormat([
              'chapters[5]',
              'links[0]',
              '"url"',
              schemeError,
            ]),
            reason: url,
          );
        }
      },
    );

    test('proje url\'sinde ve proje links\'inde tehlikeli şema → hata', () {
      for (final url in unsafe) {
        final projectUrl = _sampleJson();
        _project(projectUrl, 0)['url'] = url;
        expect(
          () => Story.fromJson(projectUrl),
          _throwsStoryFormat(['projects[0]', '"url"', schemeError]),
          reason: url,
        );

        final projectLink = _sampleJson();
        _project(projectLink, 1)['links'] = <dynamic>[
          {'label': 'Site', 'url': url},
        ];
        expect(
          () => Story.fromJson(projectLink),
          _throwsStoryFormat(['projects[1]', 'links[0]', '"url"', schemeError]),
          reason: url,
        );
      }
    });

    test('https, http, mailto geçer; büyük harf kabul, boşluk kırpılır', () {
      final json = _sampleJson();
      _contactLink(json, 0)['url'] = '  MAILTO:ornek@example.com';
      _contactLink(json, 1)['url'] = 'HTTPS://github.com/ornek ';
      _contactLink(json, 2)['url'] = 'http://example.com';
      _project(json, 0)['url'] = ' https://example.com/proje';
      final story = Story.fromJson(json);
      expect(story.chapters[5].links.map((link) => link.url), [
        'MAILTO:ornek@example.com',
        'HTTPS://github.com/ornek',
        'http://example.com',
      ]);
      expect(story.chapters[3].projects[0].url, 'https://example.com/proje');
    });

    test('proje url null ya da boş → dokunulmaz', () {
      final json = _sampleJson();
      _project(json, 2)['url'] = '';
      final projects = Story.fromJson(json).chapters[3].projects;
      expect(projects[1].url, isNull);
      expect(projects[2].url, '');
    });
  });

  group('assets/story.json — yapısal duman testi', () {
    late final Story story;

    // Gerçek asset; şema hatasında StoryFormatException mesajıyla grup düşer.
    // Yalnızca yapı denetlenir, hiçbir içerik değeri (id, renk, yol, metin) beklenmez.
    setUpAll(() {
      final json = jsonDecode(
        File('assets/story.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      story = Story.fromJson(json);
    });

    void expectWebFile(String path, String reason) =>
        expect(File('web/$path').existsSync(), isTrue, reason: reason);

    test('meta: title, owner, tagline dolu; renkler null ya da Color', () {
      expect(_filled(story.meta.title), isTrue, reason: 'meta.title boş');
      expect(_filled(story.meta.owner), isTrue, reason: 'meta.owner boş');
      expect(_filled(story.meta.tagline), isTrue, reason: 'meta.tagline boş');
      expect(story.meta.accentColor, anyOf(isNull, isA<Color>()));
      expect(story.meta.backgroundColor, anyOf(isNull, isA<Color>()));
    });

    test('bölümler: boş değil, id dolu ve benzersiz, title dolu, '
        'scrollLength > 0', () {
      expect(story.chapters, isNotEmpty);
      final ids = story.chapters.map((c) => c.id).toList();
      expect(ids.toSet().length, ids.length, reason: 'tekrar eden id: $ids');
      for (final c in story.chapters) {
        expect(_filled(c.id), isTrue, reason: 'boş id: $ids');
        expect(_filled(c.title), isTrue, reason: '${c.id} title boş');
        expect(c.scrollLength, greaterThan(0), reason: '${c.id} scrollLength');
      }
    });

    test('video bölümleri: video/*.mp4 ve video/*.jpg web/ altında var', () {
      for (final c in story.chapters.where(
        (c) => c.type == ChapterType.video,
      )) {
        final video = c.video!;
        final poster = c.poster!;
        expect(video, startsWith('video/'), reason: '${c.id} video yolu');
        expect(video, endsWith('.mp4'), reason: '${c.id} video uzantısı');
        expect(poster, startsWith('video/'), reason: '${c.id} poster yolu');
        expect(poster, endsWith('.jpg'), reason: '${c.id} poster uzantısı');
        expectWebFile(video, 'story.json ${c.id} videosu web/ altında yok');
        expectWebFile(poster, 'story.json ${c.id} posteri web/ altında yok');
      }
    });

    test('video bölümleri: videoMobile/posterMobile varsa video/*.mp4 ve '
        'video/*.jpg web/ altında var', () {
      for (final c in story.chapters.where(
        (c) => c.type == ChapterType.video,
      )) {
        if (c.videoMobile case final video?) {
          expect(video, startsWith('video/'), reason: '${c.id} videoMobile');
          expect(video, endsWith('.mp4'), reason: '${c.id} videoMobile uzantı');
          expectWebFile(
            video,
            'story.json ${c.id} videoMobile web/ altında yok',
          );
        }
        if (c.posterMobile case final poster?) {
          expect(poster, startsWith('video/'), reason: '${c.id} posterMobile');
          expect(
            poster,
            endsWith('.jpg'),
            reason: '${c.id} posterMobile uzantı',
          );
          expectWebFile(
            poster,
            'story.json ${c.id} posterMobile web/ altında yok',
          );
        }
      }
    });

    test('overlay\'ler: 0 <= from < to <= 1, title ya da body dolu', () {
      for (final c in story.chapters) {
        for (final (i, o) in c.overlays.indexed) {
          final where = '${c.id} overlays[$i]';
          expect(o.from, greaterThanOrEqualTo(0), reason: where);
          expect(o.from, lessThan(o.to), reason: where);
          expect(o.to, lessThanOrEqualTo(1), reason: where);
          expect(
            _filled(o.title) || _filled(o.body),
            isTrue,
            reason: '$where: title ya da body dolu olmalı',
          );
        }
      }
    });

    test('projects bölümleri: proje ve ad dolu', () {
      for (final c in story.chapters.where(
        (c) => c.type == ChapterType.projects,
      )) {
        expect(c.projects, isNotEmpty, reason: '${c.id} projects boş');
        for (final (i, p) in c.projects.indexed) {
          expect(_filled(p.name), isTrue, reason: '${c.id} projects[$i] name');
        }
      }
    });

    test('contact bölümleri: bağlantı listesi, label ve url dolu', () {
      for (final c in story.chapters.where(
        (c) => c.type == ChapterType.contact,
      )) {
        expect(c.links, isNotEmpty, reason: '${c.id} links boş');
        for (final (i, link) in c.links.indexed) {
          final where = '${c.id} links[$i]';
          expect(_filled(link.label), isTrue, reason: '$where label boş');
          expect(_filled(link.url), isTrue, reason: '$where url boş');
        }
      }
    });

    test('tüm bağlantılar https, http ya da mailto', () {
      final urls = [
        for (final c in story.chapters) ...[
          for (final link in c.links) link.url,
          for (final p in c.projects) ...[
            if (p.url case final url? when _filled(url)) url,
            for (final link in p.links) link.url,
          ],
        ],
      ];
      for (final url in urls) {
        expect(
          _safeSchemes.any(url.toLowerCase().startsWith),
          isTrue,
          reason: url,
        );
      }
    });
  });

  test('parseHexColor', () {
    expect(parseHexColor('#C8F04E'), const Color(0xFFC8F04E));
    expect(parseHexColor('C8F04E'), const Color(0xFFC8F04E));
    expect(parseHexColor('#80C8F04E'), const Color(0x80C8F04E));
    expect(parseHexColor(''), isNull);
    expect(parseHexColor(null), isNull);
    expect(parseHexColor('#ZZZ'), isNull);
    expect(parseHexColor('#C8F04'), isNull);
    expect(parseHexColor('-C8F04'), isNull);
  });

  group('TextOverlay.opacityAt — [0.2, 0.6], kenar payı %10 (0.04)', () {
    const overlay = TextOverlay(from: 0.2, to: 0.6);
    const edge = 0.04;

    test('aralık dışı → 0', () {
      expect(overlay.opacityAt(0), 0);
      expect(overlay.opacityAt(0.1), 0);
      expect(overlay.opacityAt(0.7), 0);
      expect(overlay.opacityAt(1), 0);
    });

    test('tam from → 0', () {
      expect(overlay.opacityAt(0.2), 0);
    });

    test('from + kenar payı → 1', () {
      expect(overlay.opacityAt(0.2 + edge), closeTo(1, 1e-9));
    });

    test('orta → 1', () {
      expect(overlay.opacityAt(0.4), 1);
    });

    test('tam to → 0', () {
      expect(overlay.opacityAt(0.6), 0);
    });

    test('to − kenar payının yarısı → 0.5', () {
      expect(overlay.opacityAt(0.6 - edge / 2), closeTo(0.5, 1e-9));
    });

    test('fade 0 → aralık boyunca 1, dışında 0', () {
      expect(overlay.opacityAt(0.2, fade: 0), 1);
      expect(overlay.opacityAt(0.6, fade: 0), 1);
      expect(overlay.opacityAt(0.61, fade: 0), 0);
    });

    test('from 0 → giriş fade\'i yok, çıkış fade\'i var', () {
      const cover = TextOverlay(from: 0, to: 0.25);
      expect(cover.opacityAt(0), 1);
      expect(cover.opacityAt(0.25), 0);
    });

    test('to 1 → çıkış fade\'i yok, giriş fade\'i var', () {
      const last = TextOverlay(from: 0.7, to: 1);
      expect(last.opacityAt(1), 1);
      expect(last.opacityAt(0.7), 0);
    });
  });

  group('StoryLoader.load', () {
    final logs = <String>[];
    late DebugPrintCallback originalDebugPrint;

    setUp(() {
      logs.clear();
      originalDebugPrint = debugPrint;
      debugPrint = (message, {wrapWidth}) => logs.add(message ?? '');
    });
    tearDown(() => debugPrint = originalDebugPrint);

    test('geçerli JSON → StoryLoaded', () async {
      final bundle = _FakeBundle(_fixtureJson);
      final result = await StoryLoader.load(bundle: bundle);
      expect(result, isA<StoryLoaded>());
      expect((result as StoryLoaded).story.chapters.length, 6);
      expect(logs, isEmpty);
    });

    test('bozuk JSON → StoryLoadFailed, mesajda JSON, loglanır', () async {
      final result = await StoryLoader.load(bundle: _FakeBundle('{"meta": '));
      expect(
        result,
        isA<StoryLoadFailed>().having(
          (r) => r.message,
          'message',
          contains('JSON'),
        ),
      );
      expect(logs, hasLength(1));
    });

    test('kök nesne değil → StoryLoadFailed', () async {
      final result = await StoryLoader.load(bundle: _FakeBundle('[1, 2]'));
      expect(result, isA<StoryLoadFailed>());
    });

    test('şema hatası → StoryFormatException mesajı aynen', () async {
      final json = _sampleJson();
      _chapter(json, 0)['type'] = 'gif';
      final result = await StoryLoader.load(
        bundle: _FakeBundle(jsonEncode(json)),
      );
      expect(
        result,
        isA<StoryLoadFailed>().having(
          (r) => r.message,
          'message',
          startsWith('Bölüm "acilis"'),
        ),
      );
    });

    test('asset okunamıyor → StoryLoadFailed, fırlatmaz', () async {
      final result = await StoryLoader.load(
        bundle: _FakeBundle('', error: FlutterError('asset yok')),
      );
      expect(
        result,
        isA<StoryLoadFailed>().having(
          (r) => r.message,
          'message',
          contains('okunamadı'),
        ),
      );
    });
  });
}
