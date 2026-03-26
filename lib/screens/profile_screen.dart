import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../core/routes/app_routes.dart';
import '../core/services/profile_service.dart';
import '../core/utils/pick_images.dart';
import '../core/utils/user_type_utils.dart';

/// Contact details: display name, location, email, mobile, and user type.
/// Email and mobile are required for everyone; artists’ contact may be shown after a winning bid.

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    this.fromSignUp = false,
    this.allowAccountTypeChoice = false,
  });

  /// When true (e.g. after sign-up), save navigates to dashboard instead of pop.
  final bool fromSignUp;

  /// When true, ignore stored [user_type] on load so the user can pick Tattoo artist or Customer.
  /// Use after sign-up or when no role is set yet (see [profileHasSetAccountType]).
  final bool allowAccountTypeChoice;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _displayNameController = TextEditingController();
  final _locationController = TextEditingController();
  final _emailController = TextEditingController();
  final _mobileController = TextEditingController();
  final _imagePicker = ImagePicker();

  String? _avatarUrl;

  /// Portfolio image URLs (tattoo artists only, max [ProfileService.maxPortfolioImages]).
  List<String> _portfolioUrls = [];

  /// Current selection in the form (tattoo artist or customer).
  String? _userType; // 'tattoo_artist' or 'customer'
  /// User type last loaded from the server. Once saved as artist/customer, it can't change.
  String? _profileUserType;
  bool _loading = false;
  bool _uploadingAvatar = false;
  bool _uploadingPortfolio = false;
  bool _initialized = false;
  String? _errorMessage;

  @override
  void dispose() {
    _displayNameController.removeListener(_onFieldChanged);
    _locationController.removeListener(_onFieldChanged);
    _emailController.removeListener(_onFieldChanged);
    _mobileController.removeListener(_onFieldChanged);
    _displayNameController.dispose();
    _locationController.dispose();
    _emailController.dispose();
    _mobileController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final profile = await ProfileService.getCurrentProfile();
    if (!mounted) return;
    if (profile != null) {
      _displayNameController.text = profile.displayName ?? '';
      _locationController.text = profile.location ?? '';
      _emailController.text = (profile.contactEmail?.trim().isNotEmpty == true)
          ? profile.contactEmail!.trim()
          : profile.email;
      _mobileController.text = profile.mobile?.trim() ?? '';
      _avatarUrl = profile.avatarUrl;
      _portfolioUrls = List<String>.from(profile.portfolioUrls);
      // Sign-up / first-time pick: don't preload a stale role (e.g. customer) from the DB.
      if (widget.fromSignUp || widget.allowAccountTypeChoice) {
        _profileUserType = null;
        _userType = null;
      } else {
        final persisted = canonicalUserType(profile.userType);
        _profileUserType = persisted;
        _userType = persisted;
      }
    }
    setState(() => _initialized = true);
  }

  Future<void> pickAndUploadImage() async {
    final xFile = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (xFile == null || !mounted) return;

    setState(() {
      _uploadingAvatar = true;
      _errorMessage = null;
    });
    try {
      final url = await ProfileService.uploadAvatar(File(xFile.path));
      if (!mounted) return;
      setState(() {
        _avatarUrl = url;
        _uploadingAvatar = false;
      });
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString();
      setState(() {
        _uploadingAvatar = false;
        _errorMessage = msg.contains('403') || msg.contains('Forbidden')
            ? 'Avatar upload denied. Ensure the "avatars" bucket exists and is public in Supabase Dashboard → Storage.'
            : msg;
      });
    }
  }

  Future<void> _showPhotoSourceSheet() async {
    if (!mounted || _uploadingAvatar) return;
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take photo'),
              onTap: () => Navigator.of(context).pop('camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Upload from gallery'),
              onTap: () => Navigator.of(context).pop('gallery'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (choice == 'camera') {
      await _openCamera();
      return;
    }
    if (choice == 'gallery') {
      await pickAndUploadImage();
    }
  }

  Future<void> _uploadAvatarFromPath(String path) async {
    if (path.trim().isEmpty || !mounted) return;
    setState(() {
      _uploadingAvatar = true;
      _errorMessage = null;
    });
    try {
      final url = await ProfileService.uploadAvatar(File(path));
      if (!mounted) return;
      setState(() {
        _avatarUrl = url;
        _uploadingAvatar = false;
      });
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString();
      setState(() {
        _uploadingAvatar = false;
        _errorMessage = msg.contains('403') || msg.contains('Forbidden')
            ? 'Avatar upload denied. Ensure the "avatars" bucket exists and is public in Supabase Dashboard → Storage.'
            : msg;
      });
    }
  }

  Future<void> _openCamera() async {
    debugPrint("Camera button tapped"); // debug
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      debugPrint("Camera permission denied");
      return;
    }
    final xFile = await _imagePicker.pickImage(
      source: ImageSource.camera,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (xFile == null) return;
    await _uploadAvatarFromPath(xFile.path);
  }

  /// True when every field on this screen is valid (mirrors form validators).
  /// Save stays disabled until this is true.
  bool get _isFormComplete {
    if (_loading || _uploadingAvatar || _uploadingPortfolio) return false;

    final name = _displayNameController.text.trim();
    final location = _locationController.text.trim();
    final email = _emailController.text.trim();
    final mobile = _mobileController.text.trim();

    if (name.isEmpty || name.length > 100) return false;
    if (location.isEmpty || location.length > 100) return false;
    if (!(_userType == 'tattoo_artist' || _userType == 'customer')) {
      return false;
    }
    if (email.isEmpty || !email.contains('@') || email.length > 254) {
      return false;
    }
    if (mobile.isEmpty || mobile.length > 40) return false;

    return true;
  }

  bool get _isTattooArtist =>
      _userType == 'tattoo_artist' || _profileUserType == 'tattoo_artist';

  bool get _canAddPortfolio =>
      _isTattooArtist &&
      _portfolioUrls.length < ProfileService.maxPortfolioImages;

  Future<void> _pickAndUploadPortfolioImage() async {
    if (!_canAddPortfolio) return;
    final remaining = ProfileService.maxPortfolioImages - _portfolioUrls.length;
    final files = await pickImages();
    if (files.isEmpty || !mounted) return;

    setState(() {
      _uploadingPortfolio = true;
      _errorMessage = null;
    });
    try {
      await ProfileService.uploadPortfolioImages(files);
      final fresh = await ProfileService.getCurrentProfile();
      if (!mounted) return;
      setState(() {
        _portfolioUrls = List<String>.from(fresh?.portfolioUrls ?? []);
        _uploadingPortfolio = false;
      });
      if (mounted && files.length > remaining) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Only $remaining more image${remaining == 1 ? '' : 's'} allowed '
              '(${ProfileService.maxPortfolioImages} max).',
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _uploadingPortfolio = false;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _removePortfolioImage(int index) async {
    setState(() => _errorMessage = null);
    try {
      await ProfileService.removePortfolioImageAt(index);
      final fresh = await ProfileService.getCurrentProfile();
      if (!mounted) return;
      setState(() {
        _portfolioUrls = List<String>.from(fresh?.portfolioUrls ?? []);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.toString());
    }
  }

  void _onFieldChanged([_]) => setState(() {});

  bool get _hasPersistedAccountType =>
      _profileUserType == 'tattoo_artist' || _profileUserType == 'customer';

  /// New users (no saved artist/customer yet) can pick and change until Save.
  /// After the choice is saved, it is permanent.
  bool get _canChangeUserType => !_hasPersistedAccountType;

  void _onAccountTypeTap(String type) {
    if (!_canChangeUserType) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Your account type can’t be changed after it’s saved.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    // Keyboard often steals taps on buttons below text fields.
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _userType = type);
  }

  Widget _accountTypeTile({
    required String value,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final theme = Theme.of(context);
    final selected = _userType == value;
    final bg = selected ? theme.colorScheme.primaryContainer : Colors.white;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: selected
              ? BorderSide.none
              : BorderSide(
                  color: theme.colorScheme.outline.withValues(alpha: 0.35),
                ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _onAccountTypeTap(value),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 28,
                  color: selected
                      ? theme.colorScheme.onPrimaryContainer
                      : theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                ),
                if (selected)
                  Icon(
                    Icons.check_circle,
                    color: theme.colorScheme.primary,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _displayNameController.addListener(_onFieldChanged);
    _locationController.addListener(_onFieldChanged);
    _emailController.addListener(_onFieldChanged);
    _mobileController.addListener(_onFieldChanged);
  }

  Future<void> _save() async {
    _errorMessage = null;
    if (!_formKey.currentState!.validate()) return;

    if (_userType == null || _userType!.isEmpty) {
      setState(() => _errorMessage = 'Please select Tattoo Artist or Customer');
      return;
    }

    final displayName = _displayNameController.text.trim();
    final location = _locationController.text.trim();
    final email = _emailController.text.trim();
    final mobile = _mobileController.text.trim();

    setState(() => _loading = true);
    try {
      await ProfileService.updateProfile(
        displayName: displayName.isEmpty ? null : displayName,
        location: location.isEmpty ? null : location,
        userType: _userType,
        contactEmail: email.isNotEmpty ? email : null,
        mobile: mobile.isNotEmpty ? mobile : null,
        portfolioUrls: _userType == 'tattoo_artist' ? _portfolioUrls : [],
        forceUserType: widget.fromSignUp || widget.allowAccountTypeChoice,
      );
      if (!mounted) return;
      if (widget.fromSignUp) {
        Navigator.of(context).pushReplacementNamed(AppRoutes.dashboard);
      } else {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contact details'),
      ),
      body: !_initialized
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _uploadingAvatar
                              ? null
                              : () {
                                  _showPhotoSourceSheet();
                                },
                          borderRadius: BorderRadius.circular(56),
                          child: Stack(
                            alignment: Alignment.center,
                            clipBehavior: Clip.none,
                            children: [
                              CircleAvatar(
                                radius: 56,
                                backgroundColor: Theme.of(context)
                                    .colorScheme
                                    .primaryContainer,
                                backgroundImage: _avatarUrl != null &&
                                        _avatarUrl!.trim().isNotEmpty
                                    ? NetworkImage(_avatarUrl!)
                                    : null,
                                child: _avatarUrl == null ||
                                        _avatarUrl!.trim().isEmpty
                                    ? Icon(
                                        Icons.person,
                                        size: 56,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onPrimaryContainer,
                                      )
                                    : null,
                              ),
                              if (_uploadingAvatar)
                                Positioned.fill(
                                  child: IgnorePointer(
                                    child: Container(
                                      decoration: const BoxDecoration(
                                        color: Colors.black45,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Center(
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                )
                              else
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: IgnorePointer(
                                    child: CircleAvatar(
                                      backgroundColor:
                                          Theme.of(context).colorScheme.primary,
                                      child: Icon(
                                        Icons.camera_alt,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onPrimary,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        _uploadingAvatar
                            ? 'Uploading...'
                            : 'Tap to change photo',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _displayNameController,
                      decoration: const InputDecoration(
                        labelText: 'Display name',
                        hintText: 'Your display name',
                        border: OutlineInputBorder(),
                      ),
                      textCapitalization: TextCapitalization.words,
                      validator: (v) {
                        final s = v?.trim() ?? '';
                        if (s.isEmpty) return 'Enter your display name';
                        if (s.length > 100) {
                          return 'Name must be 100 characters or less';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _locationController,
                      decoration: InputDecoration(
                        labelText: 'Location',
                        hintText: _userType == 'tattoo_artist'
                            ? 'Where is your tattoo studio located?'
                            : _userType == 'customer'
                                ? 'Which suburb are you from?'
                                : 'City or suburb',
                        border: const OutlineInputBorder(),
                      ),
                      textCapitalization: TextCapitalization.words,
                      validator: (v) {
                        final s = v?.trim() ?? '';
                        if (s.isEmpty) return 'Enter your location';
                        if (s.length > 100) {
                          return 'Location must be 100 characters or less';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Choose your account type',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 4, bottom: 8),
                      child: Text(
                        _canChangeUserType
                            ? 'Tap Tattoo artist or Customer below. You can switch your choice until you tap Save — after that, your account type is permanent and cannot be changed.'
                            : 'Your account type is set and cannot be changed.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: _canChangeUserType
                                  ? Theme.of(context).colorScheme.outline
                                  : Theme.of(context).colorScheme.error,
                            ),
                      ),
                    ),
                    _accountTypeTile(
                      value: 'tattoo_artist',
                      title: 'Tattoo artist',
                      subtitle: 'Bid on jobs and connect with customers',
                      icon: Icons.brush,
                    ),
                    _accountTypeTile(
                      value: 'customer',
                      title: 'Customer',
                      subtitle: 'Post tattoo jobs and hire artists',
                      icon: Icons.person,
                    ),
                    if (_isTattooArtist) ...[
                      const SizedBox(height: 24),
                      Text(
                        'Portfolio',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 4, bottom: 8),
                        child: Text(
                          'Add up to ${ProfileService.maxPortfolioImages} images '
                          'for your public artist profile.',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.outline,
                              ),
                        ),
                      ),
                      if (_portfolioUrls.isNotEmpty)
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            mainAxisSpacing: 8,
                            crossAxisSpacing: 8,
                            childAspectRatio: 1,
                          ),
                          itemCount: _portfolioUrls.length,
                          itemBuilder: (context, index) {
                            final url = _portfolioUrls[index];
                            return Stack(
                              fit: StackFit.expand,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    url,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      color: Colors.white,
                                      child: const Icon(Icons.broken_image),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 4,
                                  right: 4,
                                  child: Material(
                                    color: Colors.black54,
                                    shape: const CircleBorder(),
                                    child: IconButton(
                                      icon: const Icon(Icons.close, size: 18),
                                      color: Colors.white,
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(
                                        minWidth: 32,
                                        minHeight: 32,
                                      ),
                                      onPressed: _uploadingPortfolio
                                          ? null
                                          : () => _removePortfolioImage(index),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      if (_canAddPortfolio)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: OutlinedButton.icon(
                            onPressed: _uploadingPortfolio
                                ? null
                                : _pickAndUploadPortfolioImage,
                            icon: _uploadingPortfolio
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(
                                    Icons.add_photo_alternate_outlined),
                            label: Text(
                              _uploadingPortfolio
                                  ? 'Uploading...'
                                  : 'Add image (${_portfolioUrls.length}/${ProfileService.maxPortfolioImages})',
                            ),
                          ),
                        ),
                    ],
                    const SizedBox(height: 16),
                    Text(
                      'Contact',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 4, bottom: 8),
                      child: Text(
                        _userType == 'tattoo_artist'
                            ? 'Email and mobile are required. Shown to customers after a winning bid.'
                            : _userType == 'customer'
                                ? 'Email and mobile are required.'
                                : 'Email and mobile are required. Choose your account type above first.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                      ),
                    ),
                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        labelText: 'Email address',
                        hintText: 'your.email@example.com',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      validator: (v) {
                        final s = v?.trim() ?? '';
                        if (s.isEmpty) return 'Enter your email address';
                        if (!s.contains('@') || s.length > 254) {
                          return 'Enter a valid email address';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _mobileController,
                      decoration: const InputDecoration(
                        labelText: 'Mobile number',
                        hintText: 'Your phone number',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.phone,
                      validator: (v) {
                        final s = v?.trim() ?? '';
                        if (s.isEmpty) return 'Enter your mobile number';
                        if (s.length > 40) {
                          return 'Max 40 characters';
                        }
                        return null;
                      },
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error),
                      ),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: (_loading || !_isFormComplete) ? null : _save,
                      child: _loading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Save'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
