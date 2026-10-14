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

      final recognizer = TapGestureRecognizer()..onTap = () => _onWordTapped(word);
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

      // "Tap-only" mode intentionally does NOT reveal pinyin inline: a
      // Chinese word with pinyin is a taller inline block than its plain
      // neighbors, and Flutter has no notion of "ruby text" that keeps
      // mixed plain/annotated runs level on one line — toggling a single
      // word's pinyin on would visibly bump that word (and everything
      // after it on the line) out of alignment. The dictionary popup
      // (opened by every tap, see _onWordTapped) already shows the
      // pinyin prominently, so tap-only mode simply keeps the inline text
      // clean and relies on that popup as the "reveal".
      final showPinyinForWord = showPinyin && !tapOnlyPinyin;

      if (!showPinyinForWord) {
        spans.add(TextSpan(text: word, style: wordStyle, recognizer: recognizer));
        continue;
      }

      final pinyin = _pinyinCache[word] ?? PinyinHelper.getPinyin(word);
      if (pinyin.isEmpty) {
        spans.add(TextSpan(text: word, style: wordStyle, recognizer: recognizer));
        continue;
      }

      // Ruby-style annotation: WidgetSpan with a Column(min) — pinyin
      // above the word (standard ruby/furigana convention). Deliberately
      // NOT using PlaceholderAlignment.baseline: a Column doesn't report a
      // real text baseline, so Flutter falls back to aligning the BOTTOM
      // of the whole column to the line's baseline — meaning the ascent
      // this run contributes to the line is the Column's full height
      // (pinyin + spacing + word). That's fine for THIS run, but a
      // previous attempt at overflow-painting the pinyin outside the
      // layout box (to avoid that extra ascent) caused the pinyin to
      // paint into the line above instead, since nothing reserves room
      // for it there. PlaceholderAlignment.middle sidesteps baseline
      // fallback entirely — Flutter centers the whole annotated unit
      // within the line's own box — which stays visually consistent for
      // CJK text (fullwidth characters are already centered in their own
      // em-box, unlike Latin baseline-anchored glyphs) and, crucially,
      // the Column's full height is honestly reserved by the layout
      // engine, so consecutive lines can never collide regardless of how
      // many words on a line carry annotations.
      spans.add(WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _onWordTapped(word),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                pinyin,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  height: 1.0,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 1),
              Text(word, style: wordStyle),
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
