import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';

/// `assets/story.json` şema hatası; `message` katılımcıya aynen gösterilir.
@immutable
class StoryFormatException implements Exception {
  const StoryFormatException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// `#RRGGBB`, `RRGGBB` ya da `#AARRGGBB` metnini renge çevirir; geçersizse `null`.
Color? parseHexColor(String? hex) {
  final match = _hexPattern.firstMatch(hex?.trim() ?? '');
  if (match == null) return null;
  final digits = match.group(1)!;
  final value = int.parse(digits, radix: 16);
  const alphaMask = 0xFF000000;
  return Color(digits.length == 6 ? alphaMask | value : value);
}

final RegExp _hexPattern = RegExp(r'^#?([0-9a-fA-F]{6}|[0-9a-fA-F]{8})$');

/// Bölüm türü; `story.json` `chapters[].type` alanı.
enum ChapterType {
  video,
  text,
  projects,
  contact;

  /// `raw` metnini türe çevirir; eşleşme yoksa [StoryFormatException].
  static ChapterType parse(String raw, {required String chapterId}) {
    for (final type in values) {
      if (type.name == raw) return type;
    }
    final valid = values.map((type) => type.name).join(', ');
    throw StoryFormatException(
      'Bölüm "$chapterId": bilinmeyen type "$raw". Geçerli: $valid',
    );
  }
}

/// Senaryonun tamamı: `meta` ve sıralı bölümler; `assets/story.json`'un kökü.
@immutable
class Story {
  const Story({required this.meta, required this.chapters});

  factory Story.fromJson(Map<String, dynamic> json) {
    const where = 'story.json';
    final meta = Meta.fromJson(
      _require<Map<String, dynamic>>(json, 'meta', where),
    );
    final chapters = _objectList(
      json,
      'chapters',
      where,
      (item, i) => Chapter.fromJson(item, index: i),
    );
    if (chapters.isEmpty) {
      throw const StoryFormatException(
        'story.json: "chapters" en az bir bölüm içermeli',
      );
    }
    final seenIds = <String>{};
    for (var i = 0; i < chapters.length; i++) {
      final id = chapters[i].id;
      if (!seenIds.add(id)) {
        throw StoryFormatException(
          'chapters[$i]: id "$id" tekrar ediyor; her bölümün id\'si benzersiz '
          'olmalı',
        );
      }
    }
    return Story(meta: meta, chapters: chapters);
  }

  final Meta meta;
  final List<Chapter> chapters;

  /// Her bölümün `scrollLength`'i, bölüm sırasıyla (`ScrollProgress` girdisi).
  List<double> get scrollLengths =>
      chapters.map((chapter) => chapter.scrollLength).toList(growable: false);
}

/// Site geneli bilgiler: başlık, sahip, selamlama ve isteğe bağlı iki renk.
@immutable
class Meta {
  const Meta({
    required this.title,
    required this.owner,
    required this.tagline,
    this.accent,
    this.background,
  });

  factory Meta.fromJson(Map<String, dynamic> json) {
    const where = 'meta';
    return Meta(
      title: _require<String>(json, 'title', where),
      owner: _require<String>(json, 'owner', where),
      tagline: _require<String>(json, 'tagline', where),
      accent: _optional<String>(json, 'accent', where),
      background: _optional<String>(json, 'background', where),
    );
  }

  final String title;
  final String owner;
  final String tagline;

  /// Ham hex metinleri; geçersizse [accentColor] / [backgroundColor] `null` döner ve varsayılan
  /// renk kalır.
  final String? accent;
  final String? background;

  Color? get accentColor => parseHexColor(accent);
  Color? get backgroundColor => parseHexColor(background);
}

/// Tek bölüm; `type`'a göre `video`/`poster`, `body`, `projects` ya da `links` zorunludur.
///
/// `video` bölümünde isteğe bağlı `videoMobile`/`posterMobile` (9:16) çifti telefonda oynar
/// ([videoFor], [posterFor]); biri verilirse diğeri de zorunludur.
@immutable
class Chapter {
  const Chapter({
    required this.id,
    required this.title,
    required this.type,
    required this.scrollLength,
    this.video,
    this.poster,
    this.videoMobile,
    this.posterMobile,
    this.body,
    this.overlays = const [],
    this.projects = const [],
    this.links = const [],
  });

