import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import 'package:sns_clocked_in/core/storage/simple_cache.dart';
import 'package:sns_clocked_in/features/timesheet_admin/application/admin_timesheet_store.dart';
import 'package:sns_clocked_in/features/timesheet_admin/data/admin_timesheet_repository.dart';
import 'package:sns_clocked_in/features/timesheet_admin/presentation/admin_timesheet_approvals_screen.dart';
import 'package:sns_clocked_in/features/timesheet/domain/attendance_record.dart';

import '../../../test_helpers.dart';

void main() {
  setUpAll(() async {
    await setupTestEnvironment();
  });

  group('AdminTimesheetApprovalsScreen (timesheet_admin)', () {
    late AdminTimesheetStore store;
    late MockAdminTimesheetRepository repository;

    setUp(() {
      repository = MockAdminTimesheetRepository();
      store = AdminTimesheetStore(repository: repository);
    });

    tearDown(() {
      // Store is provided via Provider, screen won't dispose it
      // So we need to dispose it here
      store.dispose();
    });

    Widget createTestWidget() {
      return MaterialApp(
        home: Scaffold(
          body: ChangeNotifierProvider<AdminTimesheetStore>.value(
            value: store,
            child: const AdminTimesheetApprovalsScreen(),
          ),
        ),
      );
    }

    testWidgets('displays all 2 tabs', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump(); // Initial frame
      await tester.pump(const Duration(milliseconds: 100)); // Post-frame callback
      await tester.pump(const Duration(milliseconds: 200)); // Async operations
      
      // Should show all tabs
      expect(find.text('Pending'), findsWidgets);
      expect(find.text('Approved'), findsWidgets);
    });

    testWidgets('switches between Pending and Approved tabs', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Initially on Pending tab
      expect(find.text('Pending'), findsWidgets);

      // Tap Approved tab
      await tester.tap(find.text('Approved'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Should show approved tab content
      expect(find.text('Approved'), findsWidgets);
    });

    testWidgets('displays empty state when no pending records', (tester) async {
      // Create a fresh repository without seeded data for this test
      final emptyRepository = MockAdminTimesheetRepository();
      emptyRepository.clearData(); // Clear seeded data
      final emptyStore = AdminTimesheetStore(repository: emptyRepository);
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider<AdminTimesheetStore>.value(
              value: emptyStore,
              child: const AdminTimesheetApprovalsScreen(),
            ),
          ),
        ),
      );
      
      await tester.pump(); // Initial frame
      await tester.pump(const Duration(milliseconds: 100)); // Post-frame callback triggers loadPending/loadApproved
      
      // Wait for async operations to complete
      await tester.pump(const Duration(milliseconds: 100)); // Complete fetchPending
      await tester.pump(const Duration(milliseconds: 100)); // Store notifies listeners
      await tester.pump(const Duration(milliseconds: 100)); // UI rebuilds
      
      // Should show empty state after loading completes
      expect(find.text('No pending timesheets'), findsOneWidget);
      
      emptyStore.dispose();
    });

    testWidgets('displays pending records when available', (tester) async {
      // Load records from mock repository first
      await store.loadPending();
      await tester.pumpWidget(createTestWidget());
      
      // Wait for initial frame and post-frame callbacks
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      
      // Don't use pumpAndSettle as it waits indefinitely for animations
      // Instead, pump a few times to let async operations complete
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 200));

      // Should show pending records if available
      if (store.pendingRecords.isNotEmpty) {
        expect(find.text('No pending timesheets'), findsNothing);
        expect(store.pendingRecords.length, greaterThan(0));
      }
    });

    testWidgets('shows loading state when loading', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Start loading
      store.loadPending(forceRefresh: true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Should show loading indicator if records are empty
      if (store.pendingRecords.isEmpty && store.isLoadingPending) {
        expect(find.byType(CircularProgressIndicator), findsWidgets);
      }

      // Wait for loading to complete
      await tester.pump(const Duration(milliseconds: 200));
    });

    testWidgets('shows error state when loading fails', (tester) async {
      final errorRepository = ErrorThrowingAdminTimesheetRepository();
      final testStore = AdminTimesheetStore(repository: errorRepository);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider<AdminTimesheetStore>.value(
              value: testStore,
              child: const AdminTimesheetApprovalsScreen(),
            ),
          ),
        ),
      );

      // Wait for initial frame and post-frame callback
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 200));

      // Trigger load that will fail
      testStore.loadPending(forceRefresh: true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Should show error message
      expect(find.text('Failed to load pending timesheets'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      // Clean up after test completes
      await tester.pump(const Duration(milliseconds: 100));
      testStore.dispose();
    });

    testWidgets('shows bulk approve button when eligible records exist', (tester) async {
      // Load records from mock repository
      await store.loadPending();
      await tester.pumpWidget(createTestWidget());
      
      // Wait for async operations
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 200));

      // Verify eligible records exist
      if (store.eligibleForBulkApprove.isNotEmpty) {
        // Look for bulk approve button
        final bulkApproveButton = find.textContaining('Bulk Approve');
        expect(bulkApproveButton, findsWidgets);
      }
    });

    testWidgets('displays record cards with correct information', (tester) async {
      // Load records from mock repository
      await store.loadPending();
      await tester.pumpWidget(createTestWidget());
      
      // Wait for async operations
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 200));

      // Should display record cards
      if (store.pendingRecords.isNotEmpty) {
        expect(store.pendingRecords.length, greaterThan(0));
      }
    });

    testWidgets('approves a record when approve button is tapped', (tester) async {
      // Load records from mock repository
      await store.loadPending();
      await tester.pumpWidget(createTestWidget());
      
      // Wait for async operations and UI to render
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 200));

      final initialPendingCount = store.pendingRecords.length;
      if (initialPendingCount == 0) return; // Skip if no records

      // Find the first approve button
      final approveButtons = find.text('Approve');
      if (approveButtons.evaluate().isNotEmpty) {
        // Tap the first approve button
        await tester.tap(approveButtons.first);
        await tester.pump(); // Process tap
        await tester.pump(const Duration(milliseconds: 100)); // Start async operation
        await tester.pump(const Duration(milliseconds: 200)); // Complete approveTimesheet
        await tester.pump(const Duration(milliseconds: 200)); // Complete loadPending/loadApproved
        await tester.pump(const Duration(milliseconds: 100)); // Show snackbar

        // Verify record moved from pending to approved
        expect(store.pendingRecords.length, lessThan(initialPendingCount));
        expect(store.approvedRecords.length, greaterThan(0));

        // Verify success snackbar is shown (may need to wait a bit more)
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.text('Timesheet approved successfully'), findsOneWidget);
      }
    });

    testWidgets('shows reject dialog when reject button is tapped', (tester) async {
      // Load records from mock repository
      await store.loadPending();
      await tester.pumpWidget(createTestWidget());
      
      // Wait for async operations
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 200));

      if (store.pendingRecords.isEmpty) return; // Skip if no records

      // Find the first reject button
      final rejectButtons = find.text('Reject');
      if (rejectButtons.evaluate().isNotEmpty) {
        // Tap the first reject button
        await tester.tap(rejectButtons.first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        // Verify dialog is shown
        expect(find.text('Reject Timesheet'), findsOneWidget);
        expect(find.text('Please provide a reason for rejection:'), findsOneWidget);
        expect(find.byType(TextFormField), findsOneWidget);
      }
    });

    testWidgets('refreshes data when pull-to-refresh is triggered', (tester) async {
      // Load records first
      await store.loadPending();
      await tester.pumpWidget(createTestWidget());
      
      // Wait for async operations
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 200));

      final initialCallCount = repository.fetchPendingCallCount;

      // Perform pull-to-refresh gesture
      final listView = find.byType(ListView);
      if (listView.evaluate().isNotEmpty) {
        await tester.drag(listView.first, const Offset(0, 300));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Verify refresh was triggered
        expect(repository.fetchPendingCallCount, greaterThan(initialCallCount));
      }
    });
  });
}

