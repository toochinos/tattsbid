import 'package:video_player/video_player.dart';

/// Tattsagram: one [VideoPlayerController] at volume 1. Sound hands off only when a
/// **new** tile straddles the screen center; leaving center does not mute or clear active.
class TattsagramVideoSoundRegistry {
  TattsagramVideoSoundRegistry._();

  static VideoPlayerController? activeController;

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
    c.setVolume(1);
    if (!c.value.isPlaying) {
      c.play();
    }
  }

  static void syncFeedAndCenterLine({
    required VideoPlayerController controller,
    required bool straddlesCenter,
    required bool feedPlaybackAllowed,
  }) {
    final c = controller;
    if (!c.value.isInitialized) return;

    if (!feedPlaybackAllowed) {
      if (identical(activeController, c)) {
        activeController = null;
      }
      c.setVolume(0);
      if (c.value.isPlaying) c.pause();
      return;
    }

    if (straddlesCenter) {
      makeActive(c);
    }
  }

  static void disposeSlot(VideoPlayerController c) {
    if (identical(activeController, c)) {
      activeController = null;
    }
  }
}
