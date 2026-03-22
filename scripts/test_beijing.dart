import 'package:sqlite3/sqlite3.dart';

void main() {
  var db = sqlite3.open('assets/db/charu_bkrs.db');
  var rs = db.select("SELECT * FROM dictionary WHERE simplified LIKE '%北京%' LIMIT 5");
  for (var r in rs) {
    print('Word: ${r['simplified']}');
    print('Pinyin: ${r['pinyin']}');
    print('Trans: ${r['translation']}');
    print('---');
  }
  db.dispose();
}
