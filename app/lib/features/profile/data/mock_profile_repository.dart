import 'dart:async';
import 'dart:convert';

import '../../../core/storage/key_value_store.dart';
import '../domain/profile_repository.dart';
import '../domain/user_profile.dart';

/// Profiles kept on the phone, as JSON in the key-value store.
final class MockProfileRepository implements ProfileRepository {
  MockProfileRepository(this._store) {
    final raw = _store.getString(StoreKeys.mockProfiles);
    if (raw != null) {
      final map = jsonDecode(raw) as Map<String, Object?>;
      map.forEach((uid, json) => _profiles[uid] = UserProfile.fromJson(json! as Map<String, Object?>));
    }
  }

  final KeyValueStore _store;
  final Map<String, UserProfile> _profiles = {};
  final _changes = StreamController<UserProfile>.broadcast();
  final _deleted = StreamController<String>.broadcast();

  @override
  Future<UserProfile?> fetch(String uid) async => _profiles[uid];

  @override
  Stream<UserProfile?> watch(String uid) async* {
    yield _profiles[uid];
    yield* StreamGroupLite.merge<UserProfile?>([
      _changes.stream.where((p) => p.uid == uid),
      _deleted.stream.where((d) => d == uid).map((_) => null),
    ]);
  }

  @override
  Future<void> save(UserProfile profile) async {
    _profiles[profile.uid] = profile;
    await _persist();
    _changes.add(profile);
  }

  @override
  Future<void> delete(String uid) async {
    _profiles.remove(uid);
    await _persist();
    _deleted.add(uid);
  }

  Future<void> _persist() => _store.setString(
    StoreKeys.mockProfiles,
    jsonEncode({for (final e in _profiles.entries) e.key: e.value.toJson()}),
  );
}

/// Merges streams without pulling in package:async.
abstract final class StreamGroupLite {
  static Stream<T> merge<T>(List<Stream<T>> streams) {
    late final StreamController<T> controller;
    final subs = <StreamSubscription<T>>[];
    controller = StreamController<T>(
      onListen: () {
        for (final s in streams) {
          subs.add(s.listen(controller.add, onError: controller.addError));
        }
      },
      onCancel: () async {
        for (final s in subs) {
          await s.cancel();
        }
      },
    );
    return controller.stream;
  }
}
