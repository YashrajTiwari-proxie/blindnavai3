import 'dart:async';
import 'dart:io';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter/material.dart';
//import 'package:blind_nav_v1/utils/prefhelper.dart';

class TtsService {
  static final TtsService _instance = TtsService._internal();
  factory TtsService() => _instance;

  final FlutterTts _flutterTts = FlutterTts();
  bool _isInitialized = false;
  Completer<void>? _initCompleter;

  TtsService._internal();

  /// Ensure TTS is initialized before speaking
  Future<void> init() async {
    if (_isInitialized) return;

    // Avoid multiple concurrent initializations
    if (_initCompleter != null) return _initCompleter!.future;
    _initCompleter = Completer<void>();

    try {
      if (Platform.isAndroid) {
        await _flutterTts.setEngine("com.google.android.tts");
      } else if (Platform.isIOS) {
        await _flutterTts.setSharedInstance(true);
      }
      await _flutterTts.setLanguage("de-DE");
      await _flutterTts.setPitch(1);
      await _flutterTts.setSpeechRate(0.4);
      await _flutterTts.awaitSpeakCompletion(true);

      _isInitialized = true;
      _initCompleter!.complete();
    } catch (e) {
      debugPrint("TTS Init Error: $e");
      _initCompleter!.completeError(e);
    }
  }

  Future<void> speak(String text) async {
    if (!_isInitialized) await init();
    if (text.isEmpty) return;

    try {
      await _flutterTts.speak(text);
    } catch (e) {
      debugPrint("TTS Speak Error: $e");
    }
  }

  Future<void> stop() async {
    if (!_isInitialized) return;
    try {
      await _flutterTts.stop();
    } catch (e) {
      debugPrint("TTS Stop Error: $e");
    }
  }
}
