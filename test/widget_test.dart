import 'package:flutter_test/flutter_test.dart';
import 'package:charu/main.dart';

void main() {
  testWidgets('App loads', (WidgetTester tester) async {
    await tester.pumpWidget(const CharuApp());
    expect(find.text('CHARU'), findsAny);
  });
}
