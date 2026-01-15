import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sns_clocked_in/core/state/app_state.dart';
import 'package:sns_clocked_in/features/admin/dashboard/presentation/admin_dashboard_screen.dart';
import 'package:sns_clocked_in/features/employees/application/employees_store.dart';
import 'package:sns_clocked_in/features/leave/application/admin_leave_approvals_store.dart';
import 'package:sns_clocked_in/core/storage/simple_cache.dart';
import 'package:sns_clocked_in/features/leave/application/leave_balances_store.dart';
import 'package:sns_clocked_in/features/leave/application/leave_store.dart';
import 'package:sns_clocked_in/features/leave/data/leave_repository.dart';
import 'package:sns_clocked_in/features/time_tracking/application/time_tracking_store.dart';
import 'package:sns_clocked_in/features/time_tracking/data/time_tracking_repository.dart';
import '../../../../../test_helpers.dart';

void main() {
  setUpAll(() async {
    await setupTestEnvironment();
  });

  group('AdminDashboardScreen', () {
    late EmployeesStore employeesStore;
    late AdminLeaveApprovalsStore leaveApprovalsStore;
    late LeaveStore leaveStore;
    late LeaveBalancesStore leaveBalancesStore;
    late TimeTrackingStore timeTrackingStore;
    late AppState appState;

    setUp(() {
      employeesStore = EmployeesStore();
      leaveApprovalsStore = AdminLeaveApprovalsStore(
        repository: MockLeaveRepository(),
        cache: SimpleCache()..clear(),
      );
      leaveStore = LeaveStore(
        repository: MockLeaveRepository(),
        cache: SimpleCache()..clear(),
      );
      leaveBalancesStore = LeaveBalancesStore();
      timeTrackingStore = TimeTrackingStore(repository: MockTimeTrackingRepository());
      appState = AppState();
    });

    tearDown(() {
      employeesStore.dispose();
      leaveApprovalsStore.dispose();
      leaveStore.dispose();
      leaveBalancesStore.dispose();
      timeTrackingStore.dispose();
      appState.dispose();
    });

    Widget createTestWidget() {
      return MaterialApp(
        home: Scaffold(
          body: MultiProvider(
            providers: [
              ChangeNotifierProvider<AppState>.value(value: appState),
              ChangeNotifierProvider<EmployeesStore>.value(value: employeesStore),
              ChangeNotifierProvider<AdminLeaveApprovalsStore>.value(value: leaveApprovalsStore),
              ChangeNotifierProvider<LeaveStore>.value(value: leaveStore),
              ChangeNotifierProvider<LeaveBalancesStore>.value(value: leaveBalancesStore),
              ChangeNotifierProvider<TimeTrackingStore>.value(value: timeTrackingStore),
            ],
            child: const AdminDashboardScreen(),
          ),
        ),
      );
    }

    testWidgets('displays quick stats section at top', (tester) async {
      employeesStore.seedSampleData();
      leaveApprovalsStore.seedDebugData();
      
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Should show quick stats section with title
      expect(find.textContaining('Dashboard Summary'), findsOneWidget);
      
      // Should show stat cards
      expect(find.textContaining('Total Users'), findsOneWidget);
      expect(find.textContaining('Present'), findsOneWidget);
      expect(find.textContaining('On Leave'), findsOneWidget);
      expect(find.textContaining('Absent'), findsOneWidget);
      expect(find.textContaining('Pending Approvals'), findsOneWidget);
    });

    testWidgets('quick stats section is always visible (not in scrollable)', (tester) async {
      employeesStore.seedSampleData();
      
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Quick stats should be in a Column structure (not inside SingleChildScrollView)
      final quickStatsFinder = find.textContaining('Dashboard Summary');
      expect(quickStatsFinder, findsOneWidget);
      
      // Verify it's in the correct widget tree structure
      final quickStatsWidget = tester.widget<Text>(quickStatsFinder);
      expect(quickStatsWidget, isNotNull);
    });

    testWidgets('displays header card with welcome message', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.textContaining('Welcome back'), findsOneWidget);
    });

    testWidgets('displays quick actions section', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.textContaining('Quick Actions'), findsOneWidget);
      expect(find.text('Employees'), findsOneWidget);
      expect(find.text('Leave'), findsOneWidget);
      expect(find.text('Attendance'), findsOneWidget);
    });

    testWidgets('displays attendance overview section', (tester) async {
      employeesStore.seedSampleData();
      
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.textContaining("Today's Attendance"), findsOneWidget);
    });

    testWidgets('displays department table', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.textContaining('Department-wise Attendance'), findsOneWidget);
    });
  });
}
