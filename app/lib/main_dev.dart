import 'bootstrap.dart';
import 'core/config/flavor.dart';

/// `flutter run -t lib/main_dev.dart`: real sign-in and profiles on the
/// Supabase project (phantom-services).
void main() => bootstrap(Flavor.dev);
