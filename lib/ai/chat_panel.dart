import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/theme.dart';
import '../widgets/label_text.dart';
import '../widgets/pill_button.dart';
import '../widgets/tap_target.dart';
import '../widgets/typing_dots.dart';
import 'ai_config.dart';
import 'chat_controller.dart';
import 'chat_message.dart';

/// Kullanıcı balonunun panel genişliğine oranı (AGENTS.md §10.4 "sağda balon"); ölçü değil oran.
const double _bubbleWidthFactor = 0.8;

/// "💬 Sohbet" pill'i ve açılan sohbet paneli (AGENTS.md §10.4); [isOpen]'ı ve [controller]'ı dinler.
///
/// Pill masaüstünde sağ altta çizgili, mobilde sağ üstte dolu (alttaki kapak metinleriyle çakışmasın).
/// Mesajlar ve süren akış [controller]'da, panelin dışında yaşar: panel kapanıp açılınca ya da ekran
/// 720 eşiğini geçip panel yeniden kurulunca geçmiş kalır; sayfa yenilenince sıfırlanır.
/// Soru gönderildikten sonra cevabın ilk parçası gelene kadar asistan satırında "yazıyor" göstergesi
/// (`TypingDots`) durur.
/// Kapalıyken yalnızca pill hit-test'e girer; açıkken panel opaktır, tekerlek alttaki Ray'a sızmaz.
/// Bağlıyken giriş kutusunun altında yapay zekâ notu durur. Firebase bağlı değilse
/// ([ChatController.isConnected] `false`) giriş kutusu ve not yerine "bağlı değil" kartı çıkar.
class ChatPanel extends StatefulWidget {
  const ChatPanel({
    required this.isOpen,
    required this.controller,
    required this.owner,
    super.key,
  });

  final ValueNotifier<bool> isOpen;

  /// Mesajlar, akış durumu ve gönderim; sahibi `app.dart`'taki site state'idir, panel dispose etmez.
  final ChatController controller;

  /// story.json `meta.owner`; boş sohbetteki davet metninde geçer.
  final String owner;

  @override
  State<ChatPanel> createState() => _ChatPanelState();
}

class _ChatPanelState extends State<ChatPanel> {
  final TextEditingController _input = TextEditingController();
  final ScrollController _list = ScrollController();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_scrollToEnd);
    // Yeniden kurulan panel (ekran döndü) son mesajdan başlasın.
    _scrollToEnd();
  }

  @override
  void didUpdateWidget(ChatPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_scrollToEnd);
      widget.controller.addListener(_scrollToEnd);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_scrollToEnd);
    _input.dispose();
    _list.dispose();
    super.dispose();
  }

  /// Soru kabul edilirse kutu temizlenir; akış sürerken metin kutuda kalır.
  void _send(String raw) {
    if (widget.controller.send(raw)) _input.clear();
  }

  /// Liste yeni boyutunu karenin sonunda bilir; kaydırma o yüzden kare sonrasına ertelenir.
  /// `positions`: kapat-aç geçişinde iki panel kısa süre aynı controller'ı paylaşabilir.
  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      for (final position in _list.positions) {
        position.jumpTo(position.maxScrollExtent);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Mobilde nav gizli, sağ üst boş; alt kenar tam genişlikteki overlay metinlerinin yeri.
    final mobile = AppBreakpoints.isMobile;
    final corner = mobile ? Alignment.topRight : Alignment.bottomRight;
    return ValueListenableBuilder<bool>(
      valueListenable: widget.isOpen,
      builder: (context, open, _) => Padding(
        padding: EdgeInsets.all(AppSpacing.gutter),
        child: Align(
          alignment: corner,
          child: AnimatedSwitcher(
            duration: AppDurations.crossfadeOf(context),
            switchInCurve: AppDurations.crossfadeCurve,
            switchOutCurve: AppDurations.crossfadeCurve,
            layoutBuilder: _cornerLayout(corner),
            child: open
                ? ListenableBuilder(
                    key: const ValueKey<bool>(true),
                    listenable: widget.controller,
                    builder: (context, _) => _PanelFrame(
                      connected: widget.controller.isConnected,
                      owner: widget.owner,
                      messages: widget.controller.messages,
                      input: _input,
                      list: _list,
                      streaming: widget.controller.isStreaming,
                      onSend: _send,
                      onClose: () => widget.isOpen.value = false,
                    ),
                  )
                : PillButton(
                    key: const ValueKey<bool>(false),
                    label: AppStrings.chatButton,
                    semanticsLabel: AppStrings.openChat,
                    filled: mobile,
                    onTap: () => widget.isOpen.value = true,
                  ),
          ),
        ),
      ),
    );
  }

  /// Buton ↔ panel geçişinde ikisi de aynı köşeye yaslı kalır (varsayılan ortalar).
  static AnimatedSwitcherLayoutBuilder _cornerLayout(Alignment corner) =>
      (current, previous) =>
          Stack(alignment: corner, children: [...previous, ?current]);
}

