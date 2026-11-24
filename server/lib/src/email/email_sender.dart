import 'dart:convert';

import 'package:http/http.dart' as http;

/// Sends one email. Implementations throw [EmailFailure] if it wasn't sent.
abstract interface class EmailSender {
  Future<void> send({required String to, required String subject, required String text, required String html});
}

final class EmailFailure implements Exception {
  const EmailFailure(this.message);
  final String message;
  @override
  String toString() => 'EmailFailure: $message';
}

/// Prints emails instead of sending them (local development), and keeps
/// them for tests.
final class ConsoleEmailSender implements EmailSender {
  ConsoleEmailSender({this.log = print});
  final void Function(String) log;
  final sent = <({String to, String subject, String text})>[];

  @override
  Future<void> send({required String to, required String subject, required String text, required String html}) async {
    sent.add((to: to, subject: subject, text: text));
    log('[email to $to] $subject');
  }
}

/// Sends through Resend (https://resend.com/docs/api-reference/emails).
/// Resend only delivers from a domain verified in its dashboard.
final class ResendEmailSender implements EmailSender {
  ResendEmailSender({required this.apiKey, required this.from, http.Client? client}) : _http = client ?? http.Client();

  final String apiKey;
  final String from;
  final http.Client _http;

  @override
  Future<void> send({required String to, required String subject, required String text, required String html}) async {
    final response = await _http.post(
      Uri.parse('https://api.resend.com/emails'),
      headers: {'Authorization': 'Bearer $apiKey', 'Content-Type': 'application/json'},
      body: jsonEncode({
        'from': from,
        'to': [to],
        'subject': subject,
        'text': text,
        'html': html,
      }),
    );
    if (response.statusCode >= 300) {
      throw EmailFailure('Resend answered ${response.statusCode}: ${response.body}');
    }
  }
}

/// The sign-in code email: short, the code first, plain words.
({String subject, String text, String html}) codeEmail(String code) => (
  subject: 'Your Kraken code: $code',
  text:
      'Your Kraken sign-in code is $code.\n\n'
      'It works for 10 minutes. If you didn\'t ask for it, you can ignore this email.',
  html:
      '<div style="font-family:-apple-system,Segoe UI,Roboto,sans-serif;color:#15171C">'
      '<p>Your Kraken sign-in code is</p>'
      '<p style="font-size:32px;font-weight:700;letter-spacing:6px;margin:8px 0">$code</p>'
      '<p style="color:#626873">It works for 10 minutes. If you didn\'t ask for it, you can ignore this email.</p>'
      '</div>',
);
