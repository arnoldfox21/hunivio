import 'package:flutter_test/flutter_test.dart';
import 'package:hunigo/main.dart';

void main() {
  testWidgets('HuniGoApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const HuniGoApp());
    expect(find.text('HuniGo'), findsOneWidget);
    expect(find.text('Cari Kost'), findsOneWidget);
  });
}
