import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Warms the HTTP connection and reads an initial chunk of the next video URL
/// without creating a [VideoPlayerController].
class TattsagramNextVideoPreload {
  TattsagramNextVideoPreload._();

  static final Set<String> _completed = {};
  static final Map<String, Future<void>> _inFlight = {};

  /// Reads up to [byteBudget] bytes from [rawUrl] (http/https only).
  static void schedule(String rawUrl, {int byteBudget = 2 * 1024 * 1024}) {
    final url = rawUrl.trim();
    if (url.isEmpty) return;
    if (_completed.contains(url)) return;
    if (_inFlight.containsKey(url)) return;

    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (uri.scheme != 'http' && uri.scheme != 'https') return;

    final fut = _run(url, uri, byteBudget);
    _inFlight[url] = fut;
    unawaited(fut.whenComplete(() => _inFlight.remove(url)));
  }

  static Future<void> _run(String url, Uri uri, int byteBudget) async {
    final client = http.Client();
    try {
      final request = http.Request('GET', uri);
      final streamed = await client.send(request);
      var total = 0;
      await for (final chunk in streamed.stream) {
        total += chunk.length;
        if (total >= byteBudget) {
          break;
        }
      }
      if (total > 0 || streamed.statusCode == 200) {
        _completed.add(url);
      }
    } catch (e, st) {
      debugPrint('TattsagramNextVideoPreload: $e\n$st');
    } finally {
      client.close();
    }
  }
}
