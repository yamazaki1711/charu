import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart';
import 'package:sqlite3/sqlite3.dart';

void main() async {
  print('🚀 Парсинг DSL словаря (стриминг)...');

  final inputFile = File(join(Directory.current.path, 'dabkrs'));
  final outputDbFile = File(join(Directory.current.path, 'assets', 'db', 'charu_bkrs.db'));

  if (!await inputFile.exists()) {
    print('❌ Файл dabkrs не найден!');
    exit(1);
  }

  // Create database infrastructure
  if (await outputDbFile.exists()) {
    await outputDbFile.delete();
  }
  
  final db = sqlite3.open(outputDbFile.path);
  _createTables(db);

  print('📖 Чтение и парсинг файла (может занять несколько минут)...');
  
  final stream = inputFile.openRead()
      .transform(utf8.decoder)
      .transform(LineSplitter());

  String? currentWord;
  String? currentPinyin;
  String? currentTranslation;

  int totalParsed = 0;
  int insertedValid = 0;
  
  db.execute('BEGIN TRANSACTION');
  var stmt = db.prepare("INSERT INTO dictionary (simplified, traditional, pinyin, translation) VALUES (?, ?, ?, ?)");

  await for (final line in stream) {
    if (line.startsWith('#')) {
      if (_saveIfComplete(stmt, currentWord, currentPinyin, currentTranslation)) insertedValid++;
      currentWord = null; currentPinyin = null; currentTranslation = null;
      continue;
    }

    final trimmed = line.trim();
    
    if (trimmed.isEmpty) {
      if (_saveIfComplete(stmt, currentWord, currentPinyin, currentTranslation)) insertedValid++;
      currentWord = null; currentPinyin = null; currentTranslation = null;
      continue;
    }

    if (_isChinese(trimmed[0])) {
      if (_saveIfComplete(stmt, currentWord, currentPinyin, currentTranslation)) insertedValid++;
      currentWord = trimmed.split(RegExp(r'\s+')).first;
      currentPinyin = null; currentTranslation = null;
      totalParsed++;
      
      if (totalParsed % 100000 == 0) {
        db.execute('COMMIT');
        print('   ✅ Обработано $totalParsed слов (добавлено $insertedValid с пиньинем)...');
        db.execute('BEGIN TRANSACTION');
      }
    } else if (currentWord != null && trimmed.contains('[m1]')) {
      currentTranslation = trimmed;
    } else if (currentWord != null && currentTranslation != null && !trimmed.startsWith('[')) {
      currentTranslation = '$currentTranslation $trimmed';
    } else if (currentWord != null && !_hasChinese(trimmed) && trimmed.contains(RegExp(r'[a-zA-Z]'))) {
      currentPinyin = trimmed;
    }
  }

  // Save the last one
  if (_saveIfComplete(stmt, currentWord, currentPinyin, currentTranslation)) insertedValid++;
  
  stmt.dispose();
  db.execute('COMMIT');
  print('📊 Всего слов найдено: $totalParsed');
  print('📊 Сохранено слов с пиньинем: $insertedValid');

  if (insertedValid == 0) {
    print('❌ Не удалось распарсить файл (0 записей)!');
    db.dispose();
    exit(1);
  }

  print('🗄️ Создаются индексы...');
  db.execute('CREATE INDEX idx_dictionary_simplified ON dictionary(simplified)');

  db.dispose();
  print('✅ База данных успешно создана!');
  
  final size = await outputDbFile.length();
  print('📦 Итоговый размер БД: ${(size / 1024 / 1024).toStringAsFixed(2)} MB');
}

bool _saveIfComplete(PreparedStatement stmt, String? word, String? pinyin, String? translation) {
  if (word != null && translation != null) {
     final p = pinyin ?? '';
     if (p.isNotEmpty) {
       stmt.execute([word, null, p, _cleanTranslation(translation)]);
       return true;
     }
  }
  return false;
}

String _cleanTranslation(String text) {
  var result = text;
  while (result.contains('[')) {
    final start = result.indexOf('[');
    final end = result.indexOf(']');
    if (end > start) {
      result = result.substring(0, start) + result.substring(end + 1);
    } else {
      break;
    }
  }
  return result.replaceAll(RegExp(r'\s+'), ' ').trim();
}

bool _isChinese(String char) {
  if (char.isEmpty) return false;
  final code = char.codeUnitAt(0);
  return (code >= 0x4E00 && code <= 0x9FFF) || (code >= 0x3400 && code <= 0x4DBF);
}

bool _hasChinese(String text) {
  return text.contains(RegExp(r'[\u4e00-\u9fff\u3400-\u4dbf]'));
}

