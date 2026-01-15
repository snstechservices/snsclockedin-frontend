import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sns_clocked_in/core/ui/empty_state.dart';

void main() {
  group('EmptyState', () {
    testWidgets('renders with title and message', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EmptyState(
              title: 'No Items',
              message: 'No items found',
            ),
          ),
        ),
      );

      expect(find.text('No Items'), findsOneWidget);
      expect(find.text('No items found'), findsOneWidget);
    });

    testWidgets('renders with custom icon', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EmptyState(
              title: 'No Items',
              message: 'No items found',
              icon: Icons.inbox,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.inbox), findsOneWidget);
    });

    testWidgets('shows action button when provided', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EmptyState(
              title: 'No Items',
              message: 'No items found',
              actionLabel: 'Add Item',
              onAction: null,
            ),
          ),
        ),
      );

      expect(find.text('Add Item'), findsOneWidget);
    });

    testWidgets('calls onAction when action button is tapped', (WidgetTester tester) async {
      bool wasCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmptyState(
              title: 'No Items',
              message: 'No items found',
              actionLabel: 'Add Item',
              onAction: () {
                wasCalled = true;
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Add Item'));
      await tester.pump();

      expect(wasCalled, isTrue);
    });
  });
}
