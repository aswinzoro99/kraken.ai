import 'bootstrap.dart';
import 'core/config/flavor.dart';

/// Plain `flutter run` starts the mock flavor until Firebase is set up.
void main() => bootstrap(Flavor.mock);
