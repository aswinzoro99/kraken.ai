import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/routes.dart';
import '../../../core/analytics/events.dart';
import '../../../app/kraken_app.dart';
import '../../../ui_kit/ui_kit.dart';

/// The first screen a new person sees: what Kraken does, then "Get started"
/// into the sign-in chat. Phone version of the desktop sign-in landing.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final config = context.config;
    final features = const [
      (Icons.mic_none_rounded, '“Add me, Sreya for 2100, equal split”'),
      (Icons.document_scanner_outlined, 'Snap a bill, split it by item'),
      (Icons.insights_outlined, 'See where your money goes'),
    ];
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: KSpace.gutter),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: KSpace.lg),
                    const _Rise(
                      order: 0,
                      child: Align(alignment: Alignment.centerLeft, child: KrakenLogo(fontSize: 20)),
                    ),
                    const Spacer(),
                    const SizedBox(height: KSpace.xxxl),
                    _Rise(
                      order: 1,
                      child: Semantics(
                        header: true,
                        child: Text.rich(
                          TextSpan(
                            children: [
                              const TextSpan(text: 'Split expenses with friends. '),
                              TextSpan(
                                text: 'Just say it, or snap the bill.',
                                style: TextStyle(color: k.muted),
                              ),
                            ],
                          ),
                          style: KText.headline.copyWith(color: k.ink),
                        ),
                      ),
                    ),
                    const SizedBox(height: KSpace.xxl),
                    for (final (i, f) in features.indexed) ...[
                      _Rise(
                        order: 2 + i,
                        child: _Feature(icon: f.$1, text: f.$2),
                      ),
                      const SizedBox(height: KSpace.md),
                    ],
                    const Spacer(),
                    const SizedBox(height: KSpace.xl),
                    _Rise(
                      order: 6,
                      child: KButton(
                        label: 'Get started',
                        expand: true,
                        onPressed: () {
                          context.analytics.log(const WelcomeStartTapped());
                          // `go`, not `push`: sign-in replaces welcome, so the chat
                          // (and its bloc) survives the session changing under it.
                          context.go(Paths.signIn);
                        },
                      ),
                    ),
                    const SizedBox(height: KSpace.md),
                    _Legal(
                      onTerms: () => _showLink(context, 'Terms', config.termsUrl),
                      onPrivacy: () => _showLink(context, 'Privacy Policy', config.privacyPolicyUrl),
                    ),
                    const SizedBox(height: KSpace.lg),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // url_launcher arrives with Phase 2 (invite links); until then, show it.
  void _showLink(BuildContext context, String name, Uri url) => KToast.show(context, '$name: $url');
}

class _Feature extends StatelessWidget {
  const _Feature({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return MergeSemantics(
      child: Row(
        children: [
          Icon(icon, size: 20, color: k.muted),
          const SizedBox(width: KSpace.md),
          Expanded(
            child: Text(text, style: KText.body.copyWith(color: k.inkSecondary)),
          ),
        ],
      ),
    );
  }
}

class _Legal extends StatelessWidget {
  const _Legal({required this.onTerms, required this.onPrivacy});
  final VoidCallback onTerms;
  final VoidCallback onPrivacy;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final style = KText.small.copyWith(color: k.muted);
    final link = style.copyWith(color: k.ink, fontWeight: FontWeight.w500);
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text('By continuing you agree to the ', style: style),
        KPressable(
          onTap: onTerms,
          semanticLabel: 'Terms',
          child: Text('Terms', style: link),
        ),
        Text(' and ', style: style),
        KPressable(
          onTap: onPrivacy,
          semanticLabel: 'Privacy Policy',
          child: Text('Privacy Policy', style: link),
        ),
        Text('.', style: style),
      ],
    );
  }
}

/// Staggered fade-and-rise on first show. Skipped under reduced motion.
class _Rise extends StatelessWidget {
  const _Rise({required this.order, required this.child});
  final int order;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final total = KMotion.of(context, Duration(milliseconds: 360 + order * 70));
    if (total == Duration.zero) return child;
    final start = order * 70 / total.inMilliseconds;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: total,
      builder: (context, t, child) {
        final p = KMotion.curve.transform(((t - start) / (1 - start)).clamp(0, 1));
        return Opacity(
          opacity: p,
          child: Transform.translate(offset: Offset(0, 12 * (1 - p)), child: child),
        );
      },
      child: child,
    );
  }
}
