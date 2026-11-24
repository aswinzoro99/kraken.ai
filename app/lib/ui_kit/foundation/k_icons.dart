import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_ui/material_ui.dart';

/// Kraken's own icons, drawn from the SVGs in `assets/icons`: a 24 × 24
/// grid, 2 px stroke, round caps and joins. Each file is one colour with
/// transparent cut-outs, so [KSvgIcon] can tint it any colour.
abstract final class KIcons {
  /// The plus on the quick-actions button (2.5 px stroke).
  static const add = 'assets/icons/add.svg';
}

/// The tab bar icons. Idle tabs show [outline]; the selected tab shows
/// [filled]. The profile tab is the person's avatar, not an icon.
enum KTabIcon {
  home,
  friends,
  insights,
  activity;

  String get outline => 'assets/icons/$name.svg';
  String get filled => 'assets/icons/${name}_filled.svg';
}

/// One of Kraken's SVG icons at [size], tinted [color]. Decorative: the
/// control it sits in carries the label.
class KSvgIcon extends StatelessWidget {
  const KSvgIcon(this.asset, {super.key, required this.color, this.size = 24});

  final String asset;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
    asset,
    width: size,
    height: size,
    colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    excludeFromSemantics: true,
  );
}
