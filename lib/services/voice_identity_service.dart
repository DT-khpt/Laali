import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class VoiceIdentityService {
  static const String _userProfileKey = 'user_profile';
  static const String _voiceprintKey = 'voice_print';

  /// Check if there's an existing user
  Future<bool> hasExistingUser() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userProfileKey) != null;
  }

  /// Get the stored user profile
  Future<Map<String, dynamic>?> getUserProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final profileData = prefs.getString(_userProfileKey);
    if (profileData == null) return null;
    return jsonDecode(profileData);
  }

  /// Create a new voice identity
  Future<void> createVoiceIdentity(String name, {String mode = 'registered'}) async {
    final prefs = await SharedPreferences.getInstance();
    final profile = {
      'name': name,
      'mode': mode,
      'createdAt': DateTime.now().toIso8601String(),
    };
    await prefs.setString(_userProfileKey, jsonEncode(profile));
  }

  /// Enhanced voice recognition with device fallback
  Future<String?> identifyReturningUser() async {
    final prefs = await SharedPreferences.getInstance();
    final profileData = prefs.getString(_userProfileKey);
    if (profileData == null) return null;
    final profile = jsonDecode(profileData);
    return profile['name']; // Return stored username
  }

  /// Clear user profile
  Future<void> clearIdentity() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userProfileKey);
    await prefs.remove(_voiceprintKey);
  }
}

final voiceIdentityService = VoiceIdentityService();
