import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SpeechService {
  static const MethodChannel _channel = MethodChannel('speech_channel');

  static Future<String> startListening() async {
    try {
      final result = await _channel.invokeMethod<String>('startListening');
      return result ?? '';
    } catch (e) {
      debugPrint("Speech error: $e");
      return 'Speech recognition failed.';
    }
  }

  static Future<void> stopListening() async {
    try {
      await _channel.invokeMethod('stopListening');
    } catch (e) {
      debugPrint("Stop error: $e");
    }
  }

  static Future<void> setLanguage(String langTag) async {
    try {
      await _channel.invokeMethod('setLanguage', {"langTag": langTag});
    } catch (e) {
      debugPrint("Set language error: $e");
    }
  }
}
