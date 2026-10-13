import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:xml/xml.dart' as xml;

import '../../domain/model/news_models.dart';

class NewsApiService {
  final Dio _dio;

  NewsApiService({Dio? dio}) : _dio = dio ?? Dio();

  static const List<Map<String, String>> kDefaultRssSources = [
    {'name': '中国新闻网', 'url': 'https://www.chinanews.com.cn/rss/sh.xml'},
    {'name': '中国生活', 'url': 'https://www.chinanews.com.cn/rss/life.xml'},
  ];

  static const List<Map<String, String>> _htmlSources = [
    {'name': '新浪', 'url': 'https://news.sina.com.cn'},
  ];

  /// Источники RSS из таблицы news_sources (если сконфигурированы),
  /// иначе — [kDefaultRssSources].
  List<Map<String, String>> _rssSources = kDefaultRssSources;

  /// Подменить дефолтные RSS-источники (вызывается из
  /// [NewsRepositoryImpl.configureSources]).
  void configureSources(List<Map<String, String>> rssSources) {
    if (rssSources.isNotEmpty) _rssSources = rssSources;
  }

  Future<List<NewsArticle>> fetchLatestNews() async {
    // Try RSS first
    for (final source in _rssSources) {
      try {
        debugPrint('[News] Trying RSS: ${source['url']}');
        final articles = await _fetchRss(source['url']!, source['name']!);
        if (articles.isNotEmpty) {
          debugPrint('[News] Success: ${articles.length} articles');
          return articles;
        }
      } catch (e) {
        debugPrint('[News] Error ${source['name']}: $e');
      }
    }

    // Fallback to HTML
    for (final source in _htmlSources) {
      try {
        final articles = await _fetchHtml(source['url']!, source['name']!);
        if (articles.isNotEmpty) {
          return articles;
        }
      } catch (e) {
        debugPrint('[News] HTML Error: $e');
      }
    }

    return [];
  }

  Future<List<NewsArticle>> _fetchRss(String url, String sourceName) async {
    final response = await _dio.get(
      url,
      options: Options(
        headers: {
          'User-Agent': 'Mozilla/5.0',
          'Accept': 'application/rss+xml, application/xml, text/xml, */*',
        },
        receiveTimeout: const Duration(seconds: 15),
      ),
    );

    if (response.statusCode == 200) {
      return _parseRssXml(response.data.toString(), sourceName);
    }
    return [];
  }

  List<NewsArticle> _parseRssXml(String xmlString, String sourceName) {
    final articles = <NewsArticle>[];

    try {
      final document = xml.XmlDocument.parse(xmlString);
      final items = document.findAllElements('item');

      debugPrint('[News] Found ${items.length} items');

      for (final item in items) {
        final title = item.findElements('title').firstOrNull?.innerText.trim() ?? '';
        final link = item.findElements('link').firstOrNull?.innerText.trim() ?? '';
        final description = item.findElements('description').firstOrNull?.innerText.trim() ?? '';

        if (title.isNotEmpty && link.isNotEmpty && _hasChinese(title)) {
          debugPrint('[News] Article: $title');
          articles.add(NewsArticle(
            id: link,
            title: _cleanText(title),
            source: sourceName,
            publishedAt: DateTime.now(),
            summary: _cleanText(description),
            url: link,
          ));
        }

        if (articles.length >= 15) break;
      }
    } catch (e) {
      debugPrint('[News] XML parse error: $e');
    }

    return articles;
  }

  bool _hasChinese(String text) {
    for (int i = 0; i < text.length; i++) {
      final code = text.codeUnitAt(i);
      if ((code >= 0x4E00 && code <= 0x9FFF) ||
          (code >= 0x3400 && code <= 0x4DBF)) {
        return true;
      }
    }
    return false;
  }

  String _cleanText(String text) {
    // Remove HTML tags
    return text
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  Future<List<NewsArticle>> _fetchHtml(String url, String sourceName) async {
    try {
      final response = await _dio.get(
        url,
        options: Options(
          headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          },
          receiveTimeout: const Duration(seconds: 15),
        ),
      );

      if (response.statusCode == 200) {
        return _parseHtml(response.data.toString(), sourceName, url);
      }
    } catch (e) {
      debugPrint('[News] HTTP error: $e');
    }
    return [];
  }

  List<NewsArticle> _parseHtml(String html, String sourceName, String baseUrl) {
    final articles = <NewsArticle>[];

    // Simple regex-based extraction for titles
    final titleRegex = RegExp('<a[^>]*title=["\']([^"\']+)["\'][^>]*>([^<]*)</a>', caseSensitive: false);
    final hrefRegex = RegExp('href=["\']([^"\']+)["\']');
    final matches = titleRegex.allMatches(html);

    for (final match in matches) {
      final title = (match.group(1) ?? match.group(2) ?? '').trim();
      final hrefMatch = hrefRegex.firstMatch(match.group(0) ?? '');
      final href = hrefMatch?.group(1) ?? '';

      if (title.length >= 6 && title.length <= 60 && _hasChinese(title)) {
        String fullUrl = href;
        if (href.startsWith('/')) {
          fullUrl = Uri.parse(baseUrl).origin + href;
        } else if (!href.startsWith('http')) {
          fullUrl = '$baseUrl/$href';
        }

        if (fullUrl.isNotEmpty && !fullUrl.contains('javascript')) {
          articles.add(NewsArticle(
            id: fullUrl,
            title: title,
            source: sourceName,
            publishedAt: DateTime.now(),
            url: fullUrl,
          ));
        }
      }

      if (articles.length >= 15) break;
    }

    return articles;
  }

  Future<NewsArticle?> fetchArticleContent(NewsArticle article) async {
    if (article.fullContent != null && article.fullContent!.isNotEmpty) {
      return article;
    }

    final url = article.url;
    if (url == null) return article;

    try {
      final response = await _dio.get(
        url,
        options: Options(
          headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          },
          receiveTimeout: const Duration(seconds: 15),
        ),
      );

      if (response.statusCode == 200) {
        return _parseArticle(response.data.toString(), article);
      }
    } catch (e) {
      debugPrint('[News] Article fetch error: $e');
    }
    return article;
  }

  NewsArticle _parseArticle(String html, NewsArticle article) {
    String content = '';

    // Try to extract content between paragraph tags
    final pRegex = RegExp(r'<p[^>]*>([\s\S]*?)</p>', caseSensitive: false);
    final matches = pRegex.allMatches(html);

    final paragraphs = <String>[];
    for (final match in matches) {
      final text = match.group(1)?.trim() ?? '';
      if (text.length > 20) {
        paragraphs.add(_cleanText(text));
      }
    }
    content = paragraphs.join('\n\n');

    // Fallback
    if (content.length < 50) {
      final bodyRegex = RegExp(r'<body[^>]*>([\s\S]*)<\/body>', caseSensitive: false);
      final bodyMatch = bodyRegex.firstMatch(html);
      if (bodyMatch != null) {
        content = _cleanText(bodyMatch.group(1) ?? '');
        if (content.length > 500) {
          content = content.substring(0, 500);
        }
      }
    }

    return NewsArticle(
      id: article.id,
      title: article.title,
      source: article.source,
      publishedAt: article.publishedAt,
      summary: content.length > 200 ? content.substring(0, 200) : content,
      url: article.url,
      fullContent: content,
    );
  }
}
