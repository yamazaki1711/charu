import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:sqlite3/sqlite3.dart';

/// Скрипт для выполнения SQL из файла schema.sql
/// 
/// Запуск: dart run scripts/execute_schema.dart
void main() async {
  print('🚀 Выполнение схемы БД CHARU...');

  final dbPath = path.join(Directory.current.path, 'assets', 'db', 'charu_bkrs.db');
  final file = File(dbPath);
  final schemaFile = File(path.join(Directory.current.path, 'schema.sql'));

  // Удаляем старую БД если существует
  if (await file.exists()) {
    await file.delete();
    print('🗑️  Старая БД удалена');
  }

  // Читаем SQL схему
  if (!await schemaFile.exists()) {
    print('❌ Файл schema.sql не найден!');
    exit(1);
  }

  final sql = await schemaFile.readAsString();
  print('📄 Схема загружена (${sql.length} символов)');

  // Создаём новую БД
  final db = sqlite3.open(dbPath);
  print('📁 База данных создана');

  // Выполняем SQL
  print('⚙️  Выполнение SQL-запросов...');
  
  try {
    // Разделяем на отдельные statements
    final statements = sql
        .split(';')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty && !s.startsWith('--'))
        .toList();

    int executed = 0;
    int errors = 0;

    for (final statement in statements) {
      try {
        if (statement.isNotEmpty) {
          db.execute(statement);
          executed++;
          
          // Прогресс каждые 10 запросов
          if (executed % 10 == 0) {
            stdout.write('\r   Выполнено: $executed...');
          }
        }
      } catch (e) {
        // Игнорируем ошибки (некоторые statements могут быть пустыми)
        errors++;
      }
    }

    print('\r✅ Выполнено запросов: $executed');
    if (errors > 0) {
      print('⚠️  Ошибок: $errors (игнорировано)');
    }

  } catch (e) {
    print('❌ Ошибка выполнения: $e');
    db.dispose();
    exit(1);
  }

  db.dispose();

  final size = await file.length();
  print('✅ БД создана: $dbPath');
  print('📦 Размер: ${(size / 1024).toStringAsFixed(2)} KB');
  
  // Проверяем данные
  print('\n📊 Проверка данных...');
  final db2 = sqlite3.open(dbPath);
  
  final tables = [
    ('dictionary', 'Словарь БКРС'),
    ('toponyms', 'Топонимы'),
    ('person_names', 'Личные имена'),
    ('news_sources', 'Источники новостей'),
    ('streak_data', 'Ударный режим'),
  ];

  for (final table in tables) {
    try {
      final result = db2.select('SELECT COUNT(*) as count FROM ${table.$1}');
      final count = result.first['count'] ?? 0;
      print('   ✅ ${table.$2}: $count записей');
    } catch (e) {
      print('   ❌ ${table.$2}: ошибка - $e');
    }
  }

  db2.dispose();
  print('\n✨ Готово!');
}
