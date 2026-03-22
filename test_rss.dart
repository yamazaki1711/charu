import 'package:dio/dio.dart';
import 'package:xml/xml.dart' as xml;

void main() async {
  final dio = Dio();
  try {
    final response = await dio.get('https://www.chinanews.com.cn/rss/sh.xml');
    print(response.statusCode);
    final str = response.data.toString();
    print('Length: \${str.length}');
    print(str.substring(0, 100)); // preview
    final doc = xml.XmlDocument.parse(str);
    final items = doc.findAllElements('item');
    print('Found ${items.length} items');
  } catch (e) {
    print('Error: \$e');
  }
}
