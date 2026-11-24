/// Kraken's API server: sign-in codes, account deletion, and (from Phase 2)
/// invites. Built from [buildApi]; run by bin/server.dart.
library;

import 'dart:convert';

import 'src/auth/firestore_code_store.dart';
import 'src/auth/sign_in_codes.dart';
import 'src/config.dart';
import 'src/email/email_sender.dart';
import 'src/firebase/accounts.dart';
import 'src/firebase/firestore.dart';
import 'src/firebase/google_clients.dart';
import 'src/firebase/tokens.dart';
import 'src/http/api.dart';

export 'src/config.dart';
export 'src/email/email_sender.dart' show ConsoleEmailSender, EmailSender;
export 'src/http/api.dart';

/// Wires the real implementations for [config]. Tests can pass their own
/// [sender] to read the codes.
Future<KrakenApi> buildApi(ServerConfig config, {EmailSender? sender}) async {
  final admin = await adminClient(config);
  final firestore = Firestore(projectId: config.projectId, client: admin, emulatorHost: config.firestoreEmulatorHost);
  final mailer =
      sender ??
      switch (config.mailer) {
        Mailer.console => ConsoleEmailSender(),
        Mailer.resend => ResendEmailSender(apiKey: config.resendApiKey!, from: config.mailFrom!),
      };
  final key = config.serviceAccountJson == null ? null : jsonDecode(config.serviceAccountJson!) as Map<String, Object?>;
  final TokenMinter minter = config.usesEmulators
      ? EmulatorTokenMinter()
      : key != null
      ? KeyTokenMinter(clientEmail: key['client_email']! as String, privateKeyPem: key['private_key']! as String)
      : IamTokenMinter(client: admin);
  final IdTokenVerifier verifier = config.usesEmulators
      ? EmulatorIdTokenVerifier(projectId: config.projectId)
      : GoogleIdTokenVerifier(projectId: config.projectId);
  return KrakenApi(
    codes: SignInCodes(store: FirestoreCodeStore(firestore), sender: mailer, pepper: config.codePepper),
    accounts: Accounts(projectId: config.projectId, client: admin, emulatorHost: config.authEmulatorHost),
    firestore: firestore,
    minter: minter,
    verifier: verifier,
  );
}
