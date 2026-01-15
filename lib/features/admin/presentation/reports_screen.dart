import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:sns_clocked_in/core/ui/app_card.dart';
import 'package:sns_clocked_in/core/ui/app_screen_scaffold.dart';
import 'package:sns_clocked_in/design_system/app_colors.dart';
import 'package:sns_clocked_in/design_system/app_radius.dart';
import 'package:sns_clocked_in/design_system/app_spacing.dart';
import 'package:sns_clocked_in/design_system/app_typography.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';
import 'package:sns_clocked_in/core/ui/collapsible_filter_section.dart';

/// Admin Analytics & Reports screen
class AdminReportsScreen extends StatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<AdminReportsScreen> {
  String _selectedPeriod = 'Last 30d';
  DateTimeRange? _selectedRange;
  Map<String, String> _kpiValues = const {};
  List<double> _monthlyHours = const [];

  @override
  void initState() {
    super.initState();
    _seedDebugData();
    // Set default to last 30 days
    final now = DateTime.now();
    _selectedRange = DateTimeRange(
      start: now.subtract(const Duration(days: 29)),
      end: now,
    );
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
      initialDateRange: _selectedRange,
    );
    if (picked != null) {
      setState(() {
        _selectedRange = picked;
        final days = picked.end.difference(picked.start).inDays;
        if (days == 6) {
          _selectedPeriod = 'Last 7d';
        } else if (days == 29) {
          _selectedPeriod = 'Last 30d';
        } else {
          _selectedPeriod = 'Custom';
        }
      });
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
      default:
        return;
    }

