import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sns_clocked_in/core/ui/stat_card.dart';
import 'package:sns_clocked_in/design_system/app_colors.dart';

void main() {
  group('StatCard', () {
    testWidgets('renders with title, value, and icon', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StatCard(
              title: 'Total',
              value: '42',
              icon: Icons.people,
              color: AppColors.primary,
            ),
          ),
        ),
      );

      expect(find.text('Total'), findsOneWidget);
      expect(find.text('42'), findsOneWidget);
      expect(find.byIcon(Icons.people), findsOneWidget);
    });

    testWidgets('renders with optional subtitle', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StatCard(
              title: 'Total',
              value: '42',
              icon: Icons.people,
              color: AppColors.primary,
              subtitle: 'Items',
            ),
          ),
        ),
      );

      expect(find.text('Items'), findsOneWidget);
    });

    testWidgets('respects width constraint', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StatCard(
              title: 'Total',
              value: '42',
              icon: Icons.people,
              color: AppColors.primary,
              width: 140,
            ),
          ),
        ),
      );

      final card = tester.widget<StatCard>(find.byType(StatCard));
      expect(card.width, equals(140));
    });
  });
}
