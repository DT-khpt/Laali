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
      _startAutoVoiceSignup();
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

    // Start the signup flow after TTS is initialized
    if (!hasSpokenIntro) {
      await _speak('ನಾನು ನಿಮಗೆ ಖಾತೆಯನ್ನು ರಚಿಸಲು ಸಹಾಯ ಮಾಡುತ್ತೇನೆ. ದಯವಿಟ್ಟು ನಿಮ್ಮ ಹೆಸರನ್ನು ಹೇಳಿ.');
      if (mounted) setState(() => hasSpokenIntro = true);
    }
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

    await speechService.startListeningWithMixedLanguage(
      (text, isFinal) {
        if (mounted) {
          setState(() => transcript = text);
          if (isFinal) {
            _handleRecognitionResult(text);
          }
        }
      },
    );
  }

  Future<void> _startAutoVoiceSignup() async {
    if (!hasSpokenIntro) {
      await _speak('ನಾನು ನಿಮಗೆ ಖಾತೆಯನ್ನು ರಚಿಸಲು ಸಹಾಯ ಮಾಡುತ್ತೇನೆ. ದಯವಿಟ್ಟು ನಿಮ್ಮ ಹೆಸರನ್ನು ಹೇಳಿ.');
      if (mounted) setState(() => hasSpokenIntro = true);
    }
    // Start listening for name input
    await _startListeningForName();
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

        // Speak confirmation with extracted name only
        await _speak('ನೀವು "$extractedName" ಎಂದು ಹೇಳಿದ್ದೀರಿ. ನಾನು ಇದನ್ನು ನಿಮ್ಮ ಹೆಸರಾಗಿ ಉಳಿಸಬೇಕೇ?');
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
        await _speak('ನೀವು $display ಎಂದು ಹೇಳಿದ್ದೀರಿ. ನಾನು ಈ ದಿನಾಂಕವನ್ನು ಉಳಿಸಬೇಕೇ?');
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    String subtitle;
    switch (step) {
      case SignupStep.username:
        subtitle = 'ನಿಮ್ಮ ಹೆಸರನ್ನು ಹೇಳಿ';
        break;
      case SignupStep.lmp:
        subtitle = 'ನಿಮ್ಮ ಕೊನೆಯ ಮುಟ್ಟಿನ ದಿನಾಂಕವನ್ನು ಹೇಳಿ';
        break;
      case SignupStep.confirm:
        subtitle = 'ಮಾಹಿತಿಯನ್ನು ದೃಢೀಕರಿಸಿ';
        break;
    }

    return Scaffold(
      body: SafeArea(
        child: Container(
          width: double.infinity,
          height: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [Color(0xFFF7FAFC), Color(0xFFFFFFFF)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
          ),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('ಹಿಂದೆ'),
                ),
              ),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('ಖಾತೆ ರಚಿಸಿ', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text(subtitle, style: theme.textTheme.titleMedium?.copyWith(color: Colors.grey[700])),
                        const SizedBox(height: 18),

                        Card(
                          elevation: 4,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      height: 8,
                                      width: 80,
                                      decoration: BoxDecoration(
                                        color: username.isNotEmpty ? theme.primaryColor : Colors.grey[300],
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      height: 8,
                                      width: 80,
                                      decoration: BoxDecoration(
                                        color: lmpDate != null ? theme.primaryColor : Colors.grey[300],
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),

                                if (username.isNotEmpty)
                                  Column(
                                    children: [
                                      const Align(alignment: Alignment.centerLeft, child: Text('ಹೆಸರು', style: TextStyle(fontWeight: FontWeight.w600))),
                                      const SizedBox(height: 6),
                                      Text(username, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w600)),
                                      const SizedBox(height: 12),
                                    ],
                                  ),

                                if (lmpDate != null)
                                  Column(
                                    children: [
                                      const Align(alignment: Alignment.centerLeft, child: Text('ಕೊನೆಯ ಮುಟ್ಟಿನ ದಿನಾಂಕ', style: TextStyle(fontWeight: FontWeight.w600))),
                                      const SizedBox(height: 6),
                                      Text(_formatDateKn(lmpDate!), textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w600)),
                                      const SizedBox(height: 12),
                                    ],
                                  ),

                                if (transcript.isNotEmpty)
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(color: theme.primaryColor.withAlpha(20), borderRadius: BorderRadius.circular(8)),
                                    child: Text('"$transcript"', textAlign: TextAlign.center, style: const TextStyle(fontStyle: FontStyle.italic)),
                                  ),

                                const SizedBox(height: 12),

                                Column(
                                  children: [
                                    GestureDetector(
                                      onTap: _toggleListening,
                                      child: Container(
                                        padding: const EdgeInsets.all(14),
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: isListening ? Colors.red : theme.primaryColor,
                                          boxShadow: [BoxShadow(color: Colors.black.withAlpha(30), blurRadius: 8)],
                                        ),
                                        child: Icon(isListening ? Icons.mic : Icons.mic_none, color: Colors.white, size: 28),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      isListening ? '🔴 Recording...' : (isSpeaking ? '🔊 Speaking...' : '🎤 Tap to speak'),
                                      style: const TextStyle(fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 14),

                                if (step == SignupStep.confirm)
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton(
                                          onPressed: _handleReject,
                                          child: const Text('ಬದಲಾಯಿಸಿ'),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          onPressed: _handleConfirm,
                                          icon: const Icon(Icons.check),
                                          label: const Text('ದೃಢೀಕರಿಸಿ'),
                                        ),
                                      ),
                                    ],
                                  ),

                                const SizedBox(height: 8),

                                OutlinedButton(
                                  onPressed: _skipToDemo,
                                  child: const Text('ಡ್ಯಾಶ್‌ಬೋರ್ಡ್‌ಗೆ ಹೋಗಿ (ಡೆಮೊ)'),
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
            ],
          ),
        ),
      ),
    );
  }
}