  factory Chapter.fromJson(Map<String, dynamic> json, {required int index}) {
    final id = _require<String>(json, 'id', 'chapters[$index]');
    final where = 'chapters[$index] ("$id")';
    final title = _require<String>(json, 'title', where);
    final type = ChapterType.parse(
      _require<String>(json, 'type', where),
      chapterId: id,
    );
    final scrollLength = _require<num>(json, 'scrollLength', where).toDouble();
    if (scrollLength <= 0) {
      throw StoryFormatException('$where: "scrollLength" 0\'dan büyük olmalı');
    }
    final chapter = Chapter(
      id: id,
      title: title,
      type: type,
      scrollLength: scrollLength,
      video: _optional<String>(json, 'video', where),
      poster: _optional<String>(json, 'poster', where),
      videoMobile: _nonBlank(_optional<String>(json, 'videoMobile', where)),
      posterMobile: _nonBlank(_optional<String>(json, 'posterMobile', where)),
      body: _optional<String>(json, 'body', where),
      overlays: _objectList(
        json,
        'overlays',
        where,
        (item, _) => TextOverlay.fromJson(item, chapterId: id),
      ),
      projects: _objectList(
        json,
        'projects',
        where,
        (item, i) => Project.fromJson(item, where: '$where projects[$i]'),
      ),
      links: _objectList(
        json,
        'links',
        where,
        (item, i) => ContactLink.fromJson(item, where: '$where links[$i]'),
      ),
    );
    final requiredByType = switch (type) {
      ChapterType.video => {'video': chapter.video, 'poster': chapter.poster},
      ChapterType.text => {'body': chapter.body},
      ChapterType.projects => {'projects': chapter.projects},
      ChapterType.contact => {'links': chapter.links},
    };
    for (final MapEntry(:key, :value) in requiredByType.entries) {
      if (_isBlank(value)) {
        throw StoryFormatException(
          'chapters[$index] ("$id", type ${type.name}): "$key" zorunlu',
        );
      }
    }
    if (type == ChapterType.video &&
        (chapter.videoMobile == null) != (chapter.posterMobile == null)) {
      throw StoryFormatException(
        '$where: "videoMobile" ve "posterMobile" birlikte verilmeli',
      );
    }
    return chapter;
  }

  final String id;
  final String title;
  final ChapterType type;

  /// Bölümün kaydırma uzunluğu, viewport yüksekliği cinsinden (> 0).
  final double scrollLength;
  final String? video;
  final String? poster;

  /// Telefon için dikey (9:16) video ve posteri; yoksa `video` kırpılarak kullanılır. Boş metin
  /// `null` sayılır.
  final String? videoMobile;
  final String? posterMobile;
  final String? body;
  final List<TextOverlay> overlays;
  final List<Project> projects;
  final List<ContactLink> links;

  /// Ekrana göre oynatılacak video: mobilde [videoMobile] varsa o, yoksa ve masaüstünde [video].
  String? videoFor({required bool mobile}) =>
      mobile ? (videoMobile ?? video) : video;

  /// [videoFor] ile aynı seçim, poster için: mobilde [posterMobile] varsa o, yoksa [poster].
  String? posterFor({required bool mobile}) =>
      mobile ? (posterMobile ?? poster) : poster;
}

/// Video üstü metin; bölüm `progress`'i story.json `at: [from, to]` aralığındayken görünür.
@immutable
class TextOverlay {
  const TextOverlay({
    required this.from,
    required this.to,
    this.title,
    this.body,
  });

  factory TextOverlay.fromJson(
    Map<String, dynamic> json, {
    required String chapterId,
  }) {
    if (json['at'] case [final num from, final num to]
        when 0 <= from && from < to && to <= 1) {
      final where = 'Bölüm "$chapterId" overlay';
      return TextOverlay(
        from: from.toDouble(),
        to: to.toDouble(),
        title: _optional<String>(json, 'title', where),
        body: _optional<String>(json, 'body', where),
      );
    }
    throw StoryFormatException(
      'Bölüm "$chapterId": overlay "at" [from, to] 0..1 arası ve from < to '
      'olmalı',
    );
  }

  final double from;
  final double to;
  final String? title;
  final String? body;

  /// Bölüm [progress]'indeki opaklık (AGENTS.md §10.6): aralık dışında 0; aralığın ilk ve son
  /// [fade] payında doğrusal 0→1 / 1→0, arada 1. Pay sıfırsa aralık boyunca 1.
  ///
  /// `from <= 0` ise giriş fade'i, `to >= 1` ise çıkış fade'i atlanır: kapak açılışta görünsün,
  /// son overlay video sonunda kalsın.
  double opacityAt(double progress, {double fade = 0.1}) {
    if (progress < from || progress > to) return 0;
    final edge = (to - from) * fade;
    if (edge <= 0) return 1;
    final double opacity;
    if (from > 0 && progress < from + edge) {
      opacity = (progress - from) / edge;
    } else if (to < 1 && progress > to - edge) {
      opacity = (to - progress) / edge;
    } else {
      opacity = 1;
    }
    return opacity.clamp(0.0, 1.0);
  }
}

/// `projects` bölümündeki tek proje; `highlights`, `url` ve `links` isteğe bağlıdır, `url` ile
/// `links` birlikte de verilebilir.
@immutable
class Project {
  const Project({
    required this.name,
    required this.description,
    this.highlights = const [],
    this.tags = const [],
    this.url,
    this.links = const [],
  });

