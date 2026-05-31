// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Indonesian (`id`).
class AppLocalizationsId extends AppLocalizations {
  AppLocalizationsId([String locale = 'id']) : super(locale);

  @override
  String get tabExplore => 'Jelajahi';

  @override
  String get tabArtists => 'Seniman';

  @override
  String get tabTattsagram => 'Flexemo™';

  @override
  String get tabUpload => 'Buat bid';

  @override
  String get tabPromo => 'promosikan';

  @override
  String get addPromoTitle => 'Promo';

  @override
  String get addPromoFieldDescriptionLabel => 'Deskripsikan tato ini';

  @override
  String get addPromoStartingBidLabel => 'Tato ini (\$)';

  @override
  String get addPromoNextAvailabilityLabel => 'Ketersediaan';

  @override
  String get addPromoNextAvailabilityHint => 'mis. Minggu depan, 15 Juni';

  @override
  String get addPromoChatButton => 'Obrolan';

  @override
  String get tabMessage => 'Pesan';

  @override
  String get tabProfile => 'Profil';

  @override
  String get tattsagramEmptyTitle => 'Belum ada tato';

  @override
  String get tattsagramEmptySubtitle =>
      'Jadilah yang pertama menampilkan tato Anda';

  @override
  String get tattsagramFabShowTattoo => 'Tampilkan tato Anda';

  @override
  String get dashboardTitle => 'Dasbor';

  @override
  String get dashboardPlaceholderBody => 'Halaman dasbor';

  @override
  String get exploreTitle => 'Jelajahi';

  @override
  String get exploreSearchHint => 'Nama, kota, kecamatan...';

  @override
  String get exploreBidsNearMe => 'Penawaran di dekat saya';

  @override
  String get exploreNearMeNeedProfile =>
      'Tambahkan kota atau kecamatan di profil Anda untuk memakai Penawaran di dekat saya.';

  @override
  String get exploreNoSearchResults => 'Tidak ada postingan yang cocok';

