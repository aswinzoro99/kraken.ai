import 'flavor.dart';

/// Values that differ per flavor. Built once at startup and read through
/// `appConfigProvider`; never read flavor-specific values anywhere else.
final class AppConfig {
  const AppConfig({
    required this.flavor,
    required this.appName,
    required this.apiBaseUrl,
    required this.privacyPolicyUrl,
    required this.termsUrl,
    required this.privacyPolicyVersion,
    required this.showDebugTools,
    this.chatPacing = const Duration(milliseconds: 700),
  });

  factory AppConfig.forFlavor(Flavor flavor) => switch (flavor) {
    Flavor.mock => AppConfig(
      flavor: flavor,
      appName: 'Kraken Mock',
      apiBaseUrl: Uri.parse('http://localhost:8080'),
      privacyPolicyUrl: Uri.parse('https://kraken-dev.web.app/privacy'),
      termsUrl: Uri.parse('https://kraken-dev.web.app/terms'),
      privacyPolicyVersion: _policyVersion,
      showDebugTools: true,
    ),
    Flavor.dev => AppConfig(
      flavor: flavor,
      appName: 'Kraken Dev',
      apiBaseUrl: Uri.parse('https://kraken-api-dev.asia-south1.run.app'),
      privacyPolicyUrl: Uri.parse('https://kraken-dev.web.app/privacy'),
      termsUrl: Uri.parse('https://kraken-dev.web.app/terms'),
      privacyPolicyVersion: _policyVersion,
      showDebugTools: true,
    ),
    Flavor.prod => AppConfig(
      flavor: flavor,
      appName: 'Kraken',
      apiBaseUrl: Uri.parse('https://kraken-api.asia-south1.run.app'),
      privacyPolicyUrl: Uri.parse('https://kraken-prod.web.app/privacy'),
      termsUrl: Uri.parse('https://kraken-prod.web.app/terms'),
      privacyPolicyVersion: _policyVersion,
      showDebugTools: false,
    ),
  };

  /// Bump when the privacy policy text changes; people are asked again.
  static const _policyVersion = '2026-11-24';

  final Flavor flavor;
  final String appName;
  final Uri apiBaseUrl;
  final Uri privacyPolicyUrl;
  final Uri termsUrl;
  final String privacyPolicyVersion;

  /// Whether the hidden debug screen can be opened (7 taps on the version).
  final bool showDebugTools;

  /// How long Kraken "types" before a scripted chat reply. Tests set zero.
  final Duration chatPacing;

  AppConfig copyWith({Duration? chatPacing, bool? showDebugTools}) => AppConfig(
    flavor: flavor,
    appName: appName,
    apiBaseUrl: apiBaseUrl,
    privacyPolicyUrl: privacyPolicyUrl,
    termsUrl: termsUrl,
    privacyPolicyVersion: privacyPolicyVersion,
    showDebugTools: showDebugTools ?? this.showDebugTools,
    chatPacing: chatPacing ?? this.chatPacing,
  );
}
