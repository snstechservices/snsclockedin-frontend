import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../../tutorial/tutorial_service.dart';
import '../../widgets/admin_side_navigation.dart';
import '../../providers/feature_provider.dart';
import '../../services/global_notification_service.dart';

class TutorialCenterScreen extends StatefulWidget {
  const TutorialCenterScreen({super.key});

  @override
  State<TutorialCenterScreen> createState() => _TutorialCenterScreenState();
}

class _TutorialCenterScreenState extends State<TutorialCenterScreen> {
  final Map<String, Map<String, dynamic>> _tutorials = const {
    'app_navigation_coach_seen_v1': {
      'title': 'App Navigation Basics',
      'description':
          'Learn the fundamentals of navigating the app, understanding the sidebar menu, and accessing different sections efficiently.',
      'icon': Icons.navigation,
      'color': Colors.blue,
      'route': '/admin_dashboard',
      'estimatedTime': '3-5 minutes',
      'difficulty': 'Beginner',
      'category': 'Basic',
      'subscription': 'basic',
      'feature': 'basicTutorials',
    },
    'dashboard_overview_coach_seen_v1': {
      'title': 'Dashboard Overview',
      'description':
          'Master the admin dashboard, understand key metrics, quick actions, and how to interpret the overview data.',
      'icon': Icons.dashboard,
      'color': Colors.indigo,
      'route': '/admin_dashboard',
      'estimatedTime': '4-6 minutes',
      'difficulty': 'Beginner',
      'category': 'Basic',
      'subscription': 'basic',
      'feature': 'basicTutorials',
    },
    'employee_mgmt_coach_seen_v1': {
      'title': 'Employee Management',
      'description':
          'Learn how to add, edit, and manage employee records, view employee details, and handle employee lifecycle.',
      'icon': Icons.people,
      'color': Colors.green,
      'route': '/employee_management_with_coach',
      'estimatedTime': '8-12 minutes',
      'difficulty': 'Intermediate',
      'category': 'Core Features',
      'subscription': 'professional',
      'feature': 'coreFeatureTutorials',
    },
    'attendance_mgmt_coach_seen_v1': {
      'title': 'Attendance Management',
      'description':
          'Track employee attendance, view timesheets, manage work schedules, and analyze attendance patterns.',
      'icon': Icons.access_time,
      'color': Colors.orange,
      'route': '/attendance_management_with_coach',
      'estimatedTime': '10-15 minutes',
      'difficulty': 'Intermediate',
      'category': 'Core Features',
      'subscription': 'professional',
      'feature': 'coreFeatureTutorials',
    },
    'leave_mgmt_coach_seen_v1': {
      'title': 'Leave Management',
      'description':
          'Master leave request approvals, configure leave policies, and manage employee time-off requests efficiently.',
      'icon': Icons.calendar_today,
      'color': Colors.teal,
      'route': '/leave_management_with_coach',
      'estimatedTime': '6-10 minutes',
      'difficulty': 'Intermediate',
      'category': 'Core Features',
      'subscription': 'professional',
      'feature': 'coreFeatureTutorials',
    },
    'payroll_mgmt_coach_seen_v1': {
      'title': 'Payroll Management',
      'description':
          'Generate payroll reports, manage salary structures, handle employee compensation, and tax calculations.',
      'icon': Icons.account_balance_wallet,
      'color': Colors.purple,
      'route': '/payroll_management_with_coach',
      'estimatedTime': '12-18 minutes',
      'difficulty': 'Advanced',
      'category': 'Core Features',
      'subscription': 'enterprise',
      'feature': 'coreFeatureTutorials',
    },
    'company_settings_coach_seen_v1': {
      'title': 'Company Settings',
      'description':
          'Configure company policies, working hours, holidays, organizational structure, and system preferences.',
      'icon': Icons.business,
      'color': Colors.brown,
      'route': '/company_settings_with_coach',
      'estimatedTime': '8-12 minutes',
      'difficulty': 'Intermediate',
      'category': 'Configuration',
      'subscription': 'professional',
      'feature': 'configurationTutorials',
    },
    'break_management_coach_seen_v1': {
      'title': 'Break Management',
      'description':
          'Set up break types, configure break policies, and manage employee break schedules and compliance.',
      'icon': Icons.coffee,
      'color': Colors.amber,
      'route': '/break_management',
      'estimatedTime': '5-8 minutes',
      'difficulty': 'Beginner',
      'category': 'Configuration',
      'subscription': 'basic',
      'feature': 'configurationTutorials',
    },
    'location_mgmt_coach_seen_v1': {
      'title': 'Location Management',
      'description':
          'Manage office locations, set up geofencing, and configure location-based attendance tracking.',
      'icon': Icons.location_on,
      'color': Colors.red,
      'route': '/location_management',
      'estimatedTime': '6-10 minutes',
      'difficulty': 'Intermediate',
      'category': 'Configuration',
      'subscription': 'enterprise',
      'feature': 'configurationTutorials',
    },
    'training_mgmt_coach_seen_v1': {
      'title': 'Training Management',
      'description':
          'Create training programs, assign courses to employees, track progress, and manage certifications.',
      'icon': Icons.school,
      'color': Colors.cyan,
      'route': '/training_management',
      'estimatedTime': '8-12 minutes',
      'difficulty': 'Intermediate',
      'category': 'Advanced Features',
      'subscription': 'enterprise',
      'feature': 'advancedFeatureTutorials',
    },
    'expense_mgmt_coach_seen_v1': {
      'title': 'Expense Management',
      'description':
          'Set up expense categories, approve employee expense reports, and manage company spending.',
      'icon': Icons.receipt,
      'color': Colors.deepOrange,
      'route': '/expense_management',
      'estimatedTime': '6-10 minutes',
      'difficulty': 'Intermediate',
      'category': 'Advanced Features',
      'subscription': 'enterprise',
      'feature': 'advancedFeatureTutorials',
    },
    'analytics_reports_coach_seen_v1': {
      'title': 'Analytics & Reports',
      'description':
          'Generate comprehensive reports, analyze employee performance, and create custom dashboards.',
      'icon': Icons.analytics,
      'color': Colors.deepPurple,
      'route': '/admin_dashboard',
      'estimatedTime': '10-15 minutes',
      'difficulty': 'Advanced',
      'category': 'Advanced Features',
      'subscription': 'enterprise',
      'feature': 'advancedFeatureTutorials',
    },
    'notification_alerts_coach_seen_v1': {
      'title': 'Notification System',
      'description':
          'Configure alert settings, manage notification preferences, and set up automated reminders.',
      'icon': Icons.notifications,
      'color': Colors.pink,
      'route': '/admin/notification_alerts',
      'estimatedTime': '4-6 minutes',
      'difficulty': 'Beginner',
      'category': 'Configuration',
      'subscription': 'professional',
      'feature': 'configurationTutorials',
    },
    'feature_settings_coach_seen_v1': {
      'title': 'Feature Management',
      'description':
          'Enable/disable app features, configure module settings, and customize the app experience.',
      'icon': Icons.settings,
      'color': Colors.grey,
      'route': '/admin/feature_settings',
      'estimatedTime': '5-8 minutes',
      'difficulty': 'Intermediate',
      'category': 'Configuration',
      'subscription': 'enterprise',
      'feature': 'configurationTutorials',
    },
  };

