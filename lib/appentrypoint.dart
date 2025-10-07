import 'package:blindnavaiv3/screens/camerascreen.dart';
import 'package:blindnavaiv3/screens/permissionscreen.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:blindnavaiv3/services/ttsservice.dart';

class AppEntryPoint extends StatefulWidget {
  const AppEntryPoint({super.key});

  @override
  State<AppEntryPoint> createState() => _AppEntryPointState();
}

class _AppEntryPointState extends State<AppEntryPoint> {
  bool _isChecking = true;
  bool _permissionsGranted = false;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    await Future.delayed(const Duration(seconds: 1));

    final cameraStatus = await Permission.camera.status;
    final micStatus = await Permission.microphone.status;

    final granted = cameraStatus.isGranted && micStatus.isGranted;

    setState(() {
      _permissionsGranted = granted;
      _isChecking = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Colors.amberAccent),
              SizedBox(height: 16),
              Text(
                "Hilfy wird gestartet …",
                style: TextStyle(fontSize: 16, color: Colors.white),
              ),
            ],
          ),
        ),
      );
    }

    return _permissionsGranted
        ? const CameraScreen()
        : const PermissionHandlerScreen();
  }
}
