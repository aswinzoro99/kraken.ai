/// A checked email address: trimmed, lower-cased, shaped like name@domain.tld.
extension type const EmailAddress._(String value) {
  static final _shape = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');

  /// Returns null when [raw] isn't an email address. Spaces anywhere and
  /// upper case are forgiven, since people type on phone keyboards.
  static EmailAddress? tryParse(String raw) {
    final cleaned = raw.replaceAll(RegExp(r'\s+'), '').toLowerCase();
    if (cleaned.length > 254 || !_shape.hasMatch(cleaned)) return null;
    return EmailAddress._(cleaned);
  }
}
