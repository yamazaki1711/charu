import 'package:sqlite3/sqlite3.dart';

void main() {
  var db = sqlite3.open('assets/db/charu_bkrs.db');
  
  var rs = db.select("SELECT * FROM dictionary WHERE simplified = '今年'");
  print('今年: ${rs.length} results');
  for (var r in rs) {
    print('  ${r['simplified']} [${r['pinyin']}] - ${r['translation']}');
  }
  
  // Check around line 267073 in source
  rs = db.select("SELECT * FROM dictionary WHERE simplified LIKE '今%' LIMIT 10");
  print('\nWords starting with 今:');
  for (var r in rs) {
    print('  ${r['simplified']} [${r['pinyin']}]');
  }
  
  db.dispose();
}
