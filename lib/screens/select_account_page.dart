import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../provider/user_provider.dart';
import '../config/routes.dart';

class SelectAccountPage extends StatelessWidget {
  const SelectAccountPage({super.key});

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Select Account"),
        centerTitle: true,
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: userProvider.users.length + 1,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 20,
          crossAxisSpacing: 20,
        ),
        itemBuilder: (context, index) {
          // ➕ Add New Account Button
          if (index == userProvider.users.length) {
            return GestureDetector(
              onTap: () {
                Navigator.pushNamed(context, Routes.welcome);
              },
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  CircleAvatar(
                    radius: 40,
                    child: Icon(Icons.add, size: 40),
                  ),
                  SizedBox(height: 10),
                  Text("Add Account"),
                ],
              ),
            );
          }

          final user = userProvider.users[index];

          return GestureDetector(
            onTap: () async {
              await userProvider.switchUser(user);
              Navigator.pushReplacementNamed(context, Routes.dashboard);
            },
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.teal,
                  child: Icon(Icons.person, size: 40, color: Colors.white),
                ),
                const SizedBox(height: 10),
                Text(
                  user.username,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}