import 'package:flutter/foundation.dart';
import 'package:sns_clocked_in/features/leave/domain/leave_request.dart';

/// In-memory store for leave requests
class LeaveStore extends ChangeNotifier {
  final List<LeaveRequest> _leaveRequests = [];

  /// Get all leave requests
  List<LeaveRequest> get leaveRequests => List.unmodifiable(_leaveRequests);

  /// Get leave requests by status
  List<LeaveRequest> getLeaveRequestsByStatus(LeaveStatus? status) {
    if (status == null) return leaveRequests;
    return _leaveRequests.where((req) => req.status == status).toList();
  }

  /// Get leave requests by user ID
  List<LeaveRequest> getLeaveRequestsByUserId(String userId) {
    return _leaveRequests.where((req) => req.userId == userId).toList();
  }

  /// Add a new leave request
  void addLeave(LeaveRequest request) {
    _leaveRequests.insert(0, request);
    notifyListeners();
  }

  /// Approve a leave request
  void approveLeave(String id) {
    final index = _leaveRequests.indexWhere((req) => req.id == id);
    if (index != -1) {
      final request = _leaveRequests[index];
      _leaveRequests[index] = LeaveRequest(
        id: request.id,
        userId: request.userId,
        userName: request.userName,
        leaveType: request.leaveType,
        startDate: request.startDate,
        endDate: request.endDate,
        isHalfDay: request.isHalfDay,
        halfDayPart: request.halfDayPart,
        reason: request.reason,
        status: LeaveStatus.approved,
        createdAt: request.createdAt,
      );
      notifyListeners();
    }
  }

  /// Reject a leave request
  void rejectLeave(String id) {
    final index = _leaveRequests.indexWhere((req) => req.id == id);
    if (index != -1) {
      final request = _leaveRequests[index];
      _leaveRequests[index] = LeaveRequest(
        id: request.id,
        userId: request.userId,
        userName: request.userName,
        leaveType: request.leaveType,
        startDate: request.startDate,
        endDate: request.endDate,
        isHalfDay: request.isHalfDay,
        halfDayPart: request.halfDayPart,
        reason: request.reason,
        status: LeaveStatus.rejected,
        createdAt: request.createdAt,
      );
      notifyListeners();
    }
  }

  /// Initialize with sample data
  void seedSampleData() {
    if (_leaveRequests.isNotEmpty) return; // Already seeded

    final now = DateTime.now();
    _leaveRequests.addAll([
      LeaveRequest(
        id: '1',
        userId: 'user1',
        userName: 'John Doe',
        leaveType: LeaveType.annual,
        startDate: now.add(const Duration(days: 5)),
        endDate: now.add(const Duration(days: 7)),
        isHalfDay: false,
        reason: 'Family vacation',
        status: LeaveStatus.pending,
        createdAt: now.subtract(const Duration(days: 2)),
      ),
      LeaveRequest(
        id: '2',
        userId: 'user2',
        userName: 'Jane Smith',
        leaveType: LeaveType.sick,
        startDate: now.subtract(const Duration(days: 3)),
        endDate: now.subtract(const Duration(days: 3)),
        isHalfDay: true,
        halfDayPart: HalfDayPart.am,
        reason: 'Medical appointment',
        status: LeaveStatus.approved,
        createdAt: now.subtract(const Duration(days: 5)),
      ),
      LeaveRequest(
        id: '3',
        userId: 'user3',
        userName: 'Bob Johnson',
        leaveType: LeaveType.annual,
        startDate: now.subtract(const Duration(days: 10)),
        endDate: now.subtract(const Duration(days: 12)),
        isHalfDay: false,
        reason: 'Personal matters',
        status: LeaveStatus.rejected,
        createdAt: now.subtract(const Duration(days: 15)),
      ),
    ]);
    notifyListeners();
  }
}

