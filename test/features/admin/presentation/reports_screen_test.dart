import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sns_clocked_in/features/admin/presentation/reports_screen.dart';
import '../../../test_helpers.dart';

void main() {
  setUpAll(() async {
    await setupTestEnvironment();
  });

  group('AdminReportsScreen', () {
    Widget createTestWidget() {
      return MaterialApp(
        home: Scaffold(
          body: const AdminReportsScreen(),
        ),
      );
    }

    testWidgets('displays quick stats section at top', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Should show quick stats section with title
      expect(find.textContaining('Key Performance Indicators'), findsOneWidget);
      
      // Should show KPI stat cards
      expect(find.textContaining('Total Hours'), findsOneWidget);
      expect(find.textContaining('Overtime'), findsOneWidget);
      expect(find.textContaining('Absence Rate'), findsOneWidget);
      expect(find.textContaining('Avg Check-In'), findsOneWidget);
      expect(find.textContaining('Total Leave Days'), findsOneWidget);
      expect(find.textContaining('Leave Approval Rate'), findsOneWidget);
    });

    testWidgets('displays collapsible filters section', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Should show filters section
      expect(find.textContaining('Filters'), findsOneWidget);
      
      // Date filter should be visible (expanded by default)
      expect(find.textContaining('Last 30d'), findsOneWidget);
    });

    testWidgets('filters can be collapsed and expanded', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Find collapse/expand button
      final expandButton = find.byIcon(Icons.expand_less);
      expect(expandButton, findsOneWidget);

      // Tap to collapse
      await tester.tap(expandButton);
      await tester.pumpAndSettle();

      // Date filter should not be visible
      expect(find.textContaining('Last 30d'), findsNothing);

      // Tap to expand again
      final collapseButton = find.byIcon(Icons.expand_more);
      await tester.tap(collapseButton);
      await tester.pumpAndSettle();

      // Date filter should be visible again
      expect(find.textContaining('Last 30d'), findsOneWidget);
    });

    testWidgets('displays monthly hours chart section', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.textContaining('Monthly Hours'), findsOneWidget);
    });

    testWidgets('displays generate report FAB', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Generate Report'), findsOneWidget);
    });
  });
}
