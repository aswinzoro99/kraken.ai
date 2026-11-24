# Kraken

An AI expense splitter for Android and iPhone. Split costs with friends by
typing, talking or photographing a bill. See `docs/tdr/kraken-tdr.html` for
the technical design review.

## Layout

```text
app/                 Flutter app (Android + iPhone)
packages/ledger/     Pure Dart money maths, shared with the server
docs/tdr/            Technical design review
```

This is a Dart pub workspace: run `flutter pub get` once at the root.

## Run it

```sh
cd app
flutter run -t lib/main_mock.dart     # everything on fakes, no network
```

The mock flavor needs no accounts. Sign in with any email: the code appears
in a yellow "Mock inbox" bar above the chat. Tap the version number in
Account seven times for debug tools (analytics log, haptics, fake failures,
reset).

`dev` and `prod` flavors arrive with the Firebase projects (build guide,
Phase 0 day 3).

## Test it

```sh
cd app && flutter analyze && flutter test
cd packages/ledger && dart test
```
