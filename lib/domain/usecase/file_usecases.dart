import '../model/file_models.dart';
import '../repository/file_repository.dart';

/// Use case for picking and opening a local file
class OpenFileUseCase {
  final IFileRepository _repository;

  OpenFileUseCase(this._repository);

  Future<LocalFile?> call() async {
    return await _repository.pickFile();
  }
}

/// Use case for reading file content
class ReadFileContentUseCase {
  final IFileRepository _repository;

  ReadFileContentUseCase(this._repository);

  Future<String> call(String filePath) async {
    return await _repository.readFile(filePath);
  }
}

/// Use case for getting recent files
class GetRecentFilesUseCase {
  final IFileRepository _repository;

  GetRecentFilesUseCase(this._repository);

  Future<List<LocalFile>> call() async {
    return await _repository.getRecentFiles();
  }
}

/// Use case for saving reading position
class SaveReadingPositionUseCase {
  final IFileRepository _repository;

  SaveReadingPositionUseCase(this._repository);

  Future<void> call(String filePath, int position) async {
    await _repository.saveReadingPosition(filePath, position);
  }
}

/// Use case for looking up a single file's history entry (e.g. to resume
/// reading at its last saved position).
class GetFileByPathUseCase {
  final IFileRepository _repository;

  GetFileByPathUseCase(this._repository);

  Future<LocalFile?> call(String filePath) async {
    return await _repository.getFileByPath(filePath);
  }
}

/// Use case for clearing all reading history (Settings screen).
class ClearHistoryUseCase {
  final IFileRepository _repository;

  ClearHistoryUseCase(this._repository);

  Future<void> call() async {
    await _repository.clearHistory();
  }
}

/// Use case for bookmarking the current reading position.
class SaveBookmarkUseCase {
  final IFileRepository _repository;

  SaveBookmarkUseCase(this._repository);

  Future<void> call(String filePath, int position, {String? note}) async {
    await _repository.addBookmark(filePath, position, note: note);
  }
}

/// Use case for listing a file's bookmarks (Bookmarks sheet in the reader).
class GetBookmarksUseCase {
  final IFileRepository _repository;

  GetBookmarksUseCase(this._repository);

  Future<List<BookmarkEntry>> call(String filePath) async {
    return await _repository.getBookmarks(filePath);
  }
}

/// Use case for deleting a single bookmark.
class RemoveBookmarkUseCase {
  final IFileRepository _repository;

  RemoveBookmarkUseCase(this._repository);

  Future<void> call(int id) async {
    await _repository.removeBookmark(id);
  }
}
