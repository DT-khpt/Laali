import 'package:flutter/material.dart';
import 'package:mcp/config/routes.dart';
import 'package:provider/provider.dart';
import '../provider/user_provider.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    final userProvider = context.read<UserProvider>();

    await userProvider.loadUser();

    await Future.delayed(const Duration(seconds: 3));

    if (!mounted) return;

    if (userProvider.isLoggedIn) {
      Navigator.pushReplacementNamed(context, Routes.dashboard);
    } else {
      Navigator.pushReplacementNamed(context, Routes.welcome);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            CircleAvatar(
              radius: 50,
              backgroundImage:
                  AssetImage('assets/images/Laali Logo-03.jpg'),
            ),
            SizedBox(height: 20),
            Text(
              "ಮಾತೃ ಆರೋಗ್ಯ",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 30),
            CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}