import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:mcp/config/routes.dart';
import 'package:mcp/config/theme_data.dart';
import 'package:mcp/provider/theme_provider.dart';
import 'package:mcp/provider/user_provider.dart';
import 'package:provider/provider.dart'; 
import '../services/video_search_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp();
    debugPrint('✅ Firebase initialized');
  } catch (e) {
    debugPrint('⚠️ Firebase.initialize() failed: $e');
  }

  try {
    await VideoSearchService().initialize();
    debugPrint('Video search service initialized successfully');
  } catch (e) {
    debugPrint('Failed to initialize video search service: $e');
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ಮಾತೃ ಆರೋಗ್ಯ',
      darkTheme: AppThemes.darkTheme,
      theme: AppThemes.lightTheme,
      themeMode: themeProvider.themeMode,
      initialRoute: Routes.splash,
      routes: AppPages.routes,
    );
  }
}

