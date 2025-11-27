import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';
import 'services/tts_service.dart';
import 'services/speech_service.dart';
import 'services/voice_identity_service.dart';
import 'services/firebase_service.dart';
import 'voice_interface_page.dart';
import 'voice_signup_page.dart';

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

  // SAFE NAVIGATION METHODS
  void _navigateToVoice() {
    try {
      Navigator.pushReplacementNamed(context, '/voice');
    } catch (e) {
      debugPrint('Navigation to voice failed: $e');
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const VoiceInterfacePage()),
            (route) => false,
      );
    }
  }

  void _navigateToSignup() {
    try {
      Navigator.pushNamed(context, '/signup');
    } catch (e) {
      debugPrint('Navigation to signup failed: $e');
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const VoiceSignupPage()),
      );
    }
  }

  // Start greeting sequence
  Future<void> _startGreeting() async {
    await Future.delayed(const Duration(seconds: 1));
    await _speak('ನಮಸ್ಕಾರ!ಮಾತೃತ್ವ ಆರೋಗ್ಯ ಸಹಾಯಕಕ್ಕೆ ಸ್ವಾಗತ.');
    await Future.delayed(const Duration(seconds: 1));
    await _speak('ಖಾತೆ ರಚಿಸಲು ಬಯಸುವಿರಾ? ಹೌದು ಅಥವಾ ಇಲ್ಲ ಎಂದು ಹೇಳಿ,ಮೈಕ್ ಟ್ಯಾಪ್ ಮಾಡಿ ಉತ್ತರಿಸಿ');
    setState(() {
      _hasGreeted = true;
    });
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
      await speechService.startListeningWithRetry((text, isFinal) {
        if (!mounted) return;
        setState(() => transcript = text);

        if (isFinal && text.isNotEmpty) {
          setState(() => isListening = false);
          _handleUserResponse(text);
        } else if (isFinal) {
          setState(() => isListening = false);
        }
      }, localeId: 'kn-IN', retries: 2, attemptTimeout: const Duration(seconds: 10));
    } catch (e) {
      if (mounted) setState(() => isListening = false);
    }
  }

  void _handleUserResponse(String text) async {
    final lower = text.toLowerCase();

    if (lower.contains('ಹೌದು') || lower.contains('yes')) {
      await _speak('ಖಾತೆ ರಚಿಸಲು ಮುಂದುವರೆಯುತ್ತಿದ್ದೇನೆ.');
      _navigateToSignup();
    } else if (lower.contains('ಇಲ್ಲ') || lower.contains('no')) {
      await _handleAnonymous();
    } else {
      await _speak('ಕ್ಷಮಿಸಿ, ನಾನು ಅರ್ಥಮಾಡಿಕೊಳ್ಳಲಿಲ್ಲ. ದಯವಿಟ್ಟು ಹೌದು ಅಥವಾ ಇಲ್ಲ ಎಂದು ಹೇಳಿ.');
      await _startListeningForResponse();
    }
  }

  Future<void> _handleAnonymous() async {
    try {
      final user = await _firebaseService.signInAnonymously();
      if (user != null) {
        await _firebaseService.createUserProfile(
            username: 'ಅತಿಥಿ',
            lmpDate: DateTime.now(),
            isAnonymous: true
        );

        await voiceIdentityService.createVoiceIdentity('ಅತಿಥಿ');

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('userMode', 'anonymous');
        await prefs.setBool('isAnonymous', true);
        await prefs.setString('username', 'ಅತಿಥಿ');
        await prefs.setString('lmpDate', DateTime.now().toIso8601String());

        await _speak('ಅನಾಮಧೇಯವಾಗಿ ಮುಂದುವರಿಯುತ್ತಿದ್ದೇನೆ.');
        _navigateToVoice();
      }
    } catch (e) {
      debugPrint('Anonymous error: $e');
      await _speak('ಕ್ಷಮಿಸಿ, ಪ್ರವೇಶದಲ್ಲಿ ಸಮಸ್ಯೆ ಉಂಟಾಗಿದೆ.');
      // Fallback to voice interface even if Firebase fails
      _navigateToVoice();
    }
  }

  Future<void> _prepareServices() async {
    await ttsService.setSpeechRate(0.4);
    await ttsService.setPitch(1.0);
    await speechService.initialize();
    if (!mounted) return;
  }

  Future<void> _speak(String text) async {
    if (text.isEmpty) return;
    try {
      setState(() => isSpeaking = true);
      await ttsService.speak(text);
    } catch (e) {
      debugPrint('TTS speak error: $e');
    } finally {
      if (mounted) setState(() => isSpeaking = false);
    }
  }

  Future<void> _toggleListening() async {
    if (isSpeaking) return;
    if (!_hasGreeted) return;

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
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Container(
          width: double.infinity,
          height: double.infinity,
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // New Logo
                  CircleAvatar(
                    radius: min(screenHeight * 0.1, 100.0),
                    backgroundColor: Colors.transparent,
                    backgroundImage: const AssetImage('assets/images/Laali Logo-01.jpg'),
                  ),
                  const SizedBox(height: 40),

                  // Greeting Text
                  Text(
                    'ನಮಸ್ಕಾರ!',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Question Text


                  // Voice Input Section
                  if (transcript.isNotEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: const Color(0x0D1976D2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0x331976D2)),
                      ),
                      child: Text(
                        transcript,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontStyle: FontStyle.italic,
                          color: Color(0xFF1976D2),
                          fontSize: 16,
                        ),
                      ),
                    ),

                  // Big Microphone Button with Box
                  Container(
                    padding: const EdgeInsets.all(30),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.grey[400]!,
                        width: 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 25,
                          offset: const Offset(0, 15),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          onTap: _toggleListening,
                          child: Container(
                            width: 170, // Bigger mic
                            height: 170, // Bigger mic
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isListening ? const Color(0xFFD32F2F) : const Color(0xFF00796B),
                              boxShadow: [
                                BoxShadow(
                                  color: (isListening ? const Color(0xFFD32F2F) : const Color(0xFF00796B)).withOpacity(0.3),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Icon(
                              isListening ? Icons.mic : Icons.mic_none,
                              color: Colors.white,
                              size: 80, // Bigger icon
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Status Text
                        Text(
                          isListening
                              ? 'ಕೇಳುತ್ತಿದೆ... ಮಾತನಾಡಿ'
                              : (isSpeaking
                              ? 'ಮಾತನಾಡುತ್ತಿದೆ...'
                              : 'ಮಾತನಾಡಲು ಟ್ಯಾಪ್ ಮಾಡಿ'),
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: Colors.grey[700],
                            fontWeight: FontWeight.w500,
                          ),
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