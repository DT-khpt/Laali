import 'package:flutter/material.dart';
import 'package:mcp/provider/user_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/tts_service.dart';
import '../services/firebase_service.dart';
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
    final userProvider = context.read<UserProvider>();
    final user = userProvider.user;

    if (user != null) {
      username = user.username;
      lmpDate = user.lmpDate;
      ga = calculateGestationalAge(lmpDate);
    }

    await _loadFirebaseData();

    if (mounted) setState(() => loading = false);
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

      // Set recent activities
      if (mounted) {
        setState(() {
          recentSymptoms = [
            RecentSymptom(
              symptom: 'ಗರ್ಭಾವಸ್ಥೆಯ ವಯಸ್ಸು ಪರಿಶೀಲಿಸಲಾಗಿದೆ',
              date: 'ಇಂದು',
              severity: 'ಸಾಮಾನ್ಯ',
            ),
            RecentSymptom(
              symptom: 'ತಲೆನೋವು ವರದಿ ಮಾಡಲಾಗಿದೆ',
              date: 'ನಿನ್ನೆ',
              severity: 'ಕಡಿಮೆ',
            ),
            RecentSymptom(
              symptom: 'ರಕ್ತದ ಒತ್ತಡ ಪರಿಶೀಲನೆ',
              date: '2 ದಿನಗಳ ಹಿಂದೆ',
              severity: 'ಸಾಮಾನ್ಯ',
            ),
            RecentSymptom(
              symptom: 'ಆಹಾರ ಸಲಹೆ ಕೇಳಲಾಗಿದೆ',
              date: '3 ದಿನಗಳ ಹಿಂದೆ',
              severity: 'ಕಡಿಮೆ',
            ),
          ];
          riskLevel = 'ಕಡಿಮೆ';
        });
      }
    } catch (e) {
      debugPrint('Firebase data loading error: $e');
      if (mounted) {
        setState(() {
          recentSymptoms = [
            RecentSymptom(
              symptom: 'ಗರ್ಭಾವಸ್ಥೆಯ ವಯಸ್ಸು ಪರಿಶೀಲಿಸಲಾಗಿದೆ',
              date: 'ಇಂದು',
              severity: 'ಸಾಮಾನ್ಯ',
            ),
            RecentSymptom(
              symptom: 'ತಲೆನೋವು ವರದಿ ಮಾಡಲಾಗಿದೆ',
              date: 'ನಿನ್ನೆ',
              severity: 'ಕಡಿಮೆ',
            ),
          ];
        });
      }
    }
  }

  Future<void> _speakSummary() async {
    if (ga == null || isSpeaking) return;

    final dueDateStr = formatDueDate(ga!.dueDate);
    final gaStr = formatGestationalAge(ga!);
    final trimester = ga!.trimester;
    final recent = recentSymptoms.isNotEmpty
        ? recentSymptoms.map((s) => s.symptom).join(', ')
        : 'ನೀವು ಇತ್ತೀಚೆಗೆ ಯಾವುದೇ ಚಟುವಟಿಕೆಗಳನ್ನು ಹೊಂದಿಲ್ಲ';

    final summary =
        'ನಮಸ್ಕಾರ $username. ನೀವು ಪ್ರಸ್ತುತ ಗರ್ಭಾವಸ್ಥೆಯ $gaStr ನಲ್ಲಿದ್ದೀರಿ, ಇದು $trimester ನೇ ತ್ರೈಮಾಸಿಕ. ನಿಮ್ಮ ನಿರೀಕ್ಷಿತ ಹೆರಿಗೆ ದಿನಾಂಕ $dueDateStr. ನಿಮ್ಮ ಇತ್ತೀಚಿನ ಚಟುವಟಿಕೆಗಳು: $recent.';

    await ttsService.speak(summary);
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
              Text('ಲೋಡ್ ಆಗುತ್ತಿದೆ...',
                  style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Row(
        children: [
          SizedBox(width: 20,),
          ClipOval(
            child: Image.asset(
              'assets/images/Laali Logo-03.jpg',
              height: 40,
              width: 40,
              fit: BoxFit.cover,
            ),
          ),
          SizedBox(width: 20,),
          Text('ಡ್ಯಾಶ್‌ಬೋರ್ಡ್',
        style: Theme.of(context).textTheme.titleLarge),
        ],
      ),
        centerTitle: true,
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
                    Text('ಸ್ವಾಗತ, $username',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 22)),
                    const SizedBox(height: 8),
                    Text('ನಿಮ್ಮ ಗರ್ಭಾವಸ್ಥೆಯ ಅವಲೋಕನ ಇಲ್ಲಿದೆ',
                        style: Theme.of(context).textTheme.bodyMedium),
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
                            isSpeaking ? Icons.volume_up : Icons.volume_up,
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
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ⭐ LEFT SIDE — TEXT
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.calendar_today,
                                      size: 20,
                                      color: Theme.of(context).primaryColor),
                                  const SizedBox(width: 8),
                                  Text(
                                    'ಗರ್ಭಾವಸ್ಥೆಯ ವಯಸ್ಸು',
                                    style:
                                    Theme.of(context).textTheme.titleLarge,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                formatGestationalAge(ga!),
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF00796B),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'ತ್ರೈಮಾಸಿಕ ${ga!.trimester}',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'ನಿರೀಕ್ಷಿತ ಹೆರಿಗೆ ದಿನಾಂಕ: ${formatDueDate(ga!.dueDate)}',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(width: 12),

                        // ⭐ RIGHT SIDE — CIRCULAR IMAGE
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            boxShadow: [
                              BoxShadow(
                                blurRadius: 6,
                                offset: const Offset(0, 3),
                                color: Colors.black26,
                              )
                            ],
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Image.asset(
                            'assets/images/maternal-hero---1.jpg',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // NEW: Recent Activities Card (in Kannada)
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.history,
                                size: 20,
                                color: Theme.of(context).primaryColor),
                            const SizedBox(width: 8),
                            Text('ಇತ್ತೀಚಿನ ಚಟುವಟಿಕೆಗಳು',
                                style: Theme.of(context).textTheme.titleLarge),
                          ],
                        ),
                        const SizedBox(height: 12),

                        if (recentSymptoms.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            child: Text(
                              'ಇತ್ತೀಚೆಗೆ ಯಾವುದೇ ಚಟುವಟಿಕೆಗಳಿಲ್ಲ',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontStyle: FontStyle.italic,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          )
                        else
                          Column(
                            children: recentSymptoms.map((activity) =>
                                Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.grey.shade200,
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: 8,
                                        height: 8,
                                        margin: const EdgeInsets.only(top: 6, right: 12),
                                        decoration: BoxDecoration(
                                          color: _getSeverityColor(activity.severity),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              activity.symptom,
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500,
                                                color: Colors.black87,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                Icon(Icons.calendar_today,
                                                    size: 12,
                                                    color: Colors.grey.shade600),
                                                const SizedBox(width: 4),
                                                Text(
                                                  activity.date,
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey.shade600,
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(
                                                      horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: _getSeverityColor(activity.severity)
                                                        .withOpacity(0.1),
                                                    borderRadius: BorderRadius.circular(4),
                                                    border: Border.all(
                                                      color: _getSeverityColor(activity.severity)
                                                          .withOpacity(0.3),
                                                    ),
                                                  ),
                                                  child: Text(
                                                    activity.severity,
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      color: _getSeverityColor(activity.severity),
                                                      fontWeight: FontWeight.w500,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                            ).toList(),
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
                          child: Text('ಲಕ್ಷಣವನ್ನು ವರದಿ ಮಾಡಿ',
                              style: TextStyle(fontSize: 16)),
                        ),
                        onPressed: _navigateToVoice,
                        style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00796B),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10))),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Voice helper card
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(Icons.chat,
                                size: 20,
                                color: Theme.of(context).primaryColor),
                            const SizedBox(width: 8),
                            Text('ಧ್ವನಿ ಸಹಾಯಕ',
                                style: Theme.of(context).textTheme.titleLarge),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text('ನಿಮ್ಮ ಆರೋಗ್ಯ ಪ್ರಶ್ನೆಗಳಿಗೆ ತಕ್ಷಣ ಉತ್ತರ ಪಡೆಯಿರಿ',
                            style: Theme.of(context).textTheme.bodyMedium),
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.all(10.0),
                          child: ElevatedButton(
                            child : Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  const Icon(Icons.mic),
                               const Text('ಪ್ರಶ್ನೆ ಕೇಳಿ'),
                                ],
                              ),
                            ),
                            onPressed: _navigateToVoice,
                            style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1976D2),
                                foregroundColor: Colors.white),
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

  // Helper method to get color based on severity
  Color _getSeverityColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'ಕಡಿಮೆ':
        return Colors.green;
      case 'ಸಾಮಾನ್ಯ':
        return Colors.blue;
      case 'ಹೆಚ್ಚಿನ':
        return Colors.orange;
      case 'ತೀವ್ರ':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}

class RecentSymptom {
  final String symptom;
  final String date;
  final String severity;

  RecentSymptom(
      {required this.symptom, required this.date, required this.severity});
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
  final trimester = (weeks < 13)
      ? 1
      : (weeks < 27)
      ? 2
      : 3;
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
    'ಜನವರಿ',
    'ಫೆಬ್ರವರಿ',
    'ಮಾರ್ಚ್',
    'ಎಪ್ರಿಲ್',
    'ಮೇ',
    'ಜೂನ್',
    'ಜುಲೈ',
    'ಆಗಸ್ಟ್',
    'ಸೆಪ್ಟೆಂಬರ್',
    'ಅಕ್ಟೋಬರ್',
    'ನವೆಂಬರ್',
    'ಡಿಸೆಂಬರ್'
  ];
  final day = due.day;
  final month = months[due.month - 1];
  final year = due.year;
  return '$day $month $year';
}