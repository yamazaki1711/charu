import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_open_chinese_convert/flutter_open_chinese_convert.dart';

import '../../core/log.dart';

/// Downloads and cleans a single work's text from Chinese Wikisource
/// (zh.wikisource.org). Mirrors the proxy-fallback approach used by
/// [NewsApiService] for domains unreachable without a proxy.
class WikisourceService {
  final Dio _dio;

  WikisourceService({Dio? dio}) : _dio = dio ?? Dio();

  static const List<String> _feedProxies = [
    '',
    'https://api.allorigins.win/raw?url=',
    'https://api.codetabs.com/v1/proxy?quest=',
  ];

  /// Fetches [wikisourceTitle] (e.g. "故乡") via the MediaWiki `parse` API,
  /// strips wiki furniture, and optionally converts traditional -> simplified.
  Future<String> fetchBookText(
    String wikisourceTitle, {
    bool convertToSimplified = true,
  }) async {
    // redirects=1 is required: many simplified-form titles (e.g. "故乡")
    // are redirect pages to the canonical traditional title ("故鄉") on
    // zh.wikisource.org — without it, `parse` returns a near-empty
    // "重定向到：..." stub instead of the actual work's text.
    final apiUrl = 'https://zh.wikisource.org/w/api.php'
        '?action=parse&page=${Uri.encodeComponent(wikisourceTitle)}'
        '&redirects=1&prop=text&format=json&formatversion=2';

    String? html;
    for (final proxy in _feedProxies) {
      final target =
          proxy.isEmpty ? apiUrl : '$proxy${Uri.encodeComponent(apiUrl)}';
      try {
        final response = await _dio.get(
          target,
          options: Options(
            headers: {'User-Agent': 'Mozilla/5.0'},
            connectTimeout: const Duration(seconds: 8),
            receiveTimeout: const Duration(seconds: 20),
          ),
        );
        final body = response.data is String
            ? jsonDecode(response.data as String)
            : response.data;
        final text = body?['parse']?['text'] as String?;
        if (text != null && text.isNotEmpty) {
          html = text;
          if (proxy.isNotEmpty) {
            log('[Library] $wikisourceTitle: fetched via proxy');
          }
          break;
        }
      } catch (e) {
        log('[Library] $wikisourceTitle via ${proxy.isEmpty ? 'direct' : 'proxy'}: $e');
      }
    }

    if (html == null) {
      throw Exception('Wikisource: не удалось загрузить "$wikisourceTitle"');
    }

    final cleaned = _cleanWikiHtml(html);
    if (!convertToSimplified) return cleaned;

    try {
      return await ChineseConverter.convert(cleaned, TW2Sp());
    } catch (e) {
      log('[Library] OpenCC conversion failed, keeping traditional: $e');
      return cleaned;
    }
  }

  /// Strips MediaWiki chrome (nav boxes, edit-section links, page-number
  /// spans from ProofreadPage, "收錄於"/姊妹计划 footers, infobox tables)
  /// and converts block tags to plain-text paragraph breaks.
  String _cleanWikiHtml(String html) {
    var out = html;

    // script/style blocks removed entirely.
    out = out.replaceAll(
      RegExp(r'<(script|style)[^>]*>[\s\S]*?</\1>', caseSensitive: false),
      '',
    );

    // Tables (author infobox, "本作品收錄於" header box, 姊妹计划 sister-
    // project box) are all front-matter, never story content on these
    // single-work pages — but they nest, so a single non-greedy regex only
    // strips up to the *innermost* closing tag. Loop removing the innermost
    // table until none remain (peels nesting from the inside out).
    final tableRe = RegExp(
      r'<table[^>]*>(?:(?!<table)[\s\S])*?</table>',
      caseSensitive: false,
    );
    while (tableRe.hasMatch(out)) {
      out = out.replaceAll(tableRe, '');
    }
    // Block-level furniture containers (footnote reflist, PD-license
    // template, navboxes) — same nesting problem as tables, same fix: loop
    // removing the innermost non-div-nested match. These never contain a
    // nested <div> internally (just <ol>/<li>/<span>/<a>), so excluding
    // "<div" from the captured body is enough to span to the real closer.
    final divFurnitureRe = RegExp(
      r'<div[^>]*class="[^"]*(reflist|licenseContainer|licensetpl|navbox|catlinks)[^"]*"[^>]*>(?:(?!<div)[\s\S])*?</div>',
      caseSensitive: false,
    );
    while (divFurnitureRe.hasMatch(out)) {
      out = out.replaceAll(divFurnitureRe, '');
    }
    // Sister-projects list sometimes sits outside any table.
    out = out.replaceAll(
      RegExp(r'<ul[^>]+id="plainSister"[^>]*>[\s\S]*?</ul>',
          caseSensitive: false),
      '',
    );
    // Small non-nested furniture elements (safe with a simple one-shot
    // strip since they don't wrap other tags before their own close).
    out = out.replaceAll(
      RegExp(
        r'<[^>]+class="[^"]*(headertemplate|printfooter|pagenum|editsection|noprint|dablink|metadata)[^"]*"[^>]*>[\s\S]*?</[a-z]+>',
        caseSensitive: false,
      ),
      '',
    );
    // <sup> reference markers, e.g. footnote links.
    out = out.replaceAll(
      RegExp(r'<sup[^>]*>[\s\S]*?</sup>', caseSensitive: false),
      '',
    );
    // Block-level tags -> newlines.
    out = out.replaceAll(
      RegExp(r'</?(p|div|br|h[1-6]|li|dd|dt)[^>]*>', caseSensitive: false),
      '\n',
    );
    // Strip remaining tags.
    out = out.replaceAll(RegExp(r'<[^>]*>'), '');
    // Decode common HTML entities.
    out = out
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'");
    // Collapse horizontal whitespace; drop stray "编辑" (section edit-link
    // label leftover from the same nesting issue — never real content).
    out = out.replaceAll(RegExp(r'[ \t]+'), ' ');
    out = out
        .split('\n')
        .where((line) => line.trim() != '编辑')
        .join('\n');
    out = out.replaceAll(RegExp(r'\n\s*\n+'), '\n\n').trim();

    // PD-license boilerplate paragraphs have no single reliable class
    // across the different license templates in use — filter by the
    // legal terms that only appear in that boilerplate, never in prose.
    const legalMarkers = ['公有領域', '版權期限', '著作權法', '著作权法'];
    final paragraphs = out.split('\n\n').where(
          (p) => !legalMarkers.any((m) => p.contains(m)),
        );
    return paragraphs.join('\n\n').trim();
  }
}
