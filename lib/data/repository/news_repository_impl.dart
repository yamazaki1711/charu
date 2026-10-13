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
    try {
      final articles = await _apiService.fetchLatestNews();
      if (articles.isNotEmpty) {
        _cachedArticles = articles;
        return articles;
      }
    } catch (e) {
      // Fall through to mock data
    }
    
    // Fallback to mock data if API fails
    return _mockArticles;
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
    
    // Find in mock data
    final mockArticle = _mockArticles.where((a) => a.id == url).firstOrNull;
    if (mockArticle != null) {
      return mockArticle;
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

  static final List<NewsArticle> _mockArticles = [
    NewsArticle(
      id: 'mock_weather',
      title: '北京天气晴朗，适合户外活动',
      source: '天气新闻',
      publishedAt: DateTime.now(),
      summary: '北京市气象局发布最新预报，今天白天晴间多云...',
      url: 'mock_weather',
      fullContent: '北京，中华人民共和国的首都。气象学专家建议市民在好天气多参加户外锻炼，但也要注意防晒，因为紫外线指数偏高。王明（Wang Ming）教授指出，今年的气候与往年相比，略有波动。',
    ),
    NewsArticle(
      id: 'mock_space',
      title: '中国嫦娥六号探测器成功返回地球',
      source: '航天新闻',
      publishedAt: DateTime.now().subtract(const Duration(hours: 2)),
      summary: '历史性的一刻！携带月球背面样本的嫦娥六号返回器...',
      url: 'mock_space',
      fullContent: '嫦娥六号（Chang\'e-6）是中国国家航天局进行的一项月球探测任务。此次任务的目标是从月球背面采集土壤和岩石样本，并将其安全送回地球。这在人类历史上尚属首次。',
    ),
    NewsArticle(
      id: 'mock_ai',
      title: '深圳科技公司发布新款人工智能大模型',
      source: '科技新闻',
      publishedAt: DateTime.now().subtract(const Duration(hours: 5)),
      summary: '新一代AI能在毫秒级完成百万汉字的语义分析...',
      url: 'mock_ai',
      fullContent: '人工智能的发展一日千里。该模型由李开复博士投资的公司研发。其核心算法优化了张量计算，降低了电力消耗，是绿色科技的典范。',
    ),
  ];
}
