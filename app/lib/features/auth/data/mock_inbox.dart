import 'package:flutter/foundation.dart';

/// An email the mock auth "sent". Shown in the mock flavor so you can sign in
/// without a mail server.
@immutable
final class MockEmail {
  const MockEmail({required this.to, required this.code, required this.sentAt});
  final String to;
  final String code;
  final DateTime sentAt;
}

/// The mock flavor's inbox. Holds only the latest email.
final class MockInbox extends ValueNotifier<MockEmail?> {
  MockInbox() : super(null);

  void deliver(MockEmail email) => value = email;
}
