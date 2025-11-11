import 'dart:async';
import 'package:blindnavaiv3/services/ttsservice.dart';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class SpeechService {
  static final _instance = SpeechService._internal();
  factory SpeechService() => _instance;
  SpeechService._internal();

  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _initialized = false;

  Future<void> init() async {
    _initialized = await _speech.initialize(
      onError: (error) => debugPrint("Speech init error: $error"),
      onStatus: (status) => debugPrint("Speech status: $status"),
    );
  }

  static Future<String> startListening({String localeId = 'en_US'}) async {
    final service = _instance;

    if (!service._initialized) {
      await service.init();
      if (!service._initialized) {
        debugPrint("Speech recognition not available.");
        return "";
      }
    }

    await TtsService().stop();

    String recognizedText = '';
    final completer = Completer<String>();

    service._speech.listen(
      localeId: localeId,
      onResult: (result) {
        recognizedText = result.recognizedWords;
        if (result.finalResult) {
          completer.complete(recognizedText);
        }
      },
    );

    return completer.future;
  }

  static void stopListening() {
    final service = _instance;
    if (service._speech.isListening) {
      service._speech.stop();
    }
  }
}
