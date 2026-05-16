// Basic Flutter widget test.

import 'package:flutter_test/flutter_test.dart';

import 'package:khidmat_app/main.dart';

void main() {
  testWidgets('KhidmatApp builds and shows home title', (WidgetTester tester) async {
    await tester.pumpWidget(const KhidmatApp());
    await tester.pumpAndSettle();
    expect(find.text('Khidmat AI'), findsOneWidget);
  });
}
