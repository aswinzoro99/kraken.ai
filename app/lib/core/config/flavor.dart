/// Which build of Kraken is running.
///
/// * [mock] runs entirely on fakes: no network, no Firebase. Use it for UI
///   work and demos.
/// * [dev] talks to the `kraken-dev` Firebase project.
/// * [prod] talks to `kraken-prod`.
enum Flavor {
  mock,
  dev,
  prod;

  bool get isProduction => this == Flavor.prod;
}