/// Panel yüzeyi: masaüstünde 380×560 sağ altta, mobilde gutter içinde tam ekran; blur + yarı saydam `surface`.
class _PanelFrame extends StatelessWidget {
  const _PanelFrame({
    required this.connected,
    required this.owner,
    required this.messages,
    required this.input,
    required this.list,
    required this.streaming,
    required this.onSend,
    required this.onClose,
  });

  /// `false`: Firebase bağlı değil; liste ve giriş kutusu yerine kart.
  final bool connected;
  final String owner;
  final List<ChatMessage> messages;
  final TextEditingController input;
  final ScrollController list;
  final bool streaming;
  final ValueChanged<String> onSend;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final mobile = AppBreakpoints.isMobile;
    return SizedBox(
      width: mobile ? double.infinity : AppSizes.chatPanelWidth,
      height: mobile ? double.infinity : AppSizes.chatPanelHeight,
      // Opak: panelin her pikseli hit alır, tekerlek alttaki Ray'a geçmez (liste kısa olsa bile).
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerSignal: (_) {},
        child: ClipRRect(
          borderRadius: AppRadii.panel,
          child: BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: AppSizes.navBlurSigma,
              sigmaY: AppSizes.navBlurSigma,
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.surfaceGlass,
                borderRadius: AppRadii.panel,
                border: Border.all(
                  color: AppColors.border,
                  width: AppSizes.borderWidth,
                ),
              ),
              // TextField bir Material atası ister; panel Scaffold dışında da çalışsın.
              child: Material(
                type: MaterialType.transparency,
                child: Column(
                  children: [
                    _Header(onClose: onClose),
                    Expanded(
                      child: connected
                          ? _MessageList(
                              owner: owner,
                              messages: messages,
                              controller: list,
                              streaming: streaming,
                            )
                          : const _NotConnectedCard(),
                    ),
                    if (connected)
                      _Composer(
                        input: input,
                        streaming: streaming,
                        onSend: onSend,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Başlık şeridi: solda "SOHBET", sağda × kapat ikonu; altında `border` çizgi.
class _Header extends StatelessWidget {
  const _Header({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: AppColors.border,
            width: AppSizes.borderWidth,
          ),
        ),
      ),
      child: SizedBox(
        height: AppSizes.chatHeaderHeight,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const LabelText(AppStrings.chatTitle, color: AppColors.text),
              // Tooltip yok: Material ister ve kendi süre sabitlerini taşır; etiket Semantics'te.
              TapTarget(
                label: AppStrings.close,
                onTap: onClose,
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.xs),
                  child: Icon(
                    Icons.close,
                    size: AppSizes.sendButtonSize / 2,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Mesaj listesi; boşken ortada [owner] (`meta.owner`) adıyla davet metni.
class _MessageList extends StatelessWidget {
  const _MessageList({
    required this.owner,
    required this.messages,
    required this.controller,
    required this.streaming,
  });

  final String owner;
  final List<ChatMessage> messages;
  final ScrollController controller;

  /// Cevap akıyor mu; akarken son (asistan) mesajı hâlâ boşsa yerinde gösterge çizilir.
  final bool streaming;

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.md),
          child: Text(
            AppStrings.chatEmptyFor(owner),
            style: AppTextStyles.body.copyWith(color: AppColors.textMuted),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return ListView.builder(
      controller: controller,
      padding: EdgeInsets.all(AppSpacing.md),
      itemCount: messages.length,
      itemBuilder: (context, i) => Padding(
        padding: EdgeInsets.only(top: i == 0 ? 0 : AppSpacing.sm),
        child: _Bubble(
          message: messages[i],
          // Controller soruyla birlikte boş asistan mesajı ekler; ilk parça gelene kadar o boştur.
          typing:
              streaming && i == messages.length - 1 && messages[i].text.isEmpty,
        ),
      ),
    );
  }
}

/// Firebase bağlı değilken liste ve giriş kutusu yerine ortada duran kart
/// (AGENTS.md §6 "Firebase yoksa").
class _NotConnectedCard extends StatelessWidget {
  const _NotConnectedCard();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.md),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.surfaceRaised,
            borderRadius: AppRadii.panel,
          ),
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const LabelText(
                  AppStrings.notConnectedTitle,
                  color: AppColors.text,
                ),
                SizedBox(height: AppSpacing.xs),
                Text(
                  AppStrings.notConnectedBody,
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.textMuted,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Kullanıcı: sağda `surfaceRaised` balon; asistan: solda balonsuz düz metin (AGENTS.md §10.4).
/// Asistan cevabının ilk parçası beklenirken ([typing]) metin yerine `TypingDots`.
class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, this.typing = false});

  final ChatMessage message;

  /// Asistan mesajı boş ve akış sürüyor: gösterge çizilir.
  final bool typing;

  @override
  Widget build(BuildContext context) {
    final text = Text(message.text, style: AppTextStyles.body);
    if (!message.isUser) {
      return Align(
        alignment: Alignment.centerLeft,
        // Boş metin bir satır yüksekliğini tutar: ilk parça gelince satır zıplamaz.
        child: typing
            ? Stack(
                alignment: AlignmentDirectional.centerStart,
                children: [text, const TypingDots()],
              )
            : text,
      );
    }
    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: AppSizes.chatPanelWidth * _bubbleWidthFactor,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.surfaceRaised,
            borderRadius: AppRadii.panel,
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            child: text,
          ),
        ),
      ),
    );
  }
}

