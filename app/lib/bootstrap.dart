import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import 'app/composition.dart';
import 'app/kraken_app.dart';
import 'core/analytics/events.dart';
import 'core/config/app_config.dart';
import 'core/config/flavor.dart';

/// Starts Kraken for [flavor]: builds services, hooks error reporting, and
/// runs the app. Each `main_<flavor>.dart` calls this and nothing else.
Future<void> bootstrap(Flavor flavor) async {
  final startup = Stopwatch()..start();
  WidgetsFlutterBinding.ensureInitialized();

  final services = await compose(AppConfig.forFlavor(flavor));
  final crash = services.crash;

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    crash.recordError(details.exception, details.stack, reason: details.context?.toDescription());
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    crash.recordError(error, stack, fatal: true);
    return true;
  };

  runApp(KrakenApp(services: services));

  WidgetsBinding.instance.addPostFrameCallback((_) {
    services.analytics.log(AppOpened(flavor: flavor.name, coldStartMs: startup.elapsedMilliseconds));
    if (kDebugMode) crash.breadcrumb('app started (${flavor.name})');
  });
}
