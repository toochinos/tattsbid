import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// Controls shell chrome (e.g. global top-right actions) from nested routes.
class ShellChrome {
  ShellChrome._();

  static int _hideGlobalTopActionsDepth = 0;

  /// When true, [MainShellPage] hides globe / Flexemo / settings overlay.
  static final ValueNotifier<bool> hideGlobalTopActions =
      ValueNotifier<bool>(false);

  static void pushHideGlobalTopActions() {
    _hideGlobalTopActionsDepth++;
    _scheduleApply();
  }

  static void popHideGlobalTopActions() {
    if (_hideGlobalTopActionsDepth > 0) {
      _hideGlobalTopActionsDepth--;
    }
    _scheduleApply();
  }

  /// Clears stale hide state (e.g. after hot reload).
  static void resetHideGlobalTopActions() {
    _hideGlobalTopActionsDepth = 0;
    hideGlobalTopActions.value = false;
  }

  static void _scheduleApply() {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      hideGlobalTopActions.value = _hideGlobalTopActionsDepth > 0;
    });
  }
}
