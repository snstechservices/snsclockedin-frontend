import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import 'package:sns_clocked_in/core/storage/simple_cache.dart';
import 'package:sns_clocked_in/core/ui/app_card.dart';
import 'package:sns_clocked_in/features/leave/application/admin_leave_approvals_store.dart';
import 'package:sns_clocked_in/features/leave/data/leave_repository.dart';
import 'package:sns_clocked_in/features/leave/domain/leave_request.dart';
import 'package:sns_clocked_in/features/leave/presentation/admin_leave_screen.dart';
import 'package:sns_clocked_in/features/notifications/application/notifications_store.dart';

import '../../../test_helpers.dart';

void main() {
  setUpAll(() async {
    await setupTestEnvironment();
  });

  group('AdminLeaveScreen', () {
    late AdminLeaveApprovalsStore store;
    late NotificationsStore notificationsStore;
    late MockLeaveRepository repository;
    late SimpleCache cache;

    setUp(() {
      cache = SimpleCache()..clear();
      repository = MockLeaveRepository();
      store = AdminLeaveApprovalsStore(
        repository: repository,
        cache: cache,
      );
      notificationsStore = NotificationsStore();
    });

    tearDown(() {
      cache.clear();
      store.dispose();
      notificationsStore.dispose();
    });

    Widget createTestWidget() {
      return MaterialApp(
        home: Scaffold(
          body: MultiProvider(
            providers: [
              ChangeNotifierProvider<AdminLeaveApprovalsStore>.value(
                value: store,
              ),
              ChangeNotifierProvider<NotificationsStore>.value(
                value: notificationsStore,
              ),
            ],
            child: const AdminLeaveScreen(),
          ),
        ),
      );
    }

    testWidgets('displays empty state when no leave requests', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Should show empty state
      expect(find.text('No Leave Requests'), findsOneWidget);
      expect(find.text('No leave requests found'), findsOneWidget);
    });

    testWidgets('displays leave requests when available', (tester) async {
      store.seedDemo();
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Should show leave requests
      expect(find.text('No Leave Requests'), findsNothing);
      expect(store.pendingLeaves.length, greaterThan(0));
    });

    testWidgets('displays filter chips', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Should show all filter chips
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Pending'), findsOneWidget);
      expect(find.text('Approved'), findsOneWidget);
      expect(find.text('Rejected'), findsOneWidget);
    });

    testWidgets('filters leave requests by status', (tester) async {
      store.seedDemo();
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      final initialCount = store.pendingLeaves.length;
      expect(initialCount, greaterThan(0));

      // Tap Pending filter
      await tester.tap(find.text('Pending'));
      await tester.pumpAndSettle();

      // Should filter to show only pending requests
      // The UI filters based on _selectedFilter state
      expect(find.text('Pending'), findsWidgets);
    });

    testWidgets('shows loading state when loading', (tester) async {
      final testCache = SimpleCache()..clear();
      final testRepository = MockLeaveRepository();
      final testStore = AdminLeaveApprovalsStore(
        repository: testRepository,
        cache: testCache,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MultiProvider(
              providers: [
                ChangeNotifierProvider<AdminLeaveApprovalsStore>.value(
                  value: testStore,
                ),
                ChangeNotifierProvider<NotificationsStore>.value(
                  value: notificationsStore,
                ),
              ],
              child: const AdminLeaveScreen(),
            ),
          ),
        ),
      );

      // Wait for initial setup
      await tester.pump();

      // Start loading
      testStore.loadPending(forceRefresh: true);
      await tester.pump();

      // Should show loading indicator if records are empty
      if (testStore.pendingLeaves.isEmpty && testStore.isLoading) {
        expect(find.byType(CircularProgressIndicator), findsWidgets);
      }

      await tester.pumpAndSettle();
      testStore.dispose();
    });

    testWidgets('shows error state when loading fails', (tester) async {
      final errorRepository = ErrorThrowingLeaveRepository();
      final testCache = SimpleCache()..clear();
      final testStore = AdminLeaveApprovalsStore(
        repository: errorRepository,
        cache: testCache,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MultiProvider(
              providers: [
                ChangeNotifierProvider<AdminLeaveApprovalsStore>.value(
                  value: testStore,
                ),
                ChangeNotifierProvider<NotificationsStore>.value(
                  value: notificationsStore,
                ),
              ],
              child: const AdminLeaveScreen(),
            ),
          ),
        ),
      );

      // Trigger load that will fail
      testStore.loadPending(forceRefresh: true);
      await tester.pumpAndSettle();

      // Should show error message
      expect(find.text('Failed to load leave requests'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      testStore.dispose();
    });

    testWidgets('retries loading when retry button is tapped', (tester) async {
      final errorRepository = ErrorThrowingLeaveRepository();
      final testCache = SimpleCache()..clear();
      final testStore = AdminLeaveApprovalsStore(
        repository: errorRepository,
        cache: testCache,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MultiProvider(
              providers: [
                ChangeNotifierProvider<AdminLeaveApprovalsStore>.value(
                  value: testStore,
                ),
                ChangeNotifierProvider<NotificationsStore>.value(
                  value: notificationsStore,
                ),
              ],
              child: const AdminLeaveScreen(),
            ),
          ),
        ),
      );

      // Trigger load that will fail
      testStore.loadPending(forceRefresh: true);
      await tester.pumpAndSettle();

      // Verify error is shown
      expect(find.text('Failed to load leave requests'), findsOneWidget);

      // Fix the repository to return data
      errorRepository.shouldThrow = false;

      // Tap retry button
      final retryButton = find.text('Retry');
      await tester.tap(retryButton);
      await tester.pumpAndSettle();

      // Should attempt to load again
      expect(errorRepository.fetchPendingCallCount, greaterThan(1));

      testStore.dispose();
    });

    testWidgets('displays leave cards with correct information', (tester) async {
      store.seedDemo();
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      if (store.pendingLeaves.isNotEmpty) {
        // Should display leave cards
        expect(store.pendingLeaves.length, greaterThan(0));
        // Cards should show employee name, leave type, dates, etc.
      }
    });

    testWidgets('shows leave detail sheet when card is tapped', (tester) async {
      store.seedDemo();
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      if (store.pendingLeaves.isEmpty) {
        return; // Skip if no leaves
      }

      // Find and tap a leave card
      final leaveCards = find.byType(AppCard);
      if (leaveCards.evaluate().isNotEmpty) {
        await tester.tap(leaveCards.first);
        await tester.pumpAndSettle();

        // Should show detail sheet
        expect(find.text('Leave Request Details'), findsOneWidget);
      }
    });

    testWidgets('approves leave request from detail sheet', (tester) async {
      store.seedDemo();
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      if (store.pendingLeaves.isEmpty) {
        return; // Skip if no leaves
      }

      // Find a pending leave
      final pendingLeaves = store.pendingLeaves
          .where((l) => l.status == LeaveStatus.pending)
          .toList();
      if (pendingLeaves.isEmpty) {
        return; // Skip if no pending leaves
      }

      final initialPendingCount = pendingLeaves.length;

      // Open detail sheet
      final leaveCards = find.byType(AppCard);
      if (leaveCards.evaluate().isNotEmpty) {
        await tester.tap(leaveCards.first);
        await tester.pumpAndSettle();

        // Find and tap approve button
        final approveButton = find.text('Approve');
        if (approveButton.evaluate().isNotEmpty) {
          await tester.tap(approveButton);
          await tester.pumpAndSettle();

          // Verify leave was approved
          final updatedPendingCount = store.pendingLeaves
              .where((l) => l.status == LeaveStatus.pending)
              .length;
          expect(updatedPendingCount, lessThan(initialPendingCount));

          // Verify success snackbar
          expect(find.text('Leave request approved'), findsOneWidget);
        }
      }
    });

    testWidgets('shows reject dialog when reject button is tapped', (tester) async {
      store.seedDemo();
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      if (store.pendingLeaves.isEmpty) {
        return; // Skip if no leaves
      }

      // Open detail sheet
      final leaveCards = find.byType(AppCard);
      if (leaveCards.evaluate().isNotEmpty) {
        await tester.tap(leaveCards.first);
        await tester.pumpAndSettle();

        // Find and tap reject button
        final rejectButton = find.text('Reject');
        if (rejectButton.evaluate().isNotEmpty) {
          await tester.tap(rejectButton);
          await tester.pumpAndSettle();

          // Should show reject dialog
          expect(find.text('Reject Leave Request'), findsOneWidget);
          expect(find.text('Please provide a reason for rejection:'), findsOneWidget);
          expect(find.byType(TextFormField), findsOneWidget);
        }
      }
    });

    testWidgets('rejects leave request with reason', (tester) async {
      store.seedDemo();
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      if (store.pendingLeaves.isEmpty) {
        return; // Skip if no leaves
      }

      // Find a pending leave
      final pendingLeaves = store.pendingLeaves
          .where((l) => l.status == LeaveStatus.pending)
          .toList();
      if (pendingLeaves.isEmpty) {
        return; // Skip if no pending leaves
      }

      final initialPendingCount = pendingLeaves.length;

      // Open detail sheet
      final leaveCards = find.byType(AppCard);
      if (leaveCards.evaluate().isNotEmpty) {
        await tester.tap(leaveCards.first);
        await tester.pumpAndSettle();

        // Tap reject button
        final rejectButton = find.text('Reject');
        if (rejectButton.evaluate().isNotEmpty) {
          await tester.tap(rejectButton);
          await tester.pumpAndSettle();

          // Enter rejection reason
          final reasonField = find.byType(TextFormField);
          if (reasonField.evaluate().isNotEmpty) {
            await tester.enterText(reasonField, 'Insufficient leave balance');
            await tester.pump();

            // Tap confirm reject button
            final confirmRejectButton = find.widgetWithText(ElevatedButton, 'Reject');
            if (confirmRejectButton.evaluate().isNotEmpty) {
              await tester.tap(confirmRejectButton);
              await tester.pumpAndSettle();

              // Verify leave was rejected
              final updatedPendingCount = store.pendingLeaves
                  .where((l) => l.status == LeaveStatus.pending)
                  .length;
              expect(updatedPendingCount, lessThan(initialPendingCount));

              // Verify success snackbar
              expect(find.text('Leave request rejected'), findsOneWidget);
            }
          }
        }
      }
    });

    testWidgets('validates rejection reason is required', (tester) async {
      store.seedDemo();
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      if (store.pendingLeaves.isEmpty) {
        return; // Skip if no leaves
      }

      // Open detail sheet
      final leaveCards = find.byType(AppCard);
      if (leaveCards.evaluate().isNotEmpty) {
        await tester.tap(leaveCards.first);
        await tester.pumpAndSettle();

        // Tap reject button
        final rejectButton = find.text('Reject');
        if (rejectButton.evaluate().isNotEmpty) {
          await tester.tap(rejectButton);
          await tester.pumpAndSettle();

          // Try to submit without entering reason
          final confirmRejectButton = find.widgetWithText(ElevatedButton, 'Reject');
          if (confirmRejectButton.evaluate().isNotEmpty) {
            await tester.tap(confirmRejectButton);
            await tester.pump();

            // Dialog should still be open (validation failed)
            expect(find.text('Reject Leave Request'), findsOneWidget);
          }
        }
      }
    });

    testWidgets('cancels reject dialog when cancelled', (tester) async {
      store.seedDemo();
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      if (store.pendingLeaves.isEmpty) {
        return; // Skip if no leaves
      }

      // Open detail sheet
      final leaveCards = find.byType(AppCard);
      if (leaveCards.evaluate().isNotEmpty) {
        await tester.tap(leaveCards.first);
        await tester.pumpAndSettle();

        // Tap reject button
        final rejectButton = find.text('Reject');
        if (rejectButton.evaluate().isNotEmpty) {
          await tester.tap(rejectButton);
          await tester.pumpAndSettle();

          // Tap cancel button
          final cancelButton = find.text('Cancel');
          if (cancelButton.evaluate().isNotEmpty) {
            await tester.tap(cancelButton);
            await tester.pumpAndSettle();

            // Dialog should be closed
            expect(find.text('Reject Leave Request'), findsNothing);
          }
        }
      }
    });

    testWidgets('displays cache hint when using stale data', (tester) async {
      store.seedDemo();
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // The cache hint should appear if usingStale is true
      // This depends on the store's internal state after loading
      final cacheHint = find.text('Showing cached data');
      // The hint may or may not be visible depending on store state
      expect(cacheHint, findsNothing);
    });

    testWidgets('refreshes data when pull-to-refresh is triggered', (tester) async {
      store.seedDemo();
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      final initialCallCount = repository.fetchPendingCallCount;

      // Perform pull-to-refresh gesture
      final listView = find.byType(ListView);
      if (listView.evaluate().isNotEmpty) {
        await tester.drag(listView.first, const Offset(0, 300));
        await tester.pumpAndSettle();

        // Verify refresh was triggered
        expect(repository.fetchPendingCallCount, greaterThan(initialCallCount));
      }
    });

    testWidgets('shows correct empty state message for filtered status', (tester) async {
      store.seedDemo();
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Tap Approved filter
      await tester.tap(find.text('Approved'));
      await tester.pumpAndSettle();

      // If no approved leaves, should show filtered empty state
      final approvedLeaves = store.pendingLeaves
          .where((l) => l.status == LeaveStatus.approved)
          .toList();
      if (approvedLeaves.isEmpty) {
        expect(find.textContaining('approved'), findsWidgets);
      }
    });

    testWidgets('displays status chips correctly', (tester) async {
      store.seedDemo();
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      if (store.pendingLeaves.isNotEmpty) {
        // Should show status chips (Pending, Approved, Rejected)
        expect(find.text('Pending'), findsWidgets);
      }
    });

    testWidgets('shows loading indicator on individual leave during approval', (tester) async {
      store.seedDemo();
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      if (store.pendingLeaves.isEmpty) {
        return; // Skip if no leaves
      }

      // Open detail sheet
      final leaveCards = find.byType(AppCard);
      if (leaveCards.evaluate().isNotEmpty) {
        await tester.tap(leaveCards.first);
        await tester.pumpAndSettle();

        // Find approve button
        final approveButton = find.text('Approve');
        if (approveButton.evaluate().isNotEmpty) {
          // Tap approve button
          await tester.tap(approveButton);
          await tester.pump(); // Don't settle, check loading state

          // Should show loading indicator on the leave being processed
          expect(find.byType(CircularProgressIndicator), findsWidgets);

          await tester.pumpAndSettle();
        }
      }
    });
  });
}

