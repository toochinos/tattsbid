import 'package:flutter/scheduler.dart';
import 'package:video_player/video_player.dart';

enum TattsagramPlaybackTier {
  center,
  nearCenter,
  far,
}

/// Tattsagram: one [VideoPlayerController] at volume 1. Each scroll frame, visible
/// videos [submitSoundCandidate]; the **closest tile center to screen center** wins.
class TattsagramVideoSoundRegistry {
  TattsagramVideoSoundRegistry._();
  static const double _centerThresholdPx = 40;
  static const double _nearCenterThresholdPx = 400;

  static VideoPlayerController? activeController;
  static final Set<VideoPlayerController> _registeredControllers = {};
  static final Map<VideoPlayerController, TattsagramPlaybackTier> _tiers = {};

  /// User toggle: when true, the winning feed video stays at volume 0.
  static bool _userSoundMuted = false;

  static bool get userSoundMuted => _userSoundMuted;

  static void setUserSoundMuted(bool muted) {
    if (_userSoundMuted == muted) return;
    _userSoundMuted = muted;
    final a = activeController;
    if (a != null && a.value.isInitialized) {
      a.setVolume(muted ? 0 : 1);
    }
  }

  static Duration? _lastCollectFrameStamp;
  static final List<({VideoPlayerController controller, double distance})>
      _candidates = [];

  static bool _finalizeScheduled = false;

  /// Start (or continue) a collection pass for this frame. Resets best-at-center once per frame.
  static void beginScrollSoundPass() {
    final stamp = SchedulerBinding.instance.currentFrameTimeStamp;
    if (stamp != _lastCollectFrameStamp) {
      _lastCollectFrameStamp = stamp;
      _candidates.clear();
    }
  }

  /// Prefer [controller] if [distanceToScreenCenter] is smaller than any other submission this frame.
  static void submitSoundCandidate(
    VideoPlayerController controller,
    double distanceToScreenCenter,
  ) {
    final c = controller;
    if (!c.value.isInitialized) return;
    _registeredControllers.add(c);
    _candidates.add((controller: c, distance: distanceToScreenCenter));
  }

  /// Coalesced: after layout, assign CENTER/NEAR/FAR playback tiers.
  static void scheduleFinalizeSoundPass() {
    if (_finalizeScheduled) return;
    _finalizeScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _finalizeScheduled = false;
      if (_candidates.isEmpty) return;

      _candidates.sort((a, b) => a.distance.compareTo(b.distance));
      final centerCandidate = _candidates.first;
      final center = centerCandidate.distance < _centerThresholdPx
          ? centerCandidate.controller
          : null;
      final visible = _candidates.map((e) => e.controller).toSet();

      for (final c in visible) {
        final distance = _candidates
            .firstWhere((candidate) => identical(candidate.controller, c))
            .distance;
        final isCenter = distance < _centerThresholdPx;
        final isFallbackCenter =
            center == null && identical(c, centerCandidate.controller);
        final isNearCenter = distance < _nearCenterThresholdPx;

        if (isCenter || isFallbackCenter) {
          _tiers[c] = TattsagramPlaybackTier.center;
          c.setVolume(_userSoundMuted ? 0 : 1);
          if (!c.value.isPlaying) c.play();
        } else if (isNearCenter) {
          _tiers[c] = TattsagramPlaybackTier.nearCenter;
          c.setVolume(0);
          if (c.value.isPlaying) c.pause();
        } else {
          _tiers[c] = TattsagramPlaybackTier.far;
          c.setVolume(0);
          if (c.value.isPlaying) c.pause();
        }
      }

      // Registered controllers that are no longer visible should stay paused.
      for (final c in _registeredControllers) {
        if (visible.contains(c)) continue;
        _tiers[c] = TattsagramPlaybackTier.far;
        if (c.value.isInitialized) {
          c.setVolume(0);
          if (c.value.isPlaying) c.pause();
        }
      }
      activeController = center;
    });
  }

  /// When the feed is hidden (other tab): mute + pause this tile; clear active if needed.
  static void applyFeedPlaybackGate({
    required VideoPlayerController controller,
    required bool allow,
  }) {
    final c = controller;
    if (!c.value.isInitialized) return;
    if (!allow) {
      if (identical(activeController, c)) {
        activeController = null;
      }
      _tiers[c] = TattsagramPlaybackTier.far;
      c.setVolume(0);
      if (c.value.isPlaying) c.pause();
    }
  }

  static TattsagramPlaybackTier playbackTierFor(VideoPlayerController c) =>
      _tiers[c] ?? TattsagramPlaybackTier.far;

  static void registerSlot(VideoPlayerController c) {
    _registeredControllers.add(c);
  }

  static void disposeSlot(VideoPlayerController c) {
    _registeredControllers.remove(c);
    _tiers.remove(c);
    if (identical(activeController, c)) {
      activeController = null;
    }
  }
}
