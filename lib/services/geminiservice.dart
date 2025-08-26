import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class GeminiService {
  static const String _apiKey = 'AIzaSyB7DwfR6o7XLuaCkLDeAaUZ0_J6ayLtFKM';
  static const String _endpoint =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$_apiKey';

  static Future<String?> processImageWithPrompt({
    required Uint8List imageBytes,
    required String prompt,
  }) async {
    try {
      debugPrint("🔍 [GeminiService] Sending request...");
      debugPrint("📝 Prompt: $prompt");
      debugPrint("🖼️ Image bytes: ${imageBytes.length} bytes");
      final base64Image = base64Encode(imageBytes);

      final body = {
        "contents": [
          {
            "parts": [
              {
                "text":
                    "$prompt. Describe the scene in the image with one short, natural sentence that sounds like human speech, to guide a blind person in navigation; avoid markdown or symbols, keep it simple and direct, and always reply german.",
              },

              {
                "inline_data": {"mime_type": "image/jpeg", "data": base64Image},
              },
            ],
          },
        ],
      };

      debugPrint("📦 Request body size: ${jsonEncode(body).length}");

      final response = await http.post(
        Uri.parse(_endpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      debugPrint("📬 Response status: ${response.statusCode}");

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final text = json['candidates'][0]['content']['parts'][0]['text'];
        debugPrint("✅ Gemini Response: $text");
        return text;
      } else {
        debugPrint("❌ Error Response: ${response.body}");
        return "Error ${response.statusCode}: ${response.body}";
      }
    } catch (e) {
      debugPrint("❗ Exception: $e");
      return "Exception occurred: $e";
    }
  }
}