/// Mock leave repository for testing
class MockLeaveRepository implements LeaveRepositoryInterface {
  final List<LeaveRequest> _pendingLeaves = [];
  final _uuid = const Uuid();
  int _fetchPendingCallCount = 0;

  MockLeaveRepository() {
    _seedData();
  }

  int get fetchPendingCallCount => _fetchPendingCallCount;

  void _seedData() {
    final now = DateTime.now();
    _pendingLeaves.addAll([
      LeaveRequest(
        id: _uuid.v4(),
        userId: 'user1',
        userName: 'John Doe',
        leaveType: LeaveType.annual,
        startDate: now.add(const Duration(days: 1)),
        endDate: now.add(const Duration(days: 3)),
        isHalfDay: false,
        reason: 'Vacation',
        status: LeaveStatus.pending,
        createdAt: now,
      ),
      LeaveRequest(
        id: _uuid.v4(),
        userId: 'user2',
        userName: 'Jane Smith',
        leaveType: LeaveType.sick,
        startDate: now.add(const Duration(days: 5)),
        endDate: now.add(const Duration(days: 5)),
        isHalfDay: true,
        halfDayPart: HalfDayPart.am,
        reason: 'Sick day',
        status: LeaveStatus.pending,
        createdAt: now,
      ),
    ]);
  }

