import '../model/dictionary_models.dart';

/// Dictionary Repository Interface for retrieving word data.
abstract class IDictionaryRepository {
  /// Resolves the word using the strict 5-layer cascade:
  /// 1. Local BKRS (~250k)
  /// 2. Toponyms
  /// 3. Person Names
  /// 4. Online bkrs.info
  /// 5. Pinyin Character Fallback.
  Future<DictionaryResult> lookupWord(String word);

  /// Saves a word to the user's personal vocabulary.
  Future<void> saveWord(DictionaryResult result);

  // --- Individual table access for cascade internals ---

  /// Search Local BKRS. Returns null if not found.
  Future<WordEntry?> searchLocalBkrs(String word);

  /// Search Toponyms. Returns null if not found.
  Future<ToponymEntry?> searchToponym(String word);

  /// Search Person Names. Returns null if not found.
  Future<List<PersonNameEntry>> searchPersonName(String word);

  /// Search Online Grand BKRS.
  Future<WordEntry?> searchOnlineBkrs(String word);

  /// Pinyin fallback for single characters.
  Future<String> getPinyinForCharacter(String character);
}
