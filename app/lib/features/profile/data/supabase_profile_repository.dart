import 'dart:async';
import 'dart:math' as math;

import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../domain/profile_repository.dart';
import '../domain/user_profile.dart';

/// Profiles in Supabase's `profiles` table. The row is made by the server at
/// sign-up; row-level security lets people read and change only their own.
final class SupabaseProfileRepository implements ProfileRepository {
  SupabaseProfileRepository(this._client, {this.retryDelay = const Duration(seconds: 2)});
  final sb.SupabaseClient _client;

  /// The first pause before retrying a failed load; it doubles, up to 30 s.
  final Duration retryDelay;
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
  ///
  /// A failed load is retried with growing pauses rather than ending the
  /// stream (the session would otherwise wait forever). Saves are listened
  /// for before the first load starts, so one made meanwhile isn't lost.
  @override
  Stream<UserProfile?> watch(String uid) {
    late final StreamController<UserProfile?> out;
    StreamSubscription<UserProfile>? saves;
    var loaded = false;
    UserProfile? savedDuringLoad;

    Future<void> load() async {
      var delay = retryDelay;
      while (!out.isClosed) {
        try {
          final profile = await fetch(uid);
          if (out.isClosed) return;
          out.add(profile);
          loaded = true;
          final newer = savedDuringLoad;
          if (newer != null) out.add(newer);
          return;
        } on Object {
          await Future<void>.delayed(delay);
          delay = Duration(milliseconds: math.min(delay.inMilliseconds * 2, 30000));
        }
      }
    }

    out = StreamController<UserProfile?>(
      onListen: () {
        saves = _saved.stream.where((p) => p.uid == uid).listen((p) {
          if (loaded) {
            out.add(p);
          } else {
            savedDuringLoad = p;
          }
        });
        unawaited(load());
      },
      onCancel: () async {
        await saves?.cancel();
        await out.close();
      },
    );
    return out.stream;
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
