// test/ai_service_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:mcp/services/ai_service.dart';

void main() {
  group('AIService JSON KB search', () {
    final ai = AIService(); // no API key -> uses local KB

    test('finds first trimester nutrition', () async {
      final resp = await ai.getResponse('ಗರ್ಭಾವಸ್ಥೆಯ ಮೊದಲ ತಿಂಗಳ ಆಹಾರ ಏನು?', 'pregnancy');
      expect(resp.toLowerCase(), contains('ಫೋಲಿಕ್')); // Kannada term in content
    });

    test('finds newborn vaccination', () async {
      final resp = await ai.getResponse('ಶಿಶುವಿಗೆ ಯಾವ ಟೀಕೆಗಳು ಬೇಕು?', 'newborn');
      expect(resp.toLowerCase(), contains('ಟೀಕೆ'));
    });

    test('non-crashing for odd query', () async {
      final resp = await ai.getResponse('ಮರಿ ಚಾಮಟೆ ನಿದ್ರೆ ಬಗ್ಗೆ ತಿಳಿಸಿ', 'sleep');
      // Ensure we return some string (KB or fallback)
      expect(resp, isNotNull);
      expect(resp, isNotEmpty);
    });
  });
}
