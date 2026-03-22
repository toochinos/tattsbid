import 'dart:io';

import 'package:image_picker/image_picker.dart';

final ImagePicker _picker = ImagePicker();

/// Picks multiple images from the gallery. Returns an empty list if the user cancels.
Future<List<File>> pickImages() async {
  final images = await _picker.pickMultiImage();
  return images.map((e) => File(e.path)).toList();
}
