import '../../domain/model/dictionary_models.dart';
import '../../domain/repository/dictionary_repository.dart';
import '../local/database_helper.dart';

/// Concrete implementation of the Dictionary Repository handling the 5-layer cascade.
class DictionaryRepositoryImpl implements IDictionaryRepository {
  final DatabaseHelper _dbHelper;

  DictionaryRepositoryImpl({DatabaseHelper? dbHelper})
      : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  @override
  Future<DictionaryResult> lookupWord(String word) async {
    // ----------------------------------------------------------------------
    // STEP 1: Local BKRS (Offline)
    // ----------------------------------------------------------------------
    final bkrsResult = await searchLocalBkrs(word);
    if (bkrsResult != null) {
      return DictionaryResult(
        chineseWord: word,
        pinyin: bkrsResult.pinyin,
        translation: bkrsResult.translation,
        source: 'bkrs',
      );
    }

    // ----------------------------------------------------------------------
    // STEP 2: Toponym Base (Offline)
    // ----------------------------------------------------------------------
    final toponymResult = await searchToponym(word);
    if (toponymResult != null) {
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

    // ----------------------------------------------------------------------
    // STEP 3: Person Names (Offline)
    // ----------------------------------------------------------------------
    final namesResult = await searchPersonName(word);
    if (namesResult.isNotEmpty) {
      // Assuming a heuristic where we merge name+surname
      final pinyinFull = namesResult.map((n) => n.pinyin).join(' ');
      return DictionaryResult(
        chineseWord: word,
        pinyin: pinyinFull,
        translation: 'Личное имя [вероятно]',
        source: 'person',
        icon: '👤',
      );
    }

    // ----------------------------------------------------------------------
    // STEP 4: Online Grand BKRS (bkrs.info)
    // ----------------------------------------------------------------------
    // TODO: Need Network Checker before calling (requires connectivity plugin)
    final onlineResult = await searchOnlineBkrs(word);
    if (onlineResult != null) {
      return DictionaryResult(
        chineseWord: word,
        pinyin: onlineResult.pinyin,
        translation: onlineResult.translation,
        source: 'online',
        icon: '🌐',
      );
    }

    // ----------------------------------------------------------------------
    // STEP 5: Pinyin Character Fallback
    // ----------------------------------------------------------------------
    final fallbackPinyin = <String>[];
    for (int i = 0; i < word.length; i++) {
        final charPinyin = await getPinyinForCharacter(word[i]);
        fallbackPinyin.add(charPinyin);
    }

    return DictionaryResult(
      chineseWord: word,
      pinyin: fallbackPinyin.join(' '),
      translation: 'Перевод не найден',
      source: 'fallback',
      icon: '❓',
    );
  }

  @override
  Future<WordEntry?> searchLocalBkrs(String word) async {
    final db = await _dbHelper.database;
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
    final db = await _dbHelper.database;
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
    return null;
  }

  @override
  Future<List<PersonNameEntry>> searchPersonName(String word) async {
    final db = await _dbHelper.database;
    // VERY simple matching logic for names. A production impl would separate characters.
    final List<Map<String, dynamic>> maps = await db.query(
      'person_names',
      where: 'chinese = ?',
      whereArgs: [word],
    );
    return maps
        .map((m) => PersonNameEntry(
              id: m['id'] as int,
              chinese: m['chinese'] as String,
              pinyin: m['pinyin'] as String,
              isSurname: (m['is_surname'] as int) == 1,
              gender: m['gender'] as String?,
            ))
        .toList();
  }

  @override
  Future<WordEntry?> searchOnlineBkrs(String word) async {
    // TODO: Implement actual Dio HTTP request to an API endpoint representing bkrs.info
    // For scaffolding, returning null simulates 'not found' or 'offline'.
    return null;
  }

  @override
  Future<String> getPinyinForCharacter(String character) async {
    // Attempt local dictionary lookup just for the single char.
    final result = await searchLocalBkrs(character);
    return result?.pinyin ?? character; // If unresolvable, return the character itself.
  }
}
