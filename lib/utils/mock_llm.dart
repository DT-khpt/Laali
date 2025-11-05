// lib/utils/mock_llm.dart
//
// A very small mock of a language model responder used for development and UI
// testing. This mimics generating a short answer based on a prompt.
//
// The implementation is intentionally simple and synchronous. Replace with a
// real API call (OpenAI, PaLM, etc.) in production.

class MockLLM {
  /// Return a canned response for the given [prompt].
  ///
  /// A few heuristics are used to make responses slightly dynamic during UI
  /// testing.
  Future<String> generate(String prompt) async {
    // Small artificial delay to simulate network latency
    await Future.delayed(const Duration(milliseconds: 200));

    final lower = prompt.toLowerCase();
    if (lower.contains('hello') || lower.contains('hi')) {
      return 'Hi! How can I help with pregnancy tracking today?';
    }
    if (lower.contains('age') || lower.contains('gestation')) {
      return 'Based on the info you provided, gestational age is approximately 12 weeks 3 days.';
    }
    if (lower.contains('kannada')) {
      return 'ನಮಸ್ಕಾರ — ನಾನು ನಿಮ್ಮ ಸಹಾಯಕ್ಕೆ ಸಿದ್ಧನಿದ್ದೇನೆ.'; // Kannada sample
    }

    // default echo style response
    return 'Mock response: I received your prompt: "${_truncate(prompt, 120)}"';
  }

  String _truncate(String s, int max) => s.length <= max ? s : '${s.substring(0, max)}...';
}

// Provide a top-level singleton factory for convenience in small apps/tests.
MockLLM mockLLM() => MockLLM();
