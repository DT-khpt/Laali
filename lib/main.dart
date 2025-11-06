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
    // Theme colors per design request
    const Color headerTeal = Color(0xFF00796B);
    const Color actionBlue = Color(0xFF1976D2);

    final base = ThemeData(
      useMaterial3: true,
      fontFamily: 'Roboto',
      scaffoldBackgroundColor: Colors.white,
      colorScheme: ColorScheme.fromSeed(seedColor: headerTeal, primary: actionBlue, secondary: headerTeal, brightness: Brightness.light),
      appBarTheme: const AppBarTheme(
        backgroundColor: headerTeal,
        foregroundColor: Colors.white,
        elevation: 1,
        centerTitle: true,
        titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white, fontFamily: 'Roboto'),
        iconTheme: IconThemeData(color: Colors.white),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: actionBlue,
          foregroundColor: Colors.white,
          elevation: 6.0,
          shadowColor: const Color(0x401976D2), // ~25% blue
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
          padding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 18.0),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: headerTeal,
          side: const BorderSide(color: Color(0xE600796B)), // ~90% teal
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
          padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      iconTheme: const IconThemeData(color: headerTeal, size: 22),
      textTheme: const TextTheme(
        displayLarge: TextStyle(fontSize: 34, fontWeight: FontWeight.bold, color: Colors.black87),
        displayMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black87),
        headlineSmall: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.black87),
        titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.black87),
        bodyLarge: TextStyle(fontSize: 16, color: Colors.black87),
        bodyMedium: TextStyle(fontSize: 14, color: Colors.black87),
      ),
      dividerTheme: const DividerThemeData(space: 0, thickness: 1, color: Color(0xFFE8E8E8)),
      visualDensity: VisualDensity.adaptivePlatformDensity,
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ಮಾತೃ ಆರೋಗ್ಯ',
      theme: base,
      // Set WelcomePage as the initial route so it appears first when the app starts.
      initialRoute: '/',
      routes: {
        '/': (context) => const WelcomePage(),
        '/welcome': (context) => const WelcomePage(),
        '/signup': (context) => const VoiceSignupPage(),
        '/voice': (context) => const VoiceInterfacePage(),
        '/dashboard': (context) => const DashboardPage(),
      },
      // Fallback for unknown routes -> NotFoundPage receives the attempted RouteSettings
      onUnknownRoute: (settings) => MaterialPageRoute(
        builder: (_) => const NotFoundPage(),
        settings: settings,
      ),
    );
  }
}
