import '../model/news_models.dart';
import '../repository/news_repository.dart';

/// UseCase to get the main news feed
class GetLatestNewsUseCase {
  final INewsRepository _repository;

  GetLatestNewsUseCase(this._repository);

  Future<List<NewsArticle>> call() async {
    return await _repository.getLatestNews();
  }
}

/// UseCase to load the full body text of a news article
class FetchArticleContentUseCase {
  final INewsRepository _repository;

  FetchArticleContentUseCase(this._repository);

  Future<NewsArticle> call(String url) async {
    return await _repository.fetchArticleContent(url);
  }
}
