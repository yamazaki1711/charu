import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../../core/log.dart';
import '../../domain/model/file_models.dart';
import '../../domain/model/library_models.dart';
import '../../domain/repository/file_repository.dart';
import '../../domain/repository/library_repository.dart';
import '../local/database_helper.dart';
import '../remote/wikisource_service.dart';

class LibraryRepositoryImpl implements ILibraryRepository {
  final DatabaseHelper _dbHelper;
  final WikisourceService _wikisourceService;
  final IFileRepository _fileRepository;

  LibraryRepositoryImpl({
    DatabaseHelper? dbHelper,
    WikisourceService? wikisourceService,
    required IFileRepository fileRepository,
  })  : _dbHelper = dbHelper ?? DatabaseHelper.instance,
        _wikisourceService = wikisourceService ?? WikisourceService(),
        _fileRepository = fileRepository;

  @override
  Future<List<LibraryBook>> getCatalog() async {
    final raw = await rootBundle.loadString('assets/library/catalog.json');
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final entries = (json['books'] as List)
        .cast<Map<String, dynamic>>()
        .map(LibraryBook.fromCatalogJson)
        .toList();

    final db = await _dbHelper.userDatabase;
    final downloaded = await db.query('library_books');
    final byId = {for (final row in downloaded) row['id'] as String: row};

    return entries.map((entry) {
      final row = byId[entry.id];
      if (row == null) return entry;
      return entry.copyWithDownload(
        filePath: row['file_path'] as String,
        downloadedAt: DateTime.parse(row['downloaded_at'] as String),
        charCount: row['char_count'] as int? ?? 0,
      );
    }).toList();
  }

  @override
  Future<LibraryBook> downloadBook(
    LibraryBook book, {
    bool convertToSimplified = true,
  }) async {
    final text = await _wikisourceService.fetchBookText(
      book.wikisourceTitle,
      convertToSimplified: convertToSimplified,
    );

    final docsDir = await getApplicationDocumentsDirectory();
    final booksDir = Directory(path.join(docsDir.path, 'books'));
    await booksDir.create(recursive: true);
    final filePath = path.join(booksDir.path, '${book.id}.txt');
    await File(filePath).writeAsString(text, flush: true);

    final downloadedAt = DateTime.now();
    final db = await _dbHelper.userDatabase;
    await db.insert(
      'library_books',
      {
        'id': book.id,
        'wikisource_title': book.wikisourceTitle,
        'author': book.author,
        'title_display': book.titleDisplay,
        'file_path': filePath,
        'format': 'txt',
        'downloaded_at': downloadedAt.toIso8601String(),
        'char_count': text.length,
        'source_url': book.sourceUrl,
      },
    );

    // Plug into the existing reader/progress/bookmarks pipeline.
    await _fileRepository.addToHistory(LocalFile(
      id: filePath,
      path: filePath,
      name: book.titleDisplay,
      type: FileFormat.txt,
      lastOpened: downloadedAt,
    ));

    log('[Library] Downloaded "${book.titleDisplay}": ${text.length} chars');

    return book.copyWithDownload(
      filePath: filePath,
      downloadedAt: downloadedAt,
      charCount: text.length,
    );
  }

  @override
  Future<void> deleteBook(LibraryBook book) async {
    if (!book.isDownloaded) return;
    final filePath = book.filePath!;

    try {
      final file = File(filePath);
      if (await file.exists()) await file.delete();
    } catch (e) {
      log('[Library] Delete file error: $e');
    }

    final db = await _dbHelper.userDatabase;
    await db.delete('library_books', where: 'id = ?', whereArgs: [book.id]);
    await _fileRepository.removeFileFromHistory(filePath);
  }
}
