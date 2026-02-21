// lib/utils/embedding_utils.dart
import 'dart:math';

class EmbeddingUtils {
  static double cosineSimilarity(List<double> a, List<double> b) {
    if (a.length != b.length) {
      throw ArgumentError('Vectors must be same length: ${a.length} != ${b.length}');
    }

    double dot = 0.0;
    double normA = 0.0;
    double normB = 0.0;

    for (int i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }

    final denominator = sqrt(normA) * sqrt(normB);
    return denominator == 0.0 ? 0.0 : dot / denominator;
  }

  static List<double> normalizeVector(List<double> vector) {
    final norm = sqrt(vector.map((x) => x * x).reduce((a, b) => a + b));
    if (norm == 0.0) return vector;
    return vector.map((x) => x / norm).toList();
  }
}

