import 'package:material_ui/material_ui.dart';

/// Kraken's colour tokens, taken from the design canvas. Components read
/// these through `context.k`; never hard-code a colour in a widget.
@immutable
final class KColors extends ThemeExtension<KColors> {
  const KColors({
    required this.background,
    required this.surface,
    required this.surfaceMuted,
    required this.ink,
    required this.inkSecondary,
    required this.muted,
    required this.placeholder,
    required this.line,
    required this.divider,
    required this.primary,
    required this.primaryText,
    required this.onPrimary,
    required this.disabled,
    required this.owe,
    required this.owed,
    required this.success,
    required this.successSoft,
    required this.warning,
    required this.warningSoft,
    required this.danger,
    required this.dangerSoft,
    required this.info,
    required this.infoSoft,
    required this.inverse,
    required this.inverseRaised,
    required this.onInverse,
    required this.onInverseMuted,
    required this.owedOnInverse,
    required this.oweOnInverse,
    required this.accentSoft,
    required this.neutralSoft,
    required this.chartMuted,
    required this.tabIdle,
    required this.tabSelected,
    required this.tabPill,
    required this.tabAdd,
  });

  final Color background;
  final Color surface;
  final Color surfaceMuted;
  final Color ink;
  final Color inkSecondary;
  final Color muted;
  final Color placeholder;
  final Color line;
  final Color divider;
  final Color primary;
  final Color primaryText;
  final Color onPrimary;
  final Color disabled;

  /// "You owe" amounts.
  final Color owe;

  /// "You're owed" amounts.
  final Color owed;
  final Color success;
  final Color successSoft;
  final Color warning;
  final Color warningSoft;
  final Color danger;
  final Color dangerSoft;
  final Color info;
  final Color infoSoft;

  /// The dark balance card and action dock.
  final Color inverse;
  final Color inverseRaised;
  final Color onInverse;
  final Color onInverseMuted;
  final Color owedOnInverse;
  final Color oweOnInverse;
  final Color accentSoft;
  final Color neutralSoft;

  /// De-emphasised chart marks (months not selected). Kept at 3:1 against
  /// the page, the WCAG minimum for graphics.
  final Color chartMuted;

  /// The tab bar, from the tab-icons spec: idle icons, the selected icon,
  /// the pill behind it, and the + button, which stays this blue in dark
  /// mode too, with a white plus.
  final Color tabIdle;
  final Color tabSelected;
  final Color tabPill;
  final Color tabAdd;

  static const light = KColors(
    background: Color(0xFFFFFFFF),
    surface: Color(0xFFFFFFFF),
    surfaceMuted: Color(0xFFF4F5F7),
    ink: Color(0xFF15171C),
    inkSecondary: Color(0xFF4B5260),
    muted: Color(0xFF626873),
    placeholder: Color(0xFF7A808C),
    line: Color(0xFFE6E8EC),
    divider: Color(0xFFF0F1F4),
    primary: Color(0xFF2348DE),
    primaryText: Color(0xFF1C3BB8),
    onPrimary: Color(0xFFFFFFFF),
    disabled: Color(0xFFA3A9B5),
    owe: Color(0xFFB9480F),
    owed: Color(0xFF1C3BB8),
    success: Color(0xFF166534),
    successSoft: Color(0xFFDCF3E8),
    warning: Color(0xFF92400E),
    warningSoft: Color(0xFFFDECC8),
    danger: Color(0xFFB42318),
    dangerSoft: Color(0xFFFDE5E2),
    info: Color(0xFF1C2A66),
    infoSoft: Color(0xFFE9EEFF),
    inverse: Color(0xFF15171C),
    inverseRaised: Color(0xFF23262E),
    onInverse: Color(0xFFFFFFFF),
    onInverseMuted: Color(0xFFC9CDD6),
    owedOnInverse: Color(0xFFA9BCFF),
    oweOnInverse: Color(0xFFFFB48A),
    accentSoft: Color(0xFFDDE4FF),
    neutralSoft: Color(0xFFECEEF2),
    chartMuted: Color(0xFF8D94A1),
    tabIdle: Color(0xFF626873),
    tabSelected: Color(0xFF2348DE),
    tabPill: Color(0xFFE9EEFF),
    tabAdd: Color(0xFF2348DE),
  );

  /// Not in the canvas; derived so the app is usable in dark mode.
  static const dark = KColors(
    background: Color(0xFF0E1014),
    surface: Color(0xFF0E1014),
    surfaceMuted: Color(0xFF1A1D24),
    ink: Color(0xFFE9EBF0),
    inkSecondary: Color(0xFFBCC2CD),
    muted: Color(0xFF949BA8),
    placeholder: Color(0xFF7D8491),
    line: Color(0xFF262A33),
    divider: Color(0xFF1C1F26),
    primary: Color(0xFF5B78F0),
    primaryText: Color(0xFF9DB0FF),
    onPrimary: Color(0xFFFFFFFF),
    disabled: Color(0xFF4A505C),
    owe: Color(0xFFFFA36E),
    owed: Color(0xFF9DB0FF),
    success: Color(0xFF6FD3A0),
    successSoft: Color(0xFF123326),
    warning: Color(0xFFF5B76A),
    warningSoft: Color(0xFF3A2A12),
    danger: Color(0xFFFF8A7A),
    dangerSoft: Color(0xFF3B1915),
    info: Color(0xFFC9D4FF),
    infoSoft: Color(0xFF1D2547),
    inverse: Color(0xFF23262E),
    inverseRaised: Color(0xFF2E323C),
    onInverse: Color(0xFFFFFFFF),
    onInverseMuted: Color(0xFFC9CDD6),
    owedOnInverse: Color(0xFFA9BCFF),
    oweOnInverse: Color(0xFFFFB48A),
    accentSoft: Color(0xFF1D2547),
    neutralSoft: Color(0xFF1E222B),
    chartMuted: Color(0xFF5A606C),
    tabIdle: Color(0xFFA3A9B5),
    tabSelected: Color(0xFFA9BCFF),
    tabPill: Color(0xFF27305A),
    tabAdd: Color(0xFF2348DE),
  );

  @override
  KColors copyWith() => this;

  @override
  KColors lerp(KColors? other, double t) => t < 0.5 ? this : (other ?? this);
}
