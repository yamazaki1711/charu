import 'dart:io';
import 'package:path/path.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  final dbPath = join(Directory.current.path, 'assets', 'db', 'charu_dict.db');
  
  if (!File(dbPath).existsSync()) {
    print('❌ БД не найдена: $dbPath');
    exit(1);
  }
  
  final db = sqlite3.open(dbPath);
  
  print('=== Таблицы в БД ===');
  final tables = db.select("SELECT name FROM sqlite_master WHERE type='table'");
  for (final t in tables) {
    print('  - ${t["name"]}');
  }
  
  print('\n=== Поиск тестовых слов ===');
  final testWords = ['的', '北京', '学习', '图书馆', '是', '我', '中国', '天气', '今天'];
  
  for (final word in testWords) {
    final rs = db.select(
      'SELECT simplified, pinyin, translation FROM dictionary WHERE simplified = ? LIMIT 1',
      [word]
    );
    if (rs.isNotEmpty) {
      final pinyin = rs.first["pinyin"] ?? '';
      final trans = (rs.first["translation"] as String?) ?? '';
      print('✅ $word: $pinyin — $trans');
    } else {
      print('❌ $word: НЕ НАЙДЕН');
    }
  }
  
  print('\n=== Статистика ===');
  final count = db.select('SELECT COUNT(*) as c FROM dictionary').first["c"];
  print('Всего слов: $count');
  
  db.dispose();
  print('\n✨ Проверка завершена!');
}
