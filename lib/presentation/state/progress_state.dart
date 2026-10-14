import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/model/progress_models.dart';
import '../../di/di.dart';

final progressSummaryProvider = FutureProvider.autoDispose<ProgressSummary>((ref) {
  return ref.read(getProgressSummaryUseCaseProvider).call();
});

final vocabularyProvider = FutureProvider.autoDispose<List<VocabularyWord>>((ref) {
  return ref.read(getVocabularyUseCaseProvider).call();
});

/// Set of already-saved words, for "known word" highlighting in the reader.
final savedWordsSetProvider = FutureProvider.autoDispose<Set<String>>((ref) {
  return ref.read(getSavedWordsSetUseCaseProvider).call();
});

/// Words due for spaced-repetition review.
final dueWordsProvider = FutureProvider.autoDispose<List<VocabularyWord>>((ref) {
  return ref.read(getWordsDueForReviewUseCaseProvider).call();
});

/// Last ~10 weeks of daily stats, for the activity heatmap.
final activityHeatmapProvider =
    FutureProvider.autoDispose<List<DailyStats>>((ref) {
  final end = DateTime.now();
  final start = end.subtract(const Duration(days: 69));
  return ref.read(getStatsForRangeUseCaseProvider).call(start, end);
});
