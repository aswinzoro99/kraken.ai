import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../theme/kraken_theme.dart';
import '../tokens/typography.dart';

/// "NOV / 23", like the expense list in the Group design.
class KDateBlock extends StatelessWidget {
  const KDateBlock(this.date, {super.key});
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return Semantics(
      label: DateFormat('d MMMM').format(date),
      excludeSemantics: true,
      child: SizedBox(
        width: 40,
        child: Column(
          children: [
            Text(
              DateFormat.MMM().format(date).toUpperCase(),
              style: KText.tiny.copyWith(color: k.muted, letterSpacing: 0.6),
            ),
            Text('${date.day}', style: KText.heading.copyWith(color: k.ink, height: 1.2)),
          ],
        ),
      ),
    );
  }
}
