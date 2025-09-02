import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<String?> uploadImage(Uint8List imageByte, String deviceId) async {
    try {
      final folderPath = "$deviceId/";
      final fileName = "${DateTime.now().millisecondsSinceEpoch}.jpg";
      final fullPath = "$folderPath$fileName";

      debugPrint("🔹 Uploading image to: $fullPath");

      final res = await _client.storage
          .from('captured-images')
          .uploadBinary(
            fullPath,
            imageByte,
            fileOptions: const FileOptions(contentType: 'image/jpeg'),
          );

      debugPrint("✅ Upload response: $res");
      return fullPath; // return path with folder
    } catch (e) {
      debugPrint("❌ Error Uploading image: $e");
      return null;
    }
  }

  Future<String?> getSignedUrl(
    String filePath, {
    int expiresInSeconds = 3600,
  }) async {
    try {
      final fileName = filePath.split('/').last;
      final url = await _client.storage
          .from('captured-images')
          .createSignedUrl(fileName, expiresInSeconds);

      debugPrint("🌐 Signed URL: $url");
      return url;
    } catch (e) {
      debugPrint("❌ Error generating signed URL: $e");
      return null;
    }
  }

  Future<void> saveLogJson({
    required String deviceId,
    required String imagePath,
    required String question,
    required String answer,
  }) async {
    try {
      debugPrint("🔹 Saving log for image: $imagePath");
      debugPrint("   Device: $deviceId");
      debugPrint("   Q: $question");
      debugPrint("   A: $answer");

      final response =
          await _client
              .from('logs')
              .select()
              .eq('image_url', imagePath)
              .maybeSingle();

      debugPrint("   Existing log found: ${response != null}");

      List<Map<String, dynamic>> qas = [];

      if (response != null) {
        qas = List<Map<String, dynamic>>.from(response['qas'] ?? []);
        debugPrint("   Current Q&A count: ${qas.length}");
      }

      qas.add({"question": question, "answer": answer});
      debugPrint("   New Q&A count: ${qas.length}");

      if (response != null) {
        final updateRes = await _client
            .from('logs')
            .update({"qas": qas})
            .eq('id', response['id']);
        debugPrint("   ✅ Updated existing log: $updateRes");
      } else {
        final insertRes = await _client.from('logs').insert({
          "device_id": deviceId,
          "image_url": imagePath,
          "qas": qas,
        });
        debugPrint("   ✅ Inserted new log: $insertRes");
      }
    } catch (e) {
      debugPrint("❌ Error Saving logs: $e");
    }
  }
}
