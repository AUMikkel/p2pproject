import 'package:shared_preferences/shared_preferences.dart';

class UserSession {
  static final UserSession _instance = UserSession._internal();

  factory UserSession() => _instance;

  UserSession._internal();

  Future<void> saveUserData(String username, String email, String profileImageUrl) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('username', username); // Save username
    await prefs.setString('email', email);
    await prefs.setString('profileImageUrl', profileImageUrl);
  }

  Future<Map<String, String?>> getUserData() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'username': prefs.getString('username') ?? 'Unknown User',
      'email': prefs.getString('email') ?? 'No email provided',
      'profileImageUrl': prefs.getString('profileImageUrl') ?? 'https://example.com/default-profile.jpg',
    };
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}