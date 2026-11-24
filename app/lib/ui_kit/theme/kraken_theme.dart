import 'package:material_ui/material_ui.dart';

import '../tokens/colors.dart';
import '../tokens/layout.dart';
import '../tokens/typography.dart';

abstract final class KrakenTheme {
  static ThemeData light() => _build(KColors.light, Brightness.light);
  static ThemeData dark() => _build(KColors.dark, Brightness.dark);

  static ThemeData _build(KColors k, Brightness brightness) {
    final scheme = ColorScheme(
      brightness: brightness,
      primary: k.primary,
      onPrimary: k.onPrimary,
      secondary: k.primaryText,
      onSecondary: k.onPrimary,
      error: k.danger,
      onError: k.onPrimary,
      surface: k.surface,
      onSurface: k.ink,
      surfaceContainerHighest: k.surfaceMuted,
      outline: k.line,
      outlineVariant: k.divider,
      inverseSurface: k.inverse,
      onInverseSurface: k.onInverse,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: k.background,
      fontFamily: KFont.body,
      extensions: [k],
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      textTheme: TextTheme(
        headlineMedium: KText.headline.copyWith(color: k.ink),
        titleLarge: KText.title.copyWith(color: k.ink),
        titleMedium: KText.heading.copyWith(color: k.ink),
        bodyLarge: KText.body.copyWith(color: k.ink),
        bodyMedium: KText.caption.copyWith(color: k.ink),
        labelLarge: KText.label.copyWith(color: k.ink),
      ),
      textSelectionTheme: TextSelectionThemeData(cursorColor: k.primary, selectionHandleColor: k.primary),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: k.inverse,
        contentTextStyle: KText.caption.copyWith(color: k.onInverse),
        actionTextColor: k.owedOnInverse,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(KRadius.lg)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: k.surface,
        showDragHandle: true,
        dragHandleColor: k.line,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: KRadius.xxl)),
      ),
      switchTheme: SwitchThemeData(
        trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? k.primary : k.line),
        thumbColor: const WidgetStatePropertyAll(Colors.white),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
    );
  }
}

extension KContext on BuildContext {
  /// Kraken colour tokens for the current theme.
  KColors get k => Theme.of(this).extension<KColors>() ?? KColors.light;
}
