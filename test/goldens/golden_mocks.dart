import 'package:sns_clocked_in/features/leave/data/leave_repository.dart';
import 'package:sns_clocked_in/features/leave/domain/leave_request.dart';
import 'package:sns_clocked_in/features/timesheet/data/admin_approvals_repository.dart' as timesheet;
import 'package:sns_clocked_in/features/timesheet/domain/attendance_record.dart';

class GoldenLeaveRepository implements LeaveRepositoryInterface {
  @override
  Future<FetchResult<List<LeaveRequest>>> fetchUserLeaves(
    String userId, {
    bool forceRefresh = false,
  }) async {
    return const FetchResult(data: [], isStale: false);
  }

  @override
  Future<FetchResult<List<LeaveRequest>>> fetchPendingLeaves({
    bool forceRefresh = false,
  }) async {
    final now = DateTime(2025, 1, 20);
    return FetchResult(
      data: [
        LeaveRequest(
          id: 'leave-1',
          userId: 'u1',
          userName: 'Alice Johnson',
          department: 'Engineering',
          leaveType: LeaveType.annual,
          startDate: now,
          endDate: now.add(const Duration(days: 2)),
          isHalfDay: false,
          reason: 'Family trip',
          status: LeaveStatus.pending,
          createdAt: now.subtract(const Duration(days: 3)),
        ),
        LeaveRequest(
          id: 'leave-2',
          userId: 'u2',
          userName: 'Brian Lee',
          department: 'Product',
          leaveType: LeaveType.sick,
          startDate: now,
          endDate: now,
          isHalfDay: true,
          halfDayPart: HalfDayPart.am,
          reason: 'Flu',
          status: LeaveStatus.approved,
          createdAt: now.subtract(const Duration(days: 2)),
        ),
        LeaveRequest(
          id: 'leave-3',
          userId: 'u3',
          userName: 'Cathy Doe',
          department: 'HR',
          leaveType: LeaveType.unpaid,
          startDate: now.add(const Duration(days: 5)),
          endDate: now.add(const Duration(days: 5)),
          isHalfDay: false,
          reason: 'Personal errand',
          status: LeaveStatus.rejected,
          rejectionReason: 'Peak period',
          createdAt: now.subtract(const Duration(days: 1)),
        ),
      ],
      isStale: false,
    );
  }

  @override
  Future<void> submitLeaveRequest(LeaveRequest request) async {}

  @override
  Future<void> approveLeave(String leaveId, {String? comment}) async {}

  @override
  Future<void> rejectLeave(String leaveId, {required String reason}) async {}
}

class GoldenAdminApprovalsRepository implements timesheet.AdminApprovalsRepositoryInterface {
  GoldenAdminApprovalsRepository() {
    _seed();
  }

  final List<AttendanceRecord> _pending = [];
  final List<AttendanceRecord> _approved = [];

  void _seed() {
    final now = DateTime(2025, 1, 20);
    _pending.add(
      AttendanceRecord(
        id: 'rec-1',
        userId: 'u1',
        companyId: 'c1',
        date: now,
        checkInTime: now.subtract(const Duration(hours: 9)),
        checkOutTime: now.subtract(const Duration(hours: 1)),
        status: 'completed',
        approvalStatus: ApprovalStatus.pending,
        totalBreakTimeMinutes: 60,
        breaks: [
          AttendanceBreak(
            breakType: 'lunch',
            startTime: now.subtract(const Duration(hours: 5)),
            endTime: now.subtract(const Duration(hours: 4)),
            durationMinutes: 60,
          ),
        ],
        createdAt: now.subtract(const Duration(days: 1)),
      ),
    );

    _approved.add(
      AttendanceRecord(
        id: 'rec-2',
        userId: 'u2',
        companyId: 'c1',
        date: now.subtract(const Duration(days: 3)),
        checkInTime: now.subtract(const Duration(days: 3, hours: 9)),
        checkOutTime: now.subtract(const Duration(days: 3, hours: 1)),
        status: 'approved',
        approvalStatus: ApprovalStatus.approved,
        approvedBy: 'admin1',
        approvalDate: now.subtract(const Duration(days: 2)),
        totalBreakTimeMinutes: 45,
        breaks: const [],
        createdAt: now.subtract(const Duration(days: 3)),
      ),
    );
  }

  @override
  Future<timesheet.FetchResult<List<AttendanceRecord>>> fetchPending({
    bool forceRefresh = false,
  }) async {
    return timesheet.FetchResult(data: List.from(_pending), isStale: false);
  }

  @override
  Future<timesheet.FetchResult<List<AttendanceRecord>>> fetchApproved({
    bool forceRefresh = false,
  }) async {
    return timesheet.FetchResult(data: List.from(_approved), isStale: false);
  }

  @override
  Future<void> approve(String attendanceId, {String? comment}) async {}

  @override
  Future<void> reject(String attendanceId, {required String reason}) async {}

  @override
  Future<void> bulkAutoApprove() async {}
}

