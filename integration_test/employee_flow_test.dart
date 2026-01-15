import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sns_clocked_in/features/employee/dashboard/presentation/employee_dashboard_screen.dart';
import 'package:sns_clocked_in/features/splash/presentation/splash_screen.dart';
import 'package:sns_clocked_in/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'employee flow: onboarding -> login -> company select -> dashboard',
    (WidgetTester tester) async {
      // Ensure onboarding is treated as first run
      SharedPreferences.setMockInitialValues({});

      await app.main();
      await tester.pump();

      // Splash screen first
      expect(find.byType(SplashScreen), findsOneWidget);

      // Wait for bootstrap delay (2s) and routing to onboarding
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

      // Navigate through all employee pages via drawer
      await _navigateToDrawerItem(tester, 'Attendance');
      expect(find.text('Attendance'), findsAtLeastNWidgets(1));

      await _navigateToDrawerItem(tester, 'Leave');
      expect(find.text('Leave'), findsAtLeastNWidgets(1));

      await _navigateToDrawerItem(tester, 'Timesheet');
      expect(find.text('Timesheet'), findsAtLeastNWidgets(1));

      await _navigateToDrawerItem(tester, 'Notifications');
      expect(find.text('Notifications'), findsAtLeastNWidgets(1));

      await _navigateToDrawerItem(tester, 'Profile');
      expect(find.text('Profile'), findsAtLeastNWidgets(1));

      await _navigateToDrawerItem(tester, 'Dashboard');
      expect(find.byType(EmployeeDashboardScreen), findsOneWidget);
    },
  );
}

Future<void> _navigateToDrawerItem(WidgetTester tester, String label) async {
  await tester.tap(find.byIcon(Icons.menu).first);
  await tester.pumpAndSettle();

  await tester.tap(find.widgetWithText(ListTile, label));
  await tester.pumpAndSettle();
}
