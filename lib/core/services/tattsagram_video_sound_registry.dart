import 'package:flutter/scheduler.dart';
import 'package:video_player/video_player.dart';

/// Tattsagram: one [VideoPlayerController] at volume 1. Each scroll frame, visible
/// videos [submitSoundCandidate]; the **closest tile center to screen center** wins.
class TattsagramVideoSoundRegistry {
  TattsagramVideoSoundRegistry._();

  static VideoPlayerController? activeController;

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
  static double _bestDistance = double.infinity;
  static VideoPlayerController? _bestController;

  static bool _finalizeScheduled = false;

  /// Start (or continue) a collection pass for this frame. Resets best-at-center once per frame.
  static void beginScrollSoundPass() {
    final stamp = SchedulerBinding.instance.currentFrameTimeStamp;
    if (stamp != _lastCollectFrameStamp) {
      _lastCollectFrameStamp = stamp;
      _bestDistance = double.infinity;
      _bestController = null;
    }
  }

  /// Prefer [controller] if [distanceToScreenCenter] is smaller than any other submission this frame.
  static void submitSoundCandidate(
    VideoPlayerController controller,
    double distanceToScreenCenter,
  ) {
    final c = controller;
    if (!c.value.isInitialized) return;
    if (distanceToScreenCenter < _bestDistance) {
      _bestDistance = distanceToScreenCenter;
      _bestController = c;
    }
  }

  /// Coalesced: after layout, [makeActive] the single best candidate (if any).
  static void scheduleFinalizeSoundPass() {
    if (_finalizeScheduled) return;
    _finalizeScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _finalizeScheduled = false;
      final winner = _bestController;
      if (winner != null) {
        makeActive(winner);
      }
    });
  }

  /// Switches audible video: mutes previous (no pause), assigns [controller], volume 1.
  static void makeActive(VideoPlayerController controller) {
    final c = controller;
    if (!c.value.isInitialized) return;

    if (identical(activeController, c)) return;

    if (activeController != null) {
      final prev = activeController!;
      if (prev.value.isInitialized) {
        prev.setVolume(0);
      }
    }

    activeController = c;
    c.setVolume(_userSoundMuted ? 0 : 1);
    if (!c.value.isPlaying) {
      c.play();
    }
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
      c.setVolume(0);
      if (c.value.isPlaying) c.pause();
    }
  }

  static void disposeSlot(VideoPlayerController c) {
    if (identical(activeController, c)) {
      activeController = null;
    }
  }
}
