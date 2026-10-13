import 'dart:io';

void main() {
  final dbFiles = [
    'assets/db/charu_bkrs.db',
    'assets/db/charu_bkrs_large.db',
    'assets/db/charu_bkrs.db',
  ];

  for (final path in dbFiles) {
    final file = File(path);
    if (file.existsSync()) {
      final size = file.lengthSync();
      final sizeMb = (size / 1024 / 1024).toStringAsFixed(1);
      print('✅ $path: ${sizeMb}MB');

      // Read first bytes to check if it's a valid SQLite DB
      final bytes = file.openSync().readSync(16);
      final header = String.fromCharCodes(bytes.take(6));
      print('   Header: "$header" (${header == "SQLite" ? "VALID" : "INVALID"})');
    } else {
      print('❌ $path: NOT FOUND');
    }
  }

  // Also check the dabkrs file in project root
  final dabkrs = File('dabkrs');
  if (dabkrs.existsSync()) {
    final size = dabkrs.lengthSync();
    final sizeMb = (size / 1024 / 1024).toStringAsFixed(1);
    print('✅ dabkrs: ${sizeMb}MB');
    final bytes = dabkrs.openSync().readSync(16);
    final header = String.fromCharCodes(bytes.take(6));
    print('   Header: "$header" (${header == "SQLite" ? "VALID SQLite" : "NOT SQLite - check format"})');
  }
}
