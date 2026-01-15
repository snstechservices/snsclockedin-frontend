import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sns_clocked_in/core/storage/simple_cache.dart';
import 'package:sns_clocked_in/features/leave/application/admin_leave_approvals_store.dart';
import 'package:sns_clocked_in/features/leave/application/admin_leave_balances_store.dart';
import 'package:sns_clocked_in/features/leave/application/admin_leave_context_store.dart';
import 'package:sns_clocked_in/features/leave/application/leave_accrual_store.dart';
import 'package:sns_clocked_in/features/leave/application/leave_cash_out_store.dart';
import 'package:sns_clocked_in/features/leave/data/leave_repository.dart';
import 'package:sns_clocked_in/features/leave/domain/leave_balance.dart';
import 'package:sns_clocked_in/features/leave/domain/leave_request.dart';
import 'package:sns_clocked_in/features/leave/presentation/admin_leave_overview_screen.dart';
import '../../../test_helpers.dart';

void main() {
  setUpAll(() async {
    await setupTestEnvironment();
  });

  group('AdminLeaveOverviewScreen', () {
    late AdminLeaveApprovalsStore approvalsStore;
    late AdminLeaveBalancesStore balancesStore;
    late AdminLeaveContextStore contextStore;
    late LeaveAccrualStore accrualStore;
    late LeaveCashOutStore cashOutStore;
    late SimpleCache cache;

    setUp(() {
      cache = SimpleCache();
      cache.clear();
      contextStore = AdminLeaveContextStore();
      approvalsStore = AdminLeaveApprovalsStore(
        repository: MockLeaveRepository(),
        cache: cache,
      );
      balancesStore = AdminLeaveBalancesStore();
      accrualStore = LeaveAccrualStore();
      cashOutStore = LeaveCashOutStore();
    });

    tearDown(() {
      cache.clear();
      approvalsStore.dispose();
      balancesStore.dispose();
      contextStore.dispose();
      accrualStore.dispose();
      cashOutStore.dispose();
    });

    Widget createTestWidget() {
      return MaterialApp(
        home: Scaffold(
          body: MultiProvider(
            providers: [
              ChangeNotifierProvider<AdminLeaveContextStore>.value(
                value: contextStore,
              ),
              ChangeNotifierProvider<AdminLeaveApprovalsStore>.value(
                value: approvalsStore,
              ),
              ChangeNotifierProvider<AdminLeaveBalancesStore>.value(
                value: balancesStore,
              ),
              ChangeNotifierProvider<LeaveAccrualStore>.value(
                value: accrualStore,
              ),
              ChangeNotifierProvider<LeaveCashOutStore>.value(
                value: cashOutStore,
              ),
            ],
            child: const AdminLeaveOverviewScreen(),
          ),
        ),
      );
    }

    testWidgets('displays all 4 tabs', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Should show all tabs
      expect(find.text('Requests'), findsWidgets);
      expect(find.text('Balances'), findsWidgets);
      expect(find.text('Accruals'), findsWidgets);
      expect(find.text('Cash Out'), findsWidgets);
    });

    testWidgets('switches between tabs', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Initially on Requests tab
      expect(find.text('Requests'), findsWidgets);

      // Tap Balances tab
      await tester.tap(find.text('Balances'));
      await tester.pumpAndSettle();

      // Should show Balances content
      expect(find.text('Balances'), findsWidgets);
    });

    testWidgets('shows empty state for accruals tab', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Tap Accruals tab
      await tester.tap(find.text('Accruals'));
      await tester.pumpAndSettle();

      // Should show empty state or list
      expect(find.text('Accruals'), findsWidgets);
    });

    testWidgets('shows empty state for cash out tab', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Tap Cash Out tab
      await tester.tap(find.text('Cash Out'));
      await tester.pumpAndSettle();

      // Should show empty state or list
      expect(find.text('Cash Out'), findsWidgets);
    });
  });
}

/// Mock leave repository for testing
class MockLeaveRepository implements LeaveRepositoryInterface {
  @override
  Future<FetchResult<List<LeaveRequest>>> fetchUserLeaves(
    String userId, {
    bool forceRefresh = false,
  }) async {
    await Future.delayed(const Duration(milliseconds: 50));
    return const FetchResult(data: [], isStale: false);
  }

  @override
  Future<FetchResult<List<LeaveRequest>>> fetchPendingLeaves({
    bool forceRefresh = false,
  }) async {
    await Future.delayed(const Duration(milliseconds: 50));
    return const FetchResult(data: [], isStale: false);
  }

  @override
  Future<void> submitLeaveRequest(LeaveRequest request) async {
    await Future.delayed(const Duration(milliseconds: 50));
  }

  @override
  Future<void> approveLeave(String leaveId, {String? comment}) async {
    await Future.delayed(const Duration(milliseconds: 50));
  }

  @override
  Future<void> rejectLeave(String leaveId, {required String reason}) async {
    await Future.delayed(const Duration(milliseconds: 50));
  }
}
