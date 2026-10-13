import 'package:flutter/foundation.dart';

import '../../domain/model/news_models.dart';
import '../../domain/repository/news_repository.dart';
import '../remote/news_api_service.dart';
import 'news_sources_repository.dart';

class NewsRepositoryImpl implements INewsRepository {
  final NewsApiService _apiService;
  List<NewsArticle>? _cachedArticles;

  NewsRepositoryImpl({NewsApiService? apiService})
      : _apiService = apiService ?? NewsApiService();

  /// Инициализация источников из news_sources (через
  /// [NewsSourcesRepository]) — RSS-источники передаются в API-сервис.
  /// На web-платформе и при ошибках DB остаётся дефолтный набор сервиса.
  Future<void> configureSources(NewsSourcesRepository sourcesRepository) async {
    try {
      final enabled = await sourcesRepository.getEnabledSources();
      if (enabled.isEmpty) return;
      _apiService.configureSources(
        enabled
            .where((s) => s.type == 'rss')
            .map((s) => {'name': s.name, 'url': s.url})
            .toList(),
      );
    } catch (_) {
      // DB недоступен (например, web) — используем дефолтные источники.
    }
  }

  @override
  Future<List<NewsArticle>> getLatestNews() async {
    // Гарантия: источники из news_sources применяются ДО первого fetch
    // (не полагаемся на то, что внешний init уже отработал).
    await configureSources(NewsSourcesRepository());
    try {
      final articles = await _apiService.fetchLatestNews();
      if (articles.isNotEmpty) {
        _cachedArticles = articles;
        return articles;
      }
    } catch (e) {
      debugPrint('[News] All sources failed: $e');
    }

    // Честный офлайн: последние успешно загруженные новости (кеш),
    // либо пустой список — никаких фейковых мок-статей.
    return _cachedArticles ?? <NewsArticle>[];
  }

  @override
  Future<NewsArticle> fetchArticleContent(String url) async {
    // Try to find in cache first
    if (_cachedArticles != null) {
      final cached = _cachedArticles!.where((a) => a.url == url).firstOrNull;
      if (cached != null) {
        return await _fetchAndUpdateArticle(cached);
      }
    }
    
    // Create article from URL
    final article = NewsArticle(
      id: url,
      title: 'Загрузка...',
      source: '',
      publishedAt: DateTime.now(),
      url: url,
    );
    
    return await _fetchAndUpdateArticle(article);
  }

  Future<NewsArticle> _fetchAndUpdateArticle(NewsArticle article) async {
    final result = await _apiService.fetchArticleContent(article);
    return result ?? article;
  }

}
