import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:html/parser.dart' as html_parser;

import '../../domain/model/dictionary_models.dart';

/// Сервис для поиска слов в онлайн-словаре 大БКРС (bkrs.info)
class OnlineDictionaryService {
  final Dio _dio;
  static const String _baseUrl = 'https://bkrs.info';

  OnlineDictionaryService({Dio? dio}) : _dio = dio ?? Dio();

  /// Поиск слова в онлайн-словаре
  Future<WordEntry?> search(String word) async {
    if (word.trim().isEmpty) return null;

    try {
      debugPrint('[Online] Searching bkrs.info for: "$word"');

      // 1. Делаем первый запрос
      var response = await _dio.get(
        '$_baseUrl/slovo.php',
        queryParameters: {'ch': word},
        options: Options(
          headers: {
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            'Accept':
                'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8',
            'Accept-Language':
                'ru-RU,ru;q=0.9,en-US;q=0.8,en;q=0.7,zh-CN;q=0.6,zh;q=0.5',
            'Referer': 'https://bkrs.info/',
          },
          receiveTimeout: const Duration(seconds: 10),
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      final responseText = response.data?.toString() ?? '';

      // 2. Обходим защиту от ботов bkrs.info (challenge page)
      if (responseText.contains("name='ca'") ||
          responseText.contains('name="ca"')) {
        final regExp =
            RegExp(r'''name=['"]ca['"]\s+value=['"]([^'"]+)['"]''');
        final match = regExp.firstMatch(responseText);

        if (match != null && match.groupCount >= 1) {
          final caValue = match.group(1)!;
          debugPrint('[Online] Bypassing bot protection with ca=$caValue');

          response = await _dio.get(
            '$_baseUrl/slovo.php',
            queryParameters: {'ch': word},
            options: Options(
              headers: {
                'User-Agent':
                    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
                'Accept':
                    'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8',
                'Accept-Language':
                    'ru-RU,ru;q=0.9,en-US;q=0.8,en;q=0.7,zh-CN;q=0.6,zh;q=0.5',
                'Cookie': 'ca=$caValue',
                'Referer': 'https://bkrs.info/',
              },
              receiveTimeout: const Duration(seconds: 10),
            ),
          );
        }
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        final html = response.data.toString();
        return _parseSearchResult(html, word);
      }
      debugPrint('[Online] Bad status code: ${response.statusCode}');
    } on DioException catch (e) {
      debugPrint('[Online] DioException: ${e.message}');
    } catch (e) {
      debugPrint('[Online] Unexpected error: $e');
    }

    return null;
  }

  /// Парсинг HTML ответа от bkrs.info
  WordEntry? _parseSearchResult(String html, String searchWord) {
    try {
      final document = html_parser.parse(html);

      String? pinyin;
      String? translation;

      // ═══════════════════════════════════════════════════════════════
      // Strategy 1: Direct word page (div#info with pinyin + translation)
      // The word page has:
      //   <div class="py">pīn yīn</div>
      //   <div class="ru">translation text</div>
      // ═══════════════════════════════════════════════════════════════

      // Try to get pinyin
      final pyEl = document.querySelector('.py, .pinyin');
      if (pyEl != null) {
        pinyin = pyEl.text.trim();
        debugPrint('[Online] Found pinyin: "$pinyin"');
      }

      // Try to get translation from specific containers
      // Priority order: .ru (main translation), then #info content
      final ruEl = document.querySelector('div.ru');
      if (ruEl != null) {
        final text = ruEl.text.trim();
        if (text.isNotEmpty && _isActualTranslation(text)) {
          translation = text;
          debugPrint('[Online] Found translation via div.ru: "${text.substring(0, text.length.clamp(0, 60))}"');
        }
      }

      // Try the result container (#info, .tl_result)
      if (translation == null) {
        for (final selector in ['#info', '.tl_result', '.ch_ru']) {
          final el = document.querySelector(selector);
          if (el != null) {
            final text = el.text.trim();
            if (text.isNotEmpty && _isActualTranslation(text) && text.length > 5) {
              translation = text;
              debugPrint('[Online] Found translation via $selector');
              break;
            }
          }
        }
      }

      // ═══════════════════════════════════════════════════════════════
      // Strategy 2: Search results page (multiple results listed)
      // ═══════════════════════════════════════════════════════════════
      if (translation == null) {
        // Try picking from individual result items
        final resultItems = document.querySelectorAll('div.ch_ru, li.dict_entry, div.wordblock');
        for (final item in resultItems) {
          final text = item.text.trim();
          if (text.isNotEmpty && _isActualTranslation(text) && text.length > 5) {
            translation = text;
            debugPrint('[Online] Found translation via result list item');
            break;
          }
        }
      }

      // ═══════════════════════════════════════════════════════════════
      // Strategy 3: Fallback — extract from body text, filtering nav
      // ═══════════════════════════════════════════════════════════════
      if (translation == null) {
        // Remove navigation, header, footer elements
        document.querySelectorAll('nav, header, footer, .menu, .nav, #menu, #nav, #header, #footer, .sidebar, script, style, .top_menu, .header').forEach((el) => el.remove());

        final bodyText = document.body?.text ?? '';
        final lines = bodyText
            .split('\n')
            .map((l) => l.trim())
            .where((l) => l.length > 10 && l.length < 500)
            .where((l) => _isActualTranslation(l))
            .toList();

        if (lines.isNotEmpty) {
          translation = lines.first;
          debugPrint('[Online] Found translation via body text fallback');
        }
      }

      if (translation != null) {
        debugPrint('[Online] ✅ Final result for "$searchWord": pinyin="${pinyin ?? ""}", translation="${translation.substring(0, translation.length.clamp(0, 80))}"');
        return WordEntry(
          id: 0,
          simplified: searchWord,
          traditional: null,
          pinyin: pinyin ?? '',
          translation: translation,
          examples: null,
        );
      }

      debugPrint('[Online] ❌ No valid translation found in HTML');
    } catch (e) {
      debugPrint('[Online] Parse error: $e');
    }

    return null;
  }

  /// Check if text looks like actual translation content,
  /// not navigation or website chrome.
  bool _isActualTranslation(String text) {
    // Must have at least one Cyrillic character (Russian)
    if (!RegExp(r'[а-яА-ЯёЁ]').hasMatch(text)) return false;

    // Reject obvious navigation/UI strings
    const junkPhrases = [
      'Главная',
      'Добавить',
      'Новые',
      'Исправленные',
      'Примеры',
      'войти',
      'Войти',
      'регистрация',
      'Регистрация',
      'Поиск',
      'Копировать',
      'ответить',
      'Отправить',
      'bkrs.info',
      'БКРС',
      'Большой',
    ];

    for (final junk in junkPhrases) {
      // Only reject if the junk phrase appears at the START or
      // makes up most of the text (to avoid false positives)
      if (text.startsWith(junk) || text == junk) return false;
    }

    // Reject if text has NO spaces (likely concatenated nav items)
    if (text.length > 20 && !text.contains(' ') && !text.contains('，') && !text.contains('；')) {
      return false;
    }

    return true;
  }
}
