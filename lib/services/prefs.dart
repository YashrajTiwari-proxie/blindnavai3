import 'package:shared_preferences/shared_preferences.dart';

class Prefs {
  static const _langKey = "selected_language";

  static Future<void> setLanguage(String langTag) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_langKey, langTag);
  }

  static Future<String> getLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_langKey) ?? "en-US"; // default English
  }
}
