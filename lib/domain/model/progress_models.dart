/// Domain model for daily reading statistics
class DailyStats {
  final String date; // YYYY-MM-DD format
  final int articlesRead;
  final int wordsEncountered;
  final int wordsSaved;
  final int readingMinutes;

  const DailyStats({
    required this.date,
    this.articlesRead = 0,
    this.wordsEncountered = 0,
    this.wordsSaved = 0,
    this.readingMinutes = 0,
  });

  DailyStats copyWith({
    int? articlesRead,
    int? wordsEncountered,
    int? wordsSaved,
    int? readingMinutes,
  }) {
    return DailyStats(
      date: date,
      articlesRead: articlesRead ?? this.articlesRead,
      wordsEncountered: wordsEncountered ?? this.wordsEncountered,
      wordsSaved: wordsSaved ?? this.wordsSaved,
      readingMinutes: readingMinutes ?? this.readingMinutes,
    );
  }

  int get totalWords => wordsEncountered + wordsSaved;
}

/// Domain model for user streak data
class StreakData {
  final int currentStreak;
  final int maxStreak;
  final DateTime? lastActiveDate;

  const StreakData({
    required this.currentStreak,
    required this.maxStreak,
    this.lastActiveDate,
  });

  bool get isActive => currentStreak > 0;
  
  /// Check if streak is still active (last activity was today or yesterday)
  bool get isStreakAlive {
    if (lastActiveDate == null) return false;
    final now = DateTime.now();
    final diff = now.difference(lastActiveDate!);
    return diff.inDays <= 1;
  }
}

/// Domain model for user vocabulary word
class VocabularyWord {
  final int id;
  final String word;
  final String pinyin;
  final String translation;
  final String sourceType;
  final DateTime savedDate;
  final DateTime? lastReviewed;
  final int reviewCount;

  const VocabularyWord({
    required this.id,
    required this.word,
    required this.pinyin,
    required this.translation,
    required this.sourceType,
    required this.savedDate,
    this.lastReviewed,
    this.reviewCount = 0,
  });
}

/// Summary of user progress
class ProgressSummary {
  final int totalWordsSaved;
  final int totalArticlesRead;
  final int totalReadingMinutes;
  final int currentStreak;
  final int maxStreak;

  const ProgressSummary({
    required this.totalWordsSaved,
    required this.totalArticlesRead,
    required this.totalReadingMinutes,
    required this.currentStreak,
    required this.maxStreak,
  });
}
