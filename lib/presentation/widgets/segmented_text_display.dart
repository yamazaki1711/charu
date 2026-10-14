import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../core/log.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jieba_flutter/analysis/jieba_segmenter.dart';

import '../../di/di.dart';
import '../state/app_settings_state.dart'
    show showPinyinProvider, pinyinTapOnlyProvider, fontSizeProvider;
import '../state/progress_state.dart' show savedWordsSetProvider;
import 'dictionary_popup.dart';
import 'pinyin_helper.dart';

JiebaSegmenter? _jiebaSegmenter;
bool _jiebaInitialized = false;

Future<void> initializeJieba() async {
  if (kIsWeb) {
    log('[Jieba] Skipped - Web platform');
    return;
  }

  try {
    log('[Jieba] Initializing...');
    await JiebaSegmenter.init();
    _jiebaSegmenter = JiebaSegmenter();
    _jiebaInitialized = true;
    log('[Jieba] Initialized successfully');
  } catch (e, st) {
    log('[Jieba] Init failed: $e');
    log('[Jieba] Stack: $st');
    _jiebaInitialized = false;
  }
}

bool get isJiebaReady => _jiebaInitialized;

List<String> segmentChinese(String text) {
  if (text.isEmpty) return [];

  // Collapse consecutive whitespace (spaces, tabs, newlines from HTML
  // sources) into a single space so the rendered paragraph has no gaps.
  final normalized = text.replaceAll(RegExp(r'\s+'), ' ');

  final RegExp regex =
      RegExp(r'([\u4E00-\u9FA5\u3400-\u4DBF]+)|([^\u4E00-\u9FA5\u3400-\u4DBF]+)');
  final matches = regex.allMatches(normalized);

  final List<String> finalWords = [];

  for (final match in matches) {
    if (match.group(1) != null) {
      // It's a Chinese string. Pass to jieba.
      final chineseChunk = match.group(1)!;
      if (_jiebaSegmenter != null && _jiebaInitialized) {
        try {
          final results = _jiebaSegmenter!.process(chineseChunk, SegMode.SEARCH);
          finalWords.addAll(results.map((t) => t.word).where((w) => w.isNotEmpty));
        } catch (e) {
          finalWords.addAll(_simpleSegment(chineseChunk));
        }
      } else {
        finalWords.addAll(_simpleSegment(chineseChunk));
      }
    } else if (match.group(2) != null) {
      // It's non-Chinese (punctuation, english, spaces, numbers)
      finalWords.add(match.group(2)!);
    }
  }
  return finalWords;
}

bool _containsChinese(String word) {
  for (int i = 0; i < word.length; i++) {
    final code = word.codeUnitAt(i);
    if ((code >= 0x4E00 && code <= 0x9FFF) ||
        (code >= 0x3400 && code <= 0x4DBF)) {
      return true;
    }
  }
  return false;
}

List<String> _simpleSegment(String text) {
  final segments = <String>[];
  for (int i = 0; i < text.length; i++) {
    segments.add(text[i]);
  }
  return segments;
}

class SegmentedTextDisplay extends ConsumerStatefulWidget {
  final String text;

  const SegmentedTextDisplay({super.key, required this.text});

  @override
  ConsumerState<SegmentedTextDisplay> createState() =>
      _SegmentedTextDisplayState();
}

class _SegmentedTextDisplayState extends ConsumerState<SegmentedTextDisplay> {
  List<String> _segments = [];
  final Map<String, String> _pinyinCache = {};
  final List<TapGestureRecognizer> _recognizers = [];

  /// Words whose pinyin has been revealed by tapping, when
  /// [pinyinTapOnlyProvider] is active. Keyed by word text (not occurrence
  /// index): once revealed, every instance of that word in this article
  /// stays revealed — simpler than per-occurrence tracking and still
  /// discourages blind-reading on first encounter.
  final Set<String> _revealedWords = {};

  @override
  void initState() {
    super.initState();
    _segmentText();
  }