/// Giriş şeridi: üstte `border` çizgi; giriş satırı ve hemen altında yapay zekâ notu.
class _Composer extends StatelessWidget {
  const _Composer({
    required this.input,
    required this.streaming,
    required this.onSend,
  });

  final TextEditingController input;
  final bool streaming;
  final ValueChanged<String> onSend;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      border: Border(
        top: BorderSide(color: AppColors.border, width: AppSizes.borderWidth),
      ),
    ),
    child: Padding(
      padding: EdgeInsets.all(AppSpacing.sm),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _InputRow(input: input, streaming: streaming, onSend: onSend),
          SizedBox(height: AppSpacing.xs),
          const _Disclaimer(),
        ],
      ),
    ),
  );
}

/// Giriş satırı: pill metin kutusu + `accent` daire gönder; akış sürerken gönder pasif.
class _InputRow extends StatelessWidget {
  const _InputRow({
    required this.input,
    required this.streaming,
    required this.onSend,
  });

  final TextEditingController input;
  final bool streaming;
  final ValueChanged<String> onSend;

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder pill(Color color) => OutlineInputBorder(
      borderRadius: AppRadii.pill,
      borderSide: BorderSide(color: color, width: AppSizes.borderWidth),
    );
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: input,
            // `input`: telefonda da ≥ 16 px; iOS odaklanınca sayfayı yakınlaştırmasın.
            style: AppTextStyles.input,
            cursorColor: context.accent,
            textInputAction: TextInputAction.send,
            onSubmitted: onSend,
            // Soru sınırı kutuda da görünsün; PersonaService ayrıca kırpar.
            inputFormatters: [
              LengthLimitingTextInputFormatter(AiConfig.maxQuestionChars),
            ],
            // Boş `onEditingComplete`: Enter sonrası odak kutuda kalır; gönderim
            // `onSubmitted`'da.
            onEditingComplete: () {},
            decoration: InputDecoration(
              hintText: AppStrings.chatHint,
              hintStyle: AppTextStyles.input.copyWith(
                color: AppColors.textMuted,
              ),
              isDense: true,
              contentPadding: EdgeInsets.symmetric(
                horizontal: AppSizes.buttonPaddingX,
                vertical: AppSpacing.xs,
              ),
              filled: true,
              fillColor: AppColors.surfaceRaised,
              border: pill(AppColors.border),
              enabledBorder: pill(AppColors.border),
              focusedBorder: pill(context.accent),
            ),
          ),
        ),
        SizedBox(width: AppSpacing.xs),
        _SendButton(onTap: streaming ? null : () => onSend(input.text)),
      ],
    );
  }
}

/// Yapay zekâ notu ([AppStrings.chatDisclaimer]): ortalı, `button` boyutunda `textMuted`, en fazla
/// iki satır.
class _Disclaimer extends StatelessWidget {
  const _Disclaimer();

  @override
  Widget build(BuildContext context) => Text(
    AppStrings.chatDisclaimer,
    style: AppTextStyles.button.copyWith(color: AppColors.textMuted),
    textAlign: TextAlign.center,
    maxLines: 2,
    overflow: TextOverflow.ellipsis,
  );
}

/// `accent` daire içinde yukarı ok; [onTap] `null` ise pasif (gri, tıklanmaz).
///
/// `TapTarget` değil: semantics'te etkin/pasif durumu var, pasifken imleç değişmez.
class _SendButton extends StatelessWidget {
  const _SendButton({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: AppStrings.send,
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: SizedBox.square(
            dimension: AppSizes.sendButtonSize,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: enabled ? context.accent : AppColors.surfaceRaised,
              ),
              child: Center(
                child: Icon(
                  Icons.arrow_upward,
                  size: AppSizes.sendButtonSize / 2,
                  color: enabled ? AppColors.onAccent : AppColors.textMuted,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
