/// Domain model representing a word lookup result based on the 5-layer cascade.
class DictionaryResult {
  final String chineseWord;
  final String pinyin;
  final String? translation;
  final String source; // 'bkrs', 'toponym', 'person', 'online', 'fallback'
  final String? icon; // '🗺️', '👤', '🌐', '❓' or null
  final Map<String, dynamic>? metadata;

  const DictionaryResult({
    required this.chineseWord,
    required this.pinyin,
    this.translation,
    required this.source,
    this.icon,
    this.metadata,
  });

  bool get isFallback => source == 'fallback';
}

/// Raw word entry from the local BKRS database.
class WordEntry {
  final int id;
  final String simplified;
  final String? traditional;
  final String pinyin;
  final String translation;
  final String? examples;

  WordEntry({
    required this.id,
    required this.simplified,
    this.traditional,
    required this.pinyin,
    required this.translation,
    this.examples,
  });
}

/// Raw toponym geographic entry.
class ToponymEntry {
  final int id;
  final String chinese;
  final String pinyin;
  final String english;
  final String type;
  final double? latitude;
  final double? longitude;

  ToponymEntry({
    required this.id,
    required this.chinese,
    required this.pinyin,
    required this.english,
    required this.type,
    this.latitude,
    this.longitude,
  });
}

/// Raw personal name entry.
class PersonNameEntry {
  final int id;
  final String chinese;
  final String pinyin;
  final bool isSurname;
  final String? gender;

  PersonNameEntry({
    required this.id,
    required this.chinese,
    required this.pinyin,
    required this.isSurname,
    this.gender,
  });
}
