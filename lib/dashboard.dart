import 'package:flutter/material.dart';

class DashboardPage extends StatefulWidget {
  @override
  _DashboardPageState createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  bool isRecording = false;
  bool isPlaying = false;
  String responseText = '';

  void handleVoiceRecord() {
    if (isRecording) {
      // Stop recording
      setState(() {
        isRecording = false;
        isPlaying = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Processing your question...")),
      );

      // Simulate backend response
      Future.delayed(const Duration(seconds: 2), () {
        setState(() {
          isPlaying = false;
          responseText =
          "ನಿಮ್ಮ ಪ್ರಶ್ನೆಗೆ ಉತ್ತರ: ಗರ್ಭಾವಸ್ಥೆಯಲ್ಲಿ ಆರೋಗ್ಯಕರ ಆಹಾರ ಮತ್ತು ನಿಯಮಿತ ವೈದ್ಯಕೀಯ ಪರೀಕ್ಷೆಗಳು ಬಹಳ ಮುಖ್ಯ. ತಾಜಾ ಹಣ್ಣುಗಳು, ಹಸಿರು ತರಕಾರಿಗಳನ್ನು ಸೇವಿಸಿ.\n\nYour answer: During pregnancy, healthy diet and regular medical checkups are very important. Consume fresh fruits and green vegetables.";
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Audio response ready in Kannada")),
        );
      });
    } else {
      // Start recording
      setState(() {
        isRecording = true;
        responseText = '';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Recording started, tap again to stop")),
      );
    }
  }

  void handleProfileOpen() {
    Navigator.pushNamed(context, '/profile');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF48FB1), Color(0xFFE91E63)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(16, 48, 16, 32),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFE91E63), Color(0xFFF48FB1)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text("ನಮಸ್ಕಾರ ಅಮ್ಮ!",
                          style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white)),
                      SizedBox(height: 4),
                      Text("How can I help you today?",
                          style: TextStyle(
                              fontSize: 14, color: Colors.white70)),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.person, color: Colors.white, size: 28),
                    onPressed: handleProfileOpen,
                  ),
                ],
              ),
            ),

            // Status Indicator
            if (isRecording || isPlaying)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isRecording)
                        Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                      if (isRecording) const SizedBox(width: 6),
                      Icon(
                        isRecording
                            ? Icons.mic
                            : Icons.volume_up,
                        size: 16,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isRecording
                            ? "ಕೇಳುತ್ತಿದ್ದೇವೆ..."
                            : "ಉತ್ತರ ನೀಡುತ್ತಿದ್ದೇವೆ...",
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),

            // Main Content
            Expanded(
              child: Container(
                transform: Matrix4.translationValues(0, -20, 0),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(height: 16),

                      // Voice Assistant Card
                      Card(
                        elevation: 6,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              Text(
                                "Ask Your Health Question",
                                style: TextStyle(
                                    color: Colors.pink[400],
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16),
                              ),
                              const SizedBox(height: 20),
                              GestureDetector(
                                onTap: handleVoiceRecord,
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  width: 100,
                                  height: 100,
                                  decoration: BoxDecoration(
                                    color: isRecording
                                        ? Colors.red[400]
                                        : Colors.pink[400],
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    isRecording
                                        ? Icons.mic_off
                                        : isPlaying
                                        ? Icons.volume_up
                                        : Icons.mic,
                                    size: 48,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                isRecording
                                    ? "ಕೇಳುತ್ತಿದ್ದೇವೆ..."
                                    : isPlaying
                                    ? "ಉತ್ತರ ನೀಡುತ್ತಿದ್ದೇವೆ..."
                                    : "ಕನ್ನಡದಲ್ಲಿ ಪ್ರಶ್ನೆ ಕೇಳಿ",
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.black54),
                              ),
                              const SizedBox(height: 16),

                              // Response Text Display
                              if (responseText.isNotEmpty)
                                Card(
                                  color: Colors.pink[50],
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Row(
                                      crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                      children: [
                                        Icon(Icons.volume_up,
                                            color: Colors.pink[400], size: 20),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            responseText,
                                            style: const TextStyle(
                                                fontSize: 14,
                                                height: 1.4,
                                                color: Colors.black87),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Quick Tips
                      Card(
                        elevation: 6,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text("💡 ಮಾರ್ಗದರ್ಶನ",
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16)),
                              SizedBox(height: 12),
                              TipRow(
                                  icon: Icons.mic,
                                  text:
                                  "ಗರ್ಭಾವಸ್ಥೆ, ಪೋಷಣೆ, ಮಗುವಿನ ಆರೈಕೆ ಬಗ್ಗೆ ಕನ್ನಡದಲ್ಲಿ ಕೇಳಿ"),
                              TipRow(
                                  icon: Icons.volume_up,
                                  text:
                                  "ಪ್ರಶ್ನೆಗಳಿಗೆ ಧ್ವನಿ ಮತ್ತು ಪಠ್ಯ ಎರಡರಲ್ಲೂ ಉತ್ತರ ಪಡೆಯಿರಿ"),
                              TipRow(
                                  icon: Icons.favorite,
                                  text:
                                  "ತಜ್ಞರ ಸಲಹೆ ಮತ್ತು ವೈಯಕ್ತಿಕ ಆರೋಗ್ಯ ಮಾಹಿತಿ ಪಡೆಯಿರಿ"),
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
    );
  }
}

// Reusable widget for tips
class TipRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const TipRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.pink[400]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13, color: Colors.black54),
            ),
          ),
        ],
      ),
    );
  }
}
