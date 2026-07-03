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

  @override
  String get overallBalance => 'Overall Balance';

  @override
  String get whoOwesWho => 'Who owes who';

  @override
  String get byGroup => 'By group';

  @override
  String get owedToYou => 'Owed to you';

  @override
  String get youAreOwedLower => 'you are owed';

  @override
  String get youOweLower => 'you owe';

  @override
  String get createOrJoinGroup =>
      'Create or join a group to\nstart tracking balances.';

  @override
  String get youWord => 'You';

  @override
  String get owesWord => ' owe ';

  @override
  String get youWordLower => 'you';

  @override
  String get orContinueWith => 'or continue with';

  @override
  String get welcomeBack => 'Welcome back';

  @override
  String get signInToAccount => 'Sign in to your account';

  @override
  String get emailRequired => 'Email is required';

  @override
  String get enterValidEmail => 'Enter a valid email';

  @override
  String get passwordRequired => 'Password is required';

  @override
  String get atLeast6Chars => 'At least 6 characters';

  @override
  String get createAccountTitle => 'Create Account';

  @override
  String get joinSplitly => 'Join Splitly';

  @override
  String get splitExpensesCircle => 'Split expenses with your circle';

  @override
  String get fullName => 'Full Name';

  @override
  String get nameRequired => 'Name is required';

  @override
  String get nameTooShort => 'Name too short';

  @override
  String get confirmPassword => 'Confirm Password';

  @override
  String get confirmYourPassword => 'Please confirm your password';

  @override
  String get passwordsDoNotMatch => 'Passwords do not match';

  @override
  String get accountCreatedCheckEmail =>
      'Account created! Check your email to verify';

  @override
  String get totalSpent => 'Total spent';

  @override
  String get members => 'Members';

  @override
  String get admin => 'Admin';

  @override
  String get couldNotLoadMembers => 'Could not load members';

  @override
  String get couldNotLoadExpenses => 'Could not load expenses';

  @override
  String get noExpensesYet => 'No expenses yet';

  @override
  String get addFirstExpenseDesc =>
      'Add the first expense to start tracking who owes what.';

  @override
  String get history => 'History';

  @override
  String get add => 'Add';

  @override
  String inviteToGroup(String groupName) {
    return 'Invite to $groupName';
  }

  @override
  String get shareCodeDesc => 'Share this code with friends to join';

  @override
  String get inviteCodeCopied => 'Invite code copied!';

  @override
  String get shareInviteCode => 'Share Invite Code';

  @override
  String get youJoinedGroup => 'You joined the group!';

  @override
  String get archiveGroupTitle => 'Archive Group?';

  @override
  String get archiveGroupDesc =>
      'You can still view past expenses, but no new expenses can be added.';

  @override
  String get archive => 'Archive';

  @override
  String get createAGroup => 'Create a Group';

  @override
  String get startSplittingCircle =>
      'Start splitting expenses with your circle';

  @override
  String get groupType => 'Group type';

  @override
  String get groupName => 'Group name';

  @override
  String get groupNameRequired => 'Group name is required';

  @override
  String get groupNameTooShort => 'Name too short';

  @override
  String get description => 'Description';

  @override
  String get descriptionOptional => 'Description (optional)';

  @override
  String get currency => 'Currency';

  @override
  String get groupCreated => 'Group created!';

  @override
  String get joinAGroupTitle => 'Join a Group';

  @override
  String get enterInviteCodeDesc =>
      'Enter the invite code shared by your group admin';

  @override
  String get pleaseEnterInviteCode => 'Please enter an invite code';

  @override
  String get invalidInviteCode =>
      'Invalid invite code. Please check and try again.';

  @override
  String alreadyMemberOf(String groupName) {
    return 'You are already a member of \"$groupName\".';
  }

  @override
  String get expensesHeading => 'Expenses';

  @override
  String get youPay => 'You pay';

  @override
  String userPays(String name) {
    return '$name pays';
  }

  @override
  String get amountToSettle => 'Amount to settle';

  @override
  String get settleUpInfo =>
      'This will mark all related expense splits as settled between these two people.';

  @override
  String get confirmSettlement => 'Confirm Settlement';

  @override
  String get settlementRecorded => 'Settlement recorded! ✅';
}
