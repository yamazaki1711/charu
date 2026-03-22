import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jieba_flutter/analysis/jieba_segmenter.dart';

import '../../di/di.dart';
import 'dictionary_popup.dart';

JiebaSegmenter? _jiebaSegmenter;
bool _jiebaInitialized = false;

Future<void> initializeJieba() async {
  if (kIsWeb) {
    debugPrint('[Jieba] Skipped - Web platform');
    return;
  }
  
  try {
    debugPrint('[Jieba] Initializing...');
    await JiebaSegmenter.init();
    _jiebaSegmenter = JiebaSegmenter();
    _jiebaInitialized = true;
    debugPrint('[Jieba] Initialized successfully');
  } catch (e, st) {
    debugPrint('[Jieba] Init failed: $e');
    debugPrint('[Jieba] Stack: $st');
    _jiebaInitialized = false;
  }
}

bool get isJiebaReady => _jiebaInitialized;

List<String> segmentChinese(String text) {
  if (text.isEmpty) return [];

  final RegExp regex = RegExp(r'([\u4E00-\u9FA5\u3400-\u4DBF]+)|([^\u4E00-\u9FA5\u3400-\u4DBF]+)');
  final matches = regex.allMatches(text);

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
    });
  }

  void _onWordTapped(String word) async {
    debugPrint('[Tap] Word tapped: "$word"');
    final useCase = ref.read(lookupWordUseCaseProvider);
    final result = await useCase.call(word);
    if (!mounted) return;
    DictionaryPopup.show(context, result);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textStyle = TextStyle(
      color: theme.colorScheme.onSurface,
      fontSize: 18,
      height: 1.6,
    );

    if (_segments.isEmpty) {
      return Text(widget.text, style: textStyle);
    }

    _disposeRecognizers();

    final spans = _segments.map((word) {
      final isChinese = _containsChinese(word);
      TapGestureRecognizer? recognizer;
      
      if (isChinese) {
        recognizer = TapGestureRecognizer()
          ..onTap = () {
            _onWordTapped(word);
          };
        _recognizers.add(recognizer);
      }

      return TextSpan(
        text: word,
        style: isChinese ? textStyle.copyWith(
          decoration: TextDecoration.underline,
          decorationColor: theme.colorScheme.primary.withValues(alpha: 0.4),
          decorationStyle: TextDecorationStyle.dotted,
        ) : textStyle,
        recognizer: recognizer,
      );
    }).toList();

    return RichText(text: TextSpan(children: spans));
  }
}
