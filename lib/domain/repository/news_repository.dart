import '../model/news_models.dart';

/// Repository interface for fetching and reading news
abstract class INewsRepository {
  /// Fetches the latest news feed from the configured RSS sources
  Future<List<NewsArticle>> getLatestNews();

  /// Fetches the full text content of a specific article
  Future<NewsArticle> fetchArticleContent(String url);

  /// Последние ошибки источников (имя → текст ошибки) — для диагностики
  /// на пустой ленте.
  Map<String, String> get sourceErrors;
}
