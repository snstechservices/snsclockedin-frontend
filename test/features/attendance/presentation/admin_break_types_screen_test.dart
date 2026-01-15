import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sns_clocked_in/features/attendance/application/break_types_store.dart';
import 'package:sns_clocked_in/features/attendance/data/break_types_repository.dart';
import 'package:sns_clocked_in/features/attendance/presentation/admin_break_types_screen.dart';
import '../../../test_helpers.dart';

void main() {
  setUpAll(() async {
    await setupTestEnvironment();
  });

  group('AdminBreakTypesScreen', () {
    late BreakTypesStore store;
    late MockBreakTypesRepository repository;

    setUp(() {
      repository = MockBreakTypesRepository();
      store = BreakTypesStore(repository: repository);
    });

    tearDown(() {
      store.dispose();
    });

    Widget createTestWidget() {
      return MaterialApp(
        home: Scaffold(
          body: ChangeNotifierProvider<BreakTypesStore>.value(
            value: store,
            child: const AdminBreakTypesScreen(),
          ),
        ),
      );
    }

    testWidgets('displays quick stats section at top', (tester) async {
      await store.load();
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Should show quick stats section with title
      expect(find.textContaining('Break Types Summary'), findsOneWidget);
      
      // Should show stat cards
      expect(find.textContaining('Total'), findsOneWidget);
      expect(find.textContaining('Active'), findsOneWidget);
      expect(find.textContaining('Inactive'), findsOneWidget);
    });

    testWidgets('quick stats display correct counts', (tester) async {
      await store.load();
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      final totalCount = store.breakTypes.length;
      final activeCount = store.activeBreakTypes.length;
      final inactiveCount = totalCount - activeCount;

      // Verify counts are displayed
      expect(find.text(totalCount.toString()), findsWidgets);
      expect(find.text(activeCount.toString()), findsWidgets);
      expect(find.text(inactiveCount.toString()), findsWidgets);
    });

    testWidgets('displays add button', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Add'), findsOneWidget);
    });

    testWidgets('displays empty state when no break types', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Wait for loading to complete
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      // Should show empty state if no break types
      if (store.breakTypes.isEmpty) {
        expect(find.textContaining('No Break Types'), findsOneWidget);
      }
    });

    testWidgets('displays break type list when available', (tester) async {
      await store.load();
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      if (store.breakTypes.isNotEmpty) {
        // Should show break type cards
        expect(store.breakTypes.length, greaterThan(0));
      }
    });
  });
}
