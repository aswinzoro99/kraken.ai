import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/kraken_app.dart';
import '../../../app/routes.dart';
import '../../../app/session.dart';
import '../../../core/analytics/events.dart';
import '../../../ui_kit/ui_kit.dart';
import '../../profile/domain/value_objects.dart';
import '../domain/group_ledger.dart';

/// Joining with an invite: the code, then "Which name is yours?".
class JoinGroupScreen extends StatefulWidget {
  const JoinGroupScreen({super.key, this.initialCode});

  /// From a link, or a code given during sign-up.
  final String? initialCode;

  @override
  State<JoinGroupScreen> createState() => _JoinGroupScreenState();
}

class _JoinGroupScreenState extends State<JoinGroupScreen> {
  late final _code = TextEditingController(text: widget.initialCode ?? '');
  late final _newName = TextEditingController(text: context.read<SessionCubit>().state.displayName ?? '');
  InvitePreview? _preview;

  /// The member picked; null with [_asNew] means "I'm not on the list".
  String? _memberId;
  bool _asNew = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if ((widget.initialCode ?? '').isNotEmpty) WidgetsBinding.instance.addPostFrameCallback((_) => _find());
  }

  @override
  void dispose() {
    _code.dispose();
    _newName.dispose();
    super.dispose();
  }

  String _messageFor(GroupsException e) => switch (e) {
    InviteNotFound() => 'No group has that code. Check it with whoever sent it.',
    InviteExpired() => 'That invite has expired. Ask for a new one.',
    NameTaken() => 'Someone just took that name. Pick another.',
    AlreadyInGroup() => 'You’re in this group already.',
  };

  String _resultFor(GroupsException e) => switch (e) {
    InviteNotFound() => 'not_found',
    InviteExpired() => 'expired',
    NameTaken() => 'name_taken',
    AlreadyInGroup() => 'already_in',
  };

  Future<void> _find() async {
    final code = InviteCode.tryParse(_code.text);
    if (code == null) {
      setState(() => _error = 'Enter the code or paste the link from your invite.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final preview = await context.read<GroupsRepository>().openInvite(code.value);
      if (!mounted) return;
      setState(() {
        _preview = preview;
        _busy = false;
        _memberId = preview.openNames.length == 1 ? preview.openNames.single.id : null;
        _asNew = preview.openNames.isEmpty;
      });
    } on GroupsException catch (e) {
      context.analytics.log(InviteClaimed(result: _resultFor(e)));
      if (mounted) {
        setState(() {
          _busy = false;
          _error = _messageFor(e);
        });
      }
    } on Object {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = "Couldn't check the code. Try again.";
        });
      }
    }
  }

  Future<void> _join() async {
    final preview = _preview!;
    final newName = _newName.text.trim();
    if (_asNew && newName.isEmpty) {
      setState(() => _error = 'Enter your name');
      return;
    }
    if (!_asNew && _memberId == null) {
      setState(() => _error = 'Pick your name');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final analytics = context.analytics;
    final router = GoRouter.of(context);
    try {
      final groupId = await context.read<GroupsRepository>().claimInvite(
        uid: context.read<SessionCubit>().state.uid ?? '',
        code: preview.code,
        memberId: _asNew ? null : _memberId,
        newName: _asNew ? newName : null,
      );
      analytics.log(const InviteClaimed(result: 'joined'));
      router.pushReplacement(Paths.group(groupId));
    } on GroupsException catch (e) {
      analytics.log(InviteClaimed(result: _resultFor(e)));
      if (e is AlreadyInGroup) {
        router.pushReplacement(Paths.group(e.groupId));
        return;
      }
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = _messageFor(e);
      });
      // A name taken meanwhile: show what's still open.
      if (e is NameTaken) await _find();
    } on Object {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = "Couldn't join. Try again.";
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final preview = _preview;
    return Scaffold(
      body: Column(
        children: [
          KTopBar(title: 'Join a group', onBack: () => context.canPop() ? context.pop() : context.go(Paths.home)),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(KSpace.gutter, KSpace.sm, KSpace.gutter, KSpace.xl),
              children: [
                if (preview == null) ...[
                  Text(
                    'Enter the code from your invite, or paste the whole message.',
                    style: KText.body.copyWith(color: k.inkSecondary),
                  ),
                  const SizedBox(height: KSpace.xl),
                  KTextField(
                    label: 'Invite code',
                    hint: 'K7Q4M2XB',
                    controller: _code,
                    error: _error,
                    autofocus: (widget.initialCode ?? '').isEmpty,
                    textCapitalization: TextCapitalization.characters,
                    textInputAction: TextInputAction.go,
                    onSubmitted: (_) => _find(),
                  ),
                ] else ...[
                  Semantics(
                    header: true,
                    child: Text('Join ${preview.groupName}', style: KText.title.copyWith(color: k.ink)),
                  ),
                  const SizedBox(height: KSpace.xxs),
                  Text(
                    '${preview.memberCount} ${preview.memberCount == 1 ? 'person' : 'people'} so far',
                    style: KText.caption.copyWith(color: k.muted),
                  ),
                  const SizedBox(height: KSpace.xl),
                  if (preview.openNames.isNotEmpty) ...[
                    Text('Which name is yours?', style: KText.heading.copyWith(color: k.ink)),
                    const SizedBox(height: KSpace.xs),
                    for (final m in preview.openNames)
                      KCheckRow(
                        title: m.name,
                        value: !_asNew && _memberId == m.id,
                        onChanged: (_) => setState(() {
                          _memberId = m.id;
                          _asNew = false;
                          _error = null;
                        }),
                      ),
                    KCheckRow(
                      title: 'I’m not on the list',
                      subtitle: 'Join with a new name',
                      value: _asNew,
                      onChanged: (_) => setState(() {
                        _asNew = true;
                        _memberId = null;
                        _error = null;
                      }),
                    ),
                  ],
                  if (_asNew) ...[
                    const SizedBox(height: KSpace.md),
                    KTextField(
                      label: 'Your name',
                      hint: 'The name friends will see',
                      controller: _newName,
                      maxLength: 30,
                      textCapitalization: TextCapitalization.words,
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: KSpace.md),
                    Text(_error!, style: KText.caption.copyWith(color: k.danger)),
                  ],
                ],
              ],
            ),
          ),
          SafeArea(
            top: false,
            minimum: const EdgeInsets.fromLTRB(KSpace.gutter, 0, KSpace.gutter, KSpace.lg),
            child: KButton(
              label: preview == null ? 'Find group' : 'Join ${preview.groupName}',
              expand: true,
              loading: _busy,
              onPressed: preview == null ? _find : _join,
            ),
          ),
        ],
      ),
    );
  }
}
