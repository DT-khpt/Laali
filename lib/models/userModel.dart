import 'dart:convert';

class UserModel {
  final String id; // 🔥 Added from backend
  final String userMode; // Keep if needed locally
  final String username;
  final DateTime lmpDate;

  UserModel({
    required this.id,
    required this.userMode,
    required this.username,
    required this.lmpDate,
  });

  /// 🔹 For sending to backend
  Map<String, dynamic> toBackendMap() {
    return {
      "name": username,
      "date_set": lmpDate.toIso8601String().split('T')[0],
    };
  }

  /// 🔹 For receiving from backend
  factory UserModel.fromBackend(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'],
      userMode: "default", // backend doesn’t store this
      username: map['name'],
      lmpDate: DateTime.parse(map['date_set']),
    );
  }

  /// 🔹 Local storage (if still needed)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userMode': userMode,
      'username': username,
      'lmpDate': lmpDate.toIso8601String(),
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'],
      userMode: map['userMode'],
      username: map['username'],
      lmpDate: DateTime.parse(map['lmpDate']),
    );
  }

  String toJson() => jsonEncode(toMap());

  factory UserModel.fromJson(String source) =>
      UserModel.fromMap(jsonDecode(source));
}