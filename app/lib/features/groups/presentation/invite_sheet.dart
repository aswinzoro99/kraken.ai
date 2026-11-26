import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/kraken_app.dart';
import '../../../app/session.dart';
import '../../../core/analytics/events.dart';
import '../../../ui_kit/ui_kit.dart';
import '../domain/group.dart';
import '../domain/group_ledger.dart';

/// Shows the group's invite code, ready to copy and send.
Future<void> showInviteSheet(BuildContext context, GroupLedger ledger) => showKSheet<void>(
  context,
  builder: (_) => _InviteSheet(group: ledger.group, myMemberId: ledger.myMemberId, parent: context),
);

class _InviteSheet extends StatefulWidget {
  const _InviteSheet({required this.group, required this.myMemberId, required this.parent});
  final Group group;
  final String myMemberId;

  /// For reading services; the sheet's own context sits above them.
  final BuildContext parent;

  @override
  State<_InviteSheet> createState() => _InviteSheetState();
}

class _InviteSheetState extends State<_InviteSheet> {
  late final Future<Invite> _invite = widget.parent.read<GroupsRepository>().createInvite(
    widget.parent.read<SessionCubit>().state.uid ?? '',
    widget.group.id,
  );

  Future<void> _copy(Invite invite) async {
    final parent = widget.parent;
    final analytics = parent.analytics;
    final navigator = Navigator.of(context);
    await Clipboard.setData(
      ClipboardData(
        text:
            'Join “${widget.group.name}” on Kraken to split expenses. '
            'In Kraken, tap New group → Have an invite? and enter ${invite.code}',
      ),
    );
    analytics.log(const InviteShared());
    navigator.pop();
    if (parent.mounted) {
      KToast.show(parent, 'Invite copied. Paste it in a message to your friends.', kind: KToastKind.success);
    }
  }

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    // Names a friend could still take: not yours, not claimed.
    final open = [
      for (final m in widget.group.members)
        if (!m.claimed && m.id != widget.myMemberId) m.name,
    ];
    return FutureBuilder<Invite>(
      future: _invite,
      builder: (context, snap) {
        final invite = snap.data;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text('Invite to ${widget.group.name}', style: KText.heading.copyWith(color: k.ink, fontSize: 19)),
            ),
            const SizedBox(height: KSpace.xs),
            Text(
              open.isEmpty
                  ? 'Anyone with the code can join. It works for 7 days.'
                  : 'Friends enter this code in Kraken, then pick their name (${open.join(', ')}). '
                        'It works for 7 days.',
              style: KText.body.copyWith(color: k.inkSecondary),
            ),
            const SizedBox(height: KSpace.xl),
            if (snap.hasError)
              Text("Couldn't make an invite. Try again.", style: KText.body.copyWith(color: k.danger))
            else if (invite == null)
              const Center(child: CircularProgressIndicator())
            else ...[
              Container(
                padding: const EdgeInsets.symmetric(vertical: KSpace.lg),
                decoration: BoxDecoration(color: k.surfaceMuted, borderRadius: const BorderRadius.all(KRadius.lg)),
                child: Column(
                  children: [
                    Text('Invite code', style: KText.small.copyWith(color: k.muted)),
                    const SizedBox(height: KSpace.xxs),
                    SelectableText(
                      invite.code,
                      semanticsLabel: 'Invite code ${invite.code.split('').join(' ')}',
                      style: KText.title.copyWith(color: k.ink, letterSpacing: 4),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: KSpace.xl),
              KButton(label: 'Copy invite', icon: Icons.copy_rounded, expand: true, onPressed: () => _copy(invite)),
            ],
          ],
        );
      },
    );
  }
}
