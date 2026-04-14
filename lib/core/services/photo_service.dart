import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Uploads customer reference photos to Supabase storage (posts bucket).
///
/// Always uses [Supabase.instance.client] (initialized auth + storage). Never
/// construct a separate [SupabaseClient] for uploads.
class PhotoService {
  PhotoService._();

  static const String _bucket = 'posts';

  static Future<void> _ensureSessionValid(SupabaseClient supabase) async {
    final session = supabase.auth.currentSession;
    if (session != null) return;
    try {
      await supabase.auth.refreshSession();
    } catch (e, st) {
      debugPrint('PhotoService session refresh failed: $e\n$st');
      try {
        await supabase.auth.signOut();
      } catch (_) {}
    }
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
  static Future<String> uploadTattsagramPhoto(File file) async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) {
      throw Exception('User not signed in');
    }
    final userId = user.id;

    final ext = file.path.split('.').last.toLowerCase();
    if (!['jpg', 'jpeg', 'png', 'webp', 'gif'].contains(ext)) {
      throw ArgumentError('Invalid image format. Use jpg, png, webp, or gif.');
    }

    final ms = DateTime.now().millisecondsSinceEpoch;
    final path = 'images/$ms.$ext';
    final contentType = switch (ext) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      'gif' => 'image/gif',
      _ => 'image/jpeg',
    };

    await supabase.storage.from(_tattsagramBucket).upload(
          path,
          file,
          fileOptions: FileOptions(
            upsert: true,
            contentType: contentType,
          ),
        );

    final imageUrl =
        supabase.storage.from(_tattsagramBucket).getPublicUrl(path);

    await supabase.from('tattsagram_post').insert({
      'media_url': imageUrl,
      'media_type': 'image',
      'user_id': userId,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });

    return imageUrl;
  }

  /// Same endpoint and multipart shape as [StorageFileApi.upload], but streams the file
  /// so [onUploadProgress] receives byte-based progress in \[0, 1\] (Dart `storage_client`
  /// does not expose `onUploadProgress` on `.upload()` yet).
  static Future<void> _uploadStorageObjectWithProgress({
    required SupabaseClient supabase,
    required String bucket,
    required String objectRelativePath,
    required File file,
    required FileOptions fileOptions,
    void Function(double progress)? onUploadProgress,
  }) async {
    final api = supabase.storage.from(bucket);
    final finalPath = '$bucket/$objectRelativePath';
    final uri = Uri.parse('${api.url}/object/$finalPath');

    final total = await file.length();
    if (total <= 0) {
      onUploadProgress?.call(0.88);
      throw ArgumentError('Video file is empty');
    }

    var sent = 0;
    Stream<List<int>> trackedOpenRead() async* {
      await for (final chunk in file.openRead()) {
        sent += chunk.length;
        onUploadProgress?.call((sent / total).clamp(0.0, 1.0));
        yield chunk;
      }
    }

    final contentType = http.MediaType.parse(
      fileOptions.contentType ?? 'application/octet-stream',
    );

    final filename = objectRelativePath.contains('/')
        ? objectRelativePath.substring(objectRelativePath.lastIndexOf('/') + 1)
        : objectRelativePath;

    final multipartFile = http.MultipartFile(
      '',
      trackedOpenRead(),
      total,
      filename: filename,
      contentType: contentType,
    );

    final request = http.MultipartRequest('POST', uri)
      ..headers.addAll(api.headers)
      ..files.add(multipartFile)
      ..fields['cacheControl'] = fileOptions.cacheControl
      ..headers['x-upsert'] = fileOptions.upsert.toString();
    if (fileOptions.metadata != null) {
      request.fields['metadata'] = json.encode(fileOptions.metadata);
    }
    if (fileOptions.headers != null) {
      request.headers.addAll(fileOptions.headers!);
    }

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode < 200 || response.statusCode > 299) {
      throw Exception(
        'Storage upload failed (${response.statusCode}): ${response.body}',
      );
    }
  }

  /// Uploads video to Supabase Storage ([_tattsagramBucket], path `videos/<ts>.mp4`)
  /// and inserts [tattsagram_post]. Returns the public media URL.
  ///
  /// Step 3 — [onUploadProgress] is driven by bytes streamed to Storage (then a short
  /// bump for DB insert), matching JS-style upload progress for the `tattsagram` bucket.
  static Future<String> uploadVideo(
    File file, {
    void Function(double progress)? onUploadProgress,
  }) async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) {
      throw Exception('User not signed in');
    }
    final userId = user.id;

    final ext = file.path.split('.').last.toLowerCase();
    if (!['mp4', 'mov'].contains(ext)) {
      throw ArgumentError('Invalid video format. Use mp4 or mov.');
    }

    final ms = DateTime.now().millisecondsSinceEpoch;
    final path = 'videos/$ms.mp4';
    final contentType = ext == 'mov' ? 'video/quicktime' : 'video/mp4';

    void bump(double p) => onUploadProgress?.call(p.clamp(0.0, 1.0));

    final fileOptions = FileOptions(
      upsert: true,
      contentType: contentType,
    );

    try {
      bump(0.0);
      await _uploadStorageObjectWithProgress(
        supabase: supabase,
        bucket: _tattsagramBucket,
        objectRelativePath: path,
        file: file,
        fileOptions: fileOptions,
        onUploadProgress: onUploadProgress,
      );

      final videoUrl =
          supabase.storage.from(_tattsagramBucket).getPublicUrl(path);

      // Canonical table is [tattsagram_post] (media_url + media_type); Realtime picks up INSERT.
      bump(0.97);
      await supabase.from('tattsagram_post').insert({
        'media_url': videoUrl,
        'media_type': 'video',
        'user_id': userId,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });

      bump(1.0);
      return videoUrl;
    } catch (e, s) {
      debugPrint('VIDEO UPLOAD ERROR: $e\n$s');
      rethrow;
    }
  }
}
