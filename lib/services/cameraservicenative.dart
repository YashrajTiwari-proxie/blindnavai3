import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CameraServiceNative {
  static final MethodChannel _channel = MethodChannel('camera_channel');

  Future<void> startCamera() async {
    try {
      final result = await _channel.invokeMethod<String>('startCamera');
      debugPrint(result);
    } catch (e) {
      debugPrint("Camera Error: $e");
    }
  }

  Future<void> stopCamera() async {
    try {
      await _channel.invokeMethod('stopCamera');
    } catch (e) {
      debugPrint("Stop error: $e");
    }
  }

  Future<Uint8List?> captureImage() async {
    try {
      final result = await _channel.invokeMethod<Uint8List>("captureImage");
      return result;
    } catch (e) {
      debugPrint("Capture failed: $e");
      return null;
    }
  }

  Widget getCameraPreview() {
    return const AndroidView(
      viewType: 'camera-preview-view',
      layoutDirection: TextDirection.ltr,
      creationParams: null,
      creationParamsCodec: StandardMessageCodec(),
    );
  }
}