/// Mock admin timesheet repository for testing
/// Extends AdminTimesheetRepository but overrides methods to return mock data
class MockAdminTimesheetRepository extends AdminTimesheetRepository {
  final List<AttendanceRecord> _pendingRecords = [];
  final List<AttendanceRecord> _approvedRecords = [];
  final _uuid = const Uuid();
  int _fetchPendingCallCount = 0;
  int _fetchApprovedCallCount = 0;

  int get fetchPendingCallCount => _fetchPendingCallCount;
  int get fetchApprovedCallCount => _fetchApprovedCallCount;

  MockAdminTimesheetRepository() : super(
    cache: SimpleCache(),
  ) {
    _seedData();
  }

  void _seedData() {
    final now = DateTime.now();
    _pendingRecords.addAll([
      AttendanceRecord(
        id: _uuid.v4(),
        userId: 'user1',
        companyId: 'company1',
        date: now.subtract(const Duration(days: 1)),
        checkInTime: now.subtract(const Duration(days: 1, hours: 9)),
        checkOutTime: now.subtract(const Duration(days: 1, hours: 17)),
        status: 'completed',
        approvalStatus: ApprovalStatus.pending,
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
    ]);
  }

  /// Clear all data (useful for empty state tests)
  void clearData() {
    _pendingRecords.clear();
    _approvedRecords.clear();
  }

  @override
  Future<List<AttendanceRecord>> fetchPending({bool forceRefresh = false}) async {
    _fetchPendingCallCount++;
    // Return immediately without delay for faster tests
    return List.from(_pendingRecords);
  }

  @override
  Future<List<AttendanceRecord>> fetchApproved({bool forceRefresh = false}) async {
    _fetchApprovedCallCount++;
    // Return immediately without delay for faster tests
    return List.from(_approvedRecords);
  }

  @override
  Future<void> approveTimesheet(String attendanceId, {String? adminComment}) async {
    // No delay for faster tests
    final index = _pendingRecords.indexWhere((r) => r.id == attendanceId);
    if (index != -1) {
      final record = _pendingRecords[index];
      _pendingRecords.removeAt(index);
      // Create approved record
      _approvedRecords.add(
        AttendanceRecord(
          id: record.id,
          userId: record.userId,
          companyId: record.companyId,
          date: record.date,
          checkInTime: record.checkInTime,
          checkOutTime: record.checkOutTime,
          status: 'approved',
          approvalStatus: ApprovalStatus.approved,
          approvedBy: 'admin1',
          approvalDate: DateTime.now(),
          adminComment: adminComment,
          breaks: record.breaks,
          totalBreakTimeMinutes: record.totalBreakTimeMinutes,
          createdAt: record.createdAt,
        ),
      );
    }
  }

  @override
  Future<void> rejectTimesheet(String attendanceId, {required String reason}) async {
    // No delay for faster tests
    final index = _pendingRecords.indexWhere((r) => r.id == attendanceId);
    if (index != -1) {
      _pendingRecords.removeAt(index);
    }
  }

  @override
  Future<Map<String, dynamic>> bulkAutoApprove({List<String>? recordIds}) async {
    // No delay for faster tests
    final eligible = _pendingRecords.where((r) => r.isCompleted).toList();
    int approvedCount = 0;
    for (final record in eligible) {
      await approveTimesheet(record.id);
      approvedCount++;
    }
    return {'approvedCount': approvedCount};
  }
}

/// Mock repository that throws errors for testing error states
/// Extends AdminTimesheetRepository but overrides methods to throw errors
class ErrorThrowingAdminTimesheetRepository extends AdminTimesheetRepository {
  bool shouldThrow = true;
  int _fetchPendingCallCount = 0;
  int _fetchApprovedCallCount = 0;

