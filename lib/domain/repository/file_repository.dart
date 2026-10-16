import '../model/file_models.dart';

/// Repository interface for local file operations
abstract class IFileRepository {
  /// Pick a file from device storage
  Future<LocalFile?> pickFile();

  /// Open a file and return its content
  Future<String> readFile(String path);

  /// Get list of recently opened files
  Future<List<LocalFile>> getRecentFiles();

  /// Save reading position
  Future<void> saveReadingPosition(String path, int position);

  /// Delete file from history
  Future<void> removeFileFromHistory(String path);

  /// Clear all reading history
  Future<void> clearHistory();

  /// Get file info by path
  Future<LocalFile?> getFileByPath(String path);

  /// Save a bookmark at [position] (character offset) in [filePath].
  Future<void> addBookmark(String filePath, int position, {String? note});

  /// Registers [file] in reading history without going through [pickFile]
  /// (used by the Library to plug a downloaded book into the existing
  /// reader/progress/bookmarks pipeline as if it were a locally opened file).
  Future<void> addToHistory(LocalFile file);
}
