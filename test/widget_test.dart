import 'package:flutter_test/flutter_test.dart';
import 'package:hunivio/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('HuniVioApp smoke test', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const HuniVioApp());
    expect(find.text('HuniVio'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1600));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Cari Kost'), findsOneWidget);
  });
}
