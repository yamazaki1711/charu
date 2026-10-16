import '../model/dictionary_models.dart';

/// Dictionary Repository Interface for retrieving word data.
abstract class IDictionaryRepository {
  /// Resolves the word using the strict cascade:
  /// 1. Local BKRS (~863k)
  /// 1.5. Window-scan (if [windowContext] given and step 1 missed) —
  ///      segmentation-independent longest-match against the raw text
  ///      starting at the tap, so a wrong jieba split doesn't hide an
  ///      entry that genuinely exists in BKRS under different word
  ///      boundaries.
  /// 2. Toponyms
  /// 3. Person Names
  /// 4. Sub-word decomposition
  /// 5. Online bkrs.info
  /// 6. Pinyin Character Fallback.
  ///
  /// [windowContext], when given, is the tapped word followed by enough of
  /// the surrounding raw text (jieba segmentation is irrelevant here) to
  /// run the window-scan step.
  Future<DictionaryResult> lookupWord(String word, {String? windowContext});

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