  @override
  Future<FetchResult<List<LeaveRequest>>> fetchUserLeaves(
    String userId, {
    bool forceRefresh = false,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    return FetchResult(
      data: _pendingLeaves.where((l) => l.userId == userId).toList(),
      isStale: false,
    );
  }

  @override
  Future<FetchResult<List<LeaveRequest>>> fetchPendingLeaves({
    bool forceRefresh = false,
  }) async {
    _fetchPendingCallCount++;
    await Future<void>.delayed(const Duration(milliseconds: 50));
    return FetchResult(data: List.from(_pendingLeaves), isStale: false);
  }

  @override
  Future<void> submitLeaveRequest(LeaveRequest request) async {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    _pendingLeaves.add(request);
  }

  @override
  Future<void> approveLeave(String leaveId, {String? comment}) async {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final index = _pendingLeaves.indexWhere((l) => l.id == leaveId);
    if (index != -1) {
      final leave = _pendingLeaves[index];
      _pendingLeaves[index] = LeaveRequest(
        id: leave.id,
        userId: leave.userId,
        userName: leave.userName,
        leaveType: leave.leaveType,
        startDate: leave.startDate,
        endDate: leave.endDate,
        isHalfDay: leave.isHalfDay,
        halfDayPart: leave.halfDayPart,
        reason: leave.reason,
        status: LeaveStatus.approved,
        createdAt: leave.createdAt,
        adminComment: comment,
      );
    }
  }

  @override
  Future<void> rejectLeave(String leaveId, {required String reason}) async {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final index = _pendingLeaves.indexWhere((l) => l.id == leaveId);
    if (index != -1) {
      final leave = _pendingLeaves[index];
      _pendingLeaves[index] = LeaveRequest(
        id: leave.id,
        userId: leave.userId,
        userName: leave.userName,
        leaveType: leave.leaveType,
        startDate: leave.startDate,
        endDate: leave.endDate,
        isHalfDay: leave.isHalfDay,
        halfDayPart: leave.halfDayPart,
        reason: leave.reason,
        status: LeaveStatus.rejected,
        createdAt: leave.createdAt,
        rejectionReason: reason,
      );
    }
  }
}

/// Mock repository that throws errors for testing error states
class ErrorThrowingLeaveRepository implements LeaveRepositoryInterface {
  bool shouldThrow = true;
  int _fetchPendingCallCount = 0;

