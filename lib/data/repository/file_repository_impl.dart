import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart' as fp;
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

import '../../domain/model/file_models.dart';
import '../../domain/repository/file_repository.dart';
import '../local/database_helper.dart';

/// Implementation of file repository for local file operations
class FileRepositoryImpl implements IFileRepository {
  final DatabaseHelper _dbHelper;
  final fp.FilePicker _filePicker;

  FileRepositoryImpl({
    DatabaseHelper? dbHelper,
    fp.FilePicker? filePicker,
  })  : _dbHelper = dbHelper ?? DatabaseHelper.instance,
        _filePicker = filePicker ?? fp.FilePicker.platform;

  @override
  Future<LocalFile?> pickFile() async {
    try {
      final result = await _filePicker.pickFiles(
        type: fp.FileType.custom,
        allowedExtensions: ['txt', 'html', 'htm', 'epub'],
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        return null;
      }

      final file = result.files.first;
      final filePath = file.path;

      if (filePath == null) {
        return null;
      }

      final fileType = _getFileType(path.extension(filePath));

      // Save to history
      await _saveToHistory(LocalFile(
        id: filePath,
        path: filePath,
        name: file.name,
        type: fileType,
        lastOpened: DateTime.now(),
      ));

      return LocalFile(
        id: filePath,
        path: filePath,
        name: file.name,
        type: fileType,
        lastOpened: DateTime.now(),
      );
    } catch (e) {
      debugPrint('❌ File pick error: $e');
      return null;
    }
  }

  FileFormat _getFileType(String extension) {
    final ext = extension.toLowerCase();
    if (ext == '.txt') return FileFormat.txt;
    if (ext == '.html' || ext == '.htm') return FileFormat.html;
    if (ext == '.epub') return FileFormat.epub;
    return FileFormat.unknown;
  }

  FileFormat _getFileTypeFromDb(String extension) {
    final ext = extension.toLowerCase().replaceFirst('.', '');
    if (ext == 'txt') return FileFormat.txt;
    if (ext == 'html' || ext == 'htm') return FileFormat.html;
    if (ext == 'epub') return FileFormat.epub;
    return FileFormat.unknown;
  }

  @override
  Future<String> readFile(String filePath) async {
    try {
      final file = File(filePath);

      if (!await file.exists()) {
        throw FileSystemException('File not found', filePath);
      }

      // Read with UTF-8 encoding (most common for Chinese texts)
      // TODO: Add proper encoding detection for GBK, GB2312, Big5
      final content = await file.readAsString(encoding: utf8);

      // Update last opened
      await _updateLastOpened(filePath);

      return content;
    } catch (e) {
      debugPrint('❌ File read error: $e');
      rethrow;
    }
  }

  @override
  Future<List<LocalFile>> getRecentFiles() async {
    try {
      final db = await _dbHelper.userDatabase;
      
      final List<Map<String, dynamic>> maps = await db.query(
        'reading_history',
        orderBy: 'last_opened DESC',
        limit: 20,
      );

      return maps.map((m) {
        return LocalFile(
          id: m['file_path'] as String,
          path: m['file_path'] as String,
          name: m['file_name'] as String,
          type: _getFileTypeFromDb(m['file_type'] as String),
          lastOpened: DateTime.parse(m['last_opened'] as String),
          lastPosition: m['last_position'] as int? ?? 0,
          progressPercent: (m['progress_percent'] as num?)?.toDouble() ?? 0,
          totalLength: m['total_length'] as int? ?? 0,
        );
      }).toList();
    } catch (e) {
      debugPrint('❌ Get recent files error: $e');
      return [];
    }
  }

  @override
  Future<void> saveReadingPosition(String filePath, int position) async {
    try {
      final db = await _dbHelper.userDatabase;
      
      // Get file info
      final file = File(filePath);
      final totalLength = await file.length();
      
      final progress = totalLength > 0 
          ? (position / totalLength) * 100 
          : 0;

      await db.update(
        'reading_history',
        {
          'last_position': position,
          'progress_percent': progress,
          'last_opened': DateTime.now().toIso8601String(),
        },
        where: 'file_path = ?',
        whereArgs: [filePath],
      );
    } catch (e) {
      debugPrint('❌ Save position error: $e');
    }
  }

  @override
  Future<void> removeFileFromHistory(String filePath) async {
    try {
      final db = await _dbHelper.userDatabase;
      await db.delete(
        'reading_history',
        where: 'file_path = ?',
        whereArgs: [filePath],
      );
    } catch (e) {
      debugPrint('❌ Remove file error: $e');
    }
  }

  @override
  Future<void> clearHistory() async {
    try {
      final db = await _dbHelper.userDatabase;
      await db.delete('reading_history');
    } catch (e) {
      debugPrint('❌ Clear history error: $e');
    }
  }

  @override
  Future<LocalFile?> getFileByPath(String filePath) async {
    try {
      final db = await _dbHelper.userDatabase;
      
      final List<Map<String, dynamic>> maps = await db.query(
        'reading_history',
        where: 'file_path = ?',
        whereArgs: [filePath],
        limit: 1,
      );

      if (maps.isEmpty) {
        return null;
      }

      final m = maps.first;
      return LocalFile(
        id: m['file_path'] as String,
        path: m['file_path'] as String,
        name: m['file_name'] as String,
        type: _getFileTypeFromDb(m['file_type'] as String),
        lastOpened: DateTime.parse(m['last_opened'] as String),
        lastPosition: m['last_position'] as int? ?? 0,
        progressPercent: (m['progress_percent'] as num?)?.toDouble() ?? 0,
        totalLength: m['total_length'] as int? ?? 0,
      );
    } catch (e) {
      debugPrint('❌ Get file by path error: $e');
      return null;
    }
  }

  // Private helpers

  Future<void> _saveToHistory(LocalFile file) async {
    try {
      final db = await _dbHelper.userDatabase;
      
      await db.insert(
        'reading_history',
        {
          'file_path': file.path,
          'file_name': file.name,
          'file_type': file.type.extension,
          'last_opened': DateTime.now().toIso8601String(),
          'last_position': 0,
          'progress_percent': 0,
          'total_length': 0,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      debugPrint('❌ Save to history error: $e');
    }
  }

  Future<void> _updateLastOpened(String filePath) async {
    try {
      final db = await _dbHelper.userDatabase;
      
      await db.update(
        'reading_history',
        {'last_opened': DateTime.now().toIso8601String()},
        where: 'file_path = ?',
        whereArgs: [filePath],
      );
    } catch (e) {
      debugPrint('❌ Update last opened error: $e');
    }
  }
}
