import 'dart:io';
import 'dart:convert';

void main() async {
  final file = File('c:\\charu\\dabkrs');
  if (!await file.exists()) {
    print('File dabkrs not found');
    return;
  }
  
  // Try reading with default utf8, if it fails, maybe latin1? No, let's read lines
  int lineCount = 0;
  int foundCount = 0;
  
  try {
    final stream = file.openRead()
      .transform(utf8.decoder)
      .transform(LineSplitter());
      
    await for (final line in stream) {
      lineCount++;
      if (line.contains('第一个') || line.contains('第一')) {
        print('Found on line $lineCount: $line');
        foundCount++;
        if (foundCount >= 5) break;
      }
    }
    print('Total lines checked: $lineCount');
  } catch (e) {
    print('Error: $e. File might not be utf-8.');
  }
}
