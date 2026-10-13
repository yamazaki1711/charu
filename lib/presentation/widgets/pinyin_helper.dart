import 'package:pinyin/pinyin.dart' as py;

/// Helper for generating pinyin for Chinese text.
///
/// Uses the `pinyin` package (built-in character dictionary, offline, with
/// tone marks). For words that exist in the local BKRS dictionary, the
/// caller should prefer the dictionary pinyin (more accurate for multi-char
/// words); this helper is the fallback.
class PinyinHelper {
  PinyinHelper._();

  /// Returns per-character pinyin (with tone marks) for [text].
  ///
  /// Non-Chinese characters are preserved as-is.
  static String getPinyin(String text) {
    if (text.trim().isEmpty) return '';
    try {
      return py.PinyinHelper.getPinyin(
        text,
        separator: ' ',
        format: py.PinyinFormat.WITH_TONE_MARK,
      );
    } catch (_) {
      return text;
    }
  }
}
