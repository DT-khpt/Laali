// lib/data/models/video_record.dart
class VideoRecord {
  final String id;
  final List<double> embedding;
  final String videoUrl;
  final String title;
  final String? description; 

  VideoRecord({
    required this.id,
    required this.embedding,
    required this.videoUrl,
    required this.title,
    this.description,
  });

  factory VideoRecord.fromJson(Map<String, dynamic> json) {
    final embDyn = json['embedding'] as List<dynamic>;
    final emb = embDyn.map((e) => (e as num).toDouble()).toList();
    return VideoRecord(
      id: json['id'] ?? '',
      embedding: emb,
      videoUrl: json['video_url'] ?? json['url'] ?? '',
      title: json['title'] ?? '',
      description: json['description'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'embedding': embedding,
      'video_url': videoUrl,
      'title': title,
      'description': description,
    };
  }
}