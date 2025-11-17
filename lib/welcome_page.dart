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
  bool _showReturningUserOptions = false;
  bool hasSpokenIntro = false;
  bool isListening = false;
  bool isSpeaking = false;
  bool _speechReady = false;
  String transcript = '';
  bool _loading = false;

  final FirebaseService _firebaseService = FirebaseService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _prepareServices();
      _checkAndRecognizeUser();
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

  // UPDATED: Simplified anonymous login with Firebase
  Future<void> _handleAnonymous() async {
    setState(() => _loading = true);
    try {
      // SIMPLIFIED: Firebase anonymous authentication
      final user = await _firebaseService.signInAnonymously();
      if (user != null) {
        // SIMPLIFIED: Create profile with guest username and default LMP
        await _firebaseService.createUserProfile(
            username: 'ಅತಿಥಿ',
            lmpDate: DateTime.now(), // Default LMP for anonymous users
            isAnonymous: true
        );

        // Create voice identity for guest user
        await voiceIdentityService.createVoiceIdentity('ಅತಿಥಿ');

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('userMode', 'anonymous');
        await prefs.setBool('isAnonymous', true);
        await prefs.remove('userName');

        await _speak('ನೀವು ಅನಾಮಧೇಯವಾಗಿ ಮುಂದುವರಿಯಲು ನಿರ್ಧರಿಸಿದ್ದೀರಿ. ನಿಮ್ಮನ್ನು ಧ್ವನಿ ಇಂಟರ್ಫೇಸ್ಗೆ ಕರೆದೊಯ್ಯುತ್ತಿದ್ದೇನೆ.');
        if (mounted) _navigateToVoice();
      } else {
        throw Exception('Failed to create anonymous user');
      }
    } catch (e) {
      debugPrint('Anonymous sign-in error: $e');
      await _speak('ಕ್ಷಮಿಸಿ, ಅನಾಮಧೇಯ ಪ್ರವೇಶದಲ್ಲಿ ಸಮಸ್ಯೆ ಉಂಟಾಗಿದೆ. ದಯವಿಟ್ಟು ಮತ್ತೆ ಪ್ರಯತ್ನಿಸಿ.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // UPDATED: Check for existing user with Firebase
  Future<void> _checkAndRecognizeUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userMode = prefs.getString('userMode');

    if (!mounted) return;

    // Check if user has existing mode (anonymous or account)
    if (userMode != null && (userMode == 'anonymous' || userMode == 'account')) {
      setState(() => _showReturningUserOptions = true);
      await _speak('ನಮಸ್ಕಾರ! ಮತ್ತೆ ಬಂದಿದ್ದಕ್ಕೆ ಸ್ವಾಗತ. ನೀವು ಅನಾಮಧೇಯವಾಗಿ ಮುಂದುವರಿಯಲು ಬಯಸುವಿರಾ ಅಥವಾ ಖಾತೆಯೊಂದಿಗೆ ಮುಂದುವರೆಯಲು ಬಯಸುವಿರಾ?');
      return;
    } else {
      await _speak('ಮಾತೃತ್ವ ಆರೋಗ್ಯ ಸಹಾಯಕಕ್ಕೆ ಸ್ವಾಗತ. ನೀವು ಅನಾಮಧೇಯವಾಗಿ ಮುಂದುವರಿಯಲು ಬಯಸುವಿರಾ ಅಥವಾ ಖಾತೆಯನ್ನು ರಚಿಸಲು ಬಯಸುವಿರಾ?');
    }
  }

  Future<void> _startListeningForResponse(Function(String) onResponse) async {
    if (isSpeaking) {
      await _speak('ದಯವಿಟ್ಟು ಕೆಲವು ಕ್ಷಣಗಳಲ್ಲಿ ಪ್ರಯತ್ನಿಸಿ. ನಾನು ಇನ್ನೂ ಮಾತನಾಡುತ್ತಿದ್ದೇನೆ.');
      return;
    }
    final ok = await speechService.initialize();
    if (!ok) {
      await _speak('ಕ್ಷಮಿಸಿ, ಮೈಕ್ರೊಫೋನ್ ಲಭ್ಯವಿಲ್ಲ.');
      return;
    }
    if (mounted) setState(() { isListening = true; transcript = ''; });
    try {
      await speechService.startListeningWithRetry((text, isFinal) {
        if (!mounted) return;
        setState(() => transcript = text);
        if (isFinal && text.isNotEmpty) {
          if (mounted) setState(() => isListening = false);
          onResponse(text);
        } else if (isFinal) {
          if (mounted) setState(() => isListening = false);
        }
      }, localeId: 'kn-IN', retries: 2, attemptTimeout: const Duration(seconds: 10));
    } catch (e) {
      if (mounted) setState(() => isListening = false);
    }
  }

  Future<void> _prepareServices() async {
    await ttsService.setSpeechRate(0.4);
    await ttsService.setPitch(1.0);
    final ok = await speechService.initialize();
    if (!mounted) return;
    setState(() => _speechReady = ok);
  }

  Future<void> _speak(String text) async {
    if (text.isEmpty) return;
    try {
      if (mounted) setState(() => isSpeaking = true);
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
      await _startListeningForResponse((text) async {
        final lower = text.toLowerCase();
        if (_showReturningUserOptions) {
          if (lower.contains('ಅನಾಮಧೇಯ') || lower.contains('anonymous')) {
            await _handleAnonymous();
          } else if (lower.contains('ಖಾತೆ') || lower.contains('account')) {
            await _speak('ನಿಮ್ಮ ಅಸ್ತಿತ್ವದಲ್ಲಿರುವ ಖಾತೆಯೊಂದಿಗೆ ಮುಂದುವರೆಯುತ್ತಿದ್ದೇನೆ.');
            _continueAsExistingUser();
          } else {
            await _speak('ಕ್ಷಮಿಸಿ, ನಾನು ಅರ್ಥಮಾಡಿಕೊಳ್ಳಲಿಲ್ಲ. ದಯವಿಟ್ಟು "ಅನಾಮಧೇಯ" ಅಥವಾ "ಖಾತೆ" ಎಂದು ಹೇಳಿ.');
          }
        } else {
          if (lower.contains('ಅನಾಮಧೇಯ') || lower.contains('anonymous')) {
            await _handleAnonymous();
          } else if (lower.contains('ಖಾತೆ') || lower.contains('account') || lower.contains('create')) {
            await _handleCreateAccount();
          } else {
            await _speak('ಕ್ಷಮಿಸಿ, ನಾನು ಅರ್ಥಮಾಡಿಕೊಳ್ಳಲಿಲ್ಲ. ದಯವಿಟ್ಟು "ಅನಾಮಧೇಯ" ಅಥವಾ "ಖಾತೆ ರಚಿಸಿ" ಎಂದು ಹೇಳಿ.');
          }
        }
      });
    } else {
      await speechService.stop();
      if (mounted) setState(() => isListening = false);
    }
  }

  Future<void> _handleCreateAccount() async {
    await _speak('ಅದ್ಭುತ! ನಿಮಗೆ ಖಾತೆ ರಚಿಸಲು ಸಹಾಯ ಮಾಡುತ್ತೇನೆ.');
    if (mounted) _navigateToSignup();
  }

  // UPDATED: Continue as existing user with Firebase
  void _continueAsExistingUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userMode = prefs.getString('userMode');

    if (!mounted) return;

    if (userMode == 'anonymous') {
      _navigateToVoice();
    } else if (userMode == 'account') {
      _navigateToDashboard();
    } else {
      // Fallback: check Firebase for user data
      final profile = await _firebaseService.getUserProfile();
      if (profile != null && mounted) {
        if (profile['is_anonymous'] == true) {
          _navigateToVoice();
        } else {
          _navigateToDashboard();
        }
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
              child: SingleChildScrollView(
                padding: EdgeInsets.only(bottom: 24 + MediaQuery.of(context).viewInsets.bottom),
                child: Builder(builder: (context) {
                  final screenH = MediaQuery.of(context).size.height;
                  final avatarRadius = min(screenH * 0.075, 80.0);
                  final micDiameter = min(screenH * 0.2, 220.0);
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(
                        radius: avatarRadius,
                        backgroundColor: const Color(0x1A00796B),
                        backgroundImage: const AssetImage('assets/images/maternal-hero.jpg'),
                      ),
                      const SizedBox(height: 32),
                      Text('ಮಾತೃತ್ವ ಆರೋಗ್ಯ ಸಹಾಯಕ', textAlign: TextAlign.center, style: theme.textTheme.displayMedium?.copyWith(fontSize: screenHeight * 0.03)),
                      const SizedBox(height: 12),
                      Text('ನಿಮ್ಮ ಗರ್ಭಾವಸ್ಥೆಯ ಪ್ರಯಾಣದ ಧ್ವನಿ-ಮಾರ್ಗದರ್ಶಿತ', textAlign: TextAlign.center, style: theme.textTheme.bodyMedium?.copyWith(fontSize: screenHeight * 0.018)),
                      const SizedBox(height: 8),
                      Text(_speechReady ? 'ಮೈಕ್ರೊಫೋನ್ ಸಿದ್ಧವಾಗಿದೆ' : 'ಮೈಕ್ರೊಫೋನ್ ಸಿದ್ಧವಿಲ್ಲ', style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[600])),
                      const SizedBox(height: 20),
                      Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('ಧ್ವನಿ ಸಹಾಯಕ', style: theme.textTheme.titleLarge),
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
                                  child: Text('"$transcript"', textAlign: TextAlign.center, style: TextStyle(fontStyle: FontStyle.italic, color: const Color(0xFF1976D2), fontSize: screenHeight * 0.018)),
                                ),
                              GestureDetector(
                                onTap: _toggleListening,
                                child: Container(
                                  width: micDiameter,
                                  height: micDiameter,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isListening ? const Color(0xFFD32F2F) : const Color(0xFF1976D2),
                                    boxShadow: [BoxShadow(color: const Color(0x33000000), blurRadius: 16, offset: const Offset(0, 6))],
                                  ),
                                  child: Icon(isListening ? Icons.mic : Icons.mic_none, color: Colors.white, size: screenHeight * 0.08),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(isListening ? 'ಕೇಳುತ್ತಿದೆ... ಮಾತನಾಡಿ' : (isSpeaking ? 'ಮಾತನಾಡುತ್ತಿದೆ...' : 'ಮಾತನಾಡಲು ಟ್ಯಾಪ್ ಮಾಡಿ'), style: theme.textTheme.bodyLarge?.copyWith(fontSize: screenHeight * 0.022)),
                              const SizedBox(height: 8),
                              Text(_showReturningUserOptions ? '"ಅನಾಮಧೇಯ" ಅಥವಾ "ಖಾತೆ" ಎಂದು ಹೇಳಿ' : '"ಅನಾಮಧೇಯ" ಅಥವಾ "ಖಾತೆ ರಚಿಸಿ" ಎಂದು ಹೇಳಿ', textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      Column(
                        children: [
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: isSpeaking || _loading ? null : _handleAnonymous,
                              icon: const Icon(Icons.person_outline),
                              label: _loading
                                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                  : const Padding(padding: EdgeInsets.symmetric(vertical: 12.0), child: Text('ಅನಾಮಧೇಯವಾಗಿ ಉಳಿಯಿರಿ')),
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: isSpeaking ? null : _handleCreateAccount,
                              icon: const Icon(Icons.person_add_alt_1),
                              label: const Padding(padding: EdgeInsets.symmetric(vertical: 12.0), child: Text('ಖಾತೆ ರಚಿಸಿ')),
                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00796B), foregroundColor: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}