// The catalogue of analytics events. Add new events here, never inline, so
// the full list of what Kraken measures is reviewable in one file.

import 'analytics.dart';

final class AppOpened extends AnalyticsEvent {
  const AppOpened({required this.flavor, required this.coldStartMs});
  final String flavor;
  final int coldStartMs;
  @override
  String get name => 'app_opened';
  @override
  Map<String, Object> get params => {'flavor': flavor, 'cold_start_ms': coldStartMs};
}

final class ScreenViewed extends AnalyticsEvent {
  const ScreenViewed(this.screen);
  final String screen;
  @override
  String get name => 'screen_view';
  @override
  Map<String, Object> get params => {'screen_name': screen};
}

final class WelcomeStartTapped extends AnalyticsEvent {
  const WelcomeStartTapped();
  @override
  String get name => 'welcome_start_tapped';
}

final class SignInMethodChosen extends AnalyticsEvent {
  const SignInMethodChosen(this.method, {required this.signUp});

  /// `email`, `apple`, `google` or `agent`.
  final String method;
  final bool signUp;
  @override
  String get name => 'sign_in_method_chosen';
  @override
  Map<String, Object> get params => {'method': method, 'sign_up': signUp};
}

final class SignInEmailSubmitted extends AnalyticsEvent {
  const SignInEmailSubmitted({required this.valid});
  final bool valid;
  @override
  String get name => 'sign_in_email_submitted';
  @override
  Map<String, Object> get params => {'valid': valid};
}

final class SignInCodeRequested extends AnalyticsEvent {
  const SignInCodeRequested({required this.resend});
  final bool resend;
  @override
  String get name => 'sign_in_code_requested';
  @override
  Map<String, Object> get params => {'resend': resend};
}

final class SignInFailed extends AnalyticsEvent {
  const SignInFailed(this.reason);

  /// A failure code such as `wrong_code`, `expired`, `network`.
  final String reason;
  @override
  String get name => 'sign_in_failed';
  @override
  Map<String, Object> get params => {'reason': reason};
}

final class SignInCompleted extends AnalyticsEvent {
  const SignInCompleted({required this.newUser});
  final bool newUser;
  @override
  String get name => 'sign_in_completed';
  @override
  Map<String, Object> get params => {'new_user': newUser};
}

final class OnboardingStepViewed extends AnalyticsEvent {
  const OnboardingStepViewed(this.step);
  final String step;
  @override
  String get name => 'onboarding_step';
  @override
  Map<String, Object> get params => {'step': step};
}

final class ConsentRecorded extends AnalyticsEvent {
  const ConsentRecorded({required this.kind, required this.granted});

  /// `adult`, `privacy` or `analytics`.
  final String kind;
  final bool granted;
  @override
  String get name => 'consent_recorded';
  @override
  Map<String, Object> get params => {'kind': kind, 'granted': granted};
}

final class UpiStepFinished extends AnalyticsEvent {
  const UpiStepFinished({required this.added});
  final bool added;
  @override
  String get name => 'upi_step_finished';
  @override
  Map<String, Object> get params => {'added': added};
}

final class OnboardingCompleted extends AnalyticsEvent {
  const OnboardingCompleted({required this.groupChoice, required this.seconds});

  /// `invite`, `create` or `skip`.
  final String groupChoice;
  final int seconds;
  @override
  String get name => 'onboarding_completed';
  @override
  Map<String, Object> get params => {'group_choice': groupChoice, 'seconds': seconds};
}

final class SignedOut extends AnalyticsEvent {
  const SignedOut();
  @override
  String get name => 'signed_out';
}

final class AccountDeleted extends AnalyticsEvent {
  const AccountDeleted();
  @override
  String get name => 'account_deleted';
}

final class SettingChanged extends AnalyticsEvent {
  const SettingChanged({required this.setting, required this.enabled});
  final String setting;
  final bool enabled;
  @override
  String get name => 'setting_changed';
  @override
  Map<String, Object> get params => {'setting': setting, 'enabled': enabled};
}

