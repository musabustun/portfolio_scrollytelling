import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'story.dart';

/// [StoryLoader.load] sonucu: [StoryLoaded] ya da [StoryLoadFailed].
sealed class StoryLoadResult {
  const StoryLoadResult();
}

/// `story.json` okundu ve şemaya uyuyor.
final class StoryLoaded extends StoryLoadResult {
  const StoryLoaded(this.story);

  final Story story;
}

/// `story.json` okunamadı ya da bozuk; `message` hata kutusunda gösterilir.
final class StoryLoadFailed extends StoryLoadResult {
  const StoryLoadFailed(this.message);

  final String message;
}

/// `assets/story.json`'u okuyup [Story]'ye çevirir; asla fırlatmaz.
abstract final class StoryLoader {
  static const String assetPath = 'assets/story.json';

  /// `bundle` verilmezse `rootBundle`; her hata loglanır ve [StoryLoadFailed] döner.
  static Future<StoryLoadResult> load({AssetBundle? bundle}) async {
    try {
      final raw = await (bundle ?? rootBundle).loadString(assetPath);
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        throw const StoryFormatException(
          'story.json: kök bir JSON nesnesi ({ ... }) olmalı',
        );
      }
      return StoryLoaded(Story.fromJson(decoded));
    } on StoryFormatException catch (e) {
      return _fail(e.message);
    } on FormatException catch (e) {
      return _fail('story.json geçerli JSON değil: ${e.message}');
    } on Object catch (e) {
      return _fail('story.json okunamadı: $e');
    }
  }

  static StoryLoadFailed _fail(String message) {
    debugPrint('Story yüklenemedi: $message');
    return StoryLoadFailed(message);
  }
}