void _createTables(Database db) {
  db.execute('''
    CREATE TABLE dictionary (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      simplified TEXT NOT NULL,
      traditional TEXT,
      pinyin TEXT NOT NULL,
      translation TEXT NOT NULL,
      examples TEXT,
      frequency INTEGER DEFAULT 0
    )
  ''');
  db.execute('''
    CREATE TABLE toponyms (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      chinese TEXT NOT NULL, pinyin TEXT NOT NULL, english TEXT NOT NULL, type TEXT NOT NULL, latitude REAL, longitude REAL, country TEXT
    )
  ''');
  db.execute('''
    CREATE TABLE person_names (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      chinese TEXT NOT NULL, pinyin TEXT NOT NULL, is_surname INTEGER DEFAULT 0, gender TEXT, meaning TEXT
    )
  ''');
  db.execute('''
    CREATE TABLE user_vocabulary (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      word TEXT NOT NULL, pinyin TEXT NOT NULL, translation TEXT NOT NULL, source_type TEXT NOT NULL, saved_date DATETIME NOT NULL
    )
  ''');
  db.execute('''
    CREATE TABLE streak_data (
      id INTEGER PRIMARY KEY, current_streak INTEGER DEFAULT 0, max_streak INTEGER DEFAULT 0, last_active_date TEXT
    )
  ''');
  db.execute('''
    CREATE TABLE news_sources (
      id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, url TEXT NOT NULL, type TEXT DEFAULT 'html', enabled INTEGER DEFAULT 1
    )
  ''');
  db.execute("INSERT INTO streak_data (id, current_streak, max_streak) VALUES (1, 0, 0)");
  db.execute('''
    CREATE TABLE daily_stats (
      id INTEGER PRIMARY KEY AUTOINCREMENT, date TEXT NOT NULL UNIQUE, articles_read INTEGER DEFAULT 0, words_encountered INTEGER DEFAULT 0, words_saved INTEGER DEFAULT 0, reading_minutes INTEGER DEFAULT 0
    )
  ''');
  db.execute('''
    CREATE TABLE reading_history (
      id INTEGER PRIMARY KEY AUTOINCREMENT, file_path TEXT NOT NULL, file_name TEXT NOT NULL, last_position INTEGER DEFAULT 0, last_opened TEXT
    )
  ''');
}

Future<void> createDbWithEntries(File dbFile, List<Map<String, String>> entries) async {
  if (await dbFile.exists()) {
    await dbFile.delete();
  }

  print('🗄️ Создание базы данных...');
  final db = sqlite3.open(dbFile.path);
  
  // Основной словарь
  db.execute('''
    CREATE TABLE dictionary (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      simplified TEXT NOT NULL,
      traditional TEXT,
      pinyin TEXT NOT NULL,
      translation TEXT NOT NULL,
      examples TEXT,
      frequency INTEGER DEFAULT 0
    )
  ''');

  // Топонимы (пустая для совместимости)
  db.execute('''
    CREATE TABLE toponyms (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      chinese TEXT NOT NULL,
      pinyin TEXT NOT NULL,
      english TEXT NOT NULL,
      type TEXT NOT NULL,
      latitude REAL,
      longitude REAL,
      country TEXT
    )
  ''');

  // Личные имена (пустая для совместимости)
  db.execute('''
    CREATE TABLE person_names (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      chinese TEXT NOT NULL,
      pinyin TEXT NOT NULL,
      is_surname INTEGER DEFAULT 0,
      gender TEXT,
      meaning TEXT
    )
  ''');

  // User vocabulary
  db.execute('''
    CREATE TABLE user_vocabulary (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      word TEXT NOT NULL,
      pinyin TEXT NOT NULL,
      translation TEXT NOT NULL,
      source_type TEXT NOT NULL,
      saved_date DATETIME NOT NULL
    )
  ''');

  // Streak data
  db.execute('''
    CREATE TABLE streak_data (
      id INTEGER PRIMARY KEY,
      current_streak INTEGER DEFAULT 0,
      max_streak INTEGER DEFAULT 0,
      last_active_date TEXT
    )
  ''');

  // News sources
  db.execute('''
    CREATE TABLE news_sources (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      url TEXT NOT NULL,
      type TEXT DEFAULT 'html',
      enabled INTEGER DEFAULT 1
    )
  ''');

  db.execute('CREATE INDEX idx_dictionary_simplified ON dictionary(simplified)');

  // Инициализация streak_data
  db.execute("INSERT INTO streak_data (id, current_streak, max_streak) VALUES (1, 0, 0)");

  // Daily stats (пустая для совместимости)
  db.execute('''
    CREATE TABLE daily_stats (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      date TEXT NOT NULL UNIQUE,
      articles_read INTEGER DEFAULT 0,
      words_encountered INTEGER DEFAULT 0,
      words_saved INTEGER DEFAULT 0,
      reading_minutes INTEGER DEFAULT 0
    )
  ''');

  // Reading history
  db.execute('''
    CREATE TABLE reading_history (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      file_path TEXT NOT NULL,
      file_name TEXT NOT NULL,
      last_position INTEGER DEFAULT 0,
      last_opened TEXT
    )
  ''');

  print('💾 Вставка данных (с транзакцией)...');
  db.execute('BEGIN TRANSACTION');
  final stmt = db.prepare("INSERT INTO dictionary (simplified, traditional, pinyin, translation) VALUES (?, ?, ?, ?)");
  
  for (int i = 0; i < entries.length; i++) {
    final entry = entries[i];
    stmt.execute([entry['simplified'], null, entry['pinyin'], entry['translation']]);
    if (i % 10000 == 0 && i > 0) {
      print('   $i/${entries.length}');
    }
  }
  
  stmt.dispose();
  db.execute('COMMIT');

  db.dispose();

  final size = await dbFile.length();
  print('📦 Размер БД: ${(size / 1024 / 1024).toStringAsFixed(2)} MB');
  print('📚 Записей: ${entries.length}');
  
  // Проверка пиньиня
  var testDb = sqlite3.open(dbFile.path);
  var rs = testDb.select('SELECT simplified, pinyin, translation FROM dictionary WHERE pinyin != "" LIMIT 5');
  print('\nПроверка пиньиня:');
  for (var r in rs) {
    print('${r['simplified']} [${r['pinyin']}] - ${r['translation']}');
  }
  testDb.dispose();
}
