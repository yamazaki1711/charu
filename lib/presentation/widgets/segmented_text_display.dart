import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:jieba_flutter/analysis/jieba_segmenter.dart';

import 'dictionary_popup.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../di/di.dart';

/// Renders Chinese text by segmenting it with Jieba and making each word tappable.
class SegmentedTextDisplay extends ConsumerStatefulWidget {
  final String text;

  const SegmentedTextDisplay({
    super.key,
    required this.text,
  });

  @override
  ConsumerState<SegmentedTextDisplay> createState() => _SegmentedTextDisplayState();
}

class _SegmentedTextDisplayState extends ConsumerState<SegmentedTextDisplay> {
  List<String> _segments = [];
  bool _isInit = false;

  @override
  void initState() {
    super.initState();
    _segmentText();
  }

  @override
  void didUpdateWidget(covariant SegmentedTextDisplay oldWidget) {
    if (oldWidget.text != widget.text) {
      _segmentText();
    }
    super.didUpdateWidget(oldWidget);
  }

  Future<void> _segmentText() async {
    if (!_isInit) {
      await JiebaSegmenter.init();
      _isInit = true;
    }
    
    // Segment logic
    final segmenter = JiebaSegmenter();
    final tokens = segmenter.process(widget.text, SegMode.SEARCH);
    
    if (mounted) {
      setState(() {
        _segments = tokens.map((t) => t.word).toList();
      });
    }
  }

  void _onWordTapped(String word) async {
    final useCase = ref.read(lookupWordUseCaseProvider);
    final result = await useCase.call(word);

    if (mounted) {
      DictionaryPopup.show(context, result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_segments.isEmpty) {
      // Show loading while Jieba initializes or segments (usually instant)
      return Text(widget.text, style: TextStyle(fontSize: 18));
    }

    return RichText(
      text: TextSpan(
        children: _segments.map((word) {
          // If it's punctuation or whitespace, don't map interactions.
          // Very simple check:
          final isPunctuation = word.trim().isEmpty || RegExp(r'^[，。！？；：“”‘’（）【】《》]+$').hasMatch(word);

          if (isPunctuation) {
            return TextSpan(
              text: word,
              style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 18),
            );
          }

          return TextSpan(
            text: word,
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontSize: 18,
            ),
            recognizer: TapGestureRecognizer()
              ..onTap = () => _onWordTapped(word),
          );
        }).toList(),
      ),
    );
  }
}
