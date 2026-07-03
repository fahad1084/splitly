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
