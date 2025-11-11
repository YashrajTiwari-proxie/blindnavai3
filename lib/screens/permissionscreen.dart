import 'dart:async';
import 'package:blindnavaiv3/screens/camerascreen.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionHandlerScreen extends StatefulWidget {
  const PermissionHandlerScreen({super.key});

  @override
  State<PermissionHandlerScreen> createState() =>
      _PermissionHandlerScreenState();
}

class _PermissionHandlerScreenState extends State<PermissionHandlerScreen> {
  bool _cameraGranted = false;
  bool _micGranted = false;
  bool _isLoading = true;
  Timer? _permissionCheckTimer;

  @override
  void initState() {
    super.initState();
    _initPermissions();
    _startPermissionAutoCheck();
  }

  @override
  void dispose() {
    _permissionCheckTimer?.cancel();
    super.dispose();
  }

  Future<void> _initPermissions() async {
    await Future.delayed(const Duration(seconds: 1)); // Simulated splash delay

    final cameraStatus = await Permission.camera.status;
    final micStatus = await Permission.microphone.status;

    if (mounted) {
      setState(() {
        _cameraGranted = cameraStatus.isGranted;
        _micGranted = micStatus.isGranted;
        _isLoading = false;
      });
    }
  }

  void _startPermissionAutoCheck() {
    _permissionCheckTimer = Timer.periodic(const Duration(milliseconds: 200), (
      _,
    ) async {
      final cameraStatus = await Permission.camera.status;
      final micStatus = await Permission.microphone.status;

      final cameraGranted = cameraStatus.isGranted;
      final micGranted = micStatus.isGranted;

      if (mounted) {
        setState(() {
          _cameraGranted = cameraGranted;
          _micGranted = micGranted;
        });
      }

      if (cameraGranted && micGranted) {
        _permissionCheckTimer?.cancel();
        _goToMainScreen();
      }
    });
  }

  void _goToMainScreen() {
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const CameraScreen()));
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
                    const Icon(
                      Icons.lock_outline,
                      size: 80,
                      color: Colors.redAccent,
                    ),
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
                      ],
                    ),
                    const SizedBox(height: 30),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color.fromRGBO(255, 222, 89, 100),
                      ),
                      onPressed: () async {
                        await Permission.camera.request();
                        await Permission.microphone.request();
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
                        backgroundColor: Color.fromRGBO(255, 222, 89, 100),
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
