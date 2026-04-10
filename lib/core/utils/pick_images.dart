import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../l10n/app_localizations.dart';

final ImagePicker _picker = ImagePicker();

/// Bottom sheet: "Take a photo" / "Upload from gallery" (Upload, Profile, Tattsagram).
Future<ImageSource?> showPhotoSourceBottomSheet(BuildContext context) {
  final scheme = Theme.of(context).colorScheme;
  return showModalBottomSheet<ImageSource>(
    context: context,
    backgroundColor: Colors.white,
    barrierColor: Colors.black54,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (BuildContext sheetContext) {
      final l10n = AppLocalizations.of(sheetContext)!;
      final accent = scheme.primary;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.camera_alt, color: accent),
                title: Text(
                  l10n.photoTakePhoto,
                  style: TextStyle(
                    color: accent,
                    fontWeight: FontWeight.w500,
                    fontSize: 16,
                  ),
                ),
                onTap: () => Navigator.of(sheetContext).pop(ImageSource.camera),
              ),
              ListTile(
                leading: Icon(Icons.photo_library_outlined, color: accent),
                title: Text(
                  l10n.photoFromGallery,
                  style: TextStyle(
                    color: accent,
                    fontWeight: FontWeight.w500,
                    fontSize: 16,
                  ),
                ),
                onTap: () =>
                    Navigator.of(sheetContext).pop(ImageSource.gallery),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// Picks multiple images from the gallery. Returns an empty list if the user cancels.
Future<List<File>> pickImages() async {
  final images = await _picker.pickMultiImage();
  return images.map((e) => File(e.path)).toList();
}
