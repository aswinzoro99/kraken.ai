import 'dart:async';

import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../core/analytics/analytics_route_observer.dart';
import '../core/analytics/analytics.dart';
import '../debug/debug_screen.dart';
import '../features/account/presentation/account_screen.dart';
import '../features/auth/presentation/finish_sign_up_screen.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/onboarding/presentation/sign_in_chat_screen.dart';
import '../features/shell/presentation/home_shell.dart';
import '../features/shell/presentation/placeholder_tabs.dart';
import '../features/shell/presentation/splash_screen.dart';
import '../features/welcome/presentation/welcome_screen.dart';
import 'routes.dart';
import 'session.dart';

/// Where a person may be, given their session. Pure, so it's unit-tested.
String? redirectFor(SessionState session, String location, {required bool debugAllowed}) {
  final inApp = Paths.isInApp(location);
  final atDebug = location == Paths.debug;
  if (atDebug) return debugAllowed ? null : Paths.splash;
  return switch (session) {
    SessionLoading() => location == Paths.splash ? null : Paths.splash,
    SignedOutSession() =>
      (inApp || location == Paths.splash)
          ? Paths.welcome
          : location == Paths.finishSignUp
          ? Paths.login
          : null,
    // Mid-sign-up: the chat carries on where it is; otherwise the form.
    OnboardingSession() => (location == Paths.signIn || location == Paths.finishSignUp) ? null : Paths.finishSignUp,
    // Finished: the chat may stay open to show "Open your groups".
    ReadySession() =>
      const [Paths.splash, Paths.welcome, Paths.login, Paths.finishSignUp].contains(location) ? Paths.home : null,
  };
}

/// Turns a stream into a [Listenable] so go_router re-checks redirects
/// whenever the session changes. The owner disposes it with the router.
class StreamListenable extends ChangeNotifier {
  StreamListenable(Stream<Object?> stream) {
    _sub = stream.listen((_) => notifyListeners());
  }
  late final StreamSubscription<Object?> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

GoRouter createRouter({
  required SessionCubit session,
  required Listenable refresh,
  required Analytics analytics,
  required bool debugAllowed,
}) {
  return GoRouter(
    initialLocation: Paths.splash,
    refreshListenable: refresh,
    observers: [AnalyticsRouteObserver(analytics)],
    redirect: (context, state) => redirectFor(session.state, state.matchedLocation, debugAllowed: debugAllowed),
    routes: [
      GoRoute(path: Paths.splash, name: Routes.splash, builder: (_, _) => const SplashScreen()),
      GoRoute(path: Paths.welcome, name: Routes.welcome, builder: (_, _) => const WelcomeScreen()),
      GoRoute(path: Paths.login, name: Routes.login, builder: (_, _) => const LoginScreen()),
      GoRoute(path: Paths.finishSignUp, name: Routes.finishSignUp, builder: (_, _) => const FinishSignUpScreen()),
      GoRoute(path: Paths.signIn, name: Routes.signIn, builder: (_, _) => const SignInChatScreen()),
      GoRoute(path: Paths.debug, name: Routes.debug, builder: (_, _) => const DebugScreen()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => HomeShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [GoRoute(path: Paths.home, name: Routes.home, builder: (_, _) => const HomeScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: Paths.friends, name: Routes.friends, builder: (_, _) => const FriendsTab())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: Paths.insights, name: Routes.insights, builder: (_, _) => const InsightsTab())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: Paths.activity, name: Routes.activity, builder: (_, _) => const ActivityTab())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: Paths.account, name: Routes.account, builder: (_, _) => const AccountScreen())],
          ),
        ],
      ),
    ],
  );
}
