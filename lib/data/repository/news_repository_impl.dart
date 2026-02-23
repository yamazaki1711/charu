


import '../../domain/model/news_models.dart';
import '../../domain/repository/news_repository.dart';

class NewsRepositoryImpl implements INewsRepository {
  NewsRepositoryImpl();

  @override
  Future<List<NewsArticle>> getLatestNews() async {
    // For now, this is a Scaffold implementation until we find a stable Chinese news API.
    // Example: parsing some Baidu search results or Sina Roll.
    // Returning dummy data that adheres to the 5-layer vocabulary system testing needs.
    await Future.delayed(const Duration(milliseconds: 800)); // Simulate net
    
    return [
      NewsArticle(
        id: '1',
        title: '北京天气晴朗，适合户外活动',
        source: 'Baidu News (Mock)',
        publishedAt: DateTime.now(),
        summary: '北京市气象局发布最新预报，今天白天晴间多云，最高气温25摄氏度...',
        url: 'mock_weather',
        thumbnailUrl: 'https://via.placeholder.com/150/1A1A1A/E8E8E8?text=Weather',
      ),
      NewsArticle(
        id: '2',
        title: '中国嫦娥六号探测器成功返回地球',
        source: 'Sina News (Mock)',
        publishedAt: DateTime.now().subtract(const Duration(hours: 2)),
        summary: '历史性的一刻！携带月球背面样本的嫦娥六号返回器在内蒙古四子王旗着陆...',
        url: 'mock_space',
        thumbnailUrl: 'https://via.placeholder.com/150/1A1D23/E8E8E8?text=Space',
      ),
      NewsArticle(
        id: '3',
        title: '深圳科技公司发布新款人工智能大模型',
        source: 'Tencent (Mock)',
        publishedAt: DateTime.now().subtract(const Duration(hours: 5)),
        summary: '新一代AI能在毫秒级完成百万汉字的语义分析和情感识别...',
        url: 'mock_ai',
        thumbnailUrl: 'https://via.placeholder.com/150/F8F9FA/1A1A1A?text=Tech',
      ),
    ];
  }

  @override
  Future<NewsArticle> fetchArticleContent(String url) async {
    // Scaffold parsing using 'html' package.
    // In production, we actually GET the URL and extract the body.
    await Future.delayed(const Duration(milliseconds: 500));
    
    String mockContent;
    if (url == 'mock_space') {
      mockContent = '嫦娥六号（Chang\'e-6）是中国国家航天局进行的一项月球探测任务。此次任务的目标是从月球背面采集土壤和岩石样本，并将其安全送回地球。这在人类历史上尚属首次。飞船在月球降落后，利用机械臂和钻头获取了宝贵的科学材料。';
    } else if (url == 'mock_weather') {
      mockContent = '北京，中华人民共和国的首都。气象学专家建议市民在好天气多参加户外锻炼，但也要注意防晒，因为紫外线指数偏高。王明（Wang Ming）教授指出，今年的气候与往年相比，略有波动。';
    } else {
      mockContent = '人工智能的发展一日千里。该模型由李开复博士投资的公司研发。其核心算法优化了张量计算，降低了电力消耗，是绿色科技的典范。通过Jieba分词，AI可以更准确地理解中文长难句的结构。';
    }

    return NewsArticle(
      id: url,
      title: 'Full Article Analysis',
      source: 'Parsed Source',
      publishedAt: DateTime.now(),
      fullContent: mockContent,
    );
  }
}
