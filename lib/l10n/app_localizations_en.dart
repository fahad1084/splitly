// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Splitly';

  @override
  String get tagline => 'Your Circle. Your Hisaab.';

  @override
  String get groups => 'Groups';

  @override
  String get balances => 'Balances';

  @override
  String get profile => 'Profile';

  @override
  String hey(String name) {
    return 'Hey, $name';
  }

  @override
  String get balanceSummary => 'Here\'s your balance summary';

  @override
  String get youAreOwed => 'You are owed';

  @override
  String get youOwe => 'You owe';

  @override
  String get createGroup => 'Create Group';

  @override
  String get joinGroup => 'Join Group';

  @override
  String get noGroupsYet => 'No groups yet';

  @override
  String get createFirstGroup =>
      'Create your first group to start splitting expenses';

  @override
  String get joinWithInviteCode => 'Join with Invite Code';

  @override
  String get addExpense => 'Add Expense';

  @override
  String get whatWasItFor => 'What was it for?';

  @override
  String get amount => 'Amount';

  @override
  String get category => 'Category';

  @override
  String get paidBy => 'Paid by';

  @override
  String get split => 'Split';

  @override
  String get equal => 'Equal';

  @override
  String get custom => 'Custom';

  @override
  String get notes => 'Notes (optional)';

  @override
  String get settleUp => 'Settle up';

  @override
  String get allSettledUp => 'All settled up!';

  @override
  String get noOutstandingBalances =>
      'No outstanding balances. Everyone is even.';

  @override
  String get expenseHistory => 'Expense History';

  @override
  String get spendingReports => 'Spending Reports';

  @override
  String get shareSummary => 'Share Summary';

  @override
  String get exportPdfCsv => 'Export PDF/CSV';

  @override
  String get archiveGroup => 'Archive Group';

  @override
  String get inviteCode => 'Invite Code';

  @override
  String get copyCode => 'Copy Code';

  @override
  String get editProfile => 'Edit Profile';

  @override
  String get notifications => 'Notifications';

  @override
  String get darkMode => 'Dark Mode';

  @override
  String get lightMode => 'Light Mode';

  @override
  String get language => 'Language';

  @override
  String get appLock => 'App Lock / PIN';

  @override
  String get signOut => 'Sign Out';

  @override
  String get signIn => 'Sign In';

  @override
  String get signUp => 'Sign Up';

  @override
  String get email => 'Email';

  @override
  String get password => 'Password';

  @override
  String get forgotPassword => 'Forgot password?';

  @override
  String get createAccount => 'Create Account';

  @override
  String get newToSplitly => 'New to Splitly? ';

  @override
  String get alreadyHaveAccount => 'Already have an account? ';

  @override
  String get yourGroups => 'Your Groups';

  @override
  String get join => 'Join';

  @override
  String get newButton => 'New';

  @override
  String get newGroup => 'New Group';

  @override
  String get joinAGroup => 'Join a group';

  @override
  String get somethingWentWrong => 'Something went wrong';

  @override
  String get tryAgain => 'Try again';

  @override
  String membersCount(int count) {
    return '$count members';
  }

  @override
  String get createFirstGroupDesc =>
      'Create a new group or join one with an invite code.';

  @override
  String get splitlyFooter => 'Splitly v1.0.0 · Your Circle. Your Hisaab.';

  @override
  String get protectSplitly => 'Protect Splitly with a PIN or biometrics';

  @override
  String get addExtraLayer => 'Add an extra layer of security to your app';

  @override
  String get enablePinLock => 'Enable PIN Lock';

  @override
  String get useBiometricUnlock => 'Use Biometric Unlock';

  @override
  String get unlockWithFingerprint => 'Unlock with fingerprint or face';

  @override
  String get disableAppLock => 'Disable App Lock';

  @override
  String get disableAppLockTitle => 'Disable App Lock?';

  @override
  String get disableAppLockDesc =>
      'Your PIN will be removed and Splitly will open without asking for a PIN or biometric unlock.';

  @override
  String get cancel => 'Cancel';

  @override
  String get disable => 'Disable';

  @override
  String get signOutConfirmDesc => 'Are you sure you want to sign out?';

  @override
  String get system => 'System';
}
