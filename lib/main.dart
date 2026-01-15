import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:sns_clocked_in/app/app.dart';
import 'package:sns_clocked_in/app/bootstrap/app_bootstrap.dart';
import 'package:sns_clocked_in/core/state/app_state.dart';
import 'package:sns_clocked_in/features/attendance/application/attendance_store.dart';
import 'package:sns_clocked_in/features/employees/application/employees_store.dart';
import 'package:sns_clocked_in/features/leave/application/leave_store.dart';
import 'package:sns_clocked_in/features/leave/application/admin_leave_approvals_store.dart';
import 'package:sns_clocked_in/features/leave/application/admin_leave_context_store.dart';
import 'package:sns_clocked_in/features/leave/application/leave_balances_store.dart';
import 'package:sns_clocked_in/features/leave/application/admin_leave_balances_store.dart';
import 'package:sns_clocked_in/features/leave/application/leave_accrual_store.dart';
import 'package:sns_clocked_in/features/leave/application/leave_cash_out_store.dart';
import 'package:sns_clocked_in/features/leave/data/leave_repository.dart';
import 'package:sns_clocked_in/features/notifications/application/notifications_store.dart';
import 'package:sns_clocked_in/features/profile/application/profile_store.dart';
import 'package:sns_clocked_in/features/time_tracking/application/time_tracking_store.dart';
import 'package:sns_clocked_in/features/time_tracking/data/time_tracking_repository.dart';
import 'package:sns_clocked_in/features/attendance/application/break_types_store.dart';
import 'package:sns_clocked_in/features/attendance/data/break_types_repository.dart';
import 'package:sns_clocked_in/features/timesheet/application/admin_approvals_store.dart';
import 'package:sns_clocked_in/features/timesheet/data/admin_approvals_repository.dart';
import 'package:sns_clocked_in/features/timesheet/application/timesheet_store.dart';
import 'package:sns_clocked_in/features/timesheet/data/timesheet_repository.dart';
import 'package:sns_clocked_in/features/timesheet_admin/application/admin_timesheet_store.dart';
import 'package:sns_clocked_in/features/timesheet_admin/data/admin_timesheet_repository.dart';
import 'package:sns_clocked_in/features/company_calendar/application/company_calendar_store.dart';
import 'package:sns_clocked_in/features/company_calendar/data/company_calendar_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  await dotenv.load();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppState()),
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
        // Admin leave approvals store
        ChangeNotifierProvider(
          create: (_) => AdminLeaveApprovalsStore(
            repository: MockLeaveRepository(),
          ),
        ),
        // Admin leave context store (for cross-tab filtering)
        ChangeNotifierProvider(create: (_) => AdminLeaveContextStore()),
        ChangeNotifierProvider(create: (_) => LeaveBalancesStore()),
        ChangeNotifierProvider(create: (_) => AdminLeaveBalancesStore()),
        ChangeNotifierProvider(create: (_) => LeaveAccrualStore()),
        ChangeNotifierProvider(create: (_) => LeaveCashOutStore()),
        ChangeNotifierProvider(create: (_) => NotificationsStore()),
        ChangeNotifierProvider(create: (_) => ProfileStore()),
        ChangeNotifierProvider(
          create: (_) => TimeTrackingStore(
            repository: MockTimeTrackingRepository(),
          )..loadInitialData(),
        ),
        ChangeNotifierProvider(
          create: (_) => BreakTypesStore(
            repository: ApiBreakTypesRepository(),
          )..load(),
        ),
        ChangeNotifierProvider(
          create: (_) => CompanyCalendarStore(
            repository: MockCompanyCalendarRepository(),
          ),
        ),
        // Admin timesheet approvals store (lazy-loaded, not auto-fired on startup)
        ChangeNotifierProvider(
          create: (_) => AdminApprovalsStore(
            repository: MockAdminApprovalsRepository(),
          ),
        ),
        // Legacy admin timesheet store (kept for backward compatibility)
        ChangeNotifierProvider(
          create: (_) => AdminTimesheetStore(
            repository: AdminTimesheetRepository(),
          ),
        ),
        // Employee timesheet store (depends on AppState for companyId/userId)
        ChangeNotifierProxyProvider<AppState, TimesheetStore>(
          create: (_) {
            // Initial creation with default values
            return TimesheetStore(
              repository: TimesheetRepository(),
              companyId: 'default-company',
              userId: 'default-user',
            );
          },
          update: (context, appState, previous) {
            // Create new instance with values from AppState
            // Previous instance will be automatically disposed
            final companyId = appState.companyId ?? 'default-company';
            final userId = appState.userId ?? 'default-user';
            return TimesheetStore(
              repository: TimesheetRepository(),
              companyId: companyId,
              userId: userId,
            );
          },
        ),
      ],
      child: const AppBootstrap(child: App()),
    ),
  );
}
