import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../domain/profile_repository.dart';
import '../domain/user_profile.dart';

/// Profiles in Supabase's `profiles` table. The row is made by the server at
/// sign-up; row-level security lets people read and change only their own.
final class SupabaseProfileRepository implements ProfileRepository {
  SupabaseProfileRepository(this._client);
  final sb.SupabaseClient _client;
  final _saved = StreamController<UserProfile>.broadcast();

  sb.SupabaseQueryBuilder get _table => _client.from('profiles');

  static DateTime? _date(Object? v) => v is String ? DateTime.parse(v) : null;

  static UserProfile _read(Map<String, dynamic> row) => UserProfile(
    uid: row['id'] as String,
    displayName: row['display_name'] as String?,
    upiId: row['upi_id'] as String?,
    adultConfirmedAt: _date(row['adult_confirmed_at']),
    privacyAcceptedAt: _date(row['privacy_accepted_at']),
    privacyPolicyVersion: row['privacy_policy_version'] as String?,
  );

  @override
  Future<UserProfile?> fetch(String uid) async {
    final row = await _table.select().eq('id', uid).maybeSingle();
    return row == null ? null : _read(row);
  }

  /// The profile now, then each change saved from this phone.
  @override
  Stream<UserProfile?> watch(String uid) async* {
    yield await fetch(uid);
    yield* _saved.stream.where((p) => p.uid == uid);
  }

  @override
  Future<void> save(UserProfile profile) async {
    final row = await _table
        .update({
          'display_name': profile.displayName,
          'upi_id': profile.upiId,
          'adult_confirmed_at': profile.adultConfirmedAt?.toUtc().toIso8601String(),
          'privacy_accepted_at': profile.privacyAcceptedAt?.toUtc().toIso8601String(),
          'privacy_policy_version': profile.privacyPolicyVersion,
        })
        .eq('id', profile.uid)
        .select()
        .single();
    _saved.add(_read(row));
  }

  /// Profiles go when the account does (`delete_account()`); apps can't
  /// delete them directly.
  @override
  Future<void> delete(String uid) async {}
}
