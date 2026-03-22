import '../model/dictionary_models.dart';
import '../repository/dictionary_repository.dart';

/// Use Case for looking up a dictionary word.
///
/// Encapsulates the execution of the 5-layer cascade, though
/// the repository itself typically handles the low-level data fetch.
class LookupWordUseCase {
  final IDictionaryRepository _repository;

  LookupWordUseCase(this._repository);

  /// Executes the 5-layer dictionary lookup cascade.
  ///
  /// The [word] input should be properly segmented by Jieba prior to calling this.
  Future<DictionaryResult> call(String word) async {
    if (word.trim().isEmpty) {
      return DictionaryResult(
        chineseWord: word,
        pinyin: '',
        translation: '',
        source: 'empty',
      );
    }

    return await _repository.lookupWord(word);
  }
}
