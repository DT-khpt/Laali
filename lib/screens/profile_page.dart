import 'package:flutter/material.dart';
import 'package:mcp/config/routes.dart';
import 'package:provider/provider.dart';
import '../provider/user_provider.dart';
import '../models/userModel.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final user = userProvider.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text("No User Logged In")),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Profile"),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [

            /// 🔵 PROFILE HEADER
            _ProfileHeader(user: user),

            const SizedBox(height: 20),

            /// 🧾 ACCOUNT INFO
            _buildSectionTitle("Account Information"),
            _infoTile("User ID", user.id),
            _infoTile("Name", user.username),

            const SizedBox(height: 25),

            /// ⚙ SETTINGS
            _buildSectionTitle("Settings"),

            _settingTile(
              icon: Icons.switch_account,
              title: "Switch Account",
              onTap: () => Navigator.pushNamedAndRemoveUntil(context, Routes.selectAccount, (routes)=>false ),
            ),

            _settingTile(
              icon: Icons.delete_outline,
              title: "Delete Account",
              // onTap: () => _confirmDelete(context, user.id),
              onTap: (){},
              color: Colors.red,
            ),

            _settingTile(
              icon: Icons.logout,
              title: "Logout",
              onTap: (){},
            ),

            const SizedBox(height: 25),

            /// 📊 APP INFO
            _buildSectionTitle("App Info"),
            _infoTile("Total Accounts",
                userProvider.users.length.toString()),

          ],
        ),
      ),
    );
  }

  /// ---------------- PROFILE HEADER ----------------
  Widget _ProfileHeader({required UserModel user}) {
    return Column(
      children: [
        const CircleAvatar(
          radius: 45,
          child: Icon(Icons.person, size: 45),
        ),
        const SizedBox(height: 12),
        Text(
          user.username,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          "ID: ${user.id}",
          style: const TextStyle(color: Colors.grey),
        ),
      ],
    );
  }

  /// ---------------- SECTION TITLE ----------------
  Widget _buildSectionTitle(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(
          title,
          style: const TextStyle(
              fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  /// ---------------- INFO TILE ----------------
  Widget _infoTile(String title, String value) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(title),
        subtitle: Text(value),
      ),
    );
  }

  /// ---------------- SETTING TILE ----------------
  Widget _settingTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? color,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(title,
            style: TextStyle(color: color ?? Colors.black)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }

  /// ---------------- SWITCH ACCOUNT ----------------


  /// ---------------- DELETE CONFIRM ----------------
  void _confirmDelete(BuildContext context, String userId) {
    final provider = context.read<UserProvider>();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete Account"),
        content: const Text(
            "Are you sure you want to delete this account?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {

            },
            child: const Text("Delete",
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}