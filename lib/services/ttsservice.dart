import 'dart:io';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter/material.dart';
//import 'package:blind_nav_v1/utils/prefhelper.dart';

class TtsService {
  static final TtsService _instance = TtsService._internal();
  factory TtsService() => _instance;

  final FlutterTts _flutterTts = FlutterTts();
  bool _isInitialized = false;

  TtsService._internal() {
    _initTts();
  }

  Future<void> _initTts() async {
    try {
      if (Platform.isAndroid) {
        await _flutterTts.setEngine("com.google.android.tts");
      } else if (Platform.isIOS) {
        await _flutterTts.setSharedInstance(true);
      }
      _isInitialized = true;
    } catch (e) {
      debugPrint("TTS Init Error: $e");
    }
  }

  Future<void> speak(String text) async {
    if (!_isInitialized || text.isEmpty) return;

    try {
      //String selectedLanguageCode =
      //await PreferencesHelper.getLanguageCode() ?? "en-US";

      //await _flutterTts.setLanguage(selectedLanguageCode);
      await _flutterTts.setPitch(1);
      await _flutterTts.setSpeechRate(0.4);
      await _flutterTts.awaitSpeakCompletion(true);
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
