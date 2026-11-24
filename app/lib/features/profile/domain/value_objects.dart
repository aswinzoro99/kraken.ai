/// A name friends will see: trimmed, single-spaced, 1–40 characters.
extension type const DisplayName._(String value) {
  static DisplayName? tryParse(String raw) {
    final cleaned = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (cleaned.isEmpty || cleaned.length > 40) return null;
    if (!RegExp(r'\p{L}', unicode: true).hasMatch(cleaned)) return null;
    return DisplayName._(cleaned);
  }
}

/// A UPI ID (virtual payment address) shaped like name@bank.
extension type const UpiId._(String value) {
  static final _shape = RegExp(r'^[a-z0-9.\-_]{2,256}@[a-z][a-z0-9]{1,63}$');

  static UpiId? tryParse(String raw) {
    final cleaned = raw.trim().toLowerCase();
    return _shape.hasMatch(cleaned) ? UpiId._(cleaned) : null;
  }
}

/// An invite link or bare code. Links look like
/// `https://<project>.web.app/i/<code>`; codes are 6–12 letters or digits.
extension type const InviteCode._(String value) {
  static InviteCode? tryParse(String raw) {
    final text = raw.trim();
    final fromLink = RegExp(r'/i/([A-Za-z0-9]{6,12})\b').firstMatch(text);
    final candidate = fromLink?.group(1) ?? text;
    if (!RegExp(r'^[A-Za-z0-9]{6,12}$').hasMatch(candidate)) return null;
    return InviteCode._(candidate.toUpperCase());
  }
}
