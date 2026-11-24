import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../theme/kraken_theme.dart';
import '../tokens/typography.dart';

/// A labelled text field: the label above (always visible, never just a
/// placeholder), a soft filled box, and an [error] under it that screen
/// readers announce.
class KTextField extends StatelessWidget {
  const KTextField({
    super.key,
    required this.label,
    this.controller,
    this.hint,
    this.error,
    this.keyboardType,
    this.autofillHints,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.onChanged,
    this.onSubmitted,
    this.autofocus = false,
    this.enabled = true,
    this.maxLength,
    this.inputFormatters,
    this.large = false,
  });

  final String label;
  final TextEditingController? controller;
  final String? hint;
  final String? error;
  final TextInputType? keyboardType;
  final Iterable<String>? autofillHints;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;
  final bool enabled;
  final int? maxLength;
  final List<TextInputFormatter>? inputFormatters;

  /// Big, centred, spaced-out text, for a one-time code.
  final bool large;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    OutlineInputBorder border(Color color, [double width = 1.5]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: color, width: width),
    );
    final error = this.error;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: KText.label.copyWith(color: k.ink)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          autofillHints: autofillHints,
          textInputAction: textInputAction,
          textCapitalization: textCapitalization,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          autofocus: autofocus,
          enabled: enabled,
          maxLength: maxLength,
          inputFormatters: inputFormatters,
          textAlign: large ? TextAlign.center : TextAlign.start,
          style: large
              ? KText.amountHero.copyWith(color: k.ink, fontSize: 30, letterSpacing: 10)
              : KText.body.copyWith(color: k.ink),
          cursorColor: k.primary,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: (large ? KText.amountHero.copyWith(fontSize: 30, letterSpacing: 10) : KText.body).copyWith(
              color: k.placeholder,
            ),
            filled: true,
            fillColor: k.surfaceMuted,
            counterText: '',
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: large ? 16 : 14),
            border: border(Colors.transparent),
            enabledBorder: border(error == null ? Colors.transparent : k.danger),
            focusedBorder: border(error == null ? k.primary : k.danger, 2),
            disabledBorder: border(Colors.transparent),
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 6),
          Semantics(
            liveRegion: true,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Icon(Icons.error_outline_rounded, size: 16, color: k.danger),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(error, style: KText.small.copyWith(color: k.danger)),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
