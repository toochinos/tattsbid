import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../core/services/profile_service.dart';
import '../core/utils/pick_images.dart';
import '../l10n/app_localizations.dart';

/// Profile photo on Contact details: camera or gallery (files/photos).
class ProfileAvatarPicker extends StatefulWidget {
  const ProfileAvatarPicker({
    super.key,
    this.avatarUrl,
    this.onAvatarUrlChanged,
    this.onUploadingChanged,
    this.highlightWhenEmpty = false,
    this.radius = 56,
  });

  final String? avatarUrl;
  final ValueChanged<String?>? onAvatarUrlChanged;
  final ValueChanged<bool>? onUploadingChanged;

  /// Red ring + error-colored hint (e.g. sign-up when photo is required).
  final bool highlightWhenEmpty;
  final double radius;

  @override
  State<ProfileAvatarPicker> createState() => _ProfileAvatarPickerState();
}

class _ProfileAvatarPickerState extends State<ProfileAvatarPicker> {
  final _imagePicker = ImagePicker();
  String? _avatarUrl;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _avatarUrl = widget.avatarUrl;
  }

  @override
  void didUpdateWidget(covariant ProfileAvatarPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.avatarUrl != oldWidget.avatarUrl) {
      _avatarUrl = widget.avatarUrl;
    }
  }

  Future<void> _showPhotoSourceSheet() async {
    if (!mounted || _uploading) return;
    final l10n = AppLocalizations.of(context)!;
    final source = await showPhotoSourceBottomSheet(
      context,
      cameraLabel: l10n.photoTakePhoto,
      galleryLabel: l10n.profilePhotoFromFiles,
    );
    if (source == null || !mounted) return;
    await _pickAndUpload(source);
  }

  Future<bool> _ensureMediaPermission(ImageSource source) async {
    final l10n = AppLocalizations.of(context)!;
    if (source == ImageSource.camera) {
      final status = await Permission.camera.request();
      if (status.isGranted) return true;
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.profileCameraPermissionRequired)),
      );
      return false;
    }
    final photos = await Permission.photos.request();
    if (photos.isGranted || photos.isLimited) return true;
    if (!mounted) return false;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.profilePhotosPermissionRequired)),
    );
    return false;
  }

  Future<void> _pickAndUpload(ImageSource source) async {
    if (!await _ensureMediaPermission(source)) return;
    final xFile = await _imagePicker.pickImage(
      source: source,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (xFile == null || !mounted) return;
    await _uploadFromPath(xFile.path);
  }

  Future<void> _uploadFromPath(String path) async {
    if (path.trim().isEmpty || !mounted) return;
    setState(() => _uploading = true);
    widget.onUploadingChanged?.call(true);
    try {
      final url = await ProfileService.uploadAvatar(File(path));
      if (!mounted) return;
      setState(() {
        _avatarUrl = url;
        _uploading = false;
      });
      widget.onUploadingChanged?.call(false);
      widget.onAvatarUrlChanged?.call(url);
    } catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      final msg = e.toString();
      setState(() => _uploading = false);
      widget.onUploadingChanged?.call(false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            msg.contains('403') || msg.contains('Forbidden')
                ? l10n.profileAvatarUploadDenied
                : msg,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final url = _avatarUrl?.trim() ?? '';
    final hasPhoto = url.isNotEmpty;
    final showRequiredHint = widget.highlightWhenEmpty && !hasPhoto;

    return Column(
      children: [
        Center(
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: widget.highlightWhenEmpty && !hasPhoto
                  ? Border.all(
                      color: Theme.of(context).colorScheme.error,
                      width: 2.5,
                    )
                  : Border.all(color: Colors.transparent, width: 0),
            ),
            padding: widget.highlightWhenEmpty && !hasPhoto
                ? const EdgeInsets.all(3)
                : EdgeInsets.zero,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _uploading ? null : _showPhotoSourceSheet,
                borderRadius: BorderRadius.circular(widget.radius),
                child: Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    CircleAvatar(
                      radius: widget.radius,
                      backgroundColor:
                          Theme.of(context).colorScheme.primaryContainer,
                      backgroundImage: hasPhoto ? NetworkImage(url) : null,
                      child: !hasPhoto
                          ? Icon(
                              Icons.person,
                              size: widget.radius,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onPrimaryContainer,
                            )
                          : null,
                    ),
                    if (_uploading)
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
                            radius: 18,
                            backgroundColor:
                                Theme.of(context).colorScheme.primary,
                            child: Icon(
                              Icons.camera_alt,
                              size: 20,
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            _uploading
                ? l10n.profileUploading
                : showRequiredHint
                    ? l10n.profileAddPhotoRequired
                    : hasPhoto
                        ? l10n.profileTapToChangePhoto
                        : l10n.profileAddPhotoTap,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: showRequiredHint
                      ? Theme.of(context).colorScheme.error
                      : Theme.of(context).colorScheme.outline,
                ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}
