import 'package:flutter/foundation.dart' show kIsWeb;
import '../../core/log.dart';
import 'package:sqflite/sqflite.dart';

import '../../domain/model/dictionary_models.dart';
import '../../domain/repository/dictionary_repository.dart';
import '../local/database_helper.dart';
import '../remote/online_dictionary_service.dart';

/// Concrete implementation of the Dictionary Repository handling the 5-layer cascade.
class DictionaryRepositoryImpl implements IDictionaryRepository {
  final DatabaseHelper _dbHelper;
  final OnlineDictionaryService _onlineService;

  DictionaryRepositoryImpl({
    DatabaseHelper? dbHelper,
    OnlineDictionaryService? onlineService,
  })  : _dbHelper = dbHelper ?? DatabaseHelper.instance,
        _onlineService = onlineService ?? OnlineDictionaryService();

  @override
  Future<DictionaryResult> lookupWord(String word) async {
    log('[Dict] ═══ Looking up: "$word" ═══');

    // On Web, use in-memory dictionary
    if (kIsWeb) {
      final webResult = _dbHelper.lookupWeb(word);
      if (webResult != null) {
        log('[Dict] ✅ Found in Web dictionary');
        return DictionaryResult(
          chineseWord: word,
          pinyin: webResult['pinyin']!,
          translation: webResult['translation']!,
          source: 'web',
        );
      }
      log('[Dict] ❌ Not in Web dictionary, falling back');
      return DictionaryResult(
        chineseWord: word,
        pinyin: word.split('').map((c) => '[$c]').join(' '),
        translation: 'Перевод не найден (Web демо)',
        source: 'fallback',
        icon: '❓',
      );
    }

    // ------------------------------------------------------------------
    // STEP 1: Local BKRS (Offline) - Primary lookup
    // ------------------------------------------------------------------
    try {
      log('[Dict] Step 1: Local BKRS...');
      final bkrsResult = await searchLocalBkrs(word);
      if (bkrsResult != null) {
        log('[Dict] ✅ Found in local BKRS: "${bkrsResult.pinyin}" / "${bkrsResult.translation.substring(0, bkrsResult.translation.length.clamp(0, 60))}"');
        return DictionaryResult(
          chineseWord: word,
          pinyin: bkrsResult.pinyin,
          translation: bkrsResult.translation,
          source: 'bkrs',
        );
      }
      log('[Dict] ❌ Not found in local BKRS');
    } catch (e) {
      log('[Dict] ⚠️ Local BKRS error: $e');
    }

    // ------------------------------------------------------------------
    // STEP 2: Toponym Base (Offline)
    // ------------------------------------------------------------------
    try {
      log('[Dict] Step 2: Toponyms...');
      final toponymResult = await searchToponym(word);
      if (toponymResult != null) {
        log('[Dict] ✅ Found toponym: ${toponymResult.english}');
        return DictionaryResult(
          chineseWord: word,
          pinyin: toponymResult.pinyin,
          translation: '${toponymResult.english} (${toponymResult.type})',
          source: 'toponym',
          icon: '🗺️',
          metadata: {
            'lat': toponymResult.latitude,
            'lng': toponymResult.longitude,
          },
        );
      }
      log('[Dict] ❌ Not a toponym');
    } catch (e) {
      log('[Dict] ⚠️ Toponym error: $e');
    }

    // ------------------------------------------------------------------
    // STEP 3: Person Names (Offline)
    // ------------------------------------------------------------------
    try {
      log('[Dict] Step 3: Person names...');
      final namesResult = await searchPersonName(word);
      if (namesResult.isNotEmpty) {
        final pinyinFull = namesResult.map((n) => n.pinyin).join(' ');
        log('[Dict] ✅ Found person name: $pinyinFull');
        return DictionaryResult(
          chineseWord: word,
          pinyin: pinyinFull,
          translation: 'Личное имя [вероятно]',
          source: 'person',
          icon: '👤',
        );
      }
      log('[Dict] ❌ Not a person name');
    } catch (e) {
      log('[Dict] ⚠️ Person names error: $e');
    }

    // ------------------------------------------------------------------
    // STEP 4: Online Grand BKRS (bkrs.info)
    // ------------------------------------------------------------------
    // STEP 4: Smart sub-word decomposition (LOCAL, fast)
    // If the whole word is unknown, break it into known sub-parts.
    // e.g. "一说到" → "一" (found) + "说到" (found)
    // ------------------------------------------------------------------
    if (word.length > 1) {
      log('[Dict] Step 4: Sub-word decomposition for "$word" (${word.length} chars)...');
      final parts = await _decomposeIntoKnownParts(word);
      if (parts.isNotEmpty) {
        final combinedPinyin = parts.map((p) => p.pinyin).join(' ');
        final combinedTranslation = parts.map((p) {
          return '【${p.simplified}】${p.pinyin}\n${p.translation}';
        }).join('\n\n');
        log('[Dict] ✅ Decomposed into ${parts.length} parts: ${parts.map((p) => p.simplified).join(" + ")}');
        return DictionaryResult(
          chineseWord: word,
          pinyin: combinedPinyin,
          translation: combinedTranslation,
          source: 'bkrs',
          icon: '🔍',
        );
      }
    }

    // ------------------------------------------------------------------
    // STEP 5: Online Grand BKRS (bkrs.info) — slow, last resort
    // ------------------------------------------------------------------
    try {
      log('[Dict] Step 5: Online BKRS...');
      final onlineResult = await searchOnlineBkrs(word);
      if (onlineResult != null && _isValidTranslation(onlineResult.translation)) {
        log('[Dict] ✅ Found online: "${onlineResult.translation.substring(0, onlineResult.translation.length.clamp(0, 60))}"');
        String finalPinyin = onlineResult.pinyin;
        if (finalPinyin.trim().isEmpty) {
          final fallback = <String>[];
          for (int i = 0; i < word.length; i++) {
            fallback.add(await getPinyinForCharacter(word[i]));
          }
          finalPinyin = fallback.join(' ');
        }
        
        return DictionaryResult(
          chineseWord: word,
          pinyin: finalPinyin,
          translation: onlineResult.translation,
          source: 'online',
          icon: '🌐',
          examples: _onlineService.lastExamples,
        );
      }
      log('[Dict] ❌ Not found online (or invalid result)');
    } catch (e) {
      log('[Dict] ⚠️ Online BKRS error: $e');
    }

    // ------------------------------------------------------------------
    // STEP 6: Pinyin Character Fallback (last resort)
    // ------------------------------------------------------------------
    log('[Dict] Step 6: Pinyin per-character fallback...');
    final fallbackPinyin = <String>[];
    for (int i = 0; i < word.length; i++) {
      final charPinyin = await getPinyinForCharacter(word[i]);
      fallbackPinyin.add(charPinyin);
    }

    // Distinguish "no network" from "genuinely not found" so the dictionary
    // popup doesn't claim a translation search failed when it never ran.
    final offline = _onlineService.lastWasOffline;
    log('[Dict] ❓ Fallback pinyin: ${fallbackPinyin.join(" ")}${offline ? " (offline)" : ""}');
    return DictionaryResult(
      chineseWord: word,
      pinyin: fallbackPinyin.join(' '),
      translation: offline
          ? 'Нет подключения к интернету — показан посимвольный пиньинь'
          : 'Перевод не найден',
      source: 'fallback',
      icon: offline ? '📡' : '❓',
    );
  }

