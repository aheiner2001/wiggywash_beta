import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wiggywash/models/submission.dart';
import 'package:wiggywash/theme.dart';
import 'package:wiggywash/widgets/mini_scorecard_card.dart';

void main() {
  testWidgets('shows only non-zero line items', (tester) async {
    final subs = [
      Submission(
        id: '1',
        employeeName: 'Alex',
        baGoal: 40,
        counts: const {
          'protect': 2,
          'basic': 0,
        },
        submittedAt: DateTime(2026, 7, 9),
        approved: true,
        talkedTo: 10,
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: MiniScorecardCard(name: 'Alex', submissions: subs),
          ),
        ),
      ),
    );

    expect(find.text('Alex'), findsOneWidget);
    expect(find.text('Protect'), findsOneWidget);
    expect(find.text('×2'), findsOneWidget);
    expect(find.text('Basic'), findsNothing);
  });
}
