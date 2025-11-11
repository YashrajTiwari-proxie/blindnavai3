import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';

typedef ClickCallback = Future<void> Function();

class HardwareButtonService {
  static final HardwareButtonService _instance =
      HardwareButtonService._internal();
  factory HardwareButtonService() => _instance;
  HardwareButtonService._internal();

  final MethodChannel _channel = MethodChannel(
    Platform.isAndroid
        ? 'hardware_button_channel'
        : 'ios_hardware_button_channel',
  );

  ClickCallback? onSingleClick;
  ClickCallback? onDoubleClick;

  DateTime? _lastClickTime;
  Timer? _clickTimer;
  final int doubleClickThresholdMs = 400;

  void init({ClickCallback? singleClick, ClickCallback? doubleClick}) {
    onSingleClick = singleClick;
    onDoubleClick = doubleClick;

    if (Platform.isAndroid || Platform.isIOS) {
      _channel.setMethodCallHandler((call) async {
        if (call.method != 'keyPressed') return;

        final now = DateTime.now();

        // Double click
        if (_lastClickTime != null &&
            now.difference(_lastClickTime!).inMilliseconds <=
                doubleClickThresholdMs) {
          _clickTimer?.cancel();
          _clickTimer = null;
          _lastClickTime = null;

          if (onDoubleClick != null) await onDoubleClick!();
          return;
        }

        _lastClickTime = now;

        // Single click timer
        _clickTimer?.cancel();
        _clickTimer =
            Timer(Duration(milliseconds: doubleClickThresholdMs), () async {
          if (onSingleClick != null) await onSingleClick!();
          _lastClickTime = null;
          _clickTimer = null;
        });
      });
    }
  }

  void dispose() {
    _clickTimer?.cancel();
  }
}
