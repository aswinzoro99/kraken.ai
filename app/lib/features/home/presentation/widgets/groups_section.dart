import 'package:material_ui/material_ui.dart';

import '../../../../ui_kit/ui_kit.dart';
import '../../domain/home_snapshot.dart';
import 'formatting.dart';

/// Your groups, most recently active first.
class GroupsSection extends StatelessWidget {
  const GroupsSection({super.key, required this.groups, required this.now, required this.onOpen, required this.onSeeAll});

  final List<GroupSummary> groups;
  final DateTime now;
  final void Function(GroupSummary group) onOpen;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    KSectionHeader(title: 'Your groups', actionLabel: 'See all', onAction: onSeeAll),
    KGroupedList(indent: 52, children: [
      for (final g in groups)
        KListRow(
          title: g.name,
          subtitle: [
            people(g.memberCount),
            if (g.lastActivity != null) relativeDay(g.lastActivity!, now) else if (g.detail.isNotEmpty) g.detail,
          ].join(' · '),
          leading: KAvatar(name: g.name, tone: KTone.neutral),
          trailing: BalanceLabel(balance: g.myBalance),
          onTap: () => onOpen(g),
        ),
    ]),
  ]);
}
