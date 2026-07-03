// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Urdu (`ur`).
class AppLocalizationsUr extends AppLocalizations {
  AppLocalizationsUr([String locale = 'ur']) : super(locale);

  @override
  String get appName => 'Splitly';

  @override
  String get tagline => 'آپ کا حلقہ۔ آپ کا حساب۔';

  @override
  String get groups => 'گروپس';

  @override
  String get balances => 'بیلنس';

  @override
  String get profile => 'پروفائل';

  @override
  String hey(String name) {
    return 'ہیلو، $name';
  }

  @override
  String get balanceSummary => 'یہ ہے آپ کا بیلنس خلاصہ';

  @override
  String get youAreOwed => 'آپ کو ملنا ہے';

  @override
  String get youOwe => 'آپ پر واجب ہے';

  @override
  String get createGroup => 'گروپ بنائیں';

  @override
  String get joinGroup => 'گروپ میں شامل ہوں';

  @override
  String get noGroupsYet => 'ابھی کوئی گروپ نہیں';

  @override
  String get createFirstGroup => 'خرچے تقسیم کرنے کے لیے اپنا پہلا گروپ بنائیں';

  @override
  String get joinWithInviteCode => 'دعوتی کوڈ سے شامل ہوں';

  @override
  String get addExpense => 'خرچہ شامل کریں';

  @override
  String get whatWasItFor => 'یہ کس کے لیے تھا؟';

  @override
  String get amount => 'رقم';

  @override
  String get category => 'قسم';

  @override
  String get paidBy => 'ادائیگی کی گئی';

  @override
  String get split => 'تقسیم';

  @override
  String get equal => 'برابر';

  @override
  String get custom => 'حسب ضرورت';

  @override
  String get notes => 'نوٹس (اختیاری)';

  @override
  String get settleUp => 'حساب برابر کریں';

  @override
  String get allSettledUp => 'سب حساب برابر ہے!';

  @override
  String get noOutstandingBalances => 'کوئی بقایا رقم نہیں۔ سب برابر ہیں۔';

  @override
  String get expenseHistory => 'خرچے کی تاریخ';

  @override
  String get spendingReports => 'اخراجات کی رپورٹ';

  @override
  String get shareSummary => 'خلاصہ شیئر کریں';

  @override
  String get exportPdfCsv => 'پی ڈی ایف/سی ایس وی ایکسپورٹ';

  @override
  String get archiveGroup => 'گروپ آرکائیو کریں';

  @override
  String get inviteCode => 'دعوتی کوڈ';

  @override
  String get copyCode => 'کوڈ کاپی کریں';

  @override
  String get editProfile => 'پروفائل میں ترمیم کریں';

  @override
  String get notifications => 'اطلاعات';

  @override
  String get darkMode => 'ڈارک موڈ';

  @override
  String get lightMode => 'لائٹ موڈ';

  @override
  String get language => 'زبان';

  @override
  String get appLock => 'ایپ لاک / پن';

  @override
  String get signOut => 'سائن آؤٹ';

  @override
  String get signIn => 'سائن ان';

  @override
  String get signUp => 'سائن اپ';

  @override
  String get email => 'ای میل';

  @override
  String get password => 'پاس ورڈ';

  @override
  String get forgotPassword => 'پاس ورڈ بھول گئے؟';

  @override
  String get createAccount => 'اکاؤنٹ بنائیں';

  @override
  String get newToSplitly => 'Splitly پر نئے ہیں؟ ';

  @override
  String get alreadyHaveAccount => 'پہلے سے اکاؤنٹ ہے؟ ';

  @override
  String get yourGroups => 'آپ کے گروپس';

  @override
  String get join => 'شامل ہوں';

  @override
  String get newButton => 'نیا';

  @override
  String get newGroup => 'نیا گروپ';

  @override
  String get joinAGroup => 'گروپ میں شامل ہوں';

  @override
  String get somethingWentWrong => 'کچھ غلط ہو گیا';

  @override
  String get tryAgain => 'دوبارہ کوشش کریں';

  @override
  String membersCount(int count) {
    return '$count اراکین';
  }

  @override
  String get createFirstGroupDesc =>
      'نیا گروپ بنائیں یا دعوتی کوڈ سے شامل ہوں۔';

  @override
  String get splitlyFooter => 'Splitly v1.0.0 · آپ کا حلقہ۔ آپ کا حساب۔';

  @override
  String get protectSplitly => 'پن یا بایومیٹرک سے Splitly کو محفوظ بنائیں';

  @override
  String get addExtraLayer => 'اپنی ایپ میں سیکیورٹی کی اضافی تہہ شامل کریں';

  @override
  String get enablePinLock => 'پن لاک فعال کریں';

  @override
  String get useBiometricUnlock => 'بایومیٹرک ان لاک استعمال کریں';

  @override
  String get unlockWithFingerprint => 'فنگر پرنٹ یا چہرے سے ان لاک کریں';

  @override
  String get disableAppLock => 'ایپ لاک غیر فعال کریں';

  @override
  String get disableAppLockTitle => 'ایپ لاک غیر فعال کریں؟';

  @override
  String get disableAppLockDesc =>
      'آپ کا پن ہٹا دیا جائے گا اور Splitly بغیر پن یا بایومیٹرک کے کھلے گی۔';

  @override
  String get cancel => 'منسوخ کریں';

  @override
  String get disable => 'غیر فعال کریں';

  @override
  String get signOutConfirmDesc => 'کیا آپ واقعی سائن آؤٹ کرنا چاہتے ہیں؟';

  @override
  String get system => 'سسٹم';

  @override
  String get overallBalance => 'مجموعی بیلنس';

  @override
  String get whoOwesWho => 'کس پر کتنا واجب ہے';

