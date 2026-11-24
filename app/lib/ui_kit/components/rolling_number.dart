import 'package:flutter/physics.dart';
import 'package:material_ui/material_ui.dart';

/// A figure whose digits roll into place, like an odometer: on first show
/// each digit spins up from 0, and when the value changes each digit rolls
/// from where it is to its new value. Digits further right settle a little
/// later, so the change reads left to right.
///
/// Digits are matched from the right, so units stay units when a figure
/// grows a digit (₹9,800 → ₹21,500). Each roll is a spring that starts from
/// the digit's current position and speed, so a new value mid-roll
/// redirects it smoothly. Screen readers hear the figure once, as text.
/// Under Reduce Motion it's plain text.
class KRollingNumber extends StatelessWidget {
  const KRollingNumber(this.text, {super.key, required this.style});

  /// Already formatted, e.g. "₹21,500".
  final String text;
  final TextStyle style;

  static bool _isDigit(String c) => c.length == 1 && c.codeUnitAt(0) >= 48 && c.codeUnitAt(0) <= 57;

  @override
  Widget build(BuildContext context) {
    final resolved = DefaultTextStyle.of(context).style.merge(style);
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return Text(text, style: resolved);
    final scaler = MediaQuery.textScalerOf(context);
    Size measure(String s) {
      final painter = TextPainter(
        text: TextSpan(text: s, style: resolved),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      final size = painter.size;
      painter.dispose();
      return size;
    }

    final cell = measure('0');
    final chars = text.characters.toList();
    final n = chars.length;
    return Semantics(
      label: text,
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < n; i++)
            if (_isDigit(chars[i]))
              _DigitWheel(
                key: ValueKey('d${n - 1 - i}'),
                digit: chars[i].codeUnitAt(0) - 48,
                order: i,
                style: resolved,
                cell: cell,
              )
            else
              SizedBox(
                key: ValueKey('s${n - 1 - i}${chars[i]}'),
                width: measure(chars[i]).width,
                height: cell.height,
                child: Text(chars[i], style: resolved, maxLines: 1, softWrap: false),
              ),
        ],
      ),
    );
  }
}

class _DigitWheel extends StatefulWidget {
  const _DigitWheel({super.key, required this.digit, required this.order, required this.style, required this.cell});

  final int digit;

  /// Position from the left; later digits settle a little later.
  final int order;
  final TextStyle style;
  final Size cell;

  @override
  State<_DigitWheel> createState() => _DigitWheelState();
}

class _DigitWheelState extends State<_DigitWheel> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController.unbounded(vsync: this, value: 0);

  @override
  void initState() {
    super.initState();
    _roll();
  }

  @override
  void didUpdateWidget(_DigitWheel old) {
    super.didUpdateWidget(old);
    if (old.digit != widget.digit) _roll();
  }

  void _roll() {
    final spring = SpringDescription.withDurationAndBounce(duration: Duration(milliseconds: 520 + widget.order * 70));
    // From the current position and speed, so interruptions stay smooth.
    _c.animateWith(SpringSimulation(spring, _c.value, widget.digit.toDouble(), _c.velocity));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.cell.width;
    final h = widget.cell.height;
    return SizedBox(
      width: w,
      height: h,
      child: ClipRect(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, child) => OverflowBox(
            alignment: Alignment.topCenter,
            minHeight: 0,
            maxHeight: double.infinity,
            child: Transform.translate(offset: Offset(0, -_c.value * h), child: child),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var d = 0; d <= 9; d++)
                SizedBox(
                  width: w,
                  height: h,
                  child: Text('$d', style: widget.style, textAlign: TextAlign.center, maxLines: 1, softWrap: false),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
