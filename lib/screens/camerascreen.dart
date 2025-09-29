import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:blindnavaiv3/services/cameraservicenative.dart';
import 'package:blindnavaiv3/services/geminiservice.dart';
import 'package:blindnavaiv3/services/speechservice.dart';
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
  final CameraServiceNative _cameraService = CameraServiceNative();
  final MethodChannel _screenChannel = const MethodChannel('screen_state');
  final SupabaseService _supabaseService = SupabaseService();
  final player = AudioPlayer();
  final AudioPlayer _sfxPlayer = AudioPlayer();
  bool _isCameraInitialized = false;
  bool isProcessing = false;
  String spokenText = "Press the button to begin.";
  Uint8List? lastCapturedImage;
  String? lastImageUrl;
  List<Map<String, String>> qaHistory = [];
  String deviceId = "unknown device";
  String singleSound = "assets/audio/Gentle_Ding_Clicks_1.wav";
  String dualSound = "assets/audio/Dual_Ding_Clicks.mp3";

  bool _cancelRequested = false;

  @override
  void initState() {
    super.initState();
    _delayedInitializeCamera();
    _setupScreenKeyListener();
    _initDeviceId();
    _preloadSounds();
  }

  Future<void> _preloadSounds() async {
    try {
      await _sfxPlayer.setAsset(singleSound);
      await _sfxPlayer.setAsset(dualSound);
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

  Future<void> _delayedInitializeCamera() async {
    await _cameraService.startCamera();
    await Future.delayed(const Duration(milliseconds: 600));

    setState(() {
      _isCameraInitialized = true;
    });
  }

  DateTime? _lastKeyPressTime;

  Future<void> _requestStop({String text = "Stopped."}) async {
    _cancelRequested = true;

    try {
      await TtsService().stop();
    } catch (e) {
      debugPrint("TTS stop error: $e");
    }

    try {
      await player.stop();
    } catch (e) {
      // ignore
    }
    // ✅ Play stop chime + long vibration
    await _playAudio(soundAsset: dualSound, vibrationDuration: 300);

    setState(() {
      isProcessing = false;
      spokenText = text;
    });
  }

  Timer? _singleClickTimer;

  void _setupScreenKeyListener() {
    _screenChannel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'keyPressed':
          final int keyCode = call.arguments;
          debugPrint("Key pressed: $keyCode");

          if (_singleClickTimer != null && _singleClickTimer!.isActive) {
            _singleClickTimer!.cancel();
            debugPrint("🎯 Double click detected on clicker — requesting stop");
            await _requestStop();
          } else {
            _singleClickTimer = Timer(const Duration(milliseconds: 400), () {
              if (!isProcessing) {
                _cancelRequested = false;
                debugPrint(
                  "📸 Single click detected on clicker — starting capture",
                );
                _processScene();
              } else {
                debugPrint("Single click ignored: already processing");
              }
            });
          }
          break;
      }
    });
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

  Future<void> _processScene() async {
    _cancelRequested = false;

    await TtsService().stop();
    if (_isCameraInitialized == false) return;

    setState(() {
      spokenText = "Capturing image...";
      isProcessing = true; // only blocks capture while analyzing
    });

    qaHistory = [];
    lastImageUrl = null;

    // capture image (may be long)
    final Uint8List? imageBytes = await _cameraService.captureImage();

    // If cancellation was requested while the capture was happening, stop now
    if (_cancelRequested) {
      debugPrint("_processScene: cancelled after capture");
      setState(() {
        isProcessing = false;
        spokenText = "Stopped.";
      });
      return;
    }

    if (imageBytes == null) {
      setState(() {
        spokenText = "Failed to capture image.";
        isProcessing = false;
      });
      return;
    }

    setState(() => spokenText = "Compressing image...");
    final Uint8List? compressedImage = await _compressImage(imageBytes);
    await _playAudio(soundAsset: singleSound, vibrationDuration: 120);

    if (_cancelRequested) {
      debugPrint("_processScene: cancelled after compress");
      setState(() {
        isProcessing = false;
        spokenText = "Stopped.";
      });
      return;
    }

    if (compressedImage == null) {
      setState(() {
        spokenText = "Image compression failed.";
        isProcessing = false;
      });
      return;
    }

    lastCapturedImage = compressedImage;

    // Listen for question
    setState(() => spokenText = "Listening for question...");
    Vibration.vibrate(duration: 400, amplitude: 250);
    final String prompt = await SpeechService.startListening();

    if (_cancelRequested) {
      debugPrint("_processScene: cancelled after listening");
      setState(() {
        isProcessing = false;
        spokenText = "Stopped.";
      });
      return;
    }

    setState(() => spokenText = "Processing...");
    final String? result = await GeminiService.processImageWithPrompt(
      imageBytes: compressedImage,
      prompt: prompt,
    );

    if (_cancelRequested) {
      debugPrint("_processScene: cancelled after gemini");
      setState(() {
        isProcessing = false;
        spokenText = "Stopped.";
      });
      return;
    }

    if (result != null &&
        !result.toLowerCase().startsWith("error") &&
        !result.toLowerCase().contains("exception")) {
      final deviceId = await _getDeviceId();
      if (!_cancelRequested) {
        lastImageUrl ??= await _supabaseService.uploadImage(
          compressedImage,
          deviceId,
        );
      }

      if (lastImageUrl != null && !_cancelRequested) {
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

      // ✅ Run TTS & save in background — skip TTS if cancellation requested
      if (!_cancelRequested) {
        await _playAudio(text: result);
      } else {
        debugPrint("_processScene: skipping TTS due to cancellation");
      }

      qaHistory.add({"question": prompt, "answer": result});
      if (qaHistory.length > 2) qaHistory.removeAt(0);

      // Only continue the "ask question" loop if not cancelled
      if (!_cancelRequested) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (!_cancelRequested) _askQuestion();
        });
      }
    } else {
      setState(() => spokenText = "Error occurred.");
      if (!_cancelRequested) TtsService().speak("Error occurred.");
    }

    setState(
      () => isProcessing = false,
    ); // ✅ interaction re-enabled immediately
  }

  Future<void> _askQuestion() async {
    // If user previously cancelled, stop chain
    if (_cancelRequested) {
      debugPrint("_askQuestion: cancelled at start");
      setState(() {
        isProcessing = false;
        spokenText = "Stopped.";
      });
      return;
    }

    await TtsService().stop();

    if (lastCapturedImage == null) {
      await _processScene();
      return;
    }

    setState(() {
      spokenText = "Listening for new question...";
      isProcessing = true; // only blocks during gemini analysis
    });

    Vibration.vibrate(duration: 400, amplitude: 250);
    final String newPrompt = await SpeechService.startListening();

    if (_cancelRequested) {
      debugPrint("_askQuestion: cancelled after listening");
      setState(() {
        isProcessing = false;
        spokenText = "Stopped.";
      });
      return;
    }

    if (newPrompt.trim().isEmpty) {
      setState(() {
        spokenText = "No more questions. Stopping";
        isProcessing = false;
      });
      await _playAudio(soundAsset: dualSound, vibrationDuration: 0);
      return;
    }

    final String historyPrompt = qaHistory
        .map((e) => "Question: ${e['question']}\nAnswer: ${e['answer']}")
        .join("\n\n");

    final String finalPrompt =
        historyPrompt.isNotEmpty
            ? "$historyPrompt\n\nNow answer this new question: $newPrompt"
            : newPrompt;

    setState(() => spokenText = "Processing...");
    final String? result = await GeminiService.processImageWithPrompt(
      imageBytes: lastCapturedImage!,
      prompt: finalPrompt,
    );

    if (_cancelRequested) {
      debugPrint("_askQuestion: cancelled after gemini");
      setState(() {
        isProcessing = false;
        spokenText = "Stopped.";
      });
      return;
    }

    if (result != null &&
        !result.toLowerCase().startsWith("error") &&
        !result.toLowerCase().contains("exception")) {
      final deviceId = await _getDeviceId();
      if (lastImageUrl != null && !_cancelRequested) {
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

      // ✅ Run TTS in background — skip if cancelled
      if (!_cancelRequested) {
        await TtsService().speak(result);
      }

      qaHistory.add({"question": newPrompt, "answer": result});
      if (qaHistory.length > 2) qaHistory.removeAt(0);

      // Trigger next _askQuestion only if not cancelled
      if (!_cancelRequested) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (!_cancelRequested) _askQuestion();
        });
      }
    } else {
      setState(() => spokenText = "Error occurred.");
      if (!_cancelRequested) TtsService().speak("Error occurred.");
    }

    setState(() => isProcessing = false);
  }

  /// Unified audio helper
  /// - [text]: optional TTS to speak
  /// - [soundAsset]: optional sound to play
  /// - [vibrationDuration]: vibration duration in ms
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
    _cameraService.stopCamera();
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
                "Launching Camera...",
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
          Positioned.fill(child: _cameraService.getCameraPreview()),

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
                              // single tap: start capture if not already processing
                              onTap:
                                  isProcessing
                                      ? null
                                      : () {
                                        // clear any previous cancellation when user explicitly triggers single click
                                        _cancelRequested = false;
                                        _processScene();
                                      },
                              // double tap: ALWAYS stop/cancel regardless of isProcessing
                              onDoubleTap: () async {
                                debugPrint(
                                  "🎯 Double tap on button — requesting stop",
                                );
                                await _requestStop();
                              },
                              child: AbsorbPointer(
                                child: ElevatedButton.icon(
                                  onPressed: () {}, // required for style
                                  icon: const Icon(
                                    Icons.image_search_rounded,
                                    color: Colors.black,
                                  ),
                                  label: Text(
                                    isProcessing
                                        ? "Processing..."
                                        : "Tap: Capture | Double Tap: Stop",
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        isProcessing
                                            ? Color.fromRGBO(255, 185, 89, 100)
                                            : Color.fromRGBO(255, 222, 89, 100),
                                    foregroundColor: Colors.white,
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
