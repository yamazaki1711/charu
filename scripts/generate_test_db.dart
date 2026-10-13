import 'dart:io';
import 'package:path/path.dart';
import 'package:sqlite3/sqlite3.dart';

/// Скрипт для генерации тестовой базы данных charu_bkrs.db
/// 
/// Запуск: dart run scripts/generate_test_db.dart
void main() async {
  print('🚀 Генерация тестовой БД CHARU...');

  final dbPath = join(Directory.current.path, 'assets', 'db', 'charu_bkrs.db');
  final file = File(dbPath);

  // Удаляем старую БД если существует
  if (await file.exists()) {
    await file.delete();
    print('🗑️  Старая БД удалена');
  }

  // Создаём новую БД
  final db = sqlite3.open(dbPath);

  print('📁 Создание таблиц...');
  _createTables(db);

  print('📝 Заполнение тестовыми данными...');
  _insertTestData(db);

  print('📊 Заполнение демонстрационными словарями...');
  _insertDictionaryData(db);

  db.dispose();

  final size = await file.length();
  print('✅ БД создана: $dbPath');
  print('📦 Размер: ${(size / 1024).toStringAsFixed(2)} KB');
}

void _createTables(Database db) {
  // Dictionary table
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

  // Toponyms table
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

  // Person names table
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

  // User vocabulary table
  db.execute('''
    CREATE TABLE user_vocabulary (
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

  // Daily stats table
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

  // Streak data table
  db.execute('''
    CREATE TABLE streak_data (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      current_streak INTEGER DEFAULT 0,
      max_streak INTEGER DEFAULT 0,
      last_active_date TEXT,
      updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
    )
  ''');

  // Cached articles table
  db.execute('''
    CREATE TABLE cached_articles (
      id TEXT PRIMARY KEY,
      source_id INTEGER,
      title TEXT NOT NULL,
      content TEXT,
      url TEXT,
      summary TEXT,
      thumbnail_url TEXT,
      cached_date DATETIME NOT NULL,
      expires_date DATETIME,
      is_pinned INTEGER DEFAULT 0,
      cache_type TEXT DEFAULT 'auto'
    )
  ''');

  // News sources table
  db.execute('''
    CREATE TABLE news_sources (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      url TEXT NOT NULL,
      type TEXT DEFAULT 'rss',
      enabled INTEGER DEFAULT 1,
      last_updated DATETIME,
      icon_url TEXT
    )
  ''');

  // Reading history table
  db.execute('''
    CREATE TABLE reading_history (
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

  // Bookmarks table
  db.execute('''
    CREATE TABLE bookmarks (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      file_path TEXT NOT NULL,
      position INTEGER NOT NULL,
      note TEXT,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP
    )
  ''');

  // Индексы
  db.execute('CREATE INDEX idx_dictionary_simplified ON dictionary(simplified)');
  db.execute('CREATE INDEX idx_dictionary_traditional ON dictionary(traditional)');
  db.execute('CREATE INDEX idx_toponyms_chinese ON toponyms(chinese)');
  db.execute('CREATE INDEX idx_person_names_chinese ON person_names(chinese)');
  db.execute('CREATE INDEX idx_user_vocabulary_word ON user_vocabulary(word)');
  db.execute('CREATE INDEX idx_daily_stats_date ON daily_stats(date)');

  print('   ✅ Таблицы созданы');
}

void _insertTestData(Database db) {
  // Инициализация streak_data
  db.execute("INSERT INTO streak_data (id, current_streak, max_streak, last_active_date) VALUES (1, 0, 0, NULL)");

  // Источники новостей
  db.execute("INSERT INTO news_sources (name, url, type, enabled) VALUES ('Baidu Baijiahao', 'https://baijiahao.baidu.com', 'html', 1)");
  db.execute("INSERT INTO news_sources (name, url, type, enabled) VALUES ('Sina News', 'https://news.sina.com.cn', 'rss', 1)");
  db.execute("INSERT INTO news_sources (name, url, type, enabled) VALUES ('People''s Daily', 'http://en.people.cn', 'rss', 1)");

  print('   ✅ Тестовые данные добавлены');
}

void _insertDictionaryData(Database db) {
  // Базовые слова БКРС для тестирования
  final dictionaryData = [
    _map('图书馆', '圖書館', 'tú shū guǎn', 'библиотека'),
    _map('中国', '中國', 'Zhōng guó', 'Китай'),
    _map('北京', '北京', 'Běi jīng', 'Пекин'),
    _map('学习', '學習', 'xué xí', 'учиться, изучать'),
    _map('学生', '學生', 'xué sheng', 'студент, учащийся'),
    _map('老师', '老師', 'lǎo shī', 'учитель'),
    _map('朋友', '朋友', 'péng you', 'друг'),
    _map('经济', '經濟', 'jīng jì', 'экономика'),
    _map('发展', '發展', 'fā zhǎn', 'развитие'),
    _map('科技', '科技', 'kē jì', 'наука и техника'),
    _map('人工智能', '人工智能', 'rén gōng zhì néng', 'искусственный интеллект'),
    _map('新闻', '新聞', 'xīn wén', 'новости'),
    _map('阅读', '閱讀', 'yuè dú', 'читать, чтение'),
    _map('汉字', '漢字', 'Hàn zì', 'китайские иероглифы'),
    _map('拼音', '拼音', 'pīn yīn', 'пиньинь'),
    _map('翻译', '翻譯', 'fān yì', 'перевод, переводить'),
    _map('词典', '詞典', 'cí diǎn', 'словарь'),
    _map('今天', '今天', 'jīn tiān', 'сегодня'),
    _map('明天', '明天', 'míng tiān', 'завтра'),
    _map('昨天', '昨天', 'zuó tiān', 'вчера'),
    _map('天气', '天氣', 'tiān qì', 'погода'),
    _map('工作', '工作', 'gōng zuò', 'работа, работать'),
    _map('公司', '公司', 'gōng sī', 'компания'),
    _map('问题', '問題', 'wèn tí', 'вопрос, проблема'),
    _map('答案', '答案', 'dá àn', 'ответ'),
    _map('上海', '上海', 'Shàng hǎi', 'Шанхай'),
    _map('广东', '廣東', 'Guǎng dōng', 'Гуандун'),
    _map('深圳', '深圳', 'Shēn zhèn', 'Шэньчжэнь'),
    _map('文化', '文化', 'wén huà', 'культура'),
    _map('历史', '歷史', 'lì shǐ', 'история'),
  ];

  // Топонимы
  final toponymData = [
    _topo('北京', 'Běi jīng', 'Beijing', 'Город', 39.9042, 116.4074, 'Китай'),
    _topo('上海', 'Shàng hǎi', 'Shanghai', 'Город', 31.2304, 121.4737, 'Китай'),
    _topo('深圳', 'Shēn zhèn', 'Shenzhen', 'Город', 22.5431, 114.0579, 'Китай'),
    _topo('广东', 'Guǎng dōng', 'Guangdong', 'Провинция', 23.3790, 113.7633, 'Китай'),
    _topo('中国', 'Zhōng guó', 'China', 'Страна', 35.8617, 104.1954, 'Китай'),
    _topo('长城', 'Cháng chéng', 'Great Wall', 'Достопримечательность', 40.4319, 116.5704, 'Китай'),
    _topo('黄河', 'Huáng hé', 'Yellow River', 'Река', 35.0, 103.0, 'Китай'),
    _topo('长江', 'Cháng jiāng', 'Yangtze River', 'Река', 31.0, 110.0, 'Китай'),
  ];

  // Личные имена
  final personNameData = [
    _name('王', 'Wáng', 1, 'U', 'король, монарх'),
    _name('李', 'Lǐ', 1, 'U', 'слива'),
    _name('张', 'Zhāng', 1, 'U', 'растягивать'),
    _name('刘', 'Liú', 1, 'U', 'убивать'),
    _name('陈', 'Chén', 1, 'U', 'выставлять'),
    _name('明', 'Míng', 0, 'M', 'яркий, светлый'),
    _name('华', 'Huá', 0, 'U', 'цветок, великолепие'),
    _name('伟', 'Wěi', 0, 'M', 'великий'),
    _name('芳', 'Fāng', 0, 'F', 'ароматный'),
    _name('娜', 'Nà', 0, 'F', 'изящная'),
  ];

  // Вставка данных
  final insertDict = db.prepare("INSERT INTO dictionary (simplified, traditional, pinyin, translation) VALUES (?, ?, ?, ?)");
  for (final item in dictionaryData) {
    insertDict.execute([item['simplified'], item['traditional'], item['pinyin'], item['translation']]);
  }

  final insertTopo = db.prepare("INSERT INTO toponyms (chinese, pinyin, english, type, latitude, longitude, country) VALUES (?, ?, ?, ?, ?, ?, ?)");
  for (final item in toponymData) {
    insertTopo.execute([item['chinese'], item['pinyin'], item['english'], item['type'], item['latitude'], item['longitude'], item['country']]);
  }

  final insertName = db.prepare("INSERT INTO person_names (chinese, pinyin, is_surname, gender, meaning) VALUES (?, ?, ?, ?, ?)");
  for (final item in personNameData) {
    insertName.execute([item['chinese'], item['pinyin'], item['is_surname'], item['gender'], item['meaning']]);
  }

  print('   ✅ Словарные данные добавлены (${dictionaryData.length} слов, ${toponymData.length} топонимов, ${personNameData.length} имён)');
}

Map<String, dynamic> _map(String simplified, String traditional, String pinyin, String translation) {
  return {'simplified': simplified, 'traditional': traditional, 'pinyin': pinyin, 'translation': translation};
}

Map<String, dynamic> _topo(String chinese, String pinyin, String english, String type, double lat, double lng, String country) {
  return {'chinese': chinese, 'pinyin': pinyin, 'english': english, 'type': type, 'latitude': lat, 'longitude': lng, 'country': country};
}

Map<String, dynamic> _name(String chinese, String pinyin, int isSurname, String gender, String meaning) {
  return {'chinese': chinese, 'pinyin': pinyin, 'is_surname': isSurname, 'gender': gender, 'meaning': meaning};
}
