import 'package:sqlite3/sqlite3.dart';

void main() {
  final db = sqlite3.open('assets/db/charu_bkrs.db');
  final res = db.select("SELECT * FROM dictionary WHERE simplified='第一个'");
  for (var r in res) {
    print('Simplified: ${r['simplified']}');
    print('Pinyin: ${r['pinyin']}');
    print('Translation: ${r['translation']}');
  }
}