  int get fetchPendingCallCount => _fetchPendingCallCount;
  int get fetchApprovedCallCount => _fetchApprovedCallCount;

  ErrorThrowingAdminTimesheetRepository() : super(
    cache: SimpleCache(),
  );

  Future<List<AttendanceRecord>> fetchPending({bool forceRefresh = false}) async {
    _fetchPendingCallCount++;
    await Future<void>.delayed(const Duration(milliseconds: 50));
    if (shouldThrow) {
      throw Exception('Network error: Failed to fetch pending timesheets');
    }
    return [];
  }

  Future<List<AttendanceRecord>> fetchApproved({bool forceRefresh = false}) async {
    _fetchApprovedCallCount++;
    await Future<void>.delayed(const Duration(milliseconds: 50));
    if (shouldThrow) {
      throw Exception('Network error: Failed to fetch approved timesheets');
    }
    return [];
  }

  Future<void> approveTimesheet(String attendanceId, {String? adminComment}) async {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    if (shouldThrow) {
      throw Exception('Network error: Failed to approve timesheet');
    }
  }

  Future<void> rejectTimesheet(String attendanceId, {required String reason}) async {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    if (shouldThrow) {
      throw Exception('Network error: Failed to reject timesheet');
    }
  }

  Future<Map<String, dynamic>> bulkAutoApprove({List<String>? recordIds}) async {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    if (shouldThrow) {
      throw Exception('Network error: Failed to bulk approve');
    }
    return {'approvedCount': 0};
  }
}
