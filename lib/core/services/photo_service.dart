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

  /// Uploads a Tattsagram feed image and returns the public URL.
  static Future<String> uploadTattsagramPhoto(File file) async {
    final supabase = Supabase.instance.client;

    final extension = file.path.split('.').last.toLowerCase();
    if (!['jpg', 'jpeg', 'png', 'webp', 'gif'].contains(extension)) {
      throw ArgumentError('Invalid image format. Use jpg, png, webp, or gif.');
    }
    final fileName = "${DateTime.now().millisecondsSinceEpoch}.$extension";
    final path = 'images/$fileName';

    await supabase.storage.from(_tattsagramBucket).upload(
          path,
          file,
          fileOptions: FileOptions(
            contentType: extension == 'png'
                ? 'image/png'
                : extension == 'jpg' || extension == 'jpeg'
                    ? 'image/jpeg'
                    : 'application/octet-stream',
            upsert: true,
          ),
        );

    return supabase.storage.from(_tattsagramBucket).getPublicUrl(path);
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
    final filePath = 'videos/$fileName';

    void bump(double p) => onUploadProgress?.call(p.clamp(0.0, 1.0));

    try {
      bump(0.0);
      await supabase.storage
          .from(_tattsagramBucket)
          .upload(
            filePath,
            file,
            fileOptions: const FileOptions(
              contentType: 'video/mp4',
              upsert: true,
            ),
          )
          .timeout(const Duration(seconds: 30));
      bump(0.9);

      final publicUrl =
          supabase.storage.from(_tattsagramBucket).getPublicUrl(filePath);

      bump(1.0);
      return publicUrl;
    } catch (e, s) {
      debugPrint('VIDEO UPLOAD ERROR: $e\n$s');
      rethrow;
    }
  }

  static Future<String> _resolveArtistNameForInsert(
    SupabaseClient supabase, {
    String? preferred,
  }) async {
    final preferredName = preferred?.trim() ?? '';
    if (preferredName.isNotEmpty) return preferredName;

    final user = supabase.auth.currentUser;
    if (user == null) return 'Unknown';

    try {
      final profile = await supabase
          .from('profiles')
          .select('display_name, username')
          .eq('id', user.id)
          .maybeSingle();
      if (profile != null) {
        final displayName = profile['display_name']?.toString().trim() ?? '';
        if (displayName.isNotEmpty) return displayName;
        final username = profile['username']?.toString().trim() ?? '';
        if (username.isNotEmpty) return username;
      }
    } catch (_) {
      // Fall through to auth metadata fallbacks.
    }

    final meta = user.userMetadata ?? const <String, dynamic>{};
    final metaDisplay = meta['display_name']?.toString().trim() ?? '';
    if (metaDisplay.isNotEmpty) return metaDisplay;
    final metaUsername = meta['username']?.toString().trim() ?? '';
    if (metaUsername.isNotEmpty) return metaUsername;
    final emailPrefix = (user.email ?? '').split('@').first.trim();
    if (emailPrefix.isNotEmpty) return emailPrefix;
    return 'Unknown';
  }

  /// Display name for [TattsagramPostService.createPost] (profiles, metadata, email).
  static Future<String> resolveArtistNameForTattsagramPost({
    String? preferred,
  }) async {
    return _resolveArtistNameForInsert(
      Supabase.instance.client,
      preferred: preferred,
    );
  }
}
