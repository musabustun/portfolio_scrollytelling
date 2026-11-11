import 'dart:async';
import 'dart:collection';

import 'package:flutter/widgets.dart';

import 'ai_config.dart';
import 'chat_message.dart';

/// Soru alır, cevabı parça parça akıtır; uygulamada `PersonaService.ask`.
typedef AskFn = Future<Stream<String>> Function(String question);

/// Sohbetin durumu: mesaj listesi ve süren cevap akışı (AGENTS.md §6); `ChatPanel` bunu dinler.
///
/// Panelin dışında, `app.dart`'taki site state'inde yaşar: ekran 720 eşiğini geçince (telefonu
/// çevirme) panel yeniden kurulur ama mesajlar durur, süren akış kesilmez. Sayfa yenilenince
/// sıfırlanır; kalıcılık yok.
class ChatController extends ChangeNotifier {
  ChatController({required this.ask});

  /// `PersonaService.ask`; `null` ise Firebase bağlı değil, [send] hiçbir şey göndermez.
  final AskFn? ask;

  final List<ChatMessage> _messages = [];
  bool _streaming = false;
  bool _disposed = false;

  /// Mesajlar eskiden yeniye; salt okunur görünüm.
  List<ChatMessage> get messages => UnmodifiableListView(_messages);

  /// Cevap akıyor mu; akarken [send] yeni soruyu kabul etmez.
  bool get isStreaming => _streaming;

  /// Firebase bağlı mı; değilse panel giriş kutusu yerine "bağlı değil" kartını gösterir.
  bool get isConnected => ask != null;

  /// Soruyu kırpar (boşluklar, [AiConfig.maxQuestionChars] harf), kullanıcı mesajını ve boş asistan
  /// mesajını ekler, cevabı arka planda asistan mesajına akıtır.
  ///
  /// Kabul edildiyse `true` (panel giriş kutusunu temizler); bağlı değilse, soru boşsa ya da akış
  /// sürüyorsa `false` ve hiçbir şey değişmez.
  bool send(String raw) {
    final ask = this.ask;
    final question = raw
        .trim()
        .characters
        .take(AiConfig.maxQuestionChars)
        .toString();
    if (ask == null || question.isEmpty || _streaming || _disposed) {
      return false;
    }
    _messages
      ..add(ChatMessage(role: ChatRole.user, text: question))
      ..add(const ChatMessage(role: ChatRole.assistant, text: ''));
    _streaming = true;
    notifyListeners();
    unawaited(_receive(ask, question));
    return true;
  }

  Future<void> _receive(AskFn ask, String question) async {
    try {
      final stream = await ask(question);
      await for (final chunk in stream) {
        if (_disposed) return;
        _setReply(_messages.last.text + chunk);
      }
    } catch (e) {
      // PersonaService her hatayı `PersonaException`'a çevirir; `toString()` tek satır Türkçe mesajdır.
      debugPrint('ChatController: $e');
      if (!_disposed) _setReply('$e'.split('\n').first);
    } finally {
      if (!_disposed) {
        _streaming = false;
        notifyListeners();
      }
    }
  }

  void _setReply(String text) {
    _messages.last = _messages.last.copyWith(text: text);
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
