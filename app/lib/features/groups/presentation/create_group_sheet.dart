import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/kraken_app.dart';
import '../../../app/routes.dart';
import '../../../app/session.dart';
import '../../../core/analytics/events.dart';
import '../../../ui_kit/ui_kit.dart';
import '../domain/group.dart';
import '../domain/group_ledger.dart';

/// Asks for a group's name and friends' names, makes it and opens it.
Future<void> showCreateGroupSheet(BuildContext context) async {
  final router = GoRouter.of(context);
  final result = await showKSheet<Object>(context, builder: (_) => _CreateGroupSheet(parent: context));
  switch (result) {
    case final Group group:
      router.push(Paths.group(group.id));
    case _JoinInstead():
      router.push(Paths.join);
  }
}

final class _JoinInstead {
  const _JoinInstead();
}

class _CreateGroupSheet extends StatefulWidget {
  const _CreateGroupSheet({required this.parent});
  final BuildContext parent;

  @override
  State<_CreateGroupSheet> createState() => _CreateGroupSheetState();
}

class _CreateGroupSheetState extends State<_CreateGroupSheet> {
  final _name = TextEditingController();
  final _friend = TextEditingController();
  final _friendFocus = FocusNode();
  final _friends = <String>[];
  bool _saving = false;
  String? _nameError;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _friend.dispose();
    _friendFocus.dispose();
    super.dispose();
  }

  void _addFriend() {
    final name = _friend.text.trim();
    if (name.isEmpty) return;
    if (!_friends.any((f) => f.toLowerCase() == name.toLowerCase())) setState(() => _friends.add(name));
    _friend.clear();
    _friendFocus.requestFocus();
  }

  Future<void> _create() async {
    // A name still in the box counts, so it isn't lost.
    _addFriend();
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _nameError = 'Give the group a name');
      return;
    }
    setState(() {
      _saving = true;
      _nameError = null;
      _error = null;
    });
    final session = widget.parent.read<SessionCubit>().state;
    try {
      final group = await widget.parent.read<GroupsRepository>().createGroup(
        uid: session.uid ?? '',
        yourName: session.displayName ?? 'You',
        name: name,
        friendNames: _friends,
      );
      widget.parent.analytics.log(GroupCreated(memberCount: group.members.length));
      if (mounted) Navigator.of(context).pop(group);
    } on Object {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = "Couldn't make the group. Try again.";
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text('New group', style: KText.heading.copyWith(color: k.ink, fontSize: 19)),
          ),
          const SizedBox(height: KSpace.xs),
          Text(
            'A trip, your flat, office lunches. Add friends by name; they can join later with an invite.',
            style: KText.body.copyWith(color: k.inkSecondary),
          ),
          const SizedBox(height: KSpace.xl),
          KTextField(
            label: 'Group name',
            hint: 'Goa Trip',
            controller: _name,
            error: _nameError,
            autofocus: true,
            maxLength: 40,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            onSubmitted: (_) => _friendFocus.requestFocus(),
          ),
          const SizedBox(height: KSpace.lg),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Focus(
                  focusNode: _friendFocus,
                  skipTraversal: true,
                  child: KTextField(
                    label: 'Friends',
                    hint: 'A name, then Add',
                    controller: _friend,
                    maxLength: 30,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _addFriend(),
                  ),
                ),
              ),
              const SizedBox(width: KSpace.xs),
              Padding(
                padding: const EdgeInsets.only(bottom: 22),
                child: KButton.secondary(label: 'Add', size: KButtonSize.medium, onPressed: _addFriend),
              ),
            ],
          ),
          if (_friends.isNotEmpty) ...[
            const SizedBox(height: KSpace.xs),
            KChipRow(
              children: [
                for (final f in _friends)
                  KChip(label: f, icon: Icons.close_rounded, onTap: () => setState(() => _friends.remove(f))),
              ],
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: KSpace.md),
            Text(_error!, style: KText.caption.copyWith(color: k.danger)),
          ],
          const SizedBox(height: KSpace.xl),
          KButton(label: 'Create group', expand: true, loading: _saving, onPressed: _create),
          const SizedBox(height: KSpace.xs),
          KButton.ghost(
            label: 'Have an invite? Join a group',
            expand: true,
            onPressed: () => Navigator.of(context).pop(const _JoinInstead()),
          ),
        ],
      ),
    );
  }
}
