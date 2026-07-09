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

  @override
  String get setAppPin => 'ایپ پن سیٹ کریں';

  @override
  String get confirmYourPin => 'اپنے پن کی تصدیق کریں';

  @override
  String get createPin => '4 ہندسوں کا پن بنائیں';

  @override
  String get enterSamePinAgain => 'وہی پن دوبارہ درج کریں';

  @override
  String get pinUsageHint =>
      'آپ اسے Splitly ان لاک کرنے کے لیے استعمال کریں گے';

  @override
  String get pinsDoNotMatch => 'پن مماثل نہیں ہیں۔ دوبارہ کوشش کریں۔';

  @override
  String get appLockEnabled => 'ایپ لاک فعال ہو گیا!';

  @override
  String get enterPinToContinue => 'جاری رکھنے کے لیے اپنا پن درج کریں';

  @override
  String get incorrectPin => 'غلط پن۔ دوبارہ کوشش کریں۔';

  @override
  String get useBiometricsButton => 'بایومیٹرک استعمال کریں';

  @override
  String exportGroupTitle(String groupName) {
    return '$groupName ایکسپورٹ کریں';
  }

  @override
  String get downloadExpenseRecords => 'اپنے اخراجات کا ریکارڈ ڈاؤن لوڈ کریں';

  @override
  String get noExpensesToExport => 'ابھی ایکسپورٹ کے لیے کوئی خرچہ نہیں۔';

  @override
  String get pdfExportedSuccess => 'پی ڈی ایف کامیابی سے ایکسپورٹ ہو گئی';

  @override
  String get pdfExportFailed => 'پی ڈی ایف ایکسپورٹ ناکام۔ دوبارہ کوشش کریں۔';

  @override
  String get csvExportedSuccess => 'سی ایس وی کامیابی سے ایکسپورٹ ہو گئی';

  @override
  String get csvExportFailed => 'سی ایس وی ایکسپورٹ ناکام۔ دوبارہ کوشش کریں۔';

  @override
  String get exportAsPdf => 'پی ڈی ایف کے طور پر ایکسپورٹ کریں';

  @override
  String get pdfSubtitle => 'خرچوں کی فہرست کے ساتھ خلاصہ';

  @override
  String get exportAsCsv => 'سی ایس وی کے طور پر ایکسپورٹ کریں';

  @override
  String get csvSubtitle => 'Excel یا Google Sheets کے لیے خام ڈیٹا';

  @override
  String get resetPasswordTitle => 'پاس ورڈ ری سیٹ کریں';

  @override
  String get forgotYourPassword => 'پاس ورڈ\nبھول گئے؟';

  @override
  String get resetLinkDesc =>
      'اپنا ای میل درج کریں اور ہم ایک محفوظ ری سیٹ لنک بھیجیں گے۔';

  @override
  String get sendResetLink => 'ری سیٹ لنک بھیجیں';

  @override
  String get checkYourEmail => 'اپنا ای میل چیک کریں';

  @override
  String get weSentResetLink => 'ہم نے ری سیٹ لنک بھیج دیا ہے';

  @override
  String get checkSpamFolder =>
      'اگر ایک منٹ میں نظر نہ آئے تو اسپیم فولڈر چیک کریں۔';

  @override
  String get backToSignIn => 'سائن ان پر واپس جائیں';

  @override
  String get setNewPassword => 'نیا پاس ورڈ سیٹ کریں';

  @override
  String get enterConfirmNewPassword =>
      'نیچے اپنا نیا پاس ورڈ درج اور تصدیق کریں۔';

  @override
  String get newPassword => 'نیا پاس ورڈ';

  @override
  String get confirmNewPassword => 'نئے پاس ورڈ کی تصدیق کریں';

  @override
  String get updatePassword => 'پاس ورڈ اپ ڈیٹ کریں';

  @override
  String get passwordUpdated => 'پاس ورڈ اپ ڈیٹ ہو گیا!';

  @override
  String get passwordUpdatedDesc =>
      'آپ کا پاس ورڈ کامیابی سے تبدیل ہو گیا ہے۔\nآپ کو اب سائن آؤٹ کیا جا رہا ہے...';

  @override
  String get updatePasswordFailed =>
      'پاس ورڈ اپ ڈیٹ نہیں ہو سکا۔ لنک کی میعاد ختم ہو چکی ہے۔ نیا لنک درخواست کریں۔';

  @override
  String get byCategory => 'قسم کے مطابق';

  @override
  String get byMember => 'رکن کے مطابق';

  @override
  String get thisMonth => 'اس مہینے';

  @override
  String get thisWeek => 'اس ہفتے';

  @override
  String get allTime => 'تمام وقت';

  @override
  String get totalSpentLabel => 'کل خرچ';

  @override
  String expensesCountLabel(int count) {
    return '$count خرچے';
  }

  @override
  String get avgLabel => 'اوسط';

  @override
  String get createGroupAddExpensesDesc =>
      'رپورٹ دیکھنے کے لیے گروپ بنائیں\nاور خرچے شامل کریں۔';

  @override
  String get noExpensesInPeriod => 'اس مدت میں کوئی خرچہ نہیں';

  @override
  String get tryDifferentPeriod => 'مختلف وقت کی مدت منتخب کریں';

  @override
  String get youPaid => 'آپ نے ادا کیا';

  @override
  String userPaid(String name) {
    return '$name نے ادا کیا';
  }

  @override
  String get youLent => 'آپ نے دیا';

  @override
  String youOweAmount(String amount) {
    return 'آپ پر $amount واجب ہے';
  }

  @override
  String get deleteExpense => 'خرچہ حذف کریں';

  @override
  String deleteExpenseConfirm(String title) {
    return '\"$title\" حذف کریں؟ یہ واپس نہیں ہو سکتا۔';
  }

  @override
  String get delete => 'حذف کریں';

  @override
  String get splitBreakdown => 'تقسیم کی تفصیل';

  @override
  String get settled => 'طے شدہ';

  @override
  String splitLabel(String type) {
    return '$type تقسیم';
  }

  @override
  String get searchExpenses => 'خرچے تلاش کریں...';

  @override
  String get all => 'تمام';

  @override
  String get today => 'آج';

  @override
  String get yesterday => 'کل';

  @override
  String get todayCaps => 'آج';

  @override
  String get noMatchingExpenses => 'کوئی مماثل خرچہ نہیں';

  @override
  String get tryChangingFilters => 'فلٹرز تبدیل یا صاف کریں';

  @override
  String get addExpenseToSeeHere => 'یہاں دیکھنے کے لیے خرچہ شامل کریں';

  @override
  String get shareSummaryTitle => 'خلاصہ شیئر کریں';

  @override
  String shareGroupSummary(String groupName) {
    return '$groupName کا خرچہ خلاصہ شیئر کریں';
  }

  @override
  String get preview => 'پیش نظارہ';

  @override
  String get whatsapp => 'واٹس ایپ';

  @override
  String get copy => 'کاپی';

  @override
  String get share => 'شیئر';

  @override
  String get summaryCopied => 'خلاصہ کاپی ہو گیا!';

  @override
  String get scanReceipt => 'رسید اسکین کریں';

  @override
  String get scanReceiptDesc => 'رقم خودکار بھرنے کے لیے رسید اسکین کریں';

  @override
  String get couldNotDetectTotal =>
      'کل رقم معلوم نہیں ہو سکی — براہ کرم نیچے درج کریں';

  @override
  String get detectedTotalConfirm => 'کل رقم مل گئی — نیچے تصدیق یا درست کریں';

  @override
  String get totalAmountLabel => 'کل رقم';

  @override
  String get useThisAmount => 'یہ رقم استعمال کریں';

  @override
  String get camera => 'کیمرہ';

  @override
  String get retake => 'دوبارہ لیں';

  @override
  String get gallery => 'گیلری';

  @override
  String get couldNotReadReceipt =>
      'رسید نہیں پڑھی جا سکی۔ براہ کرم رقم خود درج کریں۔';

  @override
  String get additionalDetailsHint => 'کوئی اضافی تفصیل...';

  @override
  String get whatWasItForHint => 'یہ کس کے لیے تھا؟';

  @override
  String get expenseTitleHint => 'مثلاً کھانا، سودا، ٹیکسی';

  @override
  String get pleaseEnterTitle => 'براہ کرم عنوان درج کریں';

  @override
  String get pleaseEnterValidAmount => 'براہ کرم درست رقم درج کریں';

  @override
  String get noMembersToSplit => 'تقسیم کے لیے کوئی رکن نہیں';

  @override
  String get pleaseSelectWhoPaid => 'براہ کرم منتخب کریں کس نے ادا کیا';

  @override
  String customAmountsMustAddUp(String currency, String amount) {
    return 'حسب ضرورت رقوم کا مجموعہ $currency $amount ہونا چاہیے';
  }

  @override
  String get percentagesMustAddTo100 => 'فیصد کا مجموعہ 100% ہونا چاہیے';

  @override
  String get expenseAdded => 'خرچہ شامل ہو گیا!';

  @override
  String get loadingMembers => 'اراکین لوڈ ہو رہے ہیں...';

  @override
  String get percentSymbol => '%';

  @override
  String get groupChat => 'گروپ چیٹ';

  @override
  String get noMessagesYet => 'ابھی کوئی پیغام نہیں';

  @override
  String get startTheConversation => 'بات چیت شروع کریں!';

  @override
  String get messageHint => 'پیغام...';

  @override
  String get todayLabel => 'آج';

  @override
  String get yesterdayLabel => 'کل';

  @override
  String get editProfileTitle => 'پروفائل میں ترمیم کریں';

  @override
  String get fullNameLabel => 'پورا نام';

  @override
  String get phoneNumber => 'فون نمبر';

  @override
  String get phoneOptional => 'فون نمبر (اختیاری)';

  @override
  String get chooseAvatarColor => 'اوتار کا رنگ منتخب کریں';

  @override
  String get saveChanges => 'تبدیلیاں محفوظ کریں';

  @override
  String get profileUpdated => 'پروفائل اپ ڈیٹ ہو گئی!';

  @override
  String get profileUpdateFailed =>
      'پروفائل اپ ڈیٹ نہیں ہو سکی۔ دوبارہ کوشش کریں۔';

  @override
  String get yourEmail => 'آپ کا ای میل';

  @override
  String get continueWithGoogle => 'Google کے ساتھ جاری رکھیں';

  @override
  String get skip => 'نظر انداز کریں';

  @override
  String get next => 'آگے';

  @override
  String get getStarted => 'شروع کریں';

  @override
  String get onboardTitle1 => 'گروپس کے ساتھ خرچے تقسیم کریں';

  @override
  String get onboardDesc1 =>
      'سفر، گھر، یا دوستوں کے لیے گروپس بنائیں اور مل کر خرچے ٹریک کریں۔';

  @override
  String get onboardTitle2 => 'چند سیکنڈ میں خرچہ شامل کریں';

  @override
  String get onboardDesc2 =>
      'رسیدیں اسکین کریں، برابر یا حسب ضرورت تقسیم کریں، اور فوراً دیکھیں کس پر کیا واجب ہے۔';

  @override
  String get onboardTitle3 => 'آسانی سے حساب برابر کریں';

  @override
  String get onboardDesc3 =>
      'سادہ کیے گئے قرضے دکھاتے ہیں سب کا حساب برابر کرنے کے لیے کم سے کم ادائیگیاں۔';

  @override
  String get photo => 'تصویر';

  @override
  String get camera2 => 'تصویر لیں';

  @override
  String get chooseFromGallery => 'گیلری سے منتخب کریں';

  @override
  String get recording => 'ریکارڈنگ...';

  @override
  String get tapToRecord => 'ریکارڈ کرنے کے لیے مائیک دبائیں';

  @override
  String get sendingAttachment => 'بھیجا جا رہا ہے...';

  @override
  String get voiceMessage => 'صوتی پیغام';

  @override
  String get microphonePermissionNeeded =>
      'صوتی پیغام ریکارڈ کرنے کے لیے مائیکروفون کی اجازت درکار ہے۔';

  @override
  String get failedToSendAttachment => 'بھیجا نہیں جا سکا۔ دوبارہ کوشش کریں۔';

  @override
  String get removeMember => 'رکن ہٹائیں';

  @override
  String removeMemberConfirm(String name) {
    return '$name کو اس گروپ سے ہٹا دیں؟';
  }

  @override
  String get remove => 'ہٹائیں';

  @override
  String get leaveGroup => 'گروپ چھوڑیں';

  @override
  String get leaveGroupConfirm => 'کیا آپ واقعی یہ گروپ چھوڑنا چاہتے ہیں؟';

  @override
  String get leave => 'چھوڑیں';

  @override
  String get makeAdmin => 'ایڈمن بنائیں';

  @override
  String get removeAdmin => 'ایڈمن ہٹائیں';

  @override
  String get memberRemoved => 'رکن ہٹا دیا گیا';

  @override
  String get youLeftGroup => 'آپ نے گروپ چھوڑ دیا';

  @override
  String get onlyAdminsCanDoThis => 'صرف گروپ ایڈمن یہ کر سکتے ہیں';

  @override
  String get changeGroupPhoto => 'گروپ کی تصویر تبدیل کریں';

  @override
  String get groupPhotoUpdated => 'گروپ کی تصویر اپ ڈیٹ ہو گئی!';

  @override
  String get failedToUpdatePhoto =>
      'تصویر اپ ڈیٹ نہیں ہو سکی۔ دوبارہ کوشش کریں۔';

  @override
  String get deleteMessage => 'پیغام حذف کریں';

  @override
  String get deleteMessageConfirm => 'یہ پیغام حذف کریں؟';

  @override
  String get copyMessage => 'کاپی کریں';

  @override
  String replyTo(String name) {
    return '$name کو جواب دے رہے ہیں';
  }

  @override
  String get messageCopied => 'پیغام کاپی ہو گیا!';

  @override
  String isTyping(String name) {
    return '$name ٹائپ کر رہے ہیں...';
  }

  @override
  String get severalTyping => 'کئی لوگ ٹائپ کر رہے ہیں...';

  @override
  String get messageDeleted => 'پیغام حذف ہو گیا';

  @override
  String get reply => 'جواب دیں';
}