  @override
  String exploreArtistsInterested(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Seniman tertarik',
      one: '1 Seniman tertarik',
    );
    return '$_temp0';
  }

  @override
  String exploreCustomersInterested(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Pelanggan tertarik',
      one: '1 Pelanggan tertarik',
    );
    return '$_temp0';
  }

  @override
  String exploreReviewCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ulasan',
      one: '1 ulasan',
    );
    return '($_temp0)';
  }

  @override
  String exploreBidBudget(String amount) {
    return 'Anggaran $amount';
  }

  @override
  String explorePromoPrice(String amount) {
    return 'Tato ini $amount';
  }

  @override
  String get exploreBidCardTitleFallback => 'Permintaan tato';

  @override
  String get explorePostedToday => 'Diposting hari ini';

  @override
  String explorePostedHoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Diposting $count jam lalu',
      one: 'Diposting 1 jam lalu',
    );
    return '$_temp0';
  }

  @override
  String explorePostedDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Diposting $count hari lalu',
      one: 'Diposting 1 hari lalu',
    );
    return '$_temp0';
  }

  @override
  String exploreTitleWithCountry(String country) {
    return 'Jelajahi - $country';
  }

  @override
  String postedOnDate(String date) {
    return 'Diposting $date';
  }

  @override
  String requestBidsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count penawaran',
      one: '$count penawaran',
      zero: '$count penawaran',
    );
    return '$_temp0';
  }

  @override
  String get bidClosed => 'Penawaran ditutup';

  @override
  String get noTattooRequestsYet => 'Belum ada permintaan tato';

  @override
  String get addRequestToSeeHere =>
      'Tambah permintaan untuk melihatnya di sini';

  @override
  String get addPostCountryMismatchTitle => 'Tidak bisa posting di sini';

  @override
  String addPostCountryMismatchBody(String targetCountry) {
    return 'Anda hanya bisa memposting untuk negara tempat Anda tinggal. Negara di profil Anda tidak cocok dengan $targetCountry. Perbarui tempat tinggal Anda di profil.';
  }

  @override
  String get addPostCountryMissingTitle => 'Negara wajib';

  @override
  String get addPostCountryMissingBody =>
      'Tambahkan negara tempat Anda tinggal di profil sebelum memposting permintaan.';

  @override
  String get addPostCountryMismatchOk => 'Oke';

  @override
  String get addPostNeedDestinationTitle => 'Pilih negara dulu';

  @override
  String get addPostNeedDestinationBody =>
      'Pilih negara dari ikon globe di Jelajahi sebelum memposting.';

  @override
  String get retry => 'Coba lagi';

  @override
  String get actionTooltipExplore => 'Jelajahi';

  @override
  String get actionTooltipSettings => 'Pengaturan';

  @override
  String get languagePickerTitle => 'Pilih bahasa';

  @override
  String get languagePickerSubtitle => 'Pilih bahasa untuk melanjutkan';

  @override
  String get languageEnglish => 'Inggris';

  @override
  String get languageKhmer => 'Khmer';

  @override
  String get languageIndonesian => 'Indonesia';

  @override
  String get settingsTitle => 'Pengaturan';

  @override
  String get settingsLightMode => 'Mode terang';

  @override
  String get settingsDarkMode => 'Mode gelap';

  @override
  String get settingsToggleTheme => 'Ubah tema aplikasi';

  @override
  String get settingsLanguage => 'Bahasa';

  @override
  String get settingsLanguageSubtitle => 'Ubah bahasa aplikasi';

  @override
  String get settingsSignOut => 'Keluar';

  @override
  String get settingsDangerZone => 'Zona bahaya';

  @override
  String get settingsDeleteAccount => 'Hapus akun';

  @override
  String get settingsAccountDeleted => 'Akun dihapus';

  @override
  String settingsAccountDeleteFailed(String reason) {
    return 'Tidak dapat menghapus akun. $reason';
  }

  @override
  String appVersionLabel(String version) {
    return 'Versi $version';
  }

  @override
  String get authTitle => 'Akun';

  @override
  String get authTabLogin => 'Masuk';

  @override
  String get authTabSignUp => 'Daftar';

  @override
  String get authEmailLabel => 'Email';

  @override
  String get authPasswordLabel => 'Kata sandi';

  @override
  String get authReenterPasswordLabel => 'Ulangi kata sandi';

  @override
  String get authSignIn => 'Masuk';

  @override
  String get authCreateAccount => 'Buat akun';

  @override
  String get authEnterEmail => 'Masukkan email Anda';

  @override
  String get authEnterPassword => 'Masukkan kata sandi';

  @override
  String get authEnterPasswordSignUp => 'Masukkan kata sandi';

  @override
  String get authPasswordMinLength => 'Kata sandi minimal 6 karakter';

  @override
  String get authReenterPasswordError => 'Ulangi kata sandi Anda';

  @override
  String get authPasswordsDoNotMatch => 'Kata sandi tidak cocok';

  @override
  String get profileContactDetailsTitle => 'Detail kontak';

  @override
  String get profileTapToChangePhoto => 'Ketuk untuk mengganti foto';

  @override
  String get profileAddPhotoRequired => 'Tambahkan foto profil (wajib)';

  @override
  String get profileUploading => 'Mengunggah...';

  @override
  String get profileDisplayNameLabel => 'Nama tampilan';

  @override
  String get profileDisplayNameHint => 'Nama tampilan Anda';

  @override
  String get profileEnterDisplayName => 'Masukkan nama tampilan';

  @override
  String get profileNameMaxLength => 'Nama maksimal 100 karakter';

  @override
  String get profileCountryLabel => 'Negara';

  @override
  String get profileSelectCountry => 'Pilih negara';

  @override
  String get profileCountryLockedByPostsBody =>
      'Anda masih memiliki permintaan tato yang diposting. Hapus dari Jelajahi sebelum mengubah negara.';

  @override
  String get profileCountryChangeBlockedError =>
      'Hapus permintaan yang diposting sebelum mengubah negara.';

  @override
  String get profileDisplayNameLockedHelper =>
      'Nama tampilan tidak dapat diubah setelah ditetapkan.';

  @override
  String get profileDisplayNameImmutableError =>
      'Nama tampilan Anda tidak dapat diubah.';

  @override
  String get profileDisplayNameTakenError =>
      'Nama tampilan itu sudah dipakai. Coba yang lain.';

  @override
  String get profileCityLabel => 'Kota';

  @override
  String get profileSelectCity => 'Pilih kota';

  @override
  String get profileSuburbOptionalLabel => 'Wilayah pinggiran (opsional)';

  @override
  String get profileSuburbHint => 'Masukkan wilayah pinggiran';

  @override
  String get profileSuburbPickSuggestion => 'Atau pilih saran di bawah';

  @override
  String get profileSuburbMaxLength =>
      'Wilayah pinggiran maksimal 100 karakter';

  @override
  String get profileSuggestedSuburbsLabel =>
      'Wilayah pinggiran yang disarankan (opsional)';

  @override
  String get profileSuggestedSuburbsHelper =>
      'Ketuk untuk mengisi kolom wilayah di atas; Anda dapat mengeditnya';

  @override
  String get profilePickSuggestedSuburb => 'Pilih wilayah yang disarankan';

  @override
  String get profileChooseAccountType => 'Pilih jenis akun Anda';

  @override
  String get profileAccountTypeCanChange =>
      'Ketuk Seniman tato atau Pelanggan di bawah. Anda dapat mengganti pilihan sampai mengetuk Simpan — setelah itu, jenis akun Anda permanen dan tidak dapat diubah.';

  @override
  String get profileAccountTypeLocked =>
      'Jenis akun Anda sudah ditetapkan dan tidak dapat diubah.';

  @override
  String get profileAccountTypeConfirmTitle => 'Konfirmasi jenis akun';

  @override
  String profileAccountTypeConfirmBody(String accountType) {
    return 'Apakah Anda yakin ingin mendaftar sebagai $accountType?\n\nPilihan ini memengaruhi cara Anda berinteraksi dengan pengguna lain. Tidak dapat diubah setelah disimpan. Pilihlah dengan benar.';
  }

  @override
  String get profileAccountTypeConfirmCancel => 'Kembali';

  @override
  String get profileAccountTypeConfirmContinue => 'Ya, lanjutkan';

  @override
  String get profileTattooArtistTitle => 'Seniman tato';

  @override
  String get profileTattooArtistSubtitle =>
      'Posting penawaran untuk mempromosikan keterampilan seni seniman sekaligus menawar pekerjaan';

  @override
  String get profileCustomerTitle => 'Pelanggan';

  @override
  String get profileCustomerSubtitle =>
      'Pasang pekerjaan tato dan sewa seniman';

  @override
  String get profilePortfolioTitle => 'Portofolio';

  @override
  String profilePortfolioBlurb(int max) {
    return 'Tambahkan hingga $max gambar untuk profil seniman publik Anda.';
  }

  @override
  String profileAddImageButton(int current, int max) {
    return 'Tambah gambar ($current/$max)';
  }

  @override
  String profilePortfolioLimitSnackbar(int remaining, int max) {
    return 'Hanya $remaining gambar lagi yang diizinkan (maks. $max).';
  }

  @override
  String get profileContactSectionTitle => 'Kontak';

  @override
  String get profileContactHelpArtist =>
      'Email dan nomor ponsel wajib. Ditampilkan kepada pelanggan setelah menang lelang.';

  @override
  String get profileContactHelpCustomer => 'Email dan nomor ponsel wajib.';

  @override
  String get profileContactHelpNone =>
      'Email dan nomor ponsel wajib. Pilih jenis akun di atas terlebih dahulu.';

  @override
  String get profileEmailLabel => 'Alamat email';

  @override
  String get profileEmailHint => 'email.anda@contoh.com';

  @override
  String get profileEnterEmail => 'Masukkan alamat email';

  @override
  String get profileEnterValidEmail => 'Masukkan alamat email yang valid';

  @override
  String get profileMobileLabel => 'Nomor ponsel';

  @override
  String get profileMobileHint => 'Nomor telepon Anda';

  @override
  String get profileEnterMobile => 'Masukkan nomor ponsel';

  @override
  String get profileMobileMaxLength => 'Maks. 40 karakter';

  @override
  String get profileSave => 'Simpan';

  @override
  String get profileSelectUserTypeError => 'Pilih Seniman Tato atau Pelanggan';

  @override
  String get profilePhotoRequiredError =>
      'Tambahkan foto profil sebelum menyimpan.';

  @override
  String get profileCameraPermissionRequired =>
      'Izin kamera diperlukan untuk mengambil foto.';

  @override
  String get profileAvatarUploadDenied =>
      'Unggah avatar ditolak. Pastikan bucket \"avatars\" ada dan publik di Supabase Dashboard → Storage.';

  @override
  String get profileAccountTypeLockedSnackbar =>
      'Jenis akun tidak dapat diubah setelah disimpan.';

  @override
  String get profileEditContact => 'Edit kontak';

  @override
  String get profileNotLoggedIn => 'Belum masuk';

  @override
  String get bidDetailTitle => 'Detail permintaan';

  @override
  String get bidDetailAppBarHomeTooltip => 'Beranda';

  @override
  String bidDetailStartingBid(String amount) {
    return '$amount bid pembuka';
  }

  @override
  String get bidDetailHideDescription => 'Sembunyikan deskripsi';

  @override
  String get bidDetailWhatCustomerWants => 'Apa yang diinginkan pelanggan?';

  @override
  String get bidDetailAboutThisTattoo => 'Tentang tato ini';

  @override
  String get bidDetailChatToThisArtist => 'Obrolan ke seniman ini';

  @override
  String get bidDetailPlacement => 'Penempatan';

  @override
  String get bidDetailNextAvailability => 'Ketersediaan';

  @override
  String get bidDetailSize => 'Ukuran';

  @override
  String get bidDetailColour => 'Warna';

  @override
  String get bidDetailColourFull => 'Berwarna';

  @override
  String get bidDetailColourBlackGrey => 'Hitam dan abu-abu';

  @override
  String get bidDetailTimeFrame => 'Jangka waktu';

  @override
  String get bidDetailTimeframeAsap => 'Sesegera mungkin';

  @override
  String get bidDetailTimeframeWeek => 'Selama hari kerja';

  @override
  String get bidDetailTimeframeFlexible => 'Kapan saja bisa memesan';

  @override
  String get bidDetailArtistCreativeFreedom => 'Seniman bebas berkreasi';

  @override
  String get bidDetailNoDescription => 'Tidak ada deskripsi.';

  @override
  String get bidDetailBids => 'Penawaran';

  @override
  String get bidDetailArtistToolsNotBidHint =>
      'Alat seniman — penawaran tidak dimulai dari tombol ini.';

  @override
  String get bidDetailOnlyArtistsMayBid =>
      'Hanya seniman tato yang dapat mengajukan penawaran.';

  @override
  String get bidDetailBidCountryRequestMissingHint =>
      'Permintaan ini tidak memiliki negara. Anda tidak dapat mengajukan penawaran.';

  @override
  String get bidDetailBidCountryProfileMissingHint =>
      'Profil Anda belum menyimpan negara. Buka Profil → detail kontak, pilih Negara, ketuk Simpan, lalu coba lagi.';

  @override
  String bidDetailBidCountryMismatchHint(
      String requestCountry, String profileCountry) {
    return 'Anda hanya dapat menawar permintaan di negara Anda. Pekerjaan ini di $requestCountry; negara profil Anda adalah $profileCountry.';
  }

  @override
  String get bidDetailBiddingClosedMessage =>
      'Penawaran ditutup. Permintaan ini tidak lagi menerima penawaran baru.';

  @override
  String get bidDetailViewArtistTools => 'Lihat alat seniman';

  @override
  String get bidDetailBid => 'Tawar';

  @override
  String get bidDetailCouldNotLoadBids => 'Tidak dapat memuat penawaran';

  @override
  String get bidDetailNoBidsYet => 'Belum ada penawaran';

  @override
  String get bidDetailLowest => 'Terendah';

  @override
  String get bidDetailArtistNameFallback => 'Seniman';

  @override
  String get bidDetailChooseArtist => 'Pilih seniman';

  @override
  String get bidDetailPaid => 'Dibayar';

  @override
  String get bidDetailUnlockContact => 'Buka kontak';

  @override
  String get bidDetailSectionArtistContact => 'Kontak seniman';

  @override
  String get bidDetailSectionDeposit => 'Deposit';

  @override
  String get bidDetailSectionConnect => 'Hubungkan';

  @override
  String get bidDetailPaymentCompleteBody =>
      'Pembayaran ditandai selesai. Jika kontak masih terkunci, segarkan — pembukaan kontak Anda disimpan setelah Stripe mengonfirmasi.';

  @override
  String get bidDetailRefreshUnlockStatus => 'Segarkan status buka kunci';

  @override
  String get bidDetailChooseWinningBidForDeposit =>
      'Pilih penawaran menang untuk melihat deposit.';

  @override
  String get bidDetailChooseWinningBidToConnect =>
      'Pilih penawaran menang untuk terhubung dengan seniman Anda.';

  @override
  String get bidDetailChooseWinningBidToChat =>
      'Pilih penawaran menang di atas. Anda dapat langsung mengobrol dengan seniman Anda.';

  @override
  String bidDetailPhoneLine(String phone) {
    return 'Telepon: $phone';
  }

  @override
  String bidDetailEmailLine(String email) {
    return 'Email: $email';
  }

  @override
  String get bidDetailChat => 'Obrolan';

  @override
  String bidDetailTotalPriceLine(String amount) {
    return 'Total harga: $amount';
  }

  @override
  String bidDetailDepositLine(int percent, String amount) {
    return 'Deposit ($percent%): $amount';
  }

  @override
  String bidDetailRemainingLine(int percent, String amount) {
    return 'Sisa ($percent%): $amount';
  }

  @override
  String bidDetailPayDepositUnlock(int percent) {
    return 'Bayar Deposit $percent% & buka kontak seniman';
  }

  @override
  String get bidDetailPlaceBidTitle => 'Ajukan penawaran';

  @override
  String get bidDetailYourPriceLabel => 'Harga Anda (\$)';

  @override
  String get bidDetailEnterValidBidAmount =>
      'Masukkan jumlah yang valid (0 atau lebih)';

  @override
  String get bidDetailCancel => 'Batal';

  @override
  String get bidDetailSubmit => 'Kirim';

  @override
  String get bidDetailArtistToolsSheetTitle => 'Alat seniman';

  @override
  String get bidDetailArtistToolsSheetBody =>
      'Promosikan karya Anda di Explore sambil menunggu pelanggan meninjau penawaran.';

  @override
  String get bidDetailArtistToolsPostPromo => 'Posting promo';

  @override
  String get bidDetailPostPromoTitle => 'Posting promo?';

  @override
  String get bidDetailPostPromoMessage =>
      'Bagikan karya tattoo Anda di Explore agar pelanggan melihat gaya Anda bersama penawaran Anda.';

  @override
  String get bidDetailPostPromoOpen => 'Buka halaman promo';

  @override
  String get bidDetailPostPromoLater => 'Nanti saja';

  @override
  String get bidDetailCouldNotOpenProfile => 'Tidak dapat membuka profil ini.';

  @override
  String get bidDetailRequestAlreadyCompleted =>
      'Permintaan ini sudah selesai.';

  @override
  String bidDetailCouldNotUnlockContactDetails(String details) {
    return 'Tidak dapat membuka kontak: $details';
  }

  @override
  String bidDetailCouldNotSelectBidDetails(String details) {
    return 'Tidak dapat memilih penawaran: $details';
  }

  @override
  String get bidDetailTapChooseArtistHint =>
      'Ketuk Pilih seniman pada sebuah penawaran untuk terhubung dengan seniman Anda.';

  @override
  String get bidDetailPaymentAlreadyCompleted =>
      'Pembayaran untuk permintaan ini sudah selesai.';

  @override
  String get bidDetailMissingArtistForBid =>
      'Seniman untuk penawaran ini tidak ada.';

  @override
  String bidDetailPaymentFailedDetails(String details) {
    return 'Pembayaran gagal: $details';
  }

  @override
  String get bidDetailCouldNotFindBidToPay =>
      'Tidak menemukan penawaran itu untuk dibayar';

  @override
  String get bidDetailOnlyCustomerCanPay =>
      'Hanya pelanggan yang dapat membayar';

  @override
  String get bidDetailCannotPlaceBid =>
      'Anda tidak dapat mengajukan penawaran untuk permintaan ini.';

  @override
  String get bidDetailBiddingClosedSnackbar =>
      'Penawaran ditutup untuk permintaan ini.';

  @override
  String get bidDetailBidPlaced => 'Penawaran diajukan';

  @override
  String bidDetailFailedPlaceBidDetails(String details) {
    return 'Gagal mengajukan penawaran: $details';
  }

  @override
  String get photoTakePhoto => 'Ambil foto';

  @override
  String get photoFromGallery => 'Unggah dari galeri';

  @override
  String get tattsagramPhotoSharedInChat => '📷 Foto';

  @override
  String get tattsagramUploadingPhoto => 'Mengunggah foto…';

  @override
  String get tattsagramPhotoUploadFailed =>
      'Tidak dapat mengunggah media. Masuk dan coba lagi.';

  @override
  String get destinationChooseTitle => 'Pilih tujuan';

  @override
  String get destinationComingSoon => 'Segera hadir';

  @override
  String get addTabTitle => 'Tambah';

  @override
  String get addUploading => 'Mengunggah...';

  @override
  String get addPhotoButton => 'Tambah foto';

  @override
  String get addHappyAddDetails => 'Saya puas — tambah detail';

  @override
  String get addChooseDifferentPhoto => 'Pilih foto lain';

  @override
  String get addDescriptionHint => 'Jelaskan visi Anda...';

  @override
  String get addPlacementHint =>
      'Di bagian tubuh mana? (mis. lengan, punggung, kaki)';

  @override
  String get addSizeHint => 'Kecil, sedang, besar, atau ukuran';

  @override
  String get addColourChip => 'Warna';

  @override
  String get addBlackGreyChip => 'Hitam putih';

  @override
  String get addTimeAsap => 'Sesegera mungkin';

  @override
  String get addTimeWeek => 'Selama minggu ini';

  @override
  String get addTimeBookWhen => 'Kapan Anda bisa membooking saya';

  @override
  String get addBidAmountHint => '0';

  @override
  String get addSubmitRequest => 'Kirim permintaan';

  @override
  String get addBackButton => 'Kembali';

  @override
  String get addAnotherRequest => 'Tambah permintaan lain';

  @override
  String get artistsDirectorySearchHint => 'Nama, kota, kecamatan, atau negara';

  @override
  String get artistsFilterRating => 'Rating';

  @override
  String get artistsFilterCleanliness => 'Kebersihan';

  @override
  String exploreDeleteFailedDetails(String details) {
    return 'Gagal menghapus: $details';
  }

  @override
  String get exploreDeletePostTitle => 'Hapus posting?';

  @override
  String get exploreDeletePostMessage =>
      'Posting ini akan dihapus permanen dari Explore.';

  @override
  String get exploreDeletePostConfirm => 'Hapus';

  @override
  String get exploreDeletePostCancel => 'Batal';

  @override
  String get checkoutTitle => 'Checkout';

  @override
  String get checkoutContinue => 'Lanjutkan';

  @override
  String get checkoutCancelledMessage => 'Checkout dibatalkan.';

  @override
  String get checkoutTryAgain => 'Coba lagi';

  @override
  String get checkoutBackToDashboard => 'Kembali ke dasbor';

  @override
  String get depositSummaryTitle => 'Ringkasan deposit';

  @override
  String depositTotalCostLine(String amount) {
    return 'Total biaya: $amount';
  }

  @override
  String depositArtistReceivesLine(String amount) {
    return 'Seniman menerima: $amount';
  }

  @override
  String get depositPayButton => 'Bayar';

  @override
  String depositFeePercentLine(int percent, String amount) {
    return 'Biaya deposit ($percent%): $amount';
  }

  @override
  String platformFeePaymentFailed(String error) {
    return 'Pembayaran gagal: $error';
  }

  @override
  String get cameraTitle => 'Kamera';

  @override
  String cameraSwitchError(String error) {
    return 'Tidak dapat mengganti kamera: $error';
  }

  @override
  String cameraCaptureError(String error) {
    return 'Gagal mengambil gambar: $error';
  }

  @override
  String get cameraNoDeviceAvailable => 'Tidak ada kamera di perangkat ini.';

  @override
  String cameraInitFailed(String error) {
    return 'Gagal menginisialisasi kamera: $error';
  }

  @override
  String get bidPageTitle => 'Penawaran';

  @override
  String get paywallSubscribeTitle => 'Berlangganan';

  @override
  String get paywallSubscribeMonthly => 'Berlangganan bulanan';

  @override
  String get paywallFreePlanTitle => 'Versi gratis';

  @override
  String get paywallProPlanTitle => 'Versi Pro';

  @override
  String get paywallProMaxPlanTitle => 'Pro Max';

  @override
  String get paywallProPlanSubtitle => '99¢ AUD per bulan';

  @override
  String get paywallProMaxPlanSubtitle => '\$1,00 AUD per bulan';

  @override
  String get welcomeGetStarted => 'Mulai';

  @override
  String get welcomeSkip => 'Lewati';

  @override
  String get editContactEmailHint => 'Email kontak Anda';

  @override
  String get editContactPhoneHint => 'Nomor telepon Anda';

  @override
  String get publicProfileCantChatSelf =>
      'Anda tidak dapat mengobrol dengan diri sendiri.';

  @override
  String get publicProfileReviewCommentRequired => 'Silakan tulis komentar.';

  @override
  String get publicProfileReviewSubmitError =>
      'Tidak dapat mengirim ulasan sekarang. Coba lagi.';

  @override
  String get publicProfileChatButton => 'Obrolan';

  @override
  String get publicProfileChatWithArtist => 'Obrolan dengan seniman';

  @override
  String get publicProfileReviewHint => 'Bagikan pengalaman Anda…';

  @override
  String get publicProfileSubmitReview => 'Kirim ulasan';

  @override
  String get publicProfileEmailTitle => 'Email';

  @override
  String get publicProfileMobileTitle => 'Ponsel';

  @override
  String get publicProfileTitleFallback => 'Profil';

  @override
  String get publicProfileReviewSelectBoth =>
      'Pilih Rating dan Kebersihan (masing-masing 1–5 bintang).';

  @override
  String get publicProfileReviewPostedThanks =>
      'Terima kasih — ulasan Anda telah dipublikasikan.';

  @override
  String get publicProfileReviewUpdated =>
      'Anda sudah mengulas seniman ini. Ulasan Anda telah diperbarui.';

  @override
  String get publicProfileReviewAlreadyReviewedShort =>
      'Anda sudah mengulas seniman ini';

  @override
  String get publicProfileReviewsHeading => 'Ulasan';

  @override
  String get publicProfileNoReviewsYet => 'Belum ada ulasan.';

  @override
  String get publicProfilePreviousReviews => 'Ulasan sebelumnya';

  @override
  String publicProfileReviewsTileSubtitle(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ulasan · ketuk untuk memperluas',
      one: '$count ulasan · ketuk untuk memperluas',
    );
    return '$_temp0';
  }

  @override
  String get publicProfileWriteReview => 'Tulis ulasan';

  @override
  String get publicProfileEditReview => 'Edit ulasan Anda';

  @override
  String get publicProfileNoContactOnFile => 'Tidak ada detail kontak.';

  @override
  String chatSendFailed(String error) {
    return 'Gagal mengirim: $error';
  }

  @override
  String get chatMessageHint => 'Pesan (pribadi)';

  @override
  String get chatMessageArtist => 'Pesan seniman';

  @override
  String chatMobileLine(String phone) {
    return 'Ponsel: $phone';
  }

  @override
  String chatEmailLine(String email) {
    return 'Email: $email';
  }

  @override
  String get chatInboxTitle => 'Pesan';

  @override
  String get chatPartnerFallbackTitle => 'Obrolan';

  @override
  String get chatPrivacyNotice =>
      'Pesan hanya untuk seniman tato dan pelanggan. Hanya Anda dan orang ini yang dapat melihat pesan ini.';

  @override
  String get chatContactSectionTitle => 'Kontak';

  @override
  String get chatSetupRequired =>
      'Pengaturan chat diperlukan. Jalankan migrasi di supabase/apply_chat_messages.sql di Dashboard Supabase Anda (SQL Editor), lalu ketuk Coba lagi.';

  @override
  String get chatEmptyConversation =>
      'Belum ada pesan. Sapa — percakapan ini hanya terlihat oleh Anda dan orang lain.';

  @override
  String get chatYourArtist => 'Seniman Anda';

  @override
  String chatPhoneLine(String phone) {
    return 'Telepon: $phone';
  }

  @override
  String get chatNoContactYet => 'Belum ada telepon atau email.';

  @override
  String get chatUnknownUser => 'Pengguna';

  @override
  String get chatInboxEmptyTitle => 'Belum ada percakapan';

  @override
  String get chatInboxEmptyBody =>
      'Obrolan dari Jelajahi (pelanggan memulai pesan) muncul di sini. Setelah Anda membayar deposit pada penawaran yang menang, layar ini menampilkan detail kontak seniman dan tombol untuk mulai mengirim pesan.';

  @override
  String get chatInboxUnlockTitle => 'Bayar untuk membuka pesan';

  @override
  String get chatInboxUnlockBody =>
      'Selesaikan deposit dari penawaran yang menang pada permintaan Anda untuk membuka kontak seniman dan obrolan.';

  @override
  String get chatPaidArtistBlurbLong =>
      'Deposit dibayar — Anda dapat mengirim pesan ke seniman atau menggunakan detail kontak mereka di bawah.';

  @override
  String get chatPaidArtistBlurbShort =>
      'Deposit dibayar — kirim pesan ke seniman atau gunakan detail kontak mereka.';

  @override
  String get chatConversationsSection => 'Percakapan';

  @override
  String get reviewRatingLabel => 'Rating';

  @override
  String get reviewCleanlinessLabel => 'Kebersihan';

  @override
  String get userAgreementTitle => 'Perjanjian pengguna TattsBid';

  @override
  String get userAgreementAcceptTerms => 'Saya setuju dengan syarat TattsBid';

  @override
  String get userAgreementContinue => 'Lanjutkan';

  @override
  String userAgreementSaveError(String error) {
    return 'Tidak dapat menyimpan perjanjian: $error';
  }

  @override
  String get addReferencePhotoTitle => 'Tambah foto referensi';

  @override
  String get addReferencePhotoSubtitle => 'Ambil foto atau pilih dari galeri';

  @override
  String get addPhotoUploadedTitle => 'Foto berhasil diunggah';

  @override
  String get addPhotoUploadedSubtitle =>
      'Puas dengan foto ini? Tambahkan deskripsi dan penawaran awal.';

  @override
  String get addDescriptionSectionTitle => 'Deskripsi';

  @override
  String get addFieldDescriptionLabel =>
      'Apa yang Anda inginkan untuk tato Anda?';

  @override
  String get addFieldPlacementLabel => 'Penempatan';

  @override
  String get addFieldSizeLabel => 'Ukuran';

  @override
  String get addSectionColourTitle => 'Warna atau hitam putih';

  @override
  String get addSectionTimeframeTitle => 'Jangka waktu';

  @override
  String get addCreativeFreedomTitle => 'Izinkan seniman berkreasi';

  @override
  String get addStartingBidLabel => 'Penawaran awal (\$)';

  @override
  String get addInvalidBidAmount => 'Masukkan jumlah yang valid (0 atau lebih)';

  @override
  String get addSubmittedTitle => 'Permintaan dikirim!';

  @override
  String get addSubmittedSubtitle =>
      'Seniman sekarang dapat melihat permintaan Anda dan mengajukan penawaran.';

  @override
  String get artistsNearMeButton => 'Seniman di dekat saya';

  @override
  String artistsShowingInLocation(String location) {
    return 'Menampilkan seniman di $location';
  }

  @override
  String get artistsClearSearchTooltip => 'Hapus pencarian';
}
