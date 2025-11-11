import 'dart:typed_data';

import 'package:blindnavaiv3/services/camera_service_manager.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

class CameraService extends StatefulWidget {
  const CameraService({super.key});

  @override
  State<CameraService> createState() => CameraServiceState();
}

class CameraServiceState extends State<CameraService> {
  late CameraController controller;

  Future<Uint8List?> captureImage() async {
    try {
      if (!controller.value.isInitialized) return null;
      XFile file = await controller.takePicture();
      return await file.readAsBytes();
    } catch (e) {
      debugPrint("Error capturing image: $e");
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    final cameras = CameraServiceManager.instance.cameras;
    if (cameras == null || cameras.isEmpty) {
      debugPrint("No camera available");
      return;
    }
    controller = CameraController(cameras[0], ResolutionPreset.max);
    controller.initialize().then((_) {
      if (!mounted) {
        return;
      }
      setState(() {});
    }).catchError((Object e) {
      if (e is CameraException) {
        switch (e.code) {
          case 'CameraAccessDenied':
            break;
          default:
            break;
        }
      }
    });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!controller.value.isInitialized) {
      return Container();
    }
    return CameraPreview(controller);
  }
}