  late Future<Map<String, bool>> _statusFuture;
  bool _isResetting = false;

  // Get accessible tutorials based on subscription
  Map<String, Map<String, dynamic>> getAccessibleTutorials(
    BuildContext context,
  ) {
    final featureProvider = Provider.of<FeatureProvider>(
      context,
      listen: false,
    );

    return Map.fromEntries(
      _tutorials.entries.where((entry) {
        final tutorial = entry.value;
        final requiredFeature = tutorial['feature'] as String?;
        final requiredSubscription = tutorial['subscription'] as String?;

        // Check if the required feature is enabled
        if (requiredFeature != null) {
          final hasFeature = featureProvider.isFeatureEnabled(requiredFeature);
          if (!hasFeature) return false;
        }

        // Check subscription level
        if (requiredSubscription != null) {
          switch (requiredSubscription) {
            case 'basic':
              return true; // Basic tutorials available to all
            case 'professional':
              return featureProvider.isProfessionalPlan ||
                  featureProvider.isEnterprisePlan;
            case 'enterprise':
              return featureProvider.isEnterprisePlan;
            default:
              return true;
          }
        }

        return true;
      }),
    );
  }

  // Check if tutorial center is accessible
  bool isTutorialCenterAccessible(BuildContext context) {
    final featureProvider = Provider.of<FeatureProvider>(
      context,
      listen: false,
    );
    return featureProvider.hasTutorialCenter;
  }

