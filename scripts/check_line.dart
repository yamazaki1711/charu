import 'dart:io';

void main() {
  var file = File('dabkrs');
  var lines = file.readAsLinesSync();
  print('Line 267071: ${lines[267071]}');
  print('Line 267072: ${lines[267072]}');
  print('Line 267073: ${lines[267073]}');
  print('Line 267074: ${lines[267074]}');
  
  // Find 今年
  for (int i = 0; i < lines.length; i++) {
    if (lines[i] == '今年') {
      print('\nFound 今年 at line ${i+1}');
      print('Context:');
      for (int j = i-1; j <= i+3 && j < lines.length; j++) {
        print('  ${j+1}: ${lines[j]}');
      }
      break;
    }
  }
}
