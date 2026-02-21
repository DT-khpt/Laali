import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/routes.dart';
import '../models/userModel.dart';
import '../provider/user_provider.dart';
import '../services/tts_service.dart';
import '../services/speech_service.dart';
import '../services/voice_identity_service.dart';
import '../services/firebase_service.dart';

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  bool isListening = false;
  bool isSpeaking = false;
  String transcript = '';
  bool _hasGreeted = false;

  final FirebaseService _firebaseService = FirebaseService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _prepareServices();
      _startGreeting();
    });
  }


  Future<void> _startGreeting() async {
    await Future.delayed(const Duration(seconds: 1));
    await _speak('ನಮಸ್ಕಾರ! ಮಾತೃತ್ವ ಆರೋಗ್ಯ ಸಹಾಯಕಕ್ಕೆ ಸ್ವಾಗತ.');
    await Future.delayed(const Duration(seconds: 1));
    await _speak(
        'ಖಾತೆ ರಚಿಸಲು ಬಯಸುವಿರಾ? ಹೌದು ಅಥವಾ ಇಲ್ಲ ಎಂದು ಹೇಳಿ, ಮೈಕ್ ಟ್ಯಾಪ್ ಮಾಡಿ ಉತ್ತರಿಸಿ');

    if (mounted) {
      setState(() => _hasGreeted = true);
    }
  }


  Future<void> _startListeningForResponse() async {
    if (isSpeaking) {
      await _speak('ದಯವಿಟ್ಟು ಕೆಲವು ಕ್ಷಣಗಳಲ್ಲಿ ಪ್ರಯತ್ನಿಸಿ.');
      return;
    }

    if (!_hasGreeted) return;

    final ok = await speechService.initialize();
    if (!ok) {
      await _speak('ಕ್ಷಮಿಸಿ, ಮೈಕ್ರೊಫೋನ್ ಲಭ್ಯವಿಲ್ಲ.');
      return;
    }

    setState(() {
      isListening = true;
      transcript = '';
    });

    try {
      await speechService.startListeningWithRetry(
        (text, isFinal) {
          if (!mounted) return;

          setState(() => transcript = text);

          if (isFinal && text.isNotEmpty) {
            setState(() => isListening = false);
            _handleUserResponse(text);
          } else if (isFinal) {
            setState(() => isListening = false);
          }
        },
        localeId: 'kn-IN',
        retries: 2,
        attemptTimeout: const Duration(seconds: 10),
      );
    } catch (_) {
      if (mounted) setState(() => isListening = false);
    }
  }


  Future<void> _handleUserResponse(String text) async {
    final lower = text.toLowerCase();

    if (lower.contains('ಹೌದು') || lower.contains('yes')) {
      await _speak('ಖಾತೆ ರಚಿಸಲು ಮುಂದುವರೆಯುತ್ತಿದ್ದೇನೆ.');
      if (!mounted) return;
      Navigator.pushNamed(context, Routes.signup);
    } else if (lower.contains('ಇಲ್ಲ') || lower.contains('no')) {
      await _handleAnonymous();
    } else {
      await _speak(
          'ಕ್ಷಮಿಸಿ, ನಾನು ಅರ್ಥಮಾಡಿಕೊಳ್ಳಲಿಲ್ಲ. ದಯವಿಟ್ಟು ಹೌದು ಅಥವಾ ಇಲ್ಲ ಎಂದು ಹೇಳಿ.');
      await _startListeningForResponse();
    }
  }


  Future<void> _handleAnonymous() async {
    try {
      final userProvider = context.read<UserProvider>();

      final firebaseUser =
          await _firebaseService.signInAnonymously();

      if (firebaseUser != null) {
        final now = DateTime.now();

        await _firebaseService.createUserProfile(
          username: 'ಅತಿಥಿ',
          lmpDate: now,
          isAnonymous: true,
        );

        await voiceIdentityService.createVoiceIdentity('ಅತಿಥಿ');

        final userModel = UserModel(
          userMode: 'anonymous',
          username: 'ಅತಿಥಿ',
          lmpDate: now,
        );

        await userProvider.saveUser(userModel);

        await _speak('ಅನಾಮಧೇಯವಾಗಿ ಮುಂದುವರಿಯುತ್ತಿದ್ದೇನೆ.');

        if (!mounted) return;
        Navigator.pushReplacementNamed(context, Routes.dashboard);
      }
    } catch (e) {
      debugPrint('Anonymous error: $e');
      await _speak('ಕ್ಷಮಿಸಿ, ಪ್ರವೇಶದಲ್ಲಿ ಸಮಸ್ಯೆ ಉಂಟಾಗಿದೆ.');

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, Routes.dashboard);
    }
  }


  Future<void> _prepareServices() async {
    await ttsService.setSpeechRate(0.4);
    await ttsService.setPitch(1.0);
    await speechService.initialize();
  }

  Future<void> _speak(String text) async {
    if (text.isEmpty) return;

    try {
      setState(() => isSpeaking = true);
      await ttsService.speak(text);
    } catch (e) {
      debugPrint('TTS error: $e');
    } finally {
      if (mounted) setState(() => isSpeaking = false);
    }
  }

  Future<void> _toggleListening() async {
    if (isSpeaking || !_hasGreeted) return;

    if (!isListening) {
      await _startListeningForResponse();
    } else {
      await speechService.stop();
      setState(() => isListening = false);
    }
  }

  @override
  void dispose() {
    speechService.cancel();
    ttsService.stop();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [

                  CircleAvatar(
                    radius: min(screenHeight * 0.1, 100.0),
                    backgroundColor: Colors.transparent,
                    backgroundImage: const AssetImage(
                        'assets/images/Laali Logo-01.jpg'),
                  ),

                  const SizedBox(height: 40),

                  Text(
                    'ನಮಸ್ಕಾರ!',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  const SizedBox(height: 20),

                  if (transcript.isNotEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: theme.colorScheme.primary.withOpacity(0.3)),
                      ),
                      child: Text(
                        transcript,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontStyle: FontStyle.italic,
                          color: theme.colorScheme.primary,
                          fontSize: 16,
                        ),
                      ),
                    ),

                  Container(
                    padding: const EdgeInsets.all(30),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: theme.shadowColor.withOpacity(0.1),
                          blurRadius: 25,
                          offset: const Offset(0, 15),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [

                        GestureDetector(
                          onTap: _toggleListening,
                          child: Container(
                            width: 170,
                            height: 170,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isListening
                                  ? theme.colorScheme.error
                                  : theme.colorScheme.primary,
                              boxShadow: [
                                BoxShadow(
                                  color: (isListening
                                          ? theme.colorScheme.error
                                          : theme.colorScheme.primary)
                                      .withOpacity(0.3),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Icon(
                              isListening ? Icons.mic : Icons.mic_none,
                              color: Colors.white,
                              size: 80,
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        Text(
                          isListening
                              ? 'ಕೇಳುತ್ತಿದೆ... ಮಾತನಾಡಿ'
                              : (isSpeaking
                                  ? 'ಮಾತನಾಡುತ್ತಿದೆ...'
                                  : 'ಮಾತನಾಡಲು ಟ್ಯಾಪ್ ಮಾಡಿ'),
                          style: theme.textTheme.bodyLarge,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}