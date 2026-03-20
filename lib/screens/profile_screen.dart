import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/routes/app_routes.dart';
import '../core/services/profile_service.dart';

/// Profile screen: display_name, user type (Tattoo Artist / Customer), Save button.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, this.fromSignUp = false});

  /// When true (e.g. after sign-up), save navigates to dashboard instead of pop.
  final bool fromSignUp;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _displayNameController = TextEditingController();
  final _bioController = TextEditingController();
  final _locationController = TextEditingController();
  final _imagePicker = ImagePicker();

  String? _avatarUrl;
  String? _userType; // 'tattoo_artist' or 'customer'
  bool _loading = false;
  bool _uploadingAvatar = false;
  bool _initialized = false;
  String? _errorMessage;

  @override
  void dispose() {
    _displayNameController.removeListener(_onFieldChanged);
    _bioController.removeListener(_onFieldChanged);
    _locationController.removeListener(_onFieldChanged);
    _displayNameController.dispose();
    _bioController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final profile = await ProfileService.getCurrentProfile();
    if (!mounted) return;
    if (profile != null) {
      _displayNameController.text = profile.displayName ?? '';
      _bioController.text = profile.bio ?? '';
      _locationController.text = profile.location ?? '';
      _avatarUrl = profile.avatarUrl;
      _userType = profile.userType;
    }
    setState(() => _initialized = true);
  }

  Future<void> _pickAndUploadImage() async {
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

  bool get _isFormComplete {
    final name = _displayNameController.text.trim();
    final bio = _bioController.text.trim();
    final location = _locationController.text.trim();
    return name.isNotEmpty &&
        bio.isNotEmpty &&
        location.isNotEmpty &&
        (_userType == 'tattoo_artist' || _userType == 'customer');
  }

  void _onFieldChanged([_]) => setState(() {});

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _displayNameController.addListener(_onFieldChanged);
    _bioController.addListener(_onFieldChanged);
    _locationController.addListener(_onFieldChanged);
  }

  Future<void> _save() async {
    _errorMessage = null;
    if (!_formKey.currentState!.validate()) return;

    if (_userType == null || _userType!.isEmpty) {
      setState(() => _errorMessage = 'Please select Tattoo Artist or Customer');
      return;
    }

    final displayName = _displayNameController.text.trim();
    final bio = _bioController.text.trim();
    final location = _locationController.text.trim();

    setState(() => _loading = true);
    try {
      await ProfileService.updateProfile(
        displayName: displayName.isEmpty ? null : displayName,
        bio: bio.isEmpty ? null : bio,
        location: location.isEmpty ? null : location,
        userType: _userType,
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
        title: const Text('Edit profile'),
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
                          onTap: _uploadingAvatar ? null : _pickAndUploadImage,
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
                      controller: _bioController,
                      decoration: const InputDecoration(
                        labelText: 'Bio',
                        hintText: 'Tell us about yourself',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                      validator: (v) {
                        final s = v?.trim() ?? '';
                        if (s.isEmpty) return 'Enter your bio';
                        if (s.length > 500) {
                          return 'Bio must be 500 characters or less';
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
                            : 'Which suburb are you from?',
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
                    const SizedBox(height: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_userType == 'tattoo_artist' ||
                            _userType == 'customer')
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              'User type cannot be changed once set.',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color:
                                        Theme.of(context).colorScheme.outline,
                                  ),
                            ),
                          ),
                        CheckboxListTile(
                          secondary: Icon(
                            Icons.brush,
                            color: _userType == 'tattoo_artist'
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.outline,
                          ),
                          title: const Text('Tattoo Artist'),
                          value: _userType == 'tattoo_artist',
                          onChanged: _userType == 'tattoo_artist' ||
                                  _userType == 'customer'
                              ? null
                              : (checked) {
                                  setState(() {
                                    _userType = checked == true
                                        ? 'tattoo_artist'
                                        : null;
                                  });
                                },
                          tileColor: _userType == 'tattoo_artist'
                              ? Theme.of(context)
                                  .colorScheme
                                  .primaryContainer
                                  .withValues(alpha: 0.5)
                              : null,
                          selectedTileColor: Theme.of(context)
                              .colorScheme
                              .primaryContainer
                              .withValues(alpha: 0.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        const SizedBox(height: 8),
                        CheckboxListTile(
                          secondary: Icon(
                            Icons.person,
                            color: _userType == 'customer'
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.outline,
                          ),
                          title: const Text('Customer'),
                          value: _userType == 'customer',
                          onChanged: _userType == 'tattoo_artist' ||
                                  _userType == 'customer'
                              ? null
                              : (checked) {
                                  setState(() {
                                    _userType =
                                        checked == true ? 'customer' : null;
                                  });
                                },
                          tileColor: _userType == 'customer'
                              ? Theme.of(context)
                                  .colorScheme
                                  .primaryContainer
                                  .withValues(alpha: 0.5)
                              : null,
                          selectedTileColor: Theme.of(context)
                              .colorScheme
                              .primaryContainer
                              .withValues(alpha: 0.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ],
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
