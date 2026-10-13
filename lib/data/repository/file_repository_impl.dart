import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:fast_gbk/fast_gbk.dart' as gbk;
import 'package:file_picker/file_picker.dart' as fp;
import '../../core/log.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';
import 'package:xml/xml.dart' as xml;

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
      log('❌ File pick error: $e');
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

      final bytes = await file.readAsBytes();

      // EPUB is a ZIP container — unpack and extract the spine text
      if (filePath.toLowerCase().endsWith('.epub')) {
        final content = _extractEpubText(bytes);
        await _updateLastOpened(filePath);
        return content;
      }

      // Detect encoding: UTF-8 BOM → GBK → UTF-8 (with malformed check)
      final content = _decodeBytes(bytes);

      // Update last opened
      await _updateLastOpened(filePath);

      return content;
    } catch (e) {
      log('❌ File read error: $e');
      rethrow;
    }
  }

  /// Decodes [bytes] trying UTF-8 BOM, GBK/GB2312, then plain UTF-8.
  ///
  /// Heuristic: UTF-8 decodes cleanly if it contains no replacement
  /// characters; Chinese text encoded as GBK almost always decodes to
  /// replacement characters under UTF-8, so GBK is tried first when the
  /// payload is mostly non-ASCII high bytes.
  String _decodeBytes(List<int> bytes) {
    // UTF-8 BOM
    if (bytes.length >= 3 &&
        bytes[0] == 0xEF &&
        bytes[1] == 0xBB &&
        bytes[2] == 0xBF) {
      return utf8.decode(bytes.sublist(3), allowMalformed: true);
    }

    // Heuristic: if the first 4KB contain lots of high (>= 0x80) bytes
    // that are not valid UTF-8 sequences, it is very likely GBK.
    if (_looksLikeGbk(bytes)) {
      try {
        return gbk.gbk.decode(bytes, allowMalformed: true);
      } catch (e) {
        log('⚠️ GBK decode failed, falling back to UTF-8: $e');
      }
    }

    return utf8.decode(bytes, allowMalformed: true);
  }

  /// Returns true if [bytes] looks like GBK-encoded text:
  /// a high ratio of bytes >= 0x80 and many invalid UTF-8 sequences.
  bool _looksLikeGbk(List<int> bytes) {
    final sample = bytes.length > 8192 ? bytes.sublist(0, 8192) : bytes;
    if (sample.isEmpty) return false;

    int highBytes = 0;
    for (final b in sample) {
      if (b >= 0x80) highBytes++;
    }
    // Fewer than 10% high bytes → plain ASCII/Latin, not GBK.
    if (highBytes * 10 < sample.length) return false;

    // Try strict UTF-8 decode; if it throws, the payload is not valid
    // UTF-8, so GBK is a reasonable guess for Chinese text.
    try {
      utf8.decode(sample);
      return false; // valid UTF-8 — keep UTF-8
    } catch (_) {
      return true; // invalid UTF-8 → likely GBK
    }
  }

  /// Extracts plain text from an EPUB (OPF spine) archive.
  String _extractEpubText(List<int> epubBytes) {
    try {
      final archive = ZipDecoder().decodeBytes(epubBytes);

      // 1. Find META-INF/container.xml → rootfile path
      final containerXml = archive.files
          .firstWhere((f) => f.name == 'META-INF/container.xml',
              orElse: () => throw Exception('No container.xml in EPUB'));
      final containerDoc = xml.XmlDocument.parse(
        utf8.decode(containerXml.content as List<int>, allowMalformed: true),
      );
      final rootfile =
          containerDoc.findAllElements('rootfile').first.getAttribute('full-path');
      if (rootfile == null) {
        throw Exception('container.xml has no rootfile');
      }

      // 2. Read the OPF document
      final opfFile = archive.files.firstWhere(
        (f) => f.name == rootfile || f.name.replaceAll('\\', '/') == rootfile,
        orElse: () =>
            throw Exception('OPF "$rootfile" not found in archive'),
      );
      final opfDoc = xml.XmlDocument.parse(
        utf8.decode(opfFile.content as List<int>, allowMalformed: true),
      );

      // 3. Collect spine item ids in order
      final spineIds = opfDoc
          .findAllElements('itemref')
          .map((e) => e.getAttribute('idref'))
          .where((id) => id != null)
          .cast<String>()
          .toList();

      // 4. Map id → href via <manifest><item>
      final items = <String, String>{};
      for (final item in opfDoc.findAllElements('item')) {
        final id = item.getAttribute('id');
        final href = item.getAttribute('href');
        if (id != null && href != null) {
          items[id] = href;
        }
      }

      // 5. Resolve hrefs relative to the OPF directory
      final opfDir = rootfile.contains('/')
          ? rootfile.substring(0, rootfile.lastIndexOf('/') + 1)
          : '';

      final sb = StringBuffer();
      for (final id in spineIds) {
        final href = items[id];
        if (href == null) continue;
        final resolved = opfDir + href;

        final xhtmlFile = archive.files
            .cast<ArchiveFile?>()
            .firstWhere(
              (f) =>
                  f != null &&
                  (f.name == resolved ||
                      f.name.replaceAll('\\', '/') == resolved ||
                      f.name.endsWith(href)),
              orElse: () => null,
            );
        if (xhtmlFile == null) continue;

        final html = utf8.decode(
          xhtmlFile.content as List<int>,
          allowMalformed: true,
        );
        sb.writeln(_stripHtmlTags(html));
        sb.writeln('\n');
      }

      final text = sb.toString().trim();
      return text.isEmpty
          ? 'Не удалось извлечь текст из EPUB.'
          : text;
    } catch (e) {
      log('❌ EPUB parse error: $e');
      rethrow;
    }
  }

  /// Strips HTML/XHTML tags and common markup, preserving readable text.
  String _stripHtmlTags(String html) {
    String out = html;
    // Remove <script>, <style>, <head> blocks entirely
    out = out.replaceAll(
        RegExp(r'<(script|style|head)[^>]*>[\s\S]*?</\1>',
            caseSensitive: false),
        '');
    // Block-level tags become newlines
    out = out.replaceAll(RegExp(r'</?(p|div|br|h[1-6]|li|section|article|header|footer)[^>]*>', caseSensitive: false), '\n');
    // Strip all remaining tags
    out = out.replaceAll(RegExp(r'<[^>]*>'), '');
    // Decode common entities
    out = out
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'");
    // Collapse whitespace
    out = out.replaceAll(RegExp(r'[ \t]+'), ' ');
    out = out.replaceAll(RegExp(r'\n\s*\n+'), '\n\n');
    return out.trim();
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
      log('❌ Get recent files error: $e');
      return [];
    }
  }

  @override
  Future<void> saveReadingPosition(String filePath, int position) async {
    try {
      final db = await _dbHelper.userDatabase;
      
      // Progress is tracked in characters (symbols), not bytes: for UTF-8
      // Chinese text one symbol can take 3 bytes, so byte-based progress
      // would be distorted.
      String content = '';
      try {
        final bytes = await File(filePath).readAsBytes();
        if (filePath.toLowerCase().endsWith('.epub')) {
          content = _extractEpubText(bytes);
        } else {
          content = _decodeBytes(bytes);
        }
      } catch (_) {
        // Fallback: no progress info if the file cannot be decoded
      }
      final totalLength = content.length;

      final progress = totalLength > 0
          ? ((position / totalLength) * 100).clamp(0.0, 100.0)
          : 0.0;

      await db.update(
        'reading_history',
        {
          'last_position': position,
          'progress_percent': progress,
          'total_length': totalLength,
          'last_opened': DateTime.now().toIso8601String(),
        },
        where: 'file_path = ?',
        whereArgs: [filePath],
      );
    } catch (e) {
      log('❌ Save position error: $e');
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
      log('❌ Remove file error: $e');
    }
  }

  @override
  Future<void> clearHistory() async {
    try {
      final db = await _dbHelper.userDatabase;
      await db.delete('reading_history');
    } catch (e) {
      log('❌ Clear history error: $e');
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
      log('❌ Get file by path error: $e');
      return null;
    }
  }

  @override
  Future<void> addBookmark(String filePath, int position, {String? note}) async {
    try {
      final db = await _dbHelper.userDatabase;
      await db.insert('bookmarks', {
        'file_path': filePath,
        'position': position,
        'note': note,
      });
    } catch (e) {
      log('❌ Add bookmark error: $e');
      rethrow;
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
      log('❌ Save to history error: $e');
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
      log('❌ Update last opened error: $e');
    }
  }
}
