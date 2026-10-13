import 'dart:io' show Directory, File;

import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

/// Database helper to manage the SQLite connection to the pre-populated
/// dictionary bases (BKRS, Toponyms, Person Names) and user data.
///
/// Uses TWO databases:
/// - [_dictDbName]: Read-only pre-populated dictionary (BKRS, toponyms, names)
/// - [_userDbName]: Read-write user data (vocabulary, stats, progress)
///
/// On Web, uses in-memory mock data since sqflite is not supported.
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _dictDatabase;
  static Database? _userDatabase;

  // In-memory dictionary for Web (since sqflite doesn't work on Web)
  static final Map<String, Map<String, String>> _webDictionary = {
    '北京': {'pinyin': 'Běi jīng', 'translation': 'Пекин (столица Китая)'},
    '中国': {'pinyin': 'Zhōng guó', 'translation': 'Китай'},
    '学习': {'pinyin': 'xué xí', 'translation': 'учиться, изучать'},
    '学生': {'pinyin': 'xué sheng', 'translation': 'студент, учащийся'},
    '老师': {'pinyin': 'lǎo shī', 'translation': 'учитель'},
    '朋友': {'pinyin': 'péng you', 'translation': 'друг'},
    '图书馆': {'pinyin': 'tú shū guǎn', 'translation': 'библиотека'},
    '经济': {'pinyin': 'jīng jì', 'translation': 'экономика'},
    '发展': {'pinyin': 'fā zhǎn', 'translation': 'развитие'},
    '科技': {'pinyin': 'kē jì', 'translation': 'наука и техника'},
    '新闻': {'pinyin': 'xīn wén', 'translation': 'новости'},
    '阅读': {'pinyin': 'yuè dú', 'translation': 'читать, чтение'},
    '汉字': {'pinyin': 'Hàn zì', 'translation': 'китайские иероглифы'},
    '拼音': {'pinyin': 'pīn yīn', 'translation': 'пиньинь'},
    '翻译': {'pinyin': 'fān yì', 'translation': 'перевод, переводить'},
    '词典': {'pinyin': 'cí diǎn', 'translation': 'словарь'},
    '今天': {'pinyin': 'jīn tiān', 'translation': 'сегодня'},
    '明天': {'pinyin': 'míng tiān', 'translation': 'завтра'},
    '昨天': {'pinyin': 'zuó tiān', 'translation': 'вчера'},
    '天气': {'pinyin': 'tiān qì', 'translation': 'погода'},
    '工作': {'pinyin': 'gōng zuò', 'translation': 'работа, работать'},
    '公司': {'pinyin': 'gōng sī', 'translation': 'компания'},
    '问题': {'pinyin': 'wèn tí', 'translation': 'вопрос, проблема'},
    '答案': {'pinyin': 'dá àn', 'translation': 'ответ'},
    '文化': {'pinyin': 'wén huà', 'translation': 'культура'},
    '历史': {'pinyin': 'lì shǐ', 'translation': 'история'},
    '懒觉': {'pinyin': 'lǎn jiào', 'translation': 'поспать подольше, проспать'},
  };

  DatabaseHelper._init();

  /// Pre-populated dictionary database name.
  final String _dictDbName = 'charu_bkrs.db';

  /// User writable database name.
  final String _userDbName = 'charu_user.db';

  // ---------------------------------------------------------------------------
  // DICTIONARY DATABASE (read-only, pre-populated from assets)
  // ---------------------------------------------------------------------------

  /// Returns the read-only dictionary database (BKRS + toponyms + names).
  Future<Database> get database async {
    if (_dictDatabase != null) return _dictDatabase!;

    if (kIsWeb) {
      throw UnsupportedError(
          'SQLite not supported on Web. Use lookupWeb() instead.');
    }

    _dictDatabase = await _initDictDB(_dictDbName);
    return _dictDatabase!;
  }

  Future<Database> _initDictDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    var exists = await databaseExists(path);

    // Версионирование ассета: маркер assets/db/asset_version.txt.
    // При смене версии рабочая копия словаря перезаливается (она
    // read-only, пользовательские данные живут в charu_user.db) —
    // иначе новые источники/статьи не доезжали при установке поверх.
    if (exists) {
      try {
        final marker = await rootBundle
            .loadString('assets/db/asset_version.txt')
            .then((s) => s.trim());
        final prefs = await SharedPreferences.getInstance();
        final stored = prefs.getString('dict_asset_version') ?? '1';
        if (marker != stored) {
          await File(path).delete();
          await prefs.setString('dict_asset_version', marker);
          exists = false;
          debugPrint('[DB] Asset version $marker != $stored — re-copying');
        }
      } catch (_) {
        // маркера нет (старый ассет) — просто копируем при отсутствии
      }
    }

    if (!exists) {
      try {
        await Directory(dirname(path)).create(recursive: true);
      } catch (_) {}

      debugPrint('[DB] Copying dictionary from assets...');
      ByteData data = await rootBundle.load(join('assets', 'db', filePath));
      List<int> bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );

      await File(path).writeAsBytes(bytes, flush: true);
      debugPrint('[DB] Dictionary copied: ${(bytes.length / 1024 / 1024).toStringAsFixed(1)}MB');
    }

    final db = await openDatabase(path, readOnly: true);
    debugPrint('[DB] Dictionary DB opened (readOnly)');

    // Log available tables for debugging
    try {
      final tables = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name");
      final tableNames = tables.map((t) => t['name']).toList();
      debugPrint('[DB] Dictionary tables: $tableNames');

      for (final t in tables) {
        final name = t['name'] as String;
        if (!name.startsWith('sqlite_') && !name.startsWith('android_')) {
          final count = Sqflite.firstIntValue(
              await db.rawQuery('SELECT COUNT(*) FROM "$name"'));
          debugPrint('[DB]   $name: $count rows');
        }
      }
    } catch (e) {
      debugPrint('[DB] Error listing tables: $e');
    }

    return db;
  }

  // ---------------------------------------------------------------------------
  // USER DATABASE (read-write, created on first launch)
  // ---------------------------------------------------------------------------

  /// Returns the writable user database (vocabulary, stats, progress).
  Future<Database> get userDatabase async {
    if (_userDatabase != null) return _userDatabase!;

    if (kIsWeb) {
      throw UnsupportedError('SQLite not supported on Web.');
    }

    _userDatabase = await _initUserDB();
    return _userDatabase!;
  }

  Future<Database> _initUserDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _userDbName);

    debugPrint('[DB] Opening user DB at: $path');

    final db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        debugPrint('[DB] Creating user tables...');

        await db.execute('''
          CREATE TABLE IF NOT EXISTS user_vocabulary (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            word TEXT NOT NULL,
            pinyin TEXT NOT NULL,
            translation TEXT NOT NULL,
            source_type TEXT NOT NULL,
            saved_date DATETIME NOT NULL,
            last_reviewed DATETIME,
            review_count INTEGER DEFAULT 0,
            notes TEXT,
            UNIQUE(word, source_type)
          )
        ''');

        await db.execute('''
          CREATE TABLE IF NOT EXISTS daily_stats (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            date TEXT NOT NULL UNIQUE,
            articles_read INTEGER DEFAULT 0,
            words_encountered INTEGER DEFAULT 0,
            words_saved INTEGER DEFAULT 0,
            reading_minutes INTEGER DEFAULT 0,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
            updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
          )
        ''');

        await db.execute('''
          CREATE TABLE IF NOT EXISTS streak_data (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            current_streak INTEGER DEFAULT 0,
            max_streak INTEGER DEFAULT 0,
            last_active_date TEXT,
            updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
          )
        ''');

        await db.execute('''
          INSERT OR IGNORE INTO streak_data (id, current_streak, max_streak, last_active_date)
          VALUES (1, 0, 0, NULL)
        ''');

        await db.execute('''
          CREATE TABLE IF NOT EXISTS reading_history (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            file_path TEXT NOT NULL,
            file_name TEXT NOT NULL,
            file_type TEXT NOT NULL,
            last_position INTEGER DEFAULT 0,
            last_opened DATETIME NOT NULL,
            progress_percent REAL DEFAULT 0,
            total_length INTEGER DEFAULT 0
          )
        ''');

        await db.execute('''
          CREATE TABLE IF NOT EXISTS bookmarks (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            file_path TEXT NOT NULL,
            position INTEGER NOT NULL,
            note TEXT,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP
          )
        ''');

        // Indexes
        await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_user_vocabulary_word ON user_vocabulary(word)');
        await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_daily_stats_date ON daily_stats(date)');
        await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_reading_history_path ON reading_history(file_path)');

        debugPrint('[DB] User tables created successfully');
      },
    );

    debugPrint('[DB] User DB opened (read-write)');
    return db;
  }

  // ---------------------------------------------------------------------------
  // WEB HELPERS
  // ---------------------------------------------------------------------------

  /// Look up a word in the in-memory dictionary (for Web).
  Map<String, String>? lookupWeb(String word) {
    return _webDictionary[word];
  }

  // ---------------------------------------------------------------------------
  // CLEANUP
  // ---------------------------------------------------------------------------

  /// Closes all database connections.
  Future<void> close() async {
    if (!kIsWeb) {
      if (_dictDatabase != null) {
        await _dictDatabase!.close();
        _dictDatabase = null;
      }
      if (_userDatabase != null) {
        await _userDatabase!.close();
        _userDatabase = null;
      }
    }
  }
}
