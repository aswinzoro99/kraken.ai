import 'package:material_ui/material_ui.dart';

import '../theme/kraken_theme.dart';
import '../tokens/colors.dart';
import '../tokens/layout.dart';
import '../tokens/typography.dart';

enum KTone { blue, green, amber, neutral }

/// Initials on a tinted tile. Square tiles mark groups, circles mark people.
class KAvatar extends StatelessWidget {
  const KAvatar({super.key, required this.name, this.size = 40, this.circle = false, this.tone});

  final String name;
  final double size;
  final bool circle;

  /// Defaults to a tone picked from the name, stable across launches.
  final KTone? tone;

  /// "Goa Trip" → "GT", "Flat 302" → "F3", "Sreya" → "S".
  static String initialsOf(String name) {
    final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return '?';
    if (words.length == 1) return words.first.characters.first.toUpperCase();
    return (words[0].characters.first + words[1].characters.first).toUpperCase();
  }

  static KTone toneFor(String name) {
    var h = 0;
    for (final c in name.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    return KTone.values[h % KTone.values.length];
  }

  (Color, Color) _colors(KColors k) => switch (tone ?? toneFor(name)) {
    KTone.blue => (k.accentSoft, k.primaryText),
    KTone.green => (k.successSoft, k.success),
    KTone.amber => (k.warningSoft, k.warning),
    KTone.neutral => (k.neutralSoft, k.inkSecondary),
  };

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = _colors(context.k);
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          shape: circle ? BoxShape.circle : BoxShape.rectangle,
          borderRadius: circle ? null : BorderRadius.circular(size * 12 / 44),
        ),
        child: Text(
          initialsOf(name),
          style: KText.label.copyWith(color: fg, fontSize: size * 0.34, fontWeight: FontWeight.w600, height: 1),
        ),
      ),
    );
  }
}

/// Overlapping circles for a group's members.
class KAvatarStack extends StatelessWidget {
  const KAvatarStack({super.key, required this.names, this.size = 28, this.max = 4});

  final List<String> names;
  final double size;
  final int max;

  @override
  Widget build(BuildContext context) {
    final shown = names.take(max).toList();
    final overlap = size * 0.3;
    return Semantics(
      label: names.join(', '),
      child: SizedBox(
        height: size,
        width: shown.isEmpty ? 0 : size + (shown.length - 1) * (size - overlap),
        child: Stack(
          children: [
            for (var i = 0; i < shown.length; i++)
              Positioned(
                left: i * (size - overlap),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: context.k.surface, width: 2),
                  ),
                  child: KAvatar(name: shown[i], size: size, circle: true),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A space-filling placeholder that keeps bubbles aligned when the avatar
/// is hidden (only the last message in a run shows it).
const kAvatarGap = SizedBox(width: KSpace.xs);
