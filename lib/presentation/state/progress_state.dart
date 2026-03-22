import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/model/progress_models.dart';
import '../../di/di.dart';

final progressSummaryProvider = FutureProvider.autoDispose<ProgressSummary>((ref) {
  return ref.read(getProgressSummaryUseCaseProvider).call();
});

final vocabularyProvider = FutureProvider.autoDispose<List<VocabularyWord>>((ref) {
  return ref.read(getVocabularyUseCaseProvider).call();
});
