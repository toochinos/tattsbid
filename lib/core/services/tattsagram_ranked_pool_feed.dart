import 'dart:math';

import '../models/tattsagram_post.dart';

/// TikTok-style ranked pool: each post appears `likesCount + 1` times, then shuffle once.
class TattsagramRankedPoolFeed {
  TattsagramRankedPoolFeed._();

  static int score(TattsagramPost p) => p.likesCount + 1;

  /// One entry per weight unit, then Fisher–Yates shuffle.
  static List<TattsagramPost> buildShuffledRankedSequence(
    List<TattsagramPost> uniquePool, {
    Random? random,
  }) {
    if (uniquePool.isEmpty) return [];
    final rng = random ?? Random();
    final out = <TattsagramPost>[];
    for (final p in uniquePool) {
      final n = score(p).clamp(1, 1 << 20);
      for (var i = 0; i < n; i++) {
        out.add(p);
      }
    }
    out.shuffle(rng);
    return out;
  }

  static bool samePost(TattsagramPost a, TattsagramPost b) {
    final idA = a.id;
    final idB = b.id;
    if (idA != null && idB != null) return idA == idB;
    if (a.mediaType != b.mediaType) return false;
    final ca = a.canonicalRemoteUrl;
    final cb = b.canonicalRemoteUrl;
    return ca.isNotEmpty && ca == cb;
  }

  /// After a like, keep the same sequence order but point slots at [updated].
  static void syncPostInstances(
      List<TattsagramPost> sequence, TattsagramPost updated) {
    for (var i = 0; i < sequence.length; i++) {
      if (samePost(sequence[i], updated)) {
        sequence[i] = updated;
      }
    }
  }
}
