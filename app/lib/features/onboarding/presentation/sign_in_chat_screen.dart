import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/routes.dart';
import '../../../ui_kit/ui_kit.dart';
import '../domain/onboarding_machine.dart';
import '../../../app/kraken_app.dart';
import '../../../app/services.dart';
import '../../../app/session.dart';
import 'onboarding_bloc.dart';
import 'onboarding_copy.dart';
import 'widgets/mock_inbox_banner.dart';

/// Sign in by chat: no forms, no passwords (design: "Sign in — chat").
class SignInChatScreen extends StatelessWidget {
  const SignInChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final config = context.config;
    return BlocProvider(
      create: (context) => OnboardingBloc(
        session: context.read<SessionCubit>().state,
        auth: context.read(),
        profiles: context.read(),
        analytics: context.analytics,
        haptics: context.read(),
        store: context.read(),
        clock: context.read(),
        policyVersion: config.privacyPolicyVersion,
        privacyPolicyUrl: config.privacyPolicyUrl,
        pacing: config.chatPacing,
      ),
      child: const _SignInChatView(),
    );
  }
}

class _SignInChatView extends StatefulWidget {
  const _SignInChatView();

  @override
  State<_SignInChatView> createState() => _SignInChatViewState();
}

class _SignInChatViewState extends State<_SignInChatView> {
  final _input = TextEditingController();

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final view = context.watch<OnboardingBloc>().state;
    final bloc = context.read<OnboardingBloc>();
    final k = context.k;
    final meta = _InputMeta.of(view.stage);
    final showInbox = context.read<DevTools>().inbox != null && view.stage == Stage.code;

    return BlocListener<OnboardingBloc, OnboardingChatState>(
      listenWhen: (a, b) => b.notice != null && a.notice != b.notice,
      listener: (context, state) {
        KToast.show(context, state.notice!);
        bloc.add(const OnboardingNoticeShown());
      },
      child: Scaffold(
        body: Column(
          children: [
            KTopBar(
              bordered: true,
              // Back to welcome only before anyone is signed in.
              onBack: context.watch<SessionCubit>().state is SignedOutSession ? () => context.go(Paths.welcome) : null,
              leading: const KrakenLogo(fontSize: 18),
            ),
            Expanded(child: _Transcript(view: view)),
            if (showInbox)
              MockInboxBanner(
                forEmail: view.machine.email?.value,
                onUse: (code) => bloc.add(OnboardingTextSubmitted(code)),
              ),
            if (view.chips.isNotEmpty && view.canInteract)
              Padding(
                padding: const EdgeInsets.fromLTRB(KSpace.lg, 0, KSpace.lg, KSpace.md),
                child: KChipRow(
                  alignment: WrapAlignment.end,
                  children: [
                    for (final chip in view.chips)
                      KChip(label: OnboardingCopy.chip(chip), onTap: () => bloc.add(OnboardingChipPicked(chip))),
                  ],
                ),
              ),
            if (view.stage == Stage.email)
              Padding(
                padding: const EdgeInsets.fromLTRB(KSpace.gutter, 0, KSpace.gutter, KSpace.xs),
                child: Text(
                  'By continuing you agree to the Terms and Privacy Policy.',
                  textAlign: TextAlign.center,
                  style: KText.small.copyWith(color: k.muted),
                ),
              ),
            if (view.stage == Stage.done && !view.typing)
              Padding(
                padding: EdgeInsets.fromLTRB(
                  KSpace.lg,
                  KSpace.xs,
                  KSpace.lg,
                  KSpace.md + MediaQuery.paddingOf(context).bottom,
                ),
                child: KButton(
                  label: 'Open your groups',
                  expand: true,
                  haptic: HapticKind.success,
                  onPressed: () => context.go(Paths.home),
                ),
              )
            else
              ChatInputBar(
                key: ValueKey(meta.label),
                controller: _input,
                label: meta.label,
                placeholder: view.machine.isBusy ? 'One moment…' : meta.placeholder,
                keyboardType: meta.keyboard,
                autofillHints: meta.autofill,
                textCapitalization: meta.capitalization,
                enabled: view.canInteract && view.machine.acceptsText,
                onSubmitted: (text) => bloc.add(OnboardingTextSubmitted(text)),
              ),
          ],
        ),
      ),
    );
  }
}

class _Transcript extends StatelessWidget {
  const _Transcript({required this.view});
  final OnboardingChatState view;

  @override
  Widget build(BuildContext context) {
    final items = view.messages;
    // Newest at the bottom; a reversed list keeps the latest message in view
    // as the keyboard opens and closes.
    return ListView.builder(
      reverse: true,
      padding: const EdgeInsets.fromLTRB(KSpace.lg, KSpace.lg, KSpace.lg, KSpace.md),
      itemCount: items.length + (view.typing ? 1 : 0),
      itemBuilder: (context, index) {
        if (view.typing && index == 0) {
          return const Padding(
            padding: EdgeInsets.only(top: KSpace.xs),
            child: TypingIndicator(),
          );
        }
        final i = items.length - 1 - (index - (view.typing ? 1 : 0));
        final entry = items[i];
        final next = i + 1 < items.length ? items[i + 1] : null;
        final lastInRun = next == null || !next.fromKraken;
        final previous = i > 0 ? items[i - 1] : null;
        final sameAuthor = previous != null && previous.fromKraken == entry.fromKraken;
        return Padding(
          padding: EdgeInsets.only(top: i == 0 ? 0 : (sameAuthor ? 4 : KSpace.md)),
          child: _Appear(
            key: ValueKey(i),
            child: ChatBubble(
              author: entry.fromKraken ? ChatAuthor.kraken : ChatAuthor.me,
              text: entry.text,
              showAvatar: entry.fromKraken && lastInRun && !(next == null && view.typing),
            ),
          ),
        );
      },
    );
  }
}

/// New bubbles slide up and fade in, unless motion is reduced.
class _Appear extends StatelessWidget {
  const _Appear({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final duration = KMotion.of(context, KMotion.base);
    if (duration == Duration.zero) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: duration,
      curve: KMotion.curve,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, 8 * (1 - t)), child: child),
      ),
      child: child,
    );
  }
}

final class _InputMeta {
  const _InputMeta(
    this.label,
    this.placeholder,
    this.keyboard, {
    this.autofill,
    this.capitalization = TextCapitalization.none,
  });

  final String label;
  final String placeholder;
  final TextInputType keyboard;
  final Iterable<String>? autofill;
  final TextCapitalization capitalization;

  static _InputMeta of(Stage stage) => switch (stage) {
    Stage.email || Stage.sendingCode => const _InputMeta(
      'Email address',
      'you@example.com',
      TextInputType.emailAddress,
      autofill: [AutofillHints.email],
    ),
    Stage.code || Stage.verifying => const _InputMeta(
      'Verification code',
      '6-digit code',
      TextInputType.number,
      autofill: [AutofillHints.oneTimeCode],
    ),
    Stage.name => const _InputMeta(
      'Your name',
      'Your name',
      TextInputType.name,
      autofill: [AutofillHints.name],
      capitalization: TextCapitalization.words,
    ),
    Stage.upi => const _InputMeta('UPI ID', 'name@bank', TextInputType.emailAddress),
    Stage.invite => const _InputMeta('Invite link', 'Paste an invite link', TextInputType.url),
    Stage.adult ||
    Stage.privacy ||
    Stage.analytics ||
    Stage.group ||
    Stage.blocked => const _InputMeta('Message', 'Pick an option above', TextInputType.text),
    Stage.done => const _InputMeta('Message', "You're all set", TextInputType.text),
  };
}