  @override
  void didUpdateWidget(covariant SegmentedTextDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _segmentText();
    }
  }

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  void _disposeRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  void _segmentText() {
    setState(() {
      _revealedWords.clear();
      _segments = segmentChinese(widget.text);
      // Pre-fetch pinyin for all Chinese segments (cached).
      for (final word in _segments) {
        if (_containsChinese(word) && !_pinyinCache.containsKey(word)) {
          _pinyinCache[word] = PinyinHelper.getPinyin(word);
        }
      }
    });
  }

  void _onWordTapped(String word) async {
    log('[Tap] Word tapped: "$word"');
    final useCase = ref.read(lookupWordUseCaseProvider);
    final result = await useCase.call(word);
    if (!mounted) return;
    DictionaryPopup.show(context, result);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final showPinyin = ref.watch(showPinyinProvider);
    final tapOnlyPinyin = ref.watch(pinyinTapOnlyProvider);
    final knownWords = ref.watch(savedWordsSetProvider).valueOrNull ?? const <String>{};
    final fontSize = ref.watch(fontSizeProvider).toDouble();
    final textStyle = TextStyle(
      color: theme.colorScheme.onSurface,
      fontSize: fontSize,
      height: 1.6,
    );

    if (_segments.isEmpty) {
      return Text(widget.text, style: textStyle);
    }

    _disposeRecognizers();

    final spans = <InlineSpan>[];
    for (final word in _segments) {
      final isChinese = _containsChinese(word);

      if (!isChinese) {
        spans.add(TextSpan(text: word, style: textStyle));
        continue;
      }

      final isKnown = knownWords.contains(word);
      final revealed = _revealedWords.contains(word);

      final recognizer = TapGestureRecognizer()..onTap = () {
        if (tapOnlyPinyin && !revealed) {
          setState(() => _revealedWords.add(word));
        }
        _onWordTapped(word);
      };
      _recognizers.add(recognizer);

      // Already-known (saved) words render plain — only new/unknown words
      // get the dotted underline, so a glance at the page shows at a
      // glance how much of the text is still unfamiliar (LingQ-style).
      final wordStyle = isKnown
          ? textStyle.copyWith(color: textStyle.color?.withValues(alpha: 0.85))
          : textStyle.copyWith(
              decoration: TextDecoration.underline,
              decorationColor: theme.colorScheme.primary.withValues(alpha: 0.4),
              decorationStyle: TextDecorationStyle.dotted,
            );

      final showPinyinForWord = showPinyin && (!tapOnlyPinyin || revealed);

      if (!showPinyinForWord) {
        spans.add(TextSpan(text: word, style: wordStyle, recognizer: recognizer));
        continue;
      }

      final pinyin = _pinyinCache[word] ?? PinyinHelper.getPinyin(word);
      if (pinyin.isEmpty) {
        spans.add(TextSpan(text: word, style: wordStyle, recognizer: recognizer));
        continue;
      }

      // Ruby-style annotation: pinyin floats above the word via
      // Stack + Positioned(top: negative) with clipBehavior: Clip.none,
      // NOT a Column. A Column's reported size includes the pinyin's
      // height, which (now that pinyin sits above rather than below)
      // inflates the WidgetSpan's ascent — since WidgetSpan falls back to
      // bottom-of-box baseline alignment for children that don't report a
      // real text baseline, that extra ascent desyncs this run from plain
      // TextSpan neighbors on the same line (digits/punctuation visibly
      // "floating" relative to the hanzi). Overflow-painting the pinyin
      // outside the Stack's layout box keeps the reported box == the
      // word's own size, so the word baseline-aligns exactly like plain
      // text, and only the pinyin paints into the otherwise-empty space
      // above the line.
      spans.add(WidgetSpan(
        alignment: PlaceholderAlignment.baseline,
        baseline: TextBaseline.alphabetic,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _onWordTapped(word),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.bottomCenter,
            children: [
              Text(word, style: wordStyle),
              Positioned(
                left: 0,
                right: 0,
                top: -13,
                child: Text(
                  pinyin,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    height: 1.0,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
        ),
      ));
    }

    return RichText(
      softWrap: true,
      text: TextSpan(children: spans, style: textStyle),
    );
  }
}
