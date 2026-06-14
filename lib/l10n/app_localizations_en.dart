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
  String get tabTattsagram => 'Flexemo™';

  @override
  String get tabUpload => 'post a bid';

  @override
  String get tabPromo => 'promote';

  @override
  String get addPromoTitle => 'Promo';

  @override
  String get addPromoFieldDescriptionLabel => 'Describe this Tattoo';

  @override
  String get addPromoStartingBidLabel => 'This Tattoo (\$)';

  @override
  String get addPromoNextAvailabilityLabel => 'Availability';

  @override
  String get addPromoNextAvailabilityHint => 'e.g. Next week, 15 June';

  @override
  String get addPromoChatButton => 'Chat';

  @override
  String get tabMessage => 'Message';

  @override
  String get tabProfile => 'Profile';

  @override
  String get tattsagramEmptyTitle => 'No tattoos yet';

  @override
  String get tattsagramEmptySubtitle => 'Be the first to show your tattoo';

  @override
  String get tattsagramFabShowTattoo => 'Show your tattoo';

  @override
  String get dashboardTitle => 'Dashboard';

  @override
  String get dashboardPlaceholderBody => 'Dashboard page';

  @override
  String get exploreTitle => 'Explore';

  @override
  String get exploreSearchHint => 'Name, city, suburb...';

  @override
  String get exploreBidsNearMe => 'Bids near me';

  @override
  String get exploreNearMeNeedProfile =>
      'Add your city or suburb in your profile to use Bids near me.';

  @override
  String get exploreNoSearchResults => 'No posts match your search';

  @override
  String exploreArtistsInterested(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Artists Interested',
      one: '1 Artist Interested',
    );
    return '$_temp0';
  }

  @override
  String exploreCustomersInterested(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Customers Interested',
      one: '1 Customer Interested',
    );
    return '$_temp0';
  }

  @override
  String exploreReviewCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count reviews',
      one: '1 review',
    );
    return '($_temp0)';
  }

  @override
  String exploreBidBudget(String amount) {
    return 'Budget $amount';
  }

  @override
  String explorePromoPrice(String amount) {
    return 'This Tattoo $amount';
  }

  @override
  String get exploreBidCardTitleFallback => 'Tattoo request';

  @override
  String get explorePostedToday => 'Posted today';

  @override
  String explorePostedHoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Posted $count hours ago',
      one: 'Posted 1 hour ago',
    );
    return '$_temp0';
  }

  @override
  String explorePostedDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Posted $count days ago',
      one: 'Posted 1 day ago',
    );
    return '$_temp0';
  }

  @override
  String exploreTitleWithCountry(String country) {
    return 'Explore - $country';
  }

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
  String get addPostCountryMismatchTitle => 'You can\'t post here';

  @override
  String addPostCountryMismatchBody(String targetCountry) {
    return 'You can only post requests for the country where you live or stay. Your profile country does not match $targetCountry. Update where you are staying or living in your profile.';
  }

  @override
  String get addPostCountryMissingTitle => 'Country required';

  @override
  String get addPostCountryMissingBody =>
      'Add the country where you live or stay in your profile before you can post a request.';

  @override
  String get addPostCountryMismatchOk => 'OK';

  @override
  String get addPostNeedDestinationTitle => 'Select a country first';

  @override
  String get addPostNeedDestinationBody =>
      'Select a country from the globe on Explore before posting.';

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
  String get deleteAccountTitle => 'Delete account';

  @override
  String get deleteAccountWarningTitle => 'This action is permanent';

  @override
  String get deleteAccountWarningBody =>
      'Deleting your account will permanently remove your profile, tattoo listings, bids, promo posts, messages, reviews, favourites, uploaded images, and all other data linked to your account. This cannot be undone.';

  @override
  String get deleteAccountTypePrompt => 'Type DELETE to confirm';

  @override
  String get deleteAccountTypeHint => 'DELETE';

  @override
  String get deleteAccountConfirmButton => 'Permanently delete my account';

  @override
  String get deleteAccountDeleting => 'Deleting your account…';

  @override
  String get accountDeletionSuccessMessage =>
      'Your account has been permanently deleted. Thank you for using TattsBid.';

  @override
  String get settingsAccountDeleted => 'Account deleted';

  @override
  String settingsAccountDeleteFailed(String reason) {
    return 'Could not delete your account. $reason';
  }

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
  String get profileCountryLockedByPostsBody =>
      'You still have tattoo requests posted. Delete them from Explore before you can change your country.';

  @override
  String get profileCountryChangeBlockedError =>
      'Delete your posted requests before you can change country.';

  @override
  String get profileDisplayNameLockedHelper =>
      'Display name can\'t be changed after it\'s set.';

  @override
  String get profileDisplayNameImmutableError =>
      'Your display name can\'t be changed.';

  @override
  String get profileDisplayNameTakenError =>
      'That display name is already taken. Try another.';

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
  String get profileAccountTypeConfirmTitle => 'Confirm your account type';

  @override
  String profileAccountTypeConfirmBody(String accountType) {
    return 'Are you sure you want to register as $accountType?\n\nThis choice affects how you engage with other users. It cannot be changed after you save. Please choose carefully.';
  }

  @override
  String get profileAccountTypeConfirmCancel => 'Go back';

  @override
  String get profileAccountTypeConfirmContinue => 'Yes, continue';

  @override
  String get profileTattooArtistTitle => 'Tattoo artist';

  @override
  String get profileTattooArtistSubtitle =>
      'Post bids to advertise Artist Craftmanship as well as Bidding for jobs';

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
  String get bidDetailAppBarHomeTooltip => 'Home';

  @override
  String bidDetailStartingBid(String amount) {
    return '$amount starting bid';
  }

  @override
  String get bidDetailHideDescription => 'Hide description';

  @override
  String get bidDetailWhatCustomerWants => 'What does the customer want?';

  @override
  String get bidDetailAboutThisTattoo => 'About this Tattoo';

  @override
  String get bidDetailChatToThisArtist => 'Chat to the Artist';

  @override
  String get bidDetailPlacement => 'Placement';

  @override
  String get bidDetailNextAvailability => 'Availability';

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
  String get bidDetailBidCountryRequestMissingHint =>
      'This request has no country set. You can’t place a bid.';

  @override
  String get bidDetailBidCountryProfileMissingHint =>
      'Your profile has no country saved in the app. Open Profile → contact details, choose Country, tap Save, then try again.';

  @override
  String bidDetailBidCountryMismatchHint(
      String requestCountry, String profileCountry) {
    return 'You can only bid on requests in your country. This job is in $requestCountry; your profile country is $profileCountry.';
  }

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
      'Promote your work on Explore while you wait for the customer to review bids.';

  @override
  String get bidDetailArtistToolsPostPromo => 'Post a promo';

  @override
  String get bidDetailPostPromoTitle => 'Post a promo?';

  @override
  String get bidDetailPostPromoMessage =>
      'Share your tattoo work on Explore so customers can see your style alongside your bid.';

  @override
  String get bidDetailPostPromoOpen => 'Open promo page';

  @override
  String get bidDetailPostPromoLater => 'Not now';

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

  @override
  String get photoTakePhoto => 'Take a photo';

  @override
  String get photoFromGallery => 'Upload from gallery';

  @override
  String get tattsagramPhotoSharedInChat => '📷 Photo';

  @override
  String get tattsagramUploadingPhoto => 'Uploading photo…';

  @override
  String get tattsagramPhotoUploadFailed =>
      'Could not upload media. Sign in and try again.';

  @override
  String get destinationChooseTitle => 'Choose destination';

  @override
  String get destinationComingSoon => 'Coming soon';

  @override
  String get addTabTitle => 'Add';

  @override
  String get addUploading => 'Uploading...';

  @override
  String get addPhotoButton => 'Add photo';

  @override
  String get addHappyAddDetails => 'I\'m happy — add details';

  @override
  String get addChooseDifferentPhoto => 'Choose different photo';

  @override
  String get addDescriptionHint => 'Describe your vision...';

  @override
  String get addPlacementHint => 'Where on the body? (e.g. arm, back, leg)';

  @override
  String get addSizeHint => 'Small, medium, large, or dimensions';

  @override
  String get addColourChip => 'Colour';

  @override
  String get addBlackGreyChip => 'Black and grey';

  @override
  String get addTimeAsap => 'ASAP';

  @override
  String get addTimeWeek => 'During the week';

  @override
  String get addTimeBookWhen => 'Whenever you can book me in';

  @override
  String get addBidAmountHint => '0';

  @override
  String get addSubmitRequest => 'Submit request';

  @override
  String get addBackButton => 'Back';

  @override
  String get addAnotherRequest => 'Add another request';

  @override
  String get artistsDirectorySearchHint => 'Name, city, suburb, or country';

  @override
  String get artistsFilterRating => 'Rating';

  @override
  String get artistsFilterCleanliness => 'Cleanliness';

  @override
  String exploreDeleteFailedDetails(String details) {
    return 'Delete failed: $details';
  }

  @override
  String get exploreDeletePostTitle => 'Remove post?';

  @override
  String get exploreDeletePostMessage =>
      'This will permanently remove your post from Explore.';

  @override
  String get exploreDeletePostConfirm => 'Remove';

  @override
  String get exploreDeletePostCancel => 'Cancel';

  @override
  String get checkoutTitle => 'Checkout';

  @override
  String get checkoutContinue => 'Continue';

  @override
  String get checkoutCancelledMessage => 'Checkout was cancelled.';

  @override
  String get checkoutTryAgain => 'Try again';

  @override
  String get checkoutBackToDashboard => 'Back to dashboard';

  @override
  String get depositSummaryTitle => 'Deposit summary';

  @override
  String depositTotalCostLine(String amount) {
    return 'Total cost: $amount';
  }

  @override
  String depositArtistReceivesLine(String amount) {
    return 'Artist receives: $amount';
  }

  @override
  String get depositPayButton => 'Pay';

  @override
  String depositFeePercentLine(int percent, String amount) {
    return 'Deposit fee ($percent%): $amount';
  }

  @override
  String platformFeePaymentFailed(String error) {
    return 'Payment failed: $error';
  }

  @override
  String get cameraTitle => 'Camera';

  @override
  String cameraSwitchError(String error) {
    return 'Could not switch camera: $error';
  }

  @override
  String cameraCaptureError(String error) {
    return 'Failed to capture image: $error';
  }

  @override
  String get cameraNoDeviceAvailable => 'No camera available on this device.';

  @override
  String cameraInitFailed(String error) {
    return 'Failed to initialize camera: $error';
  }

  @override
  String get bidPageTitle => 'Bid';

  @override
  String get paywallSubscribeTitle => 'Subscribe';

  @override
  String get paywallSubscribeMonthly => 'Subscribe monthly';

  @override
  String get paywallFreePlanTitle => 'Free version';

  @override
  String get paywallProPlanTitle => 'Pro version';

  @override
  String get paywallProMaxPlanTitle => 'Pro Max';

  @override
  String get paywallProPlanSubtitle => '99¢ AUD monthly';

  @override
  String get paywallProMaxPlanSubtitle => '\$1.00 AUD monthly';

  @override
  String get welcomeGetStarted => 'Get started';

  @override
  String get welcomeSkip => 'Skip';

  @override
  String get editContactEmailHint => 'Your contact email';

  @override
  String get editContactPhoneHint => 'Your phone number';

  @override
  String get publicProfileCantChatSelf => 'You can\'t chat with yourself.';

  @override
  String get publicProfileReviewCommentRequired => 'Please write a comment.';

  @override
  String get publicProfileReviewSubmitError =>
      'Could not submit review right now. Please try again.';

  @override
  String get publicProfileChatButton => 'Chat';

  @override
  String get publicProfileChatWithArtist => 'Chat with artist';

  @override
  String get publicProfileReviewHint => 'Share your experience…';

  @override
  String get publicProfileSubmitReview => 'Submit review';

  @override
  String get publicProfileEmailTitle => 'Email';

  @override
  String get publicProfileMobileTitle => 'Mobile';

  @override
  String get publicProfileTitleFallback => 'Profile';

  @override
  String get publicProfileReviewSelectBoth =>
      'Please select both Rating and Cleanliness (1–5 stars each).';

  @override
  String get publicProfileReviewPostedThanks =>
      'Thanks — your review was posted.';

  @override
  String get publicProfileReviewUpdated =>
      'You have already reviewed this artist. Your review was updated.';

  @override
  String get publicProfileReviewAlreadyReviewedShort =>
      'You have already reviewed this artist';

  @override
  String get publicProfileReviewsHeading => 'Reviews';

  @override
  String get publicProfileNoReviewsYet => 'No reviews yet.';

  @override
  String get publicProfilePreviousReviews => 'Previous reviews';

  @override
  String publicProfileReviewsTileSubtitle(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count reviews · tap to expand',
      one: '$count review · tap to expand',
    );
    return '$_temp0';
  }

  @override
  String get publicProfileWriteReview => 'Write a review';

  @override
  String get publicProfileEditReview => 'Edit your review';

  @override
  String get publicProfileNoContactOnFile => 'No contact details on file.';

  @override
  String chatSendFailed(String error) {
    return 'Failed to send: $error';
  }

  @override
  String get chatMessageHint => 'Message (private)';

  @override
  String get chatMessageArtist => 'Message artist';

  @override
  String chatMobileLine(String phone) {
    return 'Mobile: $phone';
  }

  @override
  String chatEmailLine(String email) {
    return 'Email: $email';
  }

  @override
  String get chatInboxTitle => 'Message';

  @override
  String get chatPartnerFallbackTitle => 'Chat';

  @override
  String get chatPrivacyNotice =>
      'Messages between tattoo artists and customers only. Only you and this person can see these messages.';

  @override
  String get chatContactSectionTitle => 'Contact';

  @override
  String get chatSetupRequired =>
      'Chat setup required. Run the migration in supabase/apply_chat_messages.sql in your Supabase Dashboard (SQL Editor), then tap Retry.';

  @override
  String get chatEmptyConversation =>
      'No messages yet. Say hello — this conversation is only visible to you and the other person.';

  @override
  String get chatYourArtist => 'Your artist';

  @override
  String chatPhoneLine(String phone) {
    return 'Phone: $phone';
  }

  @override
  String get chatNoContactYet => 'No phone or email on file yet.';

  @override
  String get chatUnknownUser => 'User';

  @override
  String get chatInboxEmptyTitle => 'No conversations yet';

  @override
  String get chatInboxEmptyBody =>
      'Start a chat from a job or promo detail page — your conversations with artists and customers will appear here.';

  @override
  String get chatInboxUnlockTitle => 'Pay to unlock messaging';

  @override
  String get chatInboxUnlockBody =>
      'Complete the deposit from your request’s winning bid to unlock artist contact and chat.';

  @override
  String get chatPaidArtistBlurbLong =>
      'Deposit paid — you can message your artist or use their contact details below.';

  @override
  String get chatPaidArtistBlurbShort =>
      'Deposit paid — message your artist or use their contact details.';

  @override
  String get chatConversationsSection => 'Conversations';

  @override
  String get reviewRatingLabel => 'Rating';

  @override
  String get reviewCleanlinessLabel => 'Cleanliness';

  @override
  String get userAgreementTitle => 'TattsBid user agreement';

  @override
  String get userAgreementAcceptTerms => 'I agree to the TattsBid terms';

  @override
  String get userAgreementContinue => 'Continue';

  @override
  String userAgreementSaveError(String error) {
    return 'Could not save agreement: $error';
  }

  @override
  String get addReferencePhotoTitle => 'Add a reference photo';

  @override
  String get addReferencePhotoSubtitle =>
      'Take a photo or choose from your gallery';

  @override
  String get addPhotoUploadedTitle => 'Photo uploaded successfully';

  @override
  String get addPhotoUploadedSubtitle =>
      'Happy with this photo? Add a description and starting bid.';

  @override
  String get addDescriptionSectionTitle => 'Description';

  @override
  String get addFieldDescriptionLabel => 'What do you want for your tattoo?';

  @override
  String get addFieldPlacementLabel => 'Placement';

  @override
  String get addFieldSizeLabel => 'Size';

  @override
  String get addSectionColourTitle => 'Colour or black and grey';

  @override
  String get addSectionTimeframeTitle => 'Time frame';

  @override
  String get addCreativeFreedomTitle =>
      'Allow the artist to have creative freedom';

  @override
  String get addStartingBidLabel => 'Starting bid (\$)';

  @override
  String get addInvalidBidAmount => 'Enter a valid amount (0 or more)';

  @override
  String get addSubmittedTitle => 'Request submitted!';

  @override
  String get addSubmittedSubtitle =>
      'Artists can now view your request and place bids.';

  @override
  String get artistsNearMeButton => 'Artist near me';

  @override
  String artistsShowingInLocation(String location) {
    return 'Showing artists in $location';
  }

  @override
  String get artistsClearSearchTooltip => 'Clear search';
}
