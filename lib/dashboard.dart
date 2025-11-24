import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'services/tts_service.dart';
import 'services/firebase_service.dart';
import 'welcome_page.dart';
import 'voice_interface_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  String username = 'User';
  DateTime lmpDate = DateTime.now();
  GestationalAge? ga;
  bool loading = true;
  bool isSpeaking = false;

  final FirebaseService _firebaseService = FirebaseService();

  String riskLevel = 'Low';
  List<RecentSymptom> recentSymptoms = [];

  // SAFE NAVIGATION METHODS
  void _navigateToWelcome() {
    try {
      Navigator.pushReplacementNamed(context, '/welcome');
    } catch (e) {
      debugPrint('Navigation to welcome failed: $e');
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const WelcomePage()),
            (route) => false,
      );
    }
  }

  void _navigateToVoice() {
    try {
      Navigator.pushNamed(context, '/voice');
    } catch (e) {
      debugPrint('Navigation to voice failed: $e');
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const VoiceInterfacePage()),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _initTts();
    _loadPrefsAndCalculate();
  }

  Future<void> _initTts() async {
    await ttsService.setLanguage('kn-IN');
    await ttsService.setSpeechRate(0.4);
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
  }

  Future<void> _loadPrefsAndCalculate() async {
    final prefs = await SharedPreferences.getInstance();
    final storedUsername = prefs.getString('username');
    final lmpStr = prefs.getString('lmpDate');

    if (mounted) {
      setState(() {
        username = storedUsername ?? 'User';
        if (lmpStr != null) {
          try {
            lmpDate = DateTime.parse(lmpStr);
          } catch (_) {
            lmpDate = DateTime.now();
          }
        } else {
          lmpDate = DateTime.now();
        }
        ga = calculateGestationalAge(lmpDate);
      });
    }

    await _loadFirebaseData();

    if (mounted) {
      setState(() => loading = false);
    }
  }

  Future<void> _loadFirebaseData() async {
    try {
      final profile = await _firebaseService.getUserProfile();
      if (profile != null) {
        final dbUsername = profile['username'];
        if (dbUsername != null && dbUsername.isNotEmpty && mounted) {
          setState(() => username = dbUsername);
        }

        final lmpTimestamp = profile['lmp_date'] as Timestamp?;
        if (lmpTimestamp != null && mounted) {
          setState(() {
            lmpDate = lmpTimestamp.toDate();
            ga = calculateGestationalAge(lmpDate);
          });
        }
      }

      final notesData = await _firebaseService.getRecentVisitNotes(limit: 5);
      final List<RecentSymptom> loadedSymptoms = [];

      for (final note in notesData) {
        final transcript = (note['transcript'] ?? '').toString().trim();
        if (transcript.isNotEmpty) {
          final snippet = transcript.length > 60
              ? '${transcript.substring(0, 60)}...'
              : transcript;

          final timestamp = note['created_at'] as Timestamp;
          loadedSymptoms.add(RecentSymptom(
              symptom: snippet,
              date: _formatRelativeTime(timestamp.toDate()),
              severity: 'Normal'
          ));
        }
      }

      if (mounted) {
        setState(() {
          recentSymptoms = loadedSymptoms;
          riskLevel = loadedSymptoms.isEmpty ? 'Low' : 'Medium';
        });
      }
    } catch (e) {
      debugPrint('Firebase data loading error: $e');
      if (mounted) {
        setState(() {
          recentSymptoms = [
            RecentSymptom(symptom: 'ತಲೆನೋವು', date: 'ನಿನ್ನೆ', severity: 'ಕಡಿಮೆ'),
            RecentSymptom(symptom: 'ರಕ್ತದ ಒತ್ತಡ ಪರಿಶೀಲನೆ', date: '2 ದಿನಗಳ ಹಿಂದೆ', severity: 'ಸಾಮಾನ್ಯ'),
          ];
        });
      }
    }
  }

  String _formatRelativeTime(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) return 'ಇಂದು';
    if (difference.inDays == 1) return 'ನಿನ್ನೆ';
    if (difference.inDays < 7) return '${difference.inDays} ದಿನಗಳ ಹಿಂದೆ';
    if (difference.inDays < 30) return '${difference.inDays ~/ 7} ವಾರಗಳ ಹಿಂದೆ';
    return '${difference.inDays ~/ 30} ತಿಂಗಳ ಹಿಂದೆ';
  }

  Future<void> _speakSummary() async {
    if (ga == null || isSpeaking) return;

    final dueDateStr = formatDueDate(ga!.dueDate);
    final gaStr = formatGestationalAge(ga!);
    final trimester = ga!.trimester;
    final recent = recentSymptoms.isNotEmpty
        ? recentSymptoms.map((s) => s.symptom).join(', ')
        : 'ನೀವು ಇತ್ತೀಚೆಗೆ ಯಾವುದೇ ಲಕ್ಷಣಗಳನ್ನು ವರದಿ ಮಾಡಿಲ್ಲ';

    final summary =
        'ನಮಸ್ಕಾರ $username. ನೀವು ಪ್ರಸ್ತುತ ಗರ್ಭಾವಸ್ಥೆಯ $gaStr ನಲ್ಲಿದ್ದೀರಿ, ಇದು $trimester ನೇ ತ್ರೈಮಾಸಿಕ. ನಿಮ್ಮ ನಿರೀಕ್ಷಿತ ಹೆರಿಗೆ ದಿನಾಂಕ $dueDateStr. ನಿಮ್ಮ ಗರ್ಭಾವಸ್ಥೆಯ ಅಪಾಯ ಮೌಲ್ಯಮಾಪನ $riskLevel ಆಗಿದೆ. ${recentSymptoms.isNotEmpty ? 'ನೀವು ಇತ್ತೀಚೆಗೆ ವರದಿ ಮಾಡಿದ ಲಕ್ಷಣಗಳು: $recent.' : recent}';

    await ttsService.speak(summary);
  }


  String _translateSeverity(String s) {
    if (s == 'Low') return 'ಕಡಿಮೆ';
    if (s == 'Normal') return 'ಸಾಮಾನ್ಯ';
    return s;
  }

  @override
  void dispose() {
    ttsService.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (loading || ga == null) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: Color(0xFF00796B)),
              const SizedBox(height: 16),
              Text('ಲೋಡ್ ಆಗುತ್ತಿದೆ...', style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF00796B)),
          onPressed: _navigateToWelcome,
          tooltip: 'ಹಿಂದೆ',
        ),
        title: Text('ಡ್ಯಾಶ್‌ಬೋರ್ಡ್', style: Theme.of(context).textTheme.titleLarge),
        backgroundColor: Colors.white,
        elevation: 1,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Welcome Section
                Column(
                  children: [
                    Text('ಸ್ವಾಗತ, $username', style: Theme.of(context).textTheme.displaySmall),
                    const SizedBox(height: 8),
                    Text('ನಿಮ್ಮ ಗರ್ಭಾವಸ್ಥೆಯ ಅವಲೋಕನ ಇಲ್ಲಿದೆ', style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
                const SizedBox(height: 32),

                // CENTERED MIC BUTTON FOR DASHBOARD SUMMARY
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 20),
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: _speakSummary,
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: const Color(0xFF00796B),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Color.fromRGBO(0, 121, 107, 0.3),
                                blurRadius: 15,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Icon(
                            isSpeaking ? Icons.volume_up : Icons.mic,
                            color: Colors.white,
                            size: 50,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'ಡ್ಯಾಶ್ಬೋರ್ಡ್ ಸಾರಾಂಶವನ್ನು ಕೇಳಲು ಟ್ಯಾಪ್ ಮಾಡಿ',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Gestational Age Card
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(Icons.calendar_today, size: 20, color: Theme.of(context).primaryColor),
                            const SizedBox(width: 8),
                            Text('ಗರ್ಭಾವಸ್ಥೆಯ ವಯಸ್ಸು', style: Theme.of(context).textTheme.titleLarge),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          formatGestationalAge(ga!),
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF00796B),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text('ತ್ರೈಮಾಸಿಕ ${ga!.trimester}', style: Theme.of(context).textTheme.bodyMedium),
                        const SizedBox(height: 20),
                        Text('ನಿರೀಕ್ಷಿತ ಹೆರಿಗೆ ದಿನಾಂಕ: ${formatDueDate(ga!.dueDate)}', style: Theme.of(context).textTheme.bodyMedium),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Recent Activity Card
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(Icons.history, size: 20, color: Theme.of(context).primaryColor),
                            const SizedBox(width: 8),
                            Text('ಇತ್ತೀಚಿನ ಚಟುವಟಿಕೆ', style: Theme.of(context).textTheme.titleLarge),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (recentSymptoms.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Text('ಇತ್ತೀಚೆಗೆ ಯಾವುದೇ ಲಕ್ಷಣಗಳನ್ನು ವರದಿ ಮಾಡಲಾಗಿಲ್ಲ', style: Theme.of(context).textTheme.bodyMedium),
                          )
                        else
                          Column(
                            children: recentSymptoms.map((item) {
                              final bgColor = item.severity == 'Low'
                                  ? Colors.green.withAlpha(30)
                                  : item.severity == 'Normal'
                                  ? Theme.of(context).primaryColor.withAlpha(30)
                                  : Colors.orange.withAlpha(30);
                              final badgeText = _translateSeverity(item.severity);
                              final dateDisplay = item.date;
                              return Container(
                                margin: const EdgeInsets.symmetric(vertical: 6),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(10)),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(item.symptom, style: const TextStyle(fontWeight: FontWeight.w600)),
                                          const SizedBox(height: 4),
                                          Text(dateDisplay, style: TextStyle(color: Colors.grey[700], fontSize: 13)),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(20)),
                                      child: Text(badgeText, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                    )
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                // Actions
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.mic),
                        label: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 14.0),
                          child: Text('ಲಕ್ಷಣವನ್ನು ವರದಿ ಮಾಡಿ', style: TextStyle(fontSize: 16)),
                        ),
                        onPressed: _navigateToVoice,
                        style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00796B),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Voice helper card
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(Icons.chat, size: 20, color: Theme.of(context).primaryColor),
                            const SizedBox(width: 8),
                            Text('ಧ್ವನಿ ಸಹಾಯಕ', style: Theme.of(context).textTheme.titleLarge),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text('ನಿಮ್ಮ ಆರೋಗ್ಯ ಪ್ರಶ್ನೆಗಳಿಗೆ ತಕ್ಷಣ ಉತ್ತರ ಪಡೆಯಿರಿ', style: Theme.of(context).textTheme.bodyMedium),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.mic),
                          label: const Text('ಪ್ರಶ್ನೆ ಕೇಳಿ'),
                          onPressed: _navigateToVoice,
                          style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1976D2),
                              foregroundColor: Colors.white
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class RecentSymptom {
  final String symptom;
  final String date;
  final String severity;

  RecentSymptom({required this.symptom, required this.date, required this.severity});
}

