import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Opens the platform share sheet with a valid iOS [ShareParams.sharePositionOrigin].
Future<void> shareTextWithAnchor({
  required String text,
  BuildContext? context,
  GlobalKey? anchorKey,
  String? subject,
}) {
  return shareWithAnchor(
    text: text,
    context: context,
    anchorKey: anchorKey,
    subject: subject,
  );
}

/// Shares [text] and optional [uri] / [files] from [anchorKey].
Future<void> shareWithAnchor({
  String? text,
  BuildContext? context,
  GlobalKey? anchorKey,
  String? subject,
  Uri? uri,
  List<XFile>? files,
  List<String>? fileNameOverrides,
}) async {
  await SharePlus.instance.share(
    ShareParams(
      text: text,
      subject: subject,
      uri: uri,
      files: files,
      fileNameOverrides: fileNameOverrides,
      sharePositionOrigin: _shareOriginFromAnchor(
        context: context,
        anchorKey: anchorKey,
      ),
    ),
  );
}

/// Shares image [files] only — required for Facebook/Meta apps.
///
/// Meta strips attached photos when caption text or URLs are also sent; the
/// branded share card already includes artist, price, and www.tattsbid.com.
Future<void> shareImageFilesWithAnchor({
  required List<XFile> files,
  BuildContext? context,
  GlobalKey? anchorKey,
  List<String>? fileNameOverrides,
}) {
  return shareWithAnchor(
    context: context,
    anchorKey: anchorKey,
    files: files,
    fileNameOverrides: fileNameOverrides,
  );
}

/// Downloads [imageUrl] to a temp file for the share sheet. Returns [] on failure.
Future<List<XFile>> downloadImageFilesForShare(
  String imageUrl, {
  String basename = 'share',
}) async {
  final url = imageUrl.trim();
  if (url.isEmpty || !url.startsWith('http')) return const [];

  try {
    final response =
        await http.get(Uri.parse(url)).timeout(const Duration(seconds: 20));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return const [];
    }

    final ext = _imageExtensionFromUrl(url);
    final mimeType =
        _mimeTypeFromResponse(response.headers['content-type'], ext);
    final tempDir = await getTemporaryDirectory();
    final fileName = '$basename.$ext';
    final file = File('${tempDir.path}/$fileName');
    await file.writeAsBytes(response.bodyBytes);
    return [
      XFile(
        file.path,
        mimeType: mimeType,
        name: fileName,
      ),
    ];
  } catch (_) {
    return const [];
  }
}

String _imageExtensionFromUrl(String url) {
  final path = Uri.parse(url).path.toLowerCase();
  if (path.endsWith('.png')) return 'png';
  if (path.endsWith('.webp')) return 'webp';
  if (path.endsWith('.jpeg')) return 'jpeg';
  return 'jpg';
}

String _mimeTypeFromResponse(String? contentType, String ext) {
  final header = contentType?.split(';').first.trim().toLowerCase();
  if (header != null && header.startsWith('image/')) return header;
  return switch (ext) {
    'png' => 'image/png',
    'webp' => 'image/webp',
    'jpeg' => 'image/jpeg',
    _ => 'image/jpeg',
  };
}

Rect _shareOriginFromAnchor({BuildContext? context, GlobalKey? anchorKey}) {
  final anchorContext = anchorKey?.currentContext ?? context;
  if (anchorContext != null) {
    final box = anchorContext.findRenderObject() as RenderBox?;
    if (box != null && box.hasSize) {
      final size = box.size;
      if (size.width > 0 && size.height > 0) {
        return box.localToGlobal(Offset.zero) & size;
      }
    }
  }
  return const Rect.fromLTWH(0, 0, 1, 1);
}
