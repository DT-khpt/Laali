import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart'; // REPLACED Supabase
import 'package:shared_preferences/shared_preferences.dart';
import 'welcome_page.dart';
import 'voice_signup_page.dart';
import 'voice_interface_page.dart';
import 'dashboard.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // REPLACED Supabase with Firebase initialization
  try {
    await Firebase.initializeApp();
    debugPrint('✅ Firebase initialized');
  } catch (e) {
    debugPrint('⚠️ Firebase.initialize() failed: $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _determineInitialRoute();
  }

  Future<void> _determineInitialRoute() async {
    try {
      // Wait a bit to ensure everything is initialized
      await Future.delayed(const Duration(milliseconds: 100));

      final prefs = await SharedPreferences.getInstance();
      final userMode = prefs.getString('userMode');

      // SIMPLIFIED: Just check if user has a mode set
      if (userMode != null && (userMode == 'anonymous' || userMode == 'account')) {
        setState(() {
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error determining initial route: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color headerTeal = Color(0xFF00796B);
    const Color actionBlue = Color(0xFF1976D2);

    final base = ThemeData(
      useMaterial3: true,
      fontFamily: 'Roboto',
      scaffoldBackgroundColor: Colors.white,
      colorScheme: ColorScheme.fromSeed(
        seedColor: headerTeal,
        primary: actionBlue,
        secondary: headerTeal,
        brightness: Brightness.light,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: headerTeal,
        foregroundColor: Colors.white,
        elevation: 1,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Colors.white,
          fontFamily: 'Roboto',
        ),
        iconTheme: IconThemeData(color: Colors.white),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: actionBlue,
          foregroundColor: Colors.white,
          elevation: 6.0,
          shadowColor: const Color(0x401976D2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
          padding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 18.0),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: headerTeal,
          side: const BorderSide(color: Color(0xE600796B)),
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

    // Show loading screen while determining initial route
    if (_isLoading) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: base,
        home: Scaffold(
          backgroundColor: Colors.white,
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(color: Color(0xFF00796B)),
                const SizedBox(height: 16),
                Text('ಲೋಡ್ ಆಗುತ್ತಿದೆ...', style: base.textTheme.bodyMedium),
              ],
            ),
          ),
        ),
      );
    }

    // Use the determined initial route - SIMPLIFIED APPROACH
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ಮಾತೃ ಆರೋಗ್ಯ',
      theme: base,

      // SIMPLE SOLUTION: Use home for the default route and onGenerateRoute for others
      home: const WelcomePage(), // This handles the '/' route

      // Handle other routes safely
      onGenerateRoute: (RouteSettings settings) {
        debugPrint('🔄 Generating route for: ${settings.name}');

        final String routeName = settings.name ?? '/';

        switch (routeName) {
          case '/signup':
            return MaterialPageRoute(builder: (context) => const VoiceSignupPage());
          case '/voice':
            return MaterialPageRoute(builder: (context) => const VoiceInterfacePage());
          case '/dashboard':
            return MaterialPageRoute(builder: (context) => const DashboardPage());
          case '/welcome':
            return MaterialPageRoute(builder: (context) => const WelcomePage());
          default:
          // Unknown routes go to welcome page
            return MaterialPageRoute(builder: (context) => const WelcomePage());
        }
      },
    );
  }
}