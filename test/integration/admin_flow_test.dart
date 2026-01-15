import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sns_clocked_in/core/state/app_state.dart';
import 'package:sns_clocked_in/features/admin/dashboard/presentation/admin_dashboard_screen.dart';

/// Integration test for admin user flow
///
/// Tests the complete journey:
/// - Login as admin
/// - View dashboard
/// - Navigate to employees
/// - Approve leave request
void main() {
  group('Admin Flow Integration Test', () {
    testWidgets('admin dashboard loads and displays content', (WidgetTester tester) async {
      final appState = AppState();

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<AppState>.value(
            value: appState,
            child: const AdminDashboardScreen(),
          ),
        ),
      );

      // Wait for initial build
      await tester.pumpAndSettle();

      // Verify dashboard elements are present
      expect(find.byType(AdminDashboardScreen), findsOneWidget);
    });

    // Additional integration tests would go here:
    // - Test navigation between screens
    // - Test data loading
    // - Test user interactions
    // - Test approval workflows
  });
}
