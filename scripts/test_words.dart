import 'package:sqlite3/sqlite3.dart';

void main() {
  var db = sqlite3.open('assets/db/charu_bkrs.db');
  
  var words = ['北京', '学习', 'xuekou', '户外', '教授'];
  for (var word in words) {
    var rs = db.select("SELECT * FROM dictionary WHERE simplified LIKE '%$word%' LIMIT 3");
    print('=== $word ===');
    for (var r in rs) {
      print('${r['simplified']} [${r['pinyin']}] - ${r['translation']}');
    }
    if (rs.isEmpty) print('(не найдено)');
  }
  
  db.dispose();
}
