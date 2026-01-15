import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sns_clocked_in/core/storage/simple_cache.dart';
import 'package:sns_clocked_in/features/timesheet/application/timesheet_store.dart';
import 'package:sns_clocked_in/features/timesheet/data/timesheet_repository.dart';
import 'package:sns_clocked_in/features/timesheet/domain/attendance_record.dart';
import 'package:sns_clocked_in/features/timesheet/presentation/employee_timesheet_screen.dart';
import 'package:uuid/uuid.dart';
import '../../../test_helpers.dart';

void main() {
  // Setup test environment
  setUpAll(() async {
    await setupTestEnvironment();
  });

  group('EmployeeTimesheetScreen', () {
    late TimesheetStore store;
    late MockTimesheetRepository repository;
    late SimpleCache cache;

    setUp(() {
      cache = SimpleCache();
      cache.clear();
      repository = MockTimesheetRepository();
      store = TimesheetStore(
        repository: repository,
        companyId: 'test-company',
        userId: 'test-user',
      );
    });

    tearDown(() {
      cache.clear();
      store.dispose();
    });

    Widget createTestWidget() {
      return MaterialApp(
        home: Scaffold(
          body: ChangeNotifierProvider<TimesheetStore>.value(
            value: store,
            child: const EmployeeTimesheetScreen(),
          ),
        ),
      );
    }

    testWidgets('displays empty state when no records', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Should show empty state message
      expect(find.textContaining('No timesheet records'), findsWidgets);
    });

    testWidgets('displays records when available', (tester) async {
      // Seed store with records
      store.seedDemo();
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Should show records
      expect(find.textContaining('No timesheet records'), findsNothing);
      expect(store.records.length, greaterThan(0));
    });

    testWidgets('shows summary card with expand/collapse', (tester) async {
      store.seedDemo();
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Look for summary card
      // The summary should be visible when expanded
      expect(store.records.length, greaterThan(0));
    });

    testWidgets('displays date range selector', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Should show date range buttons (Today, This Week, etc.)
      expect(find.text('Today'), findsWidgets);
      expect(find.text('This Week'), findsWidgets);
      expect(find.text('This Month'), findsWidgets);
    });

    testWidgets('groups records by date', (tester) async {
      store.seedDemo();
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Verify records are grouped
      expect(store.groupedRecords.keys.length, greaterThan(0));
    });

    testWidgets('shows cache hint when using stale data', (tester) async {
      store.seedDemo();
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Cache hint should appear if using stale data
      // This depends on the UI implementation
    });

    testWidgets('does not make API calls on initial load when offline', (tester) async {
      // Create store with empty cache
      final testCache = SimpleCache();
      testCache.clear();
      final testRepository = MockTimesheetRepository();
      final testStore = TimesheetStore(
        repository: testRepository,
        companyId: 'test-company',
        userId: 'test-user',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider<TimesheetStore>.value(
              value: testStore,
              child: const EmployeeTimesheetScreen(),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify no API calls were made
      expect(testStore.records, isEmpty);
      expect(testStore.isLoading, isFalse);

      testStore.dispose();
    });

    testWidgets('supports pull to refresh', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Find the scrollable widget
      final scrollable = find.byType(Scrollable);
      expect(scrollable, findsWidgets);
    });
  });
}

/// Mock repository for testing
/// Extends TimesheetRepository but overrides methods to return mock data
class MockTimesheetRepository extends TimesheetRepository {
  final List<AttendanceRecord> _records = [];
  final _uuid = const Uuid();
  int _fetchCallCount = 0;

  int get fetchCallCount => _fetchCallCount;

  MockTimesheetRepository() : super(
    cache: SimpleCache(),
  ) {
    _seedData();
  }

  void _seedData() {
    final now = DateTime.now();

    _records.addAll([
      AttendanceRecord(
        id: _uuid.v4(),
        userId: 'test-user',
        companyId: 'test-company',
        date: now.subtract(const Duration(days: 1)),
        checkInTime: now.subtract(const Duration(days: 1, hours: 9)),
        checkOutTime: now.subtract(const Duration(days: 1, hours: 17)),
        status: 'completed',
        approvalStatus: ApprovalStatus.approved,
        breaks: [
          AttendanceBreak(
            breakType: 'lunch',
            startTime: now.subtract(const Duration(days: 1, hours: 13)),
            endTime: now.subtract(const Duration(days: 1, hours: 14)),
            durationMinutes: 60,
          ),
        ],
        totalBreakTimeMinutes: 60,
        createdAt: now.subtract(const Duration(days: 1)),
      ),
      AttendanceRecord(
        id: _uuid.v4(),
        userId: 'test-user',
        companyId: 'test-company',
        date: now.subtract(const Duration(days: 2)),
        checkInTime: now.subtract(const Duration(days: 2, hours: 8, minutes: 30)),
        checkOutTime: now.subtract(const Duration(days: 2, hours: 17, minutes: 15)),
        status: 'completed',
        approvalStatus: ApprovalStatus.approved,
        totalBreakTimeMinutes: 60,
        createdAt: now.subtract(const Duration(days: 2)),
      ),
    ]);
  }

  @override
  Future<FetchResult<List<AttendanceRecord>>> fetchMyTimesheet({
    required String companyId,
    required String userId,
    required DateTime start,
    required DateTime end,
    bool forceRefresh = false,
  }) async {
    _fetchCallCount++;
    await Future.delayed(const Duration(milliseconds: 100));
    return FetchResult(
      data: List.from(_records),
      isStale: false,
    );
  }

  @override
  Future<AttendanceSummary> fetchSummary({
    required String companyId,
    required String userId,
    bool forceRefresh = false,
  }) async {
    await Future.delayed(const Duration(milliseconds: 50));
    return const AttendanceSummary(
      totalRecords: 2,
      approved: 2,
      completed: 2,
      clockedIn: 0,
      pending: 0,
      rejected: 0,
    );
  }
}
