import 'package:material_ui/material_ui.dart';

import '../../core/haptics/haptics.dart';
import '../foundation/pressable.dart';
import '../theme/kraken_theme.dart';
import '../tokens/typography.dart';

final class KNavItem {
  const KNavItem({required this.label, required this.icon, required this.selectedIcon});
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

/// The five-tab bar at the bottom of the app.
class KBottomNav extends StatelessWidget {
  const KBottomNav({super.key, required this.items, required this.selectedIndex, required this.onSelected});

  final List<KNavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return Container(
      padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
      decoration: BoxDecoration(
        color: k.background,
        border: Border(top: BorderSide(color: k.divider)),
      ),
      child: SizedBox(
        height: 56,
        child: Row(
          children: [
            for (var i = 0; i < items.length; i++)
              Expanded(
                child: Semantics(
                  selected: i == selectedIndex,
                  child: KPressable(
                    onTap: () => onSelected(i),
                    haptic: HapticKind.selection,
                    pressedScale: 0.92,
                    semanticLabel: items[i].label,
                    excludeChildSemantics: true,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          i == selectedIndex ? items[i].selectedIcon : items[i].icon,
                          size: 22,
                          color: i == selectedIndex ? k.ink : k.muted,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          items[i].label,
                          style: KText.tiny.copyWith(
                            color: i == selectedIndex ? k.ink : k.muted,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
