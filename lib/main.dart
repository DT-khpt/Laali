// lib/main.dart
import 'package:flutter/material.dart';

// Core app pages — adjust paths if you placed files in subfolders.
import 'welcome_page.dart';
import 'voice_signup_page.dart';
import 'voice_interface_page.dart';
import 'dashboard.dart';
import 'not_found_page.dart';

// Your existing pages (if different filenames keep these imports)


void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ಮಾತೃ ಆರೋಗ್ಯ',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.pink),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      // Set WelcomePage as the initial route so it appears first when the app starts.
      initialRoute: '/welcome',
      routes: {
        '/welcome': (context) => const WelcomePage(),
        '/signup': (context) => const VoiceSignupPage(),
        '/voice': (context) => const VoiceInterfacePage(),
        '/dashboard': (context) => const DashboardPage(),
        // Redirect /login to the signup page
        '/login': (context) => const VoiceSignupPage(),

      },
      // Fallback for unknown routes -> NotFoundPage receives the attempted RouteSettings
      onUnknownRoute: (settings) => MaterialPageRoute(
        builder: (_) => const NotFoundPage(),
        settings: settings,
      ),
    );
  }
}