  @override
  void initState() {
    super.initState();
    _statusFuture = _loadStatus();
  }

  Future<Map<String, bool>> _loadStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final map = <String, bool>{};
    for (final k in _tutorials.keys) {
      // Check if the tutorial has been seen/completed
      map[k] = prefs.getBool(k) ?? false;
    }
    return map;
  }

  /// Mark a tutorial as complete
  Future<void> _markTutorialComplete(String key) async {
    await TutorialService.setSeen(key, seen: true);
    setState(() {
      _statusFuture = _loadStatus();
    });
  }

  Future<void> _reset(String key) async {
    await TutorialService.setSeen(key, seen: false);
    setState(() {
      _statusFuture = _loadStatus();
    });

    if (mounted) {
      GlobalNotificationService().showWarning(
        '${_tutorials[key]?['title']} tutorial has been reset',
      );
    }
  }

  Future<void> _resetAll() async {
    setState(() {
      _isResetting = true;
    });

    await TutorialService.resetAll();
    setState(() {
      _statusFuture = _loadStatus();
      _isResetting = false;
    });

    if (mounted) {
      GlobalNotificationService().showSuccess(
        'All tutorials have been reset successfully!',
      );
    }
  }

  void _navigateToTutorial(String route) {
    // Show helpful message before navigating
    GlobalNotificationService().showInfo(
      'Starting tutorial! Look for highlighted elements and helpful tips.',
    );

    // Navigate to the tutorial-enabled screen
    Navigator.of(context).pushNamed(route);
  }

  // Build subscription required view
  Widget _buildSubscriptionRequiredView(
    BuildContext context,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline, size: 80, color: colorScheme.primary),
            const SizedBox(height: 24),
            Text(
              'Tutorial Center',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'This feature requires a premium subscription plan.',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'To access comprehensive tutorials and learning resources, please upgrade your subscription in Company Settings.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                // Navigate to company settings where subscription can be managed
                Navigator.of(context).pushNamed('/admin/company_settings');
              },
              icon: const Icon(Icons.settings),
              label: const Text('Go to Company Settings'),
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: () {
                // Navigate back to admin dashboard
                Navigator.of(context).pop();
              },
              icon: const Icon(Icons.arrow_back),
              label: const Text('Back to Dashboard'),
              style: TextButton.styleFrom(foregroundColor: colorScheme.primary),
            ),
          ],
        ),
      ),
    );
  }

  // Get subscription color
  Color _getSubscriptionColor(String? subscription) {
    switch (subscription) {
      case 'basic':
        return Colors.green;
      case 'professional':
        return Colors.blue;
      case 'enterprise':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  // Get subscription label
  String _getSubscriptionLabel(String? subscription) {
    switch (subscription) {
      case 'basic':
        return 'BASIC';
      case 'professional':
        return 'PRO';
      case 'enterprise':
        return 'ENTERPRISE';
      default:
        return 'FREE';
    }
  }

  // Check if tutorial is accessible with current subscription
  bool _isTutorialAccessible(String? requiredSubscription) {
    if (requiredSubscription == null) return true;

    final featureProvider = Provider.of<FeatureProvider>(
      context,
      listen: false,
    );

    switch (requiredSubscription) {
      case 'basic':
        return true; // Basic tutorials available to all
      case 'professional':
        return featureProvider.isProfessionalPlan ||
            featureProvider.isEnterprisePlan;
      case 'enterprise':
        return featureProvider.isEnterprisePlan;
      default:
        return true;
    }
  }

  // Show upgrade prompt for locked tutorials
  void _showUpgradePrompt(BuildContext context, String? requiredSubscription) {
    final planName = _getSubscriptionLabel(requiredSubscription);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.lock_outline, color: Colors.orange),
            const SizedBox(width: 8),
            Text('Premium Tutorial'),
          ],
        ),
        content: Text(
          'This tutorial requires a $planName subscription plan. Upgrade your subscription to access advanced learning resources and unlock the full potential of the app.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pushNamed('/super_admin/subscriptions');
            },
            icon: const Icon(Icons.upgrade),
            label: const Text('Upgrade'),
          ),
        ],
      ),
    );
  }

  Widget _buildTutorialCard({
    required String key,
    required Map<String, dynamic> data,
    required bool isCompleted,
    required VoidCallback onStart,
    required VoidCallback onReset,
    required VoidCallback onMarkComplete,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final color = data['color'] as Color;
    final icon = data['icon'] as IconData;
    final title = data['title'] as String;
    final difficulty = data['difficulty'] as String;

    return Container(
      decoration: BoxDecoration(
        color: isCompleted
            ? color.withValues(alpha: 0.05)
            : colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isCompleted
              ? color.withValues(alpha: 0.3)
              : colorScheme.outlineVariant,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.05),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon and Title Row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(icon, color: color, size: 16),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                      fontSize: 12,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 6),

            // Status, Difficulty, and Subscription Row
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Status indicator
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: isCompleted
                            ? Colors.green.withValues(alpha: 0.1)
                            : Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        isCompleted ? '✓' : '○',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: isCompleted
                              ? Colors.green.shade700
                              : Colors.orange.shade700,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    // Difficulty
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        difficulty,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: color,
                          fontWeight: FontWeight.w600,
                          fontSize: 9,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                // Subscription requirement badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: _getSubscriptionColor(
                      data['subscription'] as String?,
                    ).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _getSubscriptionLabel(data['subscription'] as String?),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: _getSubscriptionColor(
                        data['subscription'] as String?,
                      ),
                      fontWeight: FontWeight.w600,
                      fontSize: 8,
                    ),
                  ),
                ),
              ],
            ),

            const Spacer(),

            // Action Button
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: _isTutorialAccessible(data['subscription'] as String?)
                  ? (isCompleted
                        ? OutlinedButton(
                            onPressed: onStart,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: color,
                              side: BorderSide(color: color),
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              minimumSize: const Size(0, 28),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            child: const Text(
                              'Review',
                              style: TextStyle(fontSize: 11),
                            ),
                          )
                        : ElevatedButton(
                            onPressed: onStart,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: color,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              minimumSize: const Size(0, 28),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            child: const Text(
                              'Start',
                              style: TextStyle(fontSize: 11),
                            ),
                          ))
                  : OutlinedButton(
                      onPressed: () => _showUpgradePrompt(
                        context,
                        data['subscription'] as String?,
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey,
                        side: const BorderSide(color: Colors.grey),
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        minimumSize: const Size(0, 28),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      child: const Text(
                        'Upgrade',
                        style: TextStyle(fontSize: 11),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Consumer<FeatureProvider>(
      builder: (context, featureProvider, child) {
        // Check if tutorial center feature is enabled
        if (!featureProvider.hasTutorialCenter) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Tutorial Center'),
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
              elevation: 0,
            ),
            drawer: const AdminSideNavigation(currentRoute: '/tutorial_center'),
            body: _buildSubscriptionRequiredView(context, theme, colorScheme),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Tutorial Center'),
            backgroundColor: colorScheme.primary,
            foregroundColor: colorScheme.onPrimary,
            elevation: 0,
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _isResetting
                    ? null
                    : () => setState(() {
                        _statusFuture = _loadStatus();
                      }),
                tooltip: 'Refresh Tutorial Status',
              ),
            ],
          ),
          drawer: const AdminSideNavigation(currentRoute: '/tutorial_center'),
          body: Container(
            color: colorScheme.surfaceContainerHighest,
            child: FutureBuilder<Map<String, bool>>(
              future: _statusFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 64,
                          color: colorScheme.error,
                        ),
                        const SizedBox(height: 16),
                        Text('Error loading tutorials: ${snapshot.error}'),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => setState(() {
                            _statusFuture = _loadStatus();
                          }),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                final status = snapshot.data ?? {};
                final accessibleTutorials = getAccessibleTutorials(context);
                final completedCount = status.entries
                    .where(
                      (entry) =>
                          accessibleTutorials.containsKey(entry.key) &&
                          entry.value,
                    )
                    .length;
                final totalCount = accessibleTutorials.length;
                final progress = totalCount > 0
                    ? completedCount / totalCount
                    : 0.0;

                // Group accessible tutorials by category
                final groupedTutorials =
                    <String, List<MapEntry<String, Map<String, dynamic>>>>{};
                for (final entry in accessibleTutorials.entries) {
                  final category = entry.value['category'] as String;
                  groupedTutorials.putIfAbsent(category, () => []).add(entry);
                }

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Progress Header
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              colorScheme.primary,
                              colorScheme.primary.withValues(alpha: 0.8),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: colorScheme.primary.withValues(alpha: 0.3),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.school,
                                  color: colorScheme.onPrimary,
                                  size: 32,
                                ),
                                const SizedBox(height: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Master Your Admin Dashboard',
                                        style: theme.textTheme.headlineSmall
                                            ?.copyWith(
                                              color: colorScheme.onPrimary,
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Complete tutorials to unlock the full potential of your admin tools',
                                        style: theme.textTheme.bodyLarge
                                            ?.copyWith(
                                              color: colorScheme.onPrimary
                                                  .withValues(alpha: 0.9),
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Overall Progress',
                                        style: theme.textTheme.titleMedium
                                            ?.copyWith(
                                              color: colorScheme.onPrimary
                                                  .withValues(alpha: 0.9),
                                            ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        '$completedCount of $totalCount tutorials completed',
                                        style: theme.textTheme.bodyLarge
                                            ?.copyWith(
                                              color: colorScheme.onPrimary,
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '${(progress * 100).toInt()}%',
                                      style: theme.textTheme.headlineMedium
                                          ?.copyWith(
                                            color: colorScheme.onPrimary,
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                    Text(
                                      'Complete',
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            color: colorScheme.onPrimary
                                                .withValues(alpha: 0.8),
                                          ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            LinearProgressIndicator(
                              value: progress,
                              backgroundColor: colorScheme.onPrimary.withValues(
                                alpha: 0.3,
                              ),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                colorScheme.onPrimary,
                              ),
                              minHeight: 8,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Tutorial Categories
                      ...groupedTutorials.entries.map((categoryEntry) {
                        final categoryName = categoryEntry.key;
                        final tutorials = categoryEntry.value;
                        final categoryCompleted = tutorials
                            .where((tutorial) => status[tutorial.key] == true)
                            .length;
                        final categoryProgress = tutorials.isNotEmpty
                            ? categoryCompleted / tutorials.length
                            : 0.0;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Category Header
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _getCategoryColor(categoryName),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      categoryName,
                                      style: theme.textTheme.labelLarge
                                          ?.copyWith(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Text(
                                      '$categoryCompleted of ${tutorials.length} completed',
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            color: colorScheme.onSurfaceVariant,
                                          ),
                                    ),
                                  ),
                                  Text(
                                    '${(categoryProgress * 100).toInt()}%',
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(
                                          color: _getCategoryColor(
                                            categoryName,
                                          ),
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // Tutorials Grid
                              GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 2, // 2 columns for mobile
                                      childAspectRatio:
                                          1.8, // Much taller for better content fit
                                      crossAxisSpacing: 8, // Minimal spacing
                                      mainAxisSpacing: 8, // Minimal spacing
                                    ),
                                itemCount: tutorials.length,
                                itemBuilder: (context, index) {
                                  final tutorial = tutorials[index];
                                  final key = tutorial.key;
                                  final data = tutorial.value;
                                  final isCompleted = status[key] ?? false;

                                  return _buildTutorialCard(
                                    key: key,
                                    data: data,
                                    isCompleted: isCompleted,
                                    onStart: () =>
                                        _navigateToTutorial(data['route']),
                                    onReset: () => _reset(key),
                                    onMarkComplete: () =>
                                        _markTutorialComplete(key),
                                  );
                                },
                              ),
                            ],
                          ),
                        );
                      }),

                      const SizedBox(height: 32),

                      // Quick Actions
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: colorScheme.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: colorScheme.outlineVariant),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Quick Actions',
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: _isResetting ? null : _resetAll,
                                    icon: _isResetting
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Icon(Icons.refresh),
                                    label: Text(
                                      _isResetting
                                          ? 'Resetting...'
                                          : 'Reset All Tutorials',
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          colorScheme.errorContainer,
                                      foregroundColor:
                                          colorScheme.onErrorContainer,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () => setState(() {
                                      _statusFuture = _loadStatus();
                                    }),
                                    icon: const Icon(Icons.download),
                                    label: const Text('Export Progress'),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'Basic':
        return Colors.blue;
      case 'Core Features':
        return Colors.green;
      case 'Configuration':
        return Colors.orange;
      case 'Advanced Features':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }
}
