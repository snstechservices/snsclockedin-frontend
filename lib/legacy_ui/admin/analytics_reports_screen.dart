import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:fl_chart/fl_chart.dart';
import '../../widgets/admin_side_navigation.dart';
import 'package:provider/provider.dart';
import '../../providers/admin_analytics_provider.dart';
import '../../providers/auth_provider.dart';
// Coach features disabled for this company
// import 'analytics_with_coach.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import '../../utils/time_utils.dart';
import '../../utils/logger.dart';
import '../../utils/theme_utils.dart';
import '../../utils/web_download_helper.dart';
import '../../services/global_notification_service.dart';

class AdminAnalyticsScreen extends StatefulWidget {
  const AdminAnalyticsScreen({super.key});

  @override
  State<AdminAnalyticsScreen> createState() => _AdminAnalyticsScreenState();
}

class _AdminAnalyticsScreenState extends State<AdminAnalyticsScreen> {
  DateTimeRange? _selectedRange;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  String _fmt(DateTime dt) => TimeUtils.formatDate(dt);

  void _loadData() {
    final provider = context.read<AdminAnalyticsProvider>();
    if (_selectedRange == null) {
      provider.fetchSummary();
      provider.fetchOverview();
      provider.fetchLeaveBreakdown();
      provider.fetchLeaveApprovalStatus();
      provider.fetchMonthlyHoursTrend();
    } else {
      final start = _fmt(_selectedRange!.start);
      final end = _fmt(_selectedRange!.end);
      provider.fetchSummary(start: start, end: end);
      provider.fetchOverview(start: start, end: end);
      provider.fetchLeaveBreakdown(start: start, end: end);
      provider.fetchLeaveApprovalStatus(start: start, end: end);
      provider.fetchMonthlyHoursTrend(start: start, end: end);
    }
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final initial =
        _selectedRange ??
        DateTimeRange(start: now.subtract(const Duration(days: 29)), end: now);
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
      initialDateRange: initial,
    );
    if (picked != null) {
      setState(() {
        _selectedRange = picked;
      });
      _loadData();
    }
  }

  void _applyPreset(String preset) {
    final now = DateTime.now();
    DateTime start;
    DateTime end = now;

    switch (preset) {
      case '7':
        start = now.subtract(const Duration(days: 6));
        break;
      case '30':
        start = now.subtract(const Duration(days: 29));
        break;
      case 'month':
        start = DateTime(now.year, now.month, 1);
        break;
      case 'quarter':
        final quarterStartMonth = ((now.month - 1) ~/ 3) * 3 + 1;
        start = DateTime(now.year, quarterStartMonth, 1);
        break;
      case 'year':
        start = DateTime(now.year, 1, 1);
        break;
      case 'clear':
        setState(() {
          _selectedRange = null;
        });
        _loadData();
        return;
      default:
        return;
    }

    setState(() {
      _selectedRange = DateTimeRange(start: start, end: end);
    });
    _loadData();
  }

  Future<void> _generateReport() async {
    try {
      // Show report type selection dialog
      final reportType = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Generate Report'),
          content: const Text(
            'Select the type of report you want to generate:',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop('analytics'),
              child: const Text('Analytics Report (PDF)'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop('leave'),
              child: const Text('Leave Data Export'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        ),
      );

      if (reportType == null) return; // User cancelled

      if (!mounted) return;
      final provider = context.read<AdminAnalyticsProvider>();

      String? start, end;
      if (_selectedRange != null) {
        start = _fmt(_selectedRange!.start);
        end = _fmt(_selectedRange!.end);
      }

      if (reportType == 'analytics') {
        // Generate analytics report (existing functionality)
        final reportData = await provider.generateReport(
          start: start,
          end: end,
          format: 'pdf',
        );

        if (reportData != null && reportData is Uint8List) {
          // Generate filename with timestamp in company timezone
          final now = DateTime.now();
          final auth = Provider.of<AuthProvider>(context, listen: false);
          final timestamp = TimeUtils.formatDateTime(
            now,
            user: auth.user,
            company: auth.company,
          ).replaceAll(' ', '_').replaceAll(':', '-');
          final periodText = _selectedRange != null
              ? '${_fmt(_selectedRange!.start)}_to_${_fmt(_selectedRange!.end)}'
              : 'last_30_days';
          final filename = 'analytics_report_${periodText}_$timestamp.pdf';

          if (kIsWeb) {
            // For web, use the same helper as advanced reporting
            downloadFileWeb(reportData, filename, 'application/pdf');

            if (mounted) {
              GlobalNotificationService().showSuccess(
                'Report downloaded successfully!',
              );
            }
          } else {
            // For mobile platforms, save to device storage
            Directory? directory;
            if (Platform.isAndroid) {
              // For Android, save to external storage directory (no permissions needed)
              directory = await getExternalStorageDirectory();
              // Create a Reports folder in the app's external storage
              final reportsDir = Directory('${directory?.path}/Reports');
              if (!await reportsDir.exists()) {
                await reportsDir.create(recursive: true);
              }
              directory = reportsDir;
            } else if (Platform.isIOS) {
              // For iOS, save to Documents directory
              directory = await getApplicationDocumentsDirectory();
            } else {
              // For other platforms, use Documents directory
              directory = await getApplicationDocumentsDirectory();
            }

            final file = File('${directory.path}/$filename');
            await file.writeAsBytes(reportData);

            if (mounted) {
              final friendlyPath = Platform.isAndroid
                  ? 'Android/data/com.example.sns_rooster/files/Reports/'
                  : 'Documents/';

              GlobalNotificationService().showSuccess(
                'Report generated successfully! Saved to: $friendlyPath$filename',
              );
              // Note: Open file action removed as GlobalNotificationService doesn't support actions
              // User can manually open the file from the saved location
            }

            // Also try to open the file automatically
            try {
              await OpenFile.open(file.path);
            } catch (e) {
              // If auto-open fails, that's okay - user can still open manually
              // 'Auto-open failed: $e');
            }
          }
        } else {
          throw Exception('No report data received or invalid format');
        }
      } else if (reportType == 'leave') {
        // Generate leave export
        // Show format selection dialog
        if (!mounted) return;
        final format = await showDialog<String>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Export Leave Data'),
            content: const Text('Select export format:'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop('csv'),
                child: const Text('CSV'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop('excel'),
                child: const Text('Excel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop('json'),
                child: const Text('JSON'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
            ],
          ),
        );

        if (format == null) return; // User cancelled

        final exportData = await provider.exportLeaveData(
          start: start,
          end: end,
          format: format,
        );

        if (exportData != null) {
          // Generate filename with timestamp in company timezone
          final now = DateTime.now();
          final auth = Provider.of<AuthProvider>(context, listen: false);
          final timestamp = TimeUtils.formatDateTime(
            now,
            user: auth.user,
            company: auth.company,
          ).replaceAll(' ', '_').replaceAll(':', '-');
          final periodText = _selectedRange != null
              ? '${_fmt(_selectedRange!.start)}_to_${_fmt(_selectedRange!.end)}'
              : 'all_time';
          final filename = 'leave_export_${periodText}_$timestamp.$format';

          // Handle web platform differently
          if (kIsWeb) {
            // For web, use the same helper as advanced reporting
            Uint8List bytes;
            String mimeType;

            if (format == 'json') {
              bytes = Uint8List.fromList(json.encode(exportData).codeUnits);
              mimeType = 'application/json';
            } else if (format == 'csv') {
              bytes = exportData is Uint8List
                  ? exportData
                  : Uint8List.fromList(exportData);
              mimeType = 'text/csv';
            } else if (format == 'excel' || format == 'xlsx') {
              bytes = exportData is Uint8List
                  ? exportData
                  : Uint8List.fromList(exportData);
              mimeType =
                  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
            } else {
              bytes = exportData is Uint8List
                  ? exportData
                  : Uint8List.fromList(exportData);
              mimeType = 'application/octet-stream';
            }

            downloadFileWeb(bytes, filename, mimeType);

            if (mounted) {
              GlobalNotificationService().showSuccess(
                'Leave data exported successfully in $format format!',
              );
            }
            return; // Exit early for web
          }

          // For mobile platforms, save to device storage
          if (!kIsWeb) {
            Directory? directory;
            if (Platform.isAndroid) {
              // For Android, save to external storage directory (no permissions needed)
              directory = await getExternalStorageDirectory();
              // Create a Reports folder in the app's external storage
              final reportsDir = Directory('${directory?.path}/Reports');
              if (!await reportsDir.exists()) {
                await reportsDir.create(recursive: true);
              }
              directory = reportsDir;
            } else if (Platform.isIOS) {
              // For iOS, save to Documents directory
              directory = await getApplicationDocumentsDirectory();
            } else {
              // For other platforms, use Documents directory
              directory = await getApplicationDocumentsDirectory();
            }

            final file = File('${directory.path}/$filename');

            if (format == 'json') {
              // For JSON, write the string data
              await file.writeAsString(json.encode(exportData));
            } else {
              // For CSV/Excel, write the bytes
              await file.writeAsBytes(exportData);
            }

            if (mounted) {
              final friendlyPath = Platform.isAndroid
                  ? 'Android/data/com.example.sns_rooster/files/Reports/'
                  : 'Documents/';

              GlobalNotificationService().showSuccess(
                'Leave data exported successfully! Saved to: $friendlyPath$filename',
              );
              // Note: Open file action removed as GlobalNotificationService doesn't support actions
              // User can manually open the file from the saved location
            }

            // Also try to open the file automatically
            try {
              await OpenFile.open(file.path);
            } catch (e) {
              // If auto-open fails, that's okay - user can still open manually
              // 'Auto-open failed: $e');
            }
          }
        } else {
          throw Exception('No leave data received or invalid format');
        }
      }
    } catch (e) {
      if (mounted) {
        GlobalNotificationService().showError(
          'Failed to generate report: ${e.toString()}',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final analytics = Provider.of<AdminAnalyticsProvider>(
      context,
      listen: true,
    );

    final colorScheme = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics & Reports'),
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        actions: [
          TextButton.icon(
            onPressed: _pickDateRange,
            icon: const Icon(Icons.date_range, color: Colors.white),
            label: Text(
              _selectedRange == null
                  ? 'Last 30d'
                  : '${TimeUtils.formatReadableDate(_selectedRange!.start)} - ${TimeUtils.formatReadableDate(_selectedRange!.end)}',
              style: const TextStyle(color: Colors.white),
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: (value) {
              _applyPreset(value);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: '7', child: Text('Last 7 days')),
              const PopupMenuItem(value: '30', child: Text('Last 30 days')),
              const PopupMenuItem(value: 'month', child: Text('This month')),
              const PopupMenuItem(
                value: 'quarter',
                child: Text('This quarter'),
              ),
              const PopupMenuItem(value: 'year', child: Text('This year')),
              const PopupMenuItem(value: 'clear', child: Text('Clear filter')),
            ],
          ),
        ],
      ),
      drawer: const AdminSideNavigation(currentRoute: '/analytics'),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: analytics.isLoading ? null : () => _generateReport(),
        icon: analytics.isLoading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.download),
        label: Text(analytics.isLoading ? 'Generating...' : 'Generate Report'),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Using fixed 2x3 layout for all screen sizes

          final kpis = _buildKpis(analytics.summary);

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // KPI Cards Section
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.analytics,
                          color: theme.colorScheme.primary,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Key Performance Indicators',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Column(
                      children: [
                        // First row: 2 cards
                        Row(
                          children: [
                            Expanded(child: _buildKpiCard(theme, kpis[0])),
                            const SizedBox(width: 8),
                            Expanded(child: _buildKpiCard(theme, kpis[1])),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Second row: 2 cards
                        Row(
                          children: [
                            Expanded(child: _buildKpiCard(theme, kpis[2])),
                            const SizedBox(width: 8),
                            Expanded(child: _buildKpiCard(theme, kpis[3])),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Third row: 2 cards
                        Row(
                          children: [
                            Expanded(child: _buildKpiCard(theme, kpis[4])),
                            const SizedBox(width: 8),
                            Expanded(child: _buildKpiCard(theme, kpis[5])),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Charts Section
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.show_chart,
                          color: theme.colorScheme.primary,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Analytics & Reports',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Dynamic header based on selected filter
                    Text(
                      _getHoursChartTitle(
                        analytics.monthlyHoursTrend,
                        _selectedRange,
                      ),
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildChartCard(
                      theme,
                      child: AspectRatio(
                        aspectRatio: 1.8,
                        child: _buildMonthlyHoursChart(
                          theme,
                          analytics.monthlyHoursTrend,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Leave Analytics Section
                    Text(
                      'Leave Analytics',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Leave Charts Row - Responsive Layout
                    LayoutBuilder(
                      builder: (context, constraints) {
                        if (constraints.maxWidth < 600) {
                          // Mobile layout - stacked
                          return Column(
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Leave Type Distribution',
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: theme.colorScheme.onSurface,
                                        ),
                                  ),
                                  const SizedBox(height: 12),
                                  _buildChartCard(
                                    theme,
                                    child: SizedBox(
                                      height:
                                          400, // Increased to accommodate legends
                                      child: _buildPieChart(
                                        theme,
                                        analytics.leaveBreakdown,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Leave Approval Status',
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: theme.colorScheme.onSurface,
                                        ),
                                  ),
                                  const SizedBox(height: 12),
                                  _buildChartCard(
                                    theme,
                                    child: SizedBox(
                                      height: 280,
                                      child: _buildLeaveApprovalChart(
                                        theme,
                                        analytics.leaveApprovalStatus,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          );
                        } else {
                          // Desktop layout - side by side
                          return Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Leave Type Distribution',
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: theme.colorScheme.onSurface,
                                          ),
                                    ),
                                    const SizedBox(height: 12),
                                    _buildChartCard(
                                      theme,
                                      child: SizedBox(
                                        height:
                                            400, // Increased to accommodate legends
                                        child: _buildPieChart(
                                          theme,
                                          analytics.leaveBreakdown,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Leave Approval Status',
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: theme.colorScheme.onSurface,
                                          ),
                                    ),
                                    const SizedBox(height: 12),
                                    _buildChartCard(
                                      theme,
                                      child: SizedBox(
                                        height: 280,
                                        child: _buildLeaveApprovalChart(
                                          theme,
                                          analytics.leaveApprovalStatus,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 100),
              if (analytics.isLoading)
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const CircularProgressIndicator(),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildKpiCard(ThemeData theme, Map<String, dynamic> kpi) {
    final accent = kpi['color'] as Color? ?? theme.colorScheme.primary;
    final value = kpi['value'] as String;
    final hasData = value != '—' && value.isNotEmpty;

    return Card(
      elevation: 6,
      shadowColor: accent.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              accent.withValues(alpha: 0.05),
              accent.withValues(alpha: 0.02),
            ],
          ),
        ),
        child: Stack(
          children: [
            // Background pattern
            Positioned(
              top: -8,
              right: -8,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12), // Even more compact padding
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icon and title row
                  Row(
                    children: [
                      Container(
                        width: 28, // Even smaller icon container
                        height: 28,
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(
                          kpi['icon'] as IconData,
                          size: 14, // Even smaller icon
                          color: accent,
                        ),
                      ),
                      const Spacer(),
                      if (!hasData)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'No Data',
                            style: TextStyle(
                              fontSize: 10,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.6),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8), // Even more compact spacing
                  // Value
                  Text(
                    value,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: hasData
                          ? theme.colorScheme.onSurface
                          : theme.colorScheme.onSurface.withValues(alpha: 0.4),
                      fontSize: hasData ? 18 : 16, // Even smaller font size
                    ),
                  ),
                  const SizedBox(height: 4), // Minimal spacing
                  // Title
                  Text(
                    kpi['title'],
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      fontWeight: FontWeight.w500,
                      fontSize: 11, // Smaller title text
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthlyHoursChart(ThemeData theme, List<dynamic> trend) {
    // Handle empty data
    if (trend.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.bar_chart,
                size: 48,
                color: theme.colorScheme.outline.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 16),
              Text(
                'No data available for the selected period',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.outline,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    // Prepare data map - handle both daily (YYYY-MM-DD) and monthly (YYYY-MM) formats
    final Map<String, double> map = {};
    for (var e in trend) {
      if (e is Map && e['month'] != null && e['hours'] != null) {
        map[e['month']] = (e['hours'] as num).toDouble();
      }
    }

    // Determine if data is daily or monthly based on the keys
    final sampleKey = map.keys.isNotEmpty ? map.keys.first : '';
    final isDailyData =
        sampleKey.contains('-') &&
        sampleKey.split('-').length == 3; // YYYY-MM-DD format

    // Determine date range based on filter
    final now = DateTime.now();
    DateTime startDate;
    DateTime endDate;

    if (_selectedRange != null) {
      // Use selected date range
      if (isDailyData) {
        // For daily data, use the exact date range
        startDate = DateTime(
          _selectedRange!.start.year,
          _selectedRange!.start.month,
          _selectedRange!.start.day,
        );
        endDate = DateTime(
          _selectedRange!.end.year,
          _selectedRange!.end.month,
          _selectedRange!.end.day,
        );
      } else {
        // For monthly data, use first day of each month
        startDate = DateTime(
          _selectedRange!.start.year,
          _selectedRange!.start.month,
          1,
        );
        endDate = DateTime(
          _selectedRange!.end.year,
          _selectedRange!.end.month,
          1,
        );
      }
    } else {
      // Default to last 12 months
      startDate = DateTime(now.year, now.month - 11, 1);
      endDate = DateTime(now.year, now.month, 1);
    }

    List<String> labels;
    List<double> hours;
    Map<int, String> monthIndicators =
        {}; // Map of index to month label - accessible in chart

    if (isDailyData) {
      // Generate list of days in the range
      final List<DateTime> daysList = [];
      DateTime current = startDate;
      while (current.isBefore(endDate) || current.isAtSameMomentAs(endDate)) {
        daysList.add(current);
        current = current.add(const Duration(days: 1));
      }

      // Limit to maximum 90 days for readability
      if (daysList.length > 90) {
        daysList.removeRange(0, daysList.length - 90);
      }

      // Track months for legend and add month change indicators
      final monthSet = <String>{};
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
      int? lastMonth;

      labels = daysList.asMap().entries.map((entry) {
        final idx = entry.key;
        final dt = entry.value;
        // Show just the day number for daily view
        final monthName = monthNames[dt.month - 1];
        monthSet.add('$monthName ${dt.year}');

        // Mark month changes with indicator
        if (lastMonth != null && lastMonth != dt.month) {
          monthIndicators[idx] = monthName;
        } else if (idx == 0) {
          // First day always shows month
          monthIndicators[idx] = monthName;
        }
        lastMonth = dt.month;

        return '${dt.day}';
      }).toList();

      hours = daysList.map<double>((dt) {
        final key =
            '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
        final val = map[key] ?? 0.0;
        return val < 0 ? 0 : val;
      }).toList();
    } else {
      // Generate list of months in the range
      final List<DateTime> monthsList = [];
      DateTime current = startDate;
      while (current.isBefore(endDate) || current.isAtSameMomentAs(endDate)) {
        monthsList.add(current);
        // Move to next month
        if (current.month == 12) {
          current = DateTime(current.year + 1, 1, 1);
        } else {
          current = DateTime(current.year, current.month + 1, 1);
        }
      }

      // Limit to maximum 12 months for readability
      if (monthsList.length > 12) {
        monthsList.removeRange(0, monthsList.length - 12);
      }

      labels = monthsList
          .map((dt) => TimeUtils.formatReadableDate(dt).substring(0, 3))
          .toList();
      hours = monthsList.map<double>((dt) {
        final key = '${dt.year}-${dt.month.toString().padLeft(2, '0')}';
        final val = map[key] ?? 0.0;
        return val < 0 ? 0 : val;
      }).toList();
    }

    // Handle empty hours list
    if (hours.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.bar_chart,
                size: 48,
                color: theme.colorScheme.outline.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 16),
              Text(
                'No data available for the selected period',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.outline,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final maxY = hours.reduce((a, b) => a > b ? a : b);
    final interval = _calculateYInterval(hours);

    final spots = List.generate(
      hours.length,
      (i) => FlSpot(i.toDouble(), hours[i]),
    );

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: maxY == 0 ? 5 : maxY * 1.2,
        gridData: FlGridData(
          show: true,
          verticalInterval: 1,
          horizontalInterval: interval,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(
            color: theme.colorScheme.outline.withValues(alpha: 0.15),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize:
                  45, // Increased to accommodate longer labels like "1180h"
              interval: interval,
              getTitlesWidget: (value, meta) {
                final hours = value.toInt();
                // Format large numbers more compactly (e.g., 1180h -> 1.2k h)
                final label = hours >= 1000
                    ? '${(hours / 1000).toStringAsFixed(1)}k h'
                    : '${hours}h';
                return Padding(
                  padding: const EdgeInsets.only(right: 4.0),
                  child: Text(
                    label,
                    style: theme.textTheme.bodySmall?.copyWith(fontSize: 10),
                    textAlign: TextAlign.right,
                  ),
                );
              },
            ),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 50, // Increased to accommodate month indicators
              interval: labels.length > 14
                  ? 2.0
                  : 1.0, // Show every other label if too many
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= labels.length) {
                  return const SizedBox.shrink();
                }
                // For daily data with many days, rotate labels slightly
                final isDaily = labels.length > 7;
                final monthIndicator = monthIndicators[idx];
                return Padding(
                  padding: const EdgeInsets.only(top: 6.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (monthIndicator != null)
                        Text(
                          monthIndicator,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 8,
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      Transform.rotate(
                        angle: isDaily
                            ? -0.4
                            : 0, // Slight rotation for daily labels
                        child: Text(
                          labels[idx],
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 10,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: false,
            color: theme.colorScheme.primary,
            barWidth: 3,
            belowBarData: BarAreaData(
              show: true,
              color: theme.colorScheme.primary.withValues(alpha: 0.15),
            ),
            dotData: const FlDotData(show: false),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touchedSpots) => touchedSpots
                .map(
                  (s) => LineTooltipItem(
                    '${labels[s.x.toInt()]}\n${s.y.toStringAsFixed(1)}h',
                    TextStyle(color: theme.colorScheme.onPrimary),
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildPieChart(ThemeData theme, Map<String, dynamic>? attendance) {
    if (attendance == null || attendance.isEmpty) {
      return const Center(child: Text('No data'));
    }

    // DEBUG: Log the data being used for the chart
    if (kDebugMode) {
      Logger.debug('🔍 DEBUG: _buildPieChart received data: $attendance');
      Logger.debug(
        '🔍 DEBUG: _buildPieChart keys: ${attendance.keys.toList()}',
      );
      attendance.forEach((key, value) {
        Logger.debug('🔍 DEBUG: Chart entry - "$key": $value');
      });
    }

    final theme = Theme.of(context);
    final colors = ThemeUtils.getSafeChartColors(theme);

    final entries = attendance.entries.toList();
    final total = attendance.values.fold<int>(
      0,
      (prev, v) =>
          prev + (v is int ? v : (v is String ? int.tryParse(v) ?? 0 : 0)),
    );

    final sections = List.generate(entries.length, (idx) {
      final e = entries[idx];
      final value = e.value is num
          ? (e.value as num).toDouble()
          : (e.value is String ? double.tryParse(e.value) ?? 0.0 : 0.0);
      final pct = total > 0 ? ((value / total) * 100).toStringAsFixed(1) : '0';
      return {
        'value': value,
        'label': e.key.toString(),
        'pct': pct,
        'color': colors[idx % colors.length],
      };
    });

    // DEBUG: Log sections for verification
    if (kDebugMode) {
      Logger.debug('🔍 DEBUG: Chart sections generated: ${sections.length}');
      for (var s in sections) {
        Logger.debug(
          '🔍 DEBUG: Section - "${s['label']}": ${s['value']} (${s['pct']}%)',
        );
      }
      Logger.debug('🔍 DEBUG: Total count: $total');
    }

    return Column(
      children: [
        Expanded(
          child: PieChart(
            PieChartData(
              sections: sections
                  .map(
                    (s) => PieChartSectionData(
                      value: s['value'] as double,
                      color: s['color'] as Color,
                      title: '${s['pct']}%',
                      titleStyle: TextStyle(
                        color: theme.colorScheme.onPrimary,
                        fontSize: 12,
                      ),
                    ),
                  )
                  .toList(),
              sectionsSpace: 2,
              centerSpaceRadius: 40,
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Legend - Constrained to prevent overflow
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 120),
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: Wrap(
              spacing: 12,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: sections.map((s) {
                return ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 150),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: s['color'] as Color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          '${s['label']}: ${s['pct']}%',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 11,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChartCard(ThemeData theme, {required Widget child}) {
    return Card(
      elevation: 4,
      shadowColor: theme.colorScheme.primary.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              theme.colorScheme.surface,
              theme.colorScheme.surface.withValues(alpha: 0.95),
            ],
          ),
        ),
        child: Padding(padding: const EdgeInsets.all(16.0), child: child),
      ),
    );
  }

  Widget _buildLeaveApprovalChart(
    ThemeData theme,
    Map<String, dynamic>? approvalData,
  ) {
    if (approvalData == null || approvalData.isEmpty) {
      return const Center(child: Text('No approval data available'));
    }

    // Default approval data if not provided
    final data = approvalData.isEmpty
        ? {'Approved': 15, 'Pending': 8, 'Rejected': 3}
        : approvalData;

    final theme = Theme.of(context);
    ThemeUtils.getSafeChartColors(theme);
    final colors = [
      ThemeUtils.getStatusChipColor('success', theme), // Green for approved
      ThemeUtils.getStatusChipColor('warning', theme), // Orange for pending
      ThemeUtils.getStatusChipColor('error', theme), // Red for rejected
    ];

    final entries = data.entries.toList();
    final total = data.values.fold<int>(0, (prev, v) => prev + (v as int));

    final sections = List.generate(entries.length, (idx) {
      final e = entries[idx];
      final value = (e.value as num).toDouble();
      final pct = total > 0 ? ((value / total) * 100).toStringAsFixed(1) : '0';
      return {
        'value': value,
        'label': e.key,
        'pct': pct,
        'color': colors[idx % colors.length],
      };
    });

    return Column(
      children: [
        Expanded(
          child: PieChart(
            PieChartData(
              sections: sections
                  .map(
                    (s) => PieChartSectionData(
                      value: s['value'] as double,
                      color: s['color'] as Color,
                      title: '${s['pct']}%',
                      titleStyle: TextStyle(
                        color: theme.colorScheme.onPrimary,
                        fontSize: 12,
                      ),
                    ),
                  )
                  .toList(),
              sectionsSpace: 2,
              centerSpaceRadius: 40,
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Legend - Constrained to prevent overflow
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 120),
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: Wrap(
              spacing: 12,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: sections.map((s) {
                return ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 150),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: s['color'] as Color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          '${s['label']}: ${s['pct']}%',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 11,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  List<Map<String, dynamic>> _buildKpis(Map<String, dynamic>? summary) {
    String fmtHours(num? h) => h == null ? '—' : '${h}h';
    String fmtPercent(num? p) => p == null ? '—' : '$p%';
    String fmtDays(num? d) => d == null ? '—' : '${d}d';

    String fmtTime(String? iso) {
      if (iso == null) return '—';
      final dt = DateTime.tryParse(iso);
      if (dt == null) return '—';
      return TimeUtils.formatTime(dt).substring(0, 5); // Get HH:mm part
    }

    final theme = Theme.of(context);
    final colors = ThemeUtils.getSafeChartColors(theme);
    return [
      {
        'title': 'Total Hours',
        'value': fmtHours(summary?['totalHours']),
        'icon': Icons.timer,
        'color': colors[0],
      },
      {
        'title': 'Overtime',
        'value': fmtHours(summary?['overtimeHours']),
        'icon': Icons.alarm_add,
        'color': colors[1],
      },
      {
        'title': 'Absence Rate',
        'value': fmtPercent(summary?['absenceRate']),
        'icon': Icons.person_off,
        'color': colors[2],
      },
      {
        'title': 'Avg Check-In',
        'value': fmtTime(summary?['avgCheckIn']),
        'icon': Icons.login,
        'color': colors[3],
      },
      // New Leave-specific KPIs
      {
        'title': 'Total Leave Days',
        'value': fmtDays(summary?['totalLeaveDays']),
        'icon': Icons.beach_access,
        'color': colors[4],
      },
      {
        'title': 'Leave Approval Rate',
        'value': fmtPercent(summary?['leaveApprovalRate']),
        'icon': Icons.check_circle,
        'color': colors[5],
      },
    ];
  }

  double _calculateYInterval(List<double> list) {
    final maxVal = list.isEmpty ? 0 : list.reduce((a, b) => a > b ? a : b);
    if (maxVal <= 10) return 2;
    if (maxVal <= 50) return 10;
    if (maxVal <= 100) return 20;
    return (maxVal / 5).ceilToDouble();
  }

  String _getHoursChartTitle(
    List<dynamic> trend,
    DateTimeRange? selectedRange,
  ) {
    if (trend.isEmpty) {
      return 'Hours Worked';
    }

    // Check if data is daily (YYYY-MM-DD) or monthly (YYYY-MM) format
    final sampleKey =
        trend.isNotEmpty && trend[0] is Map && trend[0]['month'] != null
        ? trend[0]['month'] as String
        : '';

    final isDaily = sampleKey.contains('-') && sampleKey.split('-').length == 3;

    // If a date range is selected, show the range in the title
    if (selectedRange != null) {
      final startStr = TimeUtils.formatReadableDate(selectedRange.start);
      final endStr = TimeUtils.formatReadableDate(selectedRange.end);
      if (isDaily) {
        return 'Daily Hours Worked ($startStr - $endStr)';
      } else {
        return 'Monthly Hours Worked ($startStr - $endStr)';
      }
    } else {
      // No filter selected - use default title
      if (isDaily) {
        return 'Daily Hours Worked';
      } else {
        return 'Monthly Hours Worked';
      }
    }
  }
}
