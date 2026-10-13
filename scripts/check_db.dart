import 'dart:io';
import 'package:path/path.dart';
import 'package:sqlite3/sqlite3.dart';

void main() async {
  final dbPath = join(Directory.current.path, 'assets', 'db', 'charu_bkrs.db');
  
  if (!await File(dbPath).exists()) {
    print('❌ БД не найдена!');
    exit(1);
  }
  
  final db = sqlite3.open(dbPath);
  
  print('📊 Проверка БД CHARU...\n');
  
  // Проверка таблиц
  final tables = ['dictionary', 'toponyms', 'person_names', 'news_sources', 'streak_data'];
  
  for (final table in tables) {
    try {
      final rs = db.select('SELECT COUNT(*) as count FROM $table');
      final count = rs.first['count'];
      print('✅ $table: $count записей');
    } catch (e) {
      print('❌ $table: ошибка - $e');
    }
  }
  
  print('\n📚 Примеры слов из словаря:');
  final words = db.select('SELECT simplified, pinyin, translation FROM dictionary LIMIT 5');
  for (final word in words) {
    print('   ${word['simplified']} (${word['pinyin']}) — ${word['translation']}');
  }
  
  print('\n🗺️ Топонимы:');
  final topos = db.select('SELECT chinese, pinyin, english FROM toponyms LIMIT 3');
  for (final topo in topos) {
    print('   ${topo['chinese']} (${topo['pinyin']}) — ${topo['english']}');
  }
  
  print('\n👤 Личные имена:');
  final names = db.select('SELECT chinese, pinyin, is_surname FROM person_names LIMIT 3');
  for (final name in names) {
    final type = name['is_surname'] == 1 ? 'фамилия' : 'имя';
    print('   ${name['chinese']} (${name['pinyin']}) — $type');
  }
  
  db.dispose();
  print('\n✨ БД готова к работе!');
}
