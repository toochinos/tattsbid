import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Uploads customer reference photos to Supabase storage (posts bucket).
///
/// Always uses [Supabase.instance.client] (initialized auth + storage). Never
/// construct a separate [SupabaseClient] for uploads.
class PhotoService {
  PhotoService._();

  static const String _bucket = 'posts';

  static Future<void> _ensureSessionValid(SupabaseClient supabase) async {
    // Upload paths should not force auth refresh/signout on transient failures.
    // Keep current in-memory auth state as-is.
    final _ = supabase.auth.currentSession;
  }

  static Future<void> _requireAuthenticatedSession(
      SupabaseClient supabase) async {
    if (supabase.auth.currentSession == null) {
      throw Exception('User not authenticated');
    }
  }

  /// Same Supabase client as storage/DB; awaits session if [currentUser] is still null.
  static Future<String> _userIdForUpload() async {
    final supabase = Supabase.instance.client;
    // Yield so pending auth hydration (e.g. after [Supabase.initialize]) can finish.
    await Future<void>.delayed(Duration.zero);
    await _ensureSessionValid(supabase);

    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('User not signed in');
    }
    return userId;
  }

  /// Uploads a photo file. Returns the public URL.
  /// Path format: posts/{userId}/{timestamp}.jpg
  static Future<String> uploadPhoto(File file) async {
    final supabase = Supabase.instance.client;
    await _ensureSessionValid(supabase);
    await _requireAuthenticatedSession(supabase);
    final userId = await _userIdForUpload();

    final ext = file.path.split('.').last.toLowerCase();
    if (!['jpg', 'jpeg', 'png', 'webp', 'gif'].contains(ext)) {
      throw ArgumentError('Invalid image format. Use jpg, png, webp, or gif.');
    }

    final fileName = DateTime.now().millisecondsSinceEpoch.toString();
    final path = '$userId/posts/$fileName.$ext';

    await supabase.storage.from(_bucket).upload(
          path,
          file,
          fileOptions: const FileOptions(upsert: true),
        );

    return supabase.storage.from(_bucket).getPublicUrl(path);
  }

  /// Image uploads only — same behavior as [uploadPhoto]; does not handle video.
  static Future<String> uploadImage(File file) => uploadPhoto(file);

  static const String _tattsagramBucket = 'tattsagram';

  /// Uploads a Tattsagram feed image and inserts a row into `tattsagram_post`
  /// so realtime feed subscribers receive the new post without manual refresh.
  /// Returns the inserted DB row from Supabase.
  static Future<Map<String, dynamic>> uploadTattsagramPhoto(File file) async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) {
      throw Exception('User not signed in');
    }
    final userId = user.id;

    final ms = DateTime.now().millisecondsSinceEpoch;
    final path = 'images/$ms.jpg';

    await supabase.storage.from(_tattsagramBucket).upload(
          path,
          file,
          fileOptions: const FileOptions(upsert: true),
        );

    final imageUrl =
        supabase.storage.from(_tattsagramBucket).getPublicUrl(path);

    final inserted = await supabase
        .from('tattsagram_post')
        .insert({
          'media_url': imageUrl,
          'media_type': 'image',
          'user_id': userId,
        })
        .select()
        .single();

    return Map<String, dynamic>.from(inserted);
  }

  /// Uploads video to Supabase Storage ([_tattsagramBucket], path `videos/<ts>.mp4`)
  /// and returns the public media URL.
  static Future<String> uploadVideo(
    File file, {
    void Function(double progress)? onUploadProgress,
  }) async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) {
      throw Exception('User not signed in');
    }
    final ext = file.path.split('.').last.toLowerCase();
    if (!['mp4', 'mov'].contains(ext)) {
      throw ArgumentError('Invalid video format. Use mp4 or mov.');
    }

    final ms = DateTime.now().millisecondsSinceEpoch;
    final fileName = '$ms.mp4';
    final path = 'videos/$fileName';

    void bump(double p) => onUploadProgress?.call(p.clamp(0.0, 1.0));

    try {
      bump(0.0);
      await supabase.storage
          .from(_tattsagramBucket)
          .upload(
            path,
            file,
            fileOptions: const FileOptions(
              contentType: 'video/mp4',
              upsert: true,
            ),
          )
          .timeout(const Duration(seconds: 30));
      bump(0.9);

      final videoUrl = supabase.storage
          .from(_tattsagramBucket)
          .getPublicUrl('videos/$fileName');

      bump(1.0);
      return videoUrl;
    } catch (e, s) {
      debugPrint('VIDEO UPLOAD ERROR: $e\n$s');
      rethrow;
    }
  }

  /// Persists uploaded video URL to [tattsagram_post] and returns inserted row.
  static Future<Map<String, dynamic>> insertUploadedVideoPost(
      String videoUrl) async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) {
      throw Exception('User not signed in');
    }
    final inserted = await supabase
        .from('tattsagram_post')
        .insert({
          'media_url': videoUrl,
          'media_type': 'video',
          'user_id': user.id,
        })
        .select()
        .single();
    return Map<String, dynamic>.from(inserted);
  }
}
