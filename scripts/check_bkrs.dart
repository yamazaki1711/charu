import 'dart:io';
import 'package:path/path.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  final dbPath = join(Directory.current.path, 'assets', 'db', 'charu_bkrs.db');
  
  if (!File(dbPath).existsSync()) {
    print('❌ БД не найдена: $dbPath');
    exit(1);
  }
  
  final db = sqlite3.open(dbPath);
  
  print('=== Таблицы в charu_bkrs.db ===');
  final tables = db.select("SELECT name FROM sqlite_master WHERE type='table'");
  for (final t in tables) {
    final count = db.select('SELECT COUNT(*) as c FROM ${t["name"]}').first["c"];
    print('  - ${t["name"]}: $count записей');
  }
  
  print('\n=== Поиск тестовых слов (С ПИНЬИНЕМ) ===');
  final testWords = ['的', '北京', '学习', '图书馆', '是', '我', '中国', '天气', '今天', '人', '了'];
  
  for (final word in testWords) {
    final rs = db.select(
      'SELECT simplified, pinyin, translation FROM dictionary WHERE simplified = ? LIMIT 1',
      [word]
    );
    if (rs.isNotEmpty) {
      final pinyin = rs.first["pinyin"] ?? '';
      final trans = (rs.first["translation"] as String?) ?? '';
      print('✅ $word:');
      print('   пиньинь: "$pinyin"');
      print('   перевод: $trans');
    } else {
      print('❌ $word: НЕ НАЙДЕН');
    }
  }
  
  print('\n=== Слова с пиньинем ===');
  final withPinyin = db.select('SELECT COUNT(*) as c FROM dictionary WHERE pinyin != ""');
  print('Всего с пиньинем: ${withPinyin.first["c"]}');
  
  final sample = db.select('SELECT simplified, pinyin FROM dictionary WHERE pinyin != "" LIMIT 5');
  print('Примеры:');
  for (final s in sample) {
    print('  ${s["simplified"]} [${s["pinyin"]}]');
  }
  
  db.dispose();
}
