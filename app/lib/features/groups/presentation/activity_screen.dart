import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/routes.dart';
import '../../../app/session.dart';
import '../../../core/time/clock.dart';
import '../../../ui_kit/ui_kit.dart';
import '../../home/presentation/widgets/formatting.dart';
import '../domain/expense.dart';
import '../domain/group_ledger.dart';
import 'ledgers_cubit.dart';
import 'widgets/group_rows.dart';

/// Everything that happened across your groups, newest first, with who did
/// it: added, edited, deleted, joined.
class ActivityScreen extends StatelessWidget {
  const ActivityScreen({super.key});

  static const shown = 100;

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (context) =>
        LedgersCubit(repository: context.read<GroupsRepository>(), uid: context.read<SessionCubit>().state.uid ?? ''),
    child: const _ActivityView(),
  );
}

class _ActivityView extends StatelessWidget {
  const _ActivityView();

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final now = context.read<Clock>()();
    final state = context.watch<LedgersCubit>().state;
    final List<Widget> body = switch (state) {
      LedgersLoading() => [
        const Padding(
          padding: EdgeInsets.all(KSpace.xxxl),
          child: Center(child: CircularProgressIndicator()),
        ),
      ],
      LedgersFailed() => [
        const KEmptyState(
          illustration: KIllustrations.emptyOffline,
          title: "Couldn't load activity",
          message: 'Check your connection and try again.',
        ),
      ],
      LedgersReady(:final ledgers) => () {
        final entries = <(ActivityEntry, GroupLedger)>[
          for (final l in ledgers)
            for (final a in l.activity) (a, l),
        ]..sort((a, b) => b.$1.date.compareTo(a.$1.date));
        if (entries.isEmpty) {
          return <Widget>[
            const Padding(
              padding: EdgeInsets.only(top: KSpace.xxxl),
              child: KEmptyState(
                illustration: KIllustrations.emptyActivity,
                title: 'Nothing yet',
                message: 'Expenses, edits and new members across your groups show up here, with who made each.',
              ),
            ),
          ];
        }
        String? day;
        final rows = <Widget>[];
        for (final (a, l) in entries.take(ActivityScreen.shown)) {
          final label = relativeDay(a.date, now);
          final heading = label.endsWith('ago') ? 'This week' : label;
          if (heading != day) {
            day = heading;
            rows.add(
              Padding(
                padding: const EdgeInsets.only(top: KSpace.md),
                child: KSectionHeader(title: heading[0].toUpperCase() + heading.substring(1)),
              ),
            );
          }
          rows.add(
            ActivityRow(
              entry: a,
              ledger: l,
              // The heading already says the day, except within "This week".
              when: heading == 'This week' ? label : '',
              showGroup: true,
              onTap: () => context.go(Paths.group(l.group.id)),
            ),
          );
        }
        if (entries.length > ActivityScreen.shown) {
          rows.add(
            Padding(
              padding: const EdgeInsets.symmetric(vertical: KSpace.lg),
              child: Text(
                'Older activity is in each group.',
                textAlign: TextAlign.center,
                style: KText.caption.copyWith(color: k.muted),
              ),
            ),
          );
        }
        return rows;
      }(),
    };
    return CustomScrollView(
      slivers: [
        const SliverToBoxAdapter(child: KTopBar(title: 'Activity')),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: KSpace.gutter),
          sliver: SliverList.list(children: body),
        ),
        SliverToBoxAdapter(child: SizedBox(height: MediaQuery.paddingOf(context).bottom + KSpace.xl)),
      ],
    );
  }
}
