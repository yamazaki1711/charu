/// Domain model representing a news article
class NewsArticle {
  final String id;
  final String title;
  final String source;
  final DateTime publishedAt;
  final String summary;
  final String? url;

  /// Full HTML or segmented text body for reading.
  final String? fullContent;

  /// Thumbnail URL if the article has an image
  final String? thumbnailUrl;

  const NewsArticle({
    required this.id,
    required this.title,
    required this.source,
    required this.publishedAt,
    this.summary = '',
    this.url,
    this.fullContent,
    this.thumbnailUrl,
  });
}
