import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/feature_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/admin_side_navigation.dart';
import '../../widgets/feature_lock_widget.dart';
import '../../widgets/timezone_selector.dart';
import '../../config/api_config.dart';
import '../../utils/time_utils.dart';
import '../../utils/theme_utils.dart';
import '../../utils/web_download_helper.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'package:intl/intl.dart';
import '../../services/global_notification_service.dart';
import '../../utils/logger.dart';

class AdvancedReportingScreen extends StatefulWidget {
  const AdvancedReportingScreen({super.key});

  @override
  State<AdvancedReportingScreen> createState() =>
      _AdvancedReportingScreenState();
}

class _AdvancedReportingScreenState extends State<AdvancedReportingScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedReportType = '';
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  String _selectedFormat = 'pdf';
  String _selectedLayout = 'detailed'; // 'detailed' or 'pivot'
  bool _isGenerating = false;

  List<String> _availableReportTypes = [];
  final List<String> _exportFormats = ['pdf', 'excel', 'csv'];

  // Report history data
  List<Map<String, dynamic>> _reportHistory = [];
  bool _isLoadingHistory = false;
  bool _isLoadingFeatures = false;
  bool _hasMoreHistory = true;
  int _currentHistoryPage = 1;
  static const int _historyPageSize = 10;

  // Bulk selection and filtering
  Set<String> _selectedReports = {};
  bool _isSelectionMode = false;
  String _timeDurationFilter = 'all'; // 'all', 'month', 'year'
  DateTime _filterStartDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _filterEndDate = DateTime.now();
  int _totalReports = 0;

  // Employee selection
  String? _selectedEmployeeId;
  List<Map<String, dynamic>> _employees = [];
  bool _isLoadingEmployees = false;

  // Scheduled reports
  List<Map<String, dynamic>> _scheduledReports = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index == 1) {
        // Load scheduled reports when switching to scheduled reports tab
        _loadScheduledReports();
      } else if (_tabController.index == 2) {
        // Load report history when switching to history tab
        _loadReportHistory();
      }
    });

    // Load available report types based on company features
    _loadAvailableReportTypes();

    // Load employees for filtering
    _loadEmployees();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FeatureProvider>(
      builder: (context, featureProvider, _) {
        // Check if advanced reporting is enabled
        if (!featureProvider.isFeatureEnabled('advancedReporting')) {
          return Scaffold(
            appBar: AppBar(
              automaticallyImplyLeading: true,
              title: const Text('Advanced Reporting'),
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              elevation: 0,
            ),
            drawer: const AdminSideNavigation(
              currentRoute: '/advanced-reporting',
            ),
            body: const FeatureLockWidget(
              featureName:
                  'advancedReporting', // Fix: Use correct parameter name
              title: 'Advanced Reporting',
              description:
                  'Create custom reports with advanced analytics, scheduled reports, and multiple export formats.',
              icon: Icons.assessment, // Fix: Add required icon parameter
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: true,
            title: const Text('Advanced Reporting'),
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
            elevation: 0,
            bottom: TabBar(
              controller: _tabController,
              labelColor: Theme.of(context).colorScheme.onPrimary,
              unselectedLabelColor: Theme.of(
                context,
              ).colorScheme.onPrimary.withValues(alpha: 0.7),
              indicatorColor: Theme.of(context).colorScheme.onPrimary,
              tabs: const [
                Tab(text: 'Report Builder'),
                Tab(text: 'Scheduled Reports'),
                Tab(text: 'Report History'),
              ],
            ),
          ),
          drawer: const AdminSideNavigation(
            currentRoute: '/advanced-reporting',
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildReportBuilder(),
              _buildScheduledReports(),
              _buildReportHistory(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildReportBuilder() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Create Custom Report',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Report Type Selection
                  DropdownButtonFormField<String>(
                    initialValue: _selectedReportType.isEmpty
                        ? null
                        : _selectedReportType,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Report Type',
                      border: const OutlineInputBorder(),
                      filled: true,
                      fillColor: colorScheme.surface,
                      suffixIcon: _isLoadingFeatures
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : null,
                    ),
                    items: _availableReportTypes.map((type) {
                      return DropdownMenuItem(
                        value: type,
                        child: Text(
                          _getReportTypeDisplayName(type),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      );
                    }).toList(),
                    onChanged: _isLoadingFeatures
                        ? null
                        : (value) {
                            setState(() {
                              _selectedReportType = value!;
                            });
                          },
                  ),
                  const SizedBox(height: 16),

                  // Employee Selection (Optional)
                  DropdownButtonFormField<String>(
                    initialValue: _selectedEmployeeId,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Employee (Optional)',
                      hintText:
                          'Select specific employee or leave blank for all',
                      border: const OutlineInputBorder(),
                      filled: true,
                      fillColor: colorScheme.surface,
                      suffixIcon: _isLoadingEmployees
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : null,
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text(
                          'All Employees',
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                      ..._employees.map((employee) {
                        final displayName =
                            '${employee['name']} (${employee['employeeId'] ?? 'N/A'})';
                        return DropdownMenuItem(
                          value:
                              employee['userId']?.toString() ??
                              employee['_id']?.toString(),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                              maxWidth: 300, // Set a maximum width
                            ),
                            child: Text(
                              displayName,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        );
                      }),
                    ],
                    onChanged: _isLoadingEmployees
                        ? null
                        : (value) {
                            setState(() {
                              _selectedEmployeeId = value;
                            });
                          },
                  ),
                  const SizedBox(height: 16),

                  // Date Range Selection
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => _selectDate(true),
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: 'Start Date',
                              border: const OutlineInputBorder(),
                              filled: true,
                              fillColor: colorScheme.surface,
                            ),
                            child: Builder(
                              builder: (context) {
                                // Format date directly without timezone conversion
                                final formattedDate =
                                    '${_startDate.year}-${_startDate.month.toString().padLeft(2, '0')}-${_startDate.day.toString().padLeft(2, '0')}';
                                return Text(formattedDate);
                              },
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: InkWell(
                          onTap: () => _selectDate(false),
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: 'End Date',
                              border: const OutlineInputBorder(),
                              filled: true,
                              fillColor: colorScheme.surface,
                            ),
                            child: Builder(
                              builder: (context) {
                                // Format date directly without timezone conversion
                                final formattedDate =
                                    '${_endDate.year}-${_endDate.month.toString().padLeft(2, '0')}-${_endDate.day.toString().padLeft(2, '0')}';
                                return Text(formattedDate);
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Export Format Selection
                  DropdownButtonFormField<String>(
                    initialValue: _selectedFormat,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Export Format',
                      border: const OutlineInputBorder(),
                      filled: true,
                      fillColor: colorScheme.surface,
                    ),
                    items: _exportFormats.map((format) {
                      return DropdownMenuItem(
                        value: format,
                        child: Text(
                          format.toUpperCase(),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedFormat = value!;
                        // If PDF is selected and pivot is currently selected, switch to detailed
                        if (value == 'pdf' && _selectedLayout == 'pivot') {
                          _selectedLayout = 'detailed';
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 16),

                  // Report Layout Selection
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Report Layout',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: RadioListTile<String>(
                              title: const Text('Detailed Format'),
                              subtitle: const Text(
                                'Traditional format with each day as a separate row',
                              ),
                              value: 'detailed',
                              groupValue: _selectedLayout,
                              onChanged: (value) {
                                setState(() {
                                  _selectedLayout = value!;
                                });
                              },
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: RadioListTile<String>(
                              title: const Text('Pivot Format'),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _getPivotFormatDescription(
                                      _selectedReportType,
                                    ),
                                  ),
                                  if (_selectedFormat == 'pdf' &&
                                      _selectedReportType != 'leave')
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4.0),
                                      child: Text(
                                        '⚠️ Not suitable for PDF exports. Detailed format will be used automatically.',
                                        style: TextStyle(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.error,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              value: 'pivot',
                              groupValue: _selectedLayout,
                              onChanged:
                                  (!_supportsPivotFormat(_selectedReportType) ||
                                      _selectedFormat == 'pdf')
                                  ? null
                                  : (value) {
                                      setState(() {
                                        _selectedLayout = value!;
                                      });
                                    },
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Generate Report Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed:
                          (_isGenerating ||
                              _selectedReportType.isEmpty ||
                              _isLoadingFeatures)
                          ? null
                          : _generateReport,
                      icon: _isGenerating
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.file_download),
                      label: Text(
                        _isGenerating ? 'Generating...' : 'Generate Report',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduledReports() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Text(
            'Scheduled Reports',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 24),

          // Scheduled Reports List
          if (_scheduledReports.isEmpty)
            _buildEmptyScheduledReports()
          else
            _buildScheduledReportsList(),
        ],
      ),
    );
  }

  Widget _buildReportHistory() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_isLoadingHistory && _reportHistory.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_reportHistory.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history,
              size: 64,
              color: colorScheme.onSurface.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No Reports Generated',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Generate your first report using the Report Builder tab.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadReportHistory(loadMore: false),
      child: Column(
        children: [
          // Filter and controls header
          _buildReportHistoryHeader(),
          // Reports list
          // Reports list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _reportHistory.length + (_hasMoreHistory ? 1 : 0),
              itemBuilder: (context, index) {
                // Safety check for empty list
                if (_reportHistory.isEmpty) {
                  return const SizedBox.shrink();
                }

                // Show Load More button at the end
                if (index == _reportHistory.length) {
                  return _buildLoadMoreButton();
                }

                // Additional safety check for index bounds
                if (index >= _reportHistory.length) {
                  return const SizedBox.shrink();
                }

                final report = _reportHistory[index];
                final isSelected = _selectedReports.contains(report['_id']);

                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 12),
                  color: isSelected
                      ? colorScheme.primary.withValues(alpha: 0.1)
                      : null,
                  child: ListTile(
                    leading: _isSelectionMode
                        ? Checkbox(
                            value: isSelected,
                            onChanged: (value) =>
                                _toggleReportSelection(report['_id']),
                          )
                        : CircleAvatar(
                            backgroundColor: colorScheme.primary,
                            child: Icon(
                              _getReportIcon(report['status']),
                              color: colorScheme.onPrimary,
                            ),
                          ),
                    title: Text(
                      report['name'] ?? 'Untitled Report',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Show user who generated the report
                        if (report['generatedBy'] != null &&
                            report['generatedBy']['name'] != null)
                          Text(
                            'Generated by: ${report['generatedBy']['name']}',
                            style: TextStyle(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        if (report['employeeName'] != null &&
                            report['employeeName'].toString().isNotEmpty)
                          Text(
                            'Employee: ${report['employeeName']}',
                            style: TextStyle(
                              color: colorScheme.secondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        Text(
                          'Generated: ${TimeUtils.formatReadableDateTime(TimeUtils.parseToLocal(report['createdAt']), user: Provider.of<AuthProvider>(context, listen: false).user, company: Provider.of<AuthProvider>(context, listen: false).company)}',
                          style: TextStyle(
                            color: colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                        ),
                        if (report['status'] != null)
                          Text(
                            'Status: ${report['status'].toString().toUpperCase()}',
                            style: TextStyle(
                              color: _getStatusColor(
                                report['status'],
                                colorScheme,
                              ),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        if (report['parameters'] != null &&
                            report['parameters']['format'] != null)
                          Text(
                            'Format: ${report['parameters']['format'].toString().toUpperCase()}',
                            style: TextStyle(
                              color: colorScheme.onSurface.withValues(
                                alpha: 0.6,
                              ),
                              fontSize: 12,
                            ),
                          ),
                        if (report['parameters'] != null &&
                            report['parameters']['layout'] != null)
                          Text(
                            'Layout: ${report['parameters']['layout'].toString().toUpperCase()}',
                            style: TextStyle(
                              color: colorScheme.secondary,
                              fontWeight: FontWeight.w500,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                    trailing: _isSelectionMode
                        ? null
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Show view button only for completed reports
                              if (report['status'] == 'completed')
                                IconButton(
                                  icon: const Icon(Icons.visibility),
                                  onPressed: () => _openReport(report),
                                  tooltip: 'Open Report',
                                ),
                              // Show download button only for completed reports
                              if (report['status'] == 'completed')
                                IconButton(
                                  icon: const Icon(Icons.download),
                                  onPressed: () => _downloadReport(report),
                                  tooltip: 'Download Report',
                                ),
                              // Show delete button for all reports (completed and failed)
                              Builder(
                                builder: (context) {
                                  final errorColor =
                                      ThemeUtils.getStatusChipColor(
                                        'error',
                                        Theme.of(context),
                                      );
                                  return IconButton(
                                    icon: Icon(Icons.delete, color: errorColor),
                                    onPressed: () => _deleteReport(report),
                                    tooltip: 'Delete Report',
                                  );
                                },
                              ),
                            ],
                          ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _selectDate(bool isStartDate) async {
    final currentDate = isStartDate ? _startDate : _endDate;

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: currentDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });

      // Force a rebuild to ensure UI updates
      if (mounted) {
        setState(() {});
      }
    }
  }

  String _generateReportName() {
    // Get user and company context for proper timezone formatting
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;
    final company = authProvider.company;

    // Generate timestamp in company's timezone, not UTC
    final dateStr = TimeUtils.formatDateWithFormat(
      DateTime.now(),
      'yyyyMMdd',
      user: user,
      company: company,
    );
    final timeStr = TimeUtils.formatDateWithFormat(
      DateTime.now(),
      'HHmmss',
      user: user,
      company: company,
    );
    final reportType = _selectedReportType.toUpperCase();

    if (_selectedEmployeeId != null && _selectedEmployeeId!.isNotEmpty) {
      // Debug logging
      // 'DEBUG: Generating report name for employeeId: $_selectedEmployeeId');
      // 'DEBUG: Available employees: ${_employees.map((e) => '${e['name']} (userId: ${e['userId']}, _id: ${e['_id']})').join(', ')}');

      // Find the selected employee name
      final selectedEmployee = _employees.isNotEmpty
          ? _employees.firstWhere(
              (emp) =>
                  (emp['userId']?.toString() == _selectedEmployeeId) ||
                  (emp['_id']?.toString() == _selectedEmployeeId),
              orElse: () => {'name': 'Unknown Employee'},
            )
          : {'name': 'Unknown Employee'};

      // 'DEBUG: Selected employee: ${selectedEmployee['name']}');
      final employeeName =
          selectedEmployee['name']?.toString().replaceAll(' ', '_') ??
          'Unknown_Employee';
      return '${reportType}_${employeeName}_${dateStr}_$timeStr';
    } else {
      return '${reportType}_All_Employees_${dateStr}_$timeStr';
    }
  }

  Future<void> _generateReport() async {
    setState(() {
      _isGenerating = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      final startDateStr =
          '${_startDate.year}-${_startDate.month.toString().padLeft(2, '0')}-${_startDate.day.toString().padLeft(2, '0')}';
      final endDateStr =
          '${_endDate.year}-${_endDate.month.toString().padLeft(2, '0')}-${_endDate.day.toString().padLeft(2, '0')}';

      // Use new unified report engine endpoint
      // Determine base URL based on user role (company admin uses /api/company/reports, super admin uses /api/super-admin/reports)
      final user = authProvider.user;
      final userRole =
          user?['role'] ?? 'admin'; // Default to 'admin' for company admins
      final String baseEndpoint = userRole == 'super_admin'
          ? '${ApiConfig.baseUrl}/super-admin/reports'
          : '${ApiConfig.baseUrl}/company/reports';

      // Always use the new unified endpoint
      final String apiEndpoint = '$baseEndpoint/generate';

      // Map 'attendance' to 'timesheet' since they're unified
      final reportType = _selectedReportType == 'attendance'
          ? 'timesheet'
          : _selectedReportType;

      // Force detailed layout for unsupported report types (pivot only for attendance/timesheet)
      final layout =
          (!_supportsPivotFormat(_selectedReportType) &&
              _selectedLayout == 'pivot')
          ? 'detailed'
          : _selectedLayout;

      // Use new request format with 'params' instead of 'parameters'
      final requestBody = {
        'reportType': reportType,
        'reportName': _generateReportName(),
        'params': {
          'startDate': startDateStr,
          'endDate': endDateStr,
          'format': _selectedFormat,
          'layout': layout,
          if (_selectedEmployeeId != null)
            'filters': {'employeeId': _selectedEmployeeId},
        },
      };

      // Use the appropriate report builder system
      final response = await http.post(
        Uri.parse(apiEndpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${authProvider.token}',
        },
        body: json.encode(requestBody),
      );

      if (response.statusCode == 200 ||
          response.statusCode == 201 ||
          response.statusCode == 202) {
        // Parse response to check if it's the new format (with jobId) or old format
        final responseData = json.decode(response.body);

        if (mounted) {
          final layoutText = _selectedLayout == 'pivot' ? 'Pivot' : 'Detailed';

          // New unified engine returns jobId for async processing
          if (responseData['jobId'] != null) {
            final jobId = responseData['jobId'] as String;
            GlobalNotificationService().showInfo(
              '$layoutText report generation started. Waiting for completion...',
            );

            // Poll for job completion
            _pollJobStatus(jobId);
          } else {
            // Old format - report generated immediately
            GlobalNotificationService().showSuccess(
              '$layoutText report generated successfully in $_selectedFormat format',
            );
            // Refresh report history
            _loadReportHistory();
          }
        }
      } else {
        if (mounted) {
          try {
            final errorData = json.decode(response.body);
            final errorCode = errorData['code'];
            final errorMessage =
                errorData['message'] ??
                errorData['error'] ??
                'Failed to generate report';

            // Check if this is a deprecated endpoint error
            if (response.statusCode == 403 &&
                errorCode == 'DEPRECATED_ENDPOINT') {
              GlobalNotificationService().showWarning(
                '⚠️ This app version is outdated. Please update to the latest version to generate reports.',
              );
            } else {
              GlobalNotificationService().showError('Error: $errorMessage');
            }
          } catch (e) {
            GlobalNotificationService().showError(
              'Failed to generate report: ${response.statusCode}',
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        GlobalNotificationService().showError('Error generating report: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
      }
    }
  }

  /// Poll job status until completion or failure
  Future<void> _pollJobStatus(String jobId) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;
    final userRole = user?['role'] ?? 'admin';
    final String baseEndpoint = userRole == 'super_admin'
        ? '${ApiConfig.baseUrl}/super-admin/reports'
        : '${ApiConfig.baseUrl}/company/reports';

    int attempts = 0;
    const maxAttempts = 60; // 2 minutes max (60 * 2 seconds)
    const intervalSeconds = 2;

    while (attempts < maxAttempts) {
      await Future.delayed(Duration(seconds: intervalSeconds));

      try {
        final response = await http.get(
          Uri.parse('$baseEndpoint/jobs/$jobId'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${authProvider.token}',
          },
        );

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final status = data['status'] as String?;

          if (status == 'completed') {
            if (mounted) {
              GlobalNotificationService().showSuccess(
                'Report generated successfully!',
              );
              // Refresh report history to show the new report
              _loadReportHistory();
            }
            return;
          } else if (status == 'failed') {
            if (mounted) {
              final errorMessage =
                  data['error']?['message'] ?? 'Report generation failed';
              _showStatusSnackBar(
                'Report generation failed: $errorMessage',
                'error',
              );
            }
            return;
          }
          // Continue polling if status is 'pending' or 'processing'
        }
      } catch (e) {
        if (kDebugMode) {
          Logger.debug('Error polling job status: $e');
        }
        // Continue polling on error
      }

      attempts++;
    }

    // Timeout
    if (mounted) {
      GlobalNotificationService().showWarning(
        'Report generation is taking longer than expected. Please check report history later.',
      );
      // Refresh report history anyway - the report might be there
      _loadReportHistory();
    }
  }

  Future<void> _loadReportHistory({bool loadMore = false}) async {
    if (loadMore) {
      _currentHistoryPage++;
    } else {
      _currentHistoryPage = 1;
      _reportHistory.clear();
      _hasMoreHistory = true;
    }

    setState(() {
      _isLoadingHistory = true;
    });

    // Add a small delay to prevent rapid successive calls
    await Future.delayed(const Duration(milliseconds: 100));

    try {
      if (!mounted) return;

      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      // Build query parameters for filtering
      final queryParams = <String, String>{
        'page': _currentHistoryPage.toString(),
        'limit': _historyPageSize.toString(),
      };

      // Add time duration filter
      if (_timeDurationFilter != 'all') {
        queryParams['startDate'] =
            '${_filterStartDate.year}-${_filterStartDate.month.toString().padLeft(2, '0')}-${_filterStartDate.day.toString().padLeft(2, '0')}';
        queryParams['endDate'] =
            '${_filterEndDate.year}-${_filterEndDate.month.toString().padLeft(2, '0')}-${_filterEndDate.day.toString().padLeft(2, '0')}';
      }

      // Use new unified report engine endpoint for fetching jobs
      final user = authProvider.user;
      final userRole = user?['role'] ?? 'admin';
      final String baseEndpoint = userRole == 'super_admin'
          ? '${ApiConfig.baseUrl}/super-admin/reports'
          : '${ApiConfig.baseUrl}/company/reports';

      final uri = Uri.parse(
        '$baseEndpoint/jobs',
      ).replace(queryParameters: queryParams);

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${authProvider.token}',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['jobs'] != null) {
          final jobs = List<Map<String, dynamic>>.from(data['jobs'] ?? []);

          // Filter to only show completed jobs in history (or include processing/pending if needed)
          final completedJobs = jobs
              .where(
                (job) =>
                    job['status'] == 'completed' || job['status'] == 'failed',
              )
              .toList();

          final hasMore = jobs.length >= _historyPageSize;
          final totalReports = completedJobs.length;

          final newReports = completedJobs.map((job) {
            // Convert UTC time to local time for display
            DateTime createdAt;
            try {
              createdAt = DateTime.parse(
                job['createdAt'] ?? DateTime.now().toIso8601String(),
              ).toLocal();
            } catch (e) {
              createdAt = DateTime.now().toLocal();
            }

            // Get report name from job params or use default
            final reportName =
                job['reportName'] ??
                job['params']?['reportName'] ??
                '${job['reportType'] ?? 'Report'} - ${DateFormat('yyyy-MM-dd').format(createdAt)}';

            return {
              'name': reportName,
              'status': job['status'] ?? 'unknown',
              'createdAt': createdAt.toIso8601String(),
              'reportId':
                  job['jobId'] ?? job['_id'], // Use jobId for new system
              '_id': job['jobId'] ?? job['_id'],
              'jobId': job['jobId'], // Store jobId for downloads
              'reportType': job['reportType'],
              'fileFormat':
                  job['params']?['format'] ?? job['outputFormat'] ?? 'excel',
              'layout':
                  job['params']?['layout'] ?? job['outputLayout'] ?? 'detailed',
              'parameters': job['params'] ?? {},
              'generatedBy':
                  job['generatedBy'] ?? {'name': 'Unknown User', 'email': null},
            };
          }).toList();

          if (mounted) {
            setState(() {
              if (loadMore) {
                _reportHistory.addAll(newReports);
              } else {
                _reportHistory = newReports;
              }
              _hasMoreHistory = hasMore;
              _totalReports = totalReports;
              _isLoadingHistory = false;
            });
          }
        }
      } else {
        // No reports available
        if (mounted) {
          setState(() {
            _reportHistory = [];
            _hasMoreHistory = false;
            _isLoadingHistory = false;
          });
        }
      }
    } catch (e) {
      Logger.error('Error loading report history: $e');
      if (mounted) {
        setState(() {
          _reportHistory = [];
          _hasMoreHistory = false;
          _isLoadingHistory = false;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingHistory = false;
        });
      }
    }
  }

  Widget _buildLoadMoreButton() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.only(top: 16, bottom: 16),
      child: Center(
        child: _isLoadingHistory
            ? const CircularProgressIndicator()
            : ElevatedButton.icon(
                onPressed: _hasMoreHistory
                    ? () => _loadReportHistory(loadMore: true)
                    : null,
                icon: const Icon(Icons.download),
                label: Text(
                  _hasMoreHistory ? 'Load More Reports' : 'No More Reports',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
      ),
    );
  }

  IconData _getReportIcon(String? status) {
    switch (status) {
      case 'completed':
        return Icons.check_circle;
      case 'generating':
        return Icons.hourglass_empty;
      case 'failed':
        return Icons.error;
      default:
        return Icons.description;
    }
  }

  Color _getStatusColor(String? status, ColorScheme colorScheme) {
    final theme = Theme.of(context);
    switch (status) {
      case 'completed':
        return ThemeUtils.getStatusChipColor('success', theme);
      case 'generating':
        return ThemeUtils.getStatusChipColor('warning', theme);
      case 'failed':
        return ThemeUtils.getStatusChipColor('error', theme);
      default:
        return colorScheme.onSurface.withValues(alpha: 0.7);
    }
  }

  /// Helper to show SnackBar with safe status colors
  void _showStatusSnackBar(String message, String status) {
    // Map status to GlobalNotificationService type
    switch (status) {
      case 'success':
        GlobalNotificationService().showSuccess(message);
        break;
      case 'error':
        GlobalNotificationService().showError(message);
        break;
      case 'warning':
        GlobalNotificationService().showWarning(message);
        break;
      default:
        GlobalNotificationService().showInfo(message);
    }
  }

  /// Helper to show info SnackBar
  void _showInfoSnackBar(String message) {
    GlobalNotificationService().showInfo(message);
  }

  Future<void> _downloadReport(Map<String, dynamic> report) async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      // Generate a proper filename
      final reportName = report['reportName'] ?? report['name'] ?? 'report';
      final cleanReportName = reportName
          .replaceAll(RegExp(r'[^\w\s-]'), '')
          .replaceAll(' ', '_');

      // Use new unified report engine endpoint for downloads
      final user = authProvider.user;
      final userRole = user?['role'] ?? 'admin';
      final String baseEndpoint = userRole == 'super_admin'
          ? '${ApiConfig.baseUrl}/super-admin/reports'
          : '${ApiConfig.baseUrl}/company/reports';

      // Use jobId if available (new system), otherwise fall back to reportId (old system)
      final reportId = report['jobId'] ?? report['reportId'] ?? report['_id'];

      if (kDebugMode) {
        Logger.debug(
          '[Flutter] Download request: jobId=$reportId, reportData=${report.toString()}',
        );
      }

      // Don't pass format parameter - backend will use stored format and serve existing file without regenerating
      final response = await http.get(
        Uri.parse('$baseEndpoint/jobs/$reportId/download'),
        headers: {'Authorization': 'Bearer ${authProvider.token}'},
      );

      if (response.statusCode == 200) {
        // CRITICAL: Determine file extension from Content-Type header (most reliable)
        final contentType =
            response.headers['content-type'] ??
            response.headers['Content-Type'] ??
            '';
        if (kDebugMode) {
          Logger.debug('[Flutter] Response headers: Content-Type=$contentType');
        }

        String fileExtension;
        String mimeType;

        // Determine extension and MIME type from Content-Type header
        if (contentType.contains('pdf') || contentType == 'application/pdf') {
          fileExtension = 'pdf';
          mimeType = 'application/pdf';
          if (kDebugMode) {
            Logger.debug('[Flutter] ✅ Detected PDF from Content-Type header');
          }
        } else if (contentType.contains('excel') ||
            contentType.contains('spreadsheet') ||
            contentType.contains('xlsx') ||
            contentType ==
                'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet') {
          fileExtension = 'xlsx';
          mimeType =
              'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
          if (kDebugMode) {
            Logger.debug('[Flutter] ✅ Detected Excel from Content-Type header');
          }
        } else if (contentType.contains('csv') || contentType == 'text/csv') {
          fileExtension = 'csv';
          mimeType = 'text/csv';
          if (kDebugMode) {
            Logger.debug('[Flutter] ✅ Detected CSV from Content-Type header');
          }
        } else if (contentType.contains('json') ||
            contentType == 'application/json') {
          fileExtension = 'json';
          mimeType = 'application/json';
          if (kDebugMode) {
            Logger.debug('[Flutter] ✅ Detected JSON from Content-Type header');
          }
        } else {
          // Fallback: Check report data for format
          String? selectedFormat;
          if (report['outputFormat'] != null) {
            selectedFormat = report['outputFormat'] as String;
          } else if (report['fileFormat'] != null) {
            selectedFormat = report['fileFormat'] as String;
          } else if (report['parameters'] != null &&
              report['parameters']['format'] != null) {
            selectedFormat = report['parameters']['format'] as String;
          }

          if (selectedFormat != null) {
            switch (selectedFormat.toLowerCase()) {
              case 'excel':
                fileExtension = 'xlsx';
                mimeType =
                    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
                break;
              case 'pdf':
                fileExtension = 'pdf';
                mimeType = 'application/pdf';
                break;
              case 'csv':
                fileExtension = 'csv';
                mimeType = 'text/csv';
                break;
              default:
                fileExtension = selectedFormat;
                mimeType = 'application/octet-stream';
            }
            if (kDebugMode) {
              Logger.debug(
                '[Flutter] ⚠️ Using format from report data: $selectedFormat -> $fileExtension',
              );
            }
          } else {
            // Last resort: default to pdf (most common for reports)
            fileExtension = 'pdf';
            mimeType = 'application/pdf';
            if (kDebugMode) {
              Logger.debug('[Flutter] ⚠️ No format found, defaulting to PDF');
            }
          }
        }

        final fileName = '$cleanReportName.$fileExtension';
        if (kDebugMode) {
          Logger.debug(
            '[Flutter] Final download settings: filename=$fileName, extension=$fileExtension, mimeType=$mimeType',
          );
        }

        // Show downloading message
        if (mounted) {
          _showInfoSnackBar('Downloading $fileName...');
        }

        if (kIsWeb) {
          // Web platform: Use browser download API
          final bytes = response.bodyBytes;
          downloadFileWeb(bytes, fileName, mimeType);

          if (mounted) {
            _showStatusSnackBar('Downloaded $fileName successfully', 'success');
          }
        } else {
          // Mobile/Desktop platform: Use file system and share intent
          final tempDir = await getTemporaryDirectory();
          final file = File('${tempDir.path}/$fileName');
          await file.writeAsBytes(response.bodyBytes);

          // Use share intent to let user choose where to save
          await _shareReportFile(context, file, fileName, cleanReportName);
        }
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      if (mounted) {
        GlobalNotificationService().showError('Error downloading report: $e');
      }
    }
  }

  // Share report file using system share intent (Google Play compliant)
  Future<void> _shareReportFile(
    BuildContext context,
    File file,
    String fileName,
    String reportName,
  ) async {
    try {
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Report: $reportName',
        subject: 'SNS Report - $reportName',
      );

      _showStatusSnackBar('Share dialog opened for $fileName', 'success');
    } catch (e) {
      _showStatusSnackBar('Error sharing report: $e', 'error');
    }
  }

  Future<void> _deleteReport(Map<String, dynamic> report) async {
    try {
      // Show confirmation dialog
      final bool? confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete Report'),
          content: Text(
            'Are you sure you want to delete "${report['name'] ?? 'this report'}"?\n\nThis action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            Builder(
              builder: (context) {
                final errorColor = ThemeUtils.getStatusChipColor(
                  'error',
                  Theme.of(context),
                );
                return TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: TextButton.styleFrom(foregroundColor: errorColor),
                  child: const Text('Delete'),
                );
              },
            ),
          ],
        ),
      );

      if (confirmed != true) return;

      if (!mounted) return;
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      if (mounted) {
        GlobalNotificationService().showWarning(
          'Deleting ${report['name'] ?? 'report'}...',
        );
      }

      // Debug logging
      // 'DEBUG: Deleting report with data: $report');
      // 'DEBUG: Report ID: ${report['reportId']}');
      // 'DEBUG: Report _id: ${report['_id']}');
      // 'DEBUG: Report status: ${report['status']}');
      // 'DEBUG: Report name: ${report['name']}');

      // Use jobId (new system) or reportId/_id (old system)
      final reportId = report['jobId'] ?? report['reportId'] ?? report['_id'];
      if (reportId == null || reportId.toString() == 'null') {
        throw Exception('No valid report ID found. Report data: $report');
      }

      // Determine if this is a job ID (new system) or ObjectId (old system)
      final isJobId = reportId.toString().startsWith('job_');
      final user = authProvider.user;
      final userRole = user?['role'] ?? 'admin';

      // Use appropriate endpoint based on ID type
      final String deleteUrl;
      if (isJobId) {
        // New system: use company/super-admin reports/jobs endpoint
        final String baseEndpoint = userRole == 'super_admin'
            ? '${ApiConfig.baseUrl}/super-admin/reports/jobs'
            : '${ApiConfig.baseUrl}/company/reports/jobs';
        deleteUrl = '$baseEndpoint/$reportId';
      } else {
        // Old system: use legacy reports endpoint
        deleteUrl = '${ApiConfig.baseUrl}/reports/$reportId';
      }

      // Call the delete endpoint
      final response = await http.delete(
        Uri.parse(deleteUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${authProvider.token}',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          if (mounted) {
            _showStatusSnackBar(
              'Report "${report['name'] ?? 'Unknown'}" deleted successfully',
              'success',
            );
            // Refresh the report history
            _loadReportHistory();
          }
        } else {
          throw Exception(data['error'] ?? 'Delete failed');
        }
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      if (mounted) {
        GlobalNotificationService().showError('Error deleting report: $e');
      }
    }
  }

  Future<void> _openReport(Map<String, dynamic> report) async {
    try {
      // Navigate to a report viewer screen
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ReportViewerScreen(
              report: report,
              onDownload: () => _downloadReport(report),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        GlobalNotificationService().showError('Error opening report: $e');
      }
    }
  }

  Future<void> _loadAvailableReportTypes() async {
    setState(() {
      _isLoadingFeatures = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      // Get company features from the backend
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/company/features'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${authProvider.token}',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final features = data['features'] ?? {};

        // Build available report types based on company features
        List<String> availableTypes = [];

        // Timesheet is always available (replaces attendance)
        availableTypes.add('timesheet');

        // Feature-dependent report types
        if (features['leaveManagement'] == true) {
          availableTypes.add('leave');
        }
        if (features['payroll'] == true) {
          availableTypes.add('payroll');
        }
        if (features['performanceReviews'] == true) {
          availableTypes.add('performance');
        }
        if (features['advancedReporting'] == true) {
          availableTypes.add('custom');
        }

        setState(() {
          _availableReportTypes = availableTypes;
          if (availableTypes.isNotEmpty && _selectedReportType.isEmpty) {
            _selectedReportType = availableTypes.first;
          }
        });
      } else {
        // Fallback to basic report types
        setState(() {
          _availableReportTypes = ['timesheet', 'leave'];
          if (_selectedReportType.isEmpty) {
            _selectedReportType = 'timesheet';
          }
        });
      }
    } catch (e) {
      // Fallback to basic report types on error
      setState(() {
        _availableReportTypes = ['timesheet', 'leave'];
        if (_selectedReportType.isEmpty) {
          _selectedReportType = 'timesheet';
        }
      });
    } finally {
      setState(() {
        _isLoadingFeatures = false;
      });
    }
  }

  Future<void> _loadEmployees() async {
    setState(() {
      _isLoadingEmployees = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      // 'DEBUG: Loading employees from: ${ApiConfig.baseUrl}/analytics/employees');
      // 'DEBUG: Auth token: ${authProvider.token?.substring(0, 20)}...');

      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/analytics/employees'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${authProvider.token}',
        },
      );

      // 'DEBUG: Employee API response status: ${response.statusCode}');
      // 'DEBUG: Employee API response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final employees = List<Map<String, dynamic>>.from(data['data']);
          // 'DEBUG: Loaded ${employees.length} employees');
          // 'DEBUG: Employee data: ${employees.map((e) => '${e['name']} (${e['userId']})').join(', ')}');
          setState(() {
            _employees = employees;
          });
        } else {
          // 'DEBUG: API returned success=false or data=null');
        }
      } else {
        // 'DEBUG: API returned non-200 status: ${response.statusCode}');
      }
    } catch (e) {
      // 'DEBUG: Error loading employees: $e');
    } finally {
      setState(() {
        _isLoadingEmployees = false;
      });
    }
  }

  String _getReportTypeDisplayName(String type) {
    switch (type) {
      case 'attendance':
        // Map attendance to timesheet since they're unified
        return 'TIMESHEET';
      case 'timesheet':
        return 'TIMESHEET';
      case 'leave':
        return 'LEAVE MANAGEMENT';
      case 'payroll':
        return 'PAYROLL';
      case 'performance':
        return 'PERFORMANCE REVIEWS';
      case 'custom':
        return 'CUSTOM REPORTS';
      default:
        return type.toUpperCase();
    }
  }

  // Scheduled Reports Methods
  Future<void> _loadScheduledReports() async {
    setState(() {});

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/scheduled-reports'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${authProvider.token}',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          setState(() {
            _scheduledReports = List<Map<String, dynamic>>.from(
              data['data']['scheduledReports'] ?? [],
            );
          });
        }
      }
    } catch (e) {
      if (mounted) {
        GlobalNotificationService().showError(
          'Error loading scheduled reports: $e',
        );
      }
    } finally {
      if (mounted) {
        setState(() {});
      }
    }
  }

  Widget _buildEmptyScheduledReports() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.schedule,
            size: 64,
            color: colorScheme.onSurface.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No Scheduled Reports',
            style: theme.textTheme.headlineSmall?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create your first scheduled report to automate report generation.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _createScheduledReport,
            icon: const Icon(Icons.add),
            label: const Text('Create Schedule'),
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduledReportsList() {
    return Column(
      children: _scheduledReports
          .map((report) => _buildScheduledReportCard(report))
          .toList(),
    );
  }

  Widget _buildScheduledReportCard(Map<String, dynamic> report) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        report['name'] ?? 'Untitled Report',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (report['description'] != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          report['description'],
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                _buildStatusChip(report['status']),
              ],
            ),
            const SizedBox(height: 16),

            // Report Details
            Row(
              children: [
                Expanded(
                  child: _buildInfoItem(
                    'Report Type',
                    _getReportTypeDisplayName(report['reportType']),
                    Icons.assessment,
                  ),
                ),
                Expanded(
                  child: _buildInfoItem(
                    'Schedule',
                    _getScheduleDisplay(report['schedule']),
                    Icons.schedule,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Execution Info
            if (report['execution'] != null) ...[
              Row(
                children: [
                  Expanded(
                    child: _buildInfoItem(
                      'Last Run',
                      report['execution']['lastRun'] != null
                          ? TimeUtils.formatReadableDateTime(
                              TimeUtils.parseToLocal(
                                report['execution']['lastRun'],
                              ),
                              user: Provider.of<AuthProvider>(
                                context,
                                listen: false,
                              ).user,
                              company: Provider.of<AuthProvider>(
                                context,
                                listen: false,
                              ).company,
                            )
                          : 'Never',
                      Icons.history,
                    ),
                  ),
                  Expanded(
                    child: _buildInfoItem(
                      'Next Run',
                      report['schedule']['nextRun'] != null
                          ? TimeUtils.formatReadableDateTime(
                              TimeUtils.parseToLocal(
                                report['schedule']['nextRun'],
                              ),
                              user: Provider.of<AuthProvider>(
                                context,
                                listen: false,
                              ).user,
                              company: Provider.of<AuthProvider>(
                                context,
                                listen: false,
                              ).company,
                            )
                          : 'Not scheduled',
                      Icons.schedule,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],

            // Actions
            Row(
              children: [
                if (report['status'] == 'active') ...[
                  TextButton.icon(
                    onPressed: () => _pauseScheduledReport(report['_id']),
                    icon: const Icon(Icons.pause, size: 16),
                    label: const Text('Pause'),
                  ),
                ] else if (report['status'] == 'paused') ...[
                  TextButton.icon(
                    onPressed: () => _resumeScheduledReport(report['_id']),
                    icon: const Icon(Icons.play_arrow, size: 16),
                    label: const Text('Resume'),
                  ),
                ],
                TextButton.icon(
                  onPressed: () => _executeScheduledReport(report['_id']),
                  icon: const Icon(Icons.play_circle, size: 16),
                  label: const Text('Run Now'),
                ),
                const Spacer(),
                PopupMenuButton<String>(
                  onSelected: (value) =>
                      _handleScheduledReportAction(value, report['_id']),
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, size: 16),
                          SizedBox(width: 8),
                          Text('Edit'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'history',
                      child: Row(
                        children: [
                          Icon(Icons.history, size: 16),
                          SizedBox(width: 8),
                          Text('View History'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Builder(
                        builder: (context) {
                          final errorColor = ThemeUtils.getStatusChipColor(
                            'error',
                            Theme.of(context),
                          );
                          return Row(
                            children: [
                              Icon(Icons.delete, size: 16, color: errorColor),
                              const SizedBox(width: 8),
                              Text(
                                'Delete',
                                style: TextStyle(color: errorColor),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                  child: const Icon(Icons.more_vert),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String? status) {
    final theme = Theme.of(context);
    Color color;
    String text;

    switch (status) {
      case 'active':
        color = ThemeUtils.getStatusChipColor('success', theme);
        text = 'Active';
        break;
      case 'paused':
        color = ThemeUtils.getStatusChipColor('warning', theme);
        text = 'Paused';
        break;
      case 'stopped':
        color = ThemeUtils.getStatusChipColor('error', theme);
        text = 'Stopped';
        break;
      case 'error':
        color = ThemeUtils.getStatusChipColor('error', theme);
        text = 'Error';
        break;
      default:
        color = theme.colorScheme.onSurface.withValues(alpha: 0.5);
        text = 'Unknown';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildInfoItem(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _getScheduleDisplay(Map<String, dynamic>? schedule) {
    if (schedule == null) return 'Not configured';

    switch (schedule['type']) {
      case 'daily':
        return 'Daily at ${schedule['dailyTime'] ?? '09:00'}';
      case 'weekly':
        final days = [
          'Sunday',
          'Monday',
          'Tuesday',
          'Wednesday',
          'Thursday',
          'Friday',
          'Saturday',
        ];
        return 'Weekly on ${days[schedule['weeklyDay'] ?? 1]}';
      case 'monthly':
        return 'Monthly on ${schedule['monthlyDay'] ?? 1}';
      case 'custom':
        return 'Custom: ${schedule['cronExpression'] ?? 'Not set'}';
      default:
        return 'Unknown';
    }
  }

  void _createScheduledReport() {
    // Ensure we have report types loaded
    if (_availableReportTypes.isEmpty) {
      _loadAvailableReportTypes();
    }

    showDialog(
      context: context,
      builder: (context) => _CreateScheduledReportDialog(
        onSave: _saveScheduledReport,
        availableReportTypes: _availableReportTypes,
        employees: _employees,
      ),
    );
  }

  void _editScheduledReport(String id) {
    final report = _scheduledReports.firstWhere(
      (r) => r['_id'] == id,
      orElse: () => {},
    );

    if (report.isEmpty) {
      _showStatusSnackBar('Report not found', 'error');
      return;
    }

    showDialog(
      context: context,
      builder: (context) => _CreateScheduledReportDialog(
        onSave: _updateScheduledReport,
        availableReportTypes: _availableReportTypes,
        employees: _employees,
        existingReport: report,
      ),
    );
  }

  Future<void> _saveScheduledReport(Map<String, dynamic> reportData) async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/scheduled-reports'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${authProvider.token}',
        },
        body: json.encode(reportData),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) {
          GlobalNotificationService().showSuccess(
            'Scheduled report created successfully!',
          );
        }

        // Refresh scheduled reports list
        _loadScheduledReports();
      } else {
        final errorData = json.decode(response.body);
        throw Exception(
          errorData['error'] ??
              'Failed to create scheduled report: ${response.statusCode}',
        );
      }
    } catch (e) {
      if (mounted) {
        GlobalNotificationService().showError(
          'Error creating scheduled report: $e',
        );
      }
    }
  }

  Future<void> _updateScheduledReport(Map<String, dynamic> reportData) async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final reportId = reportData['_id'] ?? reportData['id'];

      if (reportId == null) {
        throw Exception('Report ID is required for update');
      }

      final response = await http.put(
        Uri.parse('${ApiConfig.baseUrl}/scheduled-reports/$reportId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${authProvider.token}',
        },
        body: json.encode(reportData),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) {
          GlobalNotificationService().showSuccess(
            'Scheduled report updated successfully!',
          );
        }

        // Refresh scheduled reports list
        _loadScheduledReports();
      } else {
        final errorData = json.decode(response.body);
        throw Exception(
          errorData['error'] ??
              'Failed to update scheduled report: ${response.statusCode}',
        );
      }
    } catch (e) {
      if (mounted) {
        GlobalNotificationService().showError(
          'Error updating scheduled report: $e',
        );
      }
    }
  }

  void _pauseScheduledReport(String id) {
    _updateScheduledReportStatus(id, 'pause');
  }

  void _resumeScheduledReport(String id) {
    _updateScheduledReportStatus(id, 'resume');
  }

  Future<void> _executeScheduledReport(String id) async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      // When "Run Now" is pressed, use stored dates from the form instead of calculating
      final response = await http.post(
        Uri.parse(
          '${ApiConfig.baseUrl}/scheduled-reports/$id/execute?useStoredDates=true',
        ),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${authProvider.token}',
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) {
          GlobalNotificationService().showSuccess(
            'Report executed successfully! Check the Report History tab to view and download the generated report.',
          );
        }

        // Refresh scheduled reports list to show updated last run time
        _loadScheduledReports();
      } else {
        final errorData = json.decode(response.body);
        throw Exception(
          errorData['error'] ??
              'Failed to execute report: ${response.statusCode}',
        );
      }
    } catch (e) {
      if (mounted) {
        GlobalNotificationService().showError('Error executing report: $e');
      }
    }
  }

  Future<void> _updateScheduledReportStatus(String id, String action) async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/scheduled-reports/$id/$action'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${authProvider.token}',
        },
      );

      if (response.statusCode == 200) {
        if (!mounted) return;
        GlobalNotificationService().showSuccess(
          'Scheduled report ${action}d successfully',
        );
        _loadScheduledReports(); // Refresh the list
      } else {
        throw Exception('Failed to $action scheduled report');
      }
    } catch (e) {
      if (!mounted) return;
      GlobalNotificationService().showError(
        'Error ${action}ing scheduled report: $e',
      );
    }
  }

  void _handleScheduledReportAction(String action, String id) {
    switch (action) {
      case 'edit':
        _editScheduledReport(id);
        break;
      case 'history':
        // TODO: Implement view execution history
        GlobalNotificationService().showInfo(
          'Execution History dialog coming soon!',
        );
        break;
      case 'delete':
        _deleteScheduledReport(id);
        break;
    }
  }

  Future<void> _deleteScheduledReport(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Scheduled Report'),
        content: const Text(
          'Are you sure you want to delete this scheduled report? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // ignore: use_build_context_synchronously
        final authProvider = Provider.of<AuthProvider>(context, listen: false);

        final response = await http.delete(
          Uri.parse('${ApiConfig.baseUrl}/scheduled-reports/$id'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${authProvider.token}',
          },
        );

        if (response.statusCode == 200) {
          GlobalNotificationService().showSuccess(
            'Scheduled report deleted successfully',
          );
          _loadScheduledReports(); // Refresh the list
        } else {
          throw Exception('Failed to delete scheduled report');
        }
      } catch (e) {
        GlobalNotificationService().showError(
          'Error deleting scheduled report: $e',
        );
      }
    }
  }

  // New methods for enhanced report history
  Widget _buildReportHistoryHeader() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;
    final company = authProvider.company;

    return Container(
      padding: const EdgeInsets.all(16),
      color: colorScheme.surface,
      child: Column(
        children: [
          // Top row with controls
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Showing ${_reportHistory.length} of $_totalReports reports',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              Row(
                children: [
                  // Time duration filter
                  DropdownButton<String>(
                    value: _timeDurationFilter,
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('All Time')),
                      DropdownMenuItem(
                        value: 'month',
                        child: Text('This Month'),
                      ),
                      DropdownMenuItem(value: 'year', child: Text('This Year')),
                      DropdownMenuItem(
                        value: 'custom',
                        child: Text('Custom Range'),
                      ),
                    ],
                    onChanged: (value) => _onTimeDurationChanged(value!),
                  ),
                  const SizedBox(width: 8),
                  // Bulk selection toggle
                  IconButton(
                    icon: Icon(
                      _isSelectionMode ? Icons.close : Icons.checklist,
                    ),
                    onPressed: _toggleSelectionMode,
                    tooltip: _isSelectionMode
                        ? 'Exit Selection'
                        : 'Select Reports',
                  ),
                ],
              ),
            ],
          ),
          // Selection mode controls
          if (_isSelectionMode) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                TextButton.icon(
                  onPressed: _selectedReports.isEmpty
                      ? null
                      : _selectAllReports,
                  icon: const Icon(Icons.select_all),
                  label: const Text('Select All'),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: _selectedReports.isEmpty ? null : _clearSelection,
                  icon: const Icon(Icons.clear),
                  label: const Text('Clear'),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _selectedReports.isEmpty
                      ? null
                      : _bulkDeleteReports,
                  icon: Builder(
                    builder: (context) => Icon(
                      Icons.delete,
                      color: ThemeUtils.getStatusChipColor(
                        'error',
                        Theme.of(context),
                      ),
                    ),
                  ),
                  label: Text('Delete (${_selectedReports.length})'),
                ),
              ],
            ),
          ],
          // Custom date range picker
          if (_timeDurationFilter == 'custom') ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _selectFilterDate(true),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'From Date',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      child: Text(
                        TimeUtils.formatDateWithFormat(
                          _filterStartDate,
                          'MMM dd, yyyy',
                          user: user,
                          company: company,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: InkWell(
                    onTap: () => _selectFilterDate(false),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'To Date',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      child: Text(
                        TimeUtils.formatDateWithFormat(
                          _filterEndDate,
                          'MMM dd, yyyy',
                          user: user,
                          company: company,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _applyCustomFilter,
                  icon: const Icon(Icons.search),
                  tooltip: 'Apply Filter',
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _onTimeDurationChanged(String value) {
    setState(() {
      _timeDurationFilter = value;
      if (value == 'month') {
        _filterStartDate = DateTime(
          DateTime.now().year,
          DateTime.now().month,
          1,
        );
        _filterEndDate = DateTime.now();
      } else if (value == 'year') {
        _filterStartDate = DateTime(DateTime.now().year, 1, 1);
        _filterEndDate = DateTime.now();
      }
    });
    _loadReportHistory(loadMore: false);
  }

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      if (!_isSelectionMode) {
        _selectedReports.clear();
      }
    });
  }

  void _toggleReportSelection(String reportId) {
    setState(() {
      if (_selectedReports.contains(reportId)) {
        _selectedReports.remove(reportId);
      } else {
        _selectedReports.add(reportId);
      }
    });
  }

  void _selectAllReports() {
    setState(() {
      _selectedReports = _reportHistory
          .map((report) => report['_id'] as String)
          .toSet();
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedReports.clear();
    });
  }

  Future<void> _bulkDeleteReports() async {
    if (_selectedReports.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Reports'),
        content: Text(
          'Are you sure you want to delete ${_selectedReports.length} reports? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);

        final user = authProvider.user;
        final userRole = user?['role'] ?? 'admin';

        for (final reportId in _selectedReports) {
          // Determine if this is a job ID (new system) or ObjectId (old system)
          final isJobId = reportId.toString().startsWith('job_');

          // Use appropriate endpoint based on ID type
          final String deleteUrl;
          if (isJobId) {
            // New system: use company/super-admin reports/jobs endpoint
            final String baseEndpoint = userRole == 'super_admin'
                ? '${ApiConfig.baseUrl}/super-admin/reports/jobs'
                : '${ApiConfig.baseUrl}/company/reports/jobs';
            deleteUrl = '$baseEndpoint/$reportId';
          } else {
            // Old system: use legacy reports endpoint
            deleteUrl = '${ApiConfig.baseUrl}/reports/$reportId';
          }

          final response = await http.delete(
            Uri.parse(deleteUrl),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${authProvider.token}',
            },
          );

          if (response.statusCode != 200) {
            throw Exception('Failed to delete report $reportId');
          }
        }

        if (mounted) {
          GlobalNotificationService().showSuccess(
            '${_selectedReports.length} reports deleted successfully',
          );

          setState(() {
            _selectedReports.clear();
            _isSelectionMode = false;
          });

          _loadReportHistory(loadMore: false);
        }
      } catch (e) {
        if (mounted) {
          GlobalNotificationService().showError('Error deleting reports: $e');
        }
      }
    }
  }

  Future<void> _selectFilterDate(bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStartDate ? _filterStartDate : _filterEndDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _filterStartDate = picked;
        } else {
          _filterEndDate = picked;
        }
      });
    }
  }

  void _applyCustomFilter() {
    _loadReportHistory(loadMore: false);
  }

  // Check if a report type supports pivot format
  bool _supportsPivotFormat(String reportType) {
    final type = reportType.toLowerCase();
    // Only attendance and timesheet support pivot format
    return type == 'attendance' || type == 'timesheet';
  }

  // Get description text for pivot format based on report type
  String _getPivotFormatDescription(String reportType) {
    if (!_supportsPivotFormat(reportType)) {
      if (reportType.toLowerCase() == 'leave') {
        return 'Not available for Leave Management reports';
      } else {
        return 'Only available for Attendance/Timesheet reports';
      }
    }
    return 'Compact format with employees as rows, dates as columns';
  }
}

class ReportViewerScreen extends StatefulWidget {
  final Map<String, dynamic> report;
  final VoidCallback onDownload;

  const ReportViewerScreen({
    super.key,
    required this.report,
    required this.onDownload,
  });

  @override
  State<ReportViewerScreen> createState() => _ReportViewerScreenState();
}

class _ReportViewerScreenState extends State<ReportViewerScreen> {
  bool _isLoading = false;
  Map<String, dynamic>? _reportData;

  // Filter state
  String? _selectedEmployee;
  String? _selectedStatus;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _showFilters = false;

  // Pagination state
  int _currentPage = 1;
  static const int _itemsPerPage = 20;

  // Report date range (from report parameters)
  DateTime? _reportStartDate;
  DateTime? _reportEndDate;

  @override
  void initState() {
    super.initState();
    _initializeReportDateRange();
    _loadReportData();
  }

  void _initializeReportDateRange() {
    // Get date range from report parameters
    final parameters = widget.report['parameters'];
    if (parameters != null) {
      if (parameters['startDate'] != null) {
        try {
          _reportStartDate = DateTime.parse(parameters['startDate']);
        } catch (e) {
          // Ignore parse errors
        }
      }
      if (parameters['endDate'] != null) {
        try {
          _reportEndDate = DateTime.parse(parameters['endDate']);
        } catch (e) {
          // Ignore parse errors
        }
      }
    }
  }

  Future<void> _loadReportData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.user;
      final userRole = user?['role'] ?? 'admin';

      // Get reportId - could be jobId (new system) or ObjectId (old system)
      final reportId =
          widget.report['jobId'] ??
          widget.report['reportId'] ??
          widget.report['_id'];
      final isJobId = reportId.toString().startsWith('job_');
      // Get format from report data - prefer fileFormat, then parameters.format, default to excel for new system
      final fileFormat =
          widget.report['fileFormat']?.toString().toLowerCase() ??
          widget.report['parameters']?['format']?.toString().toLowerCase() ??
          (isJobId ? 'excel' : 'json');

      // For new unified engine (jobId), handle differently
      if (isJobId) {
        // Determine base endpoint based on user role
        final String baseEndpoint = userRole == 'super_admin'
            ? '${ApiConfig.baseUrl}/super-admin/reports'
            : '${ApiConfig.baseUrl}/company/reports';

        // First, get job status to check if it's completed
        final jobStatusResponse = await http.get(
          Uri.parse('$baseEndpoint/jobs/$reportId'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${authProvider.token}',
          },
        );

        if (jobStatusResponse.statusCode == 200) {
          final jobData = json.decode(jobStatusResponse.body);
          // Backend returns job object directly at top level, not wrapped in 'data'
          // Response structure: { success: true, jobId: "...", status: "...", ... }
          if (jobData['success'] == true) {
            // Job object is at top level, not in 'data' field
            final job = jobData;
            final status = job['status'] ?? 'unknown';
            final actualFormat =
                job['outputFormat'] ?? job['params']?['format'] ?? fileFormat;

            Logger.debug(
              '[ReportViewer] Job status: $status, Format: $actualFormat',
            );

            // Only load data if job is completed
            if (status == 'completed') {
              // Always request JSON format for viewing, regardless of the original format
              Logger.debug(
                '[ReportViewer] Requesting report in JSON format for viewing (original format: $actualFormat)...',
              );
              final downloadResponse = await http.get(
                Uri.parse('$baseEndpoint/jobs/$reportId/download?format=json'),
                headers: {'Authorization': 'Bearer ${authProvider.token}'},
              );

              if (downloadResponse.statusCode == 200) {
                try {
                  // Parse JSON response
                  final responseData = json.decode(downloadResponse.body);
                  Logger.debug(
                    '[ReportViewer] Response structure: ${responseData.keys}',
                  );

                  // Backend now returns { success: true, data: {...} } for JSON viewing
                  // Or it might return the JSON directly (for backward compatibility)
                  final reportData = responseData['data'] ?? responseData;

                  Logger.debug(
                    '[ReportViewer] Response data structure: hasSuccess=${responseData.containsKey('success')}, success=${responseData['success']}, hasData=${responseData.containsKey('data')}, dataType=${reportData.runtimeType}',
                  );
                  Logger.debug(
                    '[ReportViewer] Summary check: hasSummary=${reportData is Map && reportData.containsKey('summary')}, summaryType=${reportData is Map ? reportData['summary']?.runtimeType : 'N/A'}',
                  );
                  if (reportData is Map && reportData['summary'] is Map) {
                    final summary = reportData['summary'] as Map;
                    Logger.debug(
                      '[ReportViewer] Summary keys: ${summary.keys.toList()}',
                    );
                    Logger.debug(
                      '[ReportViewer] Summary totalWorkHours: ${summary['totalWorkHours']}',
                    );
                  }

                  if (responseData['success'] == true && reportData != null) {
                    Logger.info(
                      '[ReportViewer] ✅ Successfully loaded JSON report data',
                    );
                    if (reportData is Map && reportData['summary'] is Map) {
                      final summary = reportData['summary'] as Map;
                      Logger.info(
                        '[ReportViewer] Summary check: hasSummary=true, totalWorkHours=${summary['totalWorkHours']}, totalEmployees=${summary['totalEmployees']}',
                      );
                    } else {
                      Logger.info(
                        '[ReportViewer] Summary check: hasSummary=false',
                      );
                    }

                    // CRITICAL FIX: Ensure reportData has 'details' as a List
                    // Handle different data structures (details, data, or nested structures)
                    Map<String, dynamic> normalizedData = {};
                    if (reportData is Map) {
                      normalizedData = Map<String, dynamic>.from(reportData);

                      // Ensure 'details' exists and is a List
                      if (!normalizedData.containsKey('details') ||
                          normalizedData['details'] == null) {
                        // Try to get from 'data' field if it exists
                        if (normalizedData.containsKey('data')) {
                          if (normalizedData['data'] is List) {
                            normalizedData['details'] = normalizedData['data'];
                          } else {
                            normalizedData['details'] = [];
                          }
                        } else {
                          normalizedData['details'] = [];
                        }
                      } else if (normalizedData['details'] is! List) {
                        // If details exists but is not a List, convert it or set to empty list
                        Logger.warning(
                          '[ReportViewer] ⚠️ Warning: details is not a List, type: ${normalizedData['details'].runtimeType}',
                        );
                        if (normalizedData['details'] is Map) {
                          // If it's a Map, try to extract an array from it
                          final detailsMap = normalizedData['details'] as Map;
                          if (detailsMap.containsKey('rows') &&
                              detailsMap['rows'] is List) {
                            normalizedData['details'] = detailsMap['rows'];
                          } else {
                            normalizedData['details'] = [];
                          }
                        } else {
                          normalizedData['details'] = [];
                        }
                      }

                      // Ensure 'data' also exists for backward compatibility
                      if (!normalizedData.containsKey('data') ||
                          normalizedData['data'] == null) {
                        normalizedData['data'] = normalizedData['details'];
                      }

                      Logger.debug(
                        '[ReportViewer] Normalized data structure: hasDetails=${normalizedData.containsKey('details')}, detailsType=${normalizedData['details'].runtimeType}, detailsLength=${normalizedData['details'] is List ? (normalizedData['details'] as List).length : 'N/A'}',
                      );
                    } else {
                      // If reportData is not a Map, wrap it
                      normalizedData = {
                        'details': [],
                        'data': [],
                        'summary': {},
                        'message': 'Invalid report data structure',
                      };
                    }

                    setState(() {
                      _reportData = normalizedData;
                    });
                    return;
                  } else {
                    Logger.error(
                      '[ReportViewer] ❌ Invalid response structure or no data',
                    );
                    Logger.debug(
                      '[ReportViewer] ResponseData keys: ${responseData.keys}',
                    );
                    Logger.debug(
                      '[ReportViewer] ResponseData success: ${responseData['success']}',
                    );
                    Logger.debug(
                      '[ReportViewer] ReportData: ${reportData?.toString()}',
                    );
                    setState(() {
                      _reportData = {
                        'message':
                            'Report data is empty or invalid. Response: ${responseData.toString()}',
                        'canDownload': true,
                        'format': actualFormat,
                      };
                    });
                    return;
                  }
                } catch (e) {
                  Logger.error('[ReportViewer] Error parsing JSON: $e');
                  setState(() {
                    _reportData = {
                      'message':
                          'Error parsing report data. Please try downloading the report.',
                      'canDownload': true,
                      'format': actualFormat,
                    };
                  });
                  return;
                }
              } else {
                Logger.error(
                  '[ReportViewer] Download failed with status: ${downloadResponse.statusCode}',
                );
                setState(() {
                  _reportData = {
                    'message': 'Failed to load report data. Please try again.',
                    'canDownload': true,
                    'format': actualFormat,
                  };
                });
                return;
              }
            } else {
              // Job not completed
              Logger.debug(
                '[ReportViewer] Job status is $status - not completed yet',
              );
              setState(() {
                _reportData = {
                  'message':
                      'Report is still $status. Please wait for it to complete.',
                  'status': status,
                };
              });
              return;
            }
          } else {
            Logger.debug(
              '[ReportViewer] Invalid response structure: ${jobData.toString()}',
            );
          }
        } else {
          Logger.error(
            '[ReportViewer] Job status request failed with status: ${jobStatusResponse.statusCode}',
          );
        }

        // If we get here, something went wrong with the new system
        Logger.warning('[ReportViewer] Falling back to empty report data');
        _setEmptyReportData();
        return;
      }

      // Old system - use the original endpoint
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/reports/$reportId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${authProvider.token}',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          // Use the reportData from the backend response
          // Backend now always converts pivot to detailed format, so we always use details
          final reportData = data['data']['reportData'] ?? data['data'];

          // CRITICAL FIX: Ensure reportData has 'details' as a List
          Map<String, dynamic> normalizedData = {};
          if (reportData is Map) {
            normalizedData = Map<String, dynamic>.from(reportData);

            // Ensure 'details' exists and is a List
            if (!normalizedData.containsKey('details') ||
                normalizedData['details'] == null) {
              // Try to get from 'data' field if it exists
              if (normalizedData.containsKey('data')) {
                if (normalizedData['data'] is List) {
                  normalizedData['details'] = normalizedData['data'];
                } else {
                  normalizedData['details'] = [];
                }
              } else {
                normalizedData['details'] = [];
              }
            } else if (normalizedData['details'] is! List) {
              // If details exists but is not a List, convert it or set to empty list
              if (normalizedData['details'] is Map) {
                final detailsMap = normalizedData['details'] as Map;
                if (detailsMap.containsKey('rows') &&
                    detailsMap['rows'] is List) {
                  normalizedData['details'] = detailsMap['rows'];
                } else {
                  normalizedData['details'] = [];
                }
              } else {
                normalizedData['details'] = [];
              }
            }

            // Ensure 'data' also exists for backward compatibility
            if (!normalizedData.containsKey('data') ||
                normalizedData['data'] == null) {
              normalizedData['data'] = normalizedData['details'];
            }
          } else {
            // If reportData is not a Map, wrap it
            normalizedData = {'details': [], 'data': [], 'summary': {}};
          }

          setState(() {
            _reportData = normalizedData;
          });
        } else {
          // Fallback to empty data structure
          _setEmptyReportData();
        }
      } else {
        // Fallback to empty data structure
        _setEmptyReportData();
      }
    } catch (e) {
      // Handle error - show empty data
      Logger.error('Error loading report data: $e');
      _setEmptyReportData();
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _setEmptyReportData() {
    setState(() {
      // Handle both 'timesheet' and 'attendance' the same way since they're unified
      final reportType = widget.report['reportType'];
      if (reportType == 'timesheet' || reportType == 'attendance') {
        _reportData = {
          'summary': {
            'totalWorkHours': '0.00',
            'totalBreakHours': '0.00',
            'netWorkHours': '0.00',
            'workingDays': 0,
            'averageWorkHours': '0.00',
            'totalRecords': 0,
            'totalEmployees': 0,
            'employeesWithAttendance': 0,
            'employeesWithoutAttendance': 0,
          },
          'details': [],
        };
      } else if (widget.report['reportType'] == 'leave') {
        // Leave report data
        _reportData = {
          'summary': {
            'totalDays': 0,
            'totalEmployees': 0,
            'totalLeaveRequests': 0,
            'approvedLeaves': 0,
            'pendingLeaves': 0,
            'rejectedLeaves': 0,
            'totalHolidays': 0,
            'fullDayLeaves': 0,
            'halfDayLeaves': 0,
          },
          'details': [],
        };
      } else {
        // Default attendance report data
        _reportData = {
          'summary': {
            'totalDays': 0,
            'presentDays': 0,
            'absentDays': 0,
            'lateDays': 0,
            'attendanceRate': '0.00',
            'totalRecords': 0,
          },
          'details': [],
        };
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.report['name'] ?? 'Report Viewer'),
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _reportData == null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Failed to load report data',
                    style: theme.textTheme.headlineSmall,
                  ),
                ],
              ),
            )
          : _reportData?['message'] != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _reportData!['canDownload'] == true
                          ? Icons.download
                          : Icons.info_outline,
                      size: 64,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _reportData!['message'] ?? 'Unable to display report',
                      style: theme.textTheme.titleLarge,
                      textAlign: TextAlign.center,
                    ),
                    if (_reportData!['canDownload'] == true) ...[
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: widget.onDownload,
                        icon: const Icon(Icons.download),
                        label: const Text('Download Report'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Report Header
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.report['name'] ?? 'Report',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Type: ${widget.report['reportType']?.toString().toUpperCase() ?? 'N/A'}',
                          ),
                          Text(
                            'Generated: ${TimeUtils.formatReadableDateTime(TimeUtils.parseToLocal(widget.report['createdAt']), user: Provider.of<AuthProvider>(context, listen: false).user, company: Provider.of<AuthProvider>(context, listen: false).company)}',
                          ),
                          Text(
                            'Status: ${widget.report['status']?.toString().toUpperCase() ?? 'N/A'}',
                          ),
                          Text(
                            'Format: ${widget.report['fileFormat']?.toString().toUpperCase() ?? 'N/A'}',
                          ),
                          if (widget.report['parameters'] != null &&
                              widget.report['parameters']['layout'] != null)
                            Text(
                              'Layout: ${widget.report['parameters']['layout'].toString().toUpperCase()}',
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Report Summary
                  if (_reportData!['summary'] != null) ...[
                    Text(
                      'Summary',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Card(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            // Attendance report summary
                            if (_reportData!['summary']['totalDays'] != null)
                              _buildSummaryRow(
                                'Total Days',
                                _reportData!['summary']['totalDays'].toString(),
                              ),
                            if (_reportData!['summary']['totalActiveDays'] !=
                                null)
                              _buildSummaryRow(
                                'Total Active Days',
                                _reportData!['summary']['totalActiveDays']
                                    .toString(),
                              ),
                            if (_reportData!['summary']['totalActiveDays'] ==
                                    null &&
                                _reportData!['summary']['presentDays'] != null)
                              _buildSummaryRow(
                                'Total Active Days',
                                _reportData!['summary']['presentDays']
                                    .toString(),
                              ),
                            if (_reportData!['summary']['presentDays'] !=
                                    null &&
                                _reportData!['summary']['totalActiveDays'] !=
                                    null)
                              _buildSummaryRow(
                                'Present Days',
                                _reportData!['summary']['presentDays']
                                    .toString(),
                              ),
                            if (_reportData!['summary']['absentDays'] != null)
                              _buildSummaryRow(
                                'Absent Days',
                                _reportData!['summary']['absentDays']
                                    .toString(),
                              ),
                            if (_reportData!['summary']['absentDays'] == null &&
                                _reportData!['summary']['totalAbsentDays'] !=
                                    null)
                              _buildSummaryRow(
                                'Absent Days',
                                _reportData!['summary']['totalAbsentDays']
                                    .toString(),
                              ),
                            if (_reportData!['summary']['leaveDays'] != null)
                              _buildSummaryRow(
                                'Leave Days',
                                _reportData!['summary']['leaveDays'].toString(),
                              ),

                            // Timesheet report summary
                            if (_reportData!['summary']['totalWorkHours'] !=
                                null)
                              _buildSummaryRow(
                                'Total Work Hours',
                                '${_reportData!['summary']['totalWorkHours']}h',
                              ),
                            if (_reportData!['summary']['totalBreakHours'] !=
                                null)
                              _buildSummaryRow(
                                'Total Break Hours',
                                '${_reportData!['summary']['totalBreakHours']}h',
                              ),
                            if (_reportData!['summary']['netWorkHours'] != null)
                              _buildSummaryRow(
                                'Net Work Hours',
                                '${_reportData!['summary']['netWorkHours']}h',
                              ),
                            if (_reportData!['summary']['workingDays'] != null)
                              _buildSummaryRow(
                                'Working Days',
                                _reportData!['summary']['workingDays']
                                    .toString(),
                              ),
                            if (_reportData!['summary']['averageWorkHours'] !=
                                null)
                              _buildSummaryRow(
                                'Average Work Hours',
                                '${_reportData!['summary']['averageWorkHours']}h',
                              ),
                            if (_reportData!['summary']['totalEmployees'] !=
                                null)
                              _buildSummaryRow(
                                'Total Employees',
                                _reportData!['summary']['totalEmployees']
                                    .toString(),
                              ),
                            if (_reportData!['summary']['employeesWithAttendance'] !=
                                null)
                              _buildSummaryRow(
                                'Employees with Attendance',
                                _reportData!['summary']['employeesWithAttendance']
                                    .toString(),
                              ),
                            if (_reportData!['summary']['employeesWithoutAttendance'] !=
                                null)
                              _buildSummaryRow(
                                'Employees without Attendance',
                                _reportData!['summary']['employeesWithoutAttendance']
                                    .toString(),
                              ),

                            // Leave report summary
                            if (_reportData!['summary']['totalLeaveRequests'] !=
                                null)
                              _buildSummaryRow(
                                'Total Leave Requests',
                                _reportData!['summary']['totalLeaveRequests']
                                    .toString(),
                              ),
                            if (_reportData!['summary']['approvedLeaves'] !=
                                null)
                              _buildSummaryRow(
                                'Approved Leaves',
                                _reportData!['summary']['approvedLeaves']
                                    .toString(),
                              ),
                            if (_reportData!['summary']['pendingLeaves'] !=
                                null)
                              _buildSummaryRow(
                                'Pending Leaves',
                                _reportData!['summary']['pendingLeaves']
                                    .toString(),
                              ),
                            if (_reportData!['summary']['rejectedLeaves'] !=
                                null)
                              _buildSummaryRow(
                                'Rejected Leaves',
                                _reportData!['summary']['rejectedLeaves']
                                    .toString(),
                              ),
                            if (_reportData!['summary']['totalHolidays'] !=
                                null)
                              _buildSummaryRow(
                                'Total Holidays',
                                _reportData!['summary']['totalHolidays']
                                    .toString(),
                              ),
                            if (_reportData!['summary']['fullDayLeaves'] !=
                                null)
                              _buildSummaryRow(
                                'Full Day Leaves',
                                _reportData!['summary']['fullDayLeaves']
                                    .toString(),
                              ),
                            if (_reportData!['summary']['halfDayLeaves'] !=
                                null)
                              _buildSummaryRow(
                                'Half Day Leaves',
                                _reportData!['summary']['halfDayLeaves']
                                    .toString(),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Report Details with Filters
                  // Always show details section for timesheet/attendance reports
                  if (widget.report['reportType'] == 'timesheet' ||
                      widget.report['reportType'] == 'attendance') ...[
                    // Show message if details are empty
                    // Calculate isEmpty inline to avoid variable declaration in list literal
                    if ((_reportData!['details'] == null) ||
                        (_reportData!['details'] is! List) ||
                        (_reportData!['details'] is List &&
                            (_reportData!['details'] as List).isEmpty)) ...[
                      Text(
                        'Details',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Card(
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Center(
                            child: Column(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  size: 48,
                                  color: colorScheme.onSurface.withValues(
                                    alpha: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No timesheet details available',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: colorScheme.onSurface.withValues(
                                      alpha: 0.7,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'The report summary is available above, but detailed timesheet data is not included in this report.',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: colorScheme.onSurface.withValues(
                                      alpha: 0.6,
                                    ),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ] else ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Details',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Row(
                            children: [
                              Text(
                                'Showing ${_getPaginatedRange()} of ${_getFilteredDetailsCount()} filtered (${_getFilteredDetails().length} total)',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: Icon(
                                  _showFilters
                                      ? Icons.filter_list
                                      : Icons.filter_list_off,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _showFilters = !_showFilters;
                                  });
                                },
                                tooltip: 'Toggle Filters',
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Filters Section
                      if (_showFilters) ...[
                        Card(
                          elevation: 1,
                          color: Colors.grey.shade50,
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Filters',
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                LayoutBuilder(
                                  builder: (context, constraints) {
                                    // Use responsive layout based on available width
                                    final isWide = constraints.maxWidth > 800;

                                    return Wrap(
                                      spacing: 12,
                                      runSpacing: 12,
                                      children: [
                                        // Employee Filter
                                        SizedBox(
                                          width: isWide
                                              ? 200
                                              : constraints.maxWidth > 400
                                              ? (constraints.maxWidth - 24) / 2
                                              : constraints.maxWidth - 24,
                                          child: DropdownButtonFormField<String>(
                                            initialValue: _selectedEmployee,
                                            decoration: const InputDecoration(
                                              labelText: 'Employee',
                                              border: OutlineInputBorder(),
                                              contentPadding:
                                                  EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 8,
                                                  ),
                                              isDense: true,
                                            ),
                                            isExpanded: true,
                                            items: [
                                              const DropdownMenuItem<String>(
                                                value: null,
                                                child: Text(
                                                  'All Employees',
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                              ..._getUniqueEmployees().map(
                                                (emp) =>
                                                    DropdownMenuItem<String>(
                                                      value: emp,
                                                      child: Text(
                                                        emp,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                    ),
                                              ),
                                            ],
                                            onChanged: (value) {
                                              setState(() {
                                                _selectedEmployee = value;
                                                _currentPage =
                                                    1; // Reset to first page on filter change
                                              });
                                            },
                                          ),
                                        ),

                                        // Status Filter
                                        SizedBox(
                                          width: isWide
                                              ? 200
                                              : constraints.maxWidth > 400
                                              ? (constraints.maxWidth - 24) / 2
                                              : constraints.maxWidth - 24,
                                          child: DropdownButtonFormField<String>(
                                            initialValue: _selectedStatus,
                                            decoration: const InputDecoration(
                                              labelText: 'Status',
                                              border: OutlineInputBorder(),
                                              contentPadding:
                                                  EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 8,
                                                  ),
                                              isDense: true,
                                            ),
                                            isExpanded: true,
                                            items: [
                                              const DropdownMenuItem<String>(
                                                value: null,
                                                child: Text(
                                                  'All Statuses',
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                              ..._getUniqueStatuses().map(
                                                (status) =>
                                                    DropdownMenuItem<String>(
                                                      value: status,
                                                      child: Text(
                                                        status,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                    ),
                                              ),
                                            ],
                                            onChanged: (value) {
                                              setState(() {
                                                _selectedStatus = value;
                                                _currentPage =
                                                    1; // Reset to first page on filter change
                                              });
                                            },
                                          ),
                                        ),

                                        // Start Date Filter
                                        SizedBox(
                                          width: isWide
                                              ? 150
                                              : constraints.maxWidth > 400
                                              ? (constraints.maxWidth - 24) / 2
                                              : constraints.maxWidth - 24,
                                          child: InkWell(
                                            onTap: () async {
                                              final date = await showDatePicker(
                                                context: context,
                                                initialDate:
                                                    _startDate ??
                                                    _reportStartDate ??
                                                    DateTime.now(),
                                                firstDate:
                                                    _reportStartDate ??
                                                    DateTime(2020),
                                                lastDate:
                                                    _reportEndDate ??
                                                    _endDate ??
                                                    DateTime(2100),
                                              );
                                              if (date != null) {
                                                setState(() {
                                                  _startDate = date;
                                                  _currentPage =
                                                      1; // Reset to first page on filter change
                                                });
                                              }
                                            },
                                            child: InputDecorator(
                                              decoration: const InputDecoration(
                                                labelText: 'Start Date',
                                                border: OutlineInputBorder(),
                                                contentPadding:
                                                    EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 8,
                                                    ),
                                                suffixIcon: Icon(
                                                  Icons.calendar_today,
                                                  size: 20,
                                                ),
                                                isDense: true,
                                              ),
                                              child: Text(
                                                _startDate != null
                                                    ? '${_startDate!.day}/${_startDate!.month}/${_startDate!.year}'
                                                    : 'Select Date',
                                                style: TextStyle(
                                                  color: _startDate != null
                                                      ? null
                                                      : Colors.grey,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ),
                                        ),

                                        // End Date Filter
                                        SizedBox(
                                          width: isWide
                                              ? 150
                                              : constraints.maxWidth > 400
                                              ? (constraints.maxWidth - 24) / 2
                                              : constraints.maxWidth - 24,
                                          child: InkWell(
                                            onTap: () async {
                                              final date = await showDatePicker(
                                                context: context,
                                                initialDate:
                                                    _endDate ??
                                                    _reportEndDate ??
                                                    DateTime.now(),
                                                firstDate:
                                                    _startDate ??
                                                    _reportStartDate ??
                                                    DateTime(2020),
                                                lastDate:
                                                    _reportEndDate ??
                                                    DateTime(2100),
                                              );
                                              if (date != null) {
                                                setState(() {
                                                  _endDate = date;
                                                  _currentPage =
                                                      1; // Reset to first page on filter change
                                                });
                                              }
                                            },
                                            child: InputDecorator(
                                              decoration: const InputDecoration(
                                                labelText: 'End Date',
                                                border: OutlineInputBorder(),
                                                contentPadding:
                                                    EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 8,
                                                    ),
                                                suffixIcon: Icon(
                                                  Icons.calendar_today,
                                                  size: 20,
                                                ),
                                                isDense: true,
                                              ),
                                              child: Text(
                                                _endDate != null
                                                    ? '${_endDate!.day}/${_endDate!.month}/${_endDate!.year}'
                                                    : 'Select Date',
                                                style: TextStyle(
                                                  color: _endDate != null
                                                      ? null
                                                      : Colors.grey,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ),
                                        ),

                                        // Clear Filters Button
                                        SizedBox(
                                          width: isWide
                                              ? null
                                              : constraints.maxWidth - 24,
                                          child: ElevatedButton.icon(
                                            onPressed: () {
                                              setState(() {
                                                _selectedEmployee = null;
                                                _selectedStatus = null;
                                                _startDate = null;
                                                _endDate = null;
                                                _currentPage =
                                                    1; // Reset to first page
                                              });
                                            },
                                            icon: const Icon(
                                              Icons.clear,
                                              size: 18,
                                            ),
                                            label: const Text('Clear'),
                                            style: ElevatedButton.styleFrom(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 16,
                                                    vertical: 12,
                                                  ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],

                      Card(
                        elevation: 2,
                        child: Column(
                          children: [
                            _buildGroupedReportDetails(),
                            _buildPaginationControls(),
                          ],
                        ),
                      ),
                    ],
                  ],
                  // Also show details for other report types if they have details
                  if ((widget.report['reportType'] != 'timesheet' &&
                          widget.report['reportType'] != 'attendance') &&
                      _reportData!['details'] != null &&
                      _reportData!['details'] is List &&
                      (_reportData!['details'] as List).isNotEmpty) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Details',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Row(
                          children: [
                            Text(
                              'Showing ${_getPaginatedRange()} of ${_getFilteredDetailsCount()} filtered (${_getFilteredDetails().length} total)',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: Icon(
                                _showFilters
                                    ? Icons.filter_list
                                    : Icons.filter_list_off,
                              ),
                              onPressed: () {
                                setState(() {
                                  _showFilters = !_showFilters;
                                });
                              },
                              tooltip: 'Toggle Filters',
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Filters Section
                    if (_showFilters) ...[
                      Card(
                        elevation: 1,
                        color: Colors.grey.shade50,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Filters',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 12),
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  // Use responsive layout based on available width
                                  final isWide = constraints.maxWidth > 800;

                                  return Wrap(
                                    spacing: 12,
                                    runSpacing: 12,
                                    children: [
                                      // Employee Filter
                                      SizedBox(
                                        width: isWide
                                            ? 200
                                            : constraints.maxWidth > 400
                                            ? (constraints.maxWidth - 24) / 2
                                            : constraints.maxWidth - 24,
                                        child: DropdownButtonFormField<String>(
                                          initialValue: _selectedEmployee,
                                          decoration: const InputDecoration(
                                            labelText: 'Employee',
                                            border: OutlineInputBorder(),
                                            contentPadding:
                                                EdgeInsets.symmetric(
                                                  horizontal: 12,
                                                  vertical: 8,
                                                ),
                                            isDense: true,
                                          ),
                                          isExpanded: true,
                                          items: [
                                            const DropdownMenuItem<String>(
                                              value: null,
                                              child: Text(
                                                'All Employees',
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            ..._getUniqueEmployees().map(
                                              (emp) => DropdownMenuItem<String>(
                                                value: emp,
                                                child: Text(
                                                  emp,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ),
                                          ],
                                          onChanged: (value) {
                                            setState(() {
                                              _selectedEmployee = value;
                                              _currentPage =
                                                  1; // Reset to first page on filter change
                                            });
                                          },
                                        ),
                                      ),

                                      // Status Filter
                                      SizedBox(
                                        width: isWide
                                            ? 200
                                            : constraints.maxWidth > 400
                                            ? (constraints.maxWidth - 24) / 2
                                            : constraints.maxWidth - 24,
                                        child: DropdownButtonFormField<String>(
                                          initialValue: _selectedStatus,
                                          decoration: const InputDecoration(
                                            labelText: 'Status',
                                            border: OutlineInputBorder(),
                                            contentPadding:
                                                EdgeInsets.symmetric(
                                                  horizontal: 12,
                                                  vertical: 8,
                                                ),
                                            isDense: true,
                                          ),
                                          isExpanded: true,
                                          items: [
                                            const DropdownMenuItem<String>(
                                              value: null,
                                              child: Text(
                                                'All Statuses',
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            ..._getUniqueStatuses().map(
                                              (status) =>
                                                  DropdownMenuItem<String>(
                                                    value: status,
                                                    child: Text(
                                                      status,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                            ),
                                          ],
                                          onChanged: (value) {
                                            setState(() {
                                              _selectedStatus = value;
                                              _currentPage =
                                                  1; // Reset to first page on filter change
                                            });
                                          },
                                        ),
                                      ),

                                      // Start Date Filter
                                      SizedBox(
                                        width: isWide
                                            ? 150
                                            : constraints.maxWidth > 400
                                            ? (constraints.maxWidth - 24) / 2
                                            : constraints.maxWidth - 24,
                                        child: InkWell(
                                          onTap: () async {
                                            final date = await showDatePicker(
                                              context: context,
                                              initialDate:
                                                  _startDate ??
                                                  _reportStartDate ??
                                                  DateTime.now(),
                                              firstDate:
                                                  _reportStartDate ??
                                                  DateTime(2020),
                                              lastDate:
                                                  _reportEndDate ??
                                                  _endDate ??
                                                  DateTime(2100),
                                            );
                                            if (date != null) {
                                              setState(() {
                                                _startDate = date;
                                                _currentPage =
                                                    1; // Reset to first page on filter change
                                              });
                                            }
                                          },
                                          child: InputDecorator(
                                            decoration: const InputDecoration(
                                              labelText: 'Start Date',
                                              border: OutlineInputBorder(),
                                              contentPadding:
                                                  EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 8,
                                                  ),
                                              suffixIcon: Icon(
                                                Icons.calendar_today,
                                                size: 20,
                                              ),
                                              isDense: true,
                                            ),
                                            child: Text(
                                              _startDate != null
                                                  ? '${_startDate!.day}/${_startDate!.month}/${_startDate!.year}'
                                                  : 'Select Date',
                                              style: TextStyle(
                                                color: _startDate != null
                                                    ? null
                                                    : Colors.grey,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ),
                                      ),

                                      // End Date Filter
                                      SizedBox(
                                        width: isWide
                                            ? 150
                                            : constraints.maxWidth > 400
                                            ? (constraints.maxWidth - 24) / 2
                                            : constraints.maxWidth - 24,
                                        child: InkWell(
                                          onTap: () async {
                                            final date = await showDatePicker(
                                              context: context,
                                              initialDate:
                                                  _endDate ??
                                                  _reportEndDate ??
                                                  DateTime.now(),
                                              firstDate:
                                                  _startDate ??
                                                  _reportStartDate ??
                                                  DateTime(2020),
                                              lastDate:
                                                  _reportEndDate ??
                                                  DateTime(2100),
                                            );
                                            if (date != null) {
                                              setState(() {
                                                _endDate = date;
                                                _currentPage =
                                                    1; // Reset to first page on filter change
                                              });
                                            }
                                          },
                                          child: InputDecorator(
                                            decoration: const InputDecoration(
                                              labelText: 'End Date',
                                              border: OutlineInputBorder(),
                                              contentPadding:
                                                  EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 8,
                                                  ),
                                              suffixIcon: Icon(
                                                Icons.calendar_today,
                                                size: 20,
                                              ),
                                              isDense: true,
                                            ),
                                            child: Text(
                                              _endDate != null
                                                  ? '${_endDate!.day}/${_endDate!.month}/${_endDate!.year}'
                                                  : 'Select Date',
                                              style: TextStyle(
                                                color: _endDate != null
                                                    ? null
                                                    : Colors.grey,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ),
                                      ),

                                      // Clear Filters Button
                                      SizedBox(
                                        width: isWide
                                            ? null
                                            : constraints.maxWidth - 24,
                                        child: ElevatedButton.icon(
                                          onPressed: () {
                                            setState(() {
                                              _selectedEmployee = null;
                                              _selectedStatus = null;
                                              _startDate = null;
                                              _endDate = null;
                                              _currentPage =
                                                  1; // Reset to first page
                                            });
                                          },
                                          icon: const Icon(
                                            Icons.clear,
                                            size: 18,
                                          ),
                                          label: const Text('Clear'),
                                          style: ElevatedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 12,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],

                    Card(
                      elevation: 2,
                      child: Column(
                        children: [
                          _buildGroupedReportDetails(),
                          _buildPaginationControls(),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  List<dynamic> _getFilteredDetails() {
    // CRITICAL FIX: Handle null or non-List details safely
    if (_reportData == null || !_reportData!.containsKey('details')) {
      return [];
    }

    final detailsValue = _reportData!['details'];
    if (detailsValue == null) {
      return [];
    }

    // Ensure details is a List
    List<dynamic> details;
    if (detailsValue is List) {
      details = detailsValue;
    } else {
      Logger.warning(
        '[ReportViewer] ⚠️ Warning: details is not a List, type: ${detailsValue.runtimeType}',
      );
      return [];
    }

    if (details.isEmpty) return [];

    List<dynamic> filtered = List.from(details);

    // Apply employee filter
    if (_selectedEmployee != null) {
      filtered = filtered.where((detail) {
        final employeeName = detail['employeeName'] ?? 'Unknown Employee';
        return employeeName == _selectedEmployee;
      }).toList();
    }

    // Apply status filter
    if (_selectedStatus != null) {
      filtered = filtered.where((detail) {
        final status = detail['status'] ?? 'No Records';
        return status == _selectedStatus;
      }).toList();
    }

    // Apply date range filter
    if (_startDate != null) {
      filtered = filtered.where((detail) {
        try {
          final dateStr = detail['date'] ?? '';
          if (dateStr.isEmpty) return false;
          final recordDate = DateTime.parse(dateStr);
          return recordDate.isAfter(
            _startDate!.subtract(const Duration(days: 1)),
          );
        } catch (e) {
          return false;
        }
      }).toList();
    }

    if (_endDate != null) {
      filtered = filtered.where((detail) {
        try {
          final dateStr = detail['date'] ?? '';
          if (dateStr.isEmpty) return false;
          final recordDate = DateTime.parse(dateStr);
          final endDateWithTime = DateTime(
            _endDate!.year,
            _endDate!.month,
            _endDate!.day,
            23,
            59,
            59,
          );
          return recordDate.isBefore(endDateWithTime) ||
              recordDate.isAtSameMomentAs(endDateWithTime);
        } catch (e) {
          return false;
        }
      }).toList();
    }

    return filtered;
  }

  int _getFilteredDetailsCount() {
    return _getFilteredDetails().length;
  }

  String _getPaginatedRange() {
    final filteredDetails = _getFilteredDetails();
    final totalItems = filteredDetails.length;
    if (totalItems == 0) return '0-0';

    final startIndex = (_currentPage - 1) * _itemsPerPage;
    final endIndex = (startIndex + _itemsPerPage).clamp(0, totalItems);
    return '${startIndex + 1}-$endIndex';
  }

  List<String> _getUniqueEmployees() {
    final details = _getFilteredDetails(); // Use the safe method
    final employees = <String>{};
    for (final detail in details) {
      if (detail is Map) {
        final employeeName = detail['employeeName'] ?? 'Unknown Employee';
        employees.add(employeeName);
      }
    }
    return employees.toList()..sort();
  }

  List<String> _getUniqueStatuses() {
    final details = _getFilteredDetails(); // Use the safe method
    final statuses = <String>{};
    for (final detail in details) {
      if (detail is Map) {
        final status = detail['status'] ?? 'No Records';
        statuses.add(status);
      }
    }
    return statuses.toList()..sort();
  }

  Widget _buildGroupedReportDetails() {
    final filteredDetails = _getFilteredDetails();

    if (filteredDetails.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          _reportData!['details'] != null &&
                  _reportData!['details'] is List &&
                  (_reportData!['details'] as List).isNotEmpty
              ? 'No records match the selected filters'
              : 'No details available',
        ),
      );
    }

    // Group filtered details by employee
    final Map<String, List<dynamic>> employeeGroups = {};
    for (final detail in filteredDetails) {
      final employeeName = detail['employeeName'] ?? 'Unknown Employee';
      if (!employeeGroups.containsKey(employeeName)) {
        employeeGroups[employeeName] = [];
      }
      employeeGroups[employeeName]!.add(detail);
    }

    // Sort each employee's days by date
    for (final employeeName in employeeGroups.keys) {
      employeeGroups[employeeName]!.sort((a, b) {
        final dateA = a['date'] ?? '';
        final dateB = b['date'] ?? '';
        return dateA.compareTo(dateB);
      });
    }

    // Flatten all details for pagination (maintaining employee grouping)
    final List<Map<String, dynamic>> allDetailsWithEmployee = [];
    final employeeNames = employeeGroups.keys.toList()..sort();

    for (final employeeName in employeeNames) {
      final employeeDetails = employeeGroups[employeeName]!;
      for (final detail in employeeDetails) {
        allDetailsWithEmployee.add({
          'employeeName': employeeName,
          'detail': detail,
        });
      }
    }

    // Calculate pagination
    final totalItems = allDetailsWithEmployee.length;
    (totalItems / _itemsPerPage).ceil();
    final startIndex = (_currentPage - 1) * _itemsPerPage;
    final endIndex = (startIndex + _itemsPerPage).clamp(0, totalItems);
    final paginatedItems = allDetailsWithEmployee.sublist(startIndex, endIndex);

    // Group paginated items by employee
    final Map<String, List<dynamic>> paginatedGroups = {};
    for (final item in paginatedItems) {
      final employeeName = item['employeeName'] as String;
      if (!paginatedGroups.containsKey(employeeName)) {
        paginatedGroups[employeeName] = [];
      }
      paginatedGroups[employeeName]!.add(item['detail']);
    }

    // Build the grouped display
    final List<Widget> widgets = [];
    final paginatedEmployeeNames = paginatedGroups.keys.toList()..sort();

    for (int i = 0; i < paginatedEmployeeNames.length; i++) {
      final employeeName = paginatedEmployeeNames[i];
      final employeeDetails = paginatedGroups[employeeName]!;

      // Add employee header
      widgets.add(
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            border: Border(bottom: BorderSide(color: Colors.blue.shade200)),
          ),
          child: Text(
            employeeName,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
      );

      // Add all days for this employee
      for (final detail in employeeDetails) {
        widgets.add(_buildDayDetail(detail));
      }

      // Add gap between employees (except for the last one)
      if (i < paginatedEmployeeNames.length - 1) {
        widgets.add(
          Container(
            height: 20,
            color: Colors.grey.shade100,
            child: const Center(
              child: Text(
                '• • •',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        );
      }
    }

    return Column(children: widgets);
  }

  Widget _buildPaginationControls() {
    final filteredDetails = _getFilteredDetails();
    final totalItems = filteredDetails.length;
    final totalPages = (totalItems / _itemsPerPage).ceil();

    if (totalPages <= 1) {
      return const SizedBox.shrink();
    }

    final startIndex = (_currentPage - 1) * _itemsPerPage;
    final endIndex = (startIndex + _itemsPerPage).clamp(0, totalItems);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Showing ${startIndex + 1}-$endIndex of $totalItems records',
            style: const TextStyle(fontSize: 14, color: Colors.grey),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: _currentPage > 1
                    ? () {
                        setState(() {
                          _currentPage--;
                        });
                      }
                    : null,
                tooltip: 'Previous Page',
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Page $_currentPage of $totalPages',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: _currentPage < totalPages
                    ? () {
                        setState(() {
                          _currentPage++;
                        });
                      }
                    : null,
                tooltip: 'Next Page',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDayDetail(Map<String, dynamic> detail) {
    final isNoRecords =
        detail['checkInTime'] == 'No Records' ||
        detail['status'] == 'No Attendance';
    // Handle both ISO format (YYYY-MM-DD) and display format (DD MMM YYYY)
    String date = detail['dateDisplay'] ?? detail['date'] ?? 'N/A';
    // If date is in ISO format (YYYY-MM-DD), format it for display
    if (date.contains('-') &&
        date.length == 10 &&
        date.split('-').length == 3) {
      try {
        final dateParts = date.split('-');
        final year = dateParts[0];
        final month = int.parse(dateParts[1]);
        final day = dateParts[2];
        final monthNames = [
          'Jan',
          'Feb',
          'Mar',
          'Apr',
          'May',
          'Jun',
          'Jul',
          'Aug',
          'Sep',
          'Oct',
          'Nov',
          'Dec',
        ];
        date = '$day ${monthNames[month - 1]} $year';
      } catch (e) {
        // If parsing fails, use original date
      }
    }
    final dayName = _getDayName(detail['date'] ?? date);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
      child: Card(
        elevation: 1,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Date and day name
              Row(
                children: [
                  Text(
                    'Date: $date',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      dayName,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Status and details
              if (isNoRecords)
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning, color: Colors.orange, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'No attendance records found',
                          style: TextStyle(
                            color: Colors.orange.shade700,
                            fontStyle: FontStyle.italic,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else if (widget.report['reportType'] == 'leave') ...[
                // Leave report details
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _getStatusColor(
                      detail['status'],
                    ).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: _getStatusColor(
                        detail['status'],
                      ).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            detail['isHalfDay'] == true
                                ? Icons.schedule
                                : Icons.event_available,
                            color: _getStatusColor(detail['status']),
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              detail['status'] ?? 'Unknown',
                              style: TextStyle(
                                color: _getStatusColor(detail['status']),
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (detail['leaveType'] != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Type: ${detail['leaveType']}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                      if (detail['leaveReason'] != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Reason: ${detail['leaveReason']}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                      if (detail['isHalfDay'] == true &&
                          detail['halfDayLeaveTime'] != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Leave Time: ${detail['halfDayLeaveTime']}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.blue,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ] else ...[
                // Check-in/Check-out times
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Check-in: ${detail['checkInTime'] ?? 'N/A'}',
                        style: const TextStyle(fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Check-out: ${detail['checkOutTime'] ?? 'N/A'}',
                        style: const TextStyle(fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                // Work hours breakdown
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Work: ${_formatWorkHours(detail['workHours'])}h',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.green,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    if (detail['breakHours'] != null)
                      Expanded(
                        child: Text(
                          'Break: ${detail['breakHours']}h',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.orange,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    if (detail['netWorkHours'] != null)
                      Expanded(
                        child: Text(
                          'Net: ${detail['netWorkHours']}h',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.blue,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                  ],
                ),
                // Status
                const SizedBox(height: 4),
                Text(
                  'Status: ${detail['status'] ?? 'N/A'}',
                  style: TextStyle(
                    fontSize: 12,
                    color: _getStatusColor(detail['status']),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _getDayName(String dateStr) {
    try {
      // Handle ISO format (YYYY-MM-DD) or other formats
      String dateToParse = dateStr;

      // If it's already in ISO format (YYYY-MM-DD), append time
      if (dateStr.contains('-') &&
          dateStr.length == 10 &&
          dateStr.split('-').length == 3) {
        // Already in ISO format, just append time
        dateToParse = '${dateStr}T00:00:00Z';
      } else {
        // Try to parse other formats (e.g., "01 Dec 2025")
        // Replace spaces with dashes and try to parse
        dateToParse = dateStr.replaceAll(' ', '-');
        // Try to parse as-is first
        try {
          final testDate = DateTime.parse(dateToParse);
          dateToParse = '${testDate.toIso8601String().split('T')[0]}T00:00:00Z';
        } catch (e) {
          // If that fails, try appending time
          dateToParse = '${dateStr}T00:00:00Z';
        }
      }

      final date = DateTime.parse(dateToParse);
      // Use direct day calculation instead of TimeUtils to avoid timezone conversion
      const dayNames = [
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday',
      ];
      final dayOfWeek = date.weekday; // weekday is 1-7 (Monday-Sunday)
      return dayNames[dayOfWeek - 1]; // Convert to 0-based index
    } catch (e) {
      Logger.error('Error parsing date for day name: $dateStr, error: $e');
      return 'Unknown';
    }
  }

  String _formatWorkHours(dynamic workHours) {
    if (workHours == null) return '0';
    try {
      final hours = workHours is num
          ? workHours.toDouble()
          : double.tryParse(workHours.toString()) ?? 0.0;
      // Round to 2 decimal places
      return hours.toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '');
    } catch (e) {
      return '0';
    }
  }

  Color _getStatusColor(String? status) {
    final theme = Theme.of(context);
    final chartColors = ThemeUtils.getSafeChartColors(theme);

    switch (status?.toLowerCase()) {
      case 'present':
        return ThemeUtils.getStatusChipColor('success', theme);
      case 'absent':
        return ThemeUtils.getStatusChipColor('error', theme);
      case 'holiday':
        return chartColors[4]; // Purple
      case 'on leave':
      case 'leave (unpaid leave)':
      case 'leave (casual leave)':
      case 'leave (annual leave)':
      case 'leave (sick leave)':
      case 'leave (maternity leave)':
      case 'leave (paternity leave)':
      case 'leave (emergency leave)':
        return ThemeUtils.getStatusChipColor('warning', theme);
      case 'half day leave':
        return chartColors[2]; // Orange/Amber
      case 'approved':
        return ThemeUtils.getStatusChipColor('success', theme);
      case 'pending':
        return ThemeUtils.getStatusChipColor('warning', theme);
      case 'rejected':
        return ThemeUtils.getStatusChipColor('error', theme);
      case 'no records':
        return theme.colorScheme.onSurface.withValues(alpha: 0.5);
      default:
        return theme.colorScheme.onSurface;
    }
  }
}

class _CreateScheduledReportDialog extends StatefulWidget {
  final Function(Map<String, dynamic>) onSave;
  final List<String> availableReportTypes;
  final List<Map<String, dynamic>> employees;
  final Map<String, dynamic>? existingReport;

  const _CreateScheduledReportDialog({
    required this.onSave,
    required this.availableReportTypes,
    required this.employees,
    this.existingReport,
  });

  @override
  State<_CreateScheduledReportDialog> createState() =>
      _CreateScheduledReportDialogState();
}

class _CreateScheduledReportDialogState
    extends State<_CreateScheduledReportDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  String _selectedReportType = '';
  String _selectedScheduleType = 'daily';
  String _selectedFormat = 'pdf';
  String _selectedLayout = 'detailed'; // 'detailed' or 'pivot'
  String? _selectedEmployeeId;
  TimeOfDay _selectedTime = const TimeOfDay(hour: 9, minute: 0);
  int _selectedDay = 1; // For weekly (1=Monday) and monthly (1-31)
  bool _emailDelivery = false;
  String _emailRecipients = '';

  // NEW: Timezone settings
  String _timezoneSource = 'company'; // 'company', 'user', 'custom'
  String? _selectedTimezone;

  DateTime _startDate = DateTime.now();
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();

    if (widget.existingReport != null) {
      // Initialize with existing report data
      _nameController.text = widget.existingReport!['name'] ?? '';
      _descriptionController.text = widget.existingReport!['description'] ?? '';
      _selectedReportType = widget.existingReport!['reportType'] ?? '';
      _selectedFormat =
          widget.existingReport!['output']?['formats']?[0] ?? 'pdf';
      _selectedEmployeeId = widget.existingReport!['parameters']?['employeeId'];
      _selectedLayout =
          widget.existingReport!['parameters']?['layout'] ?? 'detailed';

      // Parse schedule data
      final schedule = widget.existingReport!['schedule'] ?? {};
      _selectedScheduleType = schedule['type'] ?? 'daily';

      // Parse time
      final timeStr = schedule['dailyTime'] ?? '09:00';
      final timeParts = timeStr.split(':');
      if (timeParts.length >= 2) {
        _selectedTime = TimeOfDay(
          hour: int.tryParse(timeParts[0]) ?? 9,
          minute: int.tryParse(timeParts[1]) ?? 0,
        );
      }

      // Parse day for weekly/monthly
      if (schedule['weeklyDay'] != null) {
        _selectedDay = schedule['weeklyDay'];
      } else if (schedule['monthlyDay'] != null) {
        _selectedDay = schedule['monthlyDay'];
      }

      // Parse email delivery
      final emailDelivery =
          widget.existingReport!['output']?['emailDelivery'] ?? {};
      _emailDelivery = emailDelivery['enabled'] ?? false;
      _emailRecipients =
          (emailDelivery['recipients'] as List?)?.join(', ') ?? '';

      // Parse date range
      final params = widget.existingReport!['parameters'] ?? {};
      if (params['startDate'] != null) {
        _startDate = DateTime.tryParse(params['startDate']) ?? DateTime.now();
      }
      if (params['endDate'] != null) {
        _endDate = DateTime.tryParse(params['endDate']);
      }
    } else {
      // Initialize with defaults for new report
      if (widget.availableReportTypes.isNotEmpty) {
        _selectedReportType = widget.availableReportTypes.first;
      } else {
        // Fallback to basic report types if none are available
        _selectedReportType = 'timesheet';
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: BoxConstraints(
          maxWidth: 600,
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      Icon(
                        Icons.schedule,
                        color: colorScheme.primary,
                        size: 28,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          widget.existingReport != null
                              ? 'Edit Scheduled Report'
                              : 'Create Scheduled Report',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Report Name
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Report Name *',
                      hintText: 'e.g., Daily Attendance Report',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a report name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 6),

                  // Description
                  TextFormField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      hintText:
                          'Optional description for this scheduled report',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 1,
                  ),
                  const SizedBox(height: 6),

                  // Report Type
                  DropdownButtonFormField<String>(
                    initialValue: _selectedReportType.isNotEmpty
                        ? _selectedReportType
                        : null,
                    decoration: const InputDecoration(
                      labelText: 'Report Type *',
                      border: OutlineInputBorder(),
                    ),
                    items:
                        (widget.availableReportTypes.isNotEmpty
                                ? widget.availableReportTypes
                                : ['timesheet', 'leave'])
                            .map((type) {
                              return DropdownMenuItem(
                                value: type,
                                child: Text(_getReportTypeDisplayName(type)),
                              );
                            })
                            .toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedReportType = value ?? '';
                      });
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please select a report type';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 6),

                  // Employee Selection
                  DropdownButtonFormField<String>(
                    initialValue: _selectedEmployeeId,
                    decoration: const InputDecoration(
                      labelText: 'Employee (Optional)',
                      hintText: 'Leave empty for all employees',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text(
                          'All Employees',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      ...widget.employees.map((emp) {
                        return DropdownMenuItem(
                          value:
                              emp['userId']?.toString() ??
                              emp['_id']?.toString(),
                          child: Text(emp['name'] ?? 'Unknown Employee'),
                        );
                      }),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedEmployeeId = value;
                      });
                    },
                  ),
                  const SizedBox(height: 6),

                  // Schedule Type
                  DropdownButtonFormField<String>(
                    initialValue: _selectedScheduleType,
                    decoration: const InputDecoration(
                      labelText: 'Schedule Type *',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'daily', child: Text('Daily')),
                      DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                      DropdownMenuItem(
                        value: 'monthly',
                        child: Text('Monthly'),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedScheduleType = value ?? 'daily';
                      });
                    },
                  ),
                  const SizedBox(height: 6),

                  // Schedule Details
                  if (_selectedScheduleType == 'daily') ...[
                    _buildTimeSelector(),
                  ] else if (_selectedScheduleType == 'weekly') ...[
                    _buildDaySelector(),
                    const SizedBox(height: 6),
                    _buildTimeSelector(),
                  ] else if (_selectedScheduleType == 'monthly') ...[
                    _buildMonthlyDaySelector(),
                    const SizedBox(height: 6),
                    _buildTimeSelector(),
                  ],
                  const SizedBox(height: 6),

                  // Date Range
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: _selectStartDate,
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Start Date *',
                              border: OutlineInputBorder(),
                            ),
                            child: Text(
                              '${_startDate.year}-${_startDate.month.toString().padLeft(2, '0')}-${_startDate.day.toString().padLeft(2, '0')}',
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: InkWell(
                          onTap: _selectEndDate,
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'End Date (Optional)',
                              border: OutlineInputBorder(),
                            ),
                            child: Text(
                              _endDate != null
                                  ? '${_endDate!.year}-${_endDate!.month.toString().padLeft(2, '0')}-${_endDate!.day.toString().padLeft(2, '0')}'
                                  : 'No end date',
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Timezone Settings
                  Card(
                    color: Colors.blue[50],
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Timezone Settings',
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue[700],
                                ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Choose which timezone to use for scheduling this report.',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          const SizedBox(height: 12),

                          // Timezone Source
                          DropdownButtonFormField<String>(
                            initialValue: _timezoneSource,
                            decoration: const InputDecoration(
                              labelText: 'Timezone Source',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'company',
                                child: Text('Company Timezone'),
                              ),
                              DropdownMenuItem(
                                value: 'user',
                                child: Text('My Timezone'),
                              ),
                              DropdownMenuItem(
                                value: 'custom',
                                child: Text('Custom Timezone'),
                              ),
                            ],
                            onChanged: (value) {
                              setState(() {
                                _timezoneSource = value ?? 'company';
                                if (_timezoneSource != 'custom') {
                                  _selectedTimezone = null;
                                }
                              });
                            },
                          ),

                          if (_timezoneSource == 'custom') ...[
                            const SizedBox(height: 8),
                            TimezoneSelector(
                              selectedTimezone: _selectedTimezone,
                              onTimezoneChanged: (timezone) {
                                setState(() {
                                  _selectedTimezone = timezone;
                                });
                              },
                              label: 'Select Timezone',
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Output Format
                  DropdownButtonFormField<String>(
                    initialValue: _selectedFormat,
                    decoration: const InputDecoration(
                      labelText: 'Output Format *',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'pdf', child: Text('PDF')),
                      DropdownMenuItem(value: 'excel', child: Text('Excel')),
                      DropdownMenuItem(value: 'csv', child: Text('CSV')),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedFormat = value ?? 'pdf';
                        // If PDF is selected and pivot is currently selected, switch to detailed
                        if (value == 'pdf' && _selectedLayout == 'pivot') {
                          _selectedLayout = 'detailed';
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 6),

                  // Report Layout Selection
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Report Layout',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: RadioListTile<String>(
                              title: const Text('Detailed Format'),
                              subtitle: const Text(
                                'Traditional format with each day as a separate row',
                              ),
                              value: 'detailed',
                              // ignore: deprecated_member_use
                              groupValue: _selectedLayout,
                              // ignore: deprecated_member_use
                              onChanged: (value) {
                                setState(() {
                                  _selectedLayout = value!;
                                });
                              },
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: RadioListTile<String>(
                              title: const Text('Pivot Format'),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _getPivotFormatDescription(
                                      _selectedReportType,
                                    ),
                                  ),
                                  if (_selectedFormat == 'pdf' &&
                                      _selectedReportType != 'leave')
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4.0),
                                      child: Text(
                                        '⚠️ Not suitable for PDF exports. Detailed format will be used automatically.',
                                        style: TextStyle(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.error,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              value: 'pivot',
                              groupValue: _selectedLayout,
                              onChanged:
                                  (!_supportsPivotFormat(_selectedReportType) ||
                                      _selectedFormat == 'pdf')
                                  ? null
                                  : (value) {
                                      setState(() {
                                        _selectedLayout = value!;
                                      });
                                    },
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Email Delivery
                  CheckboxListTile(
                    title: const Text('Email Delivery'),
                    subtitle: const Text(
                      'Send report via email when generated',
                    ),
                    value: _emailDelivery,
                    onChanged: (value) {
                      setState(() {
                        _emailDelivery = value ?? false;
                      });
                    },
                    controlAffinity: ListTileControlAffinity.leading,
                  ),

                  if (_emailDelivery) ...[
                    const SizedBox(height: 6),
                    TextFormField(
                      initialValue: _emailRecipients,
                      decoration: const InputDecoration(
                        labelText: 'Email Recipients',
                        hintText: 'comma-separated email addresses',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        _emailRecipients = value;
                      },
                    ),
                  ],
                  const SizedBox(height: 10),

                  // Action Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton(
                        onPressed: _saveReport,
                        child: Text(
                          widget.existingReport != null
                              ? 'Update Schedule'
                              : 'Create Schedule',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTimeSelector() {
    return InkWell(
      onTap: _selectTime,
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Time *',
          border: OutlineInputBorder(),
        ),
        child: Text(_selectedTime.format(context)),
      ),
    );
  }

  Widget _buildDaySelector() {
    return DropdownButtonFormField<int>(
      initialValue: _selectedDay,
      decoration: const InputDecoration(
        labelText: 'Day of Week *',
        border: OutlineInputBorder(),
      ),
      items: const [
        DropdownMenuItem(value: 1, child: Text('Monday')),
        DropdownMenuItem(value: 2, child: Text('Tuesday')),
        DropdownMenuItem(value: 3, child: Text('Wednesday')),
        DropdownMenuItem(value: 4, child: Text('Thursday')),
        DropdownMenuItem(value: 5, child: Text('Friday')),
        DropdownMenuItem(value: 6, child: Text('Saturday')),
        DropdownMenuItem(value: 0, child: Text('Sunday')),
      ],
      onChanged: (value) {
        setState(() {
          _selectedDay = value ?? 1;
        });
      },
    );
  }

  Widget _buildMonthlyDaySelector() {
    return DropdownButtonFormField<int>(
      initialValue: _selectedDay,
      decoration: const InputDecoration(
        labelText: 'Day of Month *',
        border: OutlineInputBorder(),
      ),
      items: List.generate(31, (index) {
        final day = index + 1;
        return DropdownMenuItem(value: day, child: Text('$day'));
      }),
      onChanged: (value) {
        setState(() {
          _selectedDay = value ?? 1;
        });
      },
    );
  }

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  Future<void> _selectStartDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020), // Allow past dates for historical reports
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked;
        if (_endDate != null && _endDate!.isBefore(picked)) {
          _endDate = null;
        }
      });
    }
  }

  Future<void> _selectEndDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? _startDate.add(const Duration(days: 30)),
      firstDate: _startDate,
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _endDate = picked;
      });
    }
  }

  String _getReportTypeDisplayName(String type) {
    switch (type.toLowerCase()) {
      case 'attendance':
        // Map attendance to timesheet since they're unified
        return 'Timesheet Report';
      case 'leave':
        return 'Leave Report';
      case 'timesheet':
        return 'Timesheet Report';
      case 'payroll':
        return 'Payroll Report';
      case 'performance':
        return 'Performance Report';
      default:
        return type.toUpperCase();
    }
  }

  void _saveReport() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final reportData = {
      if (widget.existingReport != null) '_id': widget.existingReport!['_id'],
      'name': _nameController.text.trim(),
      'description': _descriptionController.text.trim(),
      'reportType': _selectedReportType,
      'parameters': {
        'startDate':
            '${_startDate.year}-${_startDate.month.toString().padLeft(2, '0')}-${_startDate.day.toString().padLeft(2, '0')}',
        'endDate': _endDate != null
            ? '${_endDate!.year}-${_endDate!.month.toString().padLeft(2, '0')}-${_endDate!.day.toString().padLeft(2, '0')}'
            : null,
        'employeeId': _selectedEmployeeId,
        'format': _selectedFormat,
        'layout': _selectedLayout,
      },
      'schedule': {
        'type': _selectedScheduleType,
        'dailyTime':
            '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}',
        'timezoneSource': _timezoneSource,
        'timezone': _timezoneSource == 'custom' ? _selectedTimezone : null,
        if (_selectedScheduleType == 'weekly') 'weeklyDay': _selectedDay,
        if (_selectedScheduleType == 'monthly') 'monthlyDay': _selectedDay,
      },
      'output': {
        'formats': [_selectedFormat],
        'emailDelivery': {
          'enabled': _emailDelivery,
          if (_emailDelivery && _emailRecipients.isNotEmpty)
            'recipients': _emailRecipients
                .split(',')
                .map((e) => e.trim())
                .toList(),
        },
      },
      'status': 'active',
    };

    widget.onSave(reportData);
    Navigator.of(context).pop();
  }

  // Check if a report type supports pivot format
  bool _supportsPivotFormat(String reportType) {
    final type = reportType.toLowerCase();
    // Only attendance and timesheet support pivot format
    return type == 'attendance' || type == 'timesheet';
  }

  // Get description text for pivot format based on report type
  String _getPivotFormatDescription(String reportType) {
    if (!_supportsPivotFormat(reportType)) {
      if (reportType.toLowerCase() == 'leave') {
        return 'Not available for Leave Management reports';
      } else {
        return 'Only available for Attendance/Timesheet reports';
      }
    }
    return 'Compact format with employees as rows, dates as columns';
  }
}
