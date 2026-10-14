import '../model/progress_models.dart';
import '../repository/progress_repository.dart';

/// Use case for getting progress summary
class GetProgressSummaryUseCase {
  final IProgressRepository _repository;

  GetProgressSummaryUseCase(this._repository);

  Future<ProgressSummary> call() async {
    return await _repository.getProgressSummary();
  }
}

/// Use case for getting today's stats
class GetTodayStatsUseCase {
  final IProgressRepository _repository;

  GetTodayStatsUseCase(this._repository);

  Future<DailyStats> call() async {
    return await _repository.getTodayStats();
  }
}

/// Use case for getting streak data
class GetStreakDataUseCase {
  final IProgressRepository _repository;

  GetStreakDataUseCase(this._repository);

  Future<StreakData> call() async {
    return await _repository.getStreakData();
  }
}

/// Use case for updating streak (call after reading session)
class UpdateStreakUseCase {
  final IProgressRepository _repository;

  UpdateStreakUseCase(this._repository);

  Future<void> call() async {
    await _repository.updateStreak();
  }
}

/// Use case for getting vocabulary words
class GetVocabularyUseCase {
  final IProgressRepository _repository;
  final int limit;

  GetVocabularyUseCase(this._repository, {this.limit = 20});

  Future<List<VocabularyWord>> call() async {
    return await _repository.getVocabulary(limit: limit);
  }
}

/// Use case for getting stats for a date range (for charts)
class GetStatsForRangeUseCase {
  final IProgressRepository _repository;

  GetStatsForRangeUseCase(this._repository);

  Future<List<DailyStats>> call(DateTime start, DateTime end) async {
    return await _repository.getStatsForRange(start, end);
  }
}

/// Use case for incrementing the saved-words counter (call after saveWord)
class IncrementWordsSavedUseCase {
  final IProgressRepository _repository;

  IncrementWordsSavedUseCase(this._repository);

  Future<void> call({int count = 1}) async {
    await _repository.incrementWordsSaved(count);
  }
}

/// Use case for incrementing the articles-read counter (call on article open)
class IncrementArticlesReadUseCase {
  final IProgressRepository _repository;

  IncrementArticlesReadUseCase(this._repository);

  Future<void> call({int count = 1}) async {
    await _repository.incrementArticlesRead(count);
  }
}

/// Use case for adding reading minutes (call after a reading session)
class AddReadingMinutesUseCase {
  final IProgressRepository _repository;

  AddReadingMinutesUseCase(this._repository);

  Future<void> call({int minutes = 1}) async {
    await _repository.addReadingMinutes(minutes);
  }
}

/// Use case for wiping all vocabulary/stats/streak data (Settings screen).
class ResetProgressUseCase {
  final IProgressRepository _repository;

  ResetProgressUseCase(this._repository);

  Future<void> call() async {
    await _repository.resetProgress();
  }
}

/// Use case for the set of saved words (reader "known word" highlighting).
class GetSavedWordsSetUseCase {
  final IProgressRepository _repository;

  GetSavedWordsSetUseCase(this._repository);

  Future<Set<String>> call() async {
    return await _repository.getSavedWordsSet();
  }
}

/// Use case for fetching words due for spaced-repetition review.
class GetWordsDueForReviewUseCase {
  final IProgressRepository _repository;

  GetWordsDueForReviewUseCase(this._repository);

  Future<List<VocabularyWord>> call({int limit = 20}) async {
    return await _repository.getWordsDueForReview(limit: limit);
  }
}

/// Use case for recording a spaced-repetition review outcome.
class MarkWordReviewedUseCase {
  final IProgressRepository _repository;

  MarkWordReviewedUseCase(this._repository);

  Future<void> call(int wordId, {required bool remembered}) async {
    await _repository.markWordReviewed(wordId, remembered: remembered);
  }
}
