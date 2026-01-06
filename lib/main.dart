import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:sns_clocked_in/app/app.dart';
import 'package:sns_clocked_in/app/bootstrap/app_bootstrap.dart';
import 'package:sns_clocked_in/core/state/app_state.dart';
import 'package:sns_clocked_in/features/attendance/application/attendance_store.dart';
import 'package:sns_clocked_in/features/employees/application/employees_store.dart';
import 'package:sns_clocked_in/features/leave/application/leave_store.dart';
import 'package:sns_clocked_in/features/notifications/application/notifications_store.dart';
import 'package:sns_clocked_in/features/profile/application/profile_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  await dotenv.load();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppState()),
        ChangeNotifierProvider(create: (_) => AttendanceStore()),
        ChangeNotifierProvider(create: (_) => EmployeesStore()),
        ChangeNotifierProvider(create: (_) => LeaveStore()),
        ChangeNotifierProvider(create: (_) => NotificationsStore()),
        ChangeNotifierProvider(create: (_) => ProfileStore()),
      ],
      child: const AppBootstrap(child: App()),
    ),
  );
}
