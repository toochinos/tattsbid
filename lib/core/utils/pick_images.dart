import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

final ImagePicker _picker = ImagePicker();

/// Bottom sheet used by Upload and Profile: "Take a photo" / "Upload from gallery".
Future<ImageSource?> showPhotoSourceBottomSheet(BuildContext context) {
  return showModalBottomSheet<ImageSource>(
    context: context,
    builder: (BuildContext sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                Icons.camera_alt,
                color: Theme.of(sheetContext).colorScheme.primary,
              ),
              title: const Text('Take a photo'),
              onTap: () => Navigator.of(sheetContext).pop(ImageSource.camera),
            ),
            ListTile(
              leading: Icon(
                Icons.photo_library,
                color: Theme.of(sheetContext).colorScheme.primary,
              ),
              title: const Text('Upload from gallery'),
              onTap: () => Navigator.of(sheetContext).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Picks multiple images from the gallery. Returns an empty list if the user cancels.
Future<List<File>> pickImages() async {
  final images = await _picker.pickMultiImage();
  return images.map((e) => File(e.path)).toList();
}
