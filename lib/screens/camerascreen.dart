import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:blindnavaiv3/services/camera_service_manager.dart';
import 'package:blindnavaiv3/services/click_manager.dart';
import 'package:blindnavaiv3/services/dart_speeech_service.dart';
import 'package:blindnavaiv3/services/dartcameraservice.dart';
import 'package:blindnavaiv3/services/geminiservice.dart';
import 'package:blindnavaiv3/services/hardware_button_service.dart';
import 'package:blindnavaiv3/services/supabase_service.dart';
import 'package:blindnavaiv3/services/ttsservice.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:just_audio/just_audio.dart';
import 'package:vibration/vibration.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  CameraScreenState createState() => CameraScreenState();
}

class CameraScreenState extends State<CameraScreen> {
  final GlobalKey<CameraServiceState> _cameraKey =
      GlobalKey<CameraServiceState>();
  final SupabaseService _supabaseService = SupabaseService();
  final player = AudioPlayer();
  final AudioPlayer _sfxPlayer = AudioPlayer();
  late final ClickManager _clickManager;
  bool _isCameraInitialized = false;
  bool isProcessing = false;
  String spokenText = "Drücken Sie die Taste, um zu beginnen.";
  Uint8List? lastCapturedImage;
  String? lastImageUrl;
  List<Map<String, String>> qaHistory = [];
  String deviceId = "unbekanntes Gerät";
  String singleSound = "assets/audio/Gentle_Ding_Clicks_1.wav";
  String dualSound = "assets/audio/Dual_Ding_Clicks.mp3";
  int _sessionId = 0;

  bool _cancelRequested = false;

