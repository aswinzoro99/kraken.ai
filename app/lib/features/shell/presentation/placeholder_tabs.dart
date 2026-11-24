import 'package:material_ui/material_ui.dart';

import '../../../ui_kit/ui_kit.dart';

/// A tab whose feature arrives in a later phase. Says what will be here.
class _ComingTab extends StatelessWidget {
  const _ComingTab({required this.title, required this.illustration, required this.heading, required this.message});
  final String title;
  final String illustration;
  final String heading;
  final String message;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      KTopBar(title: title),
      Expanded(
        child: Padding(
          // Keep the message centred in the space above the floating tab bar.
          padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
          child: Center(
            child: KEmptyState(illustration: illustration, title: heading, message: message),
          ),
        ),
      ),
    ],
  );
}

class FriendsTab extends StatelessWidget {
  const FriendsTab({super.key});
  @override
  Widget build(BuildContext context) => const _ComingTab(
    title: 'Friends',
    illustration: KIllustrations.emptyFriends,
    heading: 'Your friends show up here',
    message: 'Everyone you share a group with, and where you stand with each of them. Arrives with groups in Phase 2.',
  );
}

class InsightsTab extends StatelessWidget {
  const InsightsTab({super.key});
  @override
  Widget build(BuildContext context) => const _ComingTab(
    title: 'Insights',
    illustration: KIllustrations.emptyInsights,
    heading: 'See where your money goes',
    message: 'Your share of spending by month, year, category and group. Arrives in Phase 7.',
  );
}

class ActivityTab extends StatelessWidget {
  const ActivityTab({super.key});
  @override
  Widget build(BuildContext context) => const _ComingTab(
    title: 'Activity',
    illustration: KIllustrations.emptyActivity,
    heading: 'Every change, in order',
    message: 'Expenses, payments and edits across your groups, with who made each. Arrives in Phase 2.',
  );
}
