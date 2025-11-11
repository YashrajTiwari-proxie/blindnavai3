import 'dart:async';

class ClickManager {
  final Function onSingleClick;
  final Function onDoubleClick;

  DateTime? _lastClickTime;
  Timer? _clickTimer;
  final int doubleClickThresholdMs;

  ClickManager({
    required this.onSingleClick,
    required this.onDoubleClick,
    this.doubleClickThresholdMs = 400,
  });

  void handleClick() {
    final now = DateTime.now();

    if (_lastClickTime != null &&
        now.difference(_lastClickTime!).inMilliseconds <=
            doubleClickThresholdMs) {
      // Double click detected
      _clickTimer?.cancel();
      _clickTimer = null;
      _lastClickTime = null;
      onDoubleClick();
      return;
    }

    // First click
    _lastClickTime = now;
    _clickTimer?.cancel();
    _clickTimer = Timer(Duration(milliseconds: doubleClickThresholdMs), () {
      // Timer expired → it was a single click
      onSingleClick();
      _lastClickTime = null;
      _clickTimer = null;
    });
  }

  void dispose() {
    _clickTimer?.cancel();
  }
}
