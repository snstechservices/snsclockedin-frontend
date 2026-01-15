import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sns_clocked_in/app/app.dart';
import 'package:sns_clocked_in/app/bootstrap/app_bootstrap.dart';
import 'package:sns_clocked_in/core/state/app_state.dart';
import 'package:sns_clocked_in/features/attendance/application/attendance_store.dart';
import 'package:sns_clocked_in/features/attendance/application/break_types_store.dart';
import 'package:sns_clocked_in/features/attendance/data/break_types_repository.dart';
import 'package:sns_clocked_in/features/company_calendar/application/company_calendar_store.dart';
import 'package:sns_clocked_in/features/company_calendar/data/company_calendar_repository.dart';
import 'package:sns_clocked_in/features/employees/application/employees_store.dart';
import 'package:sns_clocked_in/features/employee/dashboard/presentation/employee_dashboard_screen.dart';
import 'package:sns_clocked_in/features/leave/application/leave_balances_store.dart';
import 'package:sns_clocked_in/features/leave/application/leave_store.dart';
import 'package:sns_clocked_in/features/leave/data/leave_repository.dart';
import 'package:sns_clocked_in/features/notifications/application/notifications_store.dart';
import 'package:sns_clocked_in/features/profile/application/profile_store.dart';
import 'package:sns_clocked_in/features/time_tracking/application/time_tracking_store.dart';
import 'package:sns_clocked_in/features/time_tracking/data/time_tracking_repository.dart';
import 'package:sns_clocked_in/features/splash/presentation/splash_screen.dart';
import '../test_helpers.dart';

/// Integration test for employee user flow
///
/// Tests the complete journey:
/// - Login as employee
/// - View dashboard
/// - Navigate to attendance
/// - View timesheet
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Employee Flow Integration Test', () {
    setUpAll(() async {
      SharedPreferences.setMockInitialValues({});
      await setupTestEnvironment();
    });

    testWidgets(
      'onboarding -> login -> company select -> employee dashboard',
      (WidgetTester tester) async {
        final appState = AppState();

        await tester.pumpWidget(_buildTestApp(appState));

        // Splash screen should be visible initially
        expect(find.byType(SplashScreen), findsOneWidget);

        // Wait for bootstrap delay (2s) + routing to onboarding
        await tester.pump(const Duration(milliseconds: 2100));
        await tester.pumpAndSettle();

        // Onboarding should appear
        expect(find.text('Track Your Time'), findsOneWidget);

        // Skip onboarding
        await tester.tap(find.text('Skip'));
        await tester.pumpAndSettle();

        // Login screen should appear
        expect(find.byKey(const Key('login_demo_button')), findsOneWidget);

        // Use demo autofill + login
        await tester.tap(find.byKey(const Key('login_demo_button')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pumpAndSettle();

        // Company selection should appear (mock provides multiple companies)
        expect(find.text('Select Company'), findsOneWidget);
        await tester.tap(find.text('S&S Consulting'));
        await tester.pumpAndSettle();

        // Employee dashboard should be visible
        expect(find.byType(EmployeeDashboardScreen), findsOneWidget);
      },
    );
  });
}

Widget _buildTestApp(AppState appState) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AppState>.value(value: appState),
      ChangeNotifierProvider(
        create: (_) => AttendanceStore(
          repository: MockTimeTrackingRepository(),
        )..loadHistory(),
      ),
      ChangeNotifierProvider(create: (_) => EmployeesStore()),
      ChangeNotifierProvider(
        create: (_) => LeaveStore(
          repository: MockLeaveRepository(),
        ),
      ),
      ChangeNotifierProvider(create: (_) => LeaveBalancesStore()),
      ChangeNotifierProvider(create: (_) => NotificationsStore()),
      ChangeNotifierProvider(create: (_) => ProfileStore()),
      ChangeNotifierProvider(
        create: (_) => TimeTrackingStore(
          repository: MockTimeTrackingRepository(),
        )..loadInitialData(),
      ),
      ChangeNotifierProvider(
        create: (_) => BreakTypesStore(
          repository: MockBreakTypesRepository(),
        ),
      ),
      ChangeNotifierProvider(
        create: (_) => CompanyCalendarStore(
          repository: MockCompanyCalendarRepository(),
        ),
      ),
    ],
    child: const AppBootstrap(child: App()),
  );
}
