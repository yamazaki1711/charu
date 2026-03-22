import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/local/database_helper.dart';
import '../data/remote/online_dictionary_service.dart';
import '../data/repository/dictionary_repository_impl.dart';
import '../data/repository/file_repository_impl.dart';
import '../data/repository/progress_repository_impl.dart';
import '../domain/repository/dictionary_repository.dart';
import '../domain/repository/file_repository.dart';
import '../domain/repository/progress_repository.dart';
import '../domain/usecase/lookup_word_usecase.dart';
import '../domain/usecase/save_word_usecase.dart';
import '../domain/usecase/file_usecases.dart';
import '../domain/usecase/progress_usecases.dart';
import '../domain/repository/news_repository.dart';
import '../data/repository/news_repository_impl.dart';
import '../domain/usecase/news_usecases.dart';

/// Database Helper provider (singleton).
final databaseHelperProvider = Provider<DatabaseHelper>((ref) {
  return DatabaseHelper.instance;
});

/// Online Dictionary Service provider.
final onlineDictionaryServiceProvider = Provider<OnlineDictionaryService>((ref) {
  return OnlineDictionaryService();
});

/// Dictionary Repository provider.
///
/// Implements IDictionaryRepository to decouple the presentation from data.
final dictionaryRepositoryProvider = Provider<IDictionaryRepository>((ref) {
  final dbHelper = ref.watch(databaseHelperProvider);
  final onlineService = ref.watch(onlineDictionaryServiceProvider);
  return DictionaryRepositoryImpl(
    dbHelper: dbHelper,
    onlineService: onlineService,
  );
});

/// UseCase provider for word lookups via the 5-layer cascade.
final lookupWordUseCaseProvider = Provider<LookupWordUseCase>((ref) {
  final repo = ref.watch(dictionaryRepositoryProvider);
  return LookupWordUseCase(repo);
});

/// UseCase provider for saving words to vocabulary.
final saveWordUseCaseProvider = Provider<SaveWordUseCase>((ref) {
  final repo = ref.watch(dictionaryRepositoryProvider);
  return SaveWordUseCase(repo);
});

// -----------------------------------------------------------------------------
// NEWS MODULE
// -----------------------------------------------------------------------------

final newsRepositoryProvider = Provider<INewsRepository>((ref) {
  return NewsRepositoryImpl();
});

final getLatestNewsUseCaseProvider = Provider<GetLatestNewsUseCase>((ref) {
  return GetLatestNewsUseCase(ref.watch(newsRepositoryProvider));
});

final fetchArticleContentUseCaseProvider = Provider<FetchArticleContentUseCase>(
  (ref) {
    return FetchArticleContentUseCase(ref.watch(newsRepositoryProvider));
  },
);

// -----------------------------------------------------------------------------
// FILES MODULE
// -----------------------------------------------------------------------------

/// File Repository provider.
final fileRepositoryProvider = Provider<IFileRepository>((ref) {
  final dbHelper = ref.watch(databaseHelperProvider);
  return FileRepositoryImpl(dbHelper: dbHelper);
});

/// UseCase provider for opening files.
final openFileUseCaseProvider = Provider<OpenFileUseCase>((ref) {
  return OpenFileUseCase(ref.watch(fileRepositoryProvider));
});

/// UseCase provider for reading file content.
final readFileContentUseCaseProvider = Provider<ReadFileContentUseCase>((ref) {
  return ReadFileContentUseCase(ref.watch(fileRepositoryProvider));
});

/// UseCase provider for getting recent files.
final getRecentFilesUseCaseProvider = Provider<GetRecentFilesUseCase>((ref) {
  return GetRecentFilesUseCase(ref.watch(fileRepositoryProvider));
});

/// UseCase provider for saving reading position.
final saveReadingPositionUseCaseProvider = Provider<SaveReadingPositionUseCase>(
  (ref) {
    return SaveReadingPositionUseCase(ref.watch(fileRepositoryProvider));
  },
);

// -----------------------------------------------------------------------------
// PROGRESS MODULE
// -----------------------------------------------------------------------------

/// Progress Repository provider.
final progressRepositoryProvider = Provider<IProgressRepository>((ref) {
  final dbHelper = ref.watch(databaseHelperProvider);
  return ProgressRepositoryImpl(dbHelper: dbHelper);
});

/// UseCase provider for getting progress summary.
final getProgressSummaryUseCaseProvider = Provider<GetProgressSummaryUseCase>(
  (ref) {
    return GetProgressSummaryUseCase(ref.watch(progressRepositoryProvider));
  },
);

/// UseCase provider for getting today's stats.
final getTodayStatsUseCaseProvider = Provider<GetTodayStatsUseCase>((ref) {
  return GetTodayStatsUseCase(ref.watch(progressRepositoryProvider));
});

/// UseCase provider for getting streak data.
final getStreakDataUseCaseProvider = Provider<GetStreakDataUseCase>((ref) {
  return GetStreakDataUseCase(ref.watch(progressRepositoryProvider));
});

/// UseCase provider for updating streak.
final updateStreakUseCaseProvider = Provider<UpdateStreakUseCase>((ref) {
  return UpdateStreakUseCase(ref.watch(progressRepositoryProvider));
});

/// UseCase provider for getting vocabulary.
final getVocabularyUseCaseProvider = Provider<GetVocabularyUseCase>((ref) {
  return GetVocabularyUseCase(ref.watch(progressRepositoryProvider));
});

/// UseCase provider for getting stats for a date range.
final getStatsForRangeUseCaseProvider = Provider<GetStatsForRangeUseCase>((ref) {
  return GetStatsForRangeUseCase(ref.watch(progressRepositoryProvider));
});
