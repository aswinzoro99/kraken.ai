import '../domain/onboarding_machine.dart';

/// Everything Kraken says during sign-up, in one place for review and,
/// later, translation.
abstract final class OnboardingCopy {
  static String say(BotLine b) => switch (b.line) {
    Line.greet => "Hi! I'm Kraken. I keep track of who owes whom, so you don't have to.",
    Line.askEmail => "Let's get you signed in. What's your email address?",
    Line.badEmail => "Hmm, that doesn't look like an email address. Mind checking it?",
    Line.codeSent => "Thanks! I've sent a 6-digit code to ${b.email}. Type it here when it arrives.",
    Line.codeResent => 'Sent a fresh code to ${b.email}.',
    Line.badCodeShape => "The code has 6 digits. It's in the email from Kraken. Check spam if you can't see it.",
    Line.wrongCode => "That code doesn't match. You have ${b.count} more ${b.count == 1 ? 'try' : 'tries'}.",
    Line.codeExpired => "That code has expired. Tap Resend code and I'll send a new one.",
    Line.codeRejected => "That code didn't work. Check the digits, or tap Resend code for a new one.",
    Line.tooManyAttempts => 'Too many wrong tries for that code. Tap Resend code to get a new one.',
    Line.resendTooSoon => 'I just sent one. You can ask for another in ${b.count} seconds.',
    Line.askEmailAgain => "No problem. What's the right email?",
    Line.network => "I couldn't reach Kraken's server. Check your connection and try again.",
    Line.verified => "You're verified.",
    Line.welcomeBack => 'Welcome back, ${b.name}!',
    Line.resume =>
      b.name == null
          ? "Welcome back. Let's finish setting you up."
          : 'Welcome back, ${b.name}. Just a couple of things left.',
    Line.askName => 'What name should your friends see?',
    Line.badName => 'I need a name with at least one letter, up to 40 characters.',
    Line.niceToMeetYou => 'Nice to meet you, ${b.name}!',
    Line.askAdult => 'Quick check: are you 18 or older? Kraken is for adults only.',
    Line.underAge => "Sorry, Kraken is only for people 18 and older. I haven't kept your details.",
    Line.askPrivacy =>
      'Kraken keeps your groups, expenses and payments so everyone sees the same balances. '
          'It never sells your data. OK to continue under the Privacy Policy?',
    Line.policyPointer => "The Privacy Policy is linked below. Tap I agree when you're ready.",
    Line.askAnalytics =>
      'Can Kraken collect anonymous usage stats, like which screens you open? '
          'No names, amounts or messages. You can change this in Account.',
    Line.analyticsThanks => 'Thanks, that helps make Kraken better.',
    Line.askUpi => 'Add your UPI ID so friends can pay you back in two taps. You can skip this.',
    Line.badUpi => 'UPI IDs look like name@bank, for example aarav@okaxis. Mind checking it?',
    Line.upiSaved => 'Saved. Friends will see it when they settle up with you.',
    Line.askGroup => 'Did a friend invite you to a group?',
    Line.askInvite => 'Paste the invite link here.',
    Line.badInvite => "That doesn't look like a Kraken invite. It's a link ending in a code, like /i/K7Q2XA.",
    Line.inviteSaved => "Got it. You'll join that group as soon as it opens.",
    Line.createGroupNext => "Great. You'll name it on the next screen.",
    Line.allSet => 'All set. Tap below to see your groups.',
    Line.allSetStart => 'All set. Tap below to get started.',
  };

  static String chip(OnboardingChip c) => switch (c) {
    OnboardingChip.resendCode => 'Resend code',
    OnboardingChip.differentEmail => 'Use a different email',
    OnboardingChip.retry => 'Try again',
    OnboardingChip.adultYes => "Yes, I'm 18 or older",
    OnboardingChip.adultNo => 'No',
    OnboardingChip.privacyAgree => 'I agree',
    OnboardingChip.privacyRead => 'Read the policy',
    OnboardingChip.analyticsYes => 'Yes, share usage stats',
    OnboardingChip.analyticsNo => 'No thanks',
    OnboardingChip.skipUpi => 'Skip for now',
    OnboardingChip.haveInvite => 'I have an invite link',
    OnboardingChip.createGroup => 'Create a new group',
    OnboardingChip.skipGroup => 'Skip for now',
    OnboardingChip.startOver => 'Start over',
  };

  /// Lines that mean "that didn't work"; they get the error haptic.
  static const errorLines = {
    Line.badEmail,
    Line.badCodeShape,
    Line.wrongCode,
    Line.codeExpired,
    Line.codeRejected,
    Line.tooManyAttempts,
    Line.resendTooSoon,
    Line.network,
    Line.badName,
    Line.badUpi,
    Line.badInvite,
    Line.underAge,
  };

  static const successLines = {Line.verified, Line.allSet, Line.allSetStart};
}