    setState(() {
      _selectedRange = DateTimeRange(start: start, end: end);
      _selectedPeriod = preset == '7'
          ? 'Last 7d'
          : preset == '30'
              ? 'Last 30d'
              : 'This Month';
    });
  }

  void _showPeriodMenu() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: const Text('Last 7 days'),
              onTap: () {
                _applyPreset('7');
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: const Text('Last 30 days'),
              onTap: () {
                _applyPreset('30');
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.calendar_month),
              title: const Text('This month'),
              onTap: () {
                _applyPreset('month');
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.date_range),
              title: const Text('Custom range'),
              onTap: () {
                Navigator.pop(context);
                _pickDateRange();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _generateReport() {
    _showExportSheet();
  }

  void _showExportSheet() {
    String format = 'PDF';
    bool includeSummary = true;
    bool includeCharts = true;
    bool includeRawData = false;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return SafeArea(
              child: Padding(
                padding: AppSpacing.lgAll,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Export Report',
                      style: AppTypography.lightTextTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Choose format and sections to include.',
                      style: AppTypography.lightTextTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppCard(
                      padding: AppSpacing.mdAll,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Format',
                            style: AppTypography.lightTextTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          RadioListTile<String>(
                            value: 'PDF',
                            groupValue: format,
                            onChanged: (value) => setState(() => format = value ?? 'PDF'),
                            title: const Text('PDF'),
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                          RadioListTile<String>(
                            value: 'CSV',
                            groupValue: format,
                            onChanged: (value) => setState(() => format = value ?? 'CSV'),
                            title: const Text('CSV'),
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppCard(
                      padding: AppSpacing.mdAll,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Include Sections',
                            style: AppTypography.lightTextTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Summary'),
                            value: includeSummary,
                            onChanged: (value) => setState(() => includeSummary = value),
                          ),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Charts'),
                            value: includeCharts,
                            onChanged: (value) => setState(() => includeCharts = value),
                          ),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Raw data tables'),
                            value: includeRawData,
                            onChanged: (value) => setState(() => includeRawData = value),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Exporting report as $format (demo)'),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                      icon: const Icon(Icons.download_outlined),
                      label: const Text('Export'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: AppSpacing.mdAll,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _seedDebugData() {
    if (!kDebugMode) return;
    _kpiValues = const {
      'Total Hours': '182h',
      'Overtime': '14h',
      'Absence Rate': '2.1%',
      'Avg Check-In': '9:04 AM',
      'Total Leave Days': '12',
      'Leave Approval Rate': '93%',
    };
    _monthlyHours = const [
      120.0,
      132.0,
      128.0,
      140.0,
      150.0,
      155.0,
      160.0,
      170.0,
      168.0,
      182.0,
      190.0,
      178.0,
    ];
  }

  @override
  Widget build(BuildContext context) {
    return AppScreenScaffold(
      skipScaffold: true,
      child: Column(
        children: [
          // Quick Stats at top (always visible, match pattern)
          _buildQuickStatsSection(),
          // Collapsible Filters Section
          _buildFiltersSection(),
          // Main content (scrollable)
          Expanded(
            child: Stack(
              children: [
                SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: AppSpacing.lg),
                      // Monthly Hours Chart
                      _buildMonthlyHoursChart(),
                    ],
                  ),
                ),
                // Generate Report FAB
                Positioned(
                  bottom: AppSpacing.md,
                  right: AppSpacing.md,
                  child: FloatingActionButton.extended(
                    onPressed: _generateReport,
                    icon: const Icon(Icons.download),
                    label: const Text('Generate Report'),
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStatsSection() {
    final kpiData = [
      (
        icon: Icons.access_time,
        color: AppColors.primary,
        label: 'Total Hours',
        value: _kpiValues['Total Hours'] ?? '-',
      ),
      (
        icon: Icons.alarm,
        color: AppColors.success,
        label: 'Overtime',
        value: _kpiValues['Overtime'] ?? '-',
      ),
      (
        icon: Icons.person_off,
        color: AppColors.warning,
        label: 'Absence Rate',
        value: _kpiValues['Absence Rate'] ?? '-',
      ),
      (
        icon: Icons.login,
        color: AppColors.secondary,
        label: 'Avg Check-In',
        value: _kpiValues['Avg Check-In'] ?? '-',
      ),
      (
        icon: Icons.beach_access,
        color: AppColors.breakAction,
        label: 'Total Leave Days',
        value: _kpiValues['Total Leave Days'] ?? '-',
      ),
      (
        icon: Icons.check_circle,
        color: AppColors.success,
        label: 'Leave Approval Rate',
        value: _kpiValues['Leave Approval Rate'] ?? '-',
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.05),
        border: Border(
          bottom: BorderSide(
            color: AppColors.textSecondary.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.bar_chart, size: 18, color: AppColors.textSecondary),
              const SizedBox(width: AppSpacing.xs),
              Text(
                'Key Performance Indicators',
                style: AppTypography.lightTextTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final kpi in kpiData) ...[
                  SizedBox(
                    width: 140,
                    child: _buildStatCard(
                      title: kpi.label,
                      value: kpi.value,
                      color: kpi.color,
                      icon: kpi.icon,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: AppSpacing.sm),
          Text(
            title,
            style: AppTypography.lightTextTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            value,
            style: AppTypography.lightTextTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltersSection() {
    return CollapsibleFilterSection(
      title: 'Filters',
      initiallyExpanded: true,
      onClear: () {
        final now = DateTime.now();
        setState(() {
          _selectedRange = DateTimeRange(
            start: now.subtract(const Duration(days: 29)),
            end: now,
          );
          _selectedPeriod = 'Last 30d';
        });
      },
      child: InkWell(
        onTap: _showPeriodMenu,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: AppRadius.smAll,
            border: Border.all(
              color: AppColors.textSecondary.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.calendar_today,
                size: 16,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                _selectedPeriod,
                style: AppTypography.lightTextTheme.bodySmall,
              ),
              const SizedBox(width: AppSpacing.xs),
              const Icon(
                Icons.arrow_drop_down,
                size: 16,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }


  Widget _buildMonthlyHoursChart() {
    // Mock data for 12 months
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final hours = _monthlyHours.isNotEmpty
        ? _monthlyHours
        : [120.0, 132.0, 128.0, 140.0, 150.0, 155.0, 160.0, 170.0, 168.0, 182.0, 190.0, 178.0];

    return AppCard(
      padding: AppSpacing.lgAll,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.show_chart,
                color: AppColors.primary,
                size: 20,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Analytics & Reports',
                style: AppTypography.lightTextTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Monthly Hours Worked',
            style: AppTypography.lightTextTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 35,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: AppColors.textSecondary.withValues(alpha: 0.1),
                      strokeWidth: 1,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index >= 0 && index < months.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              months[index],
                              style: AppTypography.lightTextTheme.bodySmall?.copyWith(
                                color: AppColors.textSecondary,
                                fontSize: 10,
                              ),
                            ),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 50,
                      interval: 35,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          '${value.toInt()}h',
                          style: AppTypography.lightTextTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                            fontSize: 10,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border(
                    bottom: BorderSide(
                      color: AppColors.textSecondary.withValues(alpha: 0.2),
                    ),
                    left: BorderSide(
                      color: AppColors.textSecondary.withValues(alpha: 0.2),
                    ),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: hours.asMap().entries.map((e) {
                      return FlSpot(e.key.toDouble(), e.value);
                    }).toList(),
                    isCurved: false,
                    color: AppColors.primary,
                    barWidth: 3,
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppColors.primary.withValues(alpha: 0.15),
                    ),
                    dotData: const FlDotData(show: false),
                  ),
                ],
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        final index = spot.x.toInt();
                        return LineTooltipItem(
                          '${months[index]}\n${spot.y.toStringAsFixed(1)}h',
                          AppTypography.lightTextTheme.bodySmall?.copyWith(
                            color: Colors.white,
                          ) ?? const TextStyle(color: Colors.white),
                        );
                      }).toList();
                    },
                  ),
                ),
                minY: 0,
                maxY: 210,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
