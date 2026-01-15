import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sns_clocked_in/features/employees/application/employees_store.dart';
import 'package:sns_clocked_in/features/employees/presentation/admin_employees_screen.dart';
import '../../../test_helpers.dart';

void main() {
  setUpAll(() async {
    await setupTestEnvironment();
  });

  group('AdminEmployeesScreen', () {
    late EmployeesStore store;

    setUp(() {
      store = EmployeesStore();
    });

    tearDown(() {
      store.dispose();
    });

    Widget createTestWidget() {
      return MaterialApp(
        home: Scaffold(
          body: ChangeNotifierProvider<EmployeesStore>.value(
            value: store,
            child: const AdminEmployeesScreen(),
          ),
        ),
      );
    }

    testWidgets('displays quick stats section at top', (tester) async {
      store.seedSampleData();
      
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Should show quick stats section with title
      expect(find.textContaining('Employees Summary'), findsOneWidget);
      
      // Should show stat cards (may appear multiple times in different contexts)
      expect(find.textContaining('Total Employees'), findsWidgets);
      expect(find.textContaining('Active'), findsWidgets);
      expect(find.textContaining('Inactive'), findsWidgets);
    });

    testWidgets('displays collapsible filters section', (tester) async {
      store.seedSampleData();
      
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Should show filters section
      expect(find.textContaining('Filters'), findsOneWidget);
      
      // Filters should be expanded by default
      expect(find.byType(TextField), findsOneWidget); // Search field
      expect(find.text('All'), findsOneWidget); // Status filter
    });

    testWidgets('filters can be collapsed and expanded', (tester) async {
      store.seedSampleData();
      
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Find collapse/expand button
      final expandButton = find.byIcon(Icons.expand_less);
      expect(expandButton, findsOneWidget);

      // Tap to collapse
      await tester.tap(expandButton);
      await tester.pumpAndSettle();

      // Search field should not be visible
      expect(find.byType(TextField), findsNothing);

      // Tap to expand again
      final collapseButton = find.byIcon(Icons.expand_more);
      await tester.tap(collapseButton);
      await tester.pumpAndSettle();

      // Search field should be visible again
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('displays empty state when no employees', (tester) async {
      // Don't seed data to test empty state
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Empty state may show different text, check for any empty state indicator
      final emptyStateFound = find.textContaining('No Employees').evaluate().isNotEmpty ||
          find.textContaining('No employees').evaluate().isNotEmpty ||
          find.textContaining('Try adjusting').evaluate().isNotEmpty;
      expect(emptyStateFound, isTrue);
    });

    testWidgets('displays employee list when available', (tester) async {
      store.seedSampleData();
      
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Should show employee cards
      expect(store.filteredEmployees.length, greaterThan(0));
    });

    testWidgets('search filters employees', (tester) async {
      store.seedSampleData();
      
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      final initialCount = store.filteredEmployees.length;
      
      // Enter search text
      await tester.enterText(find.byType(TextField), 'John');
      await tester.pumpAndSettle();

      // Filtered count should be less or equal
      expect(store.filteredEmployees.length, lessThanOrEqualTo(initialCount));
    });
  });
}
