import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:blindnavaiv3/screens/camerascreen.dart';

class PermissionHandlerScreen extends StatefulWidget {
  const PermissionHandlerScreen({super.key});

  @override
  State<PermissionHandlerScreen> createState() =>
      _PermissionHandlerScreenState();
}

class _PermissionHandlerScreenState extends State<PermissionHandlerScreen> {
  bool _cameraGranted = false;
  bool _micGranted = false;
  bool _speechGranted = false; // iOS only
  bool _isLoading = true;
  Timer? _permissionCheckTimer;

  @override
  void initState() {
    super.initState();
    _requestPermissionsOnStart();
    _startPermissionAutoCheck();
  }

  @override
  void dispose() {
    _permissionCheckTimer?.cancel();
    super.dispose();
  }

  /// 🔹 Immediately request permissions when entering screen
  Future<void> _requestPermissionsOnStart() async {
    await Future.delayed(const Duration(milliseconds: 500));

    await Permission.camera.request();
    await Permission.microphone.request();
    if (Platform.isIOS) {
      await Permission.speech.request();
    }

    await _initPermissions(); // Re-check and update UI after request
  }

  Future<void> _initPermissions() async {
    final cameraStatus = await Permission.camera.status;
    final micStatus = await Permission.microphone.status;
    PermissionStatus? speechStatus;

    if (Platform.isIOS) {
      speechStatus = await Permission.speech.status;
    }

    if (mounted) {
      setState(() {
        _cameraGranted = cameraStatus.isGranted;
        _micGranted = micStatus.isGranted;
        _speechGranted =
            speechStatus?.isGranted ?? true; // Default true on Android
        _isLoading = false;
      });
    }
  }

  void _startPermissionAutoCheck() {
    _permissionCheckTimer =
        Timer.periodic(const Duration(milliseconds: 400), (_) async {
      final cameraStatus = await Permission.camera.status;
      final micStatus = await Permission.microphone.status;
      PermissionStatus? speechStatus;

      if (Platform.isIOS) {
        speechStatus = await Permission.speech.status;
      }

      final cameraGranted = cameraStatus.isGranted;
      final micGranted = micStatus.isGranted;
      final speechGranted = speechStatus?.isGranted ?? true;

      if (mounted) {
        setState(() {
          _cameraGranted = cameraGranted;
          _micGranted = micGranted;
          _speechGranted = speechGranted;
        });
      }

      if (cameraGranted && micGranted && speechGranted) {
        _permissionCheckTimer?.cancel();
        _goToMainScreen();
      }
    });
  }

  void _goToMainScreen() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const CameraScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Colors.amberAccent),
                  SizedBox(height: 20),
                  Text(
                    "Checking permissions...",
                    style: TextStyle(fontSize: 16, color: Colors.white),
                  ),
                ],
              ),
            )
          : Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.lock_outline,
                        size: 80, color: Colors.redAccent),
                    const SizedBox(height: 20),
                    const Text(
                      "Hilfy benötigt Zugriff auf die Kamera und das Mikrofon, um korrekt zu funktionieren.",
                      style: TextStyle(fontSize: 18, color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 30),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _cameraGranted
                              ? Icons.camera_alt
                              : Icons.camera_alt_outlined,
                          color:
                              _cameraGranted ? Colors.green : Colors.redAccent,
                          size: 40,
                        ),
                        const SizedBox(width: 30),
                        Icon(
                          _micGranted ? Icons.mic : Icons.mic_off,
                          color: _micGranted ? Colors.green : Colors.redAccent,
                          size: 40,
                        ),
                        if (Platform.isIOS) ...[
                          const SizedBox(width: 30),
                          Icon(
                            _speechGranted
                                ? Icons.record_voice_over
                                : Icons.mic_off,
                            color: _speechGranted
                                ? Colors.green
                                : Colors.redAccent,
                            size: 40,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 30),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            const Color.fromRGBO(255, 222, 89, 100),
                      ),
                      onPressed: () async {
                        await Permission.camera.request();
                        await Permission.microphone.request();
                        if (Platform.isIOS) {
                          await Permission.speech.request();
                        }
                        _initPermissions();
                      },
                      icon: const Icon(Icons.refresh, color: Colors.black),
                      label: const Text(
                        "Refresh Permissions",
                        style: TextStyle(color: Colors.black),
                      ),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            const Color.fromRGBO(255, 222, 89, 100),
                      ),
                      onPressed: openAppSettings,
                      icon: const Icon(Icons.settings, color: Colors.black),
                      label: const Text(
                        "Open App Settings",
                        style: TextStyle(color: Colors.black),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
