import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/local/database_helper.dart';
import '../data/repository/dictionary_repository_impl.dart';
import '../domain/repository/dictionary_repository.dart';
import '../domain/usecase/lookup_word_usecase.dart';

/// Database Helper provider (singleton).
final databaseHelperProvider = Provider<DatabaseHelper>((ref) {
  return DatabaseHelper.instance;
});

/// Dictionary Repository provider.
///
/// Implements IDictionaryRepository to decouple the presentation from data.
final dictionaryRepositoryProvider = Provider<IDictionaryRepository>((ref) {
  final dbHelper = ref.watch(databaseHelperProvider);
  return DictionaryRepositoryImpl(dbHelper: dbHelper);
});

/// UseCase provider for word lookups via the 5-layer cascade.
final lookupWordUseCaseProvider = Provider<LookupWordUseCase>((ref) {
  final repo = ref.watch(dictionaryRepositoryProvider);
  return LookupWordUseCase(repo);
});
