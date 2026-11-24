import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/haptics/haptics.dart';
import '../foundation/pressable.dart';
import '../theme/kraken_theme.dart';
import '../tokens/typography.dart';
import 'kraken_logo.dart';

/// Ways to sign in shown as logos. [kraken] is Kraken's own chat (the agent).
enum KSocial { apple, google, kraken }

/// "Continue with Apple" and "Continue with Google", styled as each asks:
/// Apple's is black (white in dark mode) with the Apple logo; Google's is
/// plain with the four-colour G. "Chat with Kraken" is Kraken blue with the
/// octopus. Full width with the name, or [compact]: the logo alone in a
/// circle, for a quiet row of sign-in options (screen readers still hear
/// the full name).
class KSocialButton extends StatelessWidget {
  const KSocialButton({
    super.key,
    required this.provider,
    required this.onPressed,
    this.loading = false,
    this.compact = false,
  });

  final KSocial provider;
  final VoidCallback? onPressed;
  final bool loading;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final (background, foreground, label) = switch (provider) {
      KSocial.apple => (dark ? Colors.white : Colors.black, dark ? Colors.black : Colors.white, 'Continue with Apple'),
      KSocial.google => (k.surface, k.ink, 'Continue with Google'),
      KSocial.kraken => (k.primary, k.onPrimary, 'Chat with Kraken'),
    };
    final border = provider == KSocial.google ? Border.all(color: k.line, width: 1.2) : null;
    final spinner = SizedBox.square(
      dimension: 20,
      child: CircularProgressIndicator(strokeWidth: 2.2, color: foreground),
    );
    return KPressable(
      onTap: loading ? null : onPressed,
      haptic: HapticKind.tap,
      pressedScale: compact ? 0.94 : 0.98,
      semanticLabel: label,
      excludeChildSemantics: true,
      child: compact
          ? Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: background, shape: BoxShape.circle, border: border),
              child: loading ? spinner : _logo(foreground, 22),
            )
          : Container(
              height: 52,
              decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(14), border: border),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (loading)
                    spinner
                  else ...[
                    _logo(foreground, 19),
                    const SizedBox(width: 10),
                    Text(
                      label,
                      style: KText.bodyStrong.copyWith(color: foreground, fontWeight: FontWeight.w600),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _logo(Color color, double size) => switch (provider) {
    KSocial.apple => Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Icon(Icons.apple, size: size + 4, color: color),
    ),
    KSocial.google => SvgPicture.asset(
      'assets/icons/google.svg',
      width: size,
      height: size,
      excludeFromSemantics: true,
    ),
    KSocial.kraken => KrakenGlyph(height: size * 0.8, color: color),
  };
}
