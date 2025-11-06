import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'services/tts_service.dart';
import 'services/speech_service.dart';
import 'services/voice_identity_service.dart';
import 'services/ai_service.dart';

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  bool _showReturningUserOptions = false;
  String? _returningUserName;
  bool _isIdentifyingUser = false;

  bool hasSpokenIntro = false;
  bool isListening = false;
  bool isSpeaking = false;
  bool _speechReady = false;
  String transcript = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _prepareServices();
      _checkAndRecognizeUser();
    });
  }

  // FIXED: Check mounted before setState in async operations
  Future<void> _checkAndRecognizeUser() async {
    final hasUser = await voiceIdentityService.hasExistingUser();
    if (!mounted) return;

    if (hasUser) {
      final profile = await voiceIdentityService.getUserProfile();
      if (!mounted) return;

      if (profile != null) {
        final name = profile['name'] ?? '';
        // Instead of immediate redirect, ask for voice confirmation
        if (!mounted) return;
        setState(() {
          _showReturningUserOptions = true;
          _returningUserName = name;
        });

        // Ask and listen automatically for confirmation
        await _askReturningUserConfirmation(name);
        return;
      }
    }
  }

  /// Speak a prompt and automatically start listening for the user's reply.
  /// The [onFinal] callback will be invoked when the recognizer returns a final result.
  Future<void> _speakThenListen(
    String prompt,
    void Function(String text) onFinal, {
    int retries = 2,
    Duration attemptTimeout = const Duration(seconds: 10),
  }) async {
    await _speak(prompt);
    // start listening with retries; onFinal is called when result is final
    await speechService.startListeningWithRetry((text, isFinal) {
      if (isFinal) {
        try {
          onFinal(text);
        } catch (e) {
          debugPrint('speakThenListen onFinal error: $e');
        }
      } else {
        // update interim transcript
        if (mounted) setState(() => transcript = text);
      }
    },
        localeId: 'kn-IN',
        retries: retries,
        attemptTimeout: attemptTimeout,
        onFailure: () async {
          // If listening fails, prompt the user to tap mic or try again
          await _speak('ಕ್ಷಮಿಸಿ, ನಾನು ನಿಮ್ಮನ್ನು ಕೇಳಲಾರದಿದ್ದು. ದಯವಿಟ್ಟು ಮತ್ತೆ ಮಾತನಾಡಿ ಅಥವಾ ಮೈಕ್ರೊಫೋನನ್ನು ಪರಿಶೀಲಿಸಿ.');
        });
  }

  /// Ask the returning user to confirm their identity by voice and act accordingly.
  Future<void> _askReturningUserConfirmation(String name) async {
    final prompt = 'ನೀವು $name ಅಲ್ಲವೇ? ದಯವಿಟ್ಟು ಹೌದು ಅಥವಾ ಇಲ್ಲ ಎಂದು ಹೇಳಿ.';
    await _speakThenListen(prompt, (text) async {
      final lower = text.toLowerCase();
      debugPrint('Returning user confirmation heard: $text');
      if (lower.contains('ಹೌದು') || lower.contains('yes') || lower.contains('continue') || lower.contains('ಮುಂದುವರ')) {
        // confirmed
        await _speak('ಧನ್ಯವಾದಗಳು $name! ನಿಮನ್ನು ಮುಂದಕ್ಕೆ ಕರೆದೊಯ್ಯುತ್ತಿದ್ದೇನೆ.');
        _continueAsExistingUser();
      } else if (lower.contains('ಇಲ್ಲ') || lower.contains('no') || lower.contains('change')) {
        // not the same person — offer options
        await _speak('ಸರಿ. ನೀವು ಹೊಸ ಬಳಕೆದಾರರಾಗಿದ್ದರೆ, ಖಾತೆ ರಚಿಸಿ ಅಥವಾ ಅನಾಮಧೇಯವಾಗಿ ಮುಂದುವರಿಯಿರಿ.');
        // open signup or anonymous choices automatically by listening again
        await _speakThenListen('ನೀವು ಖಾತೆ ರಚಿಸಬೇಕು ಅಥವಾ ಅನಾಮಧೇಯವಾಗಿರಬೇಕು?', (reply) async {
          final r = reply.toLowerCase();
          if (r.contains('ಖಾತೆ') || r.contains('create') || r.contains('signup')) {
            Navigator.pushNamed(context, '/signup');
          } else {
            await _handleAnonymous();
          }
        });
      } else {
        // unrecognized — ask again once
        await _speak('ಕ್ಷಮಿಸಿ, ನಾನು ಅರ್ಥಮಾಡಿಕೊಳ್ಳಲಿಲ್ಲ. ದಯವಿಟ್ಟು ಹೌದು ಅಥವಾ ಇಲ್ಲ ಎಂದು ಬಾರಿಸಿ.');
        await _askReturningUserConfirmation(name); // recursive one more attempt
      }
    });
  }

  // FIXED: Safe async operations with mounted checks
  Future<void> _prepareServices() async {
    await ttsService.setSpeechRate(0.4);
    await ttsService.setPitch(1.0);

    final ok = await speechService.initialize();
    if (!mounted) return;

    setState(() {
      _speechReady = ok;
    });

    if (!hasSpokenIntro) {
      Future.delayed(const Duration(milliseconds: 900), () {
        if (!mounted) return;
        _speak(
          'ಮಾತೃತ್ವ ಆರೋಗ್ಯ ಸಹಾಯಕಕ್ಕೆ ಸ್ವಾಗತ. ನೀವು ಅನಾಮಧೇಯವಾಗಿ ಮುಂದುವರಿಯಲು ಬಯಸುವಿರಾ ಅಥವಾ ಖಾತೆಯನ್ನು ರಚಿಸಲು ಬಯಸುವಿರಾ?',
        );
        if (mounted) {
          setState(() {
            hasSpokenIntro = true;
          });
        }
      });
    }
  }

  // FIXED: Safe speak method with mounted checks
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

  // FIXED: Safe listening with mounted checks
  Future<void> _toggleListening() async {
    if (isSpeaking) return;

    if (!isListening) {
      await ttsService.stop();

      final ok = await speechService.initialize();
      if (!ok) {
        if (!mounted) return;
        await _speak('ಕ್ಷಮಿಸಿ,ನಿಮ್ಮ ಮಾತು ಕೇಳಿಸುತಿಲ್ಲ. ದಯವಿಟ್ಟು ಮೈಕ್ರೊಫೋನ್ ಅನುಮತಿಗಳನ್ನು ಪರಿಶೀಲಿಸಿ.');
        if (mounted) {
          setState(() {
            _speechReady = false;
          });
        }
        return;
      }

      if (mounted) {
        setState(() {
          isListening = true;
          transcript = '';
          _speechReady = true;
        });
      }

      await speechService.startListeningWithMixedLanguage((text, isFinal) {
        if (!mounted) return;
        debugPrint("🎯 Mixed-language raw result: '$text' final=$isFinal");
        setState(() {
          transcript = text;
        });
        if (isFinal) {
          if (mounted) {
            setState(() {
              isListening = false;
            });
          }
          _onVoiceInput(text);
        }
      });
    } else {
      await speechService.stop();
      if (mounted) {
        setState(() {
          isListening = false;
        });
      }
    }
  }

  // FIXED: Safe voice input handling
  void _onVoiceInput(String text) async {
    final lower = text.toLowerCase();
    debugPrint("🎯 Processing mixed language input: '$text'");

    if (mounted) {
      setState(() {
        transcript = text;
      });
    }

    final anonKeywords = ['ಅನಾಮಧೇಯ', 'anonymous', 'anon', 'guest', 'ಅನಾಮ'];
    final signupKeywords = ['ಖಾತೆ', 'account', 'create', 'sign up', 'ರಚಿಸಿ', 'signup', 'ನೊಂದಾಯಿಸಿ'];

    bool isAnon = anonKeywords.any((k) => lower.contains(k));
    bool isSignup = signupKeywords.any((k) => lower.contains(k));

    if (isAnon) {
      debugPrint("✅ User chose: Anonymous (mixed language detected)");
      await _speak('ನೀವು ಅನಾಮಧೇಯವಾಗಿ ಮುಂದುವರಿಯಲು ನಿರ್ಧರಿಸಿದ್ದೀರಿ. ನಿಮ್ಮನ್ನು ಧ್ವನಿ ಇಂಟರ್ಫೇಸ್ಗೆ ಕರೆದೊಯ್ಯುತ್ತಿದ್ದೇನೆ.');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('userMode', 'anonymous');
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/voice');
      }
      return;
    }

    if (isSignup) {
      debugPrint("✅ User chose: Sign Up (mixed language detected)");
      await _speak('ಅದ್ಭುತ! ನಾನು ನಿಮಗೆ ಖಾತೆಯನ್ನು ರಚಿಸಲು ಸಹಾಯ ಮಾಡುತ್ತೇನೆ.');
      if (mounted) {
        Navigator.pushNamed(context, '/signup');
      }
      return;
    }

    debugPrint("❌ No matching command found in mixed input — routing to AIService");
    final resp = await aiService.getResponse(text, 'general');
    debugPrint('AI response: $resp');
    await _speak(resp);
  }

  // FIXED: Safe anonymous handler
  Future<void> _handleAnonymous() async {
    await voiceIdentityService.createVoiceIdentity('ಅತಿಥಿ');
    await _speak('ನೀವು ಅನಾಮಧೇಯವಾಗಿ ಮುಂದುವರಿಯಲು ನಿರ್ಧರಿಸಿದ್ದೀರಿ. ನಿಮ್ಮನ್ನು ಧ್ವನಿ ಇಂಟರ್ಫೇಸ್ಗೆ ಕರೆದೊಯ್ಯುತ್ತಿದ್ದೇನೆ.');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userMode', 'anonymous');
    await prefs.setString('lastLogin', DateTime.now().toIso8601String());
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/voice');
    }
  }

  // FIXED: Safe create account handler
  Future<void> _handleCreateAccount() async {
    await _speak('ಅದ್ಭುತ! ನಿಮಗೆ ಖಾತೆ ರಚಿಸಲು ಸಹಾಯ ಮಾಡುತ್ತೇನೆ.');
    if (mounted) {
      Navigator.pushNamed(context, '/signup');
    }
  }

  // FIXED: Safe voice verification
  Future<void> _verifyWithVoice() async {
    if (_isIdentifyingUser) return;
    if (mounted) {
      setState(() => _isIdentifyingUser = true);
    }
    await _speak('ದಯವಿಟ್ಟು ನಿಮ್ಮ ಹೆಸರು ಹೇಳಿ.');
    await speechService.startListening((text, isFinal) {
      if (isFinal && text.isNotEmpty) {
        _processVoiceVerification(text);
      }
    }, localeId: 'kn-IN');
  }

  // FIXED: Safe voice verification processing
  Future<void> _processVoiceVerification(String spokenText) async {
    if (spokenText.trim().isEmpty) {
      await _speak('ದಯವಿಟ್ಟು ನಿಮ್ಮ ಹೆಸರು ಸ್ಪಷ್ಟವಾಗಿ ಹೇಳಿ.');
      if (mounted) {
        setState(() => _isIdentifyingUser = false);
      }
      return;
    }

    final identifiedName = await voiceIdentityService.identifyUserFromVoice(spokenText);

    if (identifiedName != null) {
      await _speak('ಧನ್ಯವಾದಗಳು! ನಿಮ್ಮನ್ನು $identifiedName ಎಂದು ಗುರುತಿಸಲಾಗಿದೆ. ಮುಂದುವರೆಯುತ್ತೇನೆ.');
      _continueAsExistingUser();
    } else {
      await _speak('ಕ್ಷಮಿಸಿ, "$spokenText" ಹೆಸರಿನ ಬಳಕೆದಾರರನ್ನು ಕಂಡುಹಿಡಿಯಲು ಸಾಧ್ಯವಾಗಲಿಲ್ಲ. ದಯವಿಟ್ಟು ಮತ್ತೆ ಪ್ರಯತ್ನಿಸಿ ಅಥವಾ ಹೊಸ ಖಾತೆ ರಚಿಸಿ.');
    }

    if (mounted) {
      setState(() => _isIdentifyingUser = false);
    }
  }

  void _continueAsExistingUser() async {
    final profile = await voiceIdentityService.getUserProfile();
    if (!mounted) return;

    if (profile != null) {
      if (profile['mode'] == 'anonymous') {
        Navigator.pushReplacementNamed(context, '/voice');
      } else {
        Navigator.pushReplacementNamed(context, '/dashboard');
      }
    }
  }

  void _startAsNewUser() {
    if (mounted) {
      setState(() {
        _showReturningUserOptions = false;
        _returningUserName = null;
      });
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
                padding: const EdgeInsets.only(bottom: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Logo/Icon Section
                    Container(
                      height: screenHeight * 0.15,
                      width: screenHeight * 0.15,
                      decoration: BoxDecoration(
                        color: const Color(0x1A00796B), // 10% teal
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Icon(
                          Icons.favorite,
                          size: screenHeight * 0.075,
                          color: const Color(0xFFFD0681),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Title Section
                    Text(
                      'ಮಾತೃತ್ವ ಆರೋಗ್ಯ ಸಹಾಯಕ',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.displayMedium?.copyWith(fontSize: screenHeight * 0.03),
                    ),
                    const SizedBox(height: 12),

                    Text(
                      'ನಿಮ್ಮ ಗರ್ಭಾವಸ್ಥೆಯ ಪ್ರಯಾಣದ ಧ್ವನಿ-ಮಾರ್ಗದರ್ಶಿತ ',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(fontSize: screenHeight * 0.018),
                    ),
                    const SizedBox(height: 8),
                    // Microphone readiness status (reads _speechReady so field is used)
                    Text(
                      _speechReady ? 'ಮೈಕ್ರೊಫೋನ್ ಸಿದ್ಧವಾಗಿದೆ' : 'ಮೈಕ್ರೊಫೋನ್ ಸಿದ್ಧವಿಲ್ಲ',
                      style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 20),

                    // If we detected a returning user, show the confirmation card
                    if (_showReturningUserOptions && _returningUserName != null)
                      Card(
                        elevation: 4,
                        color: const Color(0xFFE8F5F2), // very light teal
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              Text(
                                '👋  ನಮಸ್ಕಾರ ${_returningUserName!}!',
                                style: theme.textTheme.titleLarge?.copyWith(color: const Color(0xFF00796B)),
                              ),
                              const SizedBox(height: 8),
                              Text('ನಿಮ್ಮನ್ನು ಮತ್ತೆ ನೋಡಿಕೊಂಡು ಸಂತೋಷ. ಮುಂದುವರೆಯಲು ಬಯಸುವಿರಾ?', textAlign: TextAlign.center, style: theme.textTheme.bodyLarge),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: _continueAsExistingUser,
                                      child: const Text('ಹೌದು, ಮುಂದುವರೆಸಿ'),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: _startAsNewUser,
                                      child: const Text('ಹೊಸ ಬಳಕೆದಾರ'),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              OutlinedButton(
                                onPressed: _verifyWithVoice,
                                child: _isIdentifyingUser
                                    ? const Row(mainAxisSize: MainAxisSize.min, children: [SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)), SizedBox(width: 8), Text('ಗುರುತಿಸುತ್ತಿದೆ...')])
                                    : const Text('ಧ್ವನಿಯಿಂದ ದೃಢೀಕರಿಸಿ'),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                    // Voice Interface Card (Welcome large mic)
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            Text(
                              'ಧ್ವನಿ ಸಹಾಯಕ',
                              style: theme.textTheme.titleLarge,
                            ),
                            const SizedBox(height: 16),

                            if (transcript.isNotEmpty)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(16),
                                margin: const EdgeInsets.only(bottom: 16),
                                decoration: BoxDecoration(
                                  color: const Color(0x0D1976D2), // ~5% blue
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0x331976D2)),
                                ),
                                child: Text(
                                  '"$transcript"',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontStyle: FontStyle.italic,
                                    color: const Color(0xFF1976D2),
                                    fontSize: screenHeight * 0.018,
                                  ),
                                ),
                              ),

                            GestureDetector(
                              onTap: _toggleListening,
                              child: Container(
                                width: screenHeight * 0.2,
                                height: screenHeight * 0.2,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isListening ? const Color(0xFFD32F2F) : const Color(0xFF1976D2),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0x33000000),
                                      blurRadius: 16,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  isListening ? Icons.mic : Icons.mic_none,
                                  color: Colors.white,
                                  size: screenHeight * 0.08,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            Text(
                              isListening ? 'ಕೇಳುತ್ತಿದೆ... ಮಾತನಾಡಿ' : (isSpeaking ? 'ಮಾತನಾಡುತ್ತಿದೆ...' : 'ಮಾತನಾಡಲು ಟ್ಯಾಪ್ ಮಾಡಿ'),
                              style: theme.textTheme.bodyLarge?.copyWith(fontSize: screenHeight * 0.022),
                            ),
                            const SizedBox(height: 8),

                            Text(
                              '"ಅನಾಮಧೇಯ" ಅಥವಾ "ಖಾತೆ ರಚಿಸಿ" ಎಂದು ಹೇಳಿ',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Action Buttons
                    Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: isSpeaking ? null : _handleAnonymous,
                            icon: const Icon(Icons.person_outline),
                            label: const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12.0),
                              child: Text('ಅನಾಮಧೇಯವಾಗಿ ಉಳಿಯಿರಿ'),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: isSpeaking ? null : _handleCreateAccount,
                            icon: const Icon(Icons.person_add_alt_1),
                            label: const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12.0),
                              child: Text('ಖಾತೆ ರಚಿಸಿ'),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00796B),
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

