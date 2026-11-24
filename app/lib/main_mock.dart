import 'bootstrap.dart';
import 'core/config/flavor.dart';

/// `flutter run -t lib/main_mock.dart`: everything on fakes, no network.
void main() => bootstrap(Flavor.mock);
