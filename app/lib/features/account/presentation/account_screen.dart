import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/routes.dart';
import '../../../app/session.dart';
import '../../../app/kraken_app.dart';
import '../../../core/analytics/analytics_consent_cubit.dart';
import '../../../core/analytics/consent_gated_analytics.dart';
import '../../../core/analytics/events.dart';
import '../../../core/haptics/haptics.dart';
import '../../../ui_kit/ui_kit.dart';
import '../../auth/domain/auth_repository.dart';
import '../../profile/domain/profile_repository.dart';

/// Account: who you are, privacy and feel settings, sign out and delete.
class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  /// Kept in step with `version:` in pubspec.yaml.
  static const version = '0.1.0 (1)';

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  int _versionTaps = 0;

  void _tapVersion() {
    if (!context.config.showDebugTools) return;
    _versionTaps++;
    final left = 7 - _versionTaps;
    if (left <= 0) {
      _versionTaps = 0;
      context.push(Paths.debug);
    } else if (left <= 3) {
      KToast.show(context, '$left more ${left == 1 ? 'tap' : 'taps'} to open debug tools');
    }
  }

  Future<void> _signOut() async {
    final ok = await showConfirmSheet(
      context,
      title: 'Sign out of Kraken?',
      message: 'Your groups stay as they are. Sign in again with the same email to get back to them.',
      confirmLabel: 'Sign out',
    );
    if (!ok) return;
    if (!mounted) return;
    await context.analytics.log(const SignedOut());
    if (!mounted) return;
    await context.read<AuthRepository>().signOut();
  }

  Future<void> _delete(String uid) async {
    final ok = await showConfirmSheet(
      context,
      title: 'Delete your account?',
      message:
          'Kraken deletes your profile and chats. Friends keep your name in shared groups so their balances '
          'still add up. This can’t be undone.',
      confirmLabel: 'Delete account',
      destructive: true,
    );
    if (!ok) return;
    if (!mounted) return;
    final profiles = context.read<ProfileRepository>();
    final auth = context.read<AuthRepository>();
    await context.analytics.log(const AccountDeleted());
    await profiles.delete(uid);
    await auth.deleteAccount();
  }

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final session = context.watch<SessionCubit>().state;
    final haptics = context.read<Haptics>();
    final consent = context.watch<AnalyticsConsentCubit>().state;
    final config = context.config;
    if (session is! ReadySession) return const SizedBox.shrink();
    final profile = session.profile;
    final name = profile.displayName ?? 'You';

    return ListView(
      // Room at the end for the floating glass tab bar.
      padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
      children: [
        const KTopBar(title: 'Account'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: KSpace.gutter),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: KSpace.sm),
                child: Row(
                  children: [
                    KAvatar(name: name, size: 48, circle: true, tone: KTone.neutral),
                    const SizedBox(width: KSpace.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, style: KText.heading.copyWith(color: k.ink)),
                          Text(session.user.email.value, style: KText.caption.copyWith(color: k.muted)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: KSpace.xl),
              const KSectionHeader(title: 'Payments'),
              KGroupedList(
                children: [
                  KNavRow(
                    title: 'UPI ID',
                    icon: Icons.account_balance_wallet_outlined,
                    value: profile.upiId ?? 'Not added',
                    onTap: () => KToast.show(context, 'Editing your UPI ID arrives in Phase 6.'),
                  ),
                ],
              ),
              const SizedBox(height: KSpace.xl),
              const KSectionHeader(title: 'Preferences'),
              KGroupedList(
                children: [
                  ValueListenableBuilder<bool>(
                    valueListenable: haptics.enabled,
                    builder: (context, on, _) => KSwitchRow(
                      title: 'Vibration',
                      subtitle: 'A light buzz when you tap, save or undo',
                      value: on,
                      onChanged: (v) {
                        haptics.setEnabled(v);
                        context.analytics.log(SettingChanged(setting: 'haptics', enabled: v));
                      },
                    ),
                  ),
                  KSwitchRow(
                    title: 'Share usage stats',
                    subtitle: 'Anonymous: which screens you open, never names or amounts',
                    value: consent == AnalyticsConsent.granted,
                    onChanged: (v) => context.read<AnalyticsConsentCubit>().set(granted: v),
                  ),
                ],
              ),
              const SizedBox(height: KSpace.xl),
              const KSectionHeader(title: 'Privacy'),
              KGroupedList(
                children: [
                  KNavRow(
                    title: 'Privacy Policy',
                    icon: Icons.shield_outlined,
                    onTap: () => KToast.show(context, 'Privacy Policy: ${config.privacyPolicyUrl}'),
                  ),
                  KNavRow(
                    title: 'Terms',
                    icon: Icons.description_outlined,
                    onTap: () => KToast.show(context, 'Terms: ${config.termsUrl}'),
                  ),
                ],
              ),
              const SizedBox(height: KSpace.xl),
              KGroupedList(
                children: [
                  KNavRow(title: 'Sign out', icon: Icons.logout_rounded, onTap: _signOut),
                  KNavRow(
                    title: 'Delete account',
                    icon: Icons.delete_outline_rounded,
                    destructive: true,
                    onTap: () => _delete(session.user.uid),
                  ),
                ],
              ),
              const SizedBox(height: KSpace.lg),
              Center(
                child: KPressable(
                  onTap: _tapVersion,
                  haptic: config.showDebugTools ? HapticKind.selection : null,
                  pressedScale: 1,
                  semanticLabel: 'Version ${AccountScreen.version}',
                  child: Padding(
                    padding: const EdgeInsets.all(KSpace.sm),
                    child: Text(
                      'Kraken ${AccountScreen.version} · ${config.flavor.name}',
                      style: KText.small.copyWith(color: k.muted),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: KSpace.xxl),
            ],
          ),
        ),
      ],
    );
  }
}
