import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class GeminiService {
  static final String? _apiKey = dotenv.env['geminiapi'];
  static final String _endpoint =
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
                    "You are an AI describing images for visually impaired users. Follow these instructions:\n"
                    "1. Describe the image clearly in 1 short sentences.\n"
                    "2. Avoid repeating the user prompt.\n"
                    "3. Do not use markdown, symbols, or extraneous commentary.\n"
                    "4. Keep language simple, precise, and easy to visualize.\n"
                    "5. Always answer in English only.\n"
                    "User prompt: $prompt",
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

        try {
          final candidates = json['candidates'];
          if (candidates != null) {
            dynamic firstCandidate;
            if (candidates is List && candidates.isNotEmpty) {
              firstCandidate = candidates[0];
            } else if (candidates is Map) {
              firstCandidate = candidates;
            }

            final contentList = firstCandidate?['content'];
            dynamic firstContent;
            if (contentList is List && contentList.isNotEmpty) {
              firstContent = contentList[0];
            } else if (contentList is Map) {
              firstContent = contentList;
            }

            final partsList = firstContent?['parts'];
            dynamic firstPart;
            if (partsList is List && partsList.isNotEmpty) {
              firstPart = partsList[0];
            } else if (partsList is Map) {
              firstPart = partsList;
            }

            final text = firstPart?['text'];
            if (text is String) {
              debugPrint("✅ Gemini Response: $text");
              return text;
            }
          }

          debugPrint("❌ Gemini response missing expected fields: $json");
          return "Error";
        } catch (e) {
          debugPrint("❗ Parsing exception: $e");
          return "Error";
        }
      } else {
        debugPrint("❌ Error Response: ${response.body}");
        return "Error";
      }
    } catch (e) {
      debugPrint("❗ Exception: $e");
      return "Exception occurred: $e";
    }
  }
}
