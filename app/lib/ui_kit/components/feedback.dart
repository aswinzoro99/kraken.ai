import 'package:material_ui/material_ui.dart';

import '../../core/haptics/haptics.dart';
import '../foundation/haptics_scope.dart';
import '../theme/kraken_theme.dart';
import '../tokens/layout.dart';
import '../tokens/typography.dart';
import 'k_button.dart';

enum KToastKind { info, success, warning, error }

/// Short messages at the bottom of the screen, with an optional action such
/// as Undo. Each kind has its haptic.
abstract final class KToast {
  static void show(
    BuildContext context,
    String message, {
    KToastKind kind = KToastKind.info,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 4),
  }) {
    context.haptic(switch (kind) {
      KToastKind.info => HapticKind.tap,
      KToastKind.success => HapticKind.success,
      KToastKind.warning => HapticKind.warning,
      KToastKind.error => HapticKind.error,
    });
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          duration: duration,
          action: actionLabel == null
              ? null
              : SnackBarAction(
                  label: actionLabel,
                  onPressed: () {
                    context.haptic(HapticKind.warning);
                    onAction?.call();
                  },
                ),
        ),
      );
  }
}

/// Opens a Kraken bottom sheet.
Future<T?> showKSheet<T>(BuildContext context, {required WidgetBuilder builder}) {
  context.haptic(HapticKind.tap);
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.fromLTRB(KSpace.gutter, 0, KSpace.gutter, KSpace.xl + MediaQuery.viewInsetsOf(ctx).bottom),
      child: builder(ctx),
    ),
  );
}

/// Asks before something hard to undo. Resolves true only on confirm.
Future<bool> showConfirmSheet(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = 'Cancel',
  bool destructive = false,
}) async {
  context.haptic(HapticKind.warning);
  final result = await showModalBottomSheet<bool>(
    context: context,
    useSafeArea: true,
    builder: (ctx) {
      final k = ctx.k;
      return Padding(
        padding: const EdgeInsets.fromLTRB(KSpace.gutter, 0, KSpace.gutter, KSpace.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(title, style: KText.heading.copyWith(color: k.ink, fontSize: 19)),
            ),
            const SizedBox(height: KSpace.xs),
            Text(message, style: KText.body.copyWith(color: k.inkSecondary)),
            const SizedBox(height: KSpace.xl),
            KButton(
              label: confirmLabel,
              variant: destructive ? KButtonVariant.danger : KButtonVariant.primary,
              haptic: destructive ? HapticKind.heavy : HapticKind.tap,
              expand: true,
              onPressed: () => Navigator.of(ctx).pop(true),
            ),
            const SizedBox(height: KSpace.xs),
            KButton.secondary(label: cancelLabel, expand: true, onPressed: () => Navigator.of(ctx).pop(false)),
          ],
        ),
      );
    },
  );
  return result ?? false;
}
