import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/tts_service.dart';
import 'services/speech_service.dart';
import 'services/voice_identity_service.dart';

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  bool hasSpokenIntro = false;
  bool isListening = false;
  bool isSpeaking = false;
  bool _speechReady = false;
  String transcript = '';
  String? _returningUserName;
  bool _showReturningOptions = false;
  bool _isProcessingResponse = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _prepareServices();
      _checkExistingUser();
    });
  }

  Future<void> _checkExistingUser() async {
    final hasUser = await voiceIdentityService.hasExistingUser();
    if (hasUser && mounted) {
      final profile = await voiceIdentityService.getUserProfile();
      if (profile != null) {
        setState(() {
          _returningUserName = profile['name'];
        });
        // Auto-start voice greeting after services are ready
        Future.delayed(const Duration(seconds: 2), () {
          _greetReturningUser();
        });
      }
    } else {
      // New user - wait a bit then start normal welcome
      Future.delayed(const Duration(seconds: 3), () {
        _startNewUserWelcome();
      });
    }
  }

  Future<void> _greetReturningUser() async {
    await _speak('ನಮಸ್ಕಾರ $_returningUserName! ನಿಮ್ಮನ್ನು ಮತ್ತೆ ನೋಡಿ ಸಂತೋಷ. ನೀವು ಮುಂದುವರೆಯಲು ಬಯಸುವಿರಾ ಅಥವಾ ಹೊಸ ಖಾತೆ ರಚಿಸಲು ಬಯಸುವಿರಾ?');
    if (mounted) {
      setState(() {
        _showReturningOptions = true;
      });
    }
    // Auto-start listening for response
    _startListeningForChoice();
  }

  Future<void> _startNewUserWelcome() async {
    if (!hasSpokenIntro && mounted) {
      await _speak(
        'ಮಾತೃತ್ವ ಆರೋಗ್ಯ ಸಹಾಯಕಕ್ಕೆ ಸ್ವಾಗತ. ನೀವು ಅನಾಮಧೇಯವಾಗಿ ಮುಂದುವರಿಯಲು ಬಯಸುವಿರಾ ಅಥವಾ ಖಾತೆಯನ್ನು ರಚಿಸಲು ಬಯಸುವಿರಾ?',
      );
      if (mounted) {
        setState(() {
          hasSpokenIntro = true;
        });
      }
      // Auto-start listening for new user choice
      _startListeningForChoice();
    }
  }

  Future<void> _prepareServices() async {
    await ttsService.setSpeechRate(0.4);
    await ttsService.setPitch(1.0);
    final ok = await speechService.initialize();
    if (mounted) {
      setState(() {
        _speechReady = ok;
      });
    }
  }

  Future<void> _speak(String text) async {
    if (text.isEmpty) return;
    try {
      if (mounted) {
        setState(() {
          isSpeaking = true;
        });
      }
      await ttsService.speak(text);
    } catch (e) {
      debugPrint('TTS speak error: $e');
    } finally {
      if (mounted) {
        setState(() {
          isSpeaking = false;
        });
      }
    }
  }

  Future<void> _startListeningForChoice() async {
    if (isSpeaking) {
      // Wait for speaking to finish
      Future.delayed(const Duration(seconds: 1), () {
        _startListeningForChoice();
      });
      return;
    }

    if (mounted) {
      setState(() {
        isListening = true;
        transcript = '';
        _isProcessingResponse = false;
      });
    }

    await speechService.startListening((text, isFinal) {
      if (!mounted) return;
      setState(() {
        transcript = text;
      });
      if (isFinal && text.isNotEmpty) {
        _processUserChoice(text);
      } else if (isFinal) {
        // No speech detected, try again
        setState(() {
          isListening = false;
        });
        _startListeningForChoice();
      }
    }, localeId: 'kn-IN');
  }

  Future<void> _processUserChoice(String text) async {
    if (mounted) {
      setState(() {
        isListening = false;
        _isProcessingResponse = true;
      });
    }

    final lower = text.toLowerCase();
    if (_showReturningOptions) {
      // Returning user flow
      await _handleReturningUserChoice(lower);
    } else {
      // New user flow
      await _handleNewUserChoice(lower);
    }

    if (mounted) {
      setState(() {
        _isProcessingResponse = false;
      });
    }
  }

  Future<void> _handleReturningUserChoice(String choice) async {
    if (choice.contains('ಮುಂದುವರೆಯಿರಿ') ||
        choice.contains('ಹೌದು') ||
        choice.contains('continue') ||
        choice.contains('yes')) {
      await _speak('ಧನ್ಯವಾದಗಳು $_returningUserName! ನಿಮ್ಮನ್ನು ಡ್ಯಾಶ್‌ಬೋರ್ಡ್‌ಗೆ ಕರೆದೊಯ್ಯುತ್ತಿದ್ದೇನೆ.');
      _continueAsExistingUser();
    } else if (choice.contains('ಹೊಸ ಖಾತೆ') ||
        choice.contains('ನೂತನ ಖಾತೆ') ||
        choice.contains('new account')) {
      await _speak('ಸರಿ, ಹೊಸ ಖಾತೆ ರಚಿಸಲು ನಿಮ್ಮನ್ನು ಸಹಾಯ ಮಾಡುತ್ತೇನೆ.');
      _navigateToSignup();
    } else if (choice.contains('ಅನಾಮಧೇಯ') || choice.contains('anonymous')) {
      await _speak('ನೀವು ಅನಾಮಧೇಯವಾಗಿ ಮುಂದುವರಿಯಲು ನಿರ್ಧರಿಸಿದ್ದೀರಿ.');
      _navigateToAnonymous();
    } else {
      await _speak(
          'ಕ್ಷಮಿಸಿ, ನಾನು ಅರ್ಥಮಾಡಿಕೊಳ್ಳಲಿಲ್ಲ. ದಯವಿಟ್ಟು "ಮುಂದುವರೆಯಿರಿ", "ಹೊಸ ಖಾತೆ" ಅಥವಾ "ಅನಾಮಧೇಯ" ಎಂದು ಹೇಳಿ.');
      _startListeningForChoice();
    }
  }

  Future<void> _handleNewUserChoice(String choice) async {
    if (choice.contains('ಅನಾಮಧೇಯ') || choice.contains('anonymous')) {
      await _handleAnonymous();
    } else if (choice.contains('ಖಾತೆ') ||
        choice.contains('ರಚಿಸಿ') ||
        choice.contains('account') ||
        choice.contains('create')) {
      await _handleCreateAccount();
    } else {
      await _speak(
          'ಕ್ಷಮಿಸಿ, ನಾನು ಅರ್ಥಮಾಡಿಕೊಳ್ಳಲಿಲ್ಲ. ದಯವಿಟ್ಟು "ಅನಾಮಧೇಯ" ಅಥವಾ "ಖಾತೆ ರಚಿಸಿ" ಎಂದು ಹೇಳಿ.');
      _startListeningForChoice();
    }
  }

  void _continueAsExistingUser() async {
    final profile = await voiceIdentityService.getUserProfile();
    if (profile != null) {
      if (profile['mode'] == 'anonymous') {
        Navigator.pushReplacementNamed(context, '/voice');
      } else {
        Navigator.pushReplacementNamed(context, '/dashboard');
      }
    }
  }

  void _navigateToSignup() {
    Navigator.pushReplacementNamed(context, '/signup');
  }

  void _navigateToAnonymous() async {
    await voiceIdentityService.createVoiceIdentity('ಅತಿಥಿ');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userMode', 'anonymous');
    await prefs.setString('lastLogin', DateTime.now().toIso8601String());
    Navigator.pushReplacementNamed(context, '/voice');
  }

  Future<void> _handleAnonymous() async {
    await voiceIdentityService.createVoiceIdentity('ಅತಿಥಿ');
    await _speak(
        'ನೀವು ಅನಾಮಧೇಯವಾಗಿ ಮುಂದುವರಿಯಲು ನಿರ್ಧರಿಸಿದ್ದೀರಿ. ನಿಮ್ಮನ್ನು ಧ್ವನಿ ಇಂಟರ್ಫೇಸ್ಗೆ ಕರೆದೊಯ್ಯುತ್ತಿದ್ದೇನೆ.');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userMode', 'anonymous');
    await prefs.setString('lastLogin', DateTime.now().toIso8601String());
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/voice');
    }
  }

  Future<void> _handleCreateAccount() async {
    await _speak('ಅದ್ಭುತ! ನಿಮಗೆ ಖಾತೆ ರಚಿಸಲು ಸಹಾಯ ಮಾಡುತ್ತೇನೆ.');
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/signup');
    }
  }

  @override
  void dispose() {
    speechService.cancel();
    ttsService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Container(
          width: double.infinity,
          height: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFF7FAFC), Color(0xFFFFFFFF)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    height: 110,
                    width: 110,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [Color(0xFF56CCF2), Color(0xFF2F80ED)]),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withAlpha(30), blurRadius: 10)
                      ],
                    ),
                    child: const Center(
                        child: Icon(Icons.favorite, size: 48, color: Colors.white)),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'ಮಾತೃತ್ವ ಆರೋಗ್ಯ ಸಹಾಯಕ',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  if (_showReturningOptions && _returningUserName != null)
                    Column(
                      children: [
                        Text(
                          'ನಮಸ್ಕಾರ $_returningUserName!',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: Colors.green[700],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'ನಿಮ್ಮನ್ನು ಮತ್ತೆ ನೋಡಿ ಸಂತೋಷ',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleMedium
                              ?.copyWith(color: Colors.grey[700]),
                        ),
                      ],
                    )
                  else
                    Text(
                      'ನಿಮ್ಮ ಧ್ವನಿ-ಮಾರ್ಗದರ್ಶಿತ ಗರ್ಭಾವಸ್ಥೆಯ ಪ್ರಯಾಣ',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(color: Colors.grey[700]),
                    ),
                  const SizedBox(height: 20),
                  if (_isProcessingResponse)
                    Column(
                      children: const [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('ಪ್ರಕ್ರಿಯೆಗೊಳಿಸುತ್ತಿದೆ...'),
                      ],
                    )
                  else if (isListening)
                    Column(
                      children: [
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.red,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.red.withAlpha(100),
                                blurRadius: 20,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child:
                              const Icon(Icons.mic, color: Colors.white, size: 50),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'ಕೇಳುತ್ತಿದ್ದೇನೆ...',
                          style: TextStyle(
                              fontSize: 16,
                              color: Colors.red,
                              fontWeight: FontWeight.w600),
                        ),
                        if (transcript.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              '"$transcript"',
                              style: TextStyle(
                                  fontStyle: FontStyle.italic,
                                  color: Colors.grey[700]),
                              textAlign: TextAlign.center,
                            ),
                          ),
                      ],
                    )
                  else if (isSpeaking)
                    Column(
                      children: [
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.orange,
                          ),
                          child: const Icon(Icons.volume_up,
                              color: Colors.white, size: 40),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'ಮಾತನಾಡುತ್ತಿದ್ದೇನೆ...',
                          style: TextStyle(
                              fontSize: 16,
                              color: Colors.orange,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    )
                  else
                    Column(
                      children: [
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.grey[300],
                          ),
                          child: Icon(Icons.mic_none,
                              color: Colors.grey[600], size: 40),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _showReturningOptions
                              ? 'ನಿಮ್ಮ ಆಯ್ಕೆಗಾಗಿ ಕಾಯ್ತಿದ್ದೇನೆ...'
                              : 'ಸಿದ್ಧವಾಗಿದೆ',
                          style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  const SizedBox(height: 30),
                  if (!_showReturningOptions)
                    Text(
                      '"ಅನಾಮಧೇಯ" ಅಥವಾ "ಖಾತೆ ರಚಿಸಿ" ಎಂದು ಹೇಳಿ',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge
                          ?.copyWith(color: Colors.grey[600], fontSize: 14),
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