class GestationalAge {
  final int weeks;
  final int days;
  final DateTime dueDate;
  final double percentComplete;
  final int trimester;

  GestationalAge({
    required this.weeks,
    required this.days,
    required this.dueDate,
    required this.percentComplete,
    required this.trimester,
  });
}

GestationalAge calculateGestationalAge(DateTime lmp) {
  final now = DateTime.now();
  final dueDate = lmp.add(const Duration(days: 280));
  final elapsed = now.difference(lmp).inDays.clamp(0, 280);
  final weeks = elapsed ~/ 7;
  final days = elapsed % 7;
  final percentComplete = (elapsed / 280.0) * 100.0;
  final trimester = (weeks < 13) ? 1 : (weeks < 27) ? 2 : 3;
  return GestationalAge(
    weeks: weeks,
    days: days,
    dueDate: dueDate,
    percentComplete: percentComplete,
    trimester: trimester,
  );
}

String formatGestationalAge(GestationalAge ga) {
  return '${ga.weeks} ವಾರಗಳು ${ga.days} ದಿನಗಳು';
}

String formatDueDate(DateTime due) {
  final months = [
    'ಜನವರಿ', 'ಫೆಬ್ರವರಿ', 'ಮಾರ್ಚ್', 'ಎಪ್ರಿಲ್', 'ಮೇ', 'ಜೂನ್',
    'ಜುಲೈ', 'ಆಗಸ್ಟ್', 'ಸೆಪ್ಟೆಂಬರ್', 'ಅಕ್ಟೋಬರ್', 'ನವೆಂಬರ್', 'ಡಿಸೆಂಬರ್'
  ];
  final day = due.day;
  final month = months[due.month - 1];
  final year = due.year;
  return '$day $month $year';
}