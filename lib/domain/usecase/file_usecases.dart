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
