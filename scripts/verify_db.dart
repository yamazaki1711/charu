import 'package:sqlite3/sqlite3.dart';

void main() {
  print('Проверка charu_bkrs_large.db:');
  var db = sqlite3.open('assets/db/charu_bkrs_large.db');
  
  try {
    var rs = db.select('SELECT COUNT(*) as count FROM dictionary');
    print('dictionary: ${rs.first['count']} записей');
    
    var words = db.select('SELECT * FROM dictionary LIMIT 5');
    print('\nПримеры слов:');
    for (var w in words) {
      print('${w['simplified']} - ${w['pinyin']} - ${w['translation']}');
    }
  } catch(e) {
    print('Ошибка: $e');
  }
  
  db.dispose();
}
