import 'dart:ui';

import 'package:blindnavaiv3/services/cameraservicenative.dart';
import 'package:blindnavaiv3/services/geminiservice.dart';
import 'package:blindnavaiv3/services/speechservice.dart';
import 'package:blindnavaiv3/services/ttsservice.dart';
import 'package:flutter/material.dart';
import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  CameraScreenState createState() => CameraScreenState();
}

class CameraScreenState extends State<CameraScreen> {
  final CameraServiceNative _cameraService = CameraServiceNative();
  bool _isCameraInitialized = false;
  bool isProcessing = false;
  String spokenText = "Press the button to begin.";

  @override
  void initState() {
    super.initState();
    _delayedInitializeCamera();
  }

  Future<void> _delayedInitializeCamera() async {
    await _cameraService.startCamera();
    await Future.delayed(const Duration(milliseconds: 600));

    setState(() {
      _isCameraInitialized = true;
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

  // Image Procession and sending to gemini
  Future<void> _processScene() async {
    setState(() {
      spokenText = "Capturing image...";
      isProcessing = true;
    });

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

    //Listening to prompt
    setState(() => spokenText = "Listening for prompt...");
    final String prompt = await SpeechService.startListening();
    debugPrint("🎙️ Recognized prompt: $prompt");

    setState(() => spokenText = "Processing...");
    final String? result = await GeminiService.processImageWithPrompt(
      imageBytes: compressedImage,
      prompt: prompt,
    );

    debugPrint("📤 Final result: $result");

    if (result != null && !result.toLowerCase().startsWith("error")) {
      await TtsService().speak(result);
    }

    setState(() {
      spokenText = result ?? "Something went wrong.";
      isProcessing = false;
    });
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
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2),
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
                            child: ElevatedButton.icon(
                              onPressed: isProcessing ? null : _processScene,
                              icon: const Icon(Icons.image_search_rounded),
                              label: Text(
                                isProcessing
                                    ? "Processing..."
                                    : "Analyze Scene",
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
