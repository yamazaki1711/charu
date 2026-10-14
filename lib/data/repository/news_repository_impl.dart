import '../../core/log.dart';

import '../../domain/model/news_models.dart';
import '../../domain/repository/news_repository.dart';
import '../remote/news_api_service.dart';
import 'news_sources_repository.dart';

class NewsRepositoryImpl implements INewsRepository {
  final NewsApiService _apiService;
  final NewsSourcesRepository _sourcesRepository;
  List<NewsArticle>? _cachedArticles;

  /// [sourcesRepository] must be the same instance the Settings screen
  /// toggles (the Riverpod singleton) — a fresh `NewsSourcesRepository()`
  /// here would always see the untouched default `enabled` column from the
  /// read-only asset DB, silently ignoring every user toggle.
  NewsRepositoryImpl({
    NewsApiService? apiService,
    NewsSourcesRepository? sourcesRepository,
  })  : _apiService = apiService ?? NewsApiService(),
        _sourcesRepository = sourcesRepository ?? NewsSourcesRepository();

  /// Применяет текущее состояние источников из [_sourcesRepository] к
  /// API-сервису. Вызывается перед каждым fetch, чтобы отражать тумблеры
  /// из Настроек, переключённые после создания репозитория.
  Future<void> _applySourceConfig() async {
    try {
      final enabled = await _sourcesRepository.getEnabledSources();
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
  Map<String, String> get sourceErrors => _apiService.lastSourceErrors;

  @override
  Future<List<NewsArticle>> getLatestNews() async {
    await _applySourceConfig();
    try {
      final articles = await _apiService.fetchLatestNews();
      if (articles.isNotEmpty) {
        _cachedArticles = articles;
        return articles;
      }
    } catch (e) {
      log('[News] All sources failed: $e');
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