  @override
  void initState() {
    super.initState();
    _initDeviceId();
    _preloadSounds();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await TtsService().init();
      await Future.delayed(
        const Duration(milliseconds: 300),
      );
      await TtsService().speak("Willkommen bei Hilfy");
    });
    _clickManager = ClickManager(onSingleClick: () async {
      debugPrint("Single click detected - start session");
      await _startNewSession();
    }, onDoubleClick: () async {
      debugPrint("Double click detected - stop session");
      await _resetSession(stopText: "Gestoppt durch Doppelklick");
    });
    HardwareButtonService().init(
      singleClick: () async {
        debugPrint("Single click detected - start session");
        await _startNewSession();
      },
      doubleClick: () async {
        debugPrint("Double click detected - stop session");
        await _resetSession(stopText: "Gestoppt durch Doppelklick");
        await _playAudio(
          soundAsset: dualSound,
          vibrationDuration: 300,
        );
      },
    );

    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    await CameraServiceManager.instance.initialize();
    if (!mounted) return;

    if (CameraServiceManager.instance.cameras != null &&
        CameraServiceManager.instance.cameras!.isNotEmpty) {
      setState(() {
        _isCameraInitialized = true;
      });
    } else {
      debugPrint("No cameras available");
    }
  }

  Future<void> _preloadSounds() async {
    try {
      final player1 = AudioPlayer();
      final player2 = AudioPlayer();
      await Future.wait([
        player1.setAsset(singleSound),
        player2.setAsset(dualSound),
      ]);
      await player1.dispose();
      await player2.dispose();
    } catch (e) {
      debugPrint("Error preloading sounds: $e");
    }
  }

  Future<void> _initDeviceId() async {
    deviceId = await _getDeviceId();
  }

  Future<String> _getDeviceId() async {
    try {
      final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        return androidInfo.id;
      } else if (Platform.isIOS) {
        final iosDeviceInfo = await deviceInfo.iosInfo;
        return iosDeviceInfo.identifierForVendor ?? "Unknown Device";
      }
    } catch (e) {
      debugPrint("Error geting device ID: $e");
    }
    return "unknown_device";
  }

  Future<void> _requestStop({String text = "Stopped."}) async {
    _cancelRequested = true;

    try {
      SpeechService.stopListening();
      await TtsService().stop();
    } catch (e) {
      debugPrint("TTS stop error: $e");
    }

    try {
      await player.stop();
    } catch (e) {
      // ignore
    }

    setState(() {
      isProcessing = false;
      spokenText = text;
    });
  }

  Future<void> _resetSession({String stopText = "Stopped."}) async {
    debugPrint("🔄 Resetting session");

    // Cancel ongoing processing
    _cancelRequested = true;

    try {
      SpeechService.stopListening();
    } catch (e) {
      debugPrint("Speech stop error: $e");
    }

    try {
      await TtsService().stop();
    } catch (e) {
      debugPrint("TTS stop error: $e");
    }

    try {
      await player.stop();
    } catch (_) {}

    // Clear state
    lastCapturedImage = null;
    lastImageUrl = null;
    qaHistory.clear();

    setState(() {
      isProcessing = false;
      spokenText = stopText;
    });
  }

  Future<void> _startNewSession() async {
    if (isProcessing) {
      debugPrint("⚠️ Ignoring new session start — already processing");
      return;
    }
    await _resetSession(stopText: "Neue Sitzung wird gestartet...");

    // Increment session ID for cancellation tracking
    _sessionId++;

    // Clear cancellation flag
    _cancelRequested = false;

    // Play single click sound
    await _playAudio(soundAsset: singleSound, vibrationDuration: 120);

    // Start processing scene for this session
    final int currentSession = _sessionId;
    await _processScene(session: currentSession);
  }

  // Image compression
  Future<Uint8List?> _compressImage(Uint8List input) async {
    return await FlutterImageCompress.compressWithList(
      input,
      minWidth: 900,
      minHeight: 900,
      quality: 70,
      format: CompressFormat.jpeg,
    );
  }

  Future<void> _processScene({required int session}) async {
    if (_isCameraInitialized == false) return;

    setState(() {
      spokenText = "Bild wird aufgenommen...";
      isProcessing = true;
    });

    qaHistory = [];
    lastImageUrl = null;

    final Uint8List? imageBytes = await _cameraKey.currentState?.captureImage();

    // Check if this session is still active
    if (_cancelRequested || session != _sessionId) {
      debugPrint("_processScene: cancelled mid-way");
      setState(() {
        isProcessing = false;
        spokenText = "Angehalten.";
      });
      return;
    }

    if (imageBytes == null) {
      setState(() {
        spokenText = "Bildaufnahme fehlgeschlagen.";
        isProcessing = false;
      });
      return;
    }

    setState(() => spokenText = "Bild wird komprimiert...");
    final Uint8List? compressedImage = await _compressImage(imageBytes);

    if (_cancelRequested || session != _sessionId) {
      debugPrint("_processScene: cancelled after compress");
      setState(() {
        isProcessing = false;
        spokenText = "Angehalten.";
      });
      return;
    }

    lastCapturedImage = compressedImage;

    setState(() => spokenText = "Auf Fragen warten ...");
    Vibration.vibrate(duration: 400, amplitude: 250);
    final String prompt = await SpeechService.startListening();

    if (_cancelRequested || session != _sessionId) {
      debugPrint("_processScene: cancelled after listening");
      setState(() {
        isProcessing = false;
        spokenText = "Angehalten.";
      });
      return;
    }

    setState(() => spokenText = "Verarbeitung...");
    final String? result = await GeminiService.processImageWithPrompt(
      imageBytes: compressedImage!,
      prompt: prompt,
    );

    if (_cancelRequested || session != _sessionId) {
      debugPrint("_processScene: cancelled after Gemini");
      setState(() {
        isProcessing = false;
        spokenText = "Angehalten.";
      });
      return;
    }

    if (result != null &&
        !result.toLowerCase().startsWith("error") &&
        !result.toLowerCase().contains("exception")) {
      final deviceId = await _getDeviceId();
      lastImageUrl ??= await _supabaseService.uploadImage(
        compressedImage,
        deviceId,
      );

      if (lastImageUrl != null) {
        unawaited(
          _supabaseService.saveLogJson(
            deviceId: deviceId,
            imagePath: lastImageUrl!,
            question: prompt,
            answer: result,
          ),
        );
      }

      setState(() => spokenText = result);
      await _playAudio(text: result);

      qaHistory.add({"question": prompt, "answer": result});
      if (qaHistory.length > 2) qaHistory.removeAt(0);

      if (!_cancelRequested && session == _sessionId) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (!_cancelRequested && session == _sessionId) {
            _askQuestion(session: session);
          }
        });
      }
    } else {
      setState(() => spokenText = "Anfrage konnte nicht verarbeitet werden.");
      if (!_cancelRequested) {
        TtsService().speak("Anfrage konnte nicht verarbeitet werden.");
      }
    }

    setState(() => isProcessing = false);
  }

  Future<void> _askQuestion({required int session}) async {
    if (_cancelRequested || session != _sessionId) {
      debugPrint("_askQuestion: cancelled at start");
      setState(() {
        isProcessing = false;
        spokenText = "Angehalten.";
      });
      return;
    }

    await TtsService().stop();

    if (lastCapturedImage == null) {
      await _processScene(session: session);
      return;
    }

    setState(() {
      spokenText = "Warte auf neue Fragen ...";
      isProcessing = true;
    });

    Vibration.vibrate(duration: 400, amplitude: 250);
    final String newPrompt = await SpeechService.startListening();

    if (_cancelRequested || session != _sessionId) {
      debugPrint("_askQuestion: cancelled after listening");
      setState(() {
        isProcessing = false;
        spokenText = "Angehalten.";
      });
      return;
    }

    if (newPrompt.trim().isEmpty) {
      setState(() {
        spokenText = "Keine weiteren Fragen. Anhalten";
        isProcessing = false;
      });
      await _playAudio(soundAsset: dualSound, vibrationDuration: 0);
      return;
    }

    final String historyPrompt = qaHistory
        .map((e) => "Question: ${e['question']}\nAnswer: ${e['answer']}")
        .join("\n\n");

    final String finalPrompt = historyPrompt.isNotEmpty
        ? "$historyPrompt\n\nNow answer this new question: $newPrompt"
        : newPrompt;

    setState(() => spokenText = "Verarbeitung...");
    final String? result = await GeminiService.processImageWithPrompt(
      imageBytes: lastCapturedImage!,
      prompt: finalPrompt,
    );

    if (_cancelRequested || session != _sessionId) {
      debugPrint("_askQuestion: cancelled after Gemini");
      setState(() {
        isProcessing = false;
        spokenText = "Angehalten.";
      });
      return;
    }

    if (result != null &&
        !result.toLowerCase().startsWith("error") &&
        !result.toLowerCase().contains("exception")) {
      final deviceId = await _getDeviceId();
      if (lastImageUrl != null) {
        unawaited(
          _supabaseService.saveLogJson(
            deviceId: deviceId,
            imagePath: lastImageUrl!,
            question: newPrompt,
            answer: result,
          ),
        );
      }

      setState(() => spokenText = result);
      await _playAudio(text: result);

      qaHistory.add({"question": newPrompt, "answer": result});
      if (qaHistory.length > 2) qaHistory.removeAt(0);

      if (!_cancelRequested && session == _sessionId) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (!_cancelRequested && session == _sessionId) {
            _askQuestion(session: session);
          }
        });
      }
    } else {
      setState(() => spokenText = "Anfrage kann nicht verarbeitet werden.");
      if (!_cancelRequested) {
        TtsService().speak("Anfrage kann nicht verarbeitet werden.");
      }
    }

    setState(() => isProcessing = false);
  }

  Future<void> _playAudio({
    String? text,
    String? soundAsset,
    int vibrationDuration = 0,
  }) async {
    try {
      await TtsService().stop();

      if (text != null && text.isNotEmpty) {
        await TtsService().speak(text);
      }

      if (soundAsset != null) {
        // play sound once
        await _sfxPlayer.stop();
        await _sfxPlayer.setAsset(soundAsset);
        await _sfxPlayer.play();

        // trigger vibration in parallel (no await needed)
        if (vibrationDuration > 0) {
          final hasVib = await Vibration.hasVibrator();
          if (hasVib) {
            Vibration.vibrate(duration: vibrationDuration);
          }
        }

        // wait until finished
        await _sfxPlayer.playerStateStream.firstWhere(
          (state) => state.processingState == ProcessingState.completed,
        );
      }
    } catch (e) {
      debugPrint("Error in _playAudio: $e");
    }
  }

  @override
  void dispose() {
    player.dispose();
    _sfxPlayer.dispose();
    HardwareButtonService().dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isCameraInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Colors.amberAccent),
              SizedBox(height: 20),
              Text(
                "Kamera wird gestartet...",
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: CameraService(key: _cameraKey),
          ),
          Positioned.fill(
            child: Container(color: Colors.black.withValues(alpha: 0.25)),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 24,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Colors.black.withValues(alpha: 0.1),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "Hilfy",
                            style: TextStyle(
                              color: Color.fromRGBO(255, 222, 89, 100),
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Row(
                            children: [
                              Icon(
                                Icons.phone_android_rounded,
                                size: 18,
                                color: Colors.greenAccent,
                              ),
                              SizedBox(width: 5),
                              Text(
                                deviceId,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 20,
                        horizontal: 24,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Colors.black.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            child: Text(
                              spokenText,
                              key: ValueKey(spokenText),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                height: 1.4,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: GestureDetector(
                              onTap: () async {
                                if (isProcessing) {
                                  debugPrint(
                                    "🔁 Single tap detected — restarting session safely",
                                  );
                                  await _resetSession(stopText: "Neustart...");
                                }

                                await _startNewSession();
                              },
                              onDoubleTap: () async {
                                debugPrint(
                                  "🛑 Double tap detected — stopping everything",
                                );
                                await _resetSession(
                                  stopText: "Durch Doppeltippen gestoppt",
                                );
                                await _playAudio(
                                  soundAsset: dualSound,
                                  vibrationDuration: 300,
                                );
                              },
                              child: AbsorbPointer(
                                child: ElevatedButton.icon(
                                  onPressed: () {},
                                  icon: const Icon(
                                    Icons.image_search_rounded,
                                    color: Colors.black,
                                  ),
                                  label: Text(
                                    isProcessing
                                        ? "Verarbeitung..."
                                        : "Tippen: Aufnehmen | Doppeltippen: Stopp",
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isProcessing
                                        ? const Color.fromRGBO(
                                            255,
                                            185,
                                            89,
                                            100,
                                          )
                                        : const Color.fromRGBO(
                                            255,
                                            222,
                                            89,
                                            100,
                                          ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                      horizontal: 20,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(30),
                                    ),
                                    elevation: 10,
                                    shadowColor: Colors.black.withValues(
                                      alpha: 0.4,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
