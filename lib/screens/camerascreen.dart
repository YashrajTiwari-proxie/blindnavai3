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

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  CameraScreenState createState() => CameraScreenState();
}

class CameraScreenState extends State<CameraScreen> {
  final CameraServiceNative _cameraService = CameraServiceNative();
  final MethodChannel _screenChannel = const MethodChannel('screen_state');
  final SupabaseService _supabaseService = SupabaseService();
  bool _isCameraInitialized = false;
  bool isProcessing = false;
  String spokenText = "Press the button to begin.";
  Uint8List? lastCapturedImage;
  String? lastImageUrl;
  List<Map<String, String>> qaHistory = [];
  String deviceId = "unknown device";

  @override
  void initState() {
    super.initState();
    _delayedInitializeCamera();
    _setupScreenKeyListener();
    _initDeviceId();
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

  void _setupScreenKeyListener() {
    _screenChannel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'screenOff':
          debugPrint("Screen turned off! Stopping TTS...");
          await TtsService().stop();
          break;

        case 'keyPressed':
          final int keyCode = call.arguments;
          debugPrint("Key pressed: $keyCode");

          if (isProcessing) return;

          final now = DateTime.now();
          if (_lastKeyPressTime != null &&
              now.difference(_lastKeyPressTime!).inMilliseconds < 400) {
            // ✅ Double click detected (within 400ms)
            debugPrint("🎯 Double click detected on clicker");
            _askQuestion();
            _lastKeyPressTime = null; // reset
          } else {
            // ✅ Single click (first press)
            _lastKeyPressTime = now;
            Future.delayed(const Duration(milliseconds: 400), () {
              if (_lastKeyPressTime != null &&
                  DateTime.now()
                          .difference(_lastKeyPressTime!)
                          .inMilliseconds >=
                      400) {
                debugPrint("📸 Single click detected on clicker");
                _processScene();
                _lastKeyPressTime = null; // reset
              }
            });
          }
          break;

        case 'screenOn':
          debugPrint("Screen turned on");
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
    await TtsService().stop();
    if (_isCameraInitialized == false) return;

    setState(() {
      spokenText = "Capturing image...";
      isProcessing = true; // only blocks capture while analyzing
    });

    qaHistory = [];
    lastImageUrl = null;

    final Uint8List? imageBytes = await _cameraService.captureImage();
    if (imageBytes == null) {
      setState(() {
        spokenText = "Failed to capture image.";
        isProcessing = false;
      });
      return;
    }

    setState(() => spokenText = "Compressing image...");
    final Uint8List? compressedImage = await _compressImage(imageBytes);

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
    final String prompt = await SpeechService.startListening();

    setState(() => spokenText = "Processing...");
    final String? result = await GeminiService.processImageWithPrompt(
      imageBytes: compressedImage,
      prompt: prompt,
    );

    if (result != null &&
        !result.toLowerCase().startsWith("error") &&
        !result.toLowerCase().contains("exception")) {
      setState(() => spokenText = result);

      // ✅ Run TTS & save in background
      TtsService().speak(result);
      qaHistory.add({"question": prompt, "answer": result});
      if (qaHistory.length > 2) qaHistory.removeAt(0);

      final deviceId = await _getDeviceId();
      lastImageUrl ??= await _supabaseService.uploadImage(
        compressedImage,
        deviceId,
      );

      if (lastImageUrl != null) {
        // Run asynchronously, don’t block interaction
        unawaited(
          _supabaseService.saveLogJson(
            deviceId: deviceId,
            imagePath: lastImageUrl!,
            question: prompt,
            answer: result,
          ),
        );
      }
    } else {
      setState(() => spokenText = "Error occurred.");
      TtsService().speak("Error occurred.");
    }

    setState(
      () => isProcessing = false,
    ); // ✅ interaction re-enabled immediately
  }

  Future<void> _askQuestion() async {
    await TtsService().stop();
    if (lastCapturedImage == null) {
      await _processScene();
      return;
    }

    setState(() {
      spokenText = "Listening for new question...";
      isProcessing = true; // only blocks during gemini analysis
    });

    final String newPrompt = await SpeechService.startListening();

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

    if (result != null &&
        !result.toLowerCase().startsWith("error") &&
        !result.toLowerCase().contains("exception")) {
      setState(() => spokenText = result);

      // ✅ Run TTS in background
      TtsService().speak(result);

      qaHistory.add({"question": newPrompt, "answer": result});
      if (qaHistory.length > 2) qaHistory.removeAt(0);

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
    } else {
      setState(() => spokenText = "Error occurred.");
      TtsService().speak("Error occurred.");
    }

    setState(() => isProcessing = false);
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
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 20),
              Text(
                "Initializing camera...",
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
                        color: Colors.black.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Colors.black.withValues(alpha: 0.1),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            height: 60,
                            child: Image.asset(
                              "assets/BlindNavAi Logo.png",
                              fit: BoxFit.contain,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Row(
                            children: [
                              Icon(
                                Icons.phone_android_rounded,
                                size: 18,
                                color: Colors.white,
                              ),
                              SizedBox(width: 5),
                              Text(
                                deviceId,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 14,
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
                        color: Colors.black.withValues(alpha: 0.1),
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
                              onTap:
                                  isProcessing
                                      ? null
                                      : _processScene, // single tap
                              onDoubleTap:
                                  isProcessing
                                      ? null
                                      : _askQuestion, // double tap
                              child: AbsorbPointer(
                                // 👈 prevents the button from firing its onPressed
                                child: ElevatedButton.icon(
                                  onPressed:
                                      () {}, // 👈 must not be null, otherwise button looks disabled
                                  icon: const Icon(Icons.image_search_rounded),
                                  label: Text(
                                    isProcessing
                                        ? "Processing..."
                                        : "Tap: Capture | Double Tap: Ask",
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        isProcessing
                                            ? Colors.purple
                                            : Colors.deepPurpleAccent,
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

  /*
  Future<void> _askQuestion() async {
    if (lastCapturedImage == null) {
      // If no image, capture first instead of just erroring
      await _processScene();
      return;
    }

    setState(() {
      spokenText = "Listening for new question...";
      isProcessing = true;
    });

    final String newPrompt = await SpeechService.startListening();

    // Build history from last 2 Q&A
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

    if (result != null &&
        !result.toLowerCase().startsWith("error") &&
        !result.toLowerCase().contains("exception")) {
      await TtsService().speak(result);

      qaHistory.add({"question": newPrompt, "answer": result});
      if (qaHistory.length > 2) qaHistory.removeAt(0);

      final deviceId = await _getDeviceId(); // your device ID method
      if (lastImageUrl != null) {
        await _supabaseService.saveLogJson(
          deviceId: deviceId,
          imageUrl: lastImageUrl!,
          question: newPrompt,
          answer: result,
        );
      } else {
        debugPrint("❌ No image uploaded yet, skipping Supabase log.");
      }

      setState(() => spokenText = result);
    } else {
      await TtsService().speak("Error occurred.");
      setState(() => spokenText = "Error occurred.");
    }

    setState(() => isProcessing = false);
  }
  */

    /*
  // Image Procession and sending to gemini
  Future<void> _processScene() async {
    setState(() {
      spokenText = "Capturing image...";
      isProcessing = true;
    });

    qaHistory = [];
    lastImageUrl = null;

    final Uint8List? imageBytes = await _cameraService.captureImage();
    debugPrint("📸 Captured image: ${imageBytes?.lengthInBytes ?? 0} bytes");
    if (imageBytes == null) {
      setState(() {
        spokenText = "Failed to capture image.";
        isProcessing = false;
      });
      debugPrint("❌ Image capture failed or empty.");
      return;
    }

    setState(() => spokenText = "Compressing image...");
    final Uint8List? compressedImage = await _compressImage(imageBytes);

    if (compressedImage == null) {
      setState(() {
        spokenText = "Image compression failed";
        isProcessing = false;
      });
      return;
    }

    debugPrint(
      "📉 Compressed image size: ${compressedImage.lengthInBytes} bytes",
    );

    lastCapturedImage = compressedImage; // ✅ save image

    // Listening to prompt
    setState(() => spokenText = "Listening for prompt...");
    final String prompt = await SpeechService.startListening();
    debugPrint("🎙️ Recognized prompt: $prompt");

    setState(() => spokenText = "Processing...");
    final String? result = await GeminiService.processImageWithPrompt(
      imageBytes: compressedImage,
      prompt: prompt,
    );

    debugPrint("📤 Final result: $result");

    if (result != null &&
        !result.toLowerCase().startsWith("error") &&
        !result.toLowerCase().contains("exception")) {
      await TtsService().speak(result);

      // ✅ store first Q&A pair with consistent keys
      qaHistory.add({"question": prompt, "answer": result});
      if (qaHistory.length > 2) qaHistory.removeAt(0);

      final deviceId = await _getDeviceId();
      // After compression
      lastCapturedImage = compressedImage;

      // ✅ Upload image only once
      lastImageUrl ??= await _supabaseService.uploadImage(
        lastCapturedImage!,
        deviceId,
      );

      if (lastImageUrl != null) {
        await _supabaseService.saveLogJson(
          deviceId: deviceId,
          imageUrl: lastImageUrl!,
          question: prompt,
          answer: result,
        );
      } else {
        debugPrint("❌ Failed to upload image, skipping Supabase log.");
      }

      setState(() => spokenText = result);
    } else {
      spokenText = "Error occurred.";
      await TtsService().speak(spokenText);
    }

    setState(() {
      spokenText =
          (result != null &&
                  !result.toLowerCase().startsWith("error") &&
                  !result.toLowerCase().contains("exception"))
              ? result
              : "Error occurred.";
      isProcessing = false;
    });
  }
  */