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

  /// No description provided for @exploreTitle.
  ///
  /// In en, this message translates to:
  /// **'Explore'**
  String get exploreTitle;

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
