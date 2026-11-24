import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../app/session.dart';
import '../core/analytics/analytics.dart';
import '../app/kraken_app.dart';
import '../app/services.dart';
import '../core/analytics/consent_gated_analytics.dart';
import '../core/haptics/haptics.dart';
import '../core/storage/key_value_store.dart';
import '../features/auth/data/mock_auth_repository.dart';
import '../features/auth/data/mock_inbox.dart';
import '../ui_kit/ui_kit.dart';

/// Hidden tools for dev and mock builds (7 taps on the version in Account).
/// Phase 0 adds the "Say hello" Gemini check here.
class DebugScreen extends StatelessWidget {
  const DebugScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final config = context.config;
    final session = context.watch<SessionCubit>().state;
    final gate = context.read<ConsentGatedAnalytics>();
    final haptics = context.read<Haptics>();
    final dev = context.read<DevTools>();
    final recorder = dev.recorder;
    final inbox = dev.inbox;
    final auth = dev.mockAuth;

    Widget section(String title, List<Widget> children) => Padding(
      padding: const EdgeInsets.fromLTRB(KSpace.gutter, KSpace.xl, KSpace.gutter, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          KSectionHeader(title: title),
          const SizedBox(height: KSpace.xxs),
          ...children,
        ],
      ),
    );

    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          KTopBar(title: 'Debug tools', subtitle: 'Not shown in production builds', onBack: () => context.pop()),
          section('Build', [
            KGroupedList(
              children: [
                KNavRow(title: 'Flavor', value: config.flavor.name),
                KNavRow(title: 'API', value: config.apiBaseUrl.host),
                KNavRow(title: 'Policy version', value: config.privacyPolicyVersion),
                KNavRow(title: 'Session', value: session.runtimeType.toString()),
              ],
            ),
          ]),
          section('Haptics', [
            Wrap(
              spacing: KSpace.xs,
              runSpacing: KSpace.xs,
              children: [
                for (final kind in HapticKind.values)
                  KButton.secondary(label: kind.name, size: KButtonSize.small, haptic: kind, onPressed: () {}),
              ],
            ),
            const SizedBox(height: KSpace.xs),
            ValueListenableBuilder(
              valueListenable: haptics.enabled,
              builder: (context, on, _) => Text(
                on ? 'Vibration is on' : 'Vibration is off in Account',
                style: KText.small.copyWith(color: k.muted),
              ),
            ),
          ]),
          if (inbox != null && auth != null)
            section('Mock server', [
              ValueListenableBuilder<MockEmail?>(
                valueListenable: inbox,
                builder: (context, email, _) => KBanner(
                  tone: KBannerTone.warning,
                  icon: Icons.mark_email_unread_outlined,
                  child: Text(email == null ? 'No code sent yet' : 'Last code ${email.code} to ${email.to}'),
                ),
              ),
              const SizedBox(height: KSpace.xs),
              _FailNextSwitch(auth: auth),
              const SizedBox(height: KSpace.xs),
              KButton(
                label: 'Reset app data',
                variant: KButtonVariant.danger,
                size: KButtonSize.medium,
                icon: Icons.restart_alt_rounded,
                onPressed: () async {
                  final ok = await showConfirmSheet(
                    context,
                    title: 'Reset app data?',
                    message: 'Signs out and clears every mock profile and setting on this phone.',
                    confirmLabel: 'Reset',
                    destructive: true,
                  );
                  if (!ok || !context.mounted) return;
                  final store = context.read<KeyValueStore>();
                  await auth.signOut();
                  await store.clear();
                },
              ),
            ]),
          section('Analytics', [
            Text(
              'Consent: ${gate.consent.name} · held back: ${gate.bufferedCount}',
              style: KText.caption.copyWith(color: k.inkSecondary),
            ),
            const SizedBox(height: KSpace.xs),
            if (recorder != null) ...[
              ListenableBuilder(
                listenable: recorder,
                builder: (context, _) {
                  final events = recorder.events.reversed.take(40).toList();
                  if (events.isEmpty) {
                    return Text(
                      'Nothing sent yet. Events wait for the usage-stats answer in sign-up.',
                      style: KText.small.copyWith(color: k.muted),
                    );
                  }
                  return KGroupedList(children: [for (final e in events) _EventRow(e)]);
                },
              ),
              const SizedBox(height: KSpace.xs),
              Align(
                alignment: Alignment.centerLeft,
                child: KButton.ghost(label: 'Clear events', onPressed: recorder.clear),
              ),
            ],
          ]),
          const SizedBox(height: KSpace.xxxl),
        ],
      ),
    );
  }
}

class _EventRow extends StatelessWidget {
  const _EventRow(this.event);
  final RecordedEvent event;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final t = event.at;
    String two(int v) => v.toString().padLeft(2, '0');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: KSpace.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${two(t.hour)}:${two(t.minute)}:${two(t.second)}', style: KText.small.copyWith(color: k.muted)),
          const SizedBox(width: KSpace.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(event.name, style: KText.label.copyWith(color: k.ink)),
                if (event.params.isNotEmpty)
                  Text(
                    event.params.entries.map((e) => '${e.key}=${e.value}').join('  '),
                    style: KText.small.copyWith(color: k.inkSecondary),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FailNextSwitch extends StatefulWidget {
  const _FailNextSwitch({required this.auth});
  final MockAuthRepository auth;

  @override
  State<_FailNextSwitch> createState() => _FailNextSwitchState();
}

class _FailNextSwitchState extends State<_FailNextSwitch> {
  @override
  Widget build(BuildContext context) => KGroupedList(
    children: [
      KSwitchRow(
        title: 'Fail the next request',
        subtitle: 'Pretend to be offline once, to see the error replies',
        value: widget.auth.failNextRequest,
        onChanged: (v) => setState(() => widget.auth.failNextRequest = v),
      ),
    ],
  );
}
