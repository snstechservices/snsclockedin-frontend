import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/shift_cover_service.dart';
import '../../models/shift_cover.dart';
import '../../services/global_notification_service.dart';
import '../../utils/logger.dart';
import '../../widgets/admin_side_navigation.dart';

class ShiftCoverManagementScreen extends StatefulWidget {
  const ShiftCoverManagementScreen({super.key});

  @override
  State<ShiftCoverManagementScreen> createState() =>
      _ShiftCoverManagementScreenState();
}

class _ShiftCoverManagementScreenState extends State<ShiftCoverManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ShiftCoverService _shiftCoverService = ShiftCoverService();
  final GlobalNotificationService _notificationService =
      GlobalNotificationService();

  List<ShiftCover> _allRequests = [];
  List<ShiftCover> _pendingRequests = [];
  List<ShiftCover> _approvedRequests = [];
  List<ShiftCover> _completedRequests = [];
  List<ShiftCover> _rejectedRequests = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadShiftCoverRequests();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadShiftCoverRequests() async {
    try {
      setState(() {
        _isLoading = true;
      });

      Logger.info('ShiftCoverManagement: Loading shift cover requests...');
      // Load all shift cover requests for admin management
      final response = await _shiftCoverService.getAllShiftCoverRequests();
      Logger.debug('ShiftCoverManagement: API response received: $response');

      if (response['success'] == true && response['data'] != null) {
        final List<dynamic> requestsData = response['data']['requests'] ?? [];
        final requests = requestsData
            .map((data) => ShiftCover.fromJson(data))
            .toList();

        setState(() {
          _allRequests = requests;
          // Pending: only 'open' requests (waiting for someone to accept)
          _pendingRequests = requests
              .where((r) => r.status.value == 'open')
              .toList();
          // Approved: 'accepted' requests (someone has committed to cover the shift)
          _approvedRequests = requests
              .where((r) => r.status.value == 'accepted')
              .toList();
          // Completed: 'completed' shift covers
          _completedRequests = requests
              .where((r) => r.status.value == 'completed')
              .toList();
          // Rejected: cancelled or expired requests
          _rejectedRequests = requests
              .where(
                (r) =>
                    r.status.value == 'cancelled' ||
                    r.status.value == 'expired',
              )
              .toList();
          _isLoading = false;
        });

        Logger.info(
          'ShiftCoverManagement: Successfully loaded ${requests.length} requests',
        );
      } else {
        setState(() {
          _isLoading = false;
        });
        Logger.error(
          'ShiftCoverManagement: API response error - ${response['message'] ?? 'Unknown error'}',
        );
        _notificationService.showError(
          'Failed to load shift cover requests: ${response['message'] ?? 'Unknown error'}',
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _notificationService.showError('Error loading shift cover requests: $e');
    }
  }

  Future<void> _updateRequestStatus(String requestId, String status) async {
    try {
      final response = await _shiftCoverService.updateShiftCoverRequest(
        requestId,
        {'status': status},
      );

      if (response['success'] == true) {
        _notificationService.showSuccess('Request $status successfully');
        _loadShiftCoverRequests(); // Refresh the list
      } else {
        _notificationService.showError('Failed to update request');
      }
    } catch (e) {
      _notificationService.showError('Error updating request: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Provider.of<AuthProvider>(context, listen: false);

    return Scaffold(
      drawer: const AdminSideNavigation(currentRoute: '/admin/shift-cover'),
      appBar: AppBar(
        title: const Text('Shift Cover Management'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.list), text: 'All'),
            Tab(icon: Icon(Icons.pending), text: 'Pending'),
            Tab(icon: Icon(Icons.check_circle), text: 'Approved'),
            Tab(icon: Icon(Icons.done_all), text: 'Completed'),
            Tab(icon: Icon(Icons.cancel), text: 'Rejected'),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _loadShiftCoverRequests,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildRequestsList(_allRequests, 'All Requests'),
          _buildRequestsList(_pendingRequests, 'Pending Requests'),
          _buildRequestsList(_approvedRequests, 'Approved Requests'),
          _buildRequestsList(_completedRequests, 'Completed Requests'),
          _buildRequestsList(_rejectedRequests, 'Rejected Requests'),
        ],
      ),
    );
  }

  Widget _buildRequestsList(List<ShiftCover> requests, String title) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (requests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No $title',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'There are no shift cover requests to display.',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadShiftCoverRequests,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: requests.length,
        itemBuilder: (context, index) {
          final request = requests[index];
          return _buildRequestCard(request);
        },
      ),
    );
  }

  Widget _buildRequestCard(ShiftCover request) {
    final theme = Theme.of(context);

    Color statusColor;
    IconData statusIcon;
    switch (request.status) {
      // ignore: constant_pattern_never_matches_value_type
      case 'pending':
        statusColor = Colors.orange;
        statusIcon = Icons.pending;
        break;
      // ignore: constant_pattern_never_matches_value_type
      case 'approved':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      // ignore: constant_pattern_never_matches_value_type
      case 'rejected':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    request.requesterName,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 16, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        request.status.toUpperCase(),
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Text(
                  'Date: ${request.shiftDate}',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Text(
                  'Time: ${request.shiftStartTime} - ${request.shiftEndTime}',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
            if (request.reason.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Reason: ${request.reason}',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ],
            if (request.specialInstructions != null &&
                request.specialInstructions!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.note, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Instructions: ${request.specialInstructions}',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ],
            // ignore: unrelated_type_equality_checks
            if (request.status == 'pending') ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () =>
                          _updateRequestStatus(request.id, 'approved'),
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Approve'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () =>
                          _updateRequestStatus(request.id, 'rejected'),
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text('Reject'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
