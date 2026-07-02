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
}
