import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import '../../core/log.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jieba_flutter/analysis/jieba_segmenter.dart';

import '../../di/di.dart';
import '../state/app_settings_state.dart'
    show
        showPinyinProvider,
        pinyinTapOnlyProvider,
        fontSizeProvider,
        lineHeightProvider;
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

  /// Index of the segment to flash on tap — visual confirmation of exactly
  /// which word the segmenter resolved the tap to (segmentation can merge
  /// several characters into one word; without this it isn't always obvious
  /// what the popup's translation actually refers to).
  int? _flashedIndex;
  Timer? _flashTimer;

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
    _flashTimer?.cancel();
    super.dispose();
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

  void _onWordTapped(String word, int index) async {
    log('[Tap] Word tapped: "$word"');
    _flashTimer?.cancel();
    setState(() => _flashedIndex = index);
    _flashTimer = Timer(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _flashedIndex = null);
    });
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
    final lineHeight = ref.watch(lineHeightProvider);
    final textStyle = TextStyle(
      color: theme.colorScheme.onSurface,
      fontSize: fontSize,
      height: lineHeight,
    );

    if (_segments.isEmpty) {
      return Text(widget.text, style: textStyle);
    }

    // Wrap, not RichText/TextSpan: a text paragraph where some inline runs
    // are "tall" (word + pinyin above it) and others are plain (digits,
    // punctuation) cannot be laid out consistently with RichText — every
    // baseline/alignment strategy tried (PlaceholderAlignment.baseline,
    // .middle, overflow-painting via Stack) either collided with the line
    // above or left plain runs floating at some arbitrary height relative
    // to the annotated words next to them, because RichText's line metrics
    // are shared across all inline runs with no per-run override. Wrap
    // sidesteps this entirely: every segment (Chinese word-with-pinyin, or
    // a plain run) is laid out as an independent box, and
    // WrapCrossAlignment.end bottom-aligns all of them within each wrapped
    // line regardless of height — a short plain Text and a tall
    // word+pinyin Column naturally share the same bottom edge, which is
    // exactly where a word's visual baseline sits.
    final children = <Widget>[];
    for (var index = 0; index < _segments.length; index++) {
      final word = _segments[index];
      final isChinese = _containsChinese(word);

      if (!isChinese) {
        children.add(Text(word, style: textStyle));
        continue;
      }

      final isKnown = knownWords.contains(word);

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

      // "Tap-only" mode intentionally does NOT reveal pinyin inline — see
      // module doc for why. The dictionary popup (opened by every tap,
      // _onWordTapped) already shows the pinyin prominently, so tap-only
      // mode simply keeps the inline text clean and relies on that popup.
      final showPinyinForWord = showPinyin && !tapOnlyPinyin;
      final pinyin = showPinyinForWord
          ? (_pinyinCache[word] ?? PinyinHelper.getPinyin(word))
          : '';

      final isFlashed = _flashedIndex == index;

      children.add(GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _onWordTapped(word, index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 1),
          decoration: BoxDecoration(
            color: isFlashed
                ? theme.colorScheme.primary.withValues(alpha: 0.25)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: pinyin.isEmpty
              ? Text(word, style: wordStyle)
              : Column(
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

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.end,
      runSpacing: 6,
      children: children,
    );
  }
}
