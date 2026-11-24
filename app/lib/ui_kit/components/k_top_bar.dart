import 'package:material_ui/material_ui.dart';

import '../foundation/pressable.dart';
import '../theme/kraken_theme.dart';
import '../tokens/layout.dart';
import '../tokens/typography.dart';

/// A screen header. Either a title with an optional back button, or any
/// [leading] widget (such as the logo on Home), with actions on the right.
class KTopBar extends StatelessWidget {
  const KTopBar({
    super.key,
    this.title,
    this.subtitle,
    this.leading,
    this.actions = const [],
    this.onBack,
    this.bordered = false,
  });

  final String? title;
  final String? subtitle;
  final Widget? leading;
  final List<Widget> actions;

  /// Shows a back chevron when set.
  final VoidCallback? onBack;

  /// A white bar with a bottom hairline, as on the sign-in chat.
  final bool bordered;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final top = MediaQuery.paddingOf(context).top;
    return Container(
      padding: EdgeInsets.fromLTRB(onBack == null ? KSpace.gutter : KSpace.xxs, top + KSpace.xs, KSpace.md, KSpace.xs),
      constraints: BoxConstraints(minHeight: top + 56),
      decoration: bordered
          ? BoxDecoration(
              border: Border(bottom: BorderSide(color: k.divider)),
            )
          : null,
      child: Row(
        children: [
          if (onBack != null)
            KPressable(
              onTap: onBack,
              semanticLabel: 'Back',
              excludeChildSemantics: true,
              child: SizedBox.square(
                dimension: kMinTouch,
                child: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: k.ink),
              ),
            ),
          ?leading,
          if (title != null)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Semantics(
                    header: true,
                    child: Text(title!, style: KText.title.copyWith(color: k.ink, fontSize: 20)),
                  ),
                  if (subtitle != null) Text(subtitle!, style: KText.small.copyWith(color: k.muted)),
                ],
              ),
            )
          else
            const Spacer(),
          ...actions,
        ],
      ),
    );
  }
}
