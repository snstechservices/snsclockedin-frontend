import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart'; // Import provider
import '../../providers/analytics_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/company_provider.dart';
import '../../widgets/app_drawer.dart'; // Import AppDrawer
import '../../services/employee_analytics_service.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import '../admin/analytics_reports_screen.dart';
import 'package:sns_rooster/services/api_service.dart';
import 'package:sns_rooster/config/api_config.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../utils/time_utils.dart';
import '../../services/connectivity_service.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  String selectedRange = 'Last 7 days';
  final List<String> ranges = ['Last 7 days', 'Last 30 days', 'Custom'];
  int _customRange = 7;

  bool get isCustom => selectedRange == 'Custom';

  Map<String, dynamic>? lateCheckins;
  Map<String, dynamic>? avgCheckout;
  List<dynamic>? recentActivity;
  bool loadingExtra = true;
  String? extraError;

  // ScrollController for chart horizontal scrolling
  final ScrollController _chartScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      Provider.of<AnalyticsProvider>(
        context,
        listen: false,
      ).fetchAnalyticsData(range: 7);
      // Fetch extra analytics
      try {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final userId = authProvider.user?['_id'] ?? authProvider.user?['id'];
        final apiService = ApiService(baseUrl: ApiConfig.baseUrl);
        final analyticsService = EmployeeAnalyticsService(apiService);
        final late = await analyticsService.fetchLateCheckins(userId);
        final avg = await analyticsService.fetchAvgCheckout(userId);
        final recent = await analyticsService.fetchRecentActivity(userId);
        setState(() {
          lateCheckins = late;
          avgCheckout = avg;
          recentActivity = recent;
          loadingExtra = false;
          // Clear error if data was loaded successfully (even if null)
          extraError = null;
        });
      } catch (e) {
        // Check if it's a "feature not enabled" error
        final errorMessage = e.toString().toLowerCase();
        if (errorMessage.contains('analytics feature is not enabled') ||
            errorMessage.contains('feature is not enabled')) {
          // Feature not enabled - show friendly message instead of error
          setState(() {
            extraError = null; // Don't show as error
            lateCheckins = null;
            avgCheckout = null;
            recentActivity = null;
            loadingExtra = false;
          });
        } else {
          // Other errors - show error message
          setState(() {
            extraError = e.toString();
            loadingExtra = false;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _chartScrollController.dispose();
    super.dispose();
  }

  // Method to scroll chart to the end with animation
  void _scrollChartToEnd(int workHoursLength) {
    if (workHoursLength > 14) {
      // Wait a bit longer to ensure the scroll view is fully built and visible
      Future.delayed(const Duration(milliseconds: 300), () {
        if (_chartScrollController.hasClients && mounted) {
          _chartScrollController.animateTo(
            _chartScrollController.position.maxScrollExtent,
            duration: const Duration(
              milliseconds: 1200,
            ), // Slower animation to make it more visible
            curve: Curves.easeOutCubic,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;

    // Check if user is authenticated - redirect immediately if not
    if (user == null || !authProvider.isAuthenticated) {
      // Navigate to login immediately instead of showing loading screen
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil('/login', (route) => false);
      });

      // Return minimal widget while navigation happens
      return const Scaffold(body: SizedBox.shrink());
    }
    final isAdmin = user['role'] == 'admin';
    if (isAdmin) {
      // Directly show admin analytics screen for admins
      return const AdminAnalyticsScreen();
    }
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics & Reports'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        elevation: 0,
        leading: Builder(
          builder: (BuildContext context) {
            return IconButton(
              icon: const Icon(Icons.menu), // Hamburger icon
              onPressed: () {
                Scaffold.of(context).openDrawer();
              },
            );
          },
        ),
      ),
      drawer: const AppDrawer(),
      body: Consumer<AnalyticsProvider>(
        builder: (context, analyticsProvider, child) {
          if (analyticsProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          } else if (analyticsProvider.error != null) {
            // Check connectivity status for better error messaging
            final connectivityService = Provider.of<ConnectivityService>(
              context,
              listen: false,
            );
            final isServerReachable = connectivityService.isServerReachable;

            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isServerReachable ? Icons.error_outline : Icons.cloud_off,
                    size: 64,
                    color: isServerReachable
                        ? Colors.red[400]
                        : Colors.orange[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isServerReachable
                        ? 'Error: ${analyticsProvider.error}'
                        : 'Server Unreachable',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: isServerReachable
                          ? Colors.red[600]
                          : Colors.orange[600],
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (!isServerReachable) ...[
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32.0),
                      child: Text(
                        'Unable to connect to the server. Please check your network connection. The app will automatically retry when the server is available.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () {
                      analyticsProvider.clearAnalyticsData();
                      analyticsProvider.fetchAnalyticsData(range: _customRange);
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Try Again'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            );
          } else if (analyticsProvider.attendanceData.isEmpty ||
              analyticsProvider.workHoursData.isEmpty) {
            return const Center(child: Text('No analytics data available.'));
          } else {
            final Map<String, int> attendance =
                analyticsProvider.attendanceData;
            final List<double> workHours = analyticsProvider.workHoursData;

            final int longestStreak = analyticsProvider.longestStreak;
            final String mostProductiveDay =
                analyticsProvider.mostProductiveDay;
            final String avgCheckIn = analyticsProvider.avgCheckIn;

            // Filter out negative work hours (should not happen, but for safety)
            final List<double> filteredWorkHours = workHours
                .map((h) => h < 0 ? 0.0 : h)
                .toList();

            // Calculate dynamic Y-axis max value (add 20% padding, minimum 10)
            final double maxWorkHours = filteredWorkHours.isEmpty
                ? 10.0
                : filteredWorkHours.reduce((a, b) => a > b ? a : b);
            final double yAxisMax = (maxWorkHours * 1.2).ceilToDouble().clamp(
              10.0,
              24.0,
            );

            final double present = attendance['Present']?.toDouble() ?? 0;
            final double absent = attendance['Absent']?.toDouble() ?? 0;
            final double leave = attendance['Leave']?.toDouble() ?? 0;
            final double total = present + absent + leave;
            String percent(double value) => total > 0
                ? '${((value / total) * 100).toStringAsFixed(0)}%'
                : '0%';

            // Dynamically generate X-axis labels with shorter format for longer ranges
            List<String> xLabels;
            bool useShortLabels = false;
            if (workHours.isEmpty) {
              xLabels = [];
            } else {
              // Use shorter labels for ranges longer than 14 days
              if (workHours.length > 14) {
                useShortLabels = true;
                xLabels = List.generate(workHours.length, (i) => '${i + 1}');
              } else {
                xLabels = List.generate(
                  workHours.length,
                  (i) => 'Day ${i + 1}',
                );
              }
            }

            // Calculate label interval based on number of days to prevent overlapping
            int labelInterval;
            if (workHours.length <= 7) {
              labelInterval = 1; // Show all labels for 7 days or less
            } else if (workHours.length <= 14) {
              labelInterval = 2; // Show every 2nd label for up to 14 days
            } else if (workHours.length <= 30) {
              labelInterval =
                  5; // Show every 5th label for 30 days (Day 1, 6, 11, 16, 21, 26)
            } else {
              labelInterval = (workHours.length / 8)
                  .ceil(); // Show ~8 labels for longer ranges
            }
            // Try to use actual dates if available in attendance data
            // (Assumes attendance data is sorted oldest to newest)
            // If you want to use actual dates, you need to pass them from the provider/backend
            // For now, fallback to Day 1...Day N
            String chartTitle = selectedRange == 'Custom'
                ? 'Work Hours Trend (Last $_customRange Days)'
                : selectedRange == 'Last 7 days'
                ? 'Work Hours Trend (Last 7 Days)'
                : selectedRange == 'Last 30 days'
                ? 'Work Hours Trend (Last 30 Days)'
                : 'Work Hours Trend';

            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Your Work Analytics',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        DropdownButton<String>(
                          value: selectedRange,
                          items: ranges
                              .map(
                                (r) =>
                                    DropdownMenuItem(value: r, child: Text(r)),
                              )
                              .toList(),
                          onChanged: (val) async {
                            if (val == 'Custom') {
                              final now = DateTime.now();
                              final int? picked = await showDialog<int>(
                                context: context,
                                builder: (context) {
                                  int tempRange = _customRange;
                                  DateTime endDate = now;
                                  DateTime startDate = now.subtract(
                                    Duration(days: tempRange - 1),
                                  );
                                  String formatDate(DateTime d) {
                                    return '${d.day.toString().padLeft(2, '0')} ${_monthName(d.month)} ${d.year}';
                                  }

                                  return StatefulBuilder(
                                    builder: (context, setState) {
                                      endDate = now;
                                      startDate = now.subtract(
                                        Duration(days: tempRange - 1),
                                      );
                                      return AlertDialog(
                                        title: const Text(
                                          'Select Custom Range (days)',
                                        ),
                                        content: SizedBox(
                                          height: 150,
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Slider(
                                                value: tempRange.toDouble(),
                                                min: 1,
                                                max: 90,
                                                divisions: 89,
                                                label: 'Days: $tempRange',
                                                onChanged: (v) {
                                                  setState(() {
                                                    tempRange = v.round();
                                                  });
                                                },
                                              ),
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  Text(
                                                    'Days: $tempRange',
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .bodyLarge
                                                        ?.copyWith(
                                                          color: Colors.black,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 12),
                                              Divider(
                                                height: 1,
                                                thickness: 1,
                                                color: AppTheme.muted
                                                    .withValues(alpha: 0.3),
                                              ),
                                              const SizedBox(height: 12),
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        'From:',
                                                        style: Theme.of(
                                                          context,
                                                        ).textTheme.bodySmall,
                                                      ),
                                                      Text(
                                                        formatDate(startDate),
                                                        style: Theme.of(context)
                                                            .textTheme
                                                            .bodyLarge
                                                            ?.copyWith(
                                                              color:
                                                                  Colors.black,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                            ),
                                                      ),
                                                    ],
                                                  ),
                                                  Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment.end,
                                                    children: [
                                                      Text(
                                                        'To:',
                                                        style: Theme.of(
                                                          context,
                                                        ).textTheme.bodySmall,
                                                      ),
                                                      Text(
                                                        formatDate(endDate),
                                                        style: Theme.of(context)
                                                            .textTheme
                                                            .bodyLarge
                                                            ?.copyWith(
                                                              color:
                                                                  Colors.black,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                            ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context, null),
                                            child: const Text('Cancel'),
                                          ),
                                          TextButton(
                                            onPressed: () => Navigator.pop(
                                              context,
                                              tempRange,
                                            ),
                                            child: const Text('OK'),
                                          ),
                                        ],
                                      );
                                    },
                                  );
                                },
                              );
                              if (picked != null) {
                                setState(() {
                                  selectedRange = 'Custom';
                                  _customRange = picked;
                                });
                                // ignore: use_build_context_synchronously
                                Provider.of<AnalyticsProvider>(
                                  context,
                                  listen: false,
                                ).fetchAnalyticsData(range: picked);
                              }
                            } else {
                              setState(() {
                                selectedRange = val!;
                              });
                              int range = 7;
                              if (val == 'Last 30 days') range = 30;
                              Provider.of<AnalyticsProvider>(
                                context,
                                listen: false,
                              ).fetchAnalyticsData(range: range);
                            }
                          },
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusMedium,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildStatCard(
                            theme,
                            'Longest Streak',
                            '$longestStreak days',
                            Icons.emoji_events,
                            Colors.blue,
                          ),
                          const SizedBox(width: 12),
                          _buildStatCard(
                            theme,
                            'Most Productive',
                            _formatMostProductiveDay(mostProductiveDay),
                            Icons.trending_up,
                            Colors.green,
                          ),
                          const SizedBox(width: 12),
                          _buildStatCard(
                            theme,
                            'Avg. Check-in',
                            avgCheckIn,
                            Icons.access_time,
                            Colors.amber,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusLarge,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              chartTitle,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            const SizedBox(height: 16),
                            // Make chart horizontally scrollable for longer ranges to prevent label crowding
                            workHours.length > 14
                                ? Builder(
                                    builder: (context) {
                                      // Trigger auto-scroll after build - use a key to trigger on data change
                                      WidgetsBinding.instance
                                          .addPostFrameCallback((_) {
                                            _scrollChartToEnd(workHours.length);
                                          });
                                      return SingleChildScrollView(
                                        key: ValueKey(
                                          '${workHours.length}_$selectedRange',
                                        ), // Rebuild when data changes
                                        controller: _chartScrollController,
                                        scrollDirection: Axis.horizontal,
                                        child: SizedBox(
                                          width:
                                              workHours.length *
                                              35.0, // 35px per day for better spacing
                                          child: ClipRect(
                                            child: SizedBox(
                                              height: 200,
                                              child: _buildLineChart(
                                                theme,
                                                filteredWorkHours,
                                                xLabels,
                                                labelInterval,
                                                useShortLabels,
                                                yAxisMax,
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  )
                                : ClipRect(
                                    child: SizedBox(
                                      height: 200,
                                      child: _buildLineChart(
                                        theme,
                                        filteredWorkHours,
                                        xLabels,
                                        labelInterval,
                                        useShortLabels,
                                        yAxisMax,
                                      ),
                                    ),
                                  ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusLarge,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Attendance Breakdown',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              height: 140,
                              child: PieChart(
                                PieChartData(
                                  sections: [
                                    PieChartSectionData(
                                      value: present,
                                      color: Colors.green,
                                      title: percent(present),
                                      radius: 50,
                                      titleStyle: theme.textTheme.bodyLarge
                                          ?.copyWith(
                                            color: Colors.black,
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                    PieChartSectionData(
                                      value: absent,
                                      color: Colors.red,
                                      title: percent(absent),
                                      radius: 50,
                                      titleStyle: theme.textTheme.bodyLarge
                                          ?.copyWith(
                                            color: Colors.black,
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                    PieChartSectionData(
                                      value: leave,
                                      color: Colors.amber,
                                      title: percent(leave),
                                      radius: 50,
                                      titleStyle: theme.textTheme.bodyLarge
                                          ?.copyWith(
                                            color: Colors.black,
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                  ],
                                  sectionsSpace: 2,
                                  centerSpaceRadius: 32,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _buildLegendDot(Colors.green),
                                const SizedBox(width: 4),
                                const Text('Present'),
                                const SizedBox(width: 16),
                                _buildLegendDot(Colors.red),
                                const SizedBox(width: 4),
                                const Text('Absent'),
                                const SizedBox(width: 16),
                                _buildLegendDot(Colors.amber),
                                const SizedBox(width: 4),
                                const Text('Leave'),
                              ],
                            ),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Divider(thickness: 1, height: 32),
                    Text(
                      'Attendance Insights',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    AnimatedOpacity(
                      opacity: loadingExtra ? 0.5 : 1.0,
                      duration: const Duration(milliseconds: 500),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (loadingExtra)
                            Center(
                              child: SpinKitThreeBounce(
                                color: theme.colorScheme.primary,
                                size: 32.0,
                              ),
                            ),
                          if (extraError != null)
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Text(
                                  'Error: $extraError',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: AppTheme.error,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          // Show message if analytics feature is not enabled
                          if (!loadingExtra &&
                              extraError == null &&
                              lateCheckins == null &&
                              avgCheckout == null &&
                              recentActivity == null)
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.info_outline,
                                      size: 48,
                                      color: Colors.grey[400],
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'Analytics feature is not enabled for this company',
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(color: Colors.grey[600]),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Please contact your administrator to enable this feature.',
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(color: Colors.grey[500]),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          if (!loadingExtra &&
                              extraError == null &&
                              (lateCheckins != null ||
                                  avgCheckout != null ||
                                  recentActivity != null)) ...[
                            Card(
                              elevation: 3,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppTheme.radiusLarge,
                                ),
                              ),
                              margin: const EdgeInsets.symmetric(
                                vertical: 8,
                                horizontal: 0,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                  horizontal: 20,
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: AppTheme.error
                                          .withValues(alpha: 0.1),
                                      child: Icon(
                                        Icons.access_time,
                                        color: AppTheme.error,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Late Check-ins (last 30 days)',
                                            style: theme.textTheme.bodyLarge
                                                ?.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                          ),
                                          Text(
                                            '${lateCheckins?['lateCount'] ?? 0} times',
                                            style: theme.textTheme.bodyMedium
                                                ?.copyWith(
                                                  color: Colors.grey[700],
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    lateCheckins?['lateDates'] != null &&
                                            (lateCheckins!['lateDates'] as List)
                                                .isNotEmpty
                                        ? IconButton(
                                            icon: Icon(
                                              Icons.info_outline,
                                              color: Colors.grey[600],
                                            ),
                                            onPressed: () {
                                              showDialog(
                                                context: context,
                                                builder: (_) {
                                                  final lateCheckinsList =
                                                      lateCheckins!['lateCheckins']
                                                          as List?;
                                                  if (lateCheckinsList !=
                                                          null &&
                                                      lateCheckinsList
                                                          .isNotEmpty) {
                                                    // Show dates with check-in times
                                                    return AlertDialog(
                                                      title: const Text(
                                                        'Late Check-in Details',
                                                      ),
                                                      content: SingleChildScrollView(
                                                        child: Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          mainAxisSize:
                                                              MainAxisSize.min,
                                                          children: lateCheckinsList.map<Widget>((
                                                            item,
                                                          ) {
                                                            final date =
                                                                item['date'] ??
                                                                '';
                                                            final time =
                                                                item['checkInTime'] ??
                                                                '';
                                                            return Padding(
                                                              padding:
                                                                  const EdgeInsets.symmetric(
                                                                    vertical:
                                                                        4.0,
                                                                  ),
                                                              child: Text(
                                                                '$date - $time',
                                                              ),
                                                            );
                                                          }).toList(),
                                                        ),
                                                      ),
                                                    );
                                                  } else {
                                                    // Fallback to dates only if new format not available
                                                    return AlertDialog(
                                                      title: const Text(
                                                        'Late Check-in Dates',
                                                      ),
                                                      content: Text(
                                                        (lateCheckins!['lateDates']
                                                                    as List?)
                                                                ?.join('\n') ??
                                                            'No late check-ins',
                                                      ),
                                                    );
                                                  }
                                                },
                                              );
                                            },
                                          )
                                        : const SizedBox.shrink(),
                                  ],
                                ),
                              ),
                            ),
                            Card(
                              elevation: 3,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppTheme.radiusLarge,
                                ),
                              ),
                              margin: const EdgeInsets.symmetric(
                                vertical: 8,
                                horizontal: 0,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                  horizontal: 20,
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: AppTheme.primary
                                          .withValues(alpha: 0.1),
                                      child: Icon(
                                        Icons.logout,
                                        color: AppTheme.primary,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Average Check-out Time',
                                            style: theme.textTheme.bodyLarge
                                                ?.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                          ),
                                          Text(
                                            avgCheckout?['avgCheckOut'] ??
                                                '--:--',
                                            style: theme.textTheme.bodyMedium
                                                ?.copyWith(
                                                  color: Colors.grey[700],
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Card(
                              elevation: 3,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppTheme.radiusLarge,
                                ),
                              ),
                              margin: const EdgeInsets.symmetric(
                                vertical: 8,
                                horizontal: 0,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                  horizontal: 20,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Recent Attendance Activity',
                                      style: theme.textTheme.bodyLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                    const SizedBox(height: 8),
                                    if (recentActivity == null ||
                                        recentActivity!.isEmpty)
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12.0,
                                        ),
                                        child: Text(
                                          'No recent activity found.',
                                          style: theme.textTheme.bodyMedium
                                              ?.copyWith(color: Colors.grey),
                                        ),
                                      )
                                    else
                                      ...recentActivity!.map(
                                        (rec) => ListTile(
                                          contentPadding: EdgeInsets.zero,
                                          title: Text(
                                            _formatDateWithDay(rec['date']),
                                            style: theme.textTheme.bodyMedium
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w500,
                                                ),
                                          ),
                                          subtitle: Text(
                                            'Check-in: ${_formatTimeOnly(rec['checkInTime'])} | Check-out: ${_formatTimeOnly(rec['checkOutTime'])}',
                                            style: theme.textTheme.bodyMedium
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w500,
                                                  color: theme
                                                      .colorScheme
                                                      .onSurface
                                                      .withValues(alpha: 0.8),
                                                ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Divider(thickness: 1, height: 32),
                    SizedBox(
                      height: 60,
                      child: Center(
                        child: Text(
                          'More charts and insights will appear here.',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.6,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
        },
      ),
    );
  }

  String _formatTimeOnly(dynamic timeField) {
    if (timeField == null) return '--:--';

    // If it's already a formatted string (from backend), return as is
    if (timeField is String &&
        timeField.contains(':') &&
        !timeField.contains('T')) {
      return timeField;
    }

    // If it's a DateTime object or ISO string, parse and format
    try {
      final time = DateTime.parse(timeField.toString());
      // Convert to user's timezone but don't show timezone info
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final companyProvider = Provider.of<CompanyProvider>(
        context,
        listen: false,
      );
      final user = authProvider.user;
      final company = companyProvider.currentCompany?.toJson();

      // Use TimeUtils to format with proper timezone and company settings
      return TimeUtils.formatTimeOnly(time, user: user, company: company);
    } catch (e) {
      return '--:--';
    }
  }

  String _formatDateWithDay(dynamic dateField) {
    if (dateField == null) return 'N/A';

    try {
      final date = DateTime.parse(dateField.toString());
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final companyProvider = Provider.of<CompanyProvider>(
        context,
        listen: false,
      );
      final user = authProvider.user;
      final company = companyProvider.currentCompany?.toJson();

      // Convert to effective timezone (company timezone)
      final userDate = TimeUtils.convertToEffectiveTimezone(
        date,
        user,
        company,
      );

      // Format as "Day, Date" using company's date format
      final dayName = DateFormat('EEEE').format(userDate);
      final dateStr = TimeUtils.formatReadableDate(
        userDate,
        user: user,
        company: company,
      );
      return '$dayName, $dateStr';
    } catch (e) {
      return 'N/A';
    }
  }

  String _formatMostProductiveDay(String? dateString) {
    if (dateString == null || dateString == 'N/A') return 'N/A';

    try {
      final date = DateTime.parse(dateString);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final companyProvider = Provider.of<CompanyProvider>(
        context,
        listen: false,
      );
      final user = authProvider.user;
      final company = companyProvider.currentCompany?.toJson();

      // Convert to effective timezone (company timezone)
      final userDate = TimeUtils.convertToEffectiveTimezone(
        date,
        user,
        company,
      );

      // Format using company's date format for better readability
      return TimeUtils.formatReadableDate(
        userDate,
        user: user,
        company: company,
      );
    } catch (e) {
      return 'N/A';
    }
  }

  Widget _buildLineChart(
    ThemeData theme,
    List<double> filteredWorkHours,
    List<String> xLabels,
    int labelInterval,
    bool useShortLabels,
    double yAxisMax,
  ) {
    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                if (value == meta.min || value == meta.max) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: Text(
                    value.toInt().toString(),
                    style: theme.textTheme.bodySmall?.copyWith(fontSize: 10),
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: useShortLabels ? 30 : 35,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                // Only show labels at intervals to prevent overlapping
                if (idx >= 0 &&
                    idx < xLabels.length &&
                    idx % labelInterval == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      xLabels[idx],
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: useShortLabels ? 10 : 9,
                        fontWeight: useShortLabels
                            ? FontWeight.w500
                            : FontWeight.normal,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
              interval: labelInterval.toDouble(),
            ),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: (filteredWorkHours.length - 1).toDouble(),
        minY: 0,
        maxY: yAxisMax,
        lineBarsData: [
          LineChartBarData(
            spots: List.generate(
              filteredWorkHours.length,
              (i) => FlSpot(i.toDouble(), filteredWorkHours[i]),
            ),
            isCurved: true,
            color: theme.colorScheme.primary,
            barWidth: 4,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: theme.colorScheme.primary.withValues(alpha: 0.15),
              cutOffY: yAxisMax,
            ),
            showingIndicators: List.generate(
              filteredWorkHours.length,
              (i) => i,
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          enabled: true,
          touchTooltipData: LineTouchTooltipData(
            tooltipBgColor: Colors.white,
            tooltipRoundedRadius: 8,
            tooltipPadding: const EdgeInsets.all(AppTheme.spacingS),
            tooltipMargin: 8,
            getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
              return touchedBarSpots.map((barSpot) {
                return LineTooltipItem(
                  '${barSpot.y.toStringAsFixed(1)} hours',
                  AppTheme.bodyMedium.copyWith(
                    color: Colors.black87,
                    fontWeight: FontWeight.bold,
                  ),
                );
              }).toList();
            },
          ),
        ),
      ),
    );
  }

  Widget _buildLegendDot(Color color) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }

  Widget _buildStatCard(
    ThemeData theme,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      ),
      child: Container(
        width: 110,
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.15),
              radius: 22,
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _monthName(int month) {
    const months = [
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
    return months[month - 1];
  }
}
