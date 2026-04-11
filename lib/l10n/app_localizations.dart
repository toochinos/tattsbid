import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_id.dart';
import 'app_localizations_km.dart';

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
    Locale('id'),
    Locale('km')
  ];

  /// No description provided for @tabExplore.
  ///
  /// In en, this message translates to:
  /// **'Explore'**
  String get tabExplore;

  /// No description provided for @tabArtists.
  ///
  /// In en, this message translates to:
  /// **'Artists'**
  String get tabArtists;

  /// No description provided for @tabTattsagram.
  ///
  /// In en, this message translates to:
  /// **'Tattsagram'**
  String get tabTattsagram;

  /// No description provided for @tabUpload.
  ///
  /// In en, this message translates to:
  /// **'Upload'**
  String get tabUpload;

  /// No description provided for @tabMessage.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get tabMessage;

  /// No description provided for @tabProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get tabProfile;

  /// No description provided for @tattsagramEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No tattoos yet'**
  String get tattsagramEmptyTitle;

  /// No description provided for @tattsagramEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Be the first to show your tattoo'**
  String get tattsagramEmptySubtitle;

  /// No description provided for @tattsagramFabShowTattoo.
  ///
  /// In en, this message translates to:
  /// **'Show your tattoo'**
  String get tattsagramFabShowTattoo;

  /// No description provided for @dashboardTitle.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get dashboardTitle;

  /// No description provided for @dashboardPlaceholderBody.
  ///
  /// In en, this message translates to:
  /// **'Dashboard page'**
  String get dashboardPlaceholderBody;

  /// No description provided for @exploreTitle.
  ///
  /// In en, this message translates to:
  /// **'Explore'**
  String get exploreTitle;

  /// No description provided for @exploreSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Name, city, suburb...'**
  String get exploreSearchHint;

  /// No description provided for @exploreBidsNearMe.
  ///
  /// In en, this message translates to:
  /// **'Bids near me'**
  String get exploreBidsNearMe;

  /// No description provided for @exploreNearMeNeedProfile.
  ///
  /// In en, this message translates to:
  /// **'Add your city or suburb in your profile to use Bids near me.'**
  String get exploreNearMeNeedProfile;

  /// No description provided for @exploreNoSearchResults.
  ///
  /// In en, this message translates to:
  /// **'No posts match your search'**
  String get exploreNoSearchResults;

  /// No description provided for @exploreTitleWithCountry.
  ///
  /// In en, this message translates to:
  /// **'Explore - {country}'**
  String exploreTitleWithCountry(String country);

  /// No description provided for @postedOnDate.
  ///
  /// In en, this message translates to:
  /// **'Posted {date}'**
  String postedOnDate(String date);

  /// No description provided for @requestBidsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, zero{{count} bids} one{{count} bid} other{{count} bids}}'**
  String requestBidsCount(int count);

  /// No description provided for @bidClosed.
  ///
  /// In en, this message translates to:
  /// **'Bid closed'**
  String get bidClosed;

  /// No description provided for @noTattooRequestsYet.
  ///
  /// In en, this message translates to:
  /// **'No tattoo requests yet'**
  String get noTattooRequestsYet;

  /// No description provided for @addRequestToSeeHere.
  ///
  /// In en, this message translates to:
  /// **'Add a request to see it here'**
  String get addRequestToSeeHere;

  /// No description provided for @addPostCountryMismatchTitle.
  ///
  /// In en, this message translates to:
  /// **'You can\'t post here'**
  String get addPostCountryMismatchTitle;

  /// No description provided for @addPostCountryMismatchBody.
  ///
  /// In en, this message translates to:
  /// **'You can only post requests for the country where you live or stay. Your profile country does not match {targetCountry}. Update where you are staying or living in your profile.'**
  String addPostCountryMismatchBody(String targetCountry);

  /// No description provided for @addPostCountryMissingTitle.
  ///
  /// In en, this message translates to:
  /// **'Country required'**
  String get addPostCountryMissingTitle;

  /// No description provided for @addPostCountryMissingBody.
  ///
  /// In en, this message translates to:
  /// **'Add the country where you live or stay in your profile before you can post a request.'**
  String get addPostCountryMissingBody;

  /// No description provided for @addPostCountryMismatchOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get addPostCountryMismatchOk;

  /// No description provided for @addPostNeedDestinationTitle.
  ///
  /// In en, this message translates to:
  /// **'Select a country first'**
  String get addPostNeedDestinationTitle;

  /// No description provided for @addPostNeedDestinationBody.
  ///
  /// In en, this message translates to:
  /// **'Select a country from the globe on Explore before posting.'**
  String get addPostNeedDestinationBody;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @actionTooltipExplore.
  ///
  /// In en, this message translates to:
  /// **'Explore'**
  String get actionTooltipExplore;

  /// No description provided for @actionTooltipSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get actionTooltipSettings;

  /// No description provided for @languagePickerTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose Language'**
  String get languagePickerTitle;

  /// No description provided for @languagePickerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Select a language to continue'**
  String get languagePickerSubtitle;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageKhmer.
  ///
  /// In en, this message translates to:
  /// **'Khmer'**
  String get languageKhmer;

  /// No description provided for @languageIndonesian.
  ///
  /// In en, this message translates to:
  /// **'Indonesian'**
  String get languageIndonesian;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsLightMode.
  ///
  /// In en, this message translates to:
  /// **'Light mode'**
  String get settingsLightMode;

  /// No description provided for @settingsDarkMode.
  ///
  /// In en, this message translates to:
  /// **'Dark mode'**
  String get settingsDarkMode;

  /// No description provided for @settingsToggleTheme.
  ///
  /// In en, this message translates to:
  /// **'Toggle app theme'**
  String get settingsToggleTheme;

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// No description provided for @settingsLanguageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Change app language'**
  String get settingsLanguageSubtitle;

  /// No description provided for @settingsSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get settingsSignOut;

  /// No description provided for @settingsDangerZone.
  ///
  /// In en, this message translates to:
  /// **'Danger zone'**
  String get settingsDangerZone;

  /// No description provided for @settingsDeleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete Account'**
  String get settingsDeleteAccount;

  /// No description provided for @settingsAccountDeleted.
  ///
  /// In en, this message translates to:
  /// **'Account deleted'**
  String get settingsAccountDeleted;

  /// No description provided for @settingsAccountDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not delete your account. {reason}'**
  String settingsAccountDeleteFailed(String reason);

  /// No description provided for @appVersionLabel.
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String appVersionLabel(String version);

  /// No description provided for @authTitle.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get authTitle;

  /// No description provided for @authTabLogin.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get authTabLogin;

  /// No description provided for @authTabSignUp.
  ///
  /// In en, this message translates to:
  /// **'Sign up'**
  String get authTabSignUp;

  /// No description provided for @authEmailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get authEmailLabel;

  /// No description provided for @authPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get authPasswordLabel;

  /// No description provided for @authReenterPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Re-enter Password'**
  String get authReenterPasswordLabel;

  /// No description provided for @authSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get authSignIn;

  /// No description provided for @authCreateAccount.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get authCreateAccount;

  /// No description provided for @authEnterEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter your email'**
  String get authEnterEmail;

  /// No description provided for @authEnterPassword.
  ///
  /// In en, this message translates to:
  /// **'Enter your password'**
  String get authEnterPassword;

  /// No description provided for @authEnterPasswordSignUp.
  ///
  /// In en, this message translates to:
  /// **'Enter a password'**
  String get authEnterPasswordSignUp;

  /// No description provided for @authPasswordMinLength.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 6 characters'**
  String get authPasswordMinLength;

  /// No description provided for @authReenterPasswordError.
  ///
  /// In en, this message translates to:
  /// **'Re-enter your password'**
  String get authReenterPasswordError;

  /// No description provided for @authPasswordsDoNotMatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get authPasswordsDoNotMatch;

  /// No description provided for @profileContactDetailsTitle.
  ///
  /// In en, this message translates to:
  /// **'Contact details'**
  String get profileContactDetailsTitle;

  /// No description provided for @profileTapToChangePhoto.
  ///
  /// In en, this message translates to:
  /// **'Tap to change photo'**
  String get profileTapToChangePhoto;

  /// No description provided for @profileAddPhotoRequired.
  ///
  /// In en, this message translates to:
  /// **'Add a profile photo (required)'**
  String get profileAddPhotoRequired;

  /// No description provided for @profileUploading.
  ///
  /// In en, this message translates to:
  /// **'Uploading...'**
  String get profileUploading;

  /// No description provided for @profileDisplayNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Display name'**
  String get profileDisplayNameLabel;

  /// No description provided for @profileDisplayNameHint.
  ///
  /// In en, this message translates to:
  /// **'Your display name'**
  String get profileDisplayNameHint;

  /// No description provided for @profileEnterDisplayName.
  ///
  /// In en, this message translates to:
  /// **'Enter your display name'**
  String get profileEnterDisplayName;

  /// No description provided for @profileNameMaxLength.
  ///
  /// In en, this message translates to:
  /// **'Name must be 100 characters or less'**
  String get profileNameMaxLength;

  /// No description provided for @profileCountryLabel.
  ///
  /// In en, this message translates to:
  /// **'Country'**
  String get profileCountryLabel;

  /// No description provided for @profileSelectCountry.
  ///
  /// In en, this message translates to:
  /// **'Select country'**
  String get profileSelectCountry;

  /// No description provided for @profileCountryLockedByPostsBody.
  ///
  /// In en, this message translates to:
  /// **'You still have tattoo requests posted. Delete them from Explore before you can change your country.'**
  String get profileCountryLockedByPostsBody;

  /// No description provided for @profileCountryChangeBlockedError.
  ///
  /// In en, this message translates to:
  /// **'Delete your posted requests before you can change country.'**
  String get profileCountryChangeBlockedError;

  /// No description provided for @profileDisplayNameLockedHelper.
  ///
  /// In en, this message translates to:
  /// **'Display name can\'t be changed after it\'s set.'**
  String get profileDisplayNameLockedHelper;

  /// No description provided for @profileDisplayNameImmutableError.
  ///
  /// In en, this message translates to:
  /// **'Your display name can\'t be changed.'**
  String get profileDisplayNameImmutableError;

  /// No description provided for @profileDisplayNameTakenError.
  ///
  /// In en, this message translates to:
  /// **'That display name is already taken. Try another.'**
  String get profileDisplayNameTakenError;

  /// No description provided for @profileCityLabel.
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get profileCityLabel;

  /// No description provided for @profileSelectCity.
  ///
  /// In en, this message translates to:
  /// **'Select city'**
  String get profileSelectCity;

  /// No description provided for @profileSuburbOptionalLabel.
  ///
  /// In en, this message translates to:
  /// **'Suburb (optional)'**
  String get profileSuburbOptionalLabel;

  /// No description provided for @profileSuburbHint.
  ///
  /// In en, this message translates to:
  /// **'Enter suburb'**
  String get profileSuburbHint;

  /// No description provided for @profileSuburbPickSuggestion.
  ///
  /// In en, this message translates to:
  /// **'Or pick a suggestion below'**
  String get profileSuburbPickSuggestion;

  /// No description provided for @profileSuburbMaxLength.
  ///
  /// In en, this message translates to:
  /// **'Suburb must be 100 characters or less'**
  String get profileSuburbMaxLength;

  /// No description provided for @profileSuggestedSuburbsLabel.
  ///
  /// In en, this message translates to:
  /// **'Suggested suburbs (optional)'**
  String get profileSuggestedSuburbsLabel;

  /// No description provided for @profileSuggestedSuburbsHelper.
  ///
  /// In en, this message translates to:
  /// **'Tap to fill the suburb field above; you can edit it'**
  String get profileSuggestedSuburbsHelper;

  /// No description provided for @profilePickSuggestedSuburb.
  ///
  /// In en, this message translates to:
  /// **'Pick a suggested suburb'**
  String get profilePickSuggestedSuburb;

  /// No description provided for @profileChooseAccountType.
  ///
  /// In en, this message translates to:
  /// **'Choose your account type'**
  String get profileChooseAccountType;

  /// No description provided for @profileAccountTypeCanChange.
  ///
  /// In en, this message translates to:
  /// **'Tap Tattoo artist or Customer below. You can switch your choice until you tap Save — after that, your account type is permanent and cannot be changed.'**
  String get profileAccountTypeCanChange;

  /// No description provided for @profileAccountTypeLocked.
  ///
  /// In en, this message translates to:
  /// **'Your account type is set and cannot be changed.'**
  String get profileAccountTypeLocked;

  /// No description provided for @profileTattooArtistTitle.
  ///
  /// In en, this message translates to:
  /// **'Tattoo artist'**
  String get profileTattooArtistTitle;

  /// No description provided for @profileTattooArtistSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Bid on jobs and connect with customers'**
  String get profileTattooArtistSubtitle;

  /// No description provided for @profileCustomerTitle.
  ///
  /// In en, this message translates to:
  /// **'Customer'**
  String get profileCustomerTitle;

  /// No description provided for @profileCustomerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Post tattoo jobs and hire artists'**
  String get profileCustomerSubtitle;

  /// No description provided for @profilePortfolioTitle.
  ///
  /// In en, this message translates to:
  /// **'Portfolio'**
  String get profilePortfolioTitle;

  /// No description provided for @profilePortfolioBlurb.
  ///
  /// In en, this message translates to:
  /// **'Add up to {max} images for your public artist profile.'**
  String profilePortfolioBlurb(int max);

  /// No description provided for @profileAddImageButton.
  ///
  /// In en, this message translates to:
  /// **'Add image ({current}/{max})'**
  String profileAddImageButton(int current, int max);

  /// No description provided for @profilePortfolioLimitSnackbar.
  ///
  /// In en, this message translates to:
  /// **'Only {remaining} more image(s) allowed ({max} max).'**
  String profilePortfolioLimitSnackbar(int remaining, int max);

  /// No description provided for @profileContactSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Contact'**
  String get profileContactSectionTitle;

  /// No description provided for @profileContactHelpArtist.
  ///
  /// In en, this message translates to:
  /// **'Email and mobile are required. Shown to customers after a winning bid.'**
  String get profileContactHelpArtist;

  /// No description provided for @profileContactHelpCustomer.
  ///
  /// In en, this message translates to:
  /// **'Email and mobile are required.'**
  String get profileContactHelpCustomer;

  /// No description provided for @profileContactHelpNone.
  ///
  /// In en, this message translates to:
  /// **'Email and mobile are required. Choose your account type above first.'**
  String get profileContactHelpNone;

  /// No description provided for @profileEmailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email address'**
  String get profileEmailLabel;

  /// No description provided for @profileEmailHint.
  ///
  /// In en, this message translates to:
  /// **'your.email@example.com'**
  String get profileEmailHint;

  /// No description provided for @profileEnterEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter your email address'**
  String get profileEnterEmail;

  /// No description provided for @profileEnterValidEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address'**
  String get profileEnterValidEmail;

  /// No description provided for @profileMobileLabel.
  ///
  /// In en, this message translates to:
  /// **'Mobile number'**
  String get profileMobileLabel;

  /// No description provided for @profileMobileHint.
  ///
  /// In en, this message translates to:
  /// **'Your phone number'**
  String get profileMobileHint;

  /// No description provided for @profileEnterMobile.
  ///
  /// In en, this message translates to:
  /// **'Enter your mobile number'**
  String get profileEnterMobile;

  /// No description provided for @profileMobileMaxLength.
  ///
  /// In en, this message translates to:
  /// **'Max 40 characters'**
  String get profileMobileMaxLength;

  /// No description provided for @profileSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get profileSave;

  /// No description provided for @profileSelectUserTypeError.
  ///
  /// In en, this message translates to:
  /// **'Please select Tattoo Artist or Customer'**
  String get profileSelectUserTypeError;

  /// No description provided for @profilePhotoRequiredError.
  ///
  /// In en, this message translates to:
  /// **'Please add a profile photo before saving.'**
  String get profilePhotoRequiredError;

  /// No description provided for @profileCameraPermissionRequired.
  ///
  /// In en, this message translates to:
  /// **'Camera permission is required to take a photo.'**
  String get profileCameraPermissionRequired;

  /// No description provided for @profileAvatarUploadDenied.
  ///
  /// In en, this message translates to:
  /// **'Avatar upload denied. Ensure the \"avatars\" bucket exists and is public in Supabase Dashboard → Storage.'**
  String get profileAvatarUploadDenied;

  /// No description provided for @profileAccountTypeLockedSnackbar.
  ///
  /// In en, this message translates to:
  /// **'Your account type can\'t be changed after it\'s saved.'**
  String get profileAccountTypeLockedSnackbar;

  /// No description provided for @profileEditContact.
  ///
  /// In en, this message translates to:
  /// **'Edit contact'**
  String get profileEditContact;

  /// No description provided for @profileNotLoggedIn.
  ///
  /// In en, this message translates to:
  /// **'Not logged in'**
  String get profileNotLoggedIn;

  /// No description provided for @bidDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Request details'**
  String get bidDetailTitle;

  /// No description provided for @bidDetailStartingBid.
  ///
  /// In en, this message translates to:
  /// **'{amount} starting bid'**
  String bidDetailStartingBid(String amount);

  /// No description provided for @bidDetailHideDescription.
  ///
  /// In en, this message translates to:
  /// **'Hide description'**
  String get bidDetailHideDescription;

  /// No description provided for @bidDetailWhatCustomerWants.
  ///
  /// In en, this message translates to:
  /// **'What does the customer want?'**
  String get bidDetailWhatCustomerWants;

  /// No description provided for @bidDetailPlacement.
  ///
  /// In en, this message translates to:
  /// **'Placement'**
  String get bidDetailPlacement;

  /// No description provided for @bidDetailSize.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get bidDetailSize;

  /// No description provided for @bidDetailColour.
  ///
  /// In en, this message translates to:
  /// **'Colour'**
  String get bidDetailColour;

  /// No description provided for @bidDetailColourFull.
  ///
  /// In en, this message translates to:
  /// **'Colour'**
  String get bidDetailColourFull;

  /// No description provided for @bidDetailColourBlackGrey.
  ///
  /// In en, this message translates to:
  /// **'Black and grey'**
  String get bidDetailColourBlackGrey;

  /// No description provided for @bidDetailTimeFrame.
  ///
  /// In en, this message translates to:
  /// **'Time frame'**
  String get bidDetailTimeFrame;

  /// No description provided for @bidDetailTimeframeAsap.
  ///
  /// In en, this message translates to:
  /// **'ASAP'**
  String get bidDetailTimeframeAsap;

  /// No description provided for @bidDetailTimeframeWeek.
  ///
  /// In en, this message translates to:
  /// **'During the week'**
  String get bidDetailTimeframeWeek;

  /// No description provided for @bidDetailTimeframeFlexible.
  ///
  /// In en, this message translates to:
  /// **'Whenever you can book me in'**
  String get bidDetailTimeframeFlexible;

  /// No description provided for @bidDetailArtistCreativeFreedom.
  ///
  /// In en, this message translates to:
  /// **'Artist has creative freedom'**
  String get bidDetailArtistCreativeFreedom;

  /// No description provided for @bidDetailNoDescription.
  ///
  /// In en, this message translates to:
  /// **'No description provided.'**
  String get bidDetailNoDescription;

  /// No description provided for @bidDetailBids.
  ///
  /// In en, this message translates to:
  /// **'Bids'**
  String get bidDetailBids;

  /// No description provided for @bidDetailArtistToolsNotBidHint.
  ///
  /// In en, this message translates to:
  /// **'Artist tools — bidding is not started from this button.'**
  String get bidDetailArtistToolsNotBidHint;

  /// No description provided for @bidDetailOnlyArtistsMayBid.
  ///
  /// In en, this message translates to:
  /// **'Only tattoo artists can place bids on requests.'**
  String get bidDetailOnlyArtistsMayBid;

  /// No description provided for @bidDetailBidCountryRequestMissingHint.
  ///
  /// In en, this message translates to:
  /// **'This request has no country set. You can’t place a bid.'**
  String get bidDetailBidCountryRequestMissingHint;

  /// No description provided for @bidDetailBidCountryProfileMissingHint.
  ///
  /// In en, this message translates to:
  /// **'Your profile has no country saved in the app. Open Profile → contact details, choose Country, tap Save, then try again.'**
  String get bidDetailBidCountryProfileMissingHint;

  /// No description provided for @bidDetailBidCountryMismatchHint.
  ///
  /// In en, this message translates to:
  /// **'You can only bid on requests in your country. This job is in {requestCountry}; your profile country is {profileCountry}.'**
  String bidDetailBidCountryMismatchHint(
      String requestCountry, String profileCountry);

  /// No description provided for @bidDetailBiddingClosedMessage.
  ///
  /// In en, this message translates to:
  /// **'Bidding is closed. This request is no longer accepting new bids.'**
  String get bidDetailBiddingClosedMessage;

  /// No description provided for @bidDetailViewArtistTools.
  ///
  /// In en, this message translates to:
  /// **'View Artist Tools'**
  String get bidDetailViewArtistTools;

  /// No description provided for @bidDetailBid.
  ///
  /// In en, this message translates to:
  /// **'Bid'**
  String get bidDetailBid;

  /// No description provided for @bidDetailCouldNotLoadBids.
  ///
  /// In en, this message translates to:
  /// **'Could not load bids'**
  String get bidDetailCouldNotLoadBids;

  /// No description provided for @bidDetailNoBidsYet.
  ///
  /// In en, this message translates to:
  /// **'No bids yet'**
  String get bidDetailNoBidsYet;

  /// No description provided for @bidDetailLowest.
  ///
  /// In en, this message translates to:
  /// **'Lowest'**
  String get bidDetailLowest;

  /// No description provided for @bidDetailArtistNameFallback.
  ///
  /// In en, this message translates to:
  /// **'Artist'**
  String get bidDetailArtistNameFallback;

  /// No description provided for @bidDetailChooseArtist.
  ///
  /// In en, this message translates to:
  /// **'Choose artist'**
  String get bidDetailChooseArtist;

  /// No description provided for @bidDetailPaid.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get bidDetailPaid;

  /// No description provided for @bidDetailUnlockContact.
  ///
  /// In en, this message translates to:
  /// **'Unlock Contact'**
  String get bidDetailUnlockContact;

  /// No description provided for @bidDetailSectionArtistContact.
  ///
  /// In en, this message translates to:
  /// **'Artist contact'**
  String get bidDetailSectionArtistContact;

  /// No description provided for @bidDetailSectionDeposit.
  ///
  /// In en, this message translates to:
  /// **'Deposit'**
  String get bidDetailSectionDeposit;

  /// No description provided for @bidDetailSectionConnect.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get bidDetailSectionConnect;

  /// No description provided for @bidDetailPaymentCompleteBody.
  ///
  /// In en, this message translates to:
  /// **'Payment is marked complete. If contact is still locked, refresh — your unlock is stored after Stripe confirms.'**
  String get bidDetailPaymentCompleteBody;

  /// No description provided for @bidDetailRefreshUnlockStatus.
  ///
  /// In en, this message translates to:
  /// **'Refresh unlock status'**
  String get bidDetailRefreshUnlockStatus;

  /// No description provided for @bidDetailChooseWinningBidForDeposit.
  ///
  /// In en, this message translates to:
  /// **'Choose a winning bid to see the deposit.'**
  String get bidDetailChooseWinningBidForDeposit;

  /// No description provided for @bidDetailChooseWinningBidToConnect.
  ///
  /// In en, this message translates to:
  /// **'Choose a winning bid to connect with your artist.'**
  String get bidDetailChooseWinningBidToConnect;

  /// No description provided for @bidDetailChooseWinningBidToChat.
  ///
  /// In en, this message translates to:
  /// **'Choose a winning bid above. You can chat with your artist right away.'**
  String get bidDetailChooseWinningBidToChat;

  /// No description provided for @bidDetailPhoneLine.
  ///
  /// In en, this message translates to:
  /// **'Phone: {phone}'**
  String bidDetailPhoneLine(String phone);

  /// No description provided for @bidDetailEmailLine.
  ///
  /// In en, this message translates to:
  /// **'Email: {email}'**
  String bidDetailEmailLine(String email);

  /// No description provided for @bidDetailChat.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get bidDetailChat;

  /// No description provided for @bidDetailTotalPriceLine.
  ///
  /// In en, this message translates to:
  /// **'Total price: {amount}'**
  String bidDetailTotalPriceLine(String amount);

  /// No description provided for @bidDetailDepositLine.
  ///
  /// In en, this message translates to:
  /// **'Deposit ({percent}%): {amount}'**
  String bidDetailDepositLine(int percent, String amount);

  /// No description provided for @bidDetailRemainingLine.
  ///
  /// In en, this message translates to:
  /// **'Remaining ({percent}%): {amount}'**
  String bidDetailRemainingLine(int percent, String amount);

  /// No description provided for @bidDetailPayDepositUnlock.
  ///
  /// In en, this message translates to:
  /// **'Pay {percent}% Deposit & Unlock Artist'**
  String bidDetailPayDepositUnlock(int percent);

  /// No description provided for @bidDetailPlaceBidTitle.
  ///
  /// In en, this message translates to:
  /// **'Place bid'**
  String get bidDetailPlaceBidTitle;

  /// No description provided for @bidDetailYourPriceLabel.
  ///
  /// In en, this message translates to:
  /// **'Your price (\$)'**
  String get bidDetailYourPriceLabel;

  /// No description provided for @bidDetailEnterValidBidAmount.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid amount (0 or more)'**
  String get bidDetailEnterValidBidAmount;

  /// No description provided for @bidDetailCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get bidDetailCancel;

  /// No description provided for @bidDetailSubmit.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get bidDetailSubmit;

  /// No description provided for @bidDetailArtistToolsSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Artist tools'**
  String get bidDetailArtistToolsSheetTitle;

  /// No description provided for @bidDetailArtistToolsSheetBody.
  ///
  /// In en, this message translates to:
  /// **'More artist actions for this job will appear here. This does not place a bid.'**
  String get bidDetailArtistToolsSheetBody;

  /// No description provided for @bidDetailCouldNotOpenProfile.
  ///
  /// In en, this message translates to:
  /// **'Could not open this profile.'**
  String get bidDetailCouldNotOpenProfile;

  /// No description provided for @bidDetailRequestAlreadyCompleted.
  ///
  /// In en, this message translates to:
  /// **'This request is already completed.'**
  String get bidDetailRequestAlreadyCompleted;

  /// No description provided for @bidDetailCouldNotUnlockContactDetails.
  ///
  /// In en, this message translates to:
  /// **'Could not unlock contact: {details}'**
  String bidDetailCouldNotUnlockContactDetails(String details);

  /// No description provided for @bidDetailCouldNotSelectBidDetails.
  ///
  /// In en, this message translates to:
  /// **'Could not select bid: {details}'**
  String bidDetailCouldNotSelectBidDetails(String details);

  /// No description provided for @bidDetailTapChooseArtistHint.
  ///
  /// In en, this message translates to:
  /// **'Tap Choose artist on a bid to connect with your artist.'**
  String get bidDetailTapChooseArtistHint;

  /// No description provided for @bidDetailPaymentAlreadyCompleted.
  ///
  /// In en, this message translates to:
  /// **'Payment has already been completed for this request.'**
  String get bidDetailPaymentAlreadyCompleted;

  /// No description provided for @bidDetailMissingArtistForBid.
  ///
  /// In en, this message translates to:
  /// **'Missing artist for this bid.'**
  String get bidDetailMissingArtistForBid;

  /// No description provided for @bidDetailPaymentFailedDetails.
  ///
  /// In en, this message translates to:
  /// **'Payment failed: {details}'**
  String bidDetailPaymentFailedDetails(String details);

  /// No description provided for @bidDetailCouldNotFindBidToPay.
  ///
  /// In en, this message translates to:
  /// **'Could not find that bid to pay'**
  String get bidDetailCouldNotFindBidToPay;

  /// No description provided for @bidDetailOnlyCustomerCanPay.
  ///
  /// In en, this message translates to:
  /// **'Only the customer can pay'**
  String get bidDetailOnlyCustomerCanPay;

  /// No description provided for @bidDetailCannotPlaceBid.
  ///
  /// In en, this message translates to:
  /// **'You can\'t place a bid on this request.'**
  String get bidDetailCannotPlaceBid;

  /// No description provided for @bidDetailBiddingClosedSnackbar.
  ///
  /// In en, this message translates to:
  /// **'Bidding is closed for this request.'**
  String get bidDetailBiddingClosedSnackbar;

  /// No description provided for @bidDetailBidPlaced.
  ///
  /// In en, this message translates to:
  /// **'Bid placed'**
  String get bidDetailBidPlaced;

  /// No description provided for @bidDetailFailedPlaceBidDetails.
  ///
  /// In en, this message translates to:
  /// **'Failed to place bid: {details}'**
  String bidDetailFailedPlaceBidDetails(String details);

  /// No description provided for @photoTakePhoto.
  ///
  /// In en, this message translates to:
  /// **'Take a photo'**
  String get photoTakePhoto;

  /// No description provided for @photoFromGallery.
  ///
  /// In en, this message translates to:
  /// **'Upload from gallery'**
  String get photoFromGallery;

  /// No description provided for @tattsagramPhotoSharedInChat.
  ///
  /// In en, this message translates to:
  /// **'📷 Photo'**
  String get tattsagramPhotoSharedInChat;

  /// No description provided for @tattsagramUploadingPhoto.
  ///
  /// In en, this message translates to:
  /// **'Uploading photo…'**
  String get tattsagramUploadingPhoto;

  /// No description provided for @tattsagramPhotoUploadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not upload media. Sign in and try again.'**
  String get tattsagramPhotoUploadFailed;

  /// No description provided for @destinationChooseTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose destination'**
  String get destinationChooseTitle;

  /// No description provided for @destinationComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Coming soon'**
  String get destinationComingSoon;

  /// No description provided for @addTabTitle.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get addTabTitle;

  /// No description provided for @addUploading.
  ///
  /// In en, this message translates to:
  /// **'Uploading...'**
  String get addUploading;

  /// No description provided for @addPhotoButton.
  ///
  /// In en, this message translates to:
  /// **'Add photo'**
  String get addPhotoButton;

  /// No description provided for @addHappyAddDetails.
  ///
  /// In en, this message translates to:
  /// **'I\'m happy — add details'**
  String get addHappyAddDetails;

  /// No description provided for @addChooseDifferentPhoto.
  ///
  /// In en, this message translates to:
  /// **'Choose different photo'**
  String get addChooseDifferentPhoto;

  /// No description provided for @addDescriptionHint.
  ///
  /// In en, this message translates to:
  /// **'Describe your vision...'**
  String get addDescriptionHint;

  /// No description provided for @addPlacementHint.
  ///
  /// In en, this message translates to:
  /// **'Where on the body? (e.g. arm, back, leg)'**
  String get addPlacementHint;

  /// No description provided for @addSizeHint.
  ///
  /// In en, this message translates to:
  /// **'Small, medium, large, or dimensions'**
  String get addSizeHint;

  /// No description provided for @addColourChip.
  ///
  /// In en, this message translates to:
  /// **'Colour'**
  String get addColourChip;

  /// No description provided for @addBlackGreyChip.
  ///
  /// In en, this message translates to:
  /// **'Black and grey'**
  String get addBlackGreyChip;

  /// No description provided for @addTimeAsap.
  ///
  /// In en, this message translates to:
  /// **'ASAP'**
  String get addTimeAsap;

  /// No description provided for @addTimeWeek.
  ///
  /// In en, this message translates to:
  /// **'During the week'**
  String get addTimeWeek;

  /// No description provided for @addTimeBookWhen.
  ///
  /// In en, this message translates to:
  /// **'Whenever you can book me in'**
  String get addTimeBookWhen;

  /// No description provided for @addBidAmountHint.
  ///
  /// In en, this message translates to:
  /// **'0'**
  String get addBidAmountHint;

  /// No description provided for @addSubmitRequest.
  ///
  /// In en, this message translates to:
  /// **'Submit request'**
  String get addSubmitRequest;

  /// No description provided for @addBackButton.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get addBackButton;

  /// No description provided for @addAnotherRequest.
  ///
  /// In en, this message translates to:
  /// **'Add another request'**
  String get addAnotherRequest;

  /// No description provided for @artistsDirectorySearchHint.
  ///
  /// In en, this message translates to:
  /// **'Name, city, suburb, or country'**
  String get artistsDirectorySearchHint;

  /// No description provided for @artistsFilterRating.
  ///
  /// In en, this message translates to:
  /// **'Rating'**
  String get artistsFilterRating;

  /// No description provided for @artistsFilterCleanliness.
  ///
  /// In en, this message translates to:
  /// **'Cleanliness'**
  String get artistsFilterCleanliness;

  /// No description provided for @exploreDeleteFailedDetails.
  ///
  /// In en, this message translates to:
  /// **'Delete failed: {details}'**
  String exploreDeleteFailedDetails(String details);

  /// No description provided for @checkoutTitle.
  ///
  /// In en, this message translates to:
  /// **'Checkout'**
  String get checkoutTitle;

  /// No description provided for @checkoutContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get checkoutContinue;

  /// No description provided for @checkoutCancelledMessage.
  ///
  /// In en, this message translates to:
  /// **'Checkout was cancelled.'**
  String get checkoutCancelledMessage;

  /// No description provided for @checkoutTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get checkoutTryAgain;

  /// No description provided for @checkoutBackToDashboard.
  ///
  /// In en, this message translates to:
  /// **'Back to dashboard'**
  String get checkoutBackToDashboard;

  /// No description provided for @depositSummaryTitle.
  ///
  /// In en, this message translates to:
  /// **'Deposit summary'**
  String get depositSummaryTitle;

  /// No description provided for @depositTotalCostLine.
  ///
  /// In en, this message translates to:
  /// **'Total cost: {amount}'**
  String depositTotalCostLine(String amount);

  /// No description provided for @depositArtistReceivesLine.
  ///
  /// In en, this message translates to:
  /// **'Artist receives: {amount}'**
  String depositArtistReceivesLine(String amount);

  /// No description provided for @depositPayButton.
  ///
  /// In en, this message translates to:
  /// **'Pay'**
  String get depositPayButton;

  /// No description provided for @depositFeePercentLine.
  ///
  /// In en, this message translates to:
  /// **'Deposit fee ({percent}%): {amount}'**
  String depositFeePercentLine(int percent, String amount);

  /// No description provided for @platformFeePaymentFailed.
  ///
  /// In en, this message translates to:
  /// **'Payment failed: {error}'**
  String platformFeePaymentFailed(String error);

  /// No description provided for @cameraTitle.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get cameraTitle;

  /// No description provided for @cameraSwitchError.
  ///
  /// In en, this message translates to:
  /// **'Could not switch camera: {error}'**
  String cameraSwitchError(String error);

  /// No description provided for @cameraCaptureError.
  ///
  /// In en, this message translates to:
  /// **'Failed to capture image: {error}'**
  String cameraCaptureError(String error);

  /// No description provided for @cameraNoDeviceAvailable.
  ///
  /// In en, this message translates to:
  /// **'No camera available on this device.'**
  String get cameraNoDeviceAvailable;

  /// No description provided for @cameraInitFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to initialize camera: {error}'**
  String cameraInitFailed(String error);

  /// No description provided for @bidPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Bid'**
  String get bidPageTitle;

  /// No description provided for @paywallSubscribeTitle.
  ///
  /// In en, this message translates to:
  /// **'Subscribe'**
  String get paywallSubscribeTitle;

  /// No description provided for @paywallSubscribeMonthly.
  ///
  /// In en, this message translates to:
  /// **'Subscribe monthly'**
  String get paywallSubscribeMonthly;

  /// No description provided for @paywallFreePlanTitle.
  ///
  /// In en, this message translates to:
  /// **'Free version'**
  String get paywallFreePlanTitle;

  /// No description provided for @paywallProPlanTitle.
  ///
  /// In en, this message translates to:
  /// **'Pro version'**
  String get paywallProPlanTitle;

  /// No description provided for @paywallProMaxPlanTitle.
  ///
  /// In en, this message translates to:
  /// **'Pro Max'**
  String get paywallProMaxPlanTitle;

  /// No description provided for @paywallProPlanSubtitle.
  ///
  /// In en, this message translates to:
  /// **'99¢ AUD monthly'**
  String get paywallProPlanSubtitle;

  /// No description provided for @paywallProMaxPlanSubtitle.
  ///
  /// In en, this message translates to:
  /// **'\$1.00 AUD monthly'**
  String get paywallProMaxPlanSubtitle;

  /// No description provided for @welcomeGetStarted.
  ///
  /// In en, this message translates to:
  /// **'Get started'**
  String get welcomeGetStarted;

  /// No description provided for @welcomeSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get welcomeSkip;

  /// No description provided for @editContactEmailHint.
  ///
  /// In en, this message translates to:
  /// **'Your contact email'**
  String get editContactEmailHint;

  /// No description provided for @editContactPhoneHint.
  ///
  /// In en, this message translates to:
  /// **'Your phone number'**
  String get editContactPhoneHint;

  /// No description provided for @publicProfileCantChatSelf.
  ///
  /// In en, this message translates to:
  /// **'You can\'t chat with yourself.'**
  String get publicProfileCantChatSelf;

  /// No description provided for @publicProfileReviewCommentRequired.
  ///
  /// In en, this message translates to:
  /// **'Please write a comment.'**
  String get publicProfileReviewCommentRequired;

  /// No description provided for @publicProfileReviewSubmitError.
  ///
  /// In en, this message translates to:
  /// **'Could not submit review right now. Please try again.'**
  String get publicProfileReviewSubmitError;

  /// No description provided for @publicProfileChatButton.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get publicProfileChatButton;

  /// No description provided for @publicProfileChatWithArtist.
  ///
  /// In en, this message translates to:
  /// **'Chat with artist'**
  String get publicProfileChatWithArtist;

  /// No description provided for @publicProfileReviewHint.
  ///
  /// In en, this message translates to:
  /// **'Share your experience…'**
  String get publicProfileReviewHint;

  /// No description provided for @publicProfileSubmitReview.
  ///
  /// In en, this message translates to:
  /// **'Submit review'**
  String get publicProfileSubmitReview;

  /// No description provided for @publicProfileEmailTitle.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get publicProfileEmailTitle;

  /// No description provided for @publicProfileMobileTitle.
  ///
  /// In en, this message translates to:
  /// **'Mobile'**
  String get publicProfileMobileTitle;

  /// No description provided for @publicProfileTitleFallback.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get publicProfileTitleFallback;

  /// No description provided for @publicProfileReviewSelectBoth.
  ///
  /// In en, this message translates to:
  /// **'Please select both Rating and Cleanliness (1–5 stars each).'**
  String get publicProfileReviewSelectBoth;

  /// No description provided for @publicProfileReviewPostedThanks.
  ///
  /// In en, this message translates to:
  /// **'Thanks — your review was posted.'**
  String get publicProfileReviewPostedThanks;

  /// No description provided for @publicProfileReviewUpdated.
  ///
  /// In en, this message translates to:
  /// **'You have already reviewed this artist. Your review was updated.'**
  String get publicProfileReviewUpdated;

  /// No description provided for @publicProfileReviewAlreadyReviewedShort.
  ///
  /// In en, this message translates to:
  /// **'You have already reviewed this artist'**
  String get publicProfileReviewAlreadyReviewedShort;

  /// No description provided for @publicProfileReviewsHeading.
  ///
  /// In en, this message translates to:
  /// **'Reviews'**
  String get publicProfileReviewsHeading;

  /// No description provided for @publicProfileNoReviewsYet.
  ///
  /// In en, this message translates to:
  /// **'No reviews yet.'**
  String get publicProfileNoReviewsYet;

  /// No description provided for @publicProfilePreviousReviews.
  ///
  /// In en, this message translates to:
  /// **'Previous reviews'**
  String get publicProfilePreviousReviews;

  /// No description provided for @publicProfileReviewsTileSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} review · tap to expand} other{{count} reviews · tap to expand}}'**
  String publicProfileReviewsTileSubtitle(num count);

  /// No description provided for @publicProfileWriteReview.
  ///
  /// In en, this message translates to:
  /// **'Write a review'**
  String get publicProfileWriteReview;

  /// No description provided for @publicProfileEditReview.
  ///
  /// In en, this message translates to:
  /// **'Edit your review'**
  String get publicProfileEditReview;

  /// No description provided for @publicProfileNoContactOnFile.
  ///
  /// In en, this message translates to:
  /// **'No contact details on file.'**
  String get publicProfileNoContactOnFile;

  /// No description provided for @chatSendFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to send: {error}'**
  String chatSendFailed(String error);

  /// No description provided for @chatMessageHint.
  ///
  /// In en, this message translates to:
  /// **'Message (private)'**
  String get chatMessageHint;

  /// No description provided for @chatMessageArtist.
  ///
  /// In en, this message translates to:
  /// **'Message artist'**
  String get chatMessageArtist;

  /// No description provided for @chatMobileLine.
  ///
  /// In en, this message translates to:
  /// **'Mobile: {phone}'**
  String chatMobileLine(String phone);

  /// No description provided for @chatEmailLine.
  ///
  /// In en, this message translates to:
  /// **'Email: {email}'**
  String chatEmailLine(String email);

  /// No description provided for @chatInboxTitle.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get chatInboxTitle;

  /// No description provided for @chatPartnerFallbackTitle.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get chatPartnerFallbackTitle;

  /// No description provided for @chatPrivacyNotice.
  ///
  /// In en, this message translates to:
  /// **'Messages between tattoo artists and customers only. Only you and this person can see these messages.'**
  String get chatPrivacyNotice;

  /// No description provided for @chatContactSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Contact'**
  String get chatContactSectionTitle;

  /// No description provided for @chatSetupRequired.
  ///
  /// In en, this message translates to:
  /// **'Chat setup required. Run the migration in supabase/apply_chat_messages.sql in your Supabase Dashboard (SQL Editor), then tap Retry.'**
  String get chatSetupRequired;

  /// No description provided for @chatEmptyConversation.
  ///
  /// In en, this message translates to:
  /// **'No messages yet. Say hello — this conversation is only visible to you and the other person.'**
  String get chatEmptyConversation;

  /// No description provided for @chatYourArtist.
  ///
  /// In en, this message translates to:
  /// **'Your artist'**
  String get chatYourArtist;

  /// No description provided for @chatPhoneLine.
  ///
  /// In en, this message translates to:
  /// **'Phone: {phone}'**
  String chatPhoneLine(String phone);

  /// No description provided for @chatNoContactYet.
  ///
  /// In en, this message translates to:
  /// **'No phone or email on file yet.'**
  String get chatNoContactYet;

  /// No description provided for @chatUnknownUser.
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get chatUnknownUser;

  /// No description provided for @chatInboxEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No conversations yet'**
  String get chatInboxEmptyTitle;

  /// No description provided for @chatInboxEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Chats from Explore (customer messages first) appear here. After you pay the deposit on your winning bid, this screen shows your artist’s contact details and a button to start messaging.'**
  String get chatInboxEmptyBody;

  /// No description provided for @chatInboxUnlockTitle.
  ///
  /// In en, this message translates to:
  /// **'Pay to unlock messaging'**
  String get chatInboxUnlockTitle;

  /// No description provided for @chatInboxUnlockBody.
  ///
  /// In en, this message translates to:
  /// **'Complete the deposit from your request’s winning bid to unlock artist contact and chat.'**
  String get chatInboxUnlockBody;

  /// No description provided for @chatPaidArtistBlurbLong.
  ///
  /// In en, this message translates to:
  /// **'Deposit paid — you can message your artist or use their contact details below.'**
  String get chatPaidArtistBlurbLong;

  /// No description provided for @chatPaidArtistBlurbShort.
  ///
  /// In en, this message translates to:
  /// **'Deposit paid — message your artist or use their contact details.'**
  String get chatPaidArtistBlurbShort;

  /// No description provided for @chatConversationsSection.
  ///
  /// In en, this message translates to:
  /// **'Conversations'**
  String get chatConversationsSection;

  /// No description provided for @reviewRatingLabel.
  ///
  /// In en, this message translates to:
  /// **'Rating'**
  String get reviewRatingLabel;

  /// No description provided for @reviewCleanlinessLabel.
  ///
  /// In en, this message translates to:
  /// **'Cleanliness'**
  String get reviewCleanlinessLabel;

  /// No description provided for @userAgreementTitle.
  ///
  /// In en, this message translates to:
  /// **'TattsBid user agreement'**
  String get userAgreementTitle;

  /// No description provided for @userAgreementAcceptTerms.
  ///
  /// In en, this message translates to:
  /// **'I agree to the TattsBid terms'**
  String get userAgreementAcceptTerms;

  /// No description provided for @userAgreementContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get userAgreementContinue;

  /// No description provided for @userAgreementSaveError.
  ///
  /// In en, this message translates to:
  /// **'Could not save agreement: {error}'**
  String userAgreementSaveError(String error);

  /// No description provided for @addReferencePhotoTitle.
  ///
  /// In en, this message translates to:
  /// **'Add a reference photo'**
  String get addReferencePhotoTitle;

  /// No description provided for @addReferencePhotoSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Take a photo or choose from your gallery'**
  String get addReferencePhotoSubtitle;

  /// No description provided for @addPhotoUploadedTitle.
  ///
  /// In en, this message translates to:
  /// **'Photo uploaded successfully'**
  String get addPhotoUploadedTitle;

  /// No description provided for @addPhotoUploadedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Happy with this photo? Add a description and starting bid.'**
  String get addPhotoUploadedSubtitle;

  /// No description provided for @addDescriptionSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get addDescriptionSectionTitle;

  /// No description provided for @addFieldDescriptionLabel.
  ///
  /// In en, this message translates to:
  /// **'What do you want for your tattoo?'**
  String get addFieldDescriptionLabel;

  /// No description provided for @addFieldPlacementLabel.
  ///
  /// In en, this message translates to:
  /// **'Placement'**
  String get addFieldPlacementLabel;

  /// No description provided for @addFieldSizeLabel.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get addFieldSizeLabel;

  /// No description provided for @addSectionColourTitle.
  ///
  /// In en, this message translates to:
  /// **'Colour or black and grey'**
  String get addSectionColourTitle;

  /// No description provided for @addSectionTimeframeTitle.
  ///
  /// In en, this message translates to:
  /// **'Time frame'**
  String get addSectionTimeframeTitle;

  /// No description provided for @addCreativeFreedomTitle.
  ///
  /// In en, this message translates to:
  /// **'Allow the artist to have creative freedom'**
  String get addCreativeFreedomTitle;

  /// No description provided for @addStartingBidLabel.
  ///
  /// In en, this message translates to:
  /// **'Starting bid (\$)'**
  String get addStartingBidLabel;

  /// No description provided for @addInvalidBidAmount.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid amount (0 or more)'**
  String get addInvalidBidAmount;

  /// No description provided for @addSubmittedTitle.
  ///
  /// In en, this message translates to:
  /// **'Request submitted!'**
  String get addSubmittedTitle;

  /// No description provided for @addSubmittedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Artists can now view your request and place bids.'**
  String get addSubmittedSubtitle;

  /// No description provided for @artistsNearMeButton.
  ///
  /// In en, this message translates to:
  /// **'Artist near me'**
  String get artistsNearMeButton;

  /// No description provided for @artistsShowingInLocation.
  ///
  /// In en, this message translates to:
  /// **'Showing artists in {location}'**
  String artistsShowingInLocation(String location);

  /// No description provided for @artistsClearSearchTooltip.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get artistsClearSearchTooltip;
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
      <String>['en', 'id', 'km'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'id':
      return AppLocalizationsId();
    case 'km':
      return AppLocalizationsKm();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
