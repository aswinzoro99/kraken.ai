# Kraken app

Flutter, clean architecture, flutter_bloc, go_router.

## Structure

```text
lib/
  main.dart, main_mock.dart   entry points (one per flavor)
  bootstrap.dart              starts services, error hooks, runApp
  app/                        composition root, services, router, session
  core/                       framework services behind interfaces
    analytics/                typed events, consent gate, route observer
    config/                   flavors and per-flavor config
    crash/                    crash reporter (Crashlytics later)
    haptics/                  semantic haptics with an on/off setting
    logging/  result/  storage/  time/
  ui_kit/                     design tokens, theme and reusable widgets
  features/<feature>/
    domain/                   pure Dart: entities, value objects, interfaces
    data/                     implementations (mocks now, Firebase later)
    presentation/             screens, widgets, blocs and cubits
  debug/                      hidden debug screen
```

Rules:

- `domain/` never imports Flutter, bloc or Firebase.
- `app/composition.dart` is the only place that picks implementations per
  flavor. It builds one `AppServices`, which `KrakenApp` hands to the tree
  with `RepositoryProvider`.
- Blocs get their repositories through their constructors, created in a
  `BlocProvider` at the screen that owns them. They never look services up.
- App-wide state is `SessionCubit` (who is signed in) and
  `AnalyticsConsentCubit`. Screen state lives in the screen's bloc:
  `OnboardingBloc` (sign-up chat; drops input while it is answering) and
  `HomeCubit` (Home: spending, balances, activity, groups; see
  `docs/ux/home-study.md`).
- Money maths (splits, who owes whom) lives in `packages/ledger`; screens
  never add up paise themselves.
- Test blocs with `bloc_test`; see `test/blocs/`.
- Features import the design system through `ui_kit/ui_kit.dart` only.
- Material comes from `package:material_ui`, the same copy go_router uses.
  Don't import `package:flutter/material.dart`.

## Analytics

Every event is a class in `core/analytics/events.dart`. Events carry no
personal data (no emails, names, amounts or UPI IDs). They are held back
until the person answers the usage-stats question in sign-up, then sent or
dropped. In mock builds, the debug screen lists what was sent.

## Haptics

Pick by meaning: `tap`, `selection`, `success`, `warning`, `error`,
`heavy`. `KPressable`, `KButton`, `KChip`, toasts and sheets already play
the right one; the Vibration switch in Account turns them all off.
