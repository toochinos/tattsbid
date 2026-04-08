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
  String get tabUpload => 'Unggah';

  @override
  String get tabMessage => 'Pesan';

  @override
  String get tabProfile => 'Profil';

  @override
  String get exploreTitle => 'Jelajahi';

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
  String get profileTattooArtistTitle => 'Seniman tato';

  @override
  String get profileTattooArtistSubtitle =>
      'Ikut lelang pekerjaan dan terhubung dengan pelanggan';

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
  String bidDetailStartingBid(String amount) {
    return '$amount bid pembuka';
  }

  @override
  String get bidDetailHideDescription => 'Sembunyikan deskripsi';

  @override
  String get bidDetailWhatCustomerWants => 'Apa yang diinginkan pelanggan?';

  @override
  String get bidDetailPlacement => 'Penempatan';

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
      'Tindakan seniman lainnya untuk pekerjaan ini akan muncul di sini. Ini tidak mengajukan penawaran.';

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
}
