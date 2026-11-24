import 'package:flutter/rendering.dart' show OverflowBoxFit;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/kraken_app.dart';
import '../../../app/routes.dart';
import '../../../core/analytics/events.dart';
import '../../../core/storage/key_value_store.dart';
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
/// page showing it with a real piece of the app. Back and Next move one
/// slide, exactly like a swipe, and the last slide's Next is Get started (into
/// log in / sign up), so everyone sees every slide. Someone who has seen them
/// all before gets a Skip link.
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

  /// Seen every slide before (on this device): offer Skip.
  late final bool _seenBefore = context.read<KeyValueStore>().getBool(StoreKeys.welcomeSeen) ?? false;

  /// True while Back or Next is moving the slider; the button already
  /// played its haptic, so the page change doesn't add a second one.
  bool _driving = false;

  int get _last => WelcomeScreen.slides.length - 1;

  void _onPage(int page) {
    if (!_driving) context.haptic(HapticKind.selection);
    setState(() => _page = page);
    if (page == _last) context.read<KeyValueStore>().setBool(StoreKeys.welcomeSeen, true);
  }

  void _start() {
    context.analytics.log(const WelcomeStartTapped());
    // `go`, not `push`: sign-in replaces welcome, so its bloc survives the
    // session changing under it.
    context.go(Paths.login);
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Future<void> _goTo(int page) async {
    _driving = true;
    await _pages.animateToPage(
      page,
      duration: KMotion.of(context, const Duration(milliseconds: 450)),
      curve: KSpringCurve(KSpring.standard),
    );
    _driving = false;
  }

  @override
  Widget build(BuildContext context) {
    final config = context.config;
    final slides = WelcomeScreen.slides;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(KSpace.gutter, KSpace.lg, KSpace.sm, 0),
              child: SizedBox(
                height: 36,
                child: Row(
                  children: [
                    const KrakenLogo(fontSize: 20),
                    const Spacer(),
                    if (_seenBefore && _page != _last)
                      KButton(label: 'Skip', variant: KButtonVariant.ghost, size: KButtonSize.small, onPressed: _start),
                  ],
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pages,
                itemCount: slides.length,
                onPageChanged: _onPage,
                itemBuilder: (context, i) => _SlideView(slide: slides[i], active: i == _page),
              ),
            ),
            _Dots(count: slides.length, page: _page),
            const SizedBox(height: KSpace.xl),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: KSpace.gutter),
              child: _Controls(
                page: _page,
                last: _last,
                onBack: () => _goTo(_page - 1),
                onNext: () => _goTo(_page + 1),
                onStart: _start,
              ),
            ),
            const SizedBox(height: KSpace.md),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: KSpace.gutter),
              // The terms go with the button that starts sign-up.
              child: AnimatedOpacity(
                opacity: _page == _last ? 1 : 0,
                duration: KMotion.of(context, KMotion.base),
                child: ExcludeSemantics(
                  excluding: _page != _last,
                  child: _Legal(
                    onTerms: () => _showLink(context, 'Terms', config.termsUrl),
                    onPrivacy: () => _showLink(context, 'Privacy Policy', config.privacyPolicyUrl),
                  ),
                ),
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

/// Back and Next, which move one slide like a swipe. Back appears from the
/// second slide; on the last, Next becomes Get started.
class _Controls extends StatelessWidget {
  const _Controls({
    required this.page,
    required this.last,
    required this.onBack,
    required this.onNext,
    required this.onStart,
  });
  final int page;
  final int last;
  final VoidCallback onBack;
  final VoidCallback onNext;
  final VoidCallback onStart;

  static const _backWidth = 112.0;

  @override
  Widget build(BuildContext context) {
    final duration = KMotion.of(context, KMotion.base);
    final curve = KSpringCurve(KSpring.snappy);
    final showBack = page > 0;
    return Row(
      children: [
        AnimatedContainer(
          duration: duration,
          curve: curve,
          width: showBack ? _backWidth + KSpace.sm : 0,
          clipBehavior: Clip.hardEdge,
          decoration: const BoxDecoration(),
          child: OverflowBox(
            // Sized by the button, so the row stays the button's height.
            fit: OverflowBoxFit.deferToChild,
            alignment: Alignment.centerLeft,
            minWidth: _backWidth,
            maxWidth: _backWidth,
            child: ExcludeSemantics(
              excluding: !showBack,
              child: KButton(
                label: 'Back',
                variant: KButtonVariant.secondary,
                expand: true,
                haptic: HapticKind.selection,
                onPressed: showBack ? onBack : null,
              ),
            ),
          ),
        ),
        Expanded(
          child: AnimatedSwitcher(
            duration: duration,
            child: page == last
                ? KButton(key: const ValueKey('start'), label: 'Get started', expand: true, onPressed: onStart)
                : KButton(
                    key: const ValueKey('next'),
                    label: 'Next',
                    variant: KButtonVariant.secondary,
                    expand: true,
                    haptic: HapticKind.selection,
                    onPressed: onNext,
                  ),
          ),
        ),
      ],
    );
  }
}

/// Page dots: where you are, the current page a longer pill. Indicators
/// only; Back, Next and swiping move between slides.
class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.page});
  final int count;
  final int page;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final duration = KMotion.of(context, const Duration(milliseconds: 300));
    return Semantics(
      label: 'Slide ${page + 1} of $count',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < count; i++)
              AnimatedContainer(
                duration: duration,
                curve: KSpringCurve(KSpring.snappy),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: i == page ? 24 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: i == page ? k.primary : k.line,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
          ],
        ),
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
