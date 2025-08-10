import 'package:five_flix/services/api_service.dart';

class SessionService {
  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'user_data';

  static Future<void> saveSession(
    String token,
    Map<String, dynamic> user,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_userKey, jsonEncode(user));
    ApiService.setAuthToken(token);
  }

  static Future<Map<String, dynamic>?> getSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    final userData = prefs.getString(_userKey);

    if (token != null && userData != null) {
      ApiService.setAuthToken(token);
      return {'token': token, 'user': jsonDecode(userData)};
    }
    return null;
  }
}
