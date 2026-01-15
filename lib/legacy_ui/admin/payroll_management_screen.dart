import 'package:flutter/material.dart';
// import 'package:intl/intl.dart'; // removed: unused
import 'package:provider/provider.dart';
import '../../providers/admin_payroll_provider.dart';
import '../../providers/auth_provider.dart';
import 'edit_payslip_dialog.dart';
import '../../widgets/admin_side_navigation.dart';
import '../../widgets/shared_app_bar.dart';
// Coach features disabled for this company
// import 'payroll_management_with_coach.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../config/api_config.dart';
import 'dart:io';
import '../../providers/payroll_cycle_settings_provider.dart';
import '../../utils/payroll_cycle_utils.dart';
import '../../theme/app_theme.dart';
import '../../utils/time_utils.dart';
import '../../services/global_notification_service.dart';

class PayrollManagementScreen extends StatefulWidget {
  const PayrollManagementScreen({super.key});

  @override
  State<PayrollManagementScreen> createState() =>
      _PayrollManagementScreenState();
}

class _PayrollManagementScreenState extends State<PayrollManagementScreen> {
  String? _selectedEmployeeId;
  bool _showEmployeeList =
      true; // Toggle between employee list and payslip history

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AdminPayrollProvider>(
        context,
        listen: false,
      ).fetchEmployees();
    });
  }

  void _onEmployeeChanged(String? employeeId) {
    if (employeeId == null) return;
    setState(() {
      _selectedEmployeeId = employeeId;
      _showEmployeeList = false; // Show payslip history when employee selected
    });
    Provider.of<AdminPayrollProvider>(
      context,
      listen: false,
    ).fetchPayslips(employeeId);
  }

  void _goBackToEmployeeList() {
    setState(() {
      _showEmployeeList = true;
      _selectedEmployeeId = null;
    });
  }

  Future<void> _addPayslip(
    BuildContext context,
    AdminPayrollProvider provider,
  ) async {
    final cycleProvider = Provider.of<PayrollCycleSettingsProvider>(
      context,
      listen: false,
    );

    final Map<String, dynamic>? cycle = cycleProvider.settings;

    final now = DateTime.now();
    late DateTime start;
    late DateTime end;

    if (cycle != null) {
      final period = PayrollCycleUtils.currentPeriod(cycle, reference: now);
      start = period['start']!;
      end = period['end']!;
    } else {
      // fallback to full month
      start = DateTime(now.year, now.month, 1);
      end = DateTime(now.year, now.month + 1, 0);
    }

    String payPeriodLabel;
    if ((cycle?['frequency'] ?? 'Monthly') == 'Weekly') {
      payPeriodLabel =
          '${TimeUtils.formatReadableDate(start).substring(0, 6)} - ${TimeUtils.formatReadableDate(end).substring(0, 6)}';
    } else {
      payPeriodLabel = TimeUtils.formatReadableDate(start).substring(0, 7);
    }

    final initial = {
      'payPeriod': payPeriodLabel,
      'periodStart': start.toIso8601String(),
      'periodEnd': end.toIso8601String(),
      'overtimeMultiplier': cycle?['overtimeMultiplier'] ?? 1.5,
    };

    final newPayslip = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => EditPayslipDialog(
        initialData: initial,
        onSave: (_) {},
        employeeId:
            _selectedEmployeeId, // Pass employee ID for fetching work hours
      ),
    );

    if (!mounted) return; // lint fix: context safety after await

    if (newPayslip != null && _selectedEmployeeId != null) {
      try {
        await provider.addPayslip(newPayslip, _selectedEmployeeId!);
        await provider.fetchPayslips(_selectedEmployeeId!);
        if (!mounted) return;

        if (provider.error != null) {
          GlobalNotificationService().showError('Error: ${provider.error}');
        } else {
          GlobalNotificationService().showSuccess(
            'Payslip added successfully.',
          );
        }
      } catch (e) {
        if (!mounted) return;
        GlobalNotificationService().showError('Error: $e');
      }
    }
  }

  Future<void> _editPayslip(
    BuildContext scaffoldContext,
    AdminPayrollProvider provider,
    int idx,
  ) async {
    final payslip = provider.payslips[idx];
    final updatedPayslip = await showDialog<Map<String, dynamic>>(
      context: scaffoldContext,
      builder: (dialogContext) =>
          EditPayslipDialog(initialData: payslip, onSave: (_) {}),
    );

    if (!mounted || updatedPayslip == null) return;
    try {
      await provider.editPayslip(payslip['_id'], updatedPayslip);
      if (_selectedEmployeeId != null) {
        await provider.fetchPayslips(_selectedEmployeeId!);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(scaffoldContext).showSnackBar(
        const SnackBar(content: Text('Payslip updated successfully.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        scaffoldContext,
      ).showSnackBar(SnackBar(content: Text('Error updating payslip: $e')));
    }
  }

  Future<void> _downloadPayslipPdf(
    BuildContext context,
    String payslipId,
    String token,
  ) async {
    try {
      final url = '${ApiConfig.baseUrl}/payroll/$payslipId/pdf';
      final response = await http.get(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (!mounted) return;

      if (response.statusCode == 200) {
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/payslip-$payslipId.pdf');
        await file.writeAsBytes(response.bodyBytes);

        // Use share intent to let user choose where to save
        await _shareFile(context, file, 'payslip-$payslipId.pdf');
      } else {
        GlobalNotificationService().showError(
          'Failed to download PDF: ${response.statusCode}',
        );
      }
    } catch (e) {
      if (!mounted) return;
      GlobalNotificationService().showError('Error downloading PDF: $e');
    }
  }

  Future<void> _downloadAllPayslips(
    BuildContext context,
    String employeeId,
    String token, {
    bool asCsv = false,
    String? queryString,
  }) async {
    try {
      final base = asCsv
          ? '${ApiConfig.baseUrl}/payroll/employee/$employeeId/csv'
          : '${ApiConfig.baseUrl}/payroll/employee/$employeeId/pdf';
      final url = queryString == null || queryString.isEmpty
          ? base
          : '$base?$queryString';

      final response = await http.get(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        // Use share intent approach (Google Play compliant)
        final tempDir = await getTemporaryDirectory();
        final ext = asCsv ? 'csv' : 'pdf';
        final file = File('${tempDir.path}/all-payslips-$employeeId.$ext');
        await file.writeAsBytes(response.bodyBytes);

        // Use share intent to let user choose where to save
        await _shareFile(context, file, 'all-payslips-$employeeId.$ext');
      } else {
        GlobalNotificationService().showError(
          'Failed to download: ${response.statusCode}',
        );
      }
    } catch (e) {
      if (!mounted) return;
      GlobalNotificationService().showError('Error downloading: $e');
    }
  }

  Widget _buildStatusIndicator(String? status, String? comment) {
    if (status == 'approved' || status == 'acknowledged') {
      return Row(
        children: [
          Icon(Icons.check_circle, color: AppTheme.success, size: 22),
          SizedBox(width: AppTheme.spacingXs),
          Text(
            'Acknowledged',
            style: TextStyle(
              color: AppTheme.success,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      );
    } else if (status == 'needs_review') {
      return Row(
        children: [
          Icon(Icons.error, color: AppTheme.error, size: 22),
          SizedBox(width: AppTheme.spacingXs),
          Text(
            'Needs Review',
            style: TextStyle(
              color: AppTheme.error,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      );
    } else {
      return Row(
        children: [
          Icon(Icons.access_time, color: AppTheme.warning, size: 22),
          SizedBox(width: AppTheme.spacingXs),
          Text(
            'Pending',
            style: TextStyle(
              color: AppTheme.warning,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scaffoldContext = context;

    return Consumer<AdminPayrollProvider>(
      builder: (context, provider, child) {
        final employees = provider.employees;
        final payslips = provider.payslips;
        final isLoading = provider.isLoading;
        final error = provider.error;

        return Scaffold(
          appBar: SharedAppBar(
            title: 'Payroll Management',
            leading: _showEmployeeList
                ? null
                : IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: _goBackToEmployeeList,
                  ),
            automaticallyImplyLeading: _showEmployeeList,
          ),
          drawer: const AdminSideNavigation(
            currentRoute: '/payroll_management',
          ),
          body: _showEmployeeList
              ? _buildEmployeeListView(employees, isLoading, provider)
              : _buildPayslipHistoryView(
                  provider,
                  payslips,
                  isLoading,
                  error,
                  theme,
                  scaffoldContext,
                ),
        );
      },
    );
  }

  // Build employee list view
  Widget _buildEmployeeListView(
    List<Map<String, dynamic>> employees,
    bool isLoading,
    AdminPayrollProvider provider,
  ) {
    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacingL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stats section
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Total',
                  '${employees.length}',
                  Icons.people,
                ),
              ),
              const SizedBox(width: AppTheme.spacingM),
              Expanded(
                child: _buildStatCard(
                  'Active',
                  '${employees.where((e) => e['isActive'] != false).length}',
                  Icons.check_circle,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingL),
          const Text(
            'Select Employee:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: AppTheme.spacingM),
          // Employee list
          Expanded(
            child: isLoading && employees.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : employees.isEmpty
                ? _buildEmptyState(
                    'No Employees',
                    'No employees found',
                    Icons.people_outline,
                  )
                : ListView.builder(
                    itemCount: employees.length,
                    itemBuilder: (context, index) {
                      final employee = employees[index];
                      return _buildEmployeeCard(employee, context);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // Build payslip history view
  Widget _buildPayslipHistoryView(
    AdminPayrollProvider provider,
    List<dynamic> payslips,
    bool isLoading,
    String? error,
    ThemeData theme,
    BuildContext scaffoldContext,
  ) {
    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacingL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_selectedEmployeeId != null)
            Padding(
              padding: const EdgeInsets.only(
                top: AppTheme.spacingM,
                bottom: AppTheme.spacingS,
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: isLoading
                          ? null
                          : () async {
                              final authProvider = Provider.of<AuthProvider>(
                                context,
                                listen: false,
                              );
                              final token = authProvider.token ?? '';
                              await _downloadAllPayslips(
                                context,
                                _selectedEmployeeId!,
                                token,
                                asCsv: false,
                              );
                            },
                      icon: const Icon(Icons.picture_as_pdf),
                      label: const Text('Download All (PDF)'),
                    ),
                    SizedBox(width: AppTheme.spacingM),
                    ElevatedButton.icon(
                      onPressed: isLoading
                          ? null
                          : () async {
                              final authProvider = Provider.of<AuthProvider>(
                                context,
                                listen: false,
                              );
                              final token = authProvider.token ?? '';
                              await _downloadAllPayslips(
                                context,
                                _selectedEmployeeId!,
                                token,
                                asCsv: true,
                              );
                            },
                      icon: const Icon(Icons.table_chart),
                      label: const Text('Download All (CSV)'),
                    ),
                    SizedBox(width: AppTheme.spacingM),
                    ElevatedButton.icon(
                      onPressed: isLoading
                          ? null
                          : () async {
                              final cycleProv =
                                  Provider.of<PayrollCycleSettingsProvider>(
                                    context,
                                    listen: false,
                                  );
                              final cycle = cycleProv.settings;
                              if (cycle == null) {
                                if (!mounted) return;
                                GlobalNotificationService().showWarning(
                                  'Load payroll cycle settings first.',
                                );
                                return;
                              }
                              final period = PayrollCycleUtils.currentPeriod(
                                cycle,
                              );
                              final authProvider = Provider.of<AuthProvider>(
                                context,
                                listen: false,
                              );
                              final token = authProvider.token ?? '';
                              final qs =
                                  'start=${period['start']!.toIso8601String()}&end=${period['end']!.toIso8601String()}';
                              await _downloadAllPayslips(
                                context,
                                _selectedEmployeeId!,
                                token,
                                asCsv: false,
                                queryString: qs,
                              );
                            },
                      icon: const Icon(Icons.picture_as_pdf),
                      label: const Text('Cycle PDF'),
                    ),
                    SizedBox(width: AppTheme.spacingM),
                    ElevatedButton.icon(
                      onPressed: isLoading
                          ? null
                          : () async {
                              final cycleProv =
                                  Provider.of<PayrollCycleSettingsProvider>(
                                    context,
                                    listen: false,
                                  );
                              final cycle = cycleProv.settings;
                              if (cycle == null) {
                                if (!mounted) return;
                                GlobalNotificationService().showWarning(
                                  'Load payroll cycle settings first.',
                                );
                                return;
                              }
                              final period = PayrollCycleUtils.currentPeriod(
                                cycle,
                              );
                              final authProvider = Provider.of<AuthProvider>(
                                context,
                                listen: false,
                              );
                              final token = authProvider.token ?? '';
                              final qs =
                                  'start=${period['start']!.toIso8601String()}&end=${period['end']!.toIso8601String()}';
                              await _downloadAllPayslips(
                                context,
                                _selectedEmployeeId!,
                                token,
                                asCsv: true,
                                queryString: qs,
                              );
                            },
                      icon: const Icon(Icons.table_chart),
                      label: const Text('Cycle CSV'),
                    ),
                  ],
                ),
              ),
            ),
          if (error != null)
            Padding(
              padding: EdgeInsets.only(top: AppTheme.spacingL),
              child: Text(
                'Error: $error',
                style: TextStyle(color: AppTheme.error),
              ),
            ),
          SizedBox(height: AppTheme.spacingXl),
          // Payslip list
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : payslips.isEmpty
                ? Center(
                    child: Text(
                      'No payslips for this employee.',
                      style: theme.textTheme.bodyLarge,
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: () async {
                      if (_selectedEmployeeId != null) {
                        await Provider.of<AdminPayrollProvider>(
                          context,
                          listen: false,
                        ).fetchPayslips(_selectedEmployeeId!);
                      }
                    },
                    child: ListView.builder(
                      itemCount: payslips.length,
                      itemBuilder: (context, idx) {
                        final slip = payslips[idx];
                        // Get employee name if available
                        String empName = '';
                        final emp = slip['employee'];
                        if (emp is Map &&
                            emp['firstName'] != null &&
                            emp['lastName'] != null) {
                          empName = '${emp['firstName']} ${emp['lastName']}';
                        }
                        return Card(
                          margin: EdgeInsets.symmetric(
                            vertical: AppTheme.spacingS,
                          ),
                          elevation: AppTheme.elevationMedium,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusLarge,
                            ),
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(AppTheme.spacingL),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Wrap(
                                  alignment: WrapAlignment.spaceBetween,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  spacing: AppTheme.spacingS,
                                  runSpacing: AppTheme.spacingS,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.calendar_month,
                                          color: theme.colorScheme.primary,
                                          size: 28,
                                        ),
                                        SizedBox(width: AppTheme.spacingS),
                                        Text(
                                          (slip['payPeriod']?.toString()) ??
                                              '-',
                                          style: theme.textTheme.titleMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.bold,
                                              ),
                                        ),
                                      ],
                                    ),
                                    Chip(
                                      label: Text(
                                        'Net Pay: ${slip['netPay'] != null ? (slip['netPay'] is num ? (slip['netPay'] as num).toStringAsFixed(2) : slip['netPay'].toString()) : '-'}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      backgroundColor:
                                          theme.colorScheme.primary,
                                    ),
                                    _buildStatusIndicator(
                                      slip['status']?.toString(),
                                      slip['employeeComment']?.toString(),
                                    ),
                                  ],
                                ),
                                if (empName.isNotEmpty)
                                  Padding(
                                    padding: EdgeInsets.only(
                                      top: AppTheme.spacingXs,
                                    ),
                                    child: Text(
                                      'Employee: $empName',
                                      style: TextStyle(
                                        color: theme.colorScheme.onSurface,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                SizedBox(height: AppTheme.spacingM),
                                Wrap(
                                  spacing: AppTheme.spacingS,
                                  runSpacing: AppTheme.spacingS,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.access_time,
                                          color: theme.colorScheme.primary,
                                          size: 22,
                                        ),
                                        SizedBox(width: AppTheme.spacingXs),
                                        Text(
                                          'Total Hours: ${slip['totalHours'] != null ? (slip['totalHours'] is num ? (slip['totalHours'] as num).toStringAsFixed(1) : slip['totalHours'].toString()) : '-'}',
                                          style: theme.textTheme.bodyMedium,
                                        ),
                                      ],
                                    ),
                                    if (slip['overtimeHours'] != null &&
                                        (slip['overtimeHours'] as num)
                                                .toDouble() >
                                            0)
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.timer,
                                            color: Colors.orange,
                                            size: 22,
                                          ),
                                          SizedBox(width: AppTheme.spacingXs),
                                          Text(
                                            'OT: ${(slip['overtimeHours'] as num).toStringAsFixed(1)}h',
                                            style: theme.textTheme.bodyMedium
                                                ?.copyWith(
                                                  color: Colors.orange,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                          ),
                                        ],
                                      ),
                                  ],
                                ),
                                SizedBox(height: AppTheme.spacingS),
                                Wrap(
                                  spacing: AppTheme.spacingS,
                                  runSpacing: AppTheme.spacingS,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.payments,
                                          color: AppTheme.success,
                                          size: 22,
                                        ),
                                        SizedBox(width: AppTheme.spacingXs),
                                        Text(
                                          'Gross: ${slip['grossPay'] != null ? (slip['grossPay'] is num ? (slip['grossPay'] as num).toStringAsFixed(2) : slip['grossPay'].toString()) : '-'}',
                                          style: theme.textTheme.bodyMedium,
                                        ),
                                      ],
                                    ),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.remove_circle,
                                          color: AppTheme.error,
                                          size: 22,
                                        ),
                                        SizedBox(width: AppTheme.spacingXs),
                                        Text(
                                          'Deductions: -${slip['deductions'] != null ? (slip['deductions'] is num ? (slip['deductions'] as num).toStringAsFixed(2) : slip['deductions'].toString()) : '-'}',
                                          style: theme.textTheme.bodyMedium,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                SizedBox(height: AppTheme.spacingS),
                                Text(
                                  'Issued: ${slip['issueDate'] != null ? TimeUtils.formatReadableDateTime(TimeUtils.parseToLocal(slip['issueDate']), user: Provider.of<AuthProvider>(context, listen: false).user, company: Provider.of<AuthProvider>(context, listen: false).company) : '-'}',
                                  style: theme.textTheme.bodySmall,
                                ),
                                SizedBox(height: AppTheme.spacingL),
                                if ((slip['employeeComment']?.toString() ?? '')
                                    .isNotEmpty)
                                  Padding(
                                    padding: EdgeInsets.only(
                                      top: AppTheme.spacingS,
                                    ),
                                    child: Text(
                                      'Employee Comment: ${slip['employeeComment']}',
                                      style: TextStyle(
                                        color: AppTheme.error,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                if (((slip['status']?.toString() ?? '') ==
                                            'pending' ||
                                        (slip['status']?.toString() ?? '') ==
                                            'needs_review') &&
                                    (slip['adminResponse'] ?? '').isNotEmpty)
                                  Padding(
                                    padding: EdgeInsets.only(
                                      top: AppTheme.spacingS,
                                    ),
                                    child: Text(
                                      'Admin Response: ${slip['adminResponse']}',
                                      style: TextStyle(
                                        color: AppTheme.primary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                Row(
                                  children: [
                                    OutlinedButton.icon(
                                      onPressed: () {
                                        final authProvider =
                                            Provider.of<AuthProvider>(
                                              context,
                                              listen: false,
                                            );
                                        final payslipId = slip['_id'];
                                        final token = authProvider.token ?? '';
                                        if (payslipId == null ||
                                            payslipId.toString().isEmpty) {
                                          GlobalNotificationService().showError(
                                            'Payslip ID is missing. Cannot download PDF.',
                                          );
                                          return;
                                        }
                                        if (token.isEmpty) {
                                          GlobalNotificationService().showError(
                                            'Auth token is missing. Cannot download PDF.',
                                          );
                                          return;
                                        }
                                        _downloadPayslipPdf(
                                          context,
                                          payslipId.toString(),
                                          token,
                                        );
                                      },
                                      icon: const Icon(Icons.download),
                                      label: const Text('Download'),
                                    ),
                                    SizedBox(width: AppTheme.spacingS),
                                    OutlinedButton.icon(
                                      onPressed:
                                          (slip['status']?.toString() ==
                                                  'approved' ||
                                              slip['status']?.toString() ==
                                                  'acknowledged')
                                          ? null
                                          : () => _editPayslip(
                                              scaffoldContext,
                                              provider,
                                              idx,
                                            ),
                                      icon: const Icon(Icons.edit),
                                      label: const Text('Edit'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
          Align(
            alignment: Alignment.bottomRight,
            child: FloatingActionButton.extended(
              onPressed: isLoading || _selectedEmployeeId == null
                  ? null
                  : () => _addPayslip(scaffoldContext, provider),
              icon: const Icon(Icons.add),
              label: const Text('Add Payslip'),
            ),
          ),
        ],
      ),
    );
  }

  // Share file using system share intent (Google Play compliant)
  Future<void> _shareFile(
    BuildContext context,
    File file,
    String fileName,
  ) async {
    try {
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Payslips - $fileName',
        subject: 'Employee Payslips',
      );

      GlobalNotificationService().showSuccess(
        'Share dialog opened for $fileName',
        duration: const Duration(seconds: 2),
      );
    } catch (e) {
      GlobalNotificationService().showError('Error sharing file: $e');
    }
  }

  // Build stat card
  Widget _buildStatCard(String title, String value, IconData icon) {
    final theme = Theme.of(context);
    return Card(
      elevation: AppTheme.elevationMedium,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingL),
        child: Column(
          children: [
            Icon(icon, color: AppTheme.primary, size: 32),
            const SizedBox(height: AppTheme.spacingS),
            Text(
              title,
              style: theme.textTheme.bodySmall?.copyWith(color: AppTheme.muted),
            ),
            const SizedBox(height: AppTheme.spacingXs),
            Text(
              value,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppTheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Build empty state
  Widget _buildEmptyState(String title, String message, IconData icon) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 60, color: AppTheme.primary),
          const SizedBox(height: AppTheme.spacingL),
          Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppTheme.primary,
            ),
          ),
          const SizedBox(height: AppTheme.spacingS),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(color: AppTheme.muted),
          ),
        ],
      ),
    );
  }

  // Build employee card
  Widget _buildEmployeeCard(
    Map<String, dynamic> employee,
    BuildContext context,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final firstName = employee['firstName'] ?? '';
    final lastName = employee['lastName'] ?? '';
    final displayName = '$firstName $lastName'.trim();
    final initials = displayName.isNotEmpty
        ? displayName[0].toUpperCase()
        : '?';
    final isActive = employee['isActive'] != false;
    final department =
        employee['departmentId']?['name'] ?? employee['department'] ?? 'N/A';
    final position =
        employee['designationId']?['title'] ?? employee['position'] ?? 'N/A';

    return Card(
      elevation: AppTheme.elevationHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        onTap: () {
          _onEmployeeChanged(employee['_id'] as String);
        },
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingL),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: colorScheme.primary,
                radius: 28,
                child: Text(
                  initials,
                  style: TextStyle(color: colorScheme.onPrimary, fontSize: 20),
                ),
              ),
              const SizedBox(width: AppTheme.spacingL),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            displayName,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        if (!isActive)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppTheme.spacingS,
                              vertical: AppTheme.spacingXs,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.error.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(
                                AppTheme.radiusMedium,
                              ),
                            ),
                            child: Text(
                              'Inactive',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppTheme.error,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(position, style: theme.textTheme.bodyMedium),
                    Text(
                      department,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppTheme.muted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: colorScheme.primary),
            ],
          ),
        ),
      ),
    );
  }
}
