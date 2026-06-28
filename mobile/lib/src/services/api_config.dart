import 'package:shared_preferences/shared_preferences.dart';

class ApiConfig {
  static const String _baseUrlKey = 'api_base_url';
  static const String defaultBaseUrl = 'https://api-production-188f2.up.railway.app';

  static Future<String> getBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_baseUrlKey) ?? defaultBaseUrl;
  }

  static Future<void> setBaseUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_baseUrlKey, url);
  }
}
