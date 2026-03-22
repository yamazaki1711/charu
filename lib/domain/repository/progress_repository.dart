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
}
