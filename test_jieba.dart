import 'package:jieba_flutter/analysis/jieba_segmenter.dart';

void main() async {
  await JiebaSegmenter.init();
  final segmenter = JiebaSegmenter();
  
  final text = "你好，世界！这是一句测试句子。";
  final results = segmenter.process(text, SegMode.SEARCH);
  
  for (final token in results) {
    print("'${token.word}'");
  }
}
