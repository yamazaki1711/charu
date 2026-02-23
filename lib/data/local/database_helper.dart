import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// Database helper to manage the SQLite connection to the pre-populated
/// dictionary bases (BKRS, Toponyms, Person Names).
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  /// Defines the name of the prepopulated database.
  /// Expecting 'charu_dict.db' to be added to assets/db/.
  final String _dbName = 'charu_dict.db';

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB(_dbName);
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    // Check if the database already exists.
    final exists = await databaseExists(path);

    if (!exists) {
      // If the database does not exist, copy it from assets.
      try {
        await Directory(dirname(path)).create(recursive: true);
      } catch (_) {}

      // Copy from asset
      ByteData data = await rootBundle.load(join('assets', 'db', filePath));
      List<int> bytes =
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);

      // Write and flush the bytes written
      await File(path).writeAsBytes(bytes, flush: true);
    }

    // Open the database
    return await openDatabase(path, readOnly: true); // Dictionary is read-only
  }

  /// Closes the connection.
  Future<void> close() async {
    final db = await instance.database;
    db.close();
  }
}
