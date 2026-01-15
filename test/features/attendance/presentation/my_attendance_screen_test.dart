import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sns_clocked_in/core/role/role.dart';
import 'package:sns_clocked_in/features/attendance/application/attendance_store.dart';
import 'package:sns_clocked_in/features/attendance/presentation/my_attendance_screen.dart';
import 'package:sns_clocked_in/features/time_tracking/application/time_tracking_store.dart';
import 'package:sns_clocked_in/features/time_tracking/data/time_tracking_repository.dart';
import '../../../test_helpers.dart';

void main() {
  setUpAll(() async {
    await setupTestEnvironment();
  });

  group('MyAttendanceScreen', () {
    late AttendanceStore attendanceStore;
    late TimeTrackingStore timeTrackingStore;

    setUp(() {
      final repository = MockTimeTrackingRepository();
      attendanceStore = AttendanceStore(repository: repository);
      timeTrackingStore = TimeTrackingStore(repository: repository);
    });

    tearDown(() {
      attendanceStore.dispose();
      timeTrackingStore.dispose();
    });

    Widget createTestWidget({Role roleScope = Role.employee}) {
      return MaterialApp(
        home: Scaffold(
          body: MultiProvider(
            providers: [
              ChangeNotifierProvider<AttendanceStore>.value(value: attendanceStore),
              ChangeNotifierProvider<TimeTrackingStore>.value(value: timeTrackingStore),
            ],
            child: MyAttendanceScreen(roleScope: roleScope),
          ),
        ),
      );
    }

    testWidgets('displays quick stats section at top', (tester) async {
      await attendanceStore.loadHistory();
      
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Should show quick stats section with title
      expect(find.textContaining('Attendance Summary'), findsOneWidget);
      
      // Should show stat cards
      expect(find.textContaining('Total Days'), findsOneWidget);
      expect(find.textContaining('On Time'), findsOneWidget);
    });

    testWidgets('quick stats section is always visible', (tester) async {
      await attendanceStore.loadHistory();
      
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Quick stats should be visible
      final quickStatsFinder = find.textContaining('Attendance Summary');
      expect(quickStatsFinder, findsOneWidget);
    });

    testWidgets('displays today timeline section', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.textContaining('Today Timeline'), findsOneWidget);
    });

    testWidgets('displays history section', (tester) async {
      await attendanceStore.loadHistory();
      
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.textContaining('History'), findsOneWidget);
    });

    testWidgets('works for both employee and admin roles', (tester) async {
      await attendanceStore.loadHistory();
      
      // Test employee role
      await tester.pumpWidget(createTestWidget(roleScope: Role.employee));
      await tester.pumpAndSettle();
      expect(find.textContaining('Attendance Summary'), findsOneWidget);

      // Test admin role
      await tester.pumpWidget(createTestWidget(roleScope: Role.admin));
      await tester.pumpAndSettle();
      expect(find.textContaining('Attendance Summary'), findsOneWidget);
    });
  });
}
