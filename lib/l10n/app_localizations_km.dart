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
  String get tabTattsagram => 'Flexemo™';

  @override
  String get tabUpload => 'ដាក់តម្លៃ';

  @override
  String get tabPromo => 'ផ្សព្វផ្សាយ';

  @override
  String get addPromoTitle => 'Promo';

  @override
  String get addPromoFieldDescriptionLabel => 'ពណ៌នាសាក់នេះ';

  @override
  String get addPromoStartingBidLabel => 'សាក់នេះ (\$)';

  @override
  String get addPromoNextAvailabilityLabel => 'ភាពអាចប្រើបាន';

  @override
  String get addPromoNextAvailabilityHint => 'ឧ. សប្តាហ៍ក្រោយ, 15 មិថុនា';

  @override
  String get addPromoChatButton => 'ជជែក';

  @override
  String get tabMessage => 'សារ';

  @override
  String get tabProfile => 'ប្រវត្តិរូប';

  @override
  String get tattsagramEmptyTitle => 'មិនទាន់មានសាក់នៅឡើយ';

  @override
  String get tattsagramEmptySubtitle => 'ក្លាយជាអ្នកដំបូងដែលបង្ហាញសាក់របស់អ្នក';

  @override
  String get tattsagramFabShowTattoo => 'បង្ហាញសាក់របស់អ្នក';

  @override
  String get dashboardTitle => 'ផ្ទាំងគ្រប់គ្រង';

  @override
  String get dashboardPlaceholderBody => 'ទំព័រផ្ទាំងគ្រប់គ្រង';

  @override
  String get exploreTitle => 'រុករក';

  @override
  String get exploreSearchHint => 'ឈ្មោះ ទីក្រុង សង្កាត់...';

  @override
  String get exploreBidsNearMe => 'ដេញថ្លៃនៅក្បែរខ្ញុំ';

  @override
  String get exploreNearMeNeedProfile =>
      'បន្ថែមទីក្រុង ឬសង្កាត់ក្នុងប្រវត្តិរូបដើម្បីប្រើដេញថ្លៃនៅក្បែរខ្ញុំ។';

  @override
  String get exploreNoSearchResults => 'គ្មានប្រកាសដែលត្រូវគ្នា';

  @override
  String exploreArtistsInterested(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'សិល្បករ $count នាក់ចាប់អារម្មណ៍',
      one: 'សិល្បករ 1 នាក់ចាប់អារម្មណ៍',
    );
    return '$_temp0';
  }

  @override
  String exploreCustomersInterested(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'អតិថិជន $count នាក់ចាប់អារម្មណ៍',
      one: 'អតិថិជន 1 នាក់ចាប់អារម្មណ៍',
    );
    return '$_temp0';
  }

  @override
  String exploreReviewCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ការវាយតម្លៃ',
      one: '1 ការវាយតម្លៃ',
    );
    return '($_temp0)';
  }

  @override
  String exploreBidBudget(String amount) {
    return 'ថវិកា $amount';
  }

  @override
  String explorePromoPrice(String amount) {
    return 'សាក់នេះ $amount';
  }

  @override
  String get exploreBidCardTitleFallback => 'ស្នើសុំសាក់';

  @override
  String get explorePostedToday => 'បានប្រកាសថ្ងៃនេះ';

  @override
  String explorePostedHoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'បានប្រកាស $count ម៉ោងមុន',
      one: 'បានប្រកាស 1 ម៉ោងមុន',
    );
    return '$_temp0';
  }

  @override
  String explorePostedDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'បានប្រកាស $count ថ្ងៃមុន',
      one: 'បានប្រកាស 1 ថ្ងៃមុន',
    );
    return '$_temp0';
  }

  @override
  String exploreTitleWithCountry(String country) {
    return 'រុករក - $country';
  }

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
  String get addPostCountryMismatchTitle => 'មិនអាចប្រកាសនៅទីនេះ';

  @override
  String addPostCountryMismatchBody(String targetCountry) {
    return 'អ្នកប្រកាសបានតែសម្រាប់ប្រទេសដែលអ្នករស់នៅប៉ុណ្ណោះ។ ប្រទេសក្នុងប្រវត្តិរូបរបស់អ្នកមិនត្រូវនឹង $targetCountry ទេ។ សូមធ្វើបច្ចុប្បន្នភាពកន្លែងរស់នៅក្នុងប្រវត្តិរូប។';
  }

  @override
  String get addPostCountryMissingTitle => 'ត្រូវការប្រទេស';

  @override
  String get addPostCountryMissingBody =>
      'បន្ថែមប្រទេសដែលអ្នករស់នៅក្នុងប្រវត្តិរូបមុនពេលប្រកាសសំណើ។';

  @override
  String get addPostCountryMismatchOk => 'យល់ព្រម';

  @override
  String get addPostNeedDestinationTitle => 'ជ្រើសប្រទេសជាមុន';

  @override
  String get addPostNeedDestinationBody =>
      'ជ្រើសប្រទេសពីរូបភពនៅទំព័ររុករកមុនពេលប្រកាស។';

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
  String get deleteAccountTitle => 'លុបគណនី';

  @override
  String get deleteAccountWarningTitle => 'សកម្មភាពនេះមិនអាចត្រឡប់វិញបានទេ';

  @override
  String get deleteAccountWarningBody =>
      'ការលុបគណនីរបស់អ្នកនឹងលុបជម្រះអចិន្ត្រៃយ៍នូវប្រវត្តិរូប ការបង្ហោះសាក់ ការដេញដំណឹង ប្រូម៉ូ សារ ការវាយតម្លៃ រូបភាព និងទិន្នន័យផ្សេងទៀតទាំងអស់ដែលភ្ជាប់ទៅគណនីរបស់អ្នក។ មិនអាចស្តារវិញបានទេ។';

  @override
  String get deleteAccountTypePrompt => 'វាយ DELETE ដើម្បីបញ្ជាក់';

  @override
  String get deleteAccountTypeHint => 'DELETE';

  @override
  String get deleteAccountConfirmButton =>
      'លុបគណនីរបស់ខ្ញុំជាមួយនឹងការលុបជម្រះ';

  @override
  String get deleteAccountDeleting => 'កំពុងលុបគណនីរបស់អ្នក…';

  @override
  String get accountDeletionSuccessMessage =>
      'គណនីរបស់អ្នកត្រូវបានលុបជម្រះអចិន្ត្រៃយ៍។ សូមអរគុណដែលបានប្រើ TattsBid។';

  @override
  String get settingsAccountDeleted => 'គណនីត្រូវបានលុប';

  @override
  String settingsAccountDeleteFailed(String reason) {
    return 'មិនអាចលុបគណនីបានទេ។ $reason';
  }

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
  String get profileCountryLockedByPostsBody =>
      'អ្នកនៅតែមានសំណើសាក់ដែលបានប្រកាស។ លុបពី Explore មុនពេលអាចផ្លាស់ប្តូរប្រទេស។';

  @override
  String get profileCountryChangeBlockedError =>
      'លុបសំណើដែលបានប្រកាសមុនពេលអាចផ្លាស់ប្តូរប្រទេស។';

  @override
  String get profileDisplayNameLockedHelper =>
      'មិនអាចផ្លាស់ប្តូរឈ្មោះដែលបង្ហាញបន្ទាប់ពីបានកំណត់រួចទេ។';

  @override
  String get profileDisplayNameImmutableError =>
      'ឈ្មោះដែលបង្ហាញរបស់អ្នកមិនអាចផ្លាស់ប្តូរបានទេ។';

  @override
  String get profileDisplayNameTakenError =>
      'ឈ្មោះដែលបង្ហាញនេះមានគេប្រើរួចហើយ។ សាកលើកផ្សេង។';

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
  String get profileAccountTypeConfirmTitle => 'បញ្ជាក់ប្រភេទគណនី';

  @override
  String profileAccountTypeConfirmBody(String accountType) {
    return 'តើអ្នកពិតជាចង់ចុះឈ្មោះជា $accountType ឬ?\n\nជម្រើសនេះប៉ះពាល់ដល់របៀបអ្នកធ្វើការជាមួយអ្នកប្រើផ្សេងទៀត។ មិនអាចប្តូរបានទៀតហើយបន្ទាប់ពីរក្សាទុក។ សូមជ្រើសឱ្យបានត្រឹមត្រូវ។';
  }

  @override
  String get profileAccountTypeConfirmCancel => 'ត្រឡប់ក្រោយ';

  @override
  String get profileAccountTypeConfirmContinue => 'បាទ/ចាស បន្ត';

  @override
  String get profileTattooArtistTitle => 'សិល្បករសាក់';

  @override
  String get profileTattooArtistSubtitle =>
      'ដាក់ស្នើដេញថ្លៃដើម្បីផ្សព្វផ្សាយជំនាញសិល្បៈ និងដេញថ្លៃការងារ';

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
  String get bidDetailAppBarHomeTooltip => 'ទំព័រដើម';

  @override
  String bidDetailStartingBid(String amount) {
    return '$amount ដេញថ្លៃចាប់ផ្តើម';
  }

  @override
  String get bidDetailHideDescription => 'លាក់ការពិពណ៌នា';

  @override
  String get bidDetailWhatCustomerWants => 'តើអតិថិជនចង់បានអ្វី?';

  @override
  String get bidDetailAboutThisTattoo => 'អំពីសាក់នេះ';

  @override
  String get bidDetailChatToThisArtist => 'ជជែកទៅសិល្បករនេះ';

  @override
  String get bidDetailPlacement => 'ទីតាំង';

  @override
  String get bidDetailNextAvailability => 'ភាពអាចប្រើបាន';

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
  String get bidDetailBidCountryRequestMissingHint =>
      'សំណើនេះមិនមានប្រទេស។ អ្នកមិនអាចដាក់ការដេញថ្លៃបានទេ។';

  @override
  String get bidDetailBidCountryProfileMissingHint =>
      'ប្រវត្តិរូបរបស់អ្នកមិនទាន់រក្សាទុកប្រទេសទេ។ ចូលទៅ ប្រវត្តិរូប → ព័ត៌មានទំនាក់ទំនង ជ្រើសប្រទេស ចុចរក្សាទុក រួចសាកម្តងទៀត។';

  @override
  String bidDetailBidCountryMismatchHint(
      String requestCountry, String profileCountry) {
    return 'អ្នកដេញថ្លៃបានតែលើសំណើនៅប្រទេសរបស់អ្នកប៉ុណ្ណោះ។ ការងានេះនៅ $requestCountry; ប្រទេសក្នុងប្រវត្តិរូបរបស់អ្នកគឺ $profileCountry។';
  }

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
      'ផ្សព្វផ្សាយការងាររបស់អ្នកនៅ Explore ខណៈរង់ចាំអតិថិជនពិនិត្យការដេញថ្លៃ។';

  @override
  String get bidDetailArtistToolsPostPromo => 'ផ្សាយប្រូម៉ូ';

  @override
  String get bidDetailPostPromoTitle => 'ផ្សាយប្រូម៉ូ?';

  @override
  String get bidDetailPostPromoMessage =>
      'ចែករំលែកការងារស្បែករបស់អ្នកនៅ Explore ដើម្បីឱ្យអតិថិជនឃើញរចនាបថរបស់អ្នកជាមួយការដេញថ្លៃ។';

  @override
  String get bidDetailPostPromoOpen => 'បើកទំព័រប្រូម៉ូ';

  @override
  String get bidDetailPostPromoLater => 'មិនទាន់';

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

  @override
  String get photoTakePhoto => 'ថតរូប';

  @override
  String get photoFromGallery => 'ផ្ទុកពីវិចិត្រសាល';

  @override
  String get tattsagramPhotoSharedInChat => '📷 រូបភាព';

  @override
  String get tattsagramUploadingPhoto => 'កំពុងផ្ទុករូបភាព…';

  @override
  String get tattsagramPhotoUploadFailed =>
      'មិនអាចផ្ទុកមេឌាបានទេ។ ចូលគណនីហើយព្យាយាមម្តងទៀត។';

  @override
  String get destinationChooseTitle => 'ជ្រើសគោលដៅ';

  @override
  String get destinationComingSoon => 'មកដល់ឆាប់ៗ';

  @override
  String get addTabTitle => 'បន្ថែម';

  @override
  String get addUploading => 'កំពុងផ្ទុក...';

  @override
  String get addPhotoButton => 'បន្ថែមរូប';

  @override
  String get addHappyAddDetails => 'ខ្ញុំពេញចិត្ត — បន្ថែមព័ត៌មានលម្អិត';

  @override
  String get addChooseDifferentPhoto => 'ជ្រើសរូបផ្សេង';

  @override
  String get addDescriptionHint => 'ពណ៌នាការចង់បានរបស់អ្នក...';

  @override
  String get addPlacementHint => 'នៅផ្នែកណារបស់ខ្លួន? (ឧ. ដៃ ខ្នង ជើង)';

  @override
  String get addSizeHint => 'តូច មធ្យម ធំ ឬទំហំ';

  @override
  String get addColourChip => 'ពណ៌';

  @override
  String get addBlackGreyChip => 'ខ្មៅ និងប្រផេះ';

  @override
  String get addTimeAsap => 'ឆាប់ៗ';

  @override
  String get addTimeWeek => 'ក្នុងសប្តាហ៍';

  @override
  String get addTimeBookWhen => 'នៅពេលអាចកក់ខ្ញុំបាន';

  @override
  String get addBidAmountHint => '0';

  @override
  String get addSubmitRequest => 'ដាក់ស្នើសំណើ';

  @override
  String get addBackButton => 'ត្រឡប់';

  @override
  String get addAnotherRequest => 'បន្ថែមសំណើផ្សេង';

  @override
  String get artistsDirectorySearchHint => 'ឈ្មោះ ទីក្រុង សង្កាត់ ឬប្រទេស';

  @override
  String get artistsFilterRating => 'ពិន្ទុ';

  @override
  String get artistsFilterCleanliness => 'អនាម័យ';

  @override
  String exploreDeleteFailedDetails(String details) {
    return 'លុបបរាជ័យ៖ $details';
  }

  @override
  String get exploreDeletePostTitle => 'លុបការផ្សាយ?';

  @override
  String get exploreDeletePostMessage =>
      'ការផ្សាយនេះនឹងត្រូវលុបចេញពី Explore ជាអចិន្ត្រៃយ៍។';

  @override
  String get exploreDeletePostConfirm => 'លុប';

  @override
  String get exploreDeletePostCancel => 'បោះបង់';

  @override
  String get checkoutTitle => 'Checkout';

  @override
  String get checkoutContinue => 'បន្ត';

  @override
  String get checkoutCancelledMessage => 'Checkout ត្រូវបានលុបចោល។';

  @override
  String get checkoutTryAgain => 'ព្យាយាមម្តងទៀត';

  @override
  String get checkoutBackToDashboard => 'ត្រឡប់ទៅផ្ទាំងគ្រប់គ្រង';

  @override
  String get depositSummaryTitle => 'សង្ខេបកក់ប្រាក់';

  @override
  String depositTotalCostLine(String amount) {
    return 'ថ្លៃសរុប៖ $amount';
  }

  @override
  String depositArtistReceivesLine(String amount) {
    return 'សិល្បករទទួល៖ $amount';
  }

  @override
  String get depositPayButton => 'បង់';

  @override
  String depositFeePercentLine(int percent, String amount) {
    return 'ថ្លៃកក់ ($percent%): $amount';
  }

  @override
  String platformFeePaymentFailed(String error) {
    return 'ការទូទាត់បរាជ័យ៖ $error';
  }

  @override
  String get cameraTitle => 'កាមេរ៉ា';

  @override
  String cameraSwitchError(String error) {
    return 'មិនអាចប្តូរកាមេរ៉ា៖ $error';
  }

  @override
  String cameraCaptureError(String error) {
    return 'ថតរូបបរាជ័យ៖ $error';
  }

  @override
  String get cameraNoDeviceAvailable => 'មិនមានកាមេរ៉ានៅលើឧបករណ៍នេះទេ។';

  @override
  String cameraInitFailed(String error) {
    return 'ចាប់ផ្តើមកាមេរ៉ាបរាជ័យ៖ $error';
  }

  @override
  String get bidPageTitle => 'ដេញថ្លៃ';

  @override
  String get paywallSubscribeTitle => 'ជាវ';

  @override
  String get paywallSubscribeMonthly => 'ជាវប្រចាំខែ';

  @override
  String get paywallFreePlanTitle => 'កំណែឥតគិតថ្លៃ';

  @override
  String get paywallProPlanTitle => 'កំណែ Pro';

  @override
  String get paywallProMaxPlanTitle => 'Pro Max';

  @override
  String get paywallProPlanSubtitle => '99¢ AUD ក្នុងមួយខែ';

  @override
  String get paywallProMaxPlanSubtitle => '\$1.00 AUD ក្នុងមួយខែ';

  @override
  String get welcomeGetStarted => 'ចាប់ផ្តើម';

  @override
  String get welcomeSkip => 'រំលង';

  @override
  String get editContactEmailHint => 'អ៊ីមែលទំនាក់ទំនងរបស់អ្នក';

  @override
  String get editContactPhoneHint => 'លេខទូរស័ព្ទរបស់អ្នក';

  @override
  String get publicProfileCantChatSelf => 'អ្នកមិនអាចជជែកជាមួយខ្លួនឯងបានទេ។';

  @override
  String get publicProfileReviewCommentRequired => 'សូមសរសេរមតិ។';

  @override
  String get publicProfileReviewSubmitError =>
      'មិនអាចដាក់ស្នើការវាយតម្លៃឥឡូវនេះ។ សូមព្យាយាមម្តងទៀត។';

  @override
  String get publicProfileChatButton => 'ជជែក';

  @override
  String get publicProfileChatWithArtist => 'ជជែកជាមួយសិល្បករ';

  @override
  String get publicProfileReviewHint => 'ចែករំលែកបទពិសោធន៍របស់អ្នក…';

  @override
  String get publicProfileSubmitReview => 'ដាក់ស្នើការវាយតម្លៃ';

  @override
  String get publicProfileEmailTitle => 'អ៊ីមែល';

  @override
  String get publicProfileMobileTitle => 'ទូរស័ព្ទ';

  @override
  String get publicProfileTitleFallback => 'ប្រូហ្វាល់';

  @override
  String get publicProfileReviewSelectBoth =>
      'សូមជ្រើសពិន្ទុ និងអនាម័យ (ផ្កាយ ១–៥ ម្យ៉ាងៗ)។';

  @override
  String get publicProfileReviewPostedThanks =>
      'អរគុណ — ការវាយតម្លៃរបស់អ្នកត្រូវបានបង្ហោះ។';

  @override
  String get publicProfileReviewUpdated =>
      'អ្នកបានវាយតម្លៃសិល្បករនេះរួចហើយ។ ការវាយតម្លៃត្រូវបានធ្វើបច្ចុប្បន្នភាព។';

  @override
  String get publicProfileReviewAlreadyReviewedShort =>
      'អ្នកបានវាយតម្លៃសិល្បករនេះរួចហើយ';

  @override
  String get publicProfileReviewsHeading => 'ការវាយតម្លៃ';

  @override
  String get publicProfileNoReviewsYet => 'មិនទាន់មានការវាយតម្លៃ។';

  @override
  String get publicProfilePreviousReviews => 'ការវាយតម្លៃមុន';

  @override
  String publicProfileReviewsTileSubtitle(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ការវាយតម្លៃ · ចុចដើម្បីពង្រីក',
      one: '$count ការវាយតម្លៃ · ចុចដើម្បីពង្រីក',
    );
    return '$_temp0';
  }

  @override
  String get publicProfileWriteReview => 'សរសេរការវាយតម្លៃ';

  @override
  String get publicProfileEditReview => 'កែការវាយតម្លៃរបស់អ្នក';

  @override
  String get publicProfileNoContactOnFile => 'មិនមានព័ត៌មានទំនាក់ទំនង។';

  @override
  String chatSendFailed(String error) {
    return 'ផ្ញើបរាជ័យ៖ $error';
  }

  @override
  String get chatMessageHint => 'សារ (ឯកជន)';

  @override
  String get chatMessageArtist => 'សារសិល្បករ';

  @override
  String chatMobileLine(String phone) {
    return 'ទូរស័ព្ទ៖ $phone';
  }

  @override
  String chatEmailLine(String email) {
    return 'អ៊ីមែល៖ $email';
  }

  @override
  String get chatInboxTitle => 'សារ';

  @override
  String get chatPartnerFallbackTitle => 'ជជែក';

  @override
  String get chatPrivacyNotice =>
      'សាររវាងសិល្បករសាក់ និងអតិថិជនប៉ុណ្ណោះ។ មានតែអ្នក និងមនុស្សនេះទេដែលឃើញសារទាំងនេះ។';

  @override
  String get chatContactSectionTitle => 'ទំនាក់ទំនង';

  @override
  String get chatSetupRequired =>
      'ត្រូវការដំឡើងជជែក។ ដំណើរការ migration នៅ supabase/apply_chat_messages.sql ក្នុង Supabase Dashboard (SQL Editor) រួចចុចព្យាយាមម្តងទៀត។';

  @override
  String get chatEmptyConversation =>
      'មិនទាន់មានសារ។ សួស្តី — ការសន្ទនានេះមានតែអ្នក និងភាគីម្ខាងទៀតឃើញ។';

  @override
  String get chatYourArtist => 'សិល្បកររបស់អ្នក';

  @override
  String chatPhoneLine(String phone) {
    return 'ទូរស័ព្ទ៖ $phone';
  }

  @override
  String get chatNoContactYet => 'មិនទាន់មានទូរស័ព្ទ ឬអ៊ីមែល។';

  @override
  String get chatUnknownUser => 'អ្នកប្រើ';

  @override
  String get chatInboxEmptyTitle => 'មិនទាន់មានការសន្ទនា';

  @override
  String get chatInboxEmptyBody =>
      'ចាប់ផ្តើមជជែកពីទំព័រព័ត៌មានលម្អិតការងារ ឬប្រូម៉ូ — ការសន្ទនារបស់អ្នកជាមួយសិល្បករ និងអតិថិជននឹងបង្ហាញនៅទីនេះ។';

  @override
  String get chatInboxUnlockTitle => 'បង់ដើម្បីដោះសោការផ្ញើសារ';

  @override
  String get chatInboxUnlockBody =>
      'បញ្ចប់ការកក់ប្រាក់ពីការដេញថ្លៃឈ្នះនៃសំណើរបស់អ្នក ដើម្បីដោះសោទំនាក់ទំនងសិល្បករ និងការជជែក។';

  @override
  String get chatPaidArtistBlurbLong =>
      'បានបង់ប្រាក់កក់ — អ្នកអាចសារសិល្បករ ឬប្រើព័ត៌មានទំនាក់ទំនងរបស់ពួកគេខាងក្រោម។';

  @override
  String get chatPaidArtistBlurbShort =>
      'បានបង់ប្រាក់កក់ — សារសិល្បករ ឬប្រើព័ត៌មានទំនាក់ទំនងរបស់ពួកគេ។';

  @override
  String get chatConversationsSection => 'ការសន្ទនា';

  @override
  String get reviewRatingLabel => 'ពិន្ទុ';

  @override
  String get reviewCleanlinessLabel => 'អនាម័យ';

  @override
  String get userAgreementTitle => 'កិច្ចព្រមព្រៀងអ្នកប្រើ TattsBid';

  @override
  String get userAgreementAcceptTerms => 'ខ្ញុំយល់ព្រមតាមលក្ខខណ្ឌ TattsBid';

  @override
  String get userAgreementContinue => 'បន្ត';

  @override
  String userAgreementSaveError(String error) {
    return 'មិនអាចរក្សាកិច្ចព្រមព្រៀង៖ $error';
  }

  @override
  String get addReferencePhotoTitle => 'បន្ថែមរូបយោង';

  @override
  String get addReferencePhotoSubtitle => 'ថតរូប ឬជ្រើសពីវិចិត្រសាល';

  @override
  String get addPhotoUploadedTitle => 'ផ្ទុករូបដោយជោគជ័យ';

  @override
  String get addPhotoUploadedSubtitle =>
      'ពេញចិត្តរូបនេះទេ? បន្ថែមពិពណ៌នានិងការដេញថ្លៃដំបូង។';

  @override
  String get addDescriptionSectionTitle => 'ពិពណ៌នា';

  @override
  String get addFieldDescriptionLabel => 'តើអ្នកចង់បានអ្វីសម្រាប់សាក់?';

  @override
  String get addFieldPlacementLabel => 'ទីតាំង';

  @override
  String get addFieldSizeLabel => 'ទំហំ';

  @override
  String get addSectionColourTitle => 'ពណ៌ ឬខ្មៅ និងប្រផេះ';

  @override
  String get addSectionTimeframeTitle => 'រយៈពេល';

  @override
  String get addCreativeFreedomTitle => 'អនុញ្ញាតឲ្យសិល្បករបង្កើតដោយសេរី';

  @override
  String get addStartingBidLabel => 'ការដេញថ្លៃដំបូង (\$)';

  @override
  String get addInvalidBidAmount => 'បញ្ចូលចំនួនត្រឹមត្រូវ (០ ឬច្រើនជាង)';

  @override
  String get addSubmittedTitle => 'បានដាក់ស្នើសំណើ!';

  @override
  String get addSubmittedSubtitle =>
      'សិល្បករអាចមើលសំណើរបស់អ្នក និងដាក់ការដេញថ្លៃ។';

  @override
  String get artistsNearMeButton => 'សិល្បករនៅក្បែរខ្ញុំ';

  @override
  String artistsShowingInLocation(String location) {
    return 'បង្ហាញសិល្បករនៅ $location';
  }

  @override
  String get artistsClearSearchTooltip => 'លុបការស្វែងរក';
}