  @override
  String get byGroup => 'بلحاظ گروپ';

  @override
  String get owedToYou => 'آپ کو ملنا ہے';

  @override
  String get youAreOwedLower => 'آپ کو ملنا ہے';

  @override
  String get youOweLower => 'آپ پر واجب ہے';

  @override
  String get createOrJoinGroup =>
      'بیلنس دیکھنے کے لیے گروپ بنائیں\nیا شامل ہوں۔';

  @override
  String get youWord => 'آپ';

  @override
  String get owesWord => ' پر واجب ہے ';

  @override
  String get youWordLower => 'آپ پر';

  @override
  String get orContinueWith => 'یا اس کے ذریعے جاری رکھیں';

  @override
  String get welcomeBack => 'خوش آمدید';

  @override
  String get signInToAccount => 'اپنے اکاؤنٹ میں سائن ان کریں';

  @override
  String get emailRequired => 'ای میل درکار ہے';

  @override
  String get enterValidEmail => 'درست ای میل درج کریں';

  @override
  String get passwordRequired => 'پاس ورڈ درکار ہے';

  @override
  String get atLeast6Chars => 'کم از کم 6 حروف';

  @override
  String get createAccountTitle => 'اکاؤنٹ بنائیں';

  @override
  String get joinSplitly => 'Splitly میں شامل ہوں';

  @override
  String get splitExpensesCircle => 'اپنے حلقے کے ساتھ اخراجات تقسیم کریں';

  @override
  String get fullName => 'پورا نام';

  @override
  String get nameRequired => 'نام درکار ہے';

  @override
  String get nameTooShort => 'نام بہت مختصر ہے';

  @override
  String get confirmPassword => 'پاس ورڈ کی تصدیق کریں';

  @override
  String get confirmYourPassword => 'براہ کرم اپنے پاس ورڈ کی تصدیق کریں';

  @override
  String get passwordsDoNotMatch => 'پاس ورڈز مماثل نہیں ہیں';

  @override
  String get accountCreatedCheckEmail =>
      'اکاؤنٹ بن گیا! تصدیق کے لیے اپنا ای میل چیک کریں';

  @override
  String get totalSpent => 'کل خرچ';

  @override
  String get members => 'اراکین';

  @override
  String get admin => 'ایڈمن';

  @override
  String get couldNotLoadMembers => 'اراکین لوڈ نہیں ہو سکے';

  @override
  String get couldNotLoadExpenses => 'خرچے لوڈ نہیں ہو سکے';

  @override
  String get noExpensesYet => 'ابھی کوئی خرچہ نہیں';

  @override
  String get addFirstExpenseDesc =>
      'کس پر کیا واجب ہے جاننے کے لیے پہلا خرچہ شامل کریں۔';

  @override
  String get history => 'تاریخ';

  @override
  String get add => 'شامل کریں';

  @override
  String inviteToGroup(String groupName) {
    return '$groupName میں دعوت دیں';
  }

  @override
  String get shareCodeDesc =>
      'شامل ہونے کے لیے دوستوں کے ساتھ یہ کوڈ شیئر کریں';

  @override
  String get inviteCodeCopied => 'دعوتی کوڈ کاپی ہو گیا!';

  @override
  String get shareInviteCode => 'دعوتی کوڈ شیئر کریں';

  @override
  String get youJoinedGroup => 'آپ گروپ میں شامل ہو گئے!';

  @override
  String get archiveGroupTitle => 'گروپ آرکائیو کریں؟';

  @override
  String get archiveGroupDesc =>
      'آپ اب بھی پرانے خرچے دیکھ سکتے ہیں، لیکن نئے خرچے شامل نہیں کیے جا سکتے۔';

  @override
  String get archive => 'آرکائیو کریں';

  @override
  String get createAGroup => 'گروپ بنائیں';

  @override
  String get startSplittingCircle =>
      'اپنے حلقے کے ساتھ خرچے تقسیم کرنا شروع کریں';

  @override
  String get groupType => 'گروپ کی قسم';

  @override
  String get groupName => 'گروپ کا نام';

  @override
  String get groupNameRequired => 'گروپ کا نام درکار ہے';

  @override
  String get groupNameTooShort => 'نام بہت مختصر ہے';

  @override
  String get description => 'تفصیل';

  @override
  String get descriptionOptional => 'تفصیل (اختیاری)';

  @override
  String get currency => 'کرنسی';

  @override
  String get groupCreated => 'گروپ بن گیا!';

  @override
  String get joinAGroupTitle => 'گروپ میں شامل ہوں';

  @override
  String get enterInviteCodeDesc => 'گروپ ایڈمن کا دیا ہوا دعوتی کوڈ درج کریں';

  @override
  String get pleaseEnterInviteCode => 'براہ کرم دعوتی کوڈ درج کریں';

  @override
  String get invalidInviteCode =>
      'غلط دعوتی کوڈ۔ براہ کرم چیک کر کے دوبارہ کوشش کریں۔';

  @override
  String alreadyMemberOf(String groupName) {
    return 'آپ پہلے سے \"$groupName\" کے رکن ہیں۔';
  }

  @override
  String get expensesHeading => 'خرچے';

  @override
  String get youPay => 'آپ ادا کریں';

  @override
  String userPays(String name) {
    return '$name ادا کرتے ہیں';
  }

  @override
  String get amountToSettle => 'طے کرنے کی رقم';

  @override
  String get settleUpInfo =>
      'اس سے ان دونوں کے درمیان متعلقہ خرچے طے شدہ کے طور پر نشان زد ہو جائیں گے۔';

  @override
  String get confirmSettlement => 'تصفیہ کی تصدیق کریں';

  @override
  String get settlementRecorded => 'تصفیہ محفوظ ہو گیا! ✅';
}