  /// `url` doluysa güvenli şema denetiminden geçer ([_safeUrl]); `null` ya da boşsa aynen kalır.
  factory Project.fromJson(Map<String, dynamic> json, {required String where}) {
    final url = _optional<String>(json, 'url', where);
    return Project(
      name: _require<String>(json, 'name', where),
      description: _require<String>(json, 'description', where),
      highlights: _stringList(json, 'highlights', where),
      tags: _stringList(json, 'tags', where),
      url: url == null || _isBlank(url) ? url : _safeUrl(url, where),
      links: _objectList(
        json,
        'links',
        where,
        (item, i) => ContactLink.fromJson(item, where: '$where links[$i]'),
      ),
    );
  }

  final String name;
  final String description;

  /// Öne çıkan kısa maddeler; açık panelde satır satır çizilir (masaüstü). Yoksa ya da `null` ise
  /// boş liste.
  final List<String> highlights;

  final List<String> tags;

  /// Tek, etiketsiz bağlantı; kartta "Projeyi aç →" olarak çizilir.
  final String? url;

  /// Etiketli ek bağlantılar (ör. "App Store", "Google Play"); her biri ayrı pill (çoksa masaüstünde
  /// link satırı). Yoksa ya da `null` ise boş liste; `contact`'ın aksine boş liste hata değildir.
  final List<ContactLink> links;
}

/// Etiketli tek bağlantı: `contact` bölümü ve proje kartı bağlantısı (e-posta, GitHub, App Store vb.).
@immutable
class ContactLink {
  const ContactLink({required this.label, required this.url});

  /// `url` zorunludur ve güvenli şema denetiminden geçer ([_safeUrl]).
  factory ContactLink.fromJson(
    Map<String, dynamic> json, {
    required String where,
  }) => ContactLink(
    label: _require<String>(json, 'label', where),
    url: _safeUrl(_require<String>(json, 'url', where), where),
  );

  final String label;
  final String url;
}

/// `json[key]` yoksa ya da `T` değilse [StoryFormatException].
T _require<T>(Map<String, dynamic> json, String key, String where) {
  final Object? value = json[key];
  if (value is T && value != null) return value;
  throw StoryFormatException('$where: "$key" eksik ya da tipi yanlış');
}

/// `json[key]` yoksa `null`; var ama `T` değilse [StoryFormatException].
T? _optional<T>(Map<String, dynamic> json, String key, String where) {
  final Object? value = json[key];
  if (value is T?) return value;
  throw StoryFormatException('$where: "$key" tipi yanlış');
}

/// `json[key]` nesne listesini `parse` ile çevirir; yoksa boş liste.
List<T> _objectList<T>(
  Map<String, dynamic> json,
  String key,
  String where,
  T Function(Map<String, dynamic> item, int index) parse,
) {
  final items = _optional<List<dynamic>>(json, key, where) ?? const [];
  return List<T>.unmodifiable([
    for (var i = 0; i < items.length; i++)
      if (items[i] case final Map<String, dynamic> item)
        parse(item, i)
      else
        throw StoryFormatException(
          '$where: "$key[$i]" bir nesne ({ ... }) olmalı',
        ),
  ]);
}

/// `json[key]` metin listesi; yoksa boş liste.
List<String> _stringList(Map<String, dynamic> json, String key, String where) {
  final items = _optional<List<dynamic>>(json, key, where) ?? const [];
  if (items.any((item) => item is! String)) {
    throw StoryFormatException('$where: "$key" yalnızca metin içermeli');
  }
  return List<String>.unmodifiable(items);
}

/// Bağlantının şemasını denetler: yalnızca `https:`, `http:` ve `mailto:` geçer (büyük/küçük harf
/// duyarsız); dönen değer baştaki ve sondaki boşluktan kırpılmıştır.
///
/// İzin listesidir: `javascript:`, `data:` gibi şemalar da, şemasız yol da
/// [StoryFormatException] olur; böylece `story.json`'dan tıklanınca kod çalıştıran bir link geçmez.
String _safeUrl(String url, String where) {
  final trimmed = url.trim();
  final lower = trimmed.toLowerCase();
  if (_allowedUrlSchemes.any(lower.startsWith)) return trimmed;
  throw StoryFormatException(
    '$where: "url" yalnızca https, http ya da mailto olabilir',
  );
}

const List<String> _allowedUrlSchemes = ['https:', 'http:', 'mailto:'];

/// Boş ya da yalnızca boşluktan ibaret metni `null`'a indirir (isteğe bağlı yol alanları).
String? _nonBlank(String? text) => _isBlank(text) ? null : text;

bool _isBlank(Object? value) => switch (value) {
  null => true,
  final String text => text.trim().isEmpty,
  final List<Object?> list => list.isEmpty,
  _ => false,
};
