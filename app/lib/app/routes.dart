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
  static const group = 'group';
  static const groups = 'groups';
  static const expense = 'expense_form';
  static const joinGroup = 'join_group';
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

  /// Every group, with search.
  static const groups = '/home/groups';

  /// Join a group with an invite code (`?code=` to fill it in).
  static const join = '/home/join';

  static String group(String id) => '/home/group/$id';

  /// Add an expense to a group, or edit one ([expenseId]).
  static String expense(String groupId, {String? expenseId}) =>
      expenseId == null ? '/home/group/$groupId/expense' : '/home/group/$groupId/expense/$expenseId';

  static String joinWith(String code) => '$join?code=${Uri.encodeQueryComponent(code)}';

  /// The five tabs of the signed-in app.
  static const tabs = [home, friends, insights, activity, account];

  static bool isInApp(String location) => tabs.any((t) => location == t || location.startsWith('$t/'));
}
