import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/kraken_app.dart';
import '../../../app/session.dart';
import '../../../core/time/clock.dart';
import '../../../ui_kit/ui_kit.dart';
import '../domain/auth_repository.dart';
import 'finish_sign_up_cubit.dart';

/// "Almost done": what a new account needs before Home. Your name (kept
/// from sign-up or Apple/Google), 18 or older, the Terms and Privacy
/// Policy, and whether to share usage stats.
class FinishSignUpScreen extends StatelessWidget {
  const FinishSignUpScreen({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (context) => FinishSignUpCubit(
      auth: context.read(),
      profiles: context.read(),
      analytics: context.analytics,
      clock: context.read<Clock>(),
      policyVersion: context.config.privacyPolicyVersion,
    ),
    child: const _FinishView(),
  );
}

class _FinishView extends StatefulWidget {
  const _FinishView();

  @override
  State<_FinishView> createState() => _FinishViewState();
}

class _FinishViewState extends State<_FinishView> {
  late final TextEditingController _name = TextEditingController(text: _knownName());

  /// Whether the person has typed in the name field themselves.
  bool _typed = false;
  bool _adult = false;
  bool _agreed = false;
  bool _stats = false;

  String _knownName() => _nameIn(context.read<SessionCubit>().state);

  static String _nameIn(SessionState session) => switch (session) {
    OnboardingSession(:final profile) => profile?.displayName ?? '',
    _ => '',
  };

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final config = context.config;
    final state = context.watch<FinishSignUpCubit>().state;
    final email = context.read<AuthRepository>().currentUser?.email.value;
    final ready = _adult && _agreed;
    return MultiBlocListener(
      listeners: [
        // The name from sign-up can be saved just after this screen opens.
        BlocListener<SessionCubit, SessionState>(
          listener: (context, session) {
            final name = _nameIn(session);
            if (!_typed && name.isNotEmpty && _name.text != name) _name.text = name;
          },
        ),
        BlocListener<FinishSignUpCubit, FinishSignUpState>(
          listenWhen: (a, b) => b.saveError != null && a.saveError != b.saveError,
          listener: (context, state) => KToast.show(context, state.saveError!),
        ),
      ],
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              const KTopBar(leading: KrakenLogo(fontSize: 18)),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(KSpace.gutter, KSpace.md, KSpace.gutter, KSpace.xl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Semantics(
                        header: true,
                        child: Text('Almost done', style: KText.headline.copyWith(color: k.ink)),
                      ),
                      const SizedBox(height: KSpace.xs),
                      Text(
                        'A couple of things before you start splitting.',
                        style: KText.body.copyWith(color: k.inkSecondary),
                      ),
                      const SizedBox(height: KSpace.xl),
                      KTextField(
                        label: 'Your name',
                        hint: 'The name friends will see',
                        controller: _name,
                        onChanged: (_) => _typed = true,
                        error: state.nameError,
                        keyboardType: TextInputType.name,
                        textCapitalization: TextCapitalization.words,
                        autofillHints: const [AutofillHints.name],
                      ),
                      const SizedBox(height: KSpace.lg),
                      KCheckRow(
                        title: "I'm 18 or older",
                        subtitle: 'Kraken handles money, so it is for adults only.',
                        value: _adult,
                        onChanged: (v) => setState(() => _adult = v),
                      ),
                      KCheckRow(
                        title: 'I agree to the Terms and Privacy Policy',
                        subtitle: 'What Kraken stores and why, in plain words.',
                        value: _agreed,
                        onChanged: (v) => setState(() => _agreed = v),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 22),
                        child: Row(
                          children: [
                            KButton(
                              label: 'Read the Terms',
                              variant: KButtonVariant.ghost,
                              size: KButtonSize.small,
                              onPressed: () => KToast.show(context, 'Terms: ${config.termsUrl}'),
                            ),
                            KButton(
                              label: 'Privacy Policy',
                              variant: KButtonVariant.ghost,
                              size: KButtonSize.small,
                              onPressed: () => KToast.show(context, 'Privacy Policy: ${config.privacyPolicyUrl}'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: KSpace.xs),
                      KSwitchRow(
                        title: 'Share usage stats',
                        subtitle: 'Anonymous: which screens you open, never names or amounts. Change it any time.',
                        value: _stats,
                        onChanged: (v) => setState(() => _stats = v),
                      ),
                      const SizedBox(height: KSpace.xl),
                      KButton(
                        label: 'Start using Kraken',
                        expand: true,
                        loading: state.saving,
                        haptic: HapticKind.success,
                        onPressed: ready
                            ? () => context.read<FinishSignUpCubit>().submit(
                                name: _name.text,
                                adult: _adult,
                                agreed: _agreed,
                                shareStats: _stats,
                              )
                            : null,
                      ),
                      if (!ready) ...[
                        const SizedBox(height: KSpace.xs),
                        Text(
                          'Tick both boxes to continue.',
                          textAlign: TextAlign.center,
                          style: KText.small.copyWith(color: k.muted),
                        ),
                      ],
                      const SizedBox(height: KSpace.xl),
                      if (email != null)
                        Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text('Signed in as $email. ', style: KText.small.copyWith(color: k.muted)),
                            KButton(
                              label: 'Not you?',
                              variant: KButtonVariant.ghost,
                              size: KButtonSize.small,
                              onPressed: () => context.read<AuthRepository>().signOut(),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
