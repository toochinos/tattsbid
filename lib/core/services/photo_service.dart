import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Uploads customer reference photos to Supabase storage (posts bucket).
class PhotoService {
  PhotoService._();

  static SupabaseClient get _client => Supabase.instance.client;

  static const String _bucket = 'posts';

  /// Uploads a photo file. Returns the public URL.
  /// Path format: posts/{userId}/{timestamp}.jpg
  static Future<String> uploadPhoto(File file) async {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('User must be authenticated');

    final ext = file.path.split('.').last.toLowerCase();
    if (!['jpg', 'jpeg', 'png', 'webp', 'gif'].contains(ext)) {
      throw ArgumentError('Invalid image format. Use jpg, png, webp, or gif.');
    }

    final fileName = DateTime.now().millisecondsSinceEpoch.toString();
    final path = '${user.id}/posts/$fileName.$ext';

    await _client.storage.from(_bucket).upload(
          path,
          file,
          fileOptions: const FileOptions(upsert: true),
        );

    return _client.storage.from(_bucket).getPublicUrl(path);
  }
}