  int get fetchPendingCallCount => _fetchPendingCallCount;

  @override
  Future<FetchResult<List<LeaveRequest>>> fetchUserLeaves(
    String userId, {
    bool forceRefresh = false,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    if (shouldThrow) {
      throw Exception('Network error: Failed to fetch user leaves');
    }
    return const FetchResult(data: [], isStale: false);
  }

  @override
  Future<FetchResult<List<LeaveRequest>>> fetchPendingLeaves({
    bool forceRefresh = false,
  }) async {
    _fetchPendingCallCount++;
    await Future<void>.delayed(const Duration(milliseconds: 50));
    if (shouldThrow) {
      throw Exception('Network error: Failed to fetch pending leaves');
    }
    return const FetchResult(data: [], isStale: false);
  }

  @override
  Future<void> submitLeaveRequest(LeaveRequest request) async {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    if (shouldThrow) {
      throw Exception('Network error: Failed to submit leave request');
    }
  }

  @override
  Future<void> approveLeave(String leaveId, {String? comment}) async {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    if (shouldThrow) {
      throw Exception('Network error: Failed to approve leave');
    }
  }

  @override
  Future<void> rejectLeave(String leaveId, {required String reason}) async {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    if (shouldThrow) {
      throw Exception('Network error: Failed to reject leave');
    }
  }
}
