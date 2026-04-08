// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get tabExplore => 'Explore';

  @override
  String get tabArtists => 'Artists';

  @override
  String get tabUpload => 'Upload';

  @override
  String get tabMessage => 'Message';

  @override
  String get tabProfile => 'Profile';

  @override
  String get exploreTitle => 'Explore';

  @override
  String postedOnDate(String date) {
    return 'Posted $date';
  }

  @override
  String requestBidsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count bids',
      one: '$count bid',
      zero: '$count bids',
    );
    return '$_temp0';
  }

  @override
  String get bidClosed => 'Bid closed';

  @override
  String get noTattooRequestsYet => 'No tattoo requests yet';

  @override
  String get addRequestToSeeHere => 'Add a request to see it here';

  @override
  String get retry => 'Retry';

  @override
  String get actionTooltipExplore => 'Explore';

  @override
  String get actionTooltipSettings => 'Settings';

  @override
  String get languagePickerTitle => 'Choose Language';

  @override
  String get languagePickerSubtitle => 'Select a language to continue';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageKhmer => 'Khmer';

  @override
  String get languageIndonesian => 'Indonesian';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsLightMode => 'Light mode';

  @override
  String get settingsDarkMode => 'Dark mode';

  @override
  String get settingsToggleTheme => 'Toggle app theme';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsLanguageSubtitle => 'Change app language';

  @override
  String get settingsSignOut => 'Sign out';

  @override
  String get settingsDangerZone => 'Danger zone';

  @override
  String get settingsDeleteAccount => 'Delete Account';

  @override
  String get settingsAccountDeleted => 'Account deleted';

  @override
  String appVersionLabel(String version) {
    return 'Version $version';
  }

  @override
  String get authTitle => 'Account';

  @override
  String get authTabLogin => 'Login';

  @override
  String get authTabSignUp => 'Sign up';

  @override
  String get authEmailLabel => 'Email';

  @override
  String get authPasswordLabel => 'Password';

  @override
  String get authReenterPasswordLabel => 'Re-enter Password';

  @override
  String get authSignIn => 'Sign in';

  @override
  String get authCreateAccount => 'Create account';

  @override
  String get authEnterEmail => 'Enter your email';

  @override
  String get authEnterPassword => 'Enter your password';

  @override
  String get authEnterPasswordSignUp => 'Enter a password';

  @override
  String get authPasswordMinLength => 'Password must be at least 6 characters';

  @override
  String get authReenterPasswordError => 'Re-enter your password';

  @override
  String get authPasswordsDoNotMatch => 'Passwords do not match';

  @override
  String get profileContactDetailsTitle => 'Contact details';

  @override
  String get profileTapToChangePhoto => 'Tap to change photo';

  @override
  String get profileAddPhotoRequired => 'Add a profile photo (required)';

  @override
  String get profileUploading => 'Uploading...';

  @override
  String get profileDisplayNameLabel => 'Display name';

  @override
  String get profileDisplayNameHint => 'Your display name';

  @override
  String get profileEnterDisplayName => 'Enter your display name';

  @override
  String get profileNameMaxLength => 'Name must be 100 characters or less';

  @override
  String get profileCountryLabel => 'Country';

  @override
  String get profileSelectCountry => 'Select country';

  @override
  String get profileCityLabel => 'City';

  @override
  String get profileSelectCity => 'Select city';

  @override
  String get profileSuburbOptionalLabel => 'Suburb (optional)';

  @override
  String get profileSuburbHint => 'Enter suburb';

  @override
  String get profileSuburbPickSuggestion => 'Or pick a suggestion below';

  @override
  String get profileSuburbMaxLength => 'Suburb must be 100 characters or less';

  @override
  String get profileSuggestedSuburbsLabel => 'Suggested suburbs (optional)';

  @override
  String get profileSuggestedSuburbsHelper =>
      'Tap to fill the suburb field above; you can edit it';

  @override
  String get profilePickSuggestedSuburb => 'Pick a suggested suburb';

  @override
  String get profileChooseAccountType => 'Choose your account type';

  @override
  String get profileAccountTypeCanChange =>
      'Tap Tattoo artist or Customer below. You can switch your choice until you tap Save — after that, your account type is permanent and cannot be changed.';

  @override
  String get profileAccountTypeLocked =>
      'Your account type is set and cannot be changed.';

  @override
  String get profileTattooArtistTitle => 'Tattoo artist';

  @override
  String get profileTattooArtistSubtitle =>
      'Bid on jobs and connect with customers';

  @override
  String get profileCustomerTitle => 'Customer';

  @override
  String get profileCustomerSubtitle => 'Post tattoo jobs and hire artists';

  @override
  String get profilePortfolioTitle => 'Portfolio';

  @override
  String profilePortfolioBlurb(int max) {
    return 'Add up to $max images for your public artist profile.';
  }

  @override
  String profileAddImageButton(int current, int max) {
    return 'Add image ($current/$max)';
  }

  @override
  String profilePortfolioLimitSnackbar(int remaining, int max) {
    return 'Only $remaining more image(s) allowed ($max max).';
  }

  @override
  String get profileContactSectionTitle => 'Contact';

  @override
  String get profileContactHelpArtist =>
      'Email and mobile are required. Shown to customers after a winning bid.';

  @override
  String get profileContactHelpCustomer => 'Email and mobile are required.';

  @override
  String get profileContactHelpNone =>
      'Email and mobile are required. Choose your account type above first.';

  @override
  String get profileEmailLabel => 'Email address';

  @override
  String get profileEmailHint => 'your.email@example.com';

  @override
  String get profileEnterEmail => 'Enter your email address';

  @override
  String get profileEnterValidEmail => 'Enter a valid email address';

  @override
  String get profileMobileLabel => 'Mobile number';

  @override
  String get profileMobileHint => 'Your phone number';

  @override
  String get profileEnterMobile => 'Enter your mobile number';

  @override
  String get profileMobileMaxLength => 'Max 40 characters';

  @override
  String get profileSave => 'Save';

  @override
  String get profileSelectUserTypeError =>
      'Please select Tattoo Artist or Customer';

  @override
  String get profilePhotoRequiredError =>
      'Please add a profile photo before saving.';

  @override
  String get profileCameraPermissionRequired =>
      'Camera permission is required to take a photo.';

  @override
  String get profileAvatarUploadDenied =>
      'Avatar upload denied. Ensure the \"avatars\" bucket exists and is public in Supabase Dashboard → Storage.';

  @override
  String get profileAccountTypeLockedSnackbar =>
      'Your account type can\'t be changed after it\'s saved.';

  @override
  String get profileEditContact => 'Edit contact';

  @override
  String get profileNotLoggedIn => 'Not logged in';

  @override
  String get bidDetailTitle => 'Request details';

  @override
  String bidDetailStartingBid(String amount) {
    return '$amount starting bid';
  }

  @override
  String get bidDetailHideDescription => 'Hide description';

  @override
  String get bidDetailWhatCustomerWants => 'What does the customer want?';

  @override
  String get bidDetailPlacement => 'Placement';

  @override
  String get bidDetailSize => 'Size';

  @override
  String get bidDetailColour => 'Colour';

  @override
  String get bidDetailColourFull => 'Colour';

  @override
  String get bidDetailColourBlackGrey => 'Black and grey';

  @override
  String get bidDetailTimeFrame => 'Time frame';

  @override
  String get bidDetailTimeframeAsap => 'ASAP';

  @override
  String get bidDetailTimeframeWeek => 'During the week';

  @override
  String get bidDetailTimeframeFlexible => 'Whenever you can book me in';

  @override
  String get bidDetailArtistCreativeFreedom => 'Artist has creative freedom';

  @override
  String get bidDetailNoDescription => 'No description provided.';

  @override
  String get bidDetailBids => 'Bids';

  @override
  String get bidDetailArtistToolsNotBidHint =>
      'Artist tools — bidding is not started from this button.';

  @override
  String get bidDetailOnlyArtistsMayBid =>
      'Only tattoo artists can place bids on requests.';

  @override
  String get bidDetailBiddingClosedMessage =>
      'Bidding is closed. This request is no longer accepting new bids.';

  @override
  String get bidDetailViewArtistTools => 'View Artist Tools';

  @override
  String get bidDetailBid => 'Bid';

  @override
  String get bidDetailCouldNotLoadBids => 'Could not load bids';

  @override
  String get bidDetailNoBidsYet => 'No bids yet';

  @override
  String get bidDetailLowest => 'Lowest';

  @override
  String get bidDetailArtistNameFallback => 'Artist';

  @override
  String get bidDetailChooseArtist => 'Choose artist';

  @override
  String get bidDetailPaid => 'Paid';

  @override
  String get bidDetailUnlockContact => 'Unlock Contact';

  @override
  String get bidDetailSectionArtistContact => 'Artist contact';

  @override
  String get bidDetailSectionDeposit => 'Deposit';

  @override
  String get bidDetailSectionConnect => 'Connect';

  @override
  String get bidDetailPaymentCompleteBody =>
      'Payment is marked complete. If contact is still locked, refresh — your unlock is stored after Stripe confirms.';

  @override
  String get bidDetailRefreshUnlockStatus => 'Refresh unlock status';

  @override
  String get bidDetailChooseWinningBidForDeposit =>
      'Choose a winning bid to see the deposit.';

  @override
  String get bidDetailChooseWinningBidToConnect =>
      'Choose a winning bid to connect with your artist.';

  @override
  String get bidDetailChooseWinningBidToChat =>
      'Choose a winning bid above. You can chat with your artist right away.';

  @override
  String bidDetailPhoneLine(String phone) {
    return 'Phone: $phone';
  }

  @override
  String bidDetailEmailLine(String email) {
    return 'Email: $email';
  }

  @override
  String get bidDetailChat => 'Chat';

  @override
  String bidDetailTotalPriceLine(String amount) {
    return 'Total price: $amount';
  }

  @override
  String bidDetailDepositLine(int percent, String amount) {
    return 'Deposit ($percent%): $amount';
  }

  @override
  String bidDetailRemainingLine(int percent, String amount) {
    return 'Remaining ($percent%): $amount';
  }

  @override
  String bidDetailPayDepositUnlock(int percent) {
    return 'Pay $percent% Deposit & Unlock Artist';
  }

  @override
  String get bidDetailPlaceBidTitle => 'Place bid';

  @override
  String get bidDetailYourPriceLabel => 'Your price (\$)';

  @override
  String get bidDetailEnterValidBidAmount => 'Enter a valid amount (0 or more)';

  @override
  String get bidDetailCancel => 'Cancel';

  @override
  String get bidDetailSubmit => 'Submit';

  @override
  String get bidDetailArtistToolsSheetTitle => 'Artist tools';

  @override
  String get bidDetailArtistToolsSheetBody =>
      'More artist actions for this job will appear here. This does not place a bid.';

  @override
  String get bidDetailCouldNotOpenProfile => 'Could not open this profile.';

  @override
  String get bidDetailRequestAlreadyCompleted =>
      'This request is already completed.';

  @override
  String bidDetailCouldNotUnlockContactDetails(String details) {
    return 'Could not unlock contact: $details';
  }

  @override
  String bidDetailCouldNotSelectBidDetails(String details) {
    return 'Could not select bid: $details';
  }

  @override
  String get bidDetailTapChooseArtistHint =>
      'Tap Choose artist on a bid to connect with your artist.';

  @override
  String get bidDetailPaymentAlreadyCompleted =>
      'Payment has already been completed for this request.';

  @override
  String get bidDetailMissingArtistForBid => 'Missing artist for this bid.';

  @override
  String bidDetailPaymentFailedDetails(String details) {
    return 'Payment failed: $details';
  }

  @override
  String get bidDetailCouldNotFindBidToPay => 'Could not find that bid to pay';

  @override
  String get bidDetailOnlyCustomerCanPay => 'Only the customer can pay';

  @override
  String get bidDetailCannotPlaceBid =>
      'You can\'t place a bid on this request.';

  @override
  String get bidDetailBiddingClosedSnackbar =>
      'Bidding is closed for this request.';

  @override
  String get bidDetailBidPlaced => 'Bid placed';

  @override
  String bidDetailFailedPlaceBidDetails(String details) {
    return 'Failed to place bid: $details';
  }
}
