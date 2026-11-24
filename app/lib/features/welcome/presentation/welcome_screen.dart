import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/kraken_app.dart';
import '../../../app/routes.dart';
import '../../../core/analytics/events.dart';
import '../../../ui_kit/ui_kit.dart';
import 'widgets/usage_examples.dart';

/// One page of the welcome slider: a real piece of the app, then words.
final class _Slide {
  const _Slide(this.example, this.title, this.body);

  /// Builds the example; `active` while its slide is in view.
  final Widget Function(bool active) example;
  final String title;
  final String body;
}

/// The first screen a new person sees: a slider of what Kraken does, each
/// page showing it with a real piece of the app, and "Get started" into the
/// sign-in chat on every page.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  static final slides = [
    _Slide(
      (active) => BalancesExample(active: active),
      'Split bills, not friendships',
      'Kraken keeps track of who paid and who owes, in every group you share.',
    ),
    _Slide(
      (active) => ChatExample(active: active),
      'Just say it',
      '“Cab 450 with Arjun, split equally.” Kraken writes it down and does the maths.',
    ),
    _Slide(
      (active) => BillExample(active: active),
      'Snap the bill',
      'Take a photo of a bill and split it item by item. No typing.',
    ),
    _Slide(
      (active) => SettleExample(active: active),
      'Settle up in a tap',
      'See where you stand with everyone, and pay back by UPI.',
    ),
  ];

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final _pages = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _goTo(int page) => _pages.animateToPage(
    page,
    duration: KMotion.of(context, const Duration(milliseconds: 450)),
    curve: KSpringCurve(KSpring.standard),
  );

  @override
  Widget build(BuildContext context) {
    final config = context.config;
    final slides = WelcomeScreen.slides;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(KSpace.gutter, KSpace.lg, KSpace.gutter, 0),
              child: Align(alignment: Alignment.centerLeft, child: KrakenLogo(fontSize: 20)),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pages,
                itemCount: slides.length,
                onPageChanged: (page) {
                  context.haptic(HapticKind.selection);
                  setState(() => _page = page);
                },
                itemBuilder: (context, i) => _SlideView(slide: slides[i], active: i == _page),
              ),
            ),
            _Dots(count: slides.length, page: _page, onTap: _goTo),
            const SizedBox(height: KSpace.xl),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: KSpace.gutter),
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: KSpace.gutter),
              child: _Legal(
                onTerms: () => _showLink(context, 'Terms', config.termsUrl),
                onPrivacy: () => _showLink(context, 'Privacy Policy', config.privacyPolicyUrl),
              ),
            ),
            const SizedBox(height: KSpace.lg),
          ],
        ),
      ),
    );
  }

  // url_launcher arrives with Phase 2 (invite links); until then, show it.
  void _showLink(BuildContext context, String name, Uri url) => KToast.show(context, '$name: $url');
}

class _SlideView extends StatelessWidget {
  const _SlideView({required this.slide, required this.active});
  final _Slide slide;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return LayoutBuilder(
      builder: (context, c) => Column(
        children: [
          // The example takes the room the words don't need, and shrinks to
          // fit on small phones.
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(KSpace.gutter, KSpace.lg, KSpace.gutter, KSpace.lg),
              // Sits a little low, nearer the words that explain it.
              child: Align(
                alignment: const Alignment(0, 0.4),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  // A demo, not controls: the words below say what it shows.
                  child: ExcludeSemantics(child: IgnorePointer(child: slide.example(active))),
                ),
              ),
            ),
          ),
          ConstrainedBox(
            // Very large text scrolls rather than squeezing out the drawing.
            constraints: BoxConstraints(maxHeight: c.maxHeight * 0.45),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: KSpace.gutter + KSpace.sm),
              child: Column(
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      slide.title,
                      textAlign: TextAlign.center,
                      style: KText.headline.copyWith(color: k.ink),
                    ),
                  ),
                  const SizedBox(height: KSpace.sm),
                  Text(
                    slide.body,
                    textAlign: TextAlign.center,
                    style: KText.body.copyWith(color: k.inkSecondary),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: KSpace.lg),
        ],
      ),
    );
  }
}

/// Page dots: the current page is a longer pill. Each dot is a button that
/// jumps to its page.
class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.page, required this.onTap});
  final int count;
  final int page;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final duration = KMotion.of(context, const Duration(milliseconds: 300));
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          Semantics(
            button: true,
            selected: i == page,
            label: 'Slide ${i + 1} of $count',
            excludeSemantics: true,
            onTap: () => onTap(i),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onTap(i),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
                child: AnimatedContainer(
                  duration: duration,
                  curve: KSpringCurve(KSpring.snappy),
                  width: i == page ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: i == page ? k.primary : k.line,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ),
      ],
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
