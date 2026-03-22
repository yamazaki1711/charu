import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html_parser;

void main() async {
  final dio = Dio();
  final word = '懒觉';
  try {
    final response = await dio.get(
      'https://bkrs.info/s.php',
      queryParameters: {'q': word},
      options: Options(
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          'Accept': 'text/html,application/xhtml+xml',
        },
      ),
    );

    print('Status: ${response.statusCode}');
    final document = html_parser.parse(response.data.toString());
    
    // Test the logic in the app
    final ruNodes = document.querySelectorAll('.ru, .ch_ru, .pua-ru');
    print('Found ${ruNodes.length} nodes with main translation classes.');
    for (var node in ruNodes) {
      print('Node text: ${node.text.trim()}');
    }

    final otherNodes = document.querySelectorAll('div#rsnt, ul.result_list li');
    print('Found ${otherNodes.length} fallback translation block nodes.');
    if (ruNodes.isEmpty && otherNodes.isNotEmpty) {
      print('Fallback node text: ${otherNodes.first.text.trim()}');
    }

    // Try finding the exact container for bkrs entries
    final translationBlock = document.querySelectorAll('.ru');
    print('Extract translation text:');
    if (translationBlock.isNotEmpty) {
        print(translationBlock.first.text);
    }
  } catch (e) {
    print('Error: $e');
  }
}