final class AppearanceChanged extends AnalyticsEvent {
  const AppearanceChanged(this.appearance);

  /// `system`, `light` or `dark`.
  final String appearance;
  @override
  String get name => 'appearance_changed';
  @override
  Map<String, Object> get params => {'appearance': appearance};
}

final class ComingSoonTapped extends AnalyticsEvent {
  const ComingSoonTapped(this.feature);
  final String feature;
  @override
  String get name => 'coming_soon_tapped';
  @override
  Map<String, Object> get params => {'feature': feature};
}

final class TabSelected extends AnalyticsEvent {
  const TabSelected(this.tab);
  final String tab;
  @override
  String get name => 'tab_selected';
  @override
  Map<String, Object> get params => {'tab': tab};
}

/// Something done on Home. No names or amounts, only what was tapped.
final class HomeAction extends AnalyticsEvent {
  const HomeAction(this.action, {this.monthsAgo});

  /// `month_selected`, `pay`, `remind`, `see_balances`, `see_activity`,
  /// `open_insights`, `open_group`, `see_groups`, `chart_bars`, `chart_line`,
  /// `refresh`.
  final String action;
  final int? monthsAgo;
  @override
  String get name => 'home_action';
  @override
  Map<String, Object> get params => {'action': action, 'months_ago': ?monthsAgo};
}

final class QuickActionsOpened extends AnalyticsEvent {
  const QuickActionsOpened();
  @override
  String get name => 'quick_actions_opened';
}

/// A quick action was used, from the menu or by holding the + button.
final class QuickActionUsed extends AnalyticsEvent {
  const QuickActionUsed(this.action, {required this.via, this.completed});

  /// `talk`, `scan`, `add` or `settle`.
  final String action;

  /// `menu` or `hold`.
  final String via;

  /// For holds: released to add (true) or slid away to cancel (false).
  final bool? completed;
  @override
  String get name => 'quick_action_used';
  @override
  Map<String, Object> get params => {'action': action, 'via': via, 'completed': ?completed};
}

// ---- Groups and expenses (Phase 2). No names, amounts or descriptions. ----

final class GroupCreated extends AnalyticsEvent {
  const GroupCreated({required this.memberCount});
  final int memberCount;
  @override
  String get name => 'group_created';
  @override
  Map<String, Object> get params => {'member_count': memberCount};
}

/// An expense was added or edited by hand.
final class ExpenseSaved extends AnalyticsEvent {
  const ExpenseSaved({required this.split, required this.edited, required this.people});

  /// `equal`, `exact`, `percent` or `shares`.
  final String split;
  final bool edited;

  /// How many people share it.
  final int people;
  @override
  String get name => 'expense_saved';
  @override
  Map<String, Object> get params => {'split': split, 'edited': edited, 'people': people};
}

final class ExpenseDeleted extends AnalyticsEvent {
  const ExpenseDeleted({required this.undone});

  /// The delete was undone straight after.
  final bool undone;
  @override
  String get name => 'expense_deleted';
  @override
  Map<String, Object> get params => {'undone': undone};
}

final class InviteShared extends AnalyticsEvent {
  const InviteShared();
  @override
  String get name => 'invite_shared';
}

/// Someone opened an invite and took a name (or it didn't work).
final class InviteClaimed extends AnalyticsEvent {
  const InviteClaimed({required this.result});

  /// `joined`, `not_found`, `expired`, `name_taken` or `already_in`.
  final String result;
  @override
  String get name => 'invite_claimed';
  @override
  Map<String, Object> get params => {'result': result};
}

final class GroupAction extends AnalyticsEvent {
  const GroupAction(this.action);

  /// `add_expense`, `open_expense`, `invite`, `settle_up`, `totals`,
  /// `tab_expenses` or `tab_activity`.
  final String action;
  @override
  String get name => 'group_action';
  @override
  Map<String, Object> get params => {'action': action};
}
