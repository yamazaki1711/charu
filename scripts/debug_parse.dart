import 'dart:io';

void main() {
  var file = File('dabkrs');
  var lines = file.readAsLinesSync();
  
  String? currentWord;
  String? currentPinyin;
  
  for (int i = 267068; i < 267080; i++) {
    var line = lines[i];
    print('${i+1}: ${repr(line)}');
    
    if (line.startsWith('#') || line.trim().isEmpty) {
      if (currentWord != null && line.trim().isEmpty) {
        print('  -> Empty line, currentWord=$currentWord, currentPinyin=$currentPinyin');
      }
      continue;
    }
    
    var trimmed = line.trim();
    
    if (_isChinese(trimmed[0])) {
      var parts = trimmed.split(RegExp(r'\s+'));
      print('  -> Chinese word: ${parts.first}');
      currentWord = parts.first;
      currentPinyin = null;
    } else if (trimmed.isNotEmpty && !_hasChinese(trimmed)) {
      print('  -> Pinyin: $trimmed');
      currentPinyin = trimmed;
    } else if (trimmed.contains('[m1]')) {
      print('  -> Translation found, saving: $currentWord [$currentPinyin]');
    }
  }
}

bool _isChinese(String char) {
  if (char.isEmpty) return false;
  final code = char.codeUnitAt(0);
  return (code >= 0x4E00 && code <= 0x9FFF) ||
         (code >= 0x3400 && code <= 0x4DBF);
}

bool _hasChinese(String text) {
  return text.contains(RegExp(r'[\u4e00-\u9fff\u3400-\u4dbf]'));
}

String repr(String s) {
  return s.replaceAll('\n', '\\n');
}