  /// Greedy left-to-right decomposition: tries the longest possible
  /// sub-string starting at each position, falls back to single character.
  Future<List<WordEntry>> _decomposeIntoKnownParts(String text) async {
    final parts = <WordEntry>[];
    int i = 0;
    while (i < text.length) {
      WordEntry? bestMatch;
      int bestLen = 0;

      // Try longest substring first (greedy, max 6 chars)
      final maxLen = (text.length - i).clamp(0, 6);
      for (int len = maxLen; len >= 1; len--) {
        final sub = text.substring(i, i + len);
        final entry = await searchLocalBkrs(sub);
        if (entry != null) {
          bestMatch = entry;
          bestLen = len;
          break; // Found longest match, stop
        }
      }

      if (bestMatch != null) {
        parts.add(bestMatch);
        i += bestLen;
      } else {
        // Single char not in dictionary — add a stub
        final ch = text[i];
        parts.add(WordEntry(
          id: 0,
          simplified: ch,
          pinyin: ch,
          translation: '—',
        ));
        i++;
      }
    }

    // If all parts are single-char stubs, decomposition adds no value
    final meaningful = parts.where((p) => p.translation != '—').length;
    if (meaningful == 0) return [];

    return parts;
  }

  /// Validates that a translation string is actually meaningful content
  /// and not website navigation garbage.
  bool _isValidTranslation(String text) {
    if (text.isEmpty || text.length < 3) return false;

    // Must contain at least one Cyrillic character (Russian translation)
    if (!RegExp(r'[а-яА-ЯёЁ]').hasMatch(text)) return false;

    // Reject common navigation/menu text from bkrs.info
    final junkPatterns = [
      'Главная',
      'ДобавитьНовые',
      'Исправленные',
      'Примеры',
      'войти',
      'регистрация',
      'поиск',
    ];
    for (final junk in junkPatterns) {
      if (text.contains(junk)) return false;
    }

    return true;
  }

