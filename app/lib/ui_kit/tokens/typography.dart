import 'package:material_ui/material_ui.dart';

/// Type scale from the design: Poppins for display and headings, Inter for
/// everything people read. Colours are applied by the component.
abstract final class KFont {
  static const display = 'Poppins';
  static const body = 'Inter';
}

@immutable
final class KText {
  const KText._();

  /// Big balance figures (₹2,870).
  static const amountHero = TextStyle(
    fontFamily: KFont.display,
    fontWeight: FontWeight.w600,
    fontSize: 34,
    height: 1.1,
    letterSpacing: -0.8,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// Screen titles and the wordmark.
  static const title = TextStyle(
    fontFamily: KFont.display,
    fontWeight: FontWeight.w600,
    fontSize: 22,
    height: 1.2,
    letterSpacing: -0.4,
  );

  /// Landing headline.
  static const headline = TextStyle(
    fontFamily: KFont.display,
    fontWeight: FontWeight.w600,
    fontSize: 28,
    height: 1.18,
    letterSpacing: -0.6,
  );

  /// Section headings ("Your groups").
  static const heading = TextStyle(fontFamily: KFont.body, fontWeight: FontWeight.w600, fontSize: 16, height: 1.3);

  /// Small section labels above lists ("Preferences").
  static const overline = TextStyle(
    fontFamily: KFont.body,
    fontWeight: FontWeight.w500,
    fontSize: 13,
    height: 1.3,
    letterSpacing: 0.1,
  );

  static const body = TextStyle(fontFamily: KFont.body, fontWeight: FontWeight.w400, fontSize: 15, height: 1.45);
  static const bodyStrong = TextStyle(fontFamily: KFont.body, fontWeight: FontWeight.w500, fontSize: 15, height: 1.4);
  static const label = TextStyle(fontFamily: KFont.body, fontWeight: FontWeight.w500, fontSize: 14, height: 1.3);
  static const caption = TextStyle(fontFamily: KFont.body, fontWeight: FontWeight.w400, fontSize: 13, height: 1.4);
  static const small = TextStyle(fontFamily: KFont.body, fontWeight: FontWeight.w400, fontSize: 12, height: 1.35);
  static const tiny = TextStyle(fontFamily: KFont.body, fontWeight: FontWeight.w500, fontSize: 11, height: 1.3);
  static const amount = TextStyle(
    fontFamily: KFont.body,
    fontWeight: FontWeight.w500,
    fontSize: 15,
    fontFeatures: [FontFeature.tabularFigures()],
  );
}
