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

  /// Same Supabase client as storage/DB; awaits session if [currentUser] is still null.
  static Future<String> _userIdForUpload() async {
    final supabase = Supabase.instance.client;
    // Yield so pending auth hydration (e.g. after [Supabase.initialize]) can finish.
    await Future<void>.delayed(Duration.zero);

    var user = supabase.auth.currentUser;
    if (user == null) {
      final session = await _authSessionOrRefresh(supabase);
      if (session.session == null) {
        throw Exception('User not signed in');
      }
    }
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('User not signed in');
    }
    return userId;
  }

  /// Parallel to JS `supabase.auth.getSession()`: current session or refresh from storage.
  /// (Dart `gotrue` has no `auth.getSession()`; this is the supported equivalent.)
  static Future<AuthResponse> _authSessionOrRefresh(
      SupabaseClient supabase) async {
    final auth = supabase.auth;
    final existing = auth.currentSession;
    if (existing != null) {
      return AuthResponse(session: existing);
    }
    try {
      return await auth.refreshSession();
    } catch (_) {
      return AuthResponse(session: auth.currentSession);
    }
  }

  /// Uploads a photo file. Returns the public URL.
  /// Path format: posts/{userId}/{timestamp}.jpg
  static Future<String> uploadPhoto(File file) async {
    final supabase = Supabase.instance.client;
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

  /// Uploads video to Tattsagram storage (`videos/…`) and inserts [tattsagram_post].
  /// Returns the public media URL.
  static Future<String> uploadVideo(File file) async {
    final supabase = Supabase.instance.client;

    debugPrint('USER: ${supabase.auth.currentUser}');
    debugPrint('FILE PATH: ${file.path}');
    debugPrint('FILE SIZE: ${file.lengthSync()}');

    final user = supabase.auth.currentUser;
    if (user == null) {
      throw Exception('User not logged in');
    }

    final ext = file.path.split('.').last.toLowerCase();
    if (!['mp4', 'mov'].contains(ext)) {
      throw ArgumentError('Invalid video format. Use mp4 or mov.');
    }

    final fileName = '${DateTime.now().millisecondsSinceEpoch}.mp4';
    final path = 'videos/$fileName';

    final contentType = ext == 'mov' ? 'video/quicktime' : 'video/mp4';

    try {
      await supabase.storage.from('tattsagram').upload(
            path,
            file,
            fileOptions: FileOptions(
              upsert: true,
              contentType: contentType,
            ),
          );

      final url = supabase.storage.from('tattsagram').getPublicUrl(path);

      await supabase.from('tattsagram_post').insert({
        'media_url': url,
        'media_type': 'video',
        'user_id': user.id,
      });

      return url;
    } catch (e, s) {
      debugPrint('VIDEO UPLOAD ERROR: $e');
      debugPrint('$s');
      rethrow;
    }
  }
}
