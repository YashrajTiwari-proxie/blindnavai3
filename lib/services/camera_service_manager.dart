import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

class CameraServiceManager {
  CameraServiceManager._privateConstructor();
  static final CameraServiceManager _instance =
      CameraServiceManager._privateConstructor();
  static CameraServiceManager get instance => _instance;

  List<CameraDescription>? _cameras;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    try {
      _cameras = await availableCameras();
      _initialized = true;
    } catch (e) {
      debugPrint("Error initializing cameras: $e");
    }
  }

  List<CameraDescription>? get cameras => _cameras;
  bool get isInitialized => _initialized;
}
