import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';
import 'services/tts_service.dart';
import 'services/speech_service.dart';
import 'services/voice_identity_service.dart';
import 'services/firebase_service.dart';
import 'voice_interface_page.dart';
import 'voice_signup_page.dart';
import 'dashboard.dart';

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  bool isListening = false;
  bool isSpeaking = false;
  String transcript = '';
  String? returningUsername;
  DateTime? returningUserLMP;
  String _currentFlow = 'initial'; // 'initial', 'confirm_identity', 'verify_lmp'

  final FirebaseService _firebaseService = FirebaseService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _prepareServices();
      _checkReturningUser();
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

  void _navigateToDashboard() {
    try {
      Navigator.pushReplacementNamed(context, '/dashboard');
    } catch (e) {
      debugPrint('Navigation to dashboard failed: $e');
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const DashboardPage()),
            (route) => false,
      );
    }
  }

  Future<void> _checkReturningUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userMode = prefs.getString('userMode');
    final username = prefs.getString('username');
    final lmpStr = prefs.getString('lmpDate');

    if (userMode == 'account' && username != null) {
      setState(() {
        returningUsername = username;
        if (lmpStr != null) {
          try {
            returningUserLMP = DateTime.parse(lmpStr);
          } catch (e) {
            debugPrint('Error parsing LMP date: $e');
          }
        }
      });

      await Future.delayed(const Duration(seconds: 1));
      await _speak('ನಮಸ್ಕಾರ! ನೀವು $username ಖಾತೆಯೊಂದಿಗೆ ಮುಂದುವರೆಯಲು ಬಯಸುವಿರಾ? ಹೌದು ಅಥವಾ ಇಲ್ಲ ಎಂದು ಹೇಳಿ.');
    } else {
      await Future.delayed(const Duration(seconds: 1));
      await _speak('ನಿಮ್ಮ ಮಾಹಿತಿಯನ್ನು ಶೇಖರಿಸಲು ನೀವು ಬಯಸುವಿರಾ? ಹೌದು ಅಥವಾ ಇಲ್ಲ ಎಂದು ಹೇಳಿ.');
    }
  }

  Future<void> _startListeningForResponse() async {
    if (isSpeaking) {
      await _speak('ದಯವಿಟ್ಟು ಕೆಲವು ಕ್ಷಣಗಳಲ್ಲಿ ಪ್ರಯತ್ನಿಸಿ. ನಾನು ಇನ್ನೂ ಮಾತನಾಡುತ್ತಿದ್ದೇನೆ.');
      return;
    }

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

    if (_currentFlow == 'initial') {
      await _handleInitialResponse(lower);
    } else if (_currentFlow == 'confirm_identity') {
      await _handleIdentityConfirmation(lower);
    } else if (_currentFlow == 'verify_lmp') {
      await _handleLMPVerification(lower);
    }
  }

  Future<void> _handleInitialResponse(String response) async {
    if (returningUsername != null) {
      // Returning user flow
      if (response.contains('ಹೌದು') || response.contains('yes')) {
        await _continueWithAccount();
      } else if (response.contains('ಇಲ್ಲ') || response.contains('no')) {
        await _handleDifferentUser();
      } else {
        await _speak('ಕ್ಷಮಿಸಿ, ನಾನು ಅರ್ಥಮಾಡಿಕೊಳ್ಳಲಿಲ್ಲ. ದಯವಿಟ್ಟು ಹೌದು ಅಥವಾ ಇಲ್ಲ ಎಂದು ಹೇಳಿ.');
        await _startListeningForResponse();
      }
    } else {
      // New user flow
      if (response.contains('ಹೌದು') || response.contains('yes')) {
        await _handleStoreInformation();
      } else if (response.contains('ಇಲ್ಲ') || response.contains('no')) {
        await _handleAnonymous();
      } else {
        await _speak('ಕ್ಷಮಿಸಿ, ನಾನು ಅರ್ಥಮಾಡಿಕೊಳ್ಳಲಿಲ್ಲ. ದಯವಿಟ್ಟು ಹೌದು ಅಥವಾ ಇಲ್ಲ ಎಂದು ಹೇಳಿ.');
        await _startListeningForResponse();
      }
    }
  }

  Future<void> _handleDifferentUser() async {
    setState(() {
      _currentFlow = 'confirm_identity';
    });

    await _speak('ನೀವು $returningUsername ಹೆಸರಿನ ಬೇರೆ ವ್ಯಕ್ತಿಯೇ? ಹೌದು ಅಥವಾ ಇಲ್ಲ ಎಂದು ಹೇಳಿ.');
    await _startListeningForResponse();
  }

  Future<void> _handleIdentityConfirmation(String response) async {
    if (response.contains('ಹೌದು') || response.contains('yes')) {
      // Same name, different person - verify LMP
      setState(() {
        _currentFlow = 'verify_lmp';
      });

      if (returningUserLMP != null) {
        final formattedDate = _formatDateForSpeech(returningUserLMP!);
        await _speak('ನಿಮ್ಮ ಕೊನೆಯ ಋತುಚಕ್ರದ ಪ್ರಥಮ ದಿನಾಂಕ ಏನು? ನಿಮ್ಮ ದಿನಾಂಕ $formattedDate ಆಗಿದೆಯೇ? ಹೌದು ಅಥವಾ ಇಲ್ಲ ಎಂದು ಹೇಳಿ.');
      } else {
        await _speak('ನಿಮ್ಮ ಕೊನೆಯ ಋತುಚಕ್ರದ ಪ್ರಥಮ ದಿನಾಂಕ ಏನು? ದಯವಿಟ್ಟು ದಿನಾಂಕ ಹೇಳಿ.');
      }
      await _startListeningForResponse();
    } else if (response.contains('ಇಲ್ಲ') || response.contains('no')) {
      // Different person with same name - create new account
      await _speak('ಹೊಸ ಖಾತೆ ರಚಿಸಲು ಮುಂದುವರೆಯುತ್ತಿದ್ದೇನೆ.');
      _navigateToSignup();
    } else {
      await _speak('ಕ್ಷಮಿಸಿ, ನಾನು ಅರ್ಥಮಾಡಿಕೊಳ್ಳಲಿಲ್ಲ. ದಯವಿಟ್ಟು ಹೌದು ಅಥವಾ ಇಲ್ಲ ಎಂದು ಹೇಳಿ.');
      await _startListeningForResponse();
    }
  }

  Future<void> _handleLMPVerification(String response) async {
    if (response.contains('ಹೌದು') || response.contains('yes')) {
      // LMP matches - continue to existing account
      await _speak('ನಿಮ್ಮ ಗುರುತನ್ನು ಧೃಡಪಡಿಸಲಾಗಿದೆ. ಡ್ಯಾಶ್‌ಬೋರ್ಡ್‌ಗೆ ಮುಂದುವರೆಯುತ್ತಿದ್ದೇನೆ.');
      _navigateToDashboard();
    } else if (response.contains('ಇಲ್ಲ') || response.contains('no')) {
      // LMP doesn't match - create new account
      await _speak('ನಿಮಗಾಗಿ ಹೊಸ ಖಾತೆ ರಚಿಸಲು ಮುಂದುವರೆಯುತ್ತಿದ್ದೇನೆ.');
      _navigateToSignup();
    } else {
      // Try to extract date from response
      final extractedDate = _extractDateFromText(response);
      if (extractedDate != null) {
        await _verifyExtractedDate(extractedDate);
      } else {
        await _speak('ಕ್ಷಮಿಸಿ, ನಾನು ದಿನಾಂಕ ಅರ್ಥಮಾಡಿಕೊಳ್ಳಲಿಲ್ಲ. ದಯವಿಟ್ಟು ಹೌದು ಅಥವಾ ಇಲ್ಲ ಎಂದು ಹೇಳಿ.');
        await _startListeningForResponse();
      }
    }
  }

  DateTime? _extractDateFromText(String text) {
    // Simple date extraction logic - you might want to enhance this
    try {
      // Look for common date patterns
      final now = DateTime.now();

      // If user says "today" or equivalent
      if (text.contains('ಇಂದು') || text.contains('today')) {
        return now;
      }

      // If user says "yesterday" or equivalent
      if (text.contains('ನಿನ್ನೆ') || text.contains('yesterday')) {
        return now.subtract(const Duration(days: 1));
      }

      // Add more date parsing logic as needed
      // This is a simplified version - you might want to use a proper date parsing library

      return null;
    } catch (e) {
      debugPrint('Date extraction error: $e');
      return null;
    }
  }

  Future<void> _verifyExtractedDate(DateTime extractedDate) async {
    if (returningUserLMP != null) {
      // Check if dates are close enough (within 2 days)
      final difference = extractedDate.difference(returningUserLMP!).inDays.abs();
      if (difference <= 2) {
        await _speak('ದಿನಾಂಕ ಹೊಂದಿಕೆಯಾಗಿದೆ. ಡ್ಯಾಶ್‌ಬೋರ್ಡ್‌ಗೆ ಮುಂದುವರೆಯುತ್ತಿದ್ದೇನೆ.');
        _navigateToDashboard();
      } else {
        await _speak('ದಿನಾಂಕ ಹೊಂದಿಕೆಯಾಗುವುದಿಲ್ಲ. ಹೊಸ ಖಾತೆ ರಚಿಸಲು ಮುಂದುವರೆಯುತ್ತಿದ್ದೇನೆ.');
        _navigateToSignup();
      }
    } else {
      // No existing LMP to compare with
      await _speak('ಹೊಸ ಖಾತೆ ರಚಿಸಲು ಮುಂದುವರೆಯುತ್ತಿದ್ದೇನೆ.');
      _navigateToSignup();
    }
  }

  String _formatDateForSpeech(DateTime date) {
    final months = [
      'ಜನವರಿ', 'ಫೆಬ್ರವರಿ', 'ಮಾರ್ಚ್', 'ಎಪ್ರಿಲ್', 'ಮೇ', 'ಜೂನ್',
      'ಜುಲೈ', 'ಆಗಸ್ಟ್', 'ಸೆಪ್ಟೆಂಬರ್', 'ಅಕ್ಟೋಬರ್', 'ನವೆಂಬರ್', 'ಡಿಸೆಂಬರ್'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  Future<void> _continueWithAccount() async {
    await _speak('ನಿಮ್ಮ ಖಾತೆಯೊಂದಿಗೆ ಮುಂದುವರೆಯುತ್ತಿದ್ದೇನೆ.');
    _navigateToDashboard();
  }

  Future<void> _handleStoreInformation() async {
    await _speak('ಖಾತೆ ರಚಿಸಲು ಮುಂದುವರೆಯುತ್ತಿದ್ದೇನೆ.');
    _navigateToSignup();
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
    } finally {
      if (mounted) {}
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
    if (!isListening) {
      await _startListeningForResponse();
    } else {
      await speechService.stop();
      setState(() => isListening = false);
    }
  }

  String _getQuestionText() {
    if (_currentFlow == 'confirm_identity') {
      return 'ನೀವು $returningUsername ಹೆಸರಿನ ಬೇರೆ ವ್ಯಕ್ತಿಯೇ?';
    } else if (_currentFlow == 'verify_lmp') {
      if (returningUserLMP != null) {
        final formattedDate = _formatDateForSpeech(returningUserLMP!);
        return 'ನಿಮ್ಮ ಕೊನೆಯ ಋತುಚಕ್ರದ ಪ್ರಥಮ ದಿನಾಂಕ $formattedDate ಆಗಿದೆಯೇ?';
      } else {
        return 'ನಿಮ್ಮ ಕೊನೆಯ ಋತುಚಕ್ರದ ಪ್ರಥಮ ದಿನಾಂಕ ಏನು?';
      }
    } else {
      if (returningUsername != null) {
        return 'ನಮಸ್ಕಾರ $returningUsername! ನಿಮ್ಮ ಖಾತೆಯೊಂದಿಗೆ ಮುಂದುವರೆಯಲು ಬಯಸುವಿರಾ?';
      } else {
        return 'ನಿಮ್ಮ ಮಾಹಿತಿಯನ್ನು ಶೇಖರಿಸಲು ನೀವು ಬಯಸುವಿರಾ?';
      }
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
                  // Minimal Logo/Image
                  CircleAvatar(
                    radius: min(screenHeight * 0.075, 80.0),
                    backgroundColor: const Color(0x1A00796B),
                    backgroundImage: const AssetImage('assets/images/maternal-hero.jpg'),
                  ),
                  const SizedBox(height: 40),

                  // Main Heading Only
                  Text(
                    'ಮಾತೃತ್ವ ಆರೋಗ್ಯ ಸಹಾಯಕ',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.displayMedium?.copyWith(
                      fontSize: screenHeight * 0.03,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Single Question Card
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _getQuestionText(),
                            style: theme.textTheme.titleLarge,
                            textAlign: TextAlign.center,
                          ),

                          const SizedBox(height: 16),

                          if (transcript.isNotEmpty)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                color: const Color(0x0D1976D2),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0x331976D2)),
                              ),
                              child: Text(
                                '"$transcript"',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontStyle: FontStyle.italic,
                                  color: Color(0xFF1976D2),
                                ),
                              ),
                            ),

                          GestureDetector(
                            onTap: _toggleListening,
                            child: Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isListening ? const Color(0xFFD32F2F) : const Color(0xFF1976D2),
                                boxShadow: [
                                  BoxShadow(
                                    color: Color.fromRGBO(0, 0, 0, 0.2),
                                    blurRadius: 16,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: Icon(
                                isListening ? Icons.mic : Icons.mic_none,
                                color: Colors.white,
                                size: 32,
                              ),
                            ),
                          ),

                          const SizedBox(height: 16),

                          Text(
                            isListening
                                ? 'ಕೇಳುತ್ತಿದೆ... ಮಾತನಾಡಿ'
                                : (isSpeaking
                                ? 'ಮಾತನಾಡುತ್ತಿದೆ...'
                                : 'ಹೌದು ಅಥವಾ ಇಲ್ಲ ಎಂದು ಹೇಳಿ'),
                            style: theme.textTheme.bodyLarge,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
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