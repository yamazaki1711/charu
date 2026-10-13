import 'dart:io';

import 'package:dio/dio.dart';
import '../../core/log.dart';
import 'package:html/parser.dart' as html_parser;

import '../../domain/model/dictionary_models.dart';

/// Сервис для поиска слов в онлайн-словаре 大БКРС (bkrs.info)
class OnlineDictionaryService {
  final Dio _dio;
  static const String _baseUrl = 'https://bkrs.info';

  /// Pinyin-annotated examples parsed from the last successful search.
  ///
  /// Populated by [search] after each successful fetch; empty otherwise.
  /// The caller (DictionaryRepositoryImpl) can read this field after
  /// `search()` returns to attach examples to the `DictionaryResult`.
  List<PinyinExample> lastExamples = const [];

  /// True when the most recent [search] call was skipped because the
  /// device appeared to be offline (connectivity probe failed), as
  /// opposed to a real "not found" result. The caller uses this to show
  /// an honest "no connection" message instead of "translation not found".
  bool lastWasOffline = false;

  /// Caches a negative connectivity result for this long so that looking
  /// up many unknown words while offline doesn't pay a DNS-timeout per word.
  static const _offlineCooldown = Duration(seconds: 20);
  static DateTime? _offlineUntil;

  OnlineDictionaryService({Dio? dio}) : _dio = dio ?? Dio();

  /// Cheap connectivity probe (DNS lookup with a short timeout) run before
  /// any HTTP request — avoids multi-second Dio timeouts on every word
  /// lookup when the device has no network at all.
  Future<bool> _isOnline() async {
    final cachedOffline = _offlineUntil;
    if (cachedOffline != null && DateTime.now().isBefore(cachedOffline)) {
      return false;
    }
    try {
      final result = await InternetAddress.lookup('bkrs.info')
          .timeout(const Duration(seconds: 3));
      if (result.isNotEmpty && result.first.rawAddress.isNotEmpty) {
        _offlineUntil = null;
        return true;
      }
    } catch (_) {
      // DNS failure or timeout — treat as offline below.
    }
    _offlineUntil = DateTime.now().add(_offlineCooldown);
    return false;
  }

  /// Поиск слова в онлайн-словаре
  Future<WordEntry?> search(String word) async {
    if (word.trim().isEmpty) return null;
    lastWasOffline = false;

    if (!await _isOnline()) {
      lastWasOffline = true;
      log('[Online] Skipped "$word" — no network connection');
      return null;
    }

    try {
      log('[Online] Searching bkrs.info for: "$word"');

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
          log('[Online] Bypassing bot protection with ca=$caValue');

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
              validateStatus: (status) => status != null && status < 500,
            ),
          );
        }
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        final html = response.data.toString();
        // Extract pinyin-annotated examples from the page (side-channel).
        lastExamples = _parseExamplePinyin(html);
        return _parseSearchResult(html, word);
      }
      if (response.statusCode != null &&
          response.statusCode! >= 400 &&
          response.statusCode! < 500) {
        log('[Online] Client error ${response.statusCode}: not found or bad request for "$word"');
      } else {
        log('[Online] Bad status code: ${response.statusCode}');
      }
    } on DioException catch (e) {
      if (e.response != null && (e.response!.statusCode ?? 0) >= 400) {
        log(
            '[Online] HTTP error ${e.response!.statusCode}: ${e.response!.statusMessage}');
      } else {
        log('[Online] DioException: ${e.message}');
      }
    } catch (e) {
      log('[Online] Unexpected error: $e');
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
        log('[Online] Found pinyin: "$pinyin"');
      }

      // Try to get translation from specific containers
      // Priority order: .ru (main translation), then #info content
      final ruEl = document.querySelector('div.ru');
      if (ruEl != null) {
        final text = ruEl.text.trim();
        if (text.isNotEmpty && _isActualTranslation(text)) {
          translation = text;
          log('[Online] Found translation via div.ru: "${text.substring(0, text.length.clamp(0, 60))}"');
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
              log('[Online] Found translation via $selector');
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
            log('[Online] Found translation via result list item');
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
          log('[Online] Found translation via body text fallback');
        }
      }

      if (translation != null) {
        log('[Online] ✅ Final result for "$searchWord": pinyin="${pinyin ?? ""}", translation="${translation.substring(0, translation.length.clamp(0, 80))}"');
        return WordEntry(
          id: 0,
          simplified: searchWord,
          traditional: null,
          pinyin: pinyin ?? '',
          translation: translation,
          examples: null,
        );
      }

      log('[Online] ❌ No valid translation found in HTML');
    } catch (e) {
      log('[Online] Parse error: $e');
    }

    return null;
  }

  /// Extracts pinyin-annotated examples from the bkrs.info page HTML.
  ///
  /// Scans all `class="ex"` blocks for `[pinyin]` annotations (with tone
  /// marks) and pairs them with the preceding Chinese text. Returns an empty
  /// list if no annotated examples are found.
  List<PinyinExample> _parseExamplePinyin(String html) {
    final examples = <PinyinExample>[];
    try {
      // Pinyin syllables with tone marks (U+0100–U+024F covers all diacritical
      // letters used in pinyin: ā á ǎ à ē é ě è ī í ǐ ì ō ó ǒ ò ū ú ǔ ù ǖ ǘ ǚ ǜ
      // plus ă ĕ ĭ ǒ ŏ ů for rare forms).
      final pinyinPattern =
          RegExp(r'\[([^\[\]]*[\u0100-\u024f][^\[\]]*)\]');

      for (final exEl
          in html_parser.parse(html).querySelectorAll('div.ex')) {
        final text = exEl.text.trim();
        if (text.isEmpty) continue;

        final pinyinMatch = pinyinPattern.firstMatch(text);
        if (pinyinMatch == null) continue;

        // The Chinese text is everything before the first `[pinyin]`.
        final chinese = text.substring(0, pinyinMatch.start).trim();
        if (chinese.isEmpty) continue;

        // Only keep entries that actually contain Chinese characters.
        if (!RegExp(r'[\u4e00-\u9fff]').hasMatch(chinese)) continue;

        examples.add(PinyinExample(
          chinese: chinese,
          pinyin: pinyinMatch.group(1)!.trim(),
        ));
      }
    } catch (e) {
      log('[Online] Failed to parse example pinyin: $e');
    }
    return examples;
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