  @override
  Future<void> saveWord(DictionaryResult result) async {
    if (kIsWeb) return;
    try {
      final db = await _dbHelper.userDatabase; // ← writable user DB
      await db.insert('user_vocabulary', {
        'word': result.chineseWord,
        'pinyin': result.pinyin,
        'translation': result.translation,
        'source_type': result.source,
        'saved_date': DateTime.now().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      log('[Dict] Saved word: ${result.chineseWord}');
    } catch (e) {
      log('[Dict] ⚠️ Save error: $e');
    }
  }

  @override
  Future<WordEntry?> searchLocalBkrs(String word) async {
    if (kIsWeb) return null;
    final db = await _dbHelper.database; // ← read-only dict DB
    final List<Map<String, dynamic>> maps = await db.query(
      'dictionary',
      where: 'simplified = ? OR traditional = ?',
      whereArgs: [word, word],
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return WordEntry(
        id: maps.first['id'] as int,
        simplified: maps.first['simplified'] as String,
        traditional: maps.first['traditional'] as String?,
        pinyin: maps.first['pinyin'] as String,
        translation: maps.first['translation'] as String,
        examples: maps.first['examples'] as String?,
      );
    }
    return null;
  }

  @override
  Future<ToponymEntry?> searchToponym(String word) async {
    if (kIsWeb) return null;
    final db = await _dbHelper.database;
    // Check if toponyms table exists
    try {
      final List<Map<String, dynamic>> maps = await db.query(
        'toponyms',
        where: 'chinese = ?',
        whereArgs: [word],
        limit: 1,
      );
      if (maps.isNotEmpty) {
        return ToponymEntry(
          id: maps.first['id'] as int,
          chinese: maps.first['chinese'] as String,
          pinyin: maps.first['pinyin'] as String,
          english: maps.first['english'] as String,
          type: maps.first['type'] as String,
          latitude: maps.first['latitude'] as double?,
          longitude: maps.first['longitude'] as double?,
        );
      }
    } catch (e) {
      log('[Dict] Toponyms table not available: $e');
    }
    return null;
  }

  @override
  Future<List<PersonNameEntry>> searchPersonName(String word) async {
    if (kIsWeb) return [];
    final db = await _dbHelper.database;
    try {
      final List<Map<String, dynamic>> maps = await db.query(
        'person_names',
        where: 'chinese = ?',
        whereArgs: [word],
      );
      return maps
          .map(
            (m) => PersonNameEntry(
              id: m['id'] as int,
              chinese: m['chinese'] as String,
              pinyin: m['pinyin'] as String,
              isSurname: (m['is_surname'] as int) == 1,
              gender: m['gender'] as String?,
            ),
          )
          .toList();
    } catch (e) {
      log('[Dict] Person names table not available: $e');
      return [];
    }
  }

  @override
  Future<WordEntry?> searchOnlineBkrs(String word) async {
    if (kIsWeb) return null;
    return await _onlineService.search(word);
  }

  @override
  Future<String> getPinyinForCharacter(String character) async {
    if (kIsWeb) {
      final webResult = _dbHelper.lookupWeb(character);
      return webResult?['pinyin'] ?? character;
    }
    final result = await searchLocalBkrs(character);
    return result?.pinyin ?? character;
  }
}
