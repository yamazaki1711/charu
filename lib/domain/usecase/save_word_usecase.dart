import '../model/dictionary_models.dart';
import '../repository/dictionary_repository.dart';

/// Use Case for saving a dictionary word to user vocabulary.
class SaveWordUseCase {
  final IDictionaryRepository _repository;

  SaveWordUseCase(this._repository);

  /// Saves the [result] to the local 'user_vocabulary' table.
  Future<void> call(DictionaryResult result) async {
    // Basic validation
    if (result.chineseWord.trim().isEmpty) return;

    await _repository.saveWord(result);
  }
}
