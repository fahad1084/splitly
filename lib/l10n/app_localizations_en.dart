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
  String get errorGeneric => 'Something went wrong. Please try again.';

  @override
  String get errorNoInternet =>
      'No internet connection. Please check your connection and try again.';

  @override
  String get errorWrongLogin => 'Wrong email or password.';

  @override
  String get errorEmailNotConfirmed =>
      'Please confirm your email first. Check your inbox for the link.';

  @override
  String get errorEmailInUse =>
      'An account with this email already exists. Try logging in.';

  @override
  String get errorWeakPassword =>
      'This password is too weak. Please choose a stronger one.';

  @override
  String get errorTooManyTries =>
      'Too many tries. Please wait a few minutes and try again.';

  @override
  String get errorNotAllowed => 'You\'re not allowed to do this.';

  @override
  String get errorNotSignedIn =>
      'Your session has ended. Please sign in again.';

  @override
  String get errorGoogleSignIn =>
      'Google sign-in didn\'t work. Please try again.';

  @override
  String get couldNotLoad => 'Couldn\'t load this. Please try again.';

  @override
  String get couldNotLoadUnread => 'Couldn\'t load unread messages.';

  @override
  String get couldNotLoadBalances => 'Couldn\'t load your balances.';

  @override
  String membersCount(int count) {
    return '$count members';
  }

  @override
  String get createFirstGroupDesc =>
      'Create a new group or join one with an invite code.';

  @override
  String get splitlyFooter => 'Splitly v1.2.0 · Your Circle. Your Hisaab.';

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
      'You can pay part of it. Only the person receiving the money can confirm it.';

  @override
  String get confirmSettlement => 'Confirm Settlement';

  @override
  String get settlementRecorded => 'Settlement recorded! ✅';

  @override
  String get setAppPin => 'Set App PIN';

  @override
  String get confirmYourPin => 'Confirm your PIN';

  @override
  String get createPin => 'Create a 4-digit PIN';

  @override
  String get enterSamePinAgain => 'Enter the same PIN again';

  @override
  String get pinUsageHint => 'You\'ll use this to unlock Splitly';

  @override
  String get pinsDoNotMatch => 'PINs do not match. Try again.';

  @override
  String get appLockEnabled => 'App Lock enabled!';

  @override
  String get enterPinToContinue => 'Enter your PIN to continue';

  @override
  String get incorrectPin => 'Incorrect PIN. Try again.';

  @override
  String get useBiometricsButton => 'Use biometrics';

  @override
  String tooManyPinAttempts(String time) {
    return 'Too many wrong tries. Try again in $time.';
  }

  @override
  String lockedNotificationMessage(String group) {
    return 'New message in $group';
  }

  @override
  String lockedNotificationActivity(String group) {
    return 'New activity in $group';
  }

  @override
  String exportGroupTitle(String groupName) {
    return 'Export $groupName';
  }

  @override
  String get downloadExpenseRecords => 'Download your expense records';

  @override
  String get noExpensesToExport => 'No expenses to export yet.';

  @override
  String get pdfExportedSuccess => 'PDF exported successfully';

  @override
  String get pdfExportFailed => 'Failed to export PDF. Please try again.';

  @override
  String get csvExportedSuccess => 'CSV exported successfully';

  @override
  String get csvExportFailed => 'Failed to export CSV. Please try again.';

  @override
  String get exportAsPdf => 'Export as PDF';

  @override
  String get pdfSubtitle => 'Formatted summary with expense list';

  @override
  String get exportAsCsv => 'Export as CSV';

  @override
  String get csvSubtitle => 'Raw data for Excel or Google Sheets';

  @override
  String get resetPasswordTitle => 'Reset Password';

  @override
  String get forgotYourPassword => 'Forgot your\npassword?';

  @override
  String get resetLinkDesc =>
      'Enter your email and we\'ll send a secure reset link.';

  @override
  String get sendResetLink => 'Send Reset Link';

  @override
  String get checkYourEmail => 'Check your email';

  @override
  String get weSentResetLink => 'We sent a reset link to';

  @override
  String get checkSpamFolder =>
      'Check your spam folder if you don\'t see it within a minute.';

  @override
  String get backToSignIn => 'Back to Sign In';

  @override
  String get setNewPassword => 'Set new password';

  @override
  String get enterConfirmNewPassword =>
      'Enter and confirm your new password below.';

  @override
  String get newPassword => 'New Password';

  @override
  String get confirmNewPassword => 'Confirm New Password';

  @override
  String get updatePassword => 'Update Password';

  @override
  String get passwordUpdated => 'Password updated!';

  @override
  String get passwordUpdatedDesc =>
      'Your password has been changed successfully.\nSigning you out now...';

  @override
  String get updatePasswordFailed =>
      'Failed to update password. The link may have expired. Please request a new one.';

  @override
  String get byCategory => 'By Category';

  @override
  String get byMember => 'By Member';

  @override
  String get thisMonth => 'This month';

  @override
  String get thisWeek => 'This week';

  @override
  String get allTime => 'All time';

  @override
  String get totalSpentLabel => 'Total Spent';

  @override
  String expensesCountLabel(int count) {
    return '$count expenses';
  }

  @override
  String get avgLabel => 'avg';

  @override
  String get createGroupAddExpensesDesc =>
      'Create a group and add expenses\nto see spending reports.';

  @override
  String get noExpensesInPeriod => 'No expenses in this period';

  @override
  String get tryDifferentPeriod => 'Try selecting a different time period';

  @override
  String get youPaid => 'You paid';

  @override
  String userPaid(String name) {
    return '$name paid';
  }

  @override
  String get youLent => 'you lent';

  @override
  String youOweAmount(String amount) {
    return 'you owe $amount';
  }

  @override
  String get deleteExpense => 'Delete Expense';

  @override
  String deleteExpenseConfirm(String title) {
    return 'Delete \"$title\"? This cannot be undone.';
  }

  @override
  String get delete => 'Delete';

  @override
  String get splitBreakdown => 'Split breakdown';

  @override
  String get settled => 'Settled';

  @override
  String splitLabel(String type) {
    return '$type split';
  }

  @override
  String get searchExpenses => 'Search expenses...';

  @override
  String get all => 'All';

  @override
  String get today => 'Today';

  @override
  String get yesterday => 'YESTERDAY';

  @override
  String get todayCaps => 'TODAY';

  @override
  String get noMatchingExpenses => 'No matching expenses';

  @override
  String get tryChangingFilters => 'Try changing or clearing the filters';

  @override
  String get addExpenseToSeeHere => 'Add an expense to see it here';

  @override
  String get shareSummaryTitle => 'Share Summary';

  @override
  String shareGroupSummary(String groupName) {
    return 'Share $groupName expense summary';
  }

  @override
  String get preview => 'Preview';

  @override
  String get whatsapp => 'WhatsApp';

  @override
  String get copy => 'Copy';

  @override
  String get share => 'Share';

  @override
  String get summaryCopied => 'Summary copied!';

  @override
  String get scanReceipt => 'Scan Receipt';

  @override
  String get scanReceiptDesc => 'Scan a receipt to auto-fill amount';

  @override
  String get couldNotDetectTotal =>
      'Could not detect total — please enter it below';

  @override
  String get detectedTotalConfirm =>
      'Detected total — confirm or correct it below';

  @override
  String get totalAmountLabel => 'Total Amount';

  @override
  String get useThisAmount => 'Use This Amount';

  @override
  String get camera => 'Camera';

  @override
  String get retake => 'Retake';

  @override
  String get gallery => 'Gallery';

  @override
  String get couldNotReadReceipt =>
      'Could not read receipt. Please enter amount manually.';

  @override
  String get additionalDetailsHint => 'Any additional details...';

  @override
  String get whatWasItForHint => 'What was it for?';

  @override
  String get expenseTitleHint => 'e.g. Dinner, Groceries, Taxi';

  @override
  String get pleaseEnterTitle => 'Please enter a title';

  @override
  String get pleaseEnterValidAmount => 'Please enter a valid amount';

  @override
  String get noMembersToSplit => 'No members to split with';

  @override
  String get pleaseSelectWhoPaid => 'Please select who paid';

  @override
  String customAmountsMustAddUp(String currency, String amount) {
    return 'Custom amounts must add up to $currency $amount';
  }

  @override
  String get percentagesMustAddTo100 => 'Percentages must add up to 100%';

  @override
  String get expenseAdded => 'Expense added!';

  @override
  String get loadingMembers => 'Loading members...';

  @override
  String get percentSymbol => '%';

  @override
  String get groupChat => 'Group chat';

  @override
  String get noMessagesYet => 'No messages yet';

  @override
  String get startTheConversation => 'Start the conversation!';

  @override
  String get messageHint => 'Message...';

  @override
  String get todayLabel => 'Today';

  @override
  String get yesterdayLabel => 'Yesterday';

  @override
  String get editProfileTitle => 'Edit Profile';

  @override
  String get fullNameLabel => 'Full Name';

  @override
  String get phoneNumber => 'Phone Number';

  @override
  String get phoneOptional => 'Phone Number (optional)';

  @override
  String get chooseAvatarColor => 'Choose Avatar Color';

  @override
  String get saveChanges => 'Save Changes';

  @override
  String get profileUpdated => 'Profile updated!';

  @override
  String get profileUpdateFailed =>
      'Failed to update profile. Please try again.';

  @override
  String get yourEmail => 'Your Email';

  @override
  String get continueWithGoogle => 'Continue with Google';

  @override
  String get skip => 'Skip';

  @override
  String get next => 'Next';

  @override
  String get getStarted => 'Get Started';

  @override
  String get onboardTitle1 => 'Split Expenses with Groups';

  @override
  String get onboardDesc1 =>
      'Create groups for trips, home, or friends and track shared expenses together.';

  @override
  String get onboardTitle2 => 'Add Expenses in Seconds';

  @override
  String get onboardDesc2 =>
      'Scan receipts, split equally or custom, and see who owes what instantly.';

  @override
  String get onboardTitle3 => 'Settle Up Easily';

  @override
  String get onboardDesc3 =>
      'Simplified debts show the minimum payments needed to settle everyone up.';

  @override
  String get photo => 'Photo';

  @override
  String get camera2 => 'Take Photo';

  @override
  String get chooseFromGallery => 'Choose from Gallery';

  @override
  String get recording => 'Recording...';

  @override
  String get tapToRecord => 'Tap mic to record';

  @override
  String get sendingAttachment => 'Sending...';

  @override
  String get voiceMessage => 'Voice message';

  @override
  String get microphonePermissionNeeded =>
      'Microphone permission needed to record voice messages.';

  @override
  String get failedToSendAttachment => 'Failed to send. Please try again.';

  @override
  String get removeMember => 'Remove Member';

  @override
  String removeMemberConfirm(String name) {
    return 'Remove $name from this group?';
  }

  @override
  String get remove => 'Remove';

  @override
  String get leaveGroup => 'Leave Group';

  @override
  String get leaveGroupConfirm => 'Are you sure you want to leave this group?';

  @override
  String get leave => 'Leave';

  @override
  String get makeAdmin => 'Make Admin';

  @override
  String get removeAdmin => 'Remove Admin';

  @override
  String get memberRemoved => 'Member removed';

  @override
  String get youLeftGroup => 'You left the group';

  @override
  String get onlyAdminsCanDoThis => 'Only group admins can do this';

  @override
  String get changeGroupPhoto => 'Change Group Photo';

  @override
  String get groupPhotoUpdated => 'Group photo updated!';

  @override
  String get failedToUpdatePhoto => 'Failed to update photo. Please try again';

  @override
  String get deleteMessage => 'Delete Message';

  @override
  String get deleteMessageConfirm => 'Delete this message?';

  @override
  String get copyMessage => 'Copy';

  @override
  String replyTo(String name) {
    return 'Replying to $name';
  }

  @override
  String get messageCopied => 'Message copied!';

  @override
  String isTyping(String name) {
    return '$name is typing...';
  }

  @override
  String get severalTyping => 'Several people are typing...';

  @override
  String get messageDeleted => 'Message deleted';

  @override
  String get reply => 'Reply';

  @override
  String get deleteAccount => 'Delete Account';

  @override
  String get deleteAccountTitle => 'Delete Account';

  @override
  String get deleteAccountWarning =>
      'This will permanently sign you out and disable this account. Your name will show as \"Deleted User\" in any group expenses you\'re part of, so balances stay accurate for others. This cannot be undone.';

  @override
  String get deleteAccountConfirmPrompt =>
      'Type DELETE to confirm you want to permanently delete your account.';

  @override
  String get continueLabel => 'Continue';

  @override
  String get customRange => 'Custom range';

  @override
  String get repeatThisExpense => 'Repeat this expense';

  @override
  String get daily => 'Daily';

  @override
  String get weekly => 'Weekly';

  @override
  String get monthly => 'Monthly';

  @override
  String shareInviteMessage(String groupName, String inviteCode) {
    return 'Join \"$groupName\" on Splitly! Use invite code $inviteCode to start splitting expenses together.\n\n_Splitly — Your Circle. Your Hisaab._';
  }

  @override
  String get notificationSettings => 'Notification Settings';

  @override
  String get notificationSettingsDesc =>
      'Choose what you get notified about across all your groups.';

  @override
  String get notifyNewMessages => 'New messages';

  @override
  String get notifyNewExpenses => 'New expenses';

  @override
  String get notifySettlements => 'Settlements';

  @override
  String get notifyNewMembers => 'New members joining';

  @override
  String get noNotificationsYet => 'No notifications yet';

  @override
  String get markAllRead => 'Mark all read';

  @override
  String get scanQrCode => 'Scan QR Code';

  @override
  String get notifyDebtReminders => 'Debt reminders';

  @override
  String get archivedGroups => 'Archived Groups';

  @override
  String get noArchivedGroups => 'No archived groups';

  @override
  String get unarchive => 'Unarchive';

  @override
  String get groupUnarchived => 'Group restored!';

  @override
  String get deleteGroupTitle => 'Delete Group Permanently?';

  @override
  String deleteGroupWarning(String groupName) {
    return 'This will permanently delete \"$groupName\" and all its expenses, chat, and settlements for every member. This cannot be undone.';
  }

  @override
  String get deletePermanently => 'Delete Permanently';

  @override
  String get groupDeleted => 'Group deleted';

  @override
  String get payments => 'Payments';

  @override
  String get noPaymentsYet => 'No payments yet';

  @override
  String get iPaid => 'I paid';

  @override
  String get markAsReceived => 'Mark as received';

  @override
  String upToAmount(String amount) {
    return 'Up to $amount';
  }

  @override
  String settlePendingInfo(String name) {
    return '$name will be asked to confirm. Until then the payment shows as pending.';
  }

  @override
  String get settleReceiverInfo =>
      'This counts right away, because you are the one receiving the money.';

  @override
  String get paymentWaitingConfirmation =>
      'Payment recorded — waiting for confirmation';

  @override
  String get paymentConfirmed => 'Payment confirmed ✅';

  @override
  String get paymentCancelled => 'Payment cancelled';

  @override
  String get confirmPayment => 'Confirm';

  @override
  String get cancelPayment => 'Cancel payment';

  @override
  String get statusPending => 'Pending';

  @override
  String get statusConfirmed => 'Confirmed';

  @override
  String get statusCancelled => 'Cancelled';

  @override
  String get statusEarlier => 'Earlier';

  @override
  String amountPending(String amount) {
    return '$amount pending';
  }

  @override
  String paymentsWaitingForYou(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count payments are waiting for your confirmation',
      one: '1 payment is waiting for your confirmation',
    );
    return '$_temp0';
  }

  @override
  String get amountMoreThanOwed => 'That is more than is still owed';

  @override
  String get nothingOwedHere => 'Nothing is owed between you any more';

  @override
  String get cantLeaveYet => 'You can\'t leave yet';

  @override
  String get settleTheseFirst => 'Settle these first:';

  @override
  String youOweUser(String name, String amount) {
    return 'You owe $name $amount';
  }

  @override
  String userOwesYou(String name, String amount) {
    return '$name owes you $amount';
  }

  @override
  String cantRemoveMemberYet(String name) {
    return '$name can\'t be removed yet';
  }

  @override
  String userOwesUser(String debtor, String creditor, String amount) {
    return '$debtor owes $creditor $amount';
  }

  @override
  String get expenseHasPaymentsWarning =>
      'Payments were already made after this expense. Deleting it changes the balances, and the debt can switch to the other person.';

  @override
  String get expenseDateLabel => 'Date';

  @override
  String get editExpense => 'Edit expense';

  @override
  String get expenseUpdated => 'Expense updated!';

  @override
  String get editedLabel => 'edited';

  @override
  String get cantEditMemberLeft =>
      'This expense can\'t be changed: someone in it has left the group.';

  @override
  String get onlyPayerOrAdminCanEdit =>
      'Only the person who paid or a group admin can change this expense.';

  @override
  String get expenseEditHasPaymentsWarning =>
      'Payments were already made after this expense. Changing it changes the balances, and the debt can switch to the other person.';

  @override
  String get recurringExpenses => 'Recurring expenses';

  @override
  String get noRecurringExpenses =>
      'No recurring expenses yet. Turn on \"Repeat this expense\" when you add an expense.';

  @override
  String nextOn(String date) {
    return 'Next: $date';
  }

  @override
  String get recurPausedLabel => 'Paused';

  @override
  String get pauseRepeating => 'Pause';

  @override
  String get resumeRepeating => 'Resume';

  @override
  String get stopRepeating => 'Stop repeating';

  @override
  String stopRepeatingConfirm(String title) {
    return 'Stop repeating \"$title\"? Copies that were already added stay.';
  }

  @override
  String get recurringPausedMsg => 'Paused. No new copies until you resume.';

  @override
  String get recurringResumedMsg => 'Resumed.';

  @override
  String get recurringStoppedMsg => 'Stopped repeating.';

  @override
  String get groupTypeHome => 'Home';

  @override
  String get groupTypeTrip => 'Trip';

  @override
  String get groupTypeFriends => 'Friends';

  @override
  String get groupTypeOffice => 'Office';

  @override
  String get groupTypeFamily => 'Family';

  @override
  String get groupTypeOther => 'Other';

  @override
  String get groupNoLongerAvailable =>
      'This group isn\'t available any more. You may have left it, or it was deleted.';

  @override
  String get expenseNoLongerExists => 'This expense was deleted.';
}
