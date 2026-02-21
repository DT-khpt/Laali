import 'dart:convert';

class UserModel {
  final String userMode;
  final String username;
  final DateTime lmpDate;

  UserModel({
    required this.userMode,
    required this.username,
    required this.lmpDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'userMode': userMode,
      'username': username,
      'lmpDate': lmpDate.toIso8601String(),
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      userMode: map['userMode'],
      username: map['username'],
      lmpDate: DateTime.parse(map['lmpDate']),
    );
  }

  String toJson() => jsonEncode(toMap());

  factory UserModel.fromJson(String source) =>
      UserModel.fromMap(jsonDecode(source));
}