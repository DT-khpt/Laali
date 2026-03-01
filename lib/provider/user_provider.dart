import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/userModel.dart';

class UserProvider extends ChangeNotifier {
  static const String _usersKey = 'usersList';
  static const String _currentUserKey = 'currentUser';

  List<UserModel> _users = [];
  UserModel? _currentUser;

  List<UserModel> get users => _users;
  UserModel? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;

  /// Load all users + current active user
  Future<void> loadUsers() async {
    final prefs = await SharedPreferences.getInstance();

    // Load users list
    final usersString = prefs.getString(_usersKey);
    if (usersString != null) {
      final List decoded = jsonDecode(usersString);
      _users = decoded.map((e) => UserModel.fromMap(e)).toList();
    }

    // Load current user
    final currentUserString = prefs.getString(_currentUserKey);
    if (currentUserString != null) {
      _currentUser = UserModel.fromMap(jsonDecode(currentUserString));
    }

    notifyListeners();
  }

  /// Add new account
  Future<void> addUser(UserModel user) async {
    final prefs = await SharedPreferences.getInstance();

    _users.add(user);

    await prefs.setString(
      _usersKey,
      jsonEncode(_users.map((e) => e.toMap()).toList()),
    );

    // Automatically switch to new user
    await switchUser(user);

    notifyListeners();
  }

  /// Switch active account
  Future<void> switchUser(UserModel user) async {
    final prefs = await SharedPreferences.getInstance();

    _currentUser = user;

    await prefs.setString(
      _currentUserKey,
      jsonEncode(user.toMap()),
    );

    notifyListeners();
  }

  /// Remove specific account
  Future<void> removeUser(UserModel user) async {
    final prefs = await SharedPreferences.getInstance();

    _users.removeWhere((u) => u.id == user.id);

    await prefs.setString(
      _usersKey,
      jsonEncode(_users.map((e) => e.toMap()).toList()),
    );

    // If removed user was current → logout
    if (_currentUser?.id == user.id) {
      await logout();
    }

    notifyListeners();
  }

  /// Logout current account only
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove(_currentUserKey);
    _currentUser = null;

    notifyListeners();
  }

  Future<String> generateUserId() async {
    final prefs = await SharedPreferences.getInstance();

    int count = prefs.getInt('userCounter') ?? 0;
    count++;

    await prefs.setInt('userCounter', count);

    return 'USER_${count.toString().padLeft(3, '0')}';
  }
}