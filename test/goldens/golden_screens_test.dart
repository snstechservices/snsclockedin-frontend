import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:sns_clocked_in/core/role/role.dart';
import 'package:sns_clocked_in/core/state/app_state.dart';
import 'package:sns_clocked_in/core/storage/simple_cache.dart';
import 'package:sns_clocked_in/features/admin/dashboard/presentation/admin_dashboard_screen.dart';
import 'package:sns_clocked_in/features/employees/application/employees_store.dart';
import 'package:sns_clocked_in/features/employees/presentation/admin_employees_screen.dart';
import 'package:sns_clocked_in/features/employee/dashboard/presentation/employee_dashboard_screen.dart';
import 'package:sns_clocked_in/features/leave/application/admin_leave_approvals_store.dart';
import 'package:sns_clocked_in/features/leave/application/admin_leave_context_store.dart';
import 'package:sns_clocked_in/features/leave/application/leave_accrual_store.dart';
import 'package:sns_clocked_in/features/leave/application/leave_balances_store.dart';
import 'package:sns_clocked_in/features/leave/application/leave_cash_out_store.dart';
import 'package:sns_clocked_in/features/leave/application/leave_store.dart';
import 'package:sns_clocked_in/features/leave/data/leave_repository.dart';
import 'package:sns_clocked_in/features/leave/domain/leave_request.dart';
import 'package:sns_clocked_in/features/leave/presentation/admin_leave_overview_screen.dart';
import 'package:sns_clocked_in/features/notifications/application/notifications_store.dart';
import 'package:sns_clocked_in/features/notifications/domain/app_notification.dart';
import 'package:sns_clocked_in/features/notifications/presentation/notifications_screen.dart';
import 'package:sns_clocked_in/features/profile/application/profile_store.dart';
import 'package:sns_clocked_in/features/time_tracking/application/time_tracking_store.dart';
import 'package:sns_clocked_in/features/timesheet/application/admin_approvals_store.dart';
import 'package:sns_clocked_in/features/timesheet/data/admin_approvals_repository.dart';
import 'package:sns_clocked_in/features/timesheet/domain/attendance_record.dart';
import 'package:sns_clocked_in/features/timesheet/presentation/admin_timesheet_approvals_screen.dart';
import 'golden_mocks.dart';
import '../test_helpers.dart';

/// Golden tests for key admin screens (light theme, phone 390x844)
/// Generate/refresh with: flutter test --update-goldens test/goldens/golden_screens_test.dart
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await setupTestEnvironment();
  });

  Future<void> _setSurface(WidgetTester tester) async {
    final binding = tester.binding;
    await binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => binding.setSurfaceSize(null));
  }

  group('Goldens - Admin Leave Requests', () {
    testWidgets('leave requests tab', (tester) async {
      await _setSurface(tester);

      final approvalsStore = AdminLeaveApprovalsStore(
        repository: GoldenLeaveRepository(),
        cache: SimpleCache(),
      );
      final contextStore = AdminLeaveContextStore();
      final accrualStore = LeaveAccrualStore();
      final cashOutStore = LeaveCashOutStore();

      final router = GoRouter(
        initialLocation: '/a/leave',
        routes: [
          GoRoute(
            path: '/a/leave',
            builder: (context, state) => Scaffold(
              body: MultiProvider(
                providers: [
                  ChangeNotifierProvider.value(value: approvalsStore),
                  ChangeNotifierProvider.value(value: contextStore),
                  ChangeNotifierProvider.value(value: accrualStore),
                  ChangeNotifierProvider.value(value: cashOutStore),
                ],
                child: const AdminLeaveOverviewScreen(),
              ),
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp.router(
          theme: ThemeData.light(),
          routerConfig: router,
        ),
      );

      await tester.pumpAndSettle();
      await expectLater(
        find.byType(AdminLeaveOverviewScreen),
        matchesGoldenFile('goldens/admin_leave_requests.png'),
      );

      // Cleanup
      router.dispose();
      approvalsStore.dispose();
      contextStore.dispose();
      accrualStore.dispose();
      cashOutStore.dispose();
    });
  });

  group('Goldens - Admin Timesheet Approvals', () {
    testWidgets('pending tab', (tester) async {
      await _setSurface(tester);

      final store = AdminApprovalsStore(
        repository: GoldenAdminApprovalsRepository(),
        cache: SimpleCache(),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: Scaffold(
            body: ChangeNotifierProvider.value(
              value: store,
              child: const AdminTimesheetApprovalsScreen(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await expectLater(
        find.byType(AdminTimesheetApprovalsScreen),
        matchesGoldenFile('goldens/admin_timesheet_pending.png'),
      );

      // Cleanup
      store.dispose();
    });

    testWidgets('approved tab', (tester) async {
      await _setSurface(tester);

      final store = AdminApprovalsStore(
        repository: GoldenAdminApprovalsRepository(),
        cache: SimpleCache(),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: Scaffold(
            body: ChangeNotifierProvider.value(
              value: store,
              child: const AdminTimesheetApprovalsScreen(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      // Switch to Approved tab
      await tester.tap(find.text('Approved'));
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(AdminTimesheetApprovalsScreen),
        matchesGoldenFile('goldens/admin_timesheet_approved.png'),
      );

      // Cleanup
      store.dispose();
    });
  });

  group('Goldens - Employees list', () {
    testWidgets('employees list', (tester) async {
      await _setSurface(tester);

      final store = EmployeesStore()..seedSampleData();

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: Scaffold(
            body: ChangeNotifierProvider.value(
              value: store,
              child: const AdminEmployeesScreen(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await expectLater(
        find.byType(AdminEmployeesScreen),
        matchesGoldenFile('goldens/admin_employees.png'),
      );

      // Cleanup
      store.dispose();
    });
  });

  group('Goldens - Notifications', () {
    testWidgets('notifications list', (tester) async {
      await _setSurface(tester);

      final store = NotificationsStore()..seedSampleData();
      final appState = AppState();

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: Scaffold(
            body: MultiProvider(
              providers: [
                ChangeNotifierProvider.value(value: store),
                ChangeNotifierProvider.value(value: appState),
              ],
              child: const NotificationsScreen(roleScope: Role.admin),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await expectLater(
        find.byType(NotificationsScreen),
        matchesGoldenFile('goldens/admin_notifications.png'),
      );

      // Cleanup
      store.dispose();
      appState.dispose();
    });
  });
}

