import '../model/progress_models.dart';

/// Repository interface for progress and statistics operations
abstract class IProgressRepository {
  /// Get today's statistics
  Future<DailyStats> getTodayStats();

  /// Update today's statistics
  Future<void> updateTodayStats(DailyStats stats);

  /// Get statistics for a date range
  Future<List<DailyStats>> getStatsForRange(DateTime start, DateTime end);

  /// Get current streak data
  Future<StreakData> getStreakData();

  /// Update streak (call when user completes a reading session)
  Future<void> updateStreak();

  /// Get saved vocabulary words
  Future<List<VocabularyWord>> getVocabulary({int limit = 20});

  /// Get progress summary
  Future<ProgressSummary> getProgressSummary();

  /// Increment words saved count for today
  Future<void> incrementWordsSaved(int count);

  /// Increment articles read count for today
  Future<void> incrementArticlesRead(int count);

  /// Add reading minutes for today
  Future<void> addReadingMinutes(int minutes);

  /// Wipes all saved vocabulary, daily stats and streak data back to a
  /// fresh-install state. Irreversible.
  Future<void> resetProgress();

  /// Returns the set of saved vocabulary words (just the `word` column, no
  /// limit) for fast "is this word already known?" lookups while reading.
  Future<Set<String>> getSavedWordsSet();

  /// Returns saved words due for spaced-repetition review, most overdue
  /// first (see [VocabularyWord] scheduling in the implementation).
  Future<List<VocabularyWord>> getWordsDueForReview({int limit = 20});

  /// Records a review outcome for a saved word: advances (or resets) its
  /// position in the review schedule and stamps `last_reviewed`.
  Future<void> markWordReviewed(int wordId, {required bool remembered});
}
