// lib/data/video_database.dart
class VideoDatabase {
  static final Map<String, Map<String, String>> _videoMap = {
    // Pregnancy related
    'how_to_make_baby_stop_crying': {
      'video': 'https://www.youtube.com/watch?v=example1',
      'title': 'ಶಿಶು ಅಳುವುದನ್ನು ನಿಲ್ಲಿಸುವ ವಿಧಾನ'
    },
    'what_to_eat_during_pregnancy': {
      'video': 'https://www.youtube.com/watch?v=example2',
      'title': 'ಗರ್ಭಧಾರಣೆಯಲ್ಲಿ ಪೋಷಕ ಆಹಾರ'
    },
    'pregnancy_exercise': {
      'video': 'https://www.youtube.com/watch?v=example3',
      'title': 'ಗರ್ಭಿಣಿಯರ ವ್ಯಾಯಾಮ'
    },
    'baby_care_tips': {
      'video': 'https://www.youtube.com/watch?v=example4',
      'title': 'ಶಿಶು ಪಾಲನೆ ತಂತ್ರಗಳು'
    },
    'breastfeeding_techniques': {
      'video': 'https://www.youtube.com/watch?v=example5',
      'title': 'ಸ್ತನಪಾನ ತಂತ್ರಗಳು'
    },

    // Symptoms related
    'fever_during_pregnancy': {
      'video': 'https://www.youtube.com/watch?v=example6',
      'title': 'ಗರ್ಭಧಾರಣೆಯಲ್ಲಿ ಜ್ವರ'
    },
    'headache_treatment': {
      'video': 'https://www.youtube.com/watch?v=example7',
      'title': 'ತಲೆನೋವು ಚಿಕಿತ್ಸೆ'
    },
    'morning_sickness': {
      'video': 'https://www.youtube.com/watch?v=example8',
      'title': 'ಬೆಳಗಿನ ಅಸ್ವಸ್ಥತೆ'
    },
    'back_pain_relief': {
      'video': 'https://www.youtube.com/watch?v=example9',
      'title': 'ಬೆನ್ನೆಲುಬು ನೋವು ಉಪಶಮನ'
    },

    // General health
    'nutrition_guide': {
      'video': 'https://www.youtube.com/watch?v=example10',
      'title': 'ಪೋಷಕಾಂಶ ಮಾರ್ಗದರ್ಶಿ'
    },
    'yoga_for_pregnancy': {
      'video': 'https://www.youtube.com/watch?v=example11',
      'title': 'ಗರ್ಭಿಣಿಯರಿಗೆ ಯೋಗ'
    }
  };

  static Map<String, String>? findVideo(String userMessage) {
    final message = userMessage.toLowerCase();

    // Keyword matching
    final keywordMap = {
      'cry': 'how_to_make_baby_stop_crying',
      'crying': 'how_to_make_baby_stop_crying',
      'baby cry': 'how_to_make_baby_stop_crying',
      'eat': 'what_to_eat_during_pregnancy',
      'food': 'what_to_eat_during_pregnancy',
      'nutrition': 'nutrition_guide',
      'diet': 'what_to_eat_during_pregnancy',
      'exercise': 'pregnancy_exercise',
      'yoga': 'yoga_for_pregnancy',
      'care': 'baby_care_tips',
      'breastfeed': 'breastfeeding_techniques',
      'milk': 'breastfeeding_techniques',
      'fever': 'fever_during_pregnancy',
      'headache': 'headache_treatment',
      'morning sickness': 'morning_sickness',
      'nausea': 'morning_sickness',
      'back pain': 'back_pain_relief',
      'backache': 'back_pain_relief'
    };

    for (final entry in keywordMap.entries) {
      if (message.contains(entry.key)) {
        return _videoMap[entry.value];
      }
    }

    return null;
  }

  static List<Map<String, String>> getAllVideos() {
    return _videoMap.entries.map((entry) => {
      'id': entry.key,
      'video': entry.value['video']!,
      'title': entry.value['title']!,
    }).toList();
  }
}