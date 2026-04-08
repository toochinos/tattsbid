// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Khmer Central Khmer (`km`).
class AppLocalizationsKm extends AppLocalizations {
  AppLocalizationsKm([String locale = 'km']) : super(locale);

  @override
  String get tabExplore => 'រុករក';

  @override
  String get tabArtists => 'សិល្បករ';

  @override
  String get tabUpload => 'ផ្ទុកឡើង';

  @override
  String get tabMessage => 'សារ';

  @override
  String get tabProfile => 'ប្រវត្តិរូប';

  @override
  String get exploreTitle => 'រុករក';

  @override
  String postedOnDate(String date) {
    return 'បានប្រកាស $date';
  }

  @override
  String requestBidsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ដេញថ្លៃ',
      one: '$count ដេញថ្លៃ',
      zero: '$count ដេញថ្លៃ',
    );
    return '$_temp0';
  }

  @override
  String get bidClosed => 'បិទដេញថ្លៃ';

  @override
  String get noTattooRequestsYet => 'មិនទាន់មានសំណើសាក់';

  @override
  String get addRequestToSeeHere => 'បន្ថែមសំណើដើម្បីមើលនៅទីនេះ';

  @override
  String get retry => 'ព្យាយាមម្តងទៀត';

  @override
  String get actionTooltipExplore => 'រុករក';

  @override
  String get actionTooltipSettings => 'ការកំណត់';

  @override
  String get languagePickerTitle => 'ជ្រើសរើសភាសា';

  @override
  String get languagePickerSubtitle => 'ជ្រើសរើសភាសាដើម្បីបន្ត';

  @override
  String get languageEnglish => 'អង់គ្លេស';

  @override
  String get languageKhmer => 'ខ្មែរ';

  @override
  String get languageIndonesian => 'ឥណ្ឌូណេស៊ី';

  @override
  String get settingsTitle => 'ការកំណត់';

  @override
  String get settingsLightMode => 'របៀបភ្លឺ';

  @override
  String get settingsDarkMode => 'របៀបងងឹត';

  @override
  String get settingsToggleTheme => 'បិទ/បើករូបរាងកម្មវិធី';

  @override
  String get settingsLanguage => 'ភាសា';

  @override
  String get settingsLanguageSubtitle => 'ប្តូរភាសាកម្មវិធី';

  @override
  String get settingsSignOut => 'ចេញពីគណនី';

  @override
  String get settingsDangerZone => 'តំបន់គ្រោះថ្នាក់';

  @override
  String get settingsDeleteAccount => 'លុបគណនី';

  @override
  String get settingsAccountDeleted => 'គណនីត្រូវបានលុប';

  @override
  String appVersionLabel(String version) {
    return 'កំណែ $version';
  }

  @override
  String get authTitle => 'គណនី';

  @override
  String get authTabLogin => 'ចូល';

  @override
  String get authTabSignUp => 'ចុះឈ្មោះ';

  @override
  String get authEmailLabel => 'អ៊ីមែល';

  @override
  String get authPasswordLabel => 'ពាក្យសម្ងាត់';

  @override
  String get authReenterPasswordLabel => 'បញ្ចូលពាក្យសម្ងាត់ម្តងទៀត';

  @override
  String get authSignIn => 'ចូល';

  @override
  String get authCreateAccount => 'បង្កើតគណនី';

  @override
  String get authEnterEmail => 'សូមបញ្ចូលអ៊ីមែលរបស់អ្នក';

  @override
  String get authEnterPassword => 'សូមបញ្ចូលពាក្យសម្ងាត់';

  @override
  String get authEnterPasswordSignUp => 'សូមបញ្ចូលពាក្យសម្ងាត់';

  @override
  String get authPasswordMinLength =>
      'ពាក្យសម្ងាត់ត្រូវមានយ៉ាងហោចណាស់ ៦ តួអក្សរ';

  @override
  String get authReenterPasswordError => 'សូមបញ្ចូលពាក្យសម្ងាត់ម្តងទៀត';

  @override
  String get authPasswordsDoNotMatch => 'ពាក្យសម្ងាត់មិនត្រូវគ្នា';

  @override
  String get profileContactDetailsTitle => 'ព័ត៌មានទំនាក់ទំនង';

  @override
  String get profileTapToChangePhoto => 'ប៉ះដើម្បីផ្លាស់ប្តូររូប';

  @override
  String get profileAddPhotoRequired => 'បន្ថែមរូបទម្រង់ (ចាំបាច់)';

  @override
  String get profileUploading => 'កំពុងផ្ទុកឡើង...';

  @override
  String get profileDisplayNameLabel => 'ឈ្មោះដែលបង្ហាញ';

  @override
  String get profileDisplayNameHint => 'ឈ្មោះដែលបង្ហាញរបស់អ្នក';

  @override
  String get profileEnterDisplayName => 'សូមបញ្ចូលឈ្មោះដែលបង្ហាញ';

  @override
  String get profileNameMaxLength => 'ឈ្មោះមិនអាចលើស ១០០ តួអក្សរ';

  @override
  String get profileCountryLabel => 'ប្រទេស';

  @override
  String get profileSelectCountry => 'ជ្រើសប្រទេស';

  @override
  String get profileCityLabel => 'ទីក្រុង';

  @override
  String get profileSelectCity => 'ជ្រើសទីក្រុង';

  @override
  String get profileSuburbOptionalLabel => 'តំបន់ជុំវិញ (ស្រេចចិត្ត)';

  @override
  String get profileSuburbHint => 'បញ្ចូលតំបន់ជុំវិញ';

  @override
  String get profileSuburbPickSuggestion => 'ឬជ្រើសពីការណែនាំខាងក្រោម';

  @override
  String get profileSuburbMaxLength => 'តំបន់ជុំវិញមិនអាចលើស ១០០ តួអក្សរ';

  @override
  String get profileSuggestedSuburbsLabel =>
      'តំបន់ជុំវិញដែលបានណែនាំ (ស្រេចចិត្ត)';

  @override
  String get profileSuggestedSuburbsHelper =>
      'ប៉ះដើម្បីបំពេញវាលតំបន់ខាងលើ អ្នកអាចកែបាន';

  @override
  String get profilePickSuggestedSuburb => 'ជ្រើសតំបន់ដែលបានណែនាំ';

  @override
  String get profileChooseAccountType => 'ជ្រើសប្រភេទគណនីរបស់អ្នក';

  @override
  String get profileAccountTypeCanChange =>
      'ប៉ះ សិល្បករសាក់ ឬ អតិថិជន ខាងក្រោម។ អ្នកអាចប្តូរជម្រើសរហូតដល់ចុចរក្សាទុក — បន្ទាប់មក ប្រភេទគណនីនឹងជាក់ស្តែង និងមិនអាចប្តូរបានទៀតទេ។';

  @override
  String get profileAccountTypeLocked =>
      'ប្រភេទគណនីរបស់អ្នកត្រូវបានកំណត់ ហើយមិនអាចប្តូរបានទេ។';

  @override
  String get profileTattooArtistTitle => 'សិល្បករសាក់';

  @override
  String get profileTattooArtistSubtitle =>
      'ដេញថ្លៃការងារ និងភ្ជាប់ជាមួយអតិថិជន';

  @override
  String get profileCustomerTitle => 'អតិថិជន';

  @override
  String get profileCustomerSubtitle => 'ប្រកាសការងារសាក់ និងជួលសិល្បករ';

  @override
  String get profilePortfolioTitle => 'ផតហ្វូលីយ៉ូ';

  @override
  String profilePortfolioBlurb(int max) {
    return 'បន្ថែមរូបភាពរហូតដល់ $max សម្រាប់ប្រូហ៊ីនសិល្បករសាធារណៈរបស់អ្នក។';
  }

  @override
  String profileAddImageButton(int current, int max) {
    return 'បន្ថែមរូប ($current/$max)';
  }

  @override
  String profilePortfolioLimitSnackbar(int remaining, int max) {
    return 'អាចបន្ថែមបានតែ $remaining រូបទៀតប៉ុណ្ណោះ (អតិបរមា $max)។';
  }

  @override
  String get profileContactSectionTitle => 'ទំនាក់ទំនង';

  @override
  String get profileContactHelpArtist =>
      'អ៊ីមែល និងទូរស័ព្ទចាំបាច់។ បង្ហាញដល់អតិថិជនបន្ទាប់ពីឈ្នះដេញថ្លៃ។';

  @override
  String get profileContactHelpCustomer => 'អ៊ីមែល និងទូរស័ព្ទចាំបាច់។';

  @override
  String get profileContactHelpNone =>
      'អ៊ីមែល និងទូរស័ព្ទចាំបាច់។ សូមជ្រើសប្រភេទគណនីខាងលើជាមុនសិន។';

  @override
  String get profileEmailLabel => 'អាសយដ្ឋានអ៊ីមែល';

  @override
  String get profileEmailHint => 'អ៊ីមែលរបស់អ្នក@ឧទាហរណ៍.com';

  @override
  String get profileEnterEmail => 'សូមបញ្ចូលអាសយដ្ឋានអ៊ីមែល';

  @override
  String get profileEnterValidEmail => 'សូមបញ្ចូលអ៊ីមែលត្រឹមត្រូវ';

  @override
  String get profileMobileLabel => 'លេខទូរស័ព្ទ';

  @override
  String get profileMobileHint => 'លេខទូរស័ព្ទរបស់អ្នក';

  @override
  String get profileEnterMobile => 'សូមបញ្ចូលលេខទូរស័ព្ទ';

  @override
  String get profileMobileMaxLength => 'អតិបរមា ៤០ តួអក្សរ';

  @override
  String get profileSave => 'រក្សាទុក';

  @override
  String get profileSelectUserTypeError => 'សូមជ្រើសសិល្បករសាក់ ឬ អតិថិជន';

  @override
  String get profilePhotoRequiredError => 'សូមបន្ថែមរូបទម្រង់មុនរក្សាទុក។';

  @override
  String get profileCameraPermissionRequired =>
      'ត្រូវការការអនុញ្ញាតកាមេរ៉ាដើម្បីថតរូប។';

  @override
  String get profileAvatarUploadDenied =>
      'ការផ្ទុករូបទម្រង់បរាជ័យ។ សូមធានាថាធុង \"avatars\" មាន និងសាធារណៈនៅ Supabase Dashboard → Storage។';

  @override
  String get profileAccountTypeLockedSnackbar =>
      'មិនអាចប្តូរប្រភេទគណនីបន្ទាប់ពីរក្សាទុករួចទេ។';

  @override
  String get profileEditContact => 'កែព័ត៌មានទំនាក់ទំនង';

  @override
  String get profileNotLoggedIn => 'មិនបានចូល';

  @override
  String get bidDetailTitle => 'ព័ត៌មានស្នើសុំ';

  @override
  String bidDetailStartingBid(String amount) {
    return '$amount ដេញថ្លៃចាប់ផ្តើម';
  }

  @override
  String get bidDetailHideDescription => 'លាក់ការពិពណ៌នា';

  @override
  String get bidDetailWhatCustomerWants => 'តើអតិថិជនចង់បានអ្វី?';

  @override
  String get bidDetailPlacement => 'ទីតាំង';

  @override
  String get bidDetailSize => 'ទំហំ';

  @override
  String get bidDetailColour => 'ពណ៌';

  @override
  String get bidDetailColourFull => 'ពណ៌';

  @override
  String get bidDetailColourBlackGrey => 'ខ្មៅ និងប្រផេះ';

  @override
  String get bidDetailTimeFrame => 'រយៈពេល';

  @override
  String get bidDetailTimeframeAsap => 'ឆាប់តាមដែលអាច';

  @override
  String get bidDetailTimeframeWeek => 'ក្នុងសប្តាហ៍';

  @override
  String get bidDetailTimeframeFlexible => 'ពេលណាក៏បានដែលអាចកក់បាន';

  @override
  String get bidDetailArtistCreativeFreedom => 'សិល្បករមានសេរីភាពច្នៃប្រឌិត';

  @override
  String get bidDetailNoDescription => 'មិនមានការពិពណ៌នា។';

  @override
  String get bidDetailBids => 'ការដេញថ្លៃ';

  @override
  String get bidDetailArtistToolsNotBidHint =>
      'ឧបករណ៍សិល្បករ — មិនចាប់ផ្តើមដេញថ្លៃពីប៊ូតុងនេះទេ។';

  @override
  String get bidDetailOnlyArtistsMayBid =>
      'មានតែសិល្បករសាក់ប៉ុណ្ណោះដែលអាចដេញថ្លៃលើស្នើសុំ។';

  @override
  String get bidDetailBiddingClosedMessage =>
      'ការដេញថ្លៃបានបិទ។ ស្នើសុំនេះមិនទទួលការដេញថ្លៃថ្មីទៀតទេ។';

  @override
  String get bidDetailViewArtistTools => 'មើលឧបករណ៍សិល្បករ';

  @override
  String get bidDetailBid => 'ដេញថ្លៃ';

  @override
  String get bidDetailCouldNotLoadBids => 'មិនអាចផ្ទុកការដេញថ្លៃ';

  @override
  String get bidDetailNoBidsYet => 'មិនទាន់មានការដេញថ្លៃ';

  @override
  String get bidDetailLowest => 'ទាបបំផុត';

  @override
  String get bidDetailArtistNameFallback => 'សិល្បករ';

  @override
  String get bidDetailChooseArtist => 'ជ្រើសសិល្បករ';

  @override
  String get bidDetailPaid => 'បានបង់';

  @override
  String get bidDetailUnlockContact => 'ដោះសោទំនាក់ទំនង';

  @override
  String get bidDetailSectionArtistContact => 'ទំនាក់ទំនងសិល្បករ';

  @override
  String get bidDetailSectionDeposit => 'កក់ប្រាក់';

  @override
  String get bidDetailSectionConnect => 'ភ្ជាប់';

  @override
  String get bidDetailPaymentCompleteBody =>
      'ការទូទាត់ត្រូវបានចំណាយរួច។ បើទំនាក់ទំនងនៅតែជាប់សោ សូមធ្វើរីហ្វ្រេស — ការដោះសោររបស់អ្នកត្រូវបានរក្សាទុកបន្ទាប់ពី Stripe បញ្ជាក់។';

  @override
  String get bidDetailRefreshUnlockStatus => 'ធ្វើរីហ្វ្រេសស្ថានភាពដោះសោ';

  @override
  String get bidDetailChooseWinningBidForDeposit =>
      'ជ្រើសការដេញថ្លៃឈ្នះដើម្បីមើលកក់ប្រាក់។';

  @override
  String get bidDetailChooseWinningBidToConnect =>
      'ជ្រើសការដេញថ្លៃឈ្នះដើម្បីភ្ជាប់ជាមួយសិល្បកររបស់អ្នក។';

  @override
  String get bidDetailChooseWinningBidToChat =>
      'ជ្រើសការដេញថ្លៃឈ្នះខាងលើ។ អ្នកអាចជជែកជាមួយសិល្បកររបស់អ្នកភ្លាមៗ។';

  @override
  String bidDetailPhoneLine(String phone) {
    return 'ទូរស័ព្ទ៖ $phone';
  }

  @override
  String bidDetailEmailLine(String email) {
    return 'អ៊ីមែល៖ $email';
  }

  @override
  String get bidDetailChat => 'ជជែក';

  @override
  String bidDetailTotalPriceLine(String amount) {
    return 'តម្លៃសរុប៖ $amount';
  }

  @override
  String bidDetailDepositLine(int percent, String amount) {
    return 'កក់ប្រាក់ ($percent%)៖ $amount';
  }

  @override
  String bidDetailRemainingLine(int percent, String amount) {
    return 'នៅសល់ ($percent%)៖ $amount';
  }

  @override
  String bidDetailPayDepositUnlock(int percent) {
    return 'បង់កក់ $percent% និងដោះសោសិល្បករ';
  }

  @override
  String get bidDetailPlaceBidTitle => 'ដាក់ការដេញថ្លៃ';

  @override
  String get bidDetailYourPriceLabel => 'តម្លៃរបស់អ្នក (\$)';

  @override
  String get bidDetailEnterValidBidAmount =>
      'សូមបញ្ចូលចំនួនត្រឹមត្រូវ (០ ឬច្រើនជាង)';

  @override
  String get bidDetailCancel => 'បោះបង់';

  @override
  String get bidDetailSubmit => 'ដាក់ស្នើ';

  @override
  String get bidDetailArtistToolsSheetTitle => 'ឧបករណ៍សិល្បករ';

  @override
  String get bidDetailArtistToolsSheetBody =>
      'សកម្មភាពសិល្បករបន្ថែមសម្រាប់ការងារនេះនឹងបង្ហាញនៅទីនេះ។ នេះមិនដាក់ការដេញថ្លៃទេ។';

  @override
  String get bidDetailCouldNotOpenProfile => 'មិនអាចបើកប្រវត្តិរូបនេះ។';

  @override
  String get bidDetailRequestAlreadyCompleted => 'ស្នើសុំនេះបានបញ្ចប់រួចហើយ។';

  @override
  String bidDetailCouldNotUnlockContactDetails(String details) {
    return 'មិនអាចដោះសោទំនាក់ទំនង៖ $details';
  }

  @override
  String bidDetailCouldNotSelectBidDetails(String details) {
    return 'មិនអាចជ្រើសការដេញថ្លៃ៖ $details';
  }

  @override
  String get bidDetailTapChooseArtistHint =>
      'ប៉ះជ្រើសសិល្បករលើការដេញថ្លៃដើម្បីភ្ជាប់ជាមួយសិល្បកររបស់អ្នក។';

  @override
  String get bidDetailPaymentAlreadyCompleted =>
      'ការទូទាត់សម្រាប់ស្នើសុំនេះបានបញ្ចប់រួចហើយ។';

  @override
  String get bidDetailMissingArtistForBid =>
      'គ្មានសិល្បករសម្រាប់ការដេញថ្លៃនេះ។';

  @override
  String bidDetailPaymentFailedDetails(String details) {
    return 'ការទូទាត់បរាជ័យ៖ $details';
  }

  @override
  String get bidDetailCouldNotFindBidToPay => 'រកមិនឃើញការដេញថ្លៃនោះដើម្បីបង់';

  @override
  String get bidDetailOnlyCustomerCanPay => 'មានតែអតិថិជនប៉ុណ្ណោះដែលអាចបង់';

  @override
  String get bidDetailCannotPlaceBid =>
      'អ្នកមិនអាចដាក់ការដេញថ្លៃលើស្នើសុំនេះទេ។';

  @override
  String get bidDetailBiddingClosedSnackbar =>
      'ការដេញថ្លៃបានបិទសម្រាប់ស្នើសុំនេះ។';

  @override
  String get bidDetailBidPlaced => 'បានដាក់ការដេញថ្លៃ';

  @override
  String bidDetailFailedPlaceBidDetails(String details) {
    return 'ដាក់ការដេញថ្លៃបរាជ័យ៖ $details';
  }
}
