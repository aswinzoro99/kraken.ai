import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/storage/key_value_store.dart';

/// How the app looks: following the phone's setting, or always light or
/// always dark.
enum Appearance { system, light, dark }

/// The Appearance choice in Account. Saved on the device so it survives
/// restarts; until the person picks, the app follows the phone.
class AppearanceCubit extends Cubit<Appearance> {
  AppearanceCubit(this._store) : super(_saved(_store));

  final KeyValueStore _store;

  static Appearance _saved(KeyValueStore store) =>
      Appearance.values.asNameMap()[store.getString(StoreKeys.appearance)] ?? Appearance.system;

  Future<void> set(Appearance appearance) async {
    if (appearance == state) return;
    emit(appearance);
    await _store.setString(StoreKeys.appearance, appearance.name);
  }
}
