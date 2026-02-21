import 'package:flutter/material.dart';
import 'package:mcp/screens/dashboard.dart';
import 'package:mcp/screens/splashScreen.dart';
import 'package:mcp/screens/voice_interface_page.dart';
import 'package:mcp/screens/voice_signup_page.dart';
import 'package:mcp/screens/welcome_page.dart';

class Routes {
  static const String splash = '/';
  static const String signup = '/signup';
  static const String voice = '/voice';
  static const String dashboard = '/dashboard';
  static const String welcome = '/welcome';
  static const String error = '/error';
}

class AppPages {
  static Map<String, WidgetBuilder> routes = {
    Routes.splash : (context) => const SplashScreen(),
    Routes.welcome: (context) => const WelcomePage(),
    Routes.signup: (context) => const VoiceSignupPage(),
    Routes.voice: (context) => const VoiceInterfacePage(),
    Routes.dashboard: (context) => const DashboardPage(),
  };
}