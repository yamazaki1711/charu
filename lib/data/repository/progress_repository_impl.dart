import '../../core/log.dart';
import 'package:sqflite/sqflite.dart';

import '../../domain/model/progress_models.dart';
import '../../domain/repository/progress_repository.dart';
import '../local/database_helper.dart';

/// Implementation of progress repository
class ProgressRepositoryImpl implements IProgressRepository {
  final DatabaseHelper _dbHelper;

  ProgressRepositoryImpl({DatabaseHelper? dbHelper})
    : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  @override
  Future<DailyStats> getTodayStats() async {
    try {
      final db = await _dbHelper.userDatabase;
      final today = _formatDate(DateTime.now());

      final List<Map<String, dynamic>> maps = await db.query(
        'daily_stats',
        where: 'date = ?',
        whereArgs: [today],
        limit: 1,
      );

      if (maps.isEmpty) {
        // Create today's stats if not exists
        await db.insert('daily_stats', {
          'date': today,
          'articles_read': 0,
          'words_encountered': 0,
          'words_saved': 0,
          'reading_minutes': 0,
        });

        return const DailyStats(date: '');
      }

      final m = maps.first;
      return DailyStats(
        date: m['date'] as String,
        articlesRead: m['articles_read'] as int? ?? 0,
        wordsEncountered: m['words_encountered'] as int? ?? 0,
        wordsSaved: m['words_saved'] as int? ?? 0,
        readingMinutes: m['reading_minutes'] as int? ?? 0,
      );
    } catch (e) {
      log('❌ Get today stats error: $e');
      return const DailyStats(date: '');
    }
  }

  @override
  Future<void> updateTodayStats(DailyStats stats) async {
    try {
      final db = await _dbHelper.userDatabase;
      final today = _formatDate(DateTime.now());

      await db.update(
        'daily_stats',
        {
          'articles_read': stats.articlesRead,
          'words_encountered': stats.wordsEncountered,
          'words_saved': stats.wordsSaved,
          'reading_minutes': stats.readingMinutes,
        },
        where: 'date = ?',
        whereArgs: [today],
      );
    } catch (e) {
      log('❌ Update today stats error: $e');
    }
  }

  @override
  Future<List<DailyStats>> getStatsForRange(
    DateTime start,
    DateTime end,
  ) async {
    try {
      final db = await _dbHelper.userDatabase;
      final startDate = _formatDate(start);
      final endDate = _formatDate(end);

      final List<Map<String, dynamic>> maps = await db.query(
        'daily_stats',
        where: 'date BETWEEN ? AND ?',
        whereArgs: [startDate, endDate],
        orderBy: 'date ASC',
      );

      return maps
          .map(
            (m) => DailyStats(
              date: m['date'] as String,
              articlesRead: m['articles_read'] as int? ?? 0,
              wordsEncountered: m['words_encountered'] as int? ?? 0,
              wordsSaved: m['words_saved'] as int? ?? 0,
              readingMinutes: m['reading_minutes'] as int? ?? 0,
            ),
          )
          .toList();
    } catch (e) {
      log('❌ Get stats for range error: $e');
      return [];
    }
  }

  @override
  Future<StreakData> getStreakData() async {
    try {
      final db = await _dbHelper.userDatabase;

      final List<Map<String, dynamic>> maps = await db.query(
        'streak_data',
        limit: 1,
      );

      if (maps.isEmpty) {
        return const StreakData(currentStreak: 0, maxStreak: 0);
      }

      final m = maps.first;
      final lastActiveDateStr = m['last_active_date'] as String?;

      return StreakData(
        currentStreak: m['current_streak'] as int? ?? 0,
        maxStreak: m['max_streak'] as int? ?? 0,
        lastActiveDate: lastActiveDateStr != null
            ? DateTime.parse(lastActiveDateStr)
            : null,
      );
    } catch (e) {
      log('❌ Get streak data error: $e');
      return const StreakData(currentStreak: 0, maxStreak: 0);
    }
  }

  @override
  Future<void> updateStreak() async {
    try {
      // Ensure the local row exists (update by id = 1 matches nothing
      // on a fresh install, silently breaking the streak).
      final db = await _dbHelper.userDatabase;
      final today = _formatDate(DateTime.now());
      final streakData = await getStreakData();

      int newStreak = streakData.currentStreak;
      int maxStreak = streakData.maxStreak;

      // Check if already active today
      if (streakData.lastActiveDate != null) {
        final lastDate = _formatDate(streakData.lastActiveDate!);
        if (lastDate == today) {
          // Already updated today
          return;
        }

        final yesterday = _formatDate(DateTime.now().subtract(const Duration(days: 1)));
        if (lastDate == yesterday) {
          // Continue streak
          newStreak++;
        } else {
          // Streak broken, reset
          newStreak = 1;
        }
      } else {
        // First activity
        newStreak = 1;
      }

      // Update max streak
      if (newStreak > maxStreak) {
        maxStreak = newStreak;
      }

      // Insert-or-update: the streak row may not exist on a fresh
      // install (updateStreak used to silently no-op in that case).
      await db.rawUpdate(
        '''
        INSERT INTO streak_data (id, current_streak, max_streak,
                                 last_active_date, updated_at)
        VALUES (1, ?, ?, ?, ?)
        ON CONFLICT(id) DO UPDATE SET
          current_streak = excluded.current_streak,
          max_streak = excluded.max_streak,
          last_active_date = excluded.last_active_date,
          updated_at = excluded.updated_at
        ''',
        [newStreak, maxStreak, today, DateTime.now().toIso8601String()],
      );
    } catch (e) {
      log('❌ Update streak error: $e');
    }
  }

  @override
  Future<List<VocabularyWord>> getVocabulary({int limit = 20}) async {
    try {
      final db = await _dbHelper.userDatabase;

      final List<Map<String, dynamic>> maps = await db.query(
        'user_vocabulary',
        orderBy: 'saved_date DESC',
        limit: limit,
      );

      return maps
          .map(
            (m) => VocabularyWord(
              id: m['id'] as int,
              word: m['word'] as String,
              pinyin: m['pinyin'] as String,
              translation: m['translation'] as String,
              sourceType: m['source_type'] as String,
              savedDate: DateTime.parse(m['saved_date'] as String),
              lastReviewed: m['last_reviewed'] != null
                  ? DateTime.parse(m['last_reviewed'] as String)
                  : null,
              reviewCount: m['review_count'] as int? ?? 0,
            ),
          )
          .toList();
    } catch (e) {
      log('❌ Get vocabulary error: $e');
      return [];
    }
  }

  @override
  Future<ProgressSummary> getProgressSummary() async {
    try {
      final db = await _dbHelper.userDatabase;

      // Get summary from view or aggregate queries
      final vocabCount = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) as count FROM user_vocabulary'),
      ) ?? 0;

      final articlesResult = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COALESCE(SUM(articles_read), 0) as total FROM daily_stats'),
      ) ?? 0;

      final minutesResult = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COALESCE(SUM(reading_minutes), 0) as total FROM daily_stats'),
      ) ?? 0;

      final streakData = await getStreakData();

      return ProgressSummary(
        totalWordsSaved: vocabCount,
        totalArticlesRead: articlesResult,
        totalReadingMinutes: minutesResult,
        currentStreak: streakData.currentStreak,
        maxStreak: streakData.maxStreak,
      );
    } catch (e) {
      log('❌ Get progress summary error: $e');
      return ProgressSummary(
        totalWordsSaved: 0,
        totalArticlesRead: 0,
        totalReadingMinutes: 0,
        currentStreak: 0,
        maxStreak: 0,
      );
    }
  }

  @override
  Future<void> incrementWordsSaved(int count) async {
    try {
      final db = await _dbHelper.userDatabase;
      final today = _formatDate(DateTime.now());

      await db.rawUpdate(
        '''
        INSERT INTO daily_stats (date, words_saved)
        VALUES (?, ?)
        ON CONFLICT(date) DO UPDATE SET words_saved = words_saved + ?
        ''',
        [today, count, count],
      );
    } catch (e) {
      log('❌ Increment words saved error: $e');
      // Propagate to the UI (dictionary popup shows a snackbar).
      rethrow;
    }
  }

  @override
  Future<void> incrementArticlesRead(int count) async {
    try {
      final db = await _dbHelper.userDatabase;
      final today = _formatDate(DateTime.now());

      await db.rawUpdate(
        '''
        INSERT INTO daily_stats (date, articles_read)
        VALUES (?, ?)
        ON CONFLICT(date) DO UPDATE SET articles_read = articles_read + ?
        ''',
        [today, count, count],
      );
    } catch (e) {
      log('❌ Increment articles read error: $e');
      // The progress screen's refresh rethrows as an AsyncError, so the
      // user sees the failure banner (task #5).
      rethrow;
    }
  }

  @override
  Future<void> addReadingMinutes(int minutes) async {
    try {
      final db = await _dbHelper.userDatabase;
      final today = _formatDate(DateTime.now());

      await db.rawUpdate(
        '''
        INSERT INTO daily_stats (date, reading_minutes)
        VALUES (?, ?)
        ON CONFLICT(date) DO UPDATE SET reading_minutes = reading_minutes + ?
        ''',
        [today, minutes, minutes],
      );
    } catch (e) {
      log('❌ Add reading minutes error: $e');
      // Rejected: rethrowing here would tear down the reader on every
      // background tick. Errors stay visible in the Progress screen via
      // progressSummaryProvider (task #5).
    }
  }

  @override
  Future<void> resetProgress() async {
    try {
      final db = await _dbHelper.userDatabase;
      await db.transaction((txn) async {
        await txn.delete('user_vocabulary');
        await txn.delete('daily_stats');
        await txn.rawUpdate(
          '''
          INSERT INTO streak_data (id, current_streak, max_streak, last_active_date, updated_at)
          VALUES (1, 0, 0, NULL, ?)
          ON CONFLICT(id) DO UPDATE SET
            current_streak = 0,
            max_streak = 0,
            last_active_date = NULL,
            updated_at = excluded.updated_at
          ''',
          [DateTime.now().toIso8601String()],
        );
      });
    } catch (e) {
      log('❌ Reset progress error: $e');
      rethrow;
    }
  }

  // Helper method to format date as YYYY-MM-DD
  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
