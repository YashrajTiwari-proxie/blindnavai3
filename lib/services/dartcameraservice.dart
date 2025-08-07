import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

class CameraService {
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  int _currentCameraIndex = 0;

  CameraController? get controller => _cameraController;

  CameraLensDirection get currentLensDirection =>
      _cameras[_currentCameraIndex].lensDirection;

  /*
  Future<void> playCaptureSound() async {
    final player = AudioPlayer();
    await player.stop();
    await player.play(AssetSource('audio/correct-answer-chime-01.wav'));
  }
  */

  Future<void> initializeCamera() async {
    try {
      _cameras = await availableCameras();

      if (_cameras.isEmpty) {
        debugPrint("No cameras available!");
        return;
      }

      _currentCameraIndex = 0;
      await _initController(_cameras[_currentCameraIndex]);
    } catch (e) {
      debugPrint("Error initializing camera: $e");
    }
  }

  Future<void> switchCamera() async {
    if (_cameras.length < 2) {
      debugPrint("Only one camera available, cannot switch.");
      return;
    }

    _currentCameraIndex = (_currentCameraIndex + 1) % _cameras.length;
    await _initController(_cameras[_currentCameraIndex]);

    final direction = _cameras[_currentCameraIndex].lensDirection;
    String announcement =
        direction == CameraLensDirection.front
            ? "Front camera activated"
            : "Back camera activated";
    //await TtsService().speak(announcement);
  }

  Future<void> _initController(CameraDescription cameraDescription) async {
    try {
      await _cameraController?.dispose();
      _cameraController = CameraController(
        cameraDescription,
        ResolutionPreset.medium,
      );
      await _cameraController!.initialize();
      debugPrint("Camera switched to: ${cameraDescription.lensDirection}");
    } catch (e) {
      debugPrint("Error initializing camera controller: $e");
    }
  }

  Widget getCameraPreview(BuildContext context) {
    if (_cameraController != null && _cameraController!.value.isInitialized) {
      double aspectRatio = _cameraController!.value.aspectRatio;

      return AspectRatio(
        aspectRatio: aspectRatio,
        child: CameraPreview(_cameraController!),
      );
    } else {
      return const Center(child: CircularProgressIndicator());
    }
  }

  Future<void> saveImageToFile(
    Uint8List imageBytes, {
    String filename = "debug_image.jpg",
  }) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final path = '${directory.path}/$filename';
      final file = File(path);
      await file.writeAsBytes(imageBytes);
      debugPrint('Image saved to: $path');
    } catch (e) {
      debugPrint('Error saving image: $e');
    }
  }

  Future<Uint8List?> captureImageBytes(BuildContext context) async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return null;
    }

    try {
      //await playCaptureSound();

      final XFile imageFile = await _cameraController!.takePicture();
      final Uint8List imageBytes = await imageFile.readAsBytes();

      img.Image? originalImage = img.decodeImage(imageBytes);
      if (originalImage == null) return null;

      img.Image rotated = img.copyRotate(originalImage, angle: 0);

      final lensDirection = _cameras[_currentCameraIndex].lensDirection;
      if (lensDirection == CameraLensDirection.front) {
        rotated = img.flipHorizontal(rotated);
      }

      final img.Image resized = img.copyResize(rotated, width: 300);
      final Uint8List compressedBytes = Uint8List.fromList(
        img.encodeJpg(resized, quality: 50),
      );

      await saveImageToFile(compressedBytes, filename: "rotated_debug.jpg");

      debugPrint("Image fixed with +90° rotation (${lensDirection.name})");

      return compressedBytes;
    } catch (e) {
      debugPrint('Error capturing image: $e');
      return null;
    }
  }
}
