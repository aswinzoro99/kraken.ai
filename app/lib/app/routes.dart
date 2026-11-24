/// Route names double as analytics screen names, so keep them stable and
/// free of ids.
abstract final class Routes {
  static const splash = 'splash';
  static const welcome = 'welcome';
  static const login = 'login';
  static const finishSignUp = 'finish_sign_up';
  static const signIn = 'sign_in';
  static const home = 'home';
  static const friends = 'friends';
  static const insights = 'insights';
  static const activity = 'activity';
  static const account = 'account';
  static const debug = 'debug';
}

abstract final class Paths {
  static const splash = '/';
  static const welcome = '/welcome';

  /// Log in or sign up: Apple, Google or an email code.
  static const login = '/login';

  /// A new account's last step: name, 18+, Terms, usage stats.
  static const finishSignUp = '/login/finish';

  /// The same, as a chat with Kraken (the agent flow).
  static const signIn = '/sign-in';
  static const home = '/home';
  static const friends = '/friends';
  static const insights = '/insights';
  static const activity = '/activity';
  static const account = '/account';
  static const debug = '/debug';

  /// The five tabs of the signed-in app.
  static const tabs = [home, friends, insights, activity, account];

  static bool isInApp(String location) => tabs.any((t) => location == t || location.startsWith('$t/'));
}
