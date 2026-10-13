import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repository/news_sources_repository.dart';
import '../../domain/model/news_models.dart';
import '../../di/di.dart';

/// Notifier that holds the state of the News Feed.
///
/// Uses [AsyncNotifier] (Riverpod 2.x) instead of the deprecated
/// [StateNotifier<AsyncValue<T>>] pattern.
class NewsFeedNotifier extends AsyncNotifier<List<NewsArticle>> {
  @override
  Future<List<NewsArticle>> build() async {
    // Ensure news sources are loaded before fetching the feed.
    await ref.read(newsSourcesProvider.notifier).load();
    return _fetch();
  }

  Future<List<NewsArticle>> _fetch() {
    final useCase = ref.read(getLatestNewsUseCaseProvider);
    return useCase.call();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_fetch);
  }
}

/// Provider for the list of News Articles.
final newsFeedProvider =
    AsyncNotifierProvider<NewsFeedNotifier, List<NewsArticle>>(
      NewsFeedNotifier.new,
    );

/// FutureProvider for a specific article's full content.
final articleContentProvider =
    FutureProvider.family<NewsArticle, String>((ref, articleId) async {
  final useCase = ref.read(fetchArticleContentUseCaseProvider);
  return useCase.call(articleId);
});
