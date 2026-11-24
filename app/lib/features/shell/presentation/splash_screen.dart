import 'package:material_ui/material_ui.dart';

import '../../../ui_kit/ui_kit.dart';

/// Shown for a moment while the session is restored.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: KrakenMark(size: 96)));
}
