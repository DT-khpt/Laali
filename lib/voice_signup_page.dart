import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/tts_service.dart';
import 'services/speech_service.dart';
import 'services/name_extractor.dart';
import 'services/voice_identity_service.dart';
import 'services/ai_service.dart';

enum SignupStep { username, lmp, confirm }

class VoiceSignupPage extends StatefulWidget {
  const VoiceSignupPage({super.key});

  @override
  State<VoiceSignupPage> createState() => _VoiceSignupPageState();
}

class _VoiceSignupPageState extends State<VoiceSignupPage> {
  SignupStep step = SignupStep.username;
  String username = '';
  DateTime? lmpDate;
  String transcript = '';
  bool hasSpokenIntro = false;

  bool isListening = false;
  bool isSpeaking = false;

  // Use the shared aiService from lib/services/ai_service.dart
  @override
  void initState() {
    super.initState();
    _initTts();
    // Auto-start voice flow after UI is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 900), () {
        _startAutoVoiceSignup();
      });
    });
  }

  Future<void> _initTts() async {
    await ttsService.setLanguage('kn-IN');
    await ttsService.setSlowSpeed(); // SLOWER speed for important signup process
    await ttsService.setPitch(1.0);

    ttsService.setStartHandler(() {
      if (mounted) setState(() => isSpeaking = true);
    });
    ttsService.setCompletionHandler(() {
      if (mounted) setState(() => isSpeaking = false);
    });
    ttsService.setErrorHandler((err) {
      debugPrint('TTS error: $err');
      if (mounted) setState(() => isSpeaking = false);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!hasSpokenIntro) {
        Future.delayed(const Duration(milliseconds: 800), () {
          _speak('ನಾನು ನಿಮಗೆ ಖಾತೆಯನ್ನು ರಚಿಸಲು ಸಹಾಯ ಮಾಡುತ್ತೇನೆ. ದಯವಿಟ್ಟು ನಿಮ್ಮ ಹೆಸರನ್ನು ಹೇಳಿ.');
          if (mounted) setState(() => hasSpokenIntro = true);
        });
      }
    });
  }

  Future<void> _speak(String text) async {
    if (text.isEmpty) return;
    try {
      await ttsService.speak(text);
    } catch (e) {
      debugPrint('TTS speak error: $e');
    }
  }

  Future<void> _toggleListening() async {
    // For signup we prefer to auto-start listening flow
    await _startListeningForName();
  }

  Future<void> _startAutoVoiceSignup() async {
    if (!hasSpokenIntro) {
      await _speak('ನಾನು ನಿಮಗೆ ಖಾತೆಯನ್ನು ರಚಿಸಲು ಸಹಾಯ ಮಾಡುತ್ತೇನೆ. ದಯವಿಟ್ಟು ನಿಮ್ಮ ಹೆಸರನ್ನು ಹೇಳಿ.');
      if (mounted) setState(() => hasSpokenIntro = true);
    }
    // Start listening for name input
    await _startListeningForName();
  }

  Future<void> _startListeningForName() async {
    if (isSpeaking) return;

    final ok = await speechService.initialize();
    if (!ok) {
      await _speak('ಕ್ಷಮಿಸಿ, ಮಾತಿನ ಗುರುತಿಸುವಿಕೆ ಲಭ್ಯವಿಲ್ಲ.');
      return;
    }

    if (mounted) {
      setState(() {
        isListening = true;
        transcript = '';
      });
    }

    try {
      await speechService.startListeningWithRetry((text, isFinal) {
        if (!mounted) return;
        setState(() => transcript = text);
        if (isFinal && text.isNotEmpty) {
          // Handle recognized result (existing flow)
          _handleRecognitionResult(text);
          // If still not at confirm step, keep listening for name again
          if (step == SignupStep.username) {
            Future.delayed(const Duration(milliseconds: 800), () async {
              if (mounted) await _startListeningForName();
            });
          } else {
            // stop listening if moved to confirm
            setState(() => isListening = false);
          }
        } else if (isFinal) {
          // no words detected
          setState(() => isListening = false);
        }
      }, localeId: 'kn-IN', retries: 2, attemptTimeout: const Duration(seconds: 10), onFailure: () async {
        if (!mounted) return;
        setState(() => isListening = false);
        await _speak('ಕ್ಷಮಿಸಿ, ನಾನು ನಿಮ್ಮನ್ನು ಕೇಳಲಾರದಿದ್ದು. ದಯವಿಟ್ಟು ಮೈಕ್ರೊಫೋನ್ ಅನುಮತಿಗಳನ್ನು ಪರಿಶೀಲಿಸಿ.');
      });
    } catch (e) {
      debugPrint('startListeningForName error: $e');
      if (mounted) setState(() => isListening = false);
    }
  }

  /// Speak a prompt and listen for a single final reply, then call onFinal.
  Future<void> _speakThenListen(String prompt, Future<void> Function(String) onFinal) async {
    await _speak(prompt);
    // Start listening and wait for a final result
    await speechService.startListeningWithRetry((text, isFinal) async {
      if (isFinal) {
        await onFinal(text);
      } else {
        if (mounted) setState(() => transcript = text);
      }
    }, localeId: 'kn-IN', retries: 2, attemptTimeout: const Duration(seconds: 10), onFailure: () async {
      await _speak('ಕ್ಷಮಿಸಿ, ನನಗೇ ನಿಮ್ಮ ಧ್ವನಿ ಕೇಳಿಸುತಿಲ್ಲ. ದಯವಿಟ್ಟು ಮೈಕ್ರೊಫೋನ್ ಪರಿಶೀಲಿಸಿ.');
    });
  }

  void _handleRecognitionResult(String text) async {
    final lower = text.toLowerCase();
    if (mounted) {
      setState(() {
        transcript = text;
      });
    }

    if (step == SignupStep.username) {
      // Use smart name extraction
      final extractedName = nameExtractor.extractNameFromContext(text, 'username');

      debugPrint("📝 Original: '$text'");
      debugPrint("🎯 Extracted: '$extractedName'");

      if (extractedName.isNotEmpty && extractedName.length > 1) {
        if (mounted) {
          setState(() {
            username = extractedName;
            step = SignupStep.confirm;
          });
        }

        // Speak confirmation with extracted name and then listen for yes/no
        await _speakThenListen('ನೀವು "$extractedName" ಎಂದು ಹೇಳಿದ್ದೀರಿ. ನಾನು ಇದನ್ನು ನಿಮ್ಮ ಹೆಸರಾಗಿ ಉಳಿಸಬೇಕೇ?', (reply) async {
          final lower = reply.toLowerCase();
          if (lower.contains('ಹೌದು') || lower.contains('yes') || lower.contains('ಸರಿ')) {
            await _handleConfirm();
          } else {
            await _handleReject();
          }
        });
      } else {
        await _speak('ದಯವಿಟ್ಟು ನಿಮ್ಮ ಹೆಸರನ್ನು ಸ್ಪಷ್ಟವಾಗಿ ಹೇಳಿ. ಉದಾಹರಣೆ: "ನನ್ನ ಹೆಸರು ರಮ್ಯಾ" ಅಥವಾ "My name is Ramya"');
      }
      return;
    }

    if (step == SignupStep.lmp) {
      final parsed = parseLMPDate(text);
      if (parsed != null) {
        if (mounted) {
          setState(() {
            lmpDate = parsed;
            step = SignupStep.confirm;
          });
        }
        final display = _formatDateKn(parsed);
        await _speakThenListen('ನೀವು $display ಎಂದು ಹೇಳಿದ್ದೀರಿ. ನಾನು ಈ ದಿನಾಂಕವನ್ನು ಉಳಿಸಬೇಕೇ?', (reply) async {
          final lower = reply.toLowerCase();
          if (lower.contains('ಹೌದು') || lower.contains('yes') || lower.contains('ಸರಿ')) {
            await _handleConfirm();
          } else {
            await _handleReject();
          }
        });
      } else {
        await _speak('ದಿನಾಂಕವನ್ನು ಅರ್ಥಮಾಡಿಕೊಳ್ಳಲಾಗಲಿಲ್ಲ. ದಯವಿಟ್ಟು ಮತ್ತೊಮ್ಮೆ ಪ್ರಯತ್ನಿಸಿ.');
      }
      return;
    }

    if (step == SignupStep.confirm) {
      if (lower.contains('ಹೌದು') || lower.contains('yes') || lower.contains('ಸರಿ') || lower.contains('correct')) {
        await _handleConfirm();
      } else if (lower.contains('ಇಲ್ಲ') || lower.contains('no') || lower.contains('ಬದಲಿಸು') || lower.contains('change')) {
        await _handleReject();
      } else {
        await _speak('ಕ್ಷಮಿಸಿ, ದಯವಿಟ್ಟು ಸರಿ ಅಥವಾ ಇಲ್ಲ ಎಂದು ಹೇಳಿ.');
      }
      return;
    }

    // Fallback: route general questions during signup to AIService (KB first)
    final fallbackResp = await aiService.getResponse(text, 'signup');
    debugPrint('AI fallback during signup: $fallbackResp');
    await _speak(fallbackResp);
  }

  Future<void> _handleConfirm() async {
    if (step == SignupStep.confirm && username.isNotEmpty && lmpDate == null) {
      if (mounted) {
        setState(() {
          step = SignupStep.lmp;
          transcript = '';
        });
      }
      await _speak('ಉತ್ತಮ! ಈಗ ದಯವಿಟ್ಟು ನಿಮ್ಮ ಕೊನೆಯ ಮುಟ್ಟಿನ ದಿನಾಂಕವನ್ನು ಹೇಳಿ.');
      return;
    } else if (step == SignupStep.confirm && lmpDate != null) {
      // Create voice identity for the new user
      await voiceIdentityService.createVoiceIdentity(username);

      await _speak('ಖಾತೆಯನ್ನು ಯಶಸ್ವಿಯಾಗಿ ರಚಿಸಲಾಗಿದೆ! ನಿಮ್ಮನ್ನು ಡ್ಯಾಶ್‌ಬೋರ್ಡ್‌ಗೆ ಕರೆದೊಯ್ಯುತ್ತಿದ್ದೇನೆ.');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('userMode', 'account');
      await prefs.setString('username', username);
      await prefs.setString('lmpDate', lmpDate!.toIso8601String());

      if (mounted) {
        Navigator.pushReplacementNamed(context, '/dashboard');
      }
      return;
    }
  }

  Future<void> _handleReject() async {
    if (username.isNotEmpty && lmpDate == null) {
      await _speak('ಸರಿ, ನಿಮ್ಮ ಹೆಸರನ್ನು ಮತ್ತೊಮ್ಮೆ ಹೇಳಿ.');
      if (mounted) {
        setState(() {
          username = '';
          step = SignupStep.username;
          transcript = '';
        });
      }
    } else if (lmpDate != null) {
      await _speak('ಸರಿ, ದಿನಾಂಕವನ್ನು ಮತ್ತೊಮ್ಮೆ ಹೇಳಿ.');
      if (mounted) {
        setState(() {
          lmpDate = null;
          step = SignupStep.lmp;
          transcript = '';
        });
      }
    } else {
      await _speak('ಸರಿ, ದಯವಿಟ್ಟು ಮತ್ತೆ ಪ್ರಯತ್ನಿಸಿ.');
      if (mounted) {
        setState(() {
          transcript = '';
        });
      }
    }
  }

  String _formatDateKn(DateTime d) {
    final months = [
      'ಜನವರಿ',
      'ಫೆಬ್ರವರಿ',
      'ಮಾರ್ಚ್',
      'ಎಪ್ರಿಲ್',
      'ಮೇ',
      'ಜೂನ',
      'ಜುಲೈ',
      'ಆಗಸ್ಟ್',
      'ಸೆಪ್ಟೆಂಬರ್',
      'ಅಕ್ಟೋಬರ್',
      'ನವೆಂಬರ್',
      'ಡಿಸೆಂಬರ್'
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  DateTime? parseLMPDate(String input) {
    final s = input.trim();

    try {
      return DateTime.parse(s);
    } catch (_) {}

    final reDMY = RegExp(r'(\d{1,2})[/\-](\d{1,2})[/\-](\d{2,4})');
    final m1 = reDMY.firstMatch(s);
    if (m1 != null) {
      final d = int.tryParse(m1.group(1) ?? '');
      final mo = int.tryParse(m1.group(2) ?? '');
      var y = int.tryParse(m1.group(3) ?? '');
      if (d != null && mo != null && y != null) {
        if (y < 100) y += 2000;
        try {
          return DateTime(y, mo, d);
        } catch (_) {}
      }
    }

    final monthNames = {
      'january': 1,
      'jan': 1,
      'february': 2,
      'feb': 2,
      'march': 3,
      'mar': 3,
      'april': 4,
      'apr': 4,
      'may': 5,
      'june': 6,
      'jun': 6,
      'july': 7,
      'jul': 7,
      'august': 8,
      'aug': 8,
      'september': 9,
      'sep': 9,
      'sept': 9,
      'october': 10,
      'oct': 10,
      'november': 11,
      'nov': 11,
      'december': 12,
      'dec': 12,
      'ಜನವರಿ': 1,
      'ಫೆಬ್ರವರಿ': 2,
      'ಮಾರ್ಚ್': 3,
      'ಏಪ್ರಿಲ್': 4,
      'ಮೇ': 5,
      'ಜೂನ್': 6,
      'ಜುಲೈ': 7,
      'ಆಗಸ್ಟ್': 8,
      'ಸೆಪ್ಟೆಂಬರ್': 9,
      'ಅಕ್ಟೋಬರ್': 10,
      'ನವೆಂಬರ್': 11,
      'ಡಿಸೆಂಬರ್': 12
    };

    final tokens = s.replaceAll(RegExp(r'[,.\-]'), ' ').split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();

    int? day;
    int? month;
    int? year;

    for (final t in tokens) {
      final n = int.tryParse(t);
      if (n != null) {
        if (n > 31 && year == null) {
          year = n < 100 ? (n + 2000) : n;
        } else if (day == null) {
          day = n;
        } else if (month == null && n <= 12) {
          month = n;
        }
      } else {
        if (month == null && monthNames.containsKey(t.toLowerCase())) {
          month = monthNames[t.toLowerCase()];
        }
      }
    }

    if (day != null && month != null) {
      year ??= DateTime.now().year;
      try {
        return DateTime(year, month, day);
      } catch (_) {}
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Use helper _getSubtitle() instead of a local variable

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Container(
          width: double.infinity,
          height: double.infinity,
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              // Back Button
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back, color: Color(0xFF00796B)),
                  label: const Text('ಹಿಂದೆ', style: TextStyle(color: Color(0xFF00796B))),
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 480),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('ಖಾತೆ ರಚಿಸಿ', style: theme.textTheme.displayMedium),
                          const SizedBox(height: 8),

                          Text(
                            _getSubtitle(),
                            style: theme.textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 32),

                          // Signup Card
                          Card(
                            elevation: 4,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                children: [
                                  // Progress Indicator
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      _buildProgressStep(1, 'ಹೆಸರು', username.isNotEmpty),
                                      const SizedBox(width: 8),
                                      _buildProgressStep(2, 'ದಿನಾಂಕ', lmpDate != null),
                                    ],
                                  ),
                                  const SizedBox(height: 24),

                                  // User Info Display
                                  if (username.isNotEmpty) _buildInfoRow('ಹೆಸರು', username),
                                  if (lmpDate != null) _buildInfoRow('ಕೊನೆಯ ಮುಟ್ಟಿನ ದಿನಾಂಕ', _formatDateKn(lmpDate!)),

                                  if (transcript.isNotEmpty)
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(16),
                                      margin: const EdgeInsets.symmetric(vertical: 16),
                                      decoration: BoxDecoration(
                                        color: const Color(0x0D1976D2), // 5% blue
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: const Color(0x331976D2), // 20% blue
                                        ),
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

                                  const SizedBox(height: 16),

                                  // Microphone Button
                                  Column(
                                    children: [
                                      GestureDetector(
                                        onTap: _toggleListening,
                                        child: Container(
                                          width: 80,
                                          height: 80,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: isListening
                                                ? const Color(0xFFD32F2F)
                                                : const Color(0xFF1976D2),
                                            boxShadow: [
                                              BoxShadow(
                                                color: const Color(0x26000000), // ~15% black
                                                blurRadius: 8,
                                                offset: const Offset(0, 4),
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
                                      const SizedBox(height: 12),
                                      Text(
                                        isListening ? 'ಕೇಳುತ್ತಿದೆ...' : (isSpeaking ? 'ಮಾತನಾಡುತ್ತಿದೆ...' : 'ಮಾತನಾಡಲು ಟ್ಯಾಪ್ ಮಾಡಿ'),
                                        style: theme.textTheme.bodyLarge,
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 24),

                                  // Action Buttons
                                  if (step == SignupStep.confirm)
                                    Row(
                                      children: [
                                        Expanded(
                                          child: OutlinedButton(
                                            onPressed: _handleReject,
                                            child: const Text('ಬದಲಾಯಿಸಿ'),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: ElevatedButton.icon(
                                            onPressed: _handleConfirm,
                                            icon: const Icon(Icons.check),
                                            label: const Text('ದೃಢೀಕರಿಸಿ'),
                                          ),
                                        ),
                                      ],
                                    ),

                                  const SizedBox(height: 16),

                                  OutlinedButton(
                                    onPressed: _skipToDemo,
                                    child: const Text('ಡೆಮೊ ಡ್ಯಾಶ್‌ಬೋರ್ಡ್'),
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
            ],
          ),
        ),
      ),
    );
  }

  // Add these helper methods:
  String _getSubtitle() {
    switch (step) {
      case SignupStep.username:
        return 'ನಿಮ್ಮ ಹೆಸರನ್ನು ಹೇಳಿ';
      case SignupStep.lmp:
        return 'ನಿಮ್ಮ ಕೊನೆಯ ಮುಟ್ಟಿನ ದಿನಾಂಕವನ್ನು ಹೇಳಿ';
      case SignupStep.confirm:
        return 'ಮಾಹಿತಿಯನ್ನು ದೃಢೀಕರಿಸಿ';
    }
  }

  Widget _buildProgressStep(int stepNumber, String label, bool isCompleted) {
    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isCompleted ? const Color(0xFF00796B) : Colors.grey.shade300,
          ),
          child: Center(
            child: Text(
              stepNumber.toString(),
              style: TextStyle(
                color: isCompleted ? Colors.white : Colors.grey.shade600,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isCompleted ? const Color(0xFF00796B) : Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.black54,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              color: Color(0xFF00796B),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    ttsService.stop();
    speechService.cancel();
    super.dispose();
  }

  void _skipToDemo() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userMode', 'account');
    await prefs.setString('username', 'ಅತಿಥಿ');
    await prefs.setString('lmpDate', DateTime.now().toIso8601String());
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/dashboard');
    }
  }
}
