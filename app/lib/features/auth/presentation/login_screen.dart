import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/kraken_app.dart';
import '../../../app/routes.dart';
import '../../../app/services.dart';
import '../../../core/analytics/events.dart';
import '../../../ui_kit/ui_kit.dart';
import '../../onboarding/presentation/widgets/mock_inbox_banner.dart';
import '../domain/auth_repository.dart';
import 'login_cubit.dart';

/// Log in or sign up the usual way: Apple, Google, or an email code. Or
/// hand over to Kraken's chat, which does the same one question at a time.
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (context) => LoginCubit(
      auth: context.read(),
      profiles: context.read(),
      analytics: context.analytics,
      policyVersion: context.config.privacyPolicyVersion,
    ),
    child: const _LoginView(),
  );
}

class _LoginView extends StatefulWidget {
  const _LoginView();

  @override
  State<_LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<_LoginView> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _code = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _code.dispose();
    super.dispose();
  }

  void _submitDetails() {
    FocusScope.of(context).unfocus();
    context.read<LoginCubit>().submitDetails(email: _email.text, name: _name.text);
  }

  void _submitCode() => context.read<LoginCubit>().submitCode(_code.text);

  @override
  Widget build(BuildContext context) {
    final state = context.watch<LoginCubit>().state;
    final cubit = context.read<LoginCubit>();
    final code = state.step == LoginStep.code;
    final showInbox = code && context.read<DevTools>().inbox != null;

    return BlocListener<LoginCubit, LoginState>(
      listenWhen: (a, b) => b.notice != null && a.notice != b.notice,
      listener: (context, state) => KToast.show(context, state.notice!),
      child: PopScope(
        // Back from the code goes back to the form, not off the screen.
        canPop: !code,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) cubit.useDifferentEmail();
        },
        child: Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                KTopBar(
                  onBack: () {
                    if (code) {
                      cubit.useDifferentEmail();
                    } else {
                      context.go(Paths.welcome);
                    }
                  },
                  leading: const KrakenLogo(fontSize: 18),
                ),
                Expanded(
                  child: AutofillGroup(
                    child: LayoutBuilder(
                      // The form fills the screen, so the sign-in logos sit at
                      // the bottom; it scrolls when the keyboard or large text
                      // needs the room.
                      builder: (context, c) => SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(KSpace.gutter, KSpace.md, KSpace.gutter, KSpace.lg),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(minHeight: c.maxHeight - KSpace.md - KSpace.lg),
                          child: IntrinsicHeight(
                            child: AnimatedSwitcher(
                              duration: KMotion.of(context, KMotion.base),
                              layoutBuilder: (current, previous) =>
                                  Stack(alignment: Alignment.topCenter, children: [...previous, ?current]),
                              child: code
                                  ? _CodeStep(
                                      key: const ValueKey('code'),
                                      state: state,
                                      controller: _code,
                                      onSubmit: _submitCode,
                                    )
                                  : _DetailsStep(
                                      key: const ValueKey('details'),
                                      state: state,
                                      name: _name,
                                      email: _email,
                                      onSubmit: _submitDetails,
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (showInbox)
                  MockInboxBanner(
                    forEmail: state.email?.value,
                    onUse: (value) {
                      _code.text = value;
                      _submitCode();
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DetailsStep extends StatelessWidget {
  const _DetailsStep({super.key, required this.state, required this.name, required this.email, required this.onSubmit});
  final LoginState state;
  final TextEditingController name;
  final TextEditingController email;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final cubit = context.read<LoginCubit>();
    final signUp = state.mode == LoginMode.signUp;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(signUp ? 'Create your account' : 'Welcome back', style: KText.headline.copyWith(color: k.ink)),
        ),
        const SizedBox(height: KSpace.xs),
        Text(
          signUp ? 'Split expenses with friends in a few taps.' : 'Log in to see your groups and balances.',
          style: KText.body.copyWith(color: k.inkSecondary),
        ),
        const SizedBox(height: KSpace.xl),
        KSegmentedControl<LoginMode>(
          segments: const [KSegment(LoginMode.logIn, 'Log in'), KSegment(LoginMode.signUp, 'Sign up')],
          value: state.mode,
          onChanged: cubit.setMode,
        ),
        const SizedBox(height: KSpace.xl),
        if (signUp) ...[
          KTextField(
            label: 'Your name',
            hint: 'The name friends will see',
            controller: name,
            error: state.nameError,
            keyboardType: TextInputType.name,
            textCapitalization: TextCapitalization.words,
            autofillHints: const [AutofillHints.name],
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: KSpace.md),
        ],
        KTextField(
          label: 'Email',
          hint: 'you@example.com',
          controller: email,
          error: state.emailError,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          textInputAction: TextInputAction.go,
          onSubmitted: (_) => onSubmit(),
        ),
        const SizedBox(height: KSpace.lg),
        KButton(
          label: 'Email me a code',
          expand: true,
          loading: state.busy == LoginBusy.email,
          onPressed: state.isBusy ? null : onSubmit,
        ),
        const SizedBox(height: KSpace.sm),
        Text(
          'No password needed. We email you a 6-digit code.',
          textAlign: TextAlign.center,
          style: KText.small.copyWith(color: k.muted),
        ),
        const SizedBox(height: KSpace.xxl),
        const Spacer(),
        _OrDivider(label: signUp ? 'or sign up with' : 'or continue with'),
        const SizedBox(height: KSpace.lg),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            KSocialButton(
              provider: KSocial.apple,
              compact: true,
              loading: state.busy == LoginBusy.apple,
              onPressed: state.isBusy ? null : () => cubit.continueWith(SocialProvider.apple),
            ),
            const SizedBox(width: KSpace.lg),
            KSocialButton(
              provider: KSocial.google,
              compact: true,
              loading: state.busy == LoginBusy.google,
              onPressed: state.isBusy ? null : () => cubit.continueWith(SocialProvider.google),
            ),
            const SizedBox(width: KSpace.lg),
            // Kraken's own chat (the agent), asking one question at a time.
            KSocialButton(
              provider: KSocial.kraken,
              compact: true,
              onPressed: state.isBusy
                  ? null
                  : () {
                      context.analytics.log(SignInMethodChosen('agent', signUp: signUp));
                      context.go(Paths.signIn);
                    },
            ),
          ],
        ),
        const SizedBox(height: KSpace.lg),
        Text(
          'By continuing you agree to the Terms and Privacy Policy.',
          textAlign: TextAlign.center,
          style: KText.small.copyWith(color: k.muted),
        ),
      ],
    );
  }
}

class _CodeStep extends StatelessWidget {
  const _CodeStep({super.key, required this.state, required this.controller, required this.onSubmit});
  final LoginState state;
  final TextEditingController controller;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final cubit = context.read<LoginCubit>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text('Check your email', style: KText.headline.copyWith(color: k.ink)),
        ),
        const SizedBox(height: KSpace.xs),
        Text.rich(
          TextSpan(
            children: [
              const TextSpan(text: 'Enter the 6-digit code we sent to '),
              TextSpan(
                text: state.email?.value ?? 'your email',
                style: TextStyle(color: k.ink, fontWeight: FontWeight.w600),
              ),
              const TextSpan(text: '.'),
            ],
          ),
          style: KText.body.copyWith(color: k.inkSecondary),
        ),
        const SizedBox(height: KSpace.xl),
        KTextField(
          label: 'Code',
          hint: '000000',
          large: true,
          autofocus: true,
          controller: controller,
          error: state.codeError,
          maxLength: 6,
          keyboardType: TextInputType.number,
          autofillHints: const [AutofillHints.oneTimeCode],
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          // The sixth digit sends it; no need to find the button.
          onChanged: (value) {
            if (value.length == 6) onSubmit();
          },
          onSubmitted: (_) => onSubmit(),
        ),
        const SizedBox(height: KSpace.lg),
        KButton(
          label: state.mode == LoginMode.signUp ? 'Continue' : 'Log in',
          expand: true,
          loading: state.busy == LoginBusy.code,
          onPressed: state.isBusy ? null : onSubmit,
        ),
        const SizedBox(height: KSpace.sm),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            KButton(
              label: 'Resend code',
              variant: KButtonVariant.ghost,
              size: KButtonSize.small,
              onPressed: state.isBusy ? null : cubit.resend,
            ),
            KButton(
              label: 'Use a different email',
              variant: KButtonVariant.ghost,
              size: KButtonSize.small,
              onPressed: state.isBusy ? null : cubit.useDifferentEmail,
            ),
          ],
        ),
      ],
    );
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return Row(
      children: [
        Expanded(child: Divider(color: k.line, height: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: KSpace.md),
          child: Text(label, style: KText.small.copyWith(color: k.muted)),
        ),
        Expanded(child: Divider(color: k.line, height: 1)),
      ],
    );
  }
}
