/// What friends see and what the person agreed to.
final class UserProfile {
  const UserProfile({
    required this.uid,
    this.displayName,
    this.adultConfirmedAt,
    this.privacyAcceptedAt,
    this.privacyPolicyVersion,
    this.upiId,
    this.pendingInviteCode,
  });

  final String uid;
  final String? displayName;

  /// When the person confirmed they are 18 or older.
  final DateTime? adultConfirmedAt;
  final DateTime? privacyAcceptedAt;
  final String? privacyPolicyVersion;
  final String? upiId;

  /// An invite pasted during sign-up, claimed once groups exist (Phase 2).
  final String? pendingInviteCode;

  /// Signed-up people have a name, are 18+ and accepted the current policy.
  bool isCompleteFor(String currentPolicyVersion) =>
      displayName != null &&
      adultConfirmedAt != null &&
      privacyAcceptedAt != null &&
      privacyPolicyVersion == currentPolicyVersion;

  UserProfile copyWith({
    String? displayName,
    DateTime? adultConfirmedAt,
    DateTime? privacyAcceptedAt,
    String? privacyPolicyVersion,
    String? upiId,
    String? pendingInviteCode,
  }) => UserProfile(
    uid: uid,
    displayName: displayName ?? this.displayName,
    adultConfirmedAt: adultConfirmedAt ?? this.adultConfirmedAt,
    privacyAcceptedAt: privacyAcceptedAt ?? this.privacyAcceptedAt,
    privacyPolicyVersion: privacyPolicyVersion ?? this.privacyPolicyVersion,
    upiId: upiId ?? this.upiId,
    pendingInviteCode: pendingInviteCode ?? this.pendingInviteCode,
  );

  Map<String, Object?> toJson() => {
    'uid': uid,
    'displayName': displayName,
    'adultConfirmedAt': adultConfirmedAt?.toIso8601String(),
    'privacyAcceptedAt': privacyAcceptedAt?.toIso8601String(),
    'privacyPolicyVersion': privacyPolicyVersion,
    'upiId': upiId,
    'pendingInviteCode': pendingInviteCode,
  };

  factory UserProfile.fromJson(Map<String, Object?> json) => UserProfile(
    uid: json['uid']! as String,
    displayName: json['displayName'] as String?,
    adultConfirmedAt: _date(json['adultConfirmedAt']),
    privacyAcceptedAt: _date(json['privacyAcceptedAt']),
    privacyPolicyVersion: json['privacyPolicyVersion'] as String?,
    upiId: json['upiId'] as String?,
    pendingInviteCode: json['pendingInviteCode'] as String?,
  );

  static DateTime? _date(Object? v) => v is String ? DateTime.parse(v) : null;
}
