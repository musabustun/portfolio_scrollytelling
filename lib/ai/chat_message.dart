import 'package:flutter/foundation.dart';

/// Sohbet mesajının sahibi: ziyaretçi ya da asistan.
enum ChatRole { user, assistant }

/// Tek sohbet mesajı (rol + metin); değişmez, cevap akarken `copyWith` ile büyütülür.
@immutable
class ChatMessage {
  const ChatMessage({required this.role, required this.text});

  final ChatRole role;
  final String text;

  bool get isUser => role == ChatRole.user;

  ChatMessage copyWith({String? text}) =>
      ChatMessage(role: role, text: text ?? this.text);
}
