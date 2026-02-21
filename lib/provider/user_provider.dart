import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/userModel.dart';

class UserProvider extends ChangeNotifier {
  static const String _userKey = 'userData';

  UserModel? _user;
  UserModel? get user => _user;

  bool get isLoggedIn => _user != null;

  Future<void> loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userString = prefs.getString(_userKey);

    if (userString != null) {
      _user = UserModel.fromJson(userString);
    } else {
      _user = null;
    }

    notifyListeners();
  }

  Future<void> saveUser(UserModel user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, user.toJson());
    _user = user;
    notifyListeners();
  }

  Future<void> clearUser() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userKey);
    _user = null;
    notifyListeners();
  }
}