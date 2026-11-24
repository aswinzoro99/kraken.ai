import 'package:material_ui/material_ui.dart';

import '../../core/haptics/haptics.dart';
import '../foundation/haptics_scope.dart';
import '../foundation/pressable.dart';
import '../theme/kraken_theme.dart';
import '../tokens/layout.dart';
import '../tokens/typography.dart';

enum ChatAuthor { kraken, me }

/// One chat bubble. Kraken's sit left on a soft grey; yours sit right in
/// blue. The last bubble of a run gets a small tail. Used by sign-in and, from
/// Phase 3, the agent chat.
class ChatBubble extends StatelessWidget {
  const ChatBubble({super.key, required this.author, required this.text, this.showAvatar = true});

  final ChatAuthor author;
  final String text;

  /// The last Kraken bubble in a run gets a tail.
  final bool showAvatar;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final width = MediaQuery.sizeOf(context).width;
    if (author == ChatAuthor.me) {
      return Align(
        alignment: Alignment.centerRight,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: width * 0.75),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: KSpace.sm),
            decoration: BoxDecoration(
              color: k.primary,
              borderRadius: const BorderRadius.only(
                topLeft: KRadius.bubble,
                topRight: KRadius.bubble,
                bottomLeft: KRadius.bubble,
                bottomRight: KRadius.sm,
              ),
            ),
            child: Semantics(
              label: 'You: $text',
              excludeSemantics: true,
              child: Text(text, style: KText.body.copyWith(color: k.onPrimary)),
            ),
          ),
        ),
      );
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: width * 0.82),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: KSpace.sm),
          decoration: BoxDecoration(
            color: k.surfaceMuted,
            borderRadius: BorderRadius.only(
              topLeft: KRadius.bubble,
              topRight: KRadius.bubble,
              bottomRight: KRadius.bubble,
              bottomLeft: showAvatar ? KRadius.sm : KRadius.bubble,
            ),
          ),
          child: Semantics(
            label: 'Kraken: $text',
            excludeSemantics: true,
            child: Text(text, style: KText.body.copyWith(color: k.ink)),
          ),
        ),
      ),
    );
  }
}

/// Kraken "typing": three bouncing dots. Still dots under reduced motion.
class TypingIndicator extends StatefulWidget {
  const TypingIndicator({super.key});

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    reduce ? _c.stop() : _c.repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return Semantics(
      label: 'Kraken is typing',
      liveRegion: true,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: k.surfaceMuted,
            borderRadius: const BorderRadius.only(
              topLeft: KRadius.bubble,
              topRight: KRadius.bubble,
              bottomRight: KRadius.bubble,
              bottomLeft: KRadius.sm,
            ),
          ),
          child: AnimatedBuilder(
            animation: _c,
            builder: (context, _) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < 3; i++) ...[
                  if (i > 0) const SizedBox(width: 4),
                  _dot(k.muted, (_c.value - i * 0.125) % 1),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _dot(Color color, double t) {
    // Rises and brightens in the first 40% of each cycle, like the design.
    final phase = t < 0.4 ? (t < 0.2 ? t / 0.2 : (0.4 - t) / 0.2) : 0.0;
    return Transform.translate(
      offset: Offset(0, -3 * phase),
      child: Opacity(
        opacity: _c.isAnimating ? 0.25 + 0.75 * phase : 0.6,
        child: Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
      ),
    );
  }
}

/// The message box at the bottom of a chat, with a round send button.
class ChatInputBar extends StatefulWidget {
  const ChatInputBar({
    super.key,
    required this.onSubmitted,
    required this.label,
    required this.placeholder,
    this.keyboardType = TextInputType.text,
    this.enabled = true,
    this.controller,
    this.autofillHints,
    this.textCapitalization = TextCapitalization.none,
    this.leading,
  });

  final ValueChanged<String> onSubmitted;

  /// Read by screen readers ("Email address").
  final String label;
  final String placeholder;
  final TextInputType keyboardType;
  final bool enabled;
  final TextEditingController? controller;
  final Iterable<String>? autofillHints;
  final TextCapitalization textCapitalization;

  /// Optional button left of the field, e.g. the mic in the agent chat.
  final Widget? leading;

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  late final TextEditingController _controller = widget.controller ?? TextEditingController();
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_changed);
  }

  void _changed() => setState(() {});

  @override
  void dispose() {
    _controller.removeListener(_changed);
    if (widget.controller == null) _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  bool get _canSend => widget.enabled && _controller.text.trim().isNotEmpty;

  void _send() {
    if (!_canSend) return;
    context.haptic(HapticKind.tap);
    widget.onSubmitted(_controller.text);
    _controller.clear();
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return Container(
      padding: EdgeInsets.fromLTRB(KSpace.md, KSpace.sm, KSpace.md, KSpace.sm + MediaQuery.paddingOf(context).bottom),
      color: k.background,
      child: Row(
        children: [
          if (widget.leading != null) ...[widget.leading!, const SizedBox(width: KSpace.xs)],
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focus,
              enabled: widget.enabled,
              keyboardType: widget.keyboardType,
              textCapitalization: widget.textCapitalization,
              autofillHints: widget.autofillHints,
              autocorrect: widget.keyboardType == TextInputType.text,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _send(),
              style: KText.body.copyWith(color: k.ink),
              decoration: InputDecoration(
                labelText: null,
                hintText: widget.placeholder,
                hintStyle: KText.body.copyWith(color: k.placeholder),
                filled: true,
                fillColor: k.surfaceMuted,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: KSpace.lg, vertical: 11),
                border: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(KRadius.dock),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: const BorderRadius.all(KRadius.dock),
                  borderSide: BorderSide(color: k.line),
                ),
                semanticCounterText: widget.label,
              ),
            ),
          ),
          const SizedBox(width: KSpace.xs),
          KPressable(
            onTap: _canSend ? _send : null,
            enabled: _canSend,
            haptic: null,
            semanticLabel: 'Send',
            excludeChildSemantics: true,
            child: AnimatedContainer(
              duration: KMotion.of(context, KMotion.fast),
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: _canSend ? k.primary : k.surfaceMuted, shape: BoxShape.circle),
              child: Icon(Icons.arrow_upward_rounded, color: _canSend ? k.onPrimary : k.muted, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}
