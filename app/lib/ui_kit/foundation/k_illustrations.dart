import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_ui/material_ui.dart';

import '../theme/kraken_theme.dart';

/// Simple line drawings of one object each, for empty and error screens, in
/// `assets/illustrations`. Like the icons they are one colour (drawn black,
/// with lighter fills as transparency), tinted in code to suit the theme.
abstract final class KIllustrations {
  /// An open, empty box.
  static const emptyGroups = 'assets/illustrations/empty_groups.svg';

  /// A cloud with a line through it.
  static const emptyOffline = 'assets/illustrations/empty_offline.svg';

  /// Two people.
  static const emptyFriends = 'assets/illustrations/empty_friends.svg';

  /// A bar chart with a sparkle.
  static const emptyInsights = 'assets/illustrations/empty_insights.svg';

  /// A receipt.
  static const emptyActivity = 'assets/illustrations/empty_activity.svg';
}

/// One of [KIllustrations] at [size], in [color] (the muted text colour by
/// default). Decorative: the words beside it carry the meaning.
class KIllustration extends StatelessWidget {
  const KIllustration(this.asset, {super.key, this.size = 88, this.color});

  final String asset;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
    asset,
    width: size,
    height: size,
    colorFilter: ColorFilter.mode(color ?? context.k.muted, BlendMode.srcIn),
    excludeFromSemantics: true,
  );
}
