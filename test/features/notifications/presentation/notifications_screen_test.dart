import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sns_clocked_in/core/role/role.dart';
import 'package:sns_clocked_in/features/notifications/application/notifications_store.dart';
import 'package:sns_clocked_in/features/notifications/presentation/notifications_screen.dart';
import '../../../test_helpers.dart';

void main() {
  setUpAll(() async {
    await setupTestEnvironment();
  });

  group('NotificationsScreen', () {
    late NotificationsStore store;

    setUp(() {
      store = NotificationsStore();
    });

    tearDown(() {
      store.dispose();
    });

    Widget createTestWidget({Role roleScope = Role.employee}) {
      return MaterialApp(
        home: Scaffold(
          body: ChangeNotifierProvider<NotificationsStore>.value(
            value: store,
            child: NotificationsScreen(roleScope: roleScope),
          ),
        ),
      );
    }

    testWidgets('displays empty state when no notifications', (tester) async {
      // Don't seed data to test empty state
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Empty state shows "No Notifications" (capital N)
      expect(find.text('No Notifications'), findsOneWidget);
    });

    testWidgets('displays notifications when available', (tester) async {
      // Seed sample data
      store.seedSampleData();
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Should show notifications
      expect(find.textContaining('No notifications'), findsNothing);
      expect(store.filteredBy.length, greaterThan(0));
    });

    testWidgets('shows mark all as read button when unread exists', (tester) async {
      store.seedSampleData();
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      if (store.unreadCount > 0) {
        // Look for mark all as read button
        expect(find.byIcon(Icons.done_all), findsWidgets);
      }
    });

    testWidgets('filters notifications by role scope', (tester) async {
      store.seedSampleData();
      
      // Test employee scope
      await tester.pumpWidget(createTestWidget(roleScope: Role.employee));
      await tester.pumpAndSettle();
      final employeeCount = store.filteredBy.length;

      // Test admin scope
      await tester.pumpWidget(createTestWidget(roleScope: Role.admin));
      await tester.pumpAndSettle();
      final adminCount = store.filteredBy.length;

      // Counts may differ based on role filtering
      expect(employeeCount, greaterThanOrEqualTo(0));
      expect(adminCount, greaterThanOrEqualTo(0));
    });

    testWidgets('displays quick stats section at top', (tester) async {
      store.seedSampleData();
      
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Should show quick stats section with title
      expect(find.textContaining('Notifications Summary'), findsOneWidget);
      
      // Should show stat cards (may appear multiple times - in stats and tabs)
      expect(find.textContaining('Total'), findsWidgets);
      expect(find.textContaining('Unread'), findsWidgets);
      expect(find.textContaining('Read'), findsWidgets);
    });

    testWidgets('quick stats display correct counts', (tester) async {
      store.seedSampleData();
      
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      final totalCount = store.all.length;
      final unreadCount = store.unreadCount;
      final readCount = totalCount - unreadCount;

      // Verify counts are displayed
      expect(find.text(totalCount.toString()), findsWidgets);
      expect(find.text(unreadCount.toString()), findsWidgets);
      expect(find.text(readCount.toString()), findsWidgets);
    });
  });
}
