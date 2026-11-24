/// Everything the server reads from its environment. On Cloud Run these are
/// service env vars (secrets from Secret Manager); locally, see README.md.
final class ServerConfig {
  const ServerConfig({
    required this.projectId,
    required this.port,
    required this.mailer,
    required this.codePepper,
    this.authEmulatorHost,
    this.firestoreEmulatorHost,
    this.resendApiKey,
    this.mailFrom,
    this.serviceAccountJson,
  });

  /// Reads the config; throws [ArgumentError] listing anything missing.
  factory ServerConfig.fromEnvironment(Map<String, String> env) {
    String? read(String key) {
      final value = env[key]?.trim();
      return value == null || value.isEmpty ? null : value;
    }

    final missing = <String>[];
    String need(String key) {
      final value = read(key);
      if (value == null) missing.add(key);
      return value ?? '';
    }

    final emulated = read('FIREBASE_AUTH_EMULATOR_HOST') != null;
    final mailer = switch (read('MAILER') ?? (emulated ? 'console' : 'resend')) {
      'console' => Mailer.console,
      'resend' => Mailer.resend,
      final other => throw ArgumentError('MAILER must be console or resend, not $other'),
    };
    final config = ServerConfig(
      projectId: need('PROJECT_ID'),
      port: int.tryParse(read('PORT') ?? '') ?? 8081,
      mailer: mailer,
      // Locally a fixed pepper is fine; in production it must be a secret.
      codePepper: emulated ? (read('CODE_PEPPER') ?? 'local-emulator-pepper') : need('CODE_PEPPER'),
      authEmulatorHost: read('FIREBASE_AUTH_EMULATOR_HOST'),
      firestoreEmulatorHost: read('FIRESTORE_EMULATOR_HOST'),
      resendApiKey: mailer == Mailer.resend ? need('RESEND_API_KEY') : null,
      mailFrom: mailer == Mailer.resend ? need('MAIL_FROM') : read('MAIL_FROM'),
      serviceAccountJson: read('SERVICE_ACCOUNT_JSON'),
    );
    if (missing.isNotEmpty) throw ArgumentError('Missing environment: ${missing.join(', ')}');
    return config;
  }

  final String projectId;
  final int port;
  final Mailer mailer;

  /// Secret mixed into every stored code hash, so a leaked database can't be
  /// brute-forced into codes.
  final String codePepper;

  /// host:port of the Firebase emulators; set means "run against emulators".
  final String? authEmulatorHost;
  final String? firestoreEmulatorHost;

  final String? resendApiKey;

  /// Sender, e.g. `Kraken <codes@mail.your-domain.com>`, on a domain
  /// verified in Resend.
  final String? mailFrom;

  /// A service account key, only for running against real Firebase from a
  /// laptop. On Cloud Run the service's own identity is used instead.
  final String? serviceAccountJson;

  bool get usesEmulators => authEmulatorHost != null;
}

/// How sign-in codes are emailed.
enum Mailer {
  /// Printed to the server log; for local development only.
  console,

  /// Sent through Resend's API (needs a verified domain).
  resend,
}
