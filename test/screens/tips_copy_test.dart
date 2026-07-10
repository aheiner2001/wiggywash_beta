import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wiggywash/screens/tips_screen.dart';

void main() {
  testWidgets('employee tips omit nonexistent total-today tap', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: TipsScreen(audience: TipsAudience.employee)),
    );
    expect(find.textContaining('Tap Your total today'), findsNothing);
    expect(find.textContaining('line-by-line breakdown'), findsNothing);
  });
}
