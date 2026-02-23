import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/model/news_models.dart';
import '../../di/di.dart';

/// Notifier to hold the state of the News Feed
class NewsFeedNotifier extends StateNotifier<AsyncValue<List<NewsArticle>>> {
  NewsFeedNotifier(this.ref) : super(const AsyncValue.loading()) {
    refresh();
  }

  final Ref ref;

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    try {
      final useCase = ref.read(getLatestNewsUseCaseProvider);
      final news = await useCase.call();
      state = AsyncValue.data(news);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

/// Provider for the list of News Articles
final newsFeedProvider = StateNotifierProvider<NewsFeedNotifier, AsyncValue<List<NewsArticle>>>((ref) {
  return NewsFeedNotifier(ref);
});

/// FutureProvider for a specific article's content
final articleContentProvider = FutureProvider.family<NewsArticle, String>((ref, url) async {
  final useCase = ref.read(fetchArticleContentUseCaseProvider);
  return await useCase.call(url);
});
