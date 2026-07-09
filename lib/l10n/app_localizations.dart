import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ur.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ur')
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'Splitly'**
  String get appName;

  /// No description provided for @tagline.
  ///
  /// In en, this message translates to:
  /// **'Your Circle. Your Hisaab.'**
  String get tagline;

  /// No description provided for @groups.
  ///
  /// In en, this message translates to:
  /// **'Groups'**
  String get groups;

  /// No description provided for @balances.
  ///
  /// In en, this message translates to:
  /// **'Balances'**
  String get balances;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @hey.
  ///
  /// In en, this message translates to:
  /// **'Hey, {name}'**
  String hey(String name);

  /// No description provided for @balanceSummary.
  ///
  /// In en, this message translates to:
  /// **'Here\'s your balance summary'**
  String get balanceSummary;

  /// No description provided for @youAreOwed.
  ///
  /// In en, this message translates to:
  /// **'You are owed'**
  String get youAreOwed;

  /// No description provided for @youOwe.
  ///
  /// In en, this message translates to:
  /// **'You owe'**
  String get youOwe;

  /// No description provided for @createGroup.
  ///
  /// In en, this message translates to:
  /// **'Create Group'**
  String get createGroup;

  /// No description provided for @joinGroup.
  ///
  /// In en, this message translates to:
  /// **'Join Group'**
  String get joinGroup;

  /// No description provided for @noGroupsYet.
  ///
  /// In en, this message translates to:
  /// **'No groups yet'**
  String get noGroupsYet;

  /// No description provided for @createFirstGroup.
  ///
  /// In en, this message translates to:
  /// **'Create your first group to start splitting expenses'**
  String get createFirstGroup;

  /// No description provided for @joinWithInviteCode.
  ///
  /// In en, this message translates to:
  /// **'Join with Invite Code'**
  String get joinWithInviteCode;

  /// No description provided for @addExpense.
  ///
  /// In en, this message translates to:
  /// **'Add Expense'**
  String get addExpense;

  /// No description provided for @whatWasItFor.
  ///
  /// In en, this message translates to:
  /// **'What was it for?'**
  String get whatWasItFor;

  /// No description provided for @amount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get amount;

  /// No description provided for @category.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get category;

  /// No description provided for @paidBy.
  ///
  /// In en, this message translates to:
  /// **'Paid by'**
  String get paidBy;

  /// No description provided for @split.
  ///
  /// In en, this message translates to:
  /// **'Split'**
  String get split;

  /// No description provided for @equal.
  ///
  /// In en, this message translates to:
  /// **'Equal'**
  String get equal;

  /// No description provided for @custom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get custom;

  /// No description provided for @notes.
  ///
  /// In en, this message translates to:
  /// **'Notes (optional)'**
  String get notes;

  /// No description provided for @settleUp.
  ///
  /// In en, this message translates to:
  /// **'Settle up'**
  String get settleUp;

  /// No description provided for @allSettledUp.
  ///
  /// In en, this message translates to:
  /// **'All settled up!'**
  String get allSettledUp;

  /// No description provided for @noOutstandingBalances.
  ///
  /// In en, this message translates to:
  /// **'No outstanding balances. Everyone is even.'**
  String get noOutstandingBalances;

  /// No description provided for @expenseHistory.
  ///
  /// In en, this message translates to:
  /// **'Expense History'**
  String get expenseHistory;

  /// No description provided for @spendingReports.
  ///
  /// In en, this message translates to:
  /// **'Spending Reports'**
  String get spendingReports;

  /// No description provided for @shareSummary.
  ///
  /// In en, this message translates to:
  /// **'Share Summary'**
  String get shareSummary;

  /// No description provided for @exportPdfCsv.
  ///
  /// In en, this message translates to:
  /// **'Export PDF/CSV'**
  String get exportPdfCsv;

  /// No description provided for @archiveGroup.
  ///
  /// In en, this message translates to:
  /// **'Archive Group'**
  String get archiveGroup;

  /// No description provided for @inviteCode.
  ///
  /// In en, this message translates to:
  /// **'Invite Code'**
  String get inviteCode;

  /// No description provided for @copyCode.
  ///
  /// In en, this message translates to:
  /// **'Copy Code'**
  String get copyCode;

  /// No description provided for @editProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit Profile'**
  String get editProfile;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @darkMode.
  ///
  /// In en, this message translates to:
  /// **'Dark Mode'**
  String get darkMode;

  /// No description provided for @lightMode.
  ///
  /// In en, this message translates to:
  /// **'Light Mode'**
  String get lightMode;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @appLock.
  ///
  /// In en, this message translates to:
  /// **'App Lock / PIN'**
  String get appLock;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get signOut;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get signIn;

  /// No description provided for @signUp.
  ///
  /// In en, this message translates to:
  /// **'Sign Up'**
  String get signUp;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get forgotPassword;

  /// No description provided for @createAccount.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get createAccount;

  /// No description provided for @newToSplitly.
  ///
  /// In en, this message translates to:
  /// **'New to Splitly? '**
  String get newToSplitly;

  /// No description provided for @alreadyHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? '**
  String get alreadyHaveAccount;

  /// No description provided for @yourGroups.
  ///
  /// In en, this message translates to:
  /// **'Your Groups'**
  String get yourGroups;

  /// No description provided for @join.
  ///
  /// In en, this message translates to:
  /// **'Join'**
  String get join;

  /// No description provided for @newButton.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get newButton;

  /// No description provided for @newGroup.
  ///
  /// In en, this message translates to:
  /// **'New Group'**
  String get newGroup;

  /// No description provided for @joinAGroup.
  ///
  /// In en, this message translates to:
  /// **'Join a group'**
  String get joinAGroup;

  /// No description provided for @somethingWentWrong.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get somethingWentWrong;

  /// No description provided for @tryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get tryAgain;

  /// No description provided for @membersCount.
  ///
  /// In en, this message translates to:
  /// **'{count} members'**
  String membersCount(int count);

  /// No description provided for @createFirstGroupDesc.
  ///
  /// In en, this message translates to:
  /// **'Create a new group or join one with an invite code.'**
  String get createFirstGroupDesc;

  /// No description provided for @splitlyFooter.
  ///
  /// In en, this message translates to:
  /// **'Splitly v1.0.0 · Your Circle. Your Hisaab.'**
  String get splitlyFooter;

  /// No description provided for @protectSplitly.
  ///
  /// In en, this message translates to:
  /// **'Protect Splitly with a PIN or biometrics'**
  String get protectSplitly;

  /// No description provided for @addExtraLayer.
  ///
  /// In en, this message translates to:
  /// **'Add an extra layer of security to your app'**
  String get addExtraLayer;

  /// No description provided for @enablePinLock.
  ///
  /// In en, this message translates to:
  /// **'Enable PIN Lock'**
  String get enablePinLock;

  /// No description provided for @useBiometricUnlock.
  ///
  /// In en, this message translates to:
  /// **'Use Biometric Unlock'**
  String get useBiometricUnlock;

  /// No description provided for @unlockWithFingerprint.
  ///
  /// In en, this message translates to:
  /// **'Unlock with fingerprint or face'**
  String get unlockWithFingerprint;

  /// No description provided for @disableAppLock.
  ///
  /// In en, this message translates to:
  /// **'Disable App Lock'**
  String get disableAppLock;

  /// No description provided for @disableAppLockTitle.
  ///
  /// In en, this message translates to:
  /// **'Disable App Lock?'**
  String get disableAppLockTitle;

  /// No description provided for @disableAppLockDesc.
  ///
  /// In en, this message translates to:
  /// **'Your PIN will be removed and Splitly will open without asking for a PIN or biometric unlock.'**
  String get disableAppLockDesc;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @disable.
  ///
  /// In en, this message translates to:
  /// **'Disable'**
  String get disable;

  /// No description provided for @signOutConfirmDesc.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to sign out?'**
  String get signOutConfirmDesc;

  /// No description provided for @system.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get system;

  /// No description provided for @overallBalance.
  ///
  /// In en, this message translates to:
  /// **'Overall Balance'**
  String get overallBalance;

  /// No description provided for @whoOwesWho.
  ///
  /// In en, this message translates to:
  /// **'Who owes who'**
  String get whoOwesWho;

  /// No description provided for @byGroup.
  ///
  /// In en, this message translates to:
  /// **'By group'**
  String get byGroup;

  /// No description provided for @owedToYou.
  ///
  /// In en, this message translates to:
  /// **'Owed to you'**
  String get owedToYou;

  /// No description provided for @youAreOwedLower.
  ///
  /// In en, this message translates to:
  /// **'you are owed'**
  String get youAreOwedLower;

  /// No description provided for @youOweLower.
  ///
  /// In en, this message translates to:
  /// **'you owe'**
  String get youOweLower;

  /// No description provided for @createOrJoinGroup.
  ///
  /// In en, this message translates to:
  /// **'Create or join a group to\nstart tracking balances.'**
  String get createOrJoinGroup;

  /// No description provided for @youWord.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get youWord;

  /// No description provided for @owesWord.
  ///
  /// In en, this message translates to:
  /// **' owe '**
  String get owesWord;

  /// No description provided for @youWordLower.
  ///
  /// In en, this message translates to:
  /// **'you'**
  String get youWordLower;

  /// No description provided for @orContinueWith.
  ///
  /// In en, this message translates to:
  /// **'or continue with'**
  String get orContinueWith;

  /// No description provided for @welcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get welcomeBack;

  /// No description provided for @signInToAccount.
  ///
  /// In en, this message translates to:
  /// **'Sign in to your account'**
  String get signInToAccount;

  /// No description provided for @emailRequired.
  ///
  /// In en, this message translates to:
  /// **'Email is required'**
  String get emailRequired;

  /// No description provided for @enterValidEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email'**
  String get enterValidEmail;

  /// No description provided for @passwordRequired.
  ///
  /// In en, this message translates to:
  /// **'Password is required'**
  String get passwordRequired;

  /// No description provided for @atLeast6Chars.
  ///
  /// In en, this message translates to:
  /// **'At least 6 characters'**
  String get atLeast6Chars;

  /// No description provided for @createAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get createAccountTitle;

  /// No description provided for @joinSplitly.
  ///
  /// In en, this message translates to:
  /// **'Join Splitly'**
  String get joinSplitly;

  /// No description provided for @splitExpensesCircle.
  ///
  /// In en, this message translates to:
  /// **'Split expenses with your circle'**
  String get splitExpensesCircle;

  /// No description provided for @fullName.
  ///
  /// In en, this message translates to:
  /// **'Full Name'**
  String get fullName;

  /// No description provided for @nameRequired.
  ///
  /// In en, this message translates to:
  /// **'Name is required'**
  String get nameRequired;

  /// No description provided for @nameTooShort.
  ///
  /// In en, this message translates to:
  /// **'Name too short'**
  String get nameTooShort;

  /// No description provided for @confirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm Password'**
  String get confirmPassword;

  /// No description provided for @confirmYourPassword.
  ///
  /// In en, this message translates to:
  /// **'Please confirm your password'**
  String get confirmYourPassword;

  /// No description provided for @passwordsDoNotMatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get passwordsDoNotMatch;

  /// No description provided for @accountCreatedCheckEmail.
  ///
  /// In en, this message translates to:
  /// **'Account created! Check your email to verify'**
  String get accountCreatedCheckEmail;

  /// No description provided for @totalSpent.
  ///
  /// In en, this message translates to:
  /// **'Total spent'**
  String get totalSpent;

  /// No description provided for @members.
  ///
  /// In en, this message translates to:
  /// **'Members'**
  String get members;

  /// No description provided for @admin.
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get admin;

  /// No description provided for @couldNotLoadMembers.
  ///
  /// In en, this message translates to:
  /// **'Could not load members'**
  String get couldNotLoadMembers;

  /// No description provided for @couldNotLoadExpenses.
  ///
  /// In en, this message translates to:
  /// **'Could not load expenses'**
  String get couldNotLoadExpenses;

  /// No description provided for @noExpensesYet.
  ///
  /// In en, this message translates to:
  /// **'No expenses yet'**
  String get noExpensesYet;

  /// No description provided for @addFirstExpenseDesc.
  ///
  /// In en, this message translates to:
  /// **'Add the first expense to start tracking who owes what.'**
  String get addFirstExpenseDesc;

  /// No description provided for @history.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get history;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @inviteToGroup.
  ///
  /// In en, this message translates to:
  /// **'Invite to {groupName}'**
  String inviteToGroup(String groupName);

  /// No description provided for @shareCodeDesc.
  ///
  /// In en, this message translates to:
  /// **'Share this code with friends to join'**
  String get shareCodeDesc;

  /// No description provided for @inviteCodeCopied.
  ///
  /// In en, this message translates to:
  /// **'Invite code copied!'**
  String get inviteCodeCopied;

  /// No description provided for @shareInviteCode.
  ///
  /// In en, this message translates to:
  /// **'Share Invite Code'**
  String get shareInviteCode;

  /// No description provided for @youJoinedGroup.
  ///
  /// In en, this message translates to:
  /// **'You joined the group!'**
  String get youJoinedGroup;

  /// No description provided for @archiveGroupTitle.
  ///
  /// In en, this message translates to:
  /// **'Archive Group?'**
  String get archiveGroupTitle;

  /// No description provided for @archiveGroupDesc.
  ///
  /// In en, this message translates to:
  /// **'You can still view past expenses, but no new expenses can be added.'**
  String get archiveGroupDesc;

  /// No description provided for @archive.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get archive;

  /// No description provided for @createAGroup.
  ///
  /// In en, this message translates to:
  /// **'Create a Group'**
  String get createAGroup;

  /// No description provided for @startSplittingCircle.
  ///
  /// In en, this message translates to:
  /// **'Start splitting expenses with your circle'**
  String get startSplittingCircle;

  /// No description provided for @groupType.
  ///
  /// In en, this message translates to:
  /// **'Group type'**
  String get groupType;

  /// No description provided for @groupName.
  ///
  /// In en, this message translates to:
  /// **'Group name'**
  String get groupName;

  /// No description provided for @groupNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Group name is required'**
  String get groupNameRequired;

  /// No description provided for @groupNameTooShort.
  ///
  /// In en, this message translates to:
  /// **'Name too short'**
  String get groupNameTooShort;

  /// No description provided for @description.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get description;

  /// No description provided for @descriptionOptional.
  ///
  /// In en, this message translates to:
  /// **'Description (optional)'**
  String get descriptionOptional;

  /// No description provided for @currency.
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get currency;

  /// No description provided for @groupCreated.
  ///
  /// In en, this message translates to:
  /// **'Group created!'**
  String get groupCreated;

  /// No description provided for @joinAGroupTitle.
  ///
  /// In en, this message translates to:
  /// **'Join a Group'**
  String get joinAGroupTitle;

  /// No description provided for @enterInviteCodeDesc.
  ///
  /// In en, this message translates to:
  /// **'Enter the invite code shared by your group admin'**
  String get enterInviteCodeDesc;

  /// No description provided for @pleaseEnterInviteCode.
  ///
  /// In en, this message translates to:
  /// **'Please enter an invite code'**
  String get pleaseEnterInviteCode;

  /// No description provided for @invalidInviteCode.
  ///
  /// In en, this message translates to:
  /// **'Invalid invite code. Please check and try again.'**
  String get invalidInviteCode;

  /// No description provided for @alreadyMemberOf.
  ///
  /// In en, this message translates to:
  /// **'You are already a member of \"{groupName}\".'**
  String alreadyMemberOf(String groupName);

  /// No description provided for @expensesHeading.
  ///
  /// In en, this message translates to:
  /// **'Expenses'**
  String get expensesHeading;

  /// No description provided for @youPay.
  ///
  /// In en, this message translates to:
  /// **'You pay'**
  String get youPay;

  /// No description provided for @userPays.
  ///
  /// In en, this message translates to:
  /// **'{name} pays'**
  String userPays(String name);

  /// No description provided for @amountToSettle.
  ///
  /// In en, this message translates to:
  /// **'Amount to settle'**
  String get amountToSettle;

  /// No description provided for @settleUpInfo.
  ///
  /// In en, this message translates to:
  /// **'This will mark all related expense splits as settled between these two people.'**
  String get settleUpInfo;

  /// No description provided for @confirmSettlement.
  ///
  /// In en, this message translates to:
  /// **'Confirm Settlement'**
  String get confirmSettlement;

  /// No description provided for @settlementRecorded.
  ///
  /// In en, this message translates to:
  /// **'Settlement recorded! ✅'**
  String get settlementRecorded;

  /// No description provided for @setAppPin.
  ///
  /// In en, this message translates to:
  /// **'Set App PIN'**
  String get setAppPin;

  /// No description provided for @confirmYourPin.
  ///
  /// In en, this message translates to:
  /// **'Confirm your PIN'**
  String get confirmYourPin;

  /// No description provided for @createPin.
  ///
  /// In en, this message translates to:
  /// **'Create a 4-digit PIN'**
  String get createPin;

  /// No description provided for @enterSamePinAgain.
  ///
  /// In en, this message translates to:
  /// **'Enter the same PIN again'**
  String get enterSamePinAgain;

  /// No description provided for @pinUsageHint.
  ///
  /// In en, this message translates to:
  /// **'You\'ll use this to unlock Splitly'**
  String get pinUsageHint;

  /// No description provided for @pinsDoNotMatch.
  ///
  /// In en, this message translates to:
  /// **'PINs do not match. Try again.'**
  String get pinsDoNotMatch;

  /// No description provided for @appLockEnabled.
  ///
  /// In en, this message translates to:
  /// **'App Lock enabled!'**
  String get appLockEnabled;

  /// No description provided for @enterPinToContinue.
  ///
  /// In en, this message translates to:
  /// **'Enter your PIN to continue'**
  String get enterPinToContinue;

  /// No description provided for @incorrectPin.
  ///
  /// In en, this message translates to:
  /// **'Incorrect PIN. Try again.'**
  String get incorrectPin;

  /// No description provided for @useBiometricsButton.
  ///
  /// In en, this message translates to:
  /// **'Use biometrics'**
  String get useBiometricsButton;

  /// No description provided for @exportGroupTitle.
  ///
  /// In en, this message translates to:
  /// **'Export {groupName}'**
  String exportGroupTitle(String groupName);

  /// No description provided for @downloadExpenseRecords.
  ///
  /// In en, this message translates to:
  /// **'Download your expense records'**
  String get downloadExpenseRecords;

  /// No description provided for @noExpensesToExport.
  ///
  /// In en, this message translates to:
  /// **'No expenses to export yet.'**
  String get noExpensesToExport;

  /// No description provided for @pdfExportedSuccess.
  ///
  /// In en, this message translates to:
  /// **'PDF exported successfully'**
  String get pdfExportedSuccess;

  /// No description provided for @pdfExportFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to export PDF. Please try again.'**
  String get pdfExportFailed;

  /// No description provided for @csvExportedSuccess.
  ///
  /// In en, this message translates to:
  /// **'CSV exported successfully'**
  String get csvExportedSuccess;

  /// No description provided for @csvExportFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to export CSV. Please try again.'**
  String get csvExportFailed;

  /// No description provided for @exportAsPdf.
  ///
  /// In en, this message translates to:
  /// **'Export as PDF'**
  String get exportAsPdf;

  /// No description provided for @pdfSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Formatted summary with expense list'**
  String get pdfSubtitle;

  /// No description provided for @exportAsCsv.
  ///
  /// In en, this message translates to:
  /// **'Export as CSV'**
  String get exportAsCsv;

  /// No description provided for @csvSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Raw data for Excel or Google Sheets'**
  String get csvSubtitle;

  /// No description provided for @resetPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset Password'**
  String get resetPasswordTitle;

  /// No description provided for @forgotYourPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot your\npassword?'**
  String get forgotYourPassword;

  /// No description provided for @resetLinkDesc.
  ///
  /// In en, this message translates to:
  /// **'Enter your email and we\'ll send a secure reset link.'**
  String get resetLinkDesc;

  /// No description provided for @sendResetLink.
  ///
  /// In en, this message translates to:
  /// **'Send Reset Link'**
  String get sendResetLink;

  /// No description provided for @checkYourEmail.
  ///
  /// In en, this message translates to:
  /// **'Check your email'**
  String get checkYourEmail;

  /// No description provided for @weSentResetLink.
  ///
  /// In en, this message translates to:
  /// **'We sent a reset link to'**
  String get weSentResetLink;

  /// No description provided for @checkSpamFolder.
  ///
  /// In en, this message translates to:
  /// **'Check your spam folder if you don\'t see it within a minute.'**
  String get checkSpamFolder;

  /// No description provided for @backToSignIn.
  ///
  /// In en, this message translates to:
  /// **'Back to Sign In'**
  String get backToSignIn;

  /// No description provided for @setNewPassword.
  ///
  /// In en, this message translates to:
  /// **'Set new password'**
  String get setNewPassword;

  /// No description provided for @enterConfirmNewPassword.
  ///
  /// In en, this message translates to:
  /// **'Enter and confirm your new password below.'**
  String get enterConfirmNewPassword;

  /// No description provided for @newPassword.
  ///
  /// In en, this message translates to:
  /// **'New Password'**
  String get newPassword;

  /// No description provided for @confirmNewPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm New Password'**
  String get confirmNewPassword;

  /// No description provided for @updatePassword.
  ///
  /// In en, this message translates to:
  /// **'Update Password'**
  String get updatePassword;

  /// No description provided for @passwordUpdated.
  ///
  /// In en, this message translates to:
  /// **'Password updated!'**
  String get passwordUpdated;

  /// No description provided for @passwordUpdatedDesc.
  ///
  /// In en, this message translates to:
  /// **'Your password has been changed successfully.\nSigning you out now...'**
  String get passwordUpdatedDesc;

  /// No description provided for @updatePasswordFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to update password. The link may have expired. Please request a new one.'**
  String get updatePasswordFailed;

  /// No description provided for @byCategory.
  ///
  /// In en, this message translates to:
  /// **'By Category'**
  String get byCategory;

  /// No description provided for @byMember.
  ///
  /// In en, this message translates to:
  /// **'By Member'**
  String get byMember;

  /// No description provided for @thisMonth.
  ///
  /// In en, this message translates to:
  /// **'This month'**
  String get thisMonth;

  /// No description provided for @thisWeek.
  ///
  /// In en, this message translates to:
  /// **'This week'**
  String get thisWeek;

  /// No description provided for @allTime.
  ///
  /// In en, this message translates to:
  /// **'All time'**
  String get allTime;

  /// No description provided for @totalSpentLabel.
  ///
  /// In en, this message translates to:
  /// **'Total Spent'**
  String get totalSpentLabel;

  /// No description provided for @expensesCountLabel.
  ///
  /// In en, this message translates to:
  /// **'{count} expenses'**
  String expensesCountLabel(int count);

  /// No description provided for @avgLabel.
  ///
  /// In en, this message translates to:
  /// **'avg'**
  String get avgLabel;

  /// No description provided for @createGroupAddExpensesDesc.
  ///
  /// In en, this message translates to:
  /// **'Create a group and add expenses\nto see spending reports.'**
  String get createGroupAddExpensesDesc;

  /// No description provided for @noExpensesInPeriod.
  ///
  /// In en, this message translates to:
  /// **'No expenses in this period'**
  String get noExpensesInPeriod;

  /// No description provided for @tryDifferentPeriod.
  ///
  /// In en, this message translates to:
  /// **'Try selecting a different time period'**
  String get tryDifferentPeriod;

  /// No description provided for @youPaid.
  ///
  /// In en, this message translates to:
  /// **'You paid'**
  String get youPaid;

  /// No description provided for @userPaid.
  ///
  /// In en, this message translates to:
  /// **'{name} paid'**
  String userPaid(String name);

  /// No description provided for @youLent.
  ///
  /// In en, this message translates to:
  /// **'you lent'**
  String get youLent;

  /// No description provided for @youOweAmount.
  ///
  /// In en, this message translates to:
  /// **'you owe {amount}'**
  String youOweAmount(String amount);

  /// No description provided for @deleteExpense.
  ///
  /// In en, this message translates to:
  /// **'Delete Expense'**
  String get deleteExpense;

  /// No description provided for @deleteExpenseConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{title}\"? This cannot be undone.'**
  String deleteExpenseConfirm(String title);

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @splitBreakdown.
  ///
  /// In en, this message translates to:
  /// **'Split breakdown'**
  String get splitBreakdown;

  /// No description provided for @settled.
  ///
  /// In en, this message translates to:
  /// **'Settled'**
  String get settled;

  /// No description provided for @splitLabel.
  ///
  /// In en, this message translates to:
  /// **'{type} split'**
  String splitLabel(String type);

  /// No description provided for @searchExpenses.
  ///
  /// In en, this message translates to:
  /// **'Search expenses...'**
  String get searchExpenses;

  /// No description provided for @all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @yesterday.
  ///
  /// In en, this message translates to:
  /// **'YESTERDAY'**
  String get yesterday;

  /// No description provided for @todayCaps.
  ///
  /// In en, this message translates to:
  /// **'TODAY'**
  String get todayCaps;

  /// No description provided for @noMatchingExpenses.
  ///
  /// In en, this message translates to:
  /// **'No matching expenses'**
  String get noMatchingExpenses;

  /// No description provided for @tryChangingFilters.
  ///
  /// In en, this message translates to:
  /// **'Try changing or clearing the filters'**
  String get tryChangingFilters;

  /// No description provided for @addExpenseToSeeHere.
  ///
  /// In en, this message translates to:
  /// **'Add an expense to see it here'**
  String get addExpenseToSeeHere;

  /// No description provided for @shareSummaryTitle.
  ///
  /// In en, this message translates to:
  /// **'Share Summary'**
  String get shareSummaryTitle;

  /// No description provided for @shareGroupSummary.
  ///
  /// In en, this message translates to:
  /// **'Share {groupName} expense summary'**
  String shareGroupSummary(String groupName);

  /// No description provided for @preview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get preview;

  /// No description provided for @whatsapp.
  ///
  /// In en, this message translates to:
  /// **'WhatsApp'**
  String get whatsapp;

  /// No description provided for @copy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copy;

  /// No description provided for @share.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// No description provided for @summaryCopied.
  ///
  /// In en, this message translates to:
  /// **'Summary copied!'**
  String get summaryCopied;

  /// No description provided for @scanReceipt.
  ///
  /// In en, this message translates to:
  /// **'Scan Receipt'**
  String get scanReceipt;

  /// No description provided for @scanReceiptDesc.
  ///
  /// In en, this message translates to:
  /// **'Scan a receipt to auto-fill amount'**
  String get scanReceiptDesc;

  /// No description provided for @couldNotDetectTotal.
  ///
  /// In en, this message translates to:
  /// **'Could not detect total — please enter it below'**
  String get couldNotDetectTotal;

  /// No description provided for @detectedTotalConfirm.
  ///
  /// In en, this message translates to:
  /// **'Detected total — confirm or correct it below'**
  String get detectedTotalConfirm;

  /// No description provided for @totalAmountLabel.
  ///
  /// In en, this message translates to:
  /// **'Total Amount'**
  String get totalAmountLabel;

  /// No description provided for @useThisAmount.
  ///
  /// In en, this message translates to:
  /// **'Use This Amount'**
  String get useThisAmount;

  /// No description provided for @camera.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get camera;

  /// No description provided for @retake.
  ///
  /// In en, this message translates to:
  /// **'Retake'**
  String get retake;

  /// No description provided for @gallery.
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get gallery;

  /// No description provided for @couldNotReadReceipt.
  ///
  /// In en, this message translates to:
  /// **'Could not read receipt. Please enter amount manually.'**
  String get couldNotReadReceipt;

  /// No description provided for @additionalDetailsHint.
  ///
  /// In en, this message translates to:
  /// **'Any additional details...'**
  String get additionalDetailsHint;

  /// No description provided for @whatWasItForHint.
  ///
  /// In en, this message translates to:
  /// **'What was it for?'**
  String get whatWasItForHint;

  /// No description provided for @expenseTitleHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Dinner, Groceries, Taxi'**
  String get expenseTitleHint;

  /// No description provided for @pleaseEnterTitle.
  ///
  /// In en, this message translates to:
  /// **'Please enter a title'**
  String get pleaseEnterTitle;

  /// No description provided for @pleaseEnterValidAmount.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid amount'**
  String get pleaseEnterValidAmount;

  /// No description provided for @noMembersToSplit.
  ///
  /// In en, this message translates to:
  /// **'No members to split with'**
  String get noMembersToSplit;

  /// No description provided for @pleaseSelectWhoPaid.
  ///
  /// In en, this message translates to:
  /// **'Please select who paid'**
  String get pleaseSelectWhoPaid;

  /// No description provided for @customAmountsMustAddUp.
  ///
  /// In en, this message translates to:
  /// **'Custom amounts must add up to {currency} {amount}'**
  String customAmountsMustAddUp(String currency, String amount);

  /// No description provided for @percentagesMustAddTo100.
  ///
  /// In en, this message translates to:
  /// **'Percentages must add up to 100%'**
  String get percentagesMustAddTo100;

  /// No description provided for @expenseAdded.
  ///
  /// In en, this message translates to:
  /// **'Expense added!'**
  String get expenseAdded;

  /// No description provided for @loadingMembers.
  ///
  /// In en, this message translates to:
  /// **'Loading members...'**
  String get loadingMembers;

  /// No description provided for @percentSymbol.
  ///
  /// In en, this message translates to:
  /// **'%'**
  String get percentSymbol;

  /// No description provided for @groupChat.
  ///
  /// In en, this message translates to:
  /// **'Group chat'**
  String get groupChat;

  /// No description provided for @noMessagesYet.
  ///
  /// In en, this message translates to:
  /// **'No messages yet'**
  String get noMessagesYet;

  /// No description provided for @startTheConversation.
  ///
  /// In en, this message translates to:
  /// **'Start the conversation!'**
  String get startTheConversation;

  /// No description provided for @messageHint.
  ///
  /// In en, this message translates to:
  /// **'Message...'**
  String get messageHint;

  /// No description provided for @todayLabel.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get todayLabel;

  /// No description provided for @yesterdayLabel.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get yesterdayLabel;

  /// No description provided for @editProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Profile'**
  String get editProfileTitle;

  /// No description provided for @fullNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Full Name'**
  String get fullNameLabel;

  /// No description provided for @phoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Phone Number'**
  String get phoneNumber;

  /// No description provided for @phoneOptional.
  ///
  /// In en, this message translates to:
  /// **'Phone Number (optional)'**
  String get phoneOptional;

  /// No description provided for @chooseAvatarColor.
  ///
  /// In en, this message translates to:
  /// **'Choose Avatar Color'**
  String get chooseAvatarColor;

  /// No description provided for @saveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get saveChanges;

  /// No description provided for @profileUpdated.
  ///
  /// In en, this message translates to:
  /// **'Profile updated!'**
  String get profileUpdated;

  /// No description provided for @profileUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to update profile. Please try again.'**
  String get profileUpdateFailed;

  /// No description provided for @yourEmail.
  ///
  /// In en, this message translates to:
  /// **'Your Email'**
  String get yourEmail;

  /// No description provided for @continueWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get continueWithGoogle;

  /// No description provided for @skip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @getStarted.
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get getStarted;

  /// No description provided for @onboardTitle1.
  ///
  /// In en, this message translates to:
  /// **'Split Expenses with Groups'**
  String get onboardTitle1;

  /// No description provided for @onboardDesc1.
  ///
  /// In en, this message translates to:
  /// **'Create groups for trips, home, or friends and track shared expenses together.'**
  String get onboardDesc1;

  /// No description provided for @onboardTitle2.
  ///
  /// In en, this message translates to:
  /// **'Add Expenses in Seconds'**
  String get onboardTitle2;

  /// No description provided for @onboardDesc2.
  ///
  /// In en, this message translates to:
  /// **'Scan receipts, split equally or custom, and see who owes what instantly.'**
  String get onboardDesc2;

  /// No description provided for @onboardTitle3.
  ///
  /// In en, this message translates to:
  /// **'Settle Up Easily'**
  String get onboardTitle3;

  /// No description provided for @onboardDesc3.
  ///
  /// In en, this message translates to:
  /// **'Simplified debts show the minimum payments needed to settle everyone up.'**
  String get onboardDesc3;

  /// No description provided for @photo.
  ///
  /// In en, this message translates to:
  /// **'Photo'**
  String get photo;

  /// No description provided for @camera2.
  ///
  /// In en, this message translates to:
  /// **'Take Photo'**
  String get camera2;

  /// No description provided for @chooseFromGallery.
  ///
  /// In en, this message translates to:
  /// **'Choose from Gallery'**
  String get chooseFromGallery;

  /// No description provided for @recording.
  ///
  /// In en, this message translates to:
  /// **'Recording...'**
  String get recording;

  /// No description provided for @tapToRecord.
  ///
  /// In en, this message translates to:
  /// **'Tap mic to record'**
  String get tapToRecord;

  /// No description provided for @sendingAttachment.
  ///
  /// In en, this message translates to:
  /// **'Sending...'**
  String get sendingAttachment;

  /// No description provided for @voiceMessage.
  ///
  /// In en, this message translates to:
  /// **'Voice message'**
  String get voiceMessage;

  /// No description provided for @microphonePermissionNeeded.
  ///
  /// In en, this message translates to:
  /// **'Microphone permission needed to record voice messages.'**
  String get microphonePermissionNeeded;

  /// No description provided for @failedToSendAttachment.
  ///
  /// In en, this message translates to:
  /// **'Failed to send. Please try again.'**
  String get failedToSendAttachment;

  /// No description provided for @removeMember.
  ///
  /// In en, this message translates to:
  /// **'Remove Member'**
  String get removeMember;

  /// No description provided for @removeMemberConfirm.
  ///
  /// In en, this message translates to:
  /// **'Remove {name} from this group?'**
  String removeMemberConfirm(String name);

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @leaveGroup.
  ///
  /// In en, this message translates to:
  /// **'Leave Group'**
  String get leaveGroup;

  /// No description provided for @leaveGroupConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to leave this group?'**
  String get leaveGroupConfirm;

  /// No description provided for @leave.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get leave;

  /// No description provided for @makeAdmin.
  ///
  /// In en, this message translates to:
  /// **'Make Admin'**
  String get makeAdmin;

  /// No description provided for @removeAdmin.
  ///
  /// In en, this message translates to:
  /// **'Remove Admin'**
  String get removeAdmin;

  /// No description provided for @memberRemoved.
  ///
  /// In en, this message translates to:
  /// **'Member removed'**
  String get memberRemoved;

  /// No description provided for @youLeftGroup.
  ///
  /// In en, this message translates to:
  /// **'You left the group'**
  String get youLeftGroup;

  /// No description provided for @onlyAdminsCanDoThis.
  ///
  /// In en, this message translates to:
  /// **'Only group admins can do this'**
  String get onlyAdminsCanDoThis;

  /// No description provided for @changeGroupPhoto.
  ///
  /// In en, this message translates to:
  /// **'Change Group Photo'**
  String get changeGroupPhoto;

  /// No description provided for @groupPhotoUpdated.
  ///
  /// In en, this message translates to:
  /// **'Group photo updated!'**
  String get groupPhotoUpdated;

  /// No description provided for @failedToUpdatePhoto.
  ///
  /// In en, this message translates to:
  /// **'Failed to update photo. Please try again'**
  String get failedToUpdatePhoto;

  /// No description provided for @deleteMessage.
  ///
  /// In en, this message translates to:
  /// **'Delete Message'**
  String get deleteMessage;

  /// No description provided for @deleteMessageConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete this message?'**
  String get deleteMessageConfirm;

  /// No description provided for @copyMessage.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copyMessage;

  /// No description provided for @replyTo.
  ///
  /// In en, this message translates to:
  /// **'Replying to {name}'**
  String replyTo(String name);

  /// No description provided for @messageCopied.
  ///
  /// In en, this message translates to:
  /// **'Message copied!'**
  String get messageCopied;

  /// No description provided for @isTyping.
  ///
  /// In en, this message translates to:
  /// **'{name} is typing...'**
  String isTyping(String name);

  /// No description provided for @severalTyping.
  ///
  /// In en, this message translates to:
  /// **'Several people are typing...'**
  String get severalTyping;

  /// No description provided for @messageDeleted.
  ///
  /// In en, this message translates to:
  /// **'Message deleted'**
  String get messageDeleted;

  /// No description provided for @reply.
  ///
  /// In en, this message translates to:
  /// **'Reply'**
  String get reply;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ur'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ur':
      return AppLocalizationsUr();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
