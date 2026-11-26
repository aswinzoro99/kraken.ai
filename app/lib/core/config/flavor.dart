/// Which build of Kraken is running.
///
/// * [mock] runs entirely on fakes: no network, no Firebase. Use it for UI
///   work and demos.
/// * [dev] talks to the Supabase project (phantom-services): real sign-in
///   and profiles; groups are still sample data until Phase 2.
/// * [prod] the release build (same project until there are two).
enum Flavor {
  mock,
  dev,
  prod;

  bool get isProduction => this == Flavor.prod;
}
