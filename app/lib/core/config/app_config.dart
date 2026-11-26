import 'flavor.dart';

/// Values that differ per flavor. Built once at startup and read through
/// `appConfigProvider`; never read flavor-specific values anywhere else.
final class AppConfig {
  const AppConfig({
    required this.flavor,
    required this.appName,
    required this.supabaseUrl,
    this.supabaseAnonKey = '',
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
      // Unused: the mock flavor never talks to a backend.
      supabaseUrl: Uri.parse('http://localhost'),
      privacyPolicyUrl: Uri.parse('https://kraken-dev.web.app/privacy'),
      termsUrl: Uri.parse('https://kraken-dev.web.app/terms'),
      privacyPolicyVersion: _policyVersion,
      showDebugTools: true,
    ),
    Flavor.dev => AppConfig(
      flavor: flavor,
      appName: 'Kraken Dev',
      supabaseUrl: _supabaseUrl,
      supabaseAnonKey: _supabaseAnonKey,
      privacyPolicyUrl: Uri.parse('https://kraken-dev.web.app/privacy'),
      termsUrl: Uri.parse('https://kraken-dev.web.app/terms'),
      privacyPolicyVersion: _policyVersion,
      showDebugTools: true,
    ),
    Flavor.prod => AppConfig(
      flavor: flavor,
      appName: 'Kraken',
      supabaseUrl: _supabaseUrl,
      supabaseAnonKey: _supabaseAnonKey,
      privacyPolicyUrl: Uri.parse('https://kraken-prod.web.app/privacy'),
      termsUrl: Uri.parse('https://kraken-prod.web.app/terms'),
      privacyPolicyVersion: _policyVersion,
      showDebugTools: false,
    ),
  };

  /// The Supabase project (phantom-services). The anon key is public by
  /// design: it's in every copy of the app, and row-level security decides
  /// what it can reach. Dev and prod share one project until there are two.
  static final _supabaseUrl = Uri.parse('https://pimootoxquuxfsweuquh.supabase.co');
  static const _supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBpbW9vdG94cXV1eGZzd2V1cXVoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTU2ODA5NDgsImV4cCI6MjExMTI1Njk0OH0.w0hi5lfQMmYmrO5K61X0J2b8MIrtLhjRlMaVptUmTB8';

  /// Bump when the privacy policy text changes; people are asked again.
  static const _policyVersion = '2026-11-24';

  final Flavor flavor;
  final String appName;

  /// The backend: phantom-services on Supabase.
  final Uri supabaseUrl;
  final String supabaseAnonKey;
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
    supabaseUrl: supabaseUrl,
    supabaseAnonKey: supabaseAnonKey,
    privacyPolicyUrl: privacyPolicyUrl,
    termsUrl: termsUrl,
    privacyPolicyVersion: privacyPolicyVersion,
    showDebugTools: showDebugTools ?? this.showDebugTools,
    chatPacing: chatPacing ?? this.chatPacing,
  );
}
