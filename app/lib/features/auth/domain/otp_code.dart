/// A 6-digit sign-in code as typed: spaces and dashes are ignored.
extension type const OtpCode._(String value) {
  static OtpCode? tryParse(String raw) {
    final digits = raw.replaceAll(RegExp(r'[\s-]'), '');
    if (!RegExp(r'^\d{6}$').hasMatch(digits)) return null;
    return OtpCode._(digits);
  }
}
