// EmployeeDashboardScreen
// ----------------------
// Main dashboard for employees.
// - Shows user info, live clock, status, quick actions, and attendance summary.
// - All data is dynamic and ready for backend integration.
// - Modular: uses widgets from widgets/dashboard/ and models/services.
//
// To connect to backend, use AttendanceService and Employee model.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'dart:async'; // Add this for TimeoutException
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../../utils/time_utils.dart';
import '../../providers/attendance_provider.dart';
import '../../providers/company_provider.dart';
import '../../providers/profile_provider.dart';
import '../../widgets/app_drawer.dart';
import '../../providers/auth_provider.dart';
import '../../config/api_config.dart';
import '../../../widgets/user_avatar.dart';

import '../../widgets/admin_side_navigation.dart';
import '../../widgets/shared_app_bar.dart';
// Coach features disabled for this company
// import 'employee_dashboard_with_coach.dart'
//     show EmployeeDashboardWithCoachMarks;

import '../../services/global_notification_service.dart';
import '../../services/connectivity_service.dart';
import '../../services/api_service.dart';
import '../../api/exceptions.dart' as api_exceptions;
import '../../services/haptic_feedback_service.dart';
import '../../services/action_sound_service.dart';
import '../../services/clock_in_reminder_service.dart';

import '../../widgets/real_time_break_timer.dart';

import 'package:sns_rooster/providers/feature_provider.dart';
import '../../widgets/employee_location_map_widget.dart';

import 'package:sns_rooster/utils/logger.dart';
import '../../widgets/dashboard/dashboard_overview_tile.dart';
import '../../theme/app_theme.dart';
import '../../utils/theme_utils.dart';
import '../onboarding/setup_guide_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

String _formatDuration(Duration duration) {
  final totalMinutes = duration.inMinutes;
  if (totalMinutes >= 60) {
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    return '${hours}h ${minutes}m';
  } else {
    return '${totalMinutes}m';
  }
}

/// EmployeeDashboardScreen displays the main dashboard for employees.
//
/// - Shows user info, live clock, status, quick actions, and attendance summary.
/// - Fetches backend data only on load, after check-in/out, or on user action.
/// - Uses [LiveClock] widget to update the clock every second without rebuilding the parent widget tree.
class EmployeeDashboardScreen extends StatefulWidget {
  final bool suppressProfilePrompt;
  const EmployeeDashboardScreen({
    super.key,
    this.suppressProfilePrompt = false,
  });

  @override
  State<EmployeeDashboardScreen> createState() =>
      _EmployeeDashboardScreenState();
}

class _EmployeeDashboardScreenState extends State<EmployeeDashboardScreen>
    with RouteAware, WidgetsBindingObserver {
  bool _profileDialogShown = false;
  bool _eventsLoading = false;
  List<Map<String, dynamic>> _upcomingEvents = [];
  bool _isInitialized = false;
  bool _isInitializing = false; // Prevent multiple initialization calls
  bool _isClockInInProgress = false; // Prevent duplicate clock-in calls
  bool _isClockOutInProgress = false; // Prevent duplicate clock-out calls
  bool _isStartBreakInProgress = false; // Prevent duplicate start break calls
  bool _isEndBreakInProgress = false; // Prevent duplicate end break calls
  List<Map<String, dynamic>> _employeeSetupNotifications =
      []; // Track notification data
  bool _notificationsLoading = false; // Track notification loading state
  RouteObserver<ModalRoute<void>>? _routeObserver;
  VoidCallback? _authReadyListener;
  // Track when dashboard first started loading

  @override
  void initState() {
    super.initState();
    // Add lifecycle observer to detect hot restart and app resume
    WidgetsBinding.instance.addObserver(this);

    // Track initial load time for grace period

    // Initialize dashboard only once on first load - ATOMIC operation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // BULLETPROOF: Triple check to prevent any race conditions
      if (!mounted || _isInitialized || _isInitializing) {
        Logger.info('DASHBOARD_INIT: Initialization skipped - already initialized or initializing');
        return;
      }

      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      // If auth and role readiness are already satisfied, initialize immediately.
      if (authProvider.authReady && authProvider.roleReady) {
        Logger.info('DASHBOARD_INIT: Auth & role ready - initializing dashboard');
        _checkProfileCompletion();
        _initializeDashboard();
        _setupConnectivityListener();
        _loadEmployeeSetupNotifications(); // Load notifications on init
        _checkOnboardingStatus(); // Check if user needs onboarding guide
        _checkClockInReminder(); // Check for clock-in reminder

        final userId = authProvider.user?['_id'];
        if (userId != null) {
          _setupDataRetryOnConnectivity(userId);
        }
        return;
      }

      // Otherwise, wait for AuthProvider to become ready before firing protected calls.
      Logger.info('DASHBOARD_INIT: Waiting for auth & role readiness before initializing dashboard');

      _authReadyListener = () {
        if (!mounted) return;
        if (authProvider.authReady && authProvider.roleReady && !_isInitialized && !_isInitializing) {
          // Remove listener and initialize
          try {
            authProvider.removeListener(_authReadyListener!);
          } catch (e) {}
          _checkProfileCompletion();
          _initializeDashboard();
          _setupConnectivityListener();
          _loadEmployeeSetupNotifications();
          _checkOnboardingStatus();
          _checkClockInReminder();

          final userId = authProvider.user?['_id'];
          if (userId != null) {
            _setupDataRetryOnConnectivity(userId);
          }
        }
      };

      authProvider.addListener(_authReadyListener!);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // On hot restart or app resume, ensure data is refreshed
    if (state == AppLifecycleState.resumed && mounted) {
      Logger.info(
        'DASHBOARD_LIFECYCLE: App resumed, checking if data needs refresh',
      );

      // Check if we have auth but no data loaded (hot restart scenario)
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.isAuthenticated && authProvider.user != null) {
        final userId = authProvider.user?['_id'];
        if (userId != null) {
          // If dashboard is initialized but we're resuming, refresh data
          if (_isInitialized) {
            Logger.info(
              'DASHBOARD_LIFECYCLE: Refreshing dashboard data on resume',
            );
            _refreshDashboard();
          } else if (!_isInitializing) {
            // If not initialized yet, try to initialize now
            Logger.info(
              'DASHBOARD_LIFECYCLE: Initializing dashboard on resume',
            );
            _initializeDashboard();
          }
        }
      }
    }
  }

  void _setupConnectivityListener() {
    // Listen to connectivity changes
    final connectivityService = Provider.of<ConnectivityService>(
      context,
      listen: false,
    );
    bool wasOffline = !connectivityService.isFullyOnline;

    connectivityService.addConnectivityListener((isOnline) {
      // Update the offline state tracking
      final previouslyOffline = wasOffline;
      wasOffline = !isOnline;

      // If we just came back online and were previously offline, refresh data
      // IMPORTANT: Retry even if dashboard is not initialized (handles initialization failures)
      if (mounted && isOnline && previouslyOffline) {
        Logger.info(
          'Dashboard: Connectivity restored, refreshing data (initialized: $_isInitialized)',
        );

        // Show connection restored message
        final notificationService = Provider.of<GlobalNotificationService>(
          context,
          listen: false,
        );
        notificationService.showSuccess(
          'Connection restored! Refreshing data...',
          duration: const Duration(seconds: 3),
        );

        // Clear any error states
        final attendanceProvider = Provider.of<AttendanceProvider>(
          context,
          listen: false,
        );
        attendanceProvider.clearErrorState();

        // If dashboard is initialized, refresh it
        if (_isInitialized) {
          _refreshDashboard();
        } else {
          // If not initialized, try to initialize now that we have connectivity
          Logger.info(
            'Dashboard: Connectivity restored but dashboard not initialized, attempting initialization',
          );
          _initializeDashboard();
        }
      }
    });
  }

  /// Set up retry mechanism when connectivity is restored after initial fetch failure
  void _setupDataRetryOnConnectivity(String userId) {
    final connectivityService = Provider.of<ConnectivityService>(
      context,
      listen: false,
    );
    bool wasOffline = !connectivityService.isFullyOnline;

    connectivityService.addConnectivityListener((isOnline) {
      final previouslyOffline = wasOffline;
      wasOffline = !isOnline;

      // Retry when connectivity is restored, even if dashboard initialization failed
      if (mounted && isOnline && previouslyOffline) {
        Logger.info(
          'Dashboard: Connectivity restored, auto-retrying data fetch for user $userId',
        );

        // Retry fetching essential data after a short delay
        Future.delayed(const Duration(seconds: 1), () async {
          if (mounted) {
            try {
              final attendanceProvider = Provider.of<AttendanceProvider>(
                context,
                listen: false,
              );
              attendanceProvider.clearErrorState();

              await Future.wait([
                attendanceProvider.fetchTodayStatus(userId),
                attendanceProvider.fetchUserAttendance(userId),
                // Note: fetchAttendanceSummary requires startDate and endDate parameters
                // It should only be called from screens that need summary data (e.g., admin attendance screen)
              ]);

              Logger.info(
                'Dashboard: Data successfully fetched after connectivity restoration',
              );

              // If dashboard wasn't initialized, mark it as initialized now
              if (!_isInitialized && mounted) {
                setState(() {
                  _isInitialized = true;
                  _isInitializing = false;
                });
              }
            } catch (e) {
              Logger.warning(
                'Dashboard: Retry after connectivity restoration failed: $e',
              );
            }
          }
        });
      }
    });
  }

  // Handle drawer state restoration - DISABLED to prevent dashboard resets

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Subscribe to RouteObserver to receive route lifecycle callbacks
    _routeObserver = Provider.of<RouteObserver<ModalRoute<void>>>(
      context,
      listen: false,
    );
    final route = ModalRoute.of(context);
    if (route != null) {
      _routeObserver?.subscribe(this, route);
    }

    // COMPLETELY DISABLED: This was causing dashboard resets when drawer opened
    // The dashboard should only initialize once on first load
    // All subsequent drawer interactions should NOT trigger reinitialization
    log(
      'DRAWER_DEBUG: didChangeDependencies called but initialization disabled to prevent resets',
    );
  }

  /// Show break type selection dialog
  Future<Map<String, dynamic>?> _showBreakTypeDialog() async {
    try {
      // Fetch break types from API
      var breakTypes = await _getBreakTypes();

      if (breakTypes.isEmpty) {
        // Try to initialize default break types if online
        try {
          final attendanceProvider = Provider.of<AttendanceProvider>(
            context,
            listen: false,
          );
          final connectivityService = ConnectivityService();

          if (connectivityService.isFullyOnline) {
            Logger.info(
              'No break types found, attempting to initialize defaults...',
            );
            breakTypes = await attendanceProvider.initializeDefaultBreakTypes();

            if (breakTypes.isEmpty) {
              // Still empty after initialization attempt
              if (mounted) {
                GlobalNotificationService().showError(
                  'No break types available. Please contact your administrator to set up break types.',
                );
              }
              return null;
            }
          } else {
            // Offline and no break types cached
            if (mounted) {
              GlobalNotificationService().showError(
                'Break types are not available offline. Please connect to the internet to load break types.',
              );
            }
            return null;
          }
        } catch (e) {
          Logger.error('Failed to initialize default break types: $e');
          if (mounted) {
            GlobalNotificationService().showError(
              'Unable to load break types. Please contact your administrator.',
            );
          }
          return null;
        }
      }

      // Show break type selection modal
      return await showDialog<Map<String, dynamic>>(
        // ignore: use_build_context_synchronously
        context: context,
        builder: (BuildContext context) {
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
            ),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 400, maxHeight: 600),
              padding: const EdgeInsets.all(AppTheme.spacingL),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.free_breakfast, color: AppTheme.primary),
                      const SizedBox(width: AppTheme.spacingS),
                      Text(
                        'Select Break Type',
                        style: AppTheme.titleLarge.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.spacingL),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: breakTypes.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.only(
                            bottom: AppTheme.spacingM,
                          ),
                          child: _buildBreakTypeOption(breakTypes[index]),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingM),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    } catch (e) {
      Logger.error('Error showing break type dialog: $e');
      // Show error instead of fallback with invalid ID
      if (mounted) {
        GlobalNotificationService().showError(
          'Unable to load break types. Please try again or contact your administrator.',
        );
      }
      return null;
    }
  }

  /// Build break type option widget for selection dialog
  Widget _buildBreakTypeOption(Map<String, dynamic> breakType) {
    final displayName =
        breakType['displayName'] ?? breakType['name'] ?? 'Unknown Break';
    final description = breakType['description'] ?? '';
    final minDuration = breakType['minDuration'] ?? 1;
    final maxDuration = breakType['maxDuration'] ?? 60;
    final colorHex = breakType['color'] ?? '#6B7280';
    final iconName = breakType['icon'] ?? 'free_breakfast';
    final isPaid = breakType['isPaid'] ?? true;

    // Parse color from hex string
    Color color = AppTheme.muted;
    try {
      color = Color(int.parse(colorHex.replaceFirst('#', '0xFF')));
    } catch (e) {
      color = AppTheme.muted;
    }

    // Map icon name to Flutter icon
    IconData icon = Icons.free_breakfast;
    switch (iconName) {
      case 'local_cafe':
      case 'coffee':
        icon = Icons.local_cafe;
        break;
      case 'restaurant':
      case 'lunch_dining':
        icon = Icons.restaurant;
        break;
      case 'chair':
      case 'weekend':
        icon = Icons.chair;
        break;
      case 'person':
      case 'account_circle':
        icon = Icons.person;
        break;
      case 'free_breakfast':
      default:
        icon = Icons.free_breakfast;
        break;
    }

    // Build duration text
    String durationText;
    if (minDuration == maxDuration) {
      durationText = '$minDuration minutes';
    } else {
      durationText = '$minDuration-$maxDuration minutes';
    }

    return InkWell(
      onTap: () => Navigator.of(context).pop(breakType),
      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingL,
          vertical: AppTheme.spacingM,
        ),
        decoration: BoxDecoration(
          border: Border.all(color: AppTheme.muted.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppTheme.spacingS),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: AppTheme.spacingM),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          displayName,
                          style: AppTheme.bodyLarge.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (!isPaid)
                        Container(
                          padding: AppTheme.inputPadding,
                          decoration: BoxDecoration(
                            color: AppTheme.error.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusSmall,
                            ),
                          ),
                          child: Text(
                            'UNPAID',
                            style: AppTheme.smallCaption.copyWith(
                              color: AppTheme.error,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.spacingXs),
                  Text(
                    durationText,
                    style: AppTheme.bodyMedium.copyWith(color: AppTheme.muted),
                  ),
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: AppTheme.spacingXs),
                    Text(
                      description,
                      style: AppTheme.smallCaption.copyWith(
                        color: AppTheme.muted,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: AppTheme.muted, size: 16),
          ],
        ),
      ),
    );
  }

  /// Simplified dashboard initialization - much faster and more responsive
  Future<void> _initializeDashboard() async {
    // BULLETPROOF: Prevent multiple initializations - this should NEVER run twice
    if (_isInitialized || _isInitializing) {
      Logger.info(
        'Dashboard initialization blocked - already initialized or initializing',
      );
      return;
    }

    _isInitializing = true;
    Logger.info('Starting dashboard initialization...');

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      // Wait for auth to be ready (with timeout for hot restart scenarios)
      int retries = 0;
      while (authProvider.user == null && retries < 5) {
        Logger.info(
          'Dashboard: Waiting for auth provider to be ready (attempt ${retries + 1}/5)',
        );
        await Future.delayed(const Duration(milliseconds: 200));
        retries++;
      }

      final userId = authProvider.user?['_id'];

      if (userId == null) {
        Logger.warning(
          'Dashboard: User ID not available after waiting, will retry later',
        );
        // Reset flags to allow retry
        if (mounted) {
          setState(() {
            _isInitializing = false;
          });
        }
        // Retry after a short delay
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted && !_isInitialized && !_isInitializing) {
            _initializeDashboard();
          }
        });
        return;
      }

      final attendanceProvider = Provider.of<AttendanceProvider>(
        context,
        listen: false,
      );

      Logger.info(
        'Loading essential attendance data for user: $userId (cache-first)',
      );

      // CRITICAL: Use cache-first load() method - shows cached data immediately, then refreshes in background
      // This ensures UI shows immediately with cached data, preventing "loading" screen
      try {
        await attendanceProvider.fetchUserAttendance(userId);
        await attendanceProvider.fetchTodayStatus(userId);
        // Note: fetchAttendanceSummary requires startDate and endDate parameters
        // It should only be called from screens that need summary data (e.g., admin attendance screen)
        Logger.info('Dashboard: Attendance data loaded (cache-first)');
      } catch (e) {
        Logger.warning('Dashboard: Failed to load attendance data: $e');
        // Continue - cached data will be shown if available
      }

      Logger.info('Essential data loaded, marking dashboard as ready');

      // Mark as initialized IMMEDIATELY after cache load (don't wait for server refresh)
      // The load() method already shows cached data and refreshes in background
      if (mounted) {
        setState(() {
          _isInitialized = true;
          _isInitializing = false;
        });

        Logger.info(
          'Dashboard marked as initialized - UI will now render with cached data',
        );

        // Load additional data in background without blocking UI
        _loadAdditionalDataInBackground(userId);
      }
    } catch (e) {
      Logger.warning('Error during dashboard initialization: $e');

      // Always set initialized to prevent infinite loading
      if (mounted) {
        setState(() {
          _isInitialized = true;
          _isInitializing = false;
        });

        Logger.info(
          'Dashboard initialized despite error - UI will render with partial data',
        );
      }
    }
  }

  /// Load additional data in background without blocking UI
  Future<void> _loadAdditionalDataInBackground(String userId) async {
    try {
      final attendanceProvider = Provider.of<AttendanceProvider>(
        context,
        listen: false,
      );

      // Load these in parallel in background
      await Future.wait([
        attendanceProvider.fetchUserAttendance(userId),
        attendanceProvider.preFetchBreakTypes(),
      ]).timeout(
        const Duration(seconds: 20),
        onTimeout: () {
          Logger.warning('Background data loading timed out');
          return <void>[]; // Return empty list instead of null
        },
      );

      Logger.info('Background data loading completed');

      // Load events if feature is enabled
      final featureProvider = Provider.of<FeatureProvider>(
        context,
        listen: false,
      );
      if (featureProvider.hasEvents) {
        _fetchUpcomingEvents();
      }
    } catch (e) {
      Logger.warning('Background data loading failed: $e');
      // Don't block UI for background data failures
    }
  }

  @override
  void dispose() {
    // Unsubscribe from RouteObserver
    _routeObserver?.unsubscribe(this);
    // Remove lifecycle observer
    WidgetsBinding.instance.removeObserver(this);
    // Remove auth readiness listener if still present
    if (_authReadyListener != null) {
      try {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        authProvider.removeListener(_authReadyListener!);
      } catch (e) {}
    }
    // Simplified disposal to prevent widget tree corruption
    super.dispose();
  }

  @override
  void didPush() {
    super.didPush();
    Logger.info('DASHBOARD_ROUTE: Route pushed, ensuring initialization');
    // When route is pushed (including hot restart), ensure data is loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        if (authProvider.isAuthenticated && authProvider.user != null) {
          final userId = authProvider.user?['_id'];
          if (userId != null) {
            // Check if we have data - if not, force initialization
            final attendanceProvider = Provider.of<AttendanceProvider>(
              context,
              listen: false,
            );
            final hasData = attendanceProvider.todayStatus != null;

            Logger.info(
              'DASHBOARD_ROUTE: Checking state - initialized=$_isInitialized, initializing=$_isInitializing, hasData=$hasData',
            );

            if (!_isInitialized && !_isInitializing) {
              Logger.info(
                'DASHBOARD_ROUTE: Initializing dashboard from didPush',
              );
              _initializeDashboard();
            } else if (_isInitialized && !hasData) {
              // Dashboard is initialized but no data - force fetch
              Logger.info(
                'DASHBOARD_ROUTE: Dashboard initialized but no data, forcing data fetch',
              );
              _forceDataFetch(userId);
            } else if (_isInitialized) {
              Logger.info(
                'DASHBOARD_ROUTE: Dashboard already initialized with data, refreshing',
              );
              _refreshDashboard();
            }
          }
        }
      }
    });
  }

  /// Force data fetch when dashboard is initialized but data is missing
  Future<void> _forceDataFetch(String userId) async {
    try {
      Logger.info('Dashboard: Force fetching data for user $userId');
      final attendanceProvider = Provider.of<AttendanceProvider>(
        context,
        listen: false,
      );

      await Future.wait([
        attendanceProvider
            .fetchTodayStatus(userId)
            .timeout(
              const Duration(seconds: 10),
              onTimeout: () {
                Logger.warning('Force fetch: Today status timed out');
                throw TimeoutException('Today status fetch timed out');
              },
            ),
        attendanceProvider
            .fetchUserAttendance(userId)
            .timeout(
              const Duration(seconds: 15),
              onTimeout: () {
                Logger.warning('Force fetch: Attendance history timed out');
                throw TimeoutException('Attendance history fetch timed out');
              },
            ),
      ]);

      Logger.info('Dashboard: Force fetch completed successfully');
      if (mounted) {
        setState(() {}); // Force UI rebuild
      }
    } catch (e) {
      Logger.warning('Dashboard: Force fetch failed: $e');
    }
  }

  @override
  void didPopNext() {
    super.didPopNext();
    // DISABLED: This was causing dashboard resets when returning from other screens
    // Profile completion check is now handled in initState only
    log(
      'DRAWER_DEBUG: didPopNext called but profile check disabled to prevent resets',
    );

    // Load notifications when returning to this screen
    _loadEmployeeSetupNotifications();
  }

  void _checkProfileCompletion() {
    if (widget.suppressProfilePrompt || !mounted) {
      return;
    }

    try {
      final profileProvider = Provider.of<ProfileProvider>(
        context,
        listen: false,
      );
      final profile = profileProvider.profile;
      if (profile != null &&
          profile['isProfileComplete'] == false &&
          !_profileDialogShown) {
        setState(() {
          _profileDialogShown = true;
        });
        // Delay the dialog until after the first frame to ensure the latest profile is shown
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_profileDialogShown) {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (ctx) => AlertDialog(
                title: const Text('Complete Your Profile'),
                content: const Text(
                  'For your safety and to access all features, please complete your profile information.',
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      // Don't reset the flag when dismissing
                    },
                    child: const Text('Dismiss'),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      Navigator.of(context).pushNamed('/profile').then((_) {
                        if (mounted) {
                          // Reset the flag when returning from profile screen
                          // so dialog can show again if profile is still incomplete
                          _profileDialogShown = false;
                        }
                      });
                    },
                    child: const Text('Update Now'),
                  ),
                ],
              ),
            );
          }
        });
      }
    } catch (e) {
      Logger.error('Failed to check profile completion: $e');
    }
  }

  // Quick action functions
  Future<void> _clockIn() async {
    // Prevent duplicate clock-in calls
    if (_isClockInInProgress) {
      if (mounted) {
        GlobalNotificationService().showInfo(
          'Clock-in in progress, please wait...',
        );
      }
      return;
    }

    // Haptic feedback on button press
    await HapticFeedbackService.instance.mediumImpact();

    final attendanceProvider = Provider.of<AttendanceProvider>(
      context,
      listen: false,
    );

    if (mounted) {
      setState(() {
        _isClockInInProgress = true;
      });
    }
    try {
      // CRITICAL FIX: Prevent clock in when on leave
      if (attendanceProvider.leaveInfo != null) {
        if (mounted) {
          GlobalNotificationService().showError(
            'Cannot clock in while on leave. Attendance actions are disabled during your leave period.',
          );
          await HapticFeedbackService.instance.error();
        }
        return;
      }

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.user?['_id'] as String?;

      if (userId == null) {
        if (mounted) {
          GlobalNotificationService().showError(
            'User ID not found. Please login again.',
          );
          await HapticFeedbackService.instance.error();
        }
        return;
      }

      // Show loading indicator
      if (mounted) {
        GlobalNotificationService().showInfo(
          'Clocking in...',
          duration: const Duration(seconds: 1),
        );
      }

      final result = await attendanceProvider.clockIn(userId);

      // Force refresh attendance status to get updated state immediately after clock-in
      Logger.info(
        'EmployeeDashboard: About to call fetchTodayStatus after clock in',
      );
      await attendanceProvider.fetchTodayStatus(userId, forceRefresh: true);
      Logger.info(
        'EmployeeDashboard: fetchTodayStatus completed, todayStatus=${attendanceProvider.todayStatus}',
      );

      // Force a small delay to ensure state is fully updated
      await Future.delayed(const Duration(milliseconds: 500));

      // Verify clock-in actually succeeded before showing success
      // Accept 'pending' (server-side processing/auto-clockout pending) as a valid
      // clock-in state too — backend may return 'pending' when autoClockOut/processing
      // applies but attendance record exists.
      final currentStatus = attendanceProvider.todayStatus;
      final bool successStatus =
          attendanceProvider.isClockedIn || currentStatus == 'pending';
      if (!successStatus) {
        throw Exception(
          'Clock-in was not successful. Current status: $currentStatus',
        );
      }

      // Update local state
      if (mounted) {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final user = authProvider.user;
        final companyProvider = Provider.of<CompanyProvider>(
          context,
          listen: false,
        );
        final timeStr = TimeUtils.formatTimeWithSmartTimezone(
          DateTime.now(),
          user: user,
          company: companyProvider.currentCompany?.toJson(),
        );
        GlobalNotificationService().showSuccess(
          'Successfully clocked in at $timeStr',
        );

        // Haptic feedback for success
        await HapticFeedbackService.instance.success();

        // Play sound for clock in
        await ActionSoundService.instance.playClockInSound();

        // Force UI refresh to clear any stale error states
        setState(() {});
      }

      Logger.info('Clock in successful: $result');
    } catch (e) {
      Logger.error('Clock in failed: $e');
      // Haptic feedback for error
      await HapticFeedbackService.instance.error();

      if (mounted) {
        // Enhanced error handling with better working hours error detection
        String errorMessage = 'Clock in failed: ${e.toString()}';
        String errorString = e.toString();

        if (errorString.contains('Outside working hours')) {
          // Extract working hours information from the error
          final workingHoursMatch = RegExp(
            r'Working hours: (\d{2}:\d{2}) - (\d{2}:\d{2})',
          ).firstMatch(errorString);
          final localTimeMatch = RegExp(
            r'Your local time: ([^,]+)',
          ).firstMatch(errorString);

          if (workingHoursMatch != null && localTimeMatch != null) {
            final startTime = workingHoursMatch.group(1);
            final endTime = workingHoursMatch.group(2);
            final localTime = localTimeMatch.group(1);
            errorMessage =
                'Clock-in failed: Outside working hours.\n\nYour time: $localTime\nWorking hours: $startTime - $endTime\n\nPlease clock in during your company\'s working hours.';
          } else {
            errorMessage =
                'Clock-in failed: Outside working hours. Please check your company\'s working hours.';
          }
        } else if (errorString.contains('holiday')) {
          errorMessage =
              'Cannot clock in on company holidays. Please check the company calendar.';
        } else if (errorString.contains('non-working day')) {
          errorMessage =
              'Cannot clock in on non-working days. Please check the company calendar.';
        } else if (errorString.contains('working day')) {
          errorMessage =
              'Cannot clock in on non-working days. Please check the company calendar.';
        } else if (errorString.contains('Already checked in')) {
          errorMessage = 'You have already clocked in for today.';
        } else if (errorString.contains('on approved')) {
          errorMessage = 'Cannot clock in while on approved leave.';
        } else if (errorString.contains('Clock-in failed:')) {
          // Use the detailed error message from the backend
          errorMessage = errorString.replaceFirst('Exception: ', '');
        }

        GlobalNotificationService().showError(errorMessage);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isClockInInProgress = false;
        });
      } else {
        _isClockInInProgress = false;
      }
    }
  }

  /// Show overtime notification dialog when user clocks out with overtime
  Future<void> _showOvertimeNotificationDialog(
    Map<String, dynamic> overtimeInfo,
  ) async {
    if (!mounted) return;

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        final theme = Theme.of(context);
        final warningColor = ThemeUtils.getStatusChipColor('warning', theme);

        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.access_time, color: warningColor, size: 28),
              const SizedBox(width: 12),
              const Text(
                'Overtime Detected!',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                overtimeInfo['message'] ?? 'You have worked overtime today!',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: warningColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: warningColor.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Expected Hours:',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                        Text(
                          '${overtimeInfo['expectedHours']?.toString() ?? '8.0'} hrs',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Overtime Hours:',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                        Text(
                          '${overtimeInfo['overtimeHours']?.toString() ?? '0.0'} hrs',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: warningColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Working Hours:',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                        Text(
                          '${overtimeInfo['workingHours']?['start'] ?? '09:00'} - ${overtimeInfo['workingHours']?['end'] ?? '17:00'}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Your overtime has been automatically recorded and will be included in your timesheet.',
                style: TextStyle(
                  fontSize: 14,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text(
                'Got it!',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _clockOut() async {
    // Prevent duplicate clock-out calls
    if (_isClockOutInProgress) {
      if (mounted) {
        GlobalNotificationService().showInfo(
          'Clock-out in progress, please wait...',
        );
      }
      return;
    }

    // Haptic feedback on button press
    await HapticFeedbackService.instance.mediumImpact();

    final attendanceProvider = Provider.of<AttendanceProvider>(
      context,
      listen: false,
    );

    _isClockOutInProgress = true;
    try {
      // CRITICAL FIX: Prevent clock out when on leave
      if (attendanceProvider.leaveInfo != null) {
        if (mounted) {
          GlobalNotificationService().showError(
            'Cannot clock out while on leave. Attendance actions are disabled during your leave period.',
          );
          await HapticFeedbackService.instance.error();
        }
        return;
      }

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.user?['_id'] as String?;

      if (userId == null) {
        if (mounted) {
          GlobalNotificationService().showError(
            'User ID not found. Please login again.',
          );
          await HapticFeedbackService.instance.error();
        }
        return;
      }

      // Show loading indicator
      if (mounted) {
        GlobalNotificationService().showInfo(
          'Clocking out...',
          duration: const Duration(seconds: 1),
        );
      }

      final result = await attendanceProvider.clockOut(userId);

      // Check for overtime and show notification dialog
      if (mounted &&
          result['hasOvertime'] == true &&
          result['overtimeInfo'] != null) {
        await _showOvertimeNotificationDialog(result['overtimeInfo']);
      }

      // Force refresh attendance status to get updated state immediately after clock-out
      await attendanceProvider.fetchTodayStatus(userId, forceRefresh: true);

      // Force a small delay to ensure state is fully updated
      await Future.delayed(const Duration(milliseconds: 500));

      // Update local state
      if (mounted) {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final user = authProvider.user;
        final companyProvider = Provider.of<CompanyProvider>(
          context,
          listen: false,
        );
        final timeStr = TimeUtils.formatTimeWithSmartTimezone(
          DateTime.now(),
          user: user,
          company: companyProvider.currentCompany?.toJson(),
        );
        GlobalNotificationService().showSuccess(
          'Successfully clocked out at $timeStr',
        );

        // Haptic feedback for success
        await HapticFeedbackService.instance.success();

        // Play sound for clock out
        await ActionSoundService.instance.playClockOutSound();

        // Force UI refresh to clear any stale error states
        setState(() {});
      }

      Logger.info('Clock out successful: $result');
    } catch (e) {
      Logger.error('Clock out failed: $e');
      // Haptic feedback for error
      await HapticFeedbackService.instance.error();

      if (mounted) {
        GlobalNotificationService().showError(
          'Clock out failed: ${e.toString()}',
        );
      }
    } finally {
      _isClockOutInProgress = false;
    }
  }

  Future<void> _startBreak() async {
    // Haptic feedback on button press
    await HapticFeedbackService.instance.lightImpact();

    // Prevent duplicate start break calls
    if (_isStartBreakInProgress) {
      if (mounted) {
        GlobalNotificationService().showInfo(
          'Break action in progress, please wait...',
        );
      }
      return;
    }

    final attendanceProvider = Provider.of<AttendanceProvider>(
      context,
      listen: false,
    );
    // CRITICAL FIX: Prevent break actions when on leave
    if (attendanceProvider.leaveInfo != null) {
      if (mounted) {
        GlobalNotificationService().showError(
          'Cannot manage breaks while on leave. Attendance actions are disabled during your leave period.',
        );
        await HapticFeedbackService.instance.error();
      }
      return;
    }

    // CRITICAL FIX: Prevent starting break if already on break
    if (attendanceProvider.isOnBreak) {
      if (mounted) {
        GlobalNotificationService().showError(
          'You are already on break. Please end your current break first.',
        );
        await HapticFeedbackService.instance.error();
      }
      return;
    }

    _isStartBreakInProgress = true;

    // Show break type selection dialog
    final selectedBreakType = await _showBreakTypeDialog();
    if (selectedBreakType == null) {
      _isStartBreakInProgress = false; // Reset loading state
      return; // User cancelled
    }

    // Show duration confirmation dialog
    final confirmed = await _showBreakDurationConfirmation(selectedBreakType);
    if (!confirmed) {
      _isStartBreakInProgress = false; // Reset loading state
      return; // User cancelled
    }

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.user?['_id'] as String?;

      if (userId == null) {
        if (mounted) {
          GlobalNotificationService().showError(
            'User ID not found. Please login again.',
          );
          await HapticFeedbackService.instance.error();
        }
        return;
      }

      // Show loading indicator
      if (mounted) {
        GlobalNotificationService().showInfo(
          'Starting break...',
          duration: const Duration(seconds: 1),
        );
      }

      // Start break with selected break type
      await attendanceProvider.startBreakWithType(userId, selectedBreakType);

      // CRITICAL FIX: Refresh attendance status to get updated state
      await attendanceProvider.fetchTodayStatus(userId);

      // Force immediate UI refresh - no delays
      if (mounted) {
        setState(() {});
      }

      // Update local state immediately
      if (mounted) {
        final displayName = selectedBreakType['displayName'] ?? 'Break';

        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final user = authProvider.user;
        final companyProvider = Provider.of<CompanyProvider>(
          context,
          listen: false,
        );
        final timeStr = TimeUtils.formatTimeWithSmartTimezone(
          DateTime.now(),
          user: user,
          company: companyProvider.currentCompany?.toJson(),
        );
        GlobalNotificationService().showEvent(
          'Break Started',
          '$displayName started at $timeStr',
        );

        // Haptic feedback for success
        await HapticFeedbackService.instance.success();

        // Play sound for start break
        await ActionSoundService.instance.playStartBreakSound();

        // Force UI refresh to show updated status after provider has updated
        if (mounted) {
          setState(() {});
        }

        // Removed delayed notification to prevent UI delays
      }

      Logger.info('Break started successfully');
    } catch (e) {
      Logger.error('Start break failed: $e');
      // Haptic feedback for error
      await HapticFeedbackService.instance.error();

      if (mounted) {
        GlobalNotificationService().showError(
          'Failed to start break: ${e.toString()}',
        );
      }
    } finally {
      // Always reset loading state
      _isStartBreakInProgress = false;
    }
  }

  /// Get break types with cache-first pattern
  Future<List<Map<String, dynamic>>> _getBreakTypes() async {
    try {
      final attendanceProvider = Provider.of<AttendanceProvider>(
        context,
        listen: false,
      );
      final breakTypes = await attendanceProvider.getBreakTypes();
      Logger.info(
        'Fetched ${breakTypes.length} break types (cached or from API)',
      );
      return breakTypes;
    } catch (e) {
      Logger.error('Error fetching break types: $e');
      // Return empty list instead of invalid "default" ID
      // The dialog will handle initialization or show error
      return [];
    }
  }

  /// Show confirmation dialog for break duration requirements
  Future<bool> _showBreakDurationConfirmation(
    Map<String, dynamic> breakType,
  ) async {
    final displayName =
        breakType['displayName'] ?? breakType['name'] ?? 'Break';
    final minDuration = breakType['minDuration'] ?? 1;
    final maxDuration = breakType['maxDuration'] ?? 60;

    String durationText;
    if (minDuration == maxDuration) {
      durationText = '$minDuration minutes';
    } else {
      durationText = '$minDuration-$maxDuration minutes';
    }

    return await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text('Confirm $displayName'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('You are about to start a $displayName.'),
                  const SizedBox(height: 8),
                  Text(
                    'Duration: $durationText',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  if (minDuration > 1)
                    Builder(
                      builder: (context) {
                        final theme = Theme.of(context);
                        final warningColor = ThemeUtils.getStatusChipColor(
                          'warning',
                          theme,
                        );
                        return Text(
                          '⚠️ This break type requires a minimum duration of $minDuration minutes.',
                          style: TextStyle(
                            color: warningColor,
                            fontWeight: FontWeight.w500,
                          ),
                        );
                      },
                    ),
                  const SizedBox(height: 8),
                  Text('Are you sure you want to start this break?'),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Start Break'),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  Future<void> _endBreak() async {
    // Haptic feedback on button press
    await HapticFeedbackService.instance.lightImpact();

    // Prevent duplicate end break calls
    if (_isEndBreakInProgress) {
      if (mounted) {
        GlobalNotificationService().showInfo(
          'Break action in progress, please wait...',
        );
      }
      return;
    }

    _isEndBreakInProgress = true;

    final attendanceProvider = Provider.of<AttendanceProvider>(
      context,
      listen: false,
    );
    try {
      // CRITICAL FIX: Prevent break actions when on leave
      if (attendanceProvider.leaveInfo != null) {
        if (mounted) {
          GlobalNotificationService().showError(
            'Cannot manage breaks while on leave. Attendance actions are disabled during your leave period.',
          );
          await HapticFeedbackService.instance.error();
        }
        return;
      }

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.user?['_id'] as String?;

      if (userId == null) {
        if (mounted) {
          GlobalNotificationService().showError(
            'User ID not found. Please login again.',
          );
          await HapticFeedbackService.instance.error();
        }
        return;
      }

      // CRITICAL FIX: Validate minimum break duration before allowing end break
      final currentAttendance = attendanceProvider.currentAttendance;
      if (currentAttendance != null && currentAttendance['breaks'] != null) {
        final breaks = currentAttendance['breaks'] as List;
        if (breaks.isNotEmpty) {
          final currentBreak = breaks.last;
          final breakStartTime =
              currentBreak['startTime'] ?? currentBreak['start'];

          if (breakStartTime != null) {
            try {
              final startTime = DateTime.parse(breakStartTime).toLocal();
              final now = DateTime.now();
              final breakDuration = now.difference(startTime);
              final breakDurationMinutes = breakDuration.inMinutes;

              // Get the break type to check minimum duration
              final breakTypeId =
                  currentBreak['breakTypeId'] ?? currentBreak['breakType'];
              if (breakTypeId != null) {
                // Get break types from the provider or fetch them
                final breakTypes = await _getBreakTypes();
                final breakType = breakTypes.firstWhere(
                  (bt) => bt['_id'] == breakTypeId || bt['id'] == breakTypeId,
                  orElse: () => {'minDuration': 1},
                );

                final minDuration =
                    breakType['minDuration'] ?? 0.5; // 30 seconds default

                if (breakDurationMinutes < minDuration) {
                  final remainingSeconds =
                      ((minDuration - breakDurationMinutes) * 60).round();
                  if (mounted) {
                    GlobalNotificationService().showError(
                      'Break must be at least ${(minDuration * 60).round()} seconds long. Please wait $remainingSeconds more seconds.',
                    );
                    await HapticFeedbackService.instance.error();
                  }
                  return;
                }
              }
            } catch (e) {
              Logger.error('Error validating break duration: $e');
              // Continue with break end if validation fails
            }
          }
        }
      }

      // Show loading indicator
      if (mounted) {
        GlobalNotificationService().showInfo(
          'Ending break...',
          duration: const Duration(seconds: 1),
        );
      }

      final result = await attendanceProvider.endBreak(userId);

      // Check if break ended successfully
      if (result) {
        // Force immediate UI refresh
        if (mounted) {
          setState(() {});
        }

        // Update local state
        if (mounted) {
          final authProvider = Provider.of<AuthProvider>(
            context,
            listen: false,
          );
          final user = authProvider.user;
          final companyProvider = Provider.of<CompanyProvider>(
            context,
            listen: false,
          );
          final timeStr = TimeUtils.formatTimeWithSmartTimezone(
            DateTime.now(),
            user: user,
            company: companyProvider.currentCompany?.toJson(),
          );
          GlobalNotificationService().showEvent(
            'Break Ended',
            'Break ended at $timeStr',
          );

          // Haptic feedback for success
          await HapticFeedbackService.instance.success();

          // Play sound for end break
          await ActionSoundService.instance.playEndBreakSound();

          // Force UI refresh to show updated status after provider has updated
          await Future.delayed(const Duration(milliseconds: 300));
          if (mounted) {
            setState(() {});
          }
        }

        Logger.info('Break ended successfully: $result');
      } else {
        // Break did not end successfully, show error message
        final errorMessage = attendanceProvider.error ?? 'Failed to end break';
        if (mounted) {
          // Add 1 second delay before showing error to ensure user sees the loading state
          await Future.delayed(const Duration(seconds: 1));
          if (mounted) {
            GlobalNotificationService().showError(errorMessage);
            await HapticFeedbackService.instance.error();
          }
        }
        Logger.error('Break end failed: $errorMessage');
      }
    } catch (e) {
      Logger.error('End break failed: $e');
      // Haptic feedback for error
      await HapticFeedbackService.instance.error();

      if (mounted) {
        // Add 1 second delay before showing error to ensure user sees the loading state
        await Future.delayed(const Duration(seconds: 1));
        if (mounted) {
          GlobalNotificationService().showError(
            'End break failed: ${e.toString()}',
          );
        }
      }
    } finally {
      // Always reset loading state
      _isEndBreakInProgress = false;
    }
  }

  void _applyLeave(BuildContext context) {
    Navigator.pushNamed(context, '/leave_request');
  }

  void _openTimesheet(BuildContext context) {
    Navigator.pushNamed(context, '/timesheet');
  }

  void _openProfile(BuildContext context) {
    Navigator.pushNamed(context, '/profile');
  }

  void _openEvents(BuildContext context) {
    Navigator.pushNamed(context, '/events');
  }

  void _openCompanyInfo(BuildContext context) {
    Navigator.pushNamed(context, '/company_info');
  }

  // Build leave status widget
  Widget _buildLeaveStatusWidget(AttendanceProvider attendanceProvider) {
    if (attendanceProvider.leaveInfo == null) return const SizedBox.shrink();

    final leaveType = attendanceProvider.leaveInfo!['type'] ?? 'Leave';
    final startDate = DateTime.parse(
      attendanceProvider.leaveInfo!['startDate'],
    );
    final endDate = DateTime.parse(attendanceProvider.leaveInfo!['endDate']);
    final reason =
        attendanceProvider.leaveInfo!['reason'] ?? 'No reason provided';
    final isHalfDay = attendanceProvider.leaveInfo!['isHalfDay'] == true;
    final halfDayLeaveTime =
        attendanceProvider.leaveInfo!['halfDayLeaveTime'] as String?;

    // Get user and company data for date formatting
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final companyProvider = Provider.of<CompanyProvider>(
      context,
      listen: false,
    );
    final user = authProvider.user;
    final company = companyProvider.currentCompany?.toJson();

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppTheme.warning.withValues(alpha: 0.1),
              AppTheme.warning.withValues(alpha: 0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        ),
        padding: AppTheme.standardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.beach_access, color: AppTheme.warning, size: 30),
                const SizedBox(width: AppTheme.spacingM),
                Expanded(
                  child: Text(
                    isHalfDay ? 'Half Day Leave' : 'On Leave',
                    style: AppTheme.titleLarge.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.warning,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingL),
            _buildLeaveInfoRow('Type', leaveType),
            _buildLeaveInfoRow(
              'From',
              TimeUtils.formatReadableDate(
                startDate,
                user: user,
                company: company,
              ),
            ),
            _buildLeaveInfoRow(
              'To',
              TimeUtils.formatReadableDate(
                endDate,
                user: user,
                company: company,
              ),
            ),
            if (isHalfDay && halfDayLeaveTime != null)
              _buildLeaveInfoRow('Leave Time', halfDayLeaveTime),
            if (reason.isNotEmpty) _buildLeaveInfoRow('Reason', reason),
            const SizedBox(height: AppTheme.spacingM),
            Container(
              padding: AppTheme.cardPadding,
              decoration: BoxDecoration(
                color: AppTheme.warning.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                border: Border.all(
                  color: AppTheme.warning.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: AppTheme.warning, size: 20),
                  const SizedBox(width: AppTheme.spacingS),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isHalfDay
                              ? (halfDayLeaveTime != null
                                    ? 'You can clock in for half-day leave. You will be automatically clocked out at $halfDayLeaveTime.'
                                    : 'You can clock in for half-day leave.')
                              : 'Attendance actions are disabled during your leave period.',
                          style: AppTheme.bodyMedium.copyWith(
                            color: AppTheme.warning,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Leave ends: ${TimeUtils.formatReadableDate(endDate, user: user, company: company)}',
                          style: AppTheme.bodyMedium.copyWith(
                            color: AppTheme.warning.withValues(alpha: 0.8),
                            fontWeight: FontWeight.w400,
                            fontSize: 12,
                          ),
                        ),
                      ],
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

  Widget _buildLeaveInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacingS),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: AppTheme.bodyMedium.copyWith(
                fontWeight: FontWeight.w600,
                color: AppTheme.warning,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTheme.bodyMedium.copyWith(color: AppTheme.warning),
            ),
          ),
        ],
      ),
    );
  }

  /// Fetches upcoming events for the employee dashboard
  Future<void> _fetchUpcomingEvents() async {
    if (!mounted) return;

    setState(() {
      _eventsLoading = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.token;
      final userId = authProvider.user?['_id'];

      if (token == null || userId == null) {
        throw Exception('Authentication required');
      }

      final response = await http
          .get(
            Uri.parse('${ApiConfig.baseUrl}/events'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
          )
          .timeout(
            const Duration(seconds: 60),
            onTimeout: () {
              throw api_exceptions.TimeoutException(
                'Events request timed out after 60 seconds',
              );
            },
          );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final allEvents = List<Map<String, dynamic>>.from(data['events'] ?? []);

        // Filter for upcoming events (next 7 days)
        final now = DateTime.now();
        final nextWeek = now.add(const Duration(days: 7));

        final upcomingEvents = allEvents.where((event) {
          final eventDate = DateTime.parse(event['startDate'] ?? '');
          return eventDate.isAfter(now) && eventDate.isBefore(nextWeek);
        }).toList();

        if (mounted) {
          setState(() {
            _upcomingEvents = upcomingEvents;
            _eventsLoading = false;
          });

          // Show success notification if events were loaded
          if (upcomingEvents.isNotEmpty) {
            GlobalNotificationService().showEvent(
              'Events Loaded',
              '${upcomingEvents.length} upcoming events loaded successfully',
            );
          }
        }
      } else {
        throw Exception('Failed to load events: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _eventsLoading = false;
        });

        // Show error notification to user
        GlobalNotificationService().showError(
          'Failed to load events: ${e.toString()}',
        );
      }
      // Also log the error for debugging
      Logger.warning('Error fetching events: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.user;

    // Check if user is authenticated - redirect immediately if not
    if (user == null || !authProvider.isAuthenticated) {
      // LOGIN FIX VERIFICATION: Log when user is redirected back to login
      Logger.warning(
        '🔧 LOGIN FIX: User not authenticated on dashboard - redirecting to login',
      );
      Logger.warning(
        '🔧 LOGIN FIX: user == null: ${user == null}, isAuthenticated: ${authProvider.isAuthenticated}',
      );
      Logger.warning(
        '🔧 LOGIN FIX: This indicates the login fix may not be working properly',
      );

      // Navigate to login immediately instead of showing loading screen
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil('/login', (route) => false);
      });

      // Return minimal widget while navigation happens
      return const Scaffold(body: SizedBox.shrink());
    }

    // LOGIN FIX VERIFICATION: Log successful authentication check
    Logger.info(
      '🔧 LOGIN FIX: User authenticated on dashboard - login fix is working!',
    );
    Logger.info('🔧 LOGIN FIX: User ID: ${user['_id']}, Role: ${user['role']}');

    final isAdmin = user['role'] == 'admin';
    final attendanceProvider = Provider.of<AttendanceProvider>(context);
    final profileProvider = Provider.of<ProfileProvider>(context);

    // Check connectivity status
    final connectivityService = Provider.of<ConnectivityService>(context);
    final isOnline = connectivityService.isFullyOnline;

    // Cache-first loading check: Only show loading if no cached data available
    final hasCachedData =
        attendanceProvider.attendanceRecords.isNotEmpty ||
        attendanceProvider.todayStatus != null;

    // Only show loading if not initialized AND no cached data available
    final isLoading = !_isInitialized && !hasCachedData;

    // Grace period: Don't show connectivity errors during first 2 seconds of loading
    // This prevents the brief flash of connectivity error screen while connectivity service checks

    // Only show connectivity errors if:
    // 1. Grace period has elapsed (give connectivity service time to check)
    // 2. We're not in initial loading phase
    // 3. We've actually tried to load data (initialized or has error)
    // 4. There's an actual error from the provider

    // Debug logging for loading state
    if (isLoading) {
      Logger.info(
        'Dashboard loading state: _isInitialized=$_isInitialized, hasCachedData=$hasCachedData, isOnline=$isOnline',
      );
    }

    if (isLoading) {
      // Simple loading screen - don't show connectivity errors during initial load
      return Scaffold(
        appBar: AppBar(
          title: const Text('Employee Dashboard'),
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: ThemeUtils.getAutoTextColor(
            Theme.of(context).colorScheme.primary,
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              const Text(
                'Loading your dashboard...',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                'This should only take a few seconds',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  // Force reinitialize dashboard - but only if not already initializing
                  if (!_isInitializing) {
                    setState(() {
                      _isInitialized = false;
                      _isInitializing = false; // Reset both flags
                    });
                    _initializeDashboard();
                  }
                },
                child: const Text('Retry Loading'),
              ),
            ],
          ),
        ),
      );
    }

    if (isAdmin) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Employee Dashboard'),
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: ThemeUtils.getAutoTextColor(
            Theme.of(context).colorScheme.primary,
          ),
        ),
        body: const Center(child: Text('Access denied')),
        drawer: const AdminSideNavigation(currentRoute: '/employee_dashboard'),
      );
    }

    return Scaffold(
      appBar: SharedAppBar(
        title: 'Employee Dashboard',
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: ThemeUtils.getAutoTextColor(
          Theme.of(context).colorScheme.primary,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshDashboard,
            tooltip: 'Refresh Dashboard',
          ),
        ],
      ),
      key: const Key('employee_dashboard_scaffold'),
      drawer: const AppDrawer(),
      onDrawerChanged: (isOpened) {
        log(
          'DRAWER_DEBUG: Drawer state changed to: ${isOpened ? 'open' : 'closed'}',
        );
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        if (isOpened) {
          log('DRAWER_DEBUG: Opening drawer via provider');
          authProvider.openDrawer();
        } else {
          log('DRAWER_DEBUG: Closing drawer via provider');
          authProvider.closeDrawer();
        }

        // CRITICAL FIX: Don't reinitialize dashboard when drawer opens/closes
        // This prevents the "Already clocked in" error from appearing
        log(
          'DRAWER_DEBUG: Drawer state change handled, dashboard state preserved',
        );
      },
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= 1200) {
            // Desktop mode: center and constrain width
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: _buildMainContent(profileProvider.profile!),
              ),
            );
          } else {
            // Mobile/tablet mode: full width
            return _buildMainContent(profileProvider.profile!);
          }
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        0,
        AppTheme.spacingS,
        0,
        AppTheme.spacingS,
      ),
      child: Text(
        title,
        style: AppTheme.smallCaption.copyWith(
          fontWeight: FontWeight.bold,
          color: AppTheme.muted,
          letterSpacing: 1.1,
        ),
      ),
    );
  }

  /// Build notification banner for employee setup status
  Widget _buildEmployeeSetupNotificationBanner() {
    if (_notificationsLoading) {
      return const SizedBox.shrink(); // Don't show anything while loading
    }

    if (_employeeSetupNotifications.isEmpty) {
      return const SizedBox.shrink(); // Don't show banner if no notifications
    }

    final setupNotification = _employeeSetupNotifications.firstWhere(
      (n) => n['data']?['actionType'] == 'employee_setup_pending',
      orElse: () => {},
    );

    if (setupNotification.isEmpty) {
      return const SizedBox.shrink(); // No setup pending notification
    }

    final theme = Theme.of(context);
    final warningColor = ThemeUtils.getStatusChipColor('warning', theme);

    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingL),
      padding: const EdgeInsets.all(AppTheme.spacingL),
      decoration: BoxDecoration(
        color: warningColor.withValues(alpha: 0.1),
        border: Border.all(color: warningColor.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: warningColor, size: 24),
          const SizedBox(width: AppTheme.spacingM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  setupNotification['title'] ?? 'Action Required',
                  style: AppTheme.bodyMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: warningColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  setupNotification['body'] ??
                      'Please wait for your admin to complete your profile setup.',
                  style: AppTheme.bodyMedium.copyWith(
                    color: warningColor.withValues(alpha: 0.8),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          // Add refresh button
          IconButton(
            onPressed: _refreshEmployeeSetupNotifications,
            icon: const Icon(Icons.refresh, size: 20),
            tooltip: 'Refresh notifications',
          ),
        ],
      ),
    );
  }

  /// Force refresh employee setup notifications
  Future<void> _refreshEmployeeSetupNotifications() async {
    Logger.info('Force refreshing employee setup notifications');
    await _loadEmployeeSetupNotifications();
  }

  /// Check if user needs onboarding guide
  void _checkClockInReminder() async {
    Logger.info('DASHBOARD: _checkClockInReminder called');
    // Check for clock-in reminder when dashboard opens
    // But skip if we're navigating from a notification
    final prefs = await SharedPreferences.getInstance();
    final navigatingFromNotification =
        prefs.getBool('_navigating_from_notification') ?? false;
    Logger.info(
      'DASHBOARD: _navigating_from_notification flag = $navigatingFromNotification',
    );

    if (navigatingFromNotification) {
      Logger.info(
        'DASHBOARD: ⚠️ SKIPPING clock-in reminder check - navigating from notification',
      );
      return;
    }

    Logger.info(
      'DASHBOARD: Flag check passed, scheduling reminder check in 2 seconds',
    );
    Future.delayed(const Duration(seconds: 2), () async {
      if (mounted) {
        // Double-check the flag before showing reminder
        final prefs = await SharedPreferences.getInstance();
        final stillNavigating =
            prefs.getBool('_navigating_from_notification') ?? false;
        Logger.info(
          'DASHBOARD: After 2s delay, _navigating_from_notification flag = $stillNavigating',
        );
        if (!stillNavigating) {
          Logger.info(
            'DASHBOARD: Calling ClockInReminderService.checkReminderOnAppOpen()',
          );
          ClockInReminderService().checkReminderOnAppOpen();
        } else {
          Logger.info(
            'DASHBOARD: ⚠️ SKIPPING clock-in reminder - still navigating from notification',
          );
        }
      }
    });
  }

  bool _onboardingGuideShown =
      false; // Track if guide has been shown in this session

  void _checkOnboardingStatus() {
    // Prevent showing guide multiple times
    if (_onboardingGuideShown) {
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    // Only show onboarding guide for authenticated first-time users
    // Don't show if user is logged out (isAuthenticated will be false)
    if (authProvider.isAuthenticated && !authProvider.hasCompletedOnboarding) {
      // Add a small delay to ensure the dashboard is fully loaded
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted && authProvider.isAuthenticated && !_onboardingGuideShown) {
          _showOnboardingGuide();
        }
      });
    }
  }

  /// Show onboarding guide popup
  void _showOnboardingGuide() {
    // Double-check: don't show if already shown or if dialog is already open
    if (_onboardingGuideShown) {
      return;
    }

    // Check if there's already a dialog open
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      // There's already a route/dialog, don't show another
      return;
    }

    _onboardingGuideShown = true; // Mark as shown before displaying

    showDialog(
      context: context,
      barrierDismissible: false, // Prevent dismissing by tapping outside
      builder: (BuildContext context) {
        return const SetupGuideScreen();
      },
    ).then((_) {
      // Don't reset the flag - once shown in this session, don't show again
      // The flag will be reset when the widget is disposed or the app restarts
      // This prevents the dialog from appearing repeatedly
    });
  }

  /// Build timezone setup notification banner
  Widget _buildTimezoneSetupNotificationBanner() {
    Provider.of<AuthProvider>(context, listen: false);

    // Check if company needs timezone setup
    final companyProvider = Provider.of<CompanyProvider>(
      context,
      listen: false,
    );
    final company = companyProvider.currentCompany?.toJson();
    if (company == null || !TimeUtils.needsTimezoneSetup(company)) {
      return const SizedBox.shrink(); // No timezone setup needed
    }

    final theme = Theme.of(context);
    final headerBgColor = ThemeUtils.getSafeHeaderBackgroundColor(theme);
    final headerColor = ThemeUtils.getSafeHeaderColor(theme);
    final textColor = ThemeUtils.getAutoTextColor(headerColor);
    final iconColor = ThemeUtils.getSafeIconColor(headerColor, theme);

    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingL),
      padding: const EdgeInsets.all(AppTheme.spacingL),
      decoration: BoxDecoration(
        color: headerBgColor,
        border: Border.all(color: headerColor.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.schedule_rounded, color: iconColor, size: 24),
          const SizedBox(width: AppTheme.spacingM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Set Your Timezone',
                  style: AppTheme.bodyMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Configure your timezone to see accurate times in your timesheet and attendance records.',
                  style: AppTheme.bodyMedium.copyWith(
                    color: textColor.withValues(alpha: 0.8),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pushNamed('/admin/company_settings');
            },
            child: Text(
              'Setup',
              style: TextStyle(color: headerColor, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  /// Load employee setup notifications
  Future<void> _loadEmployeeSetupNotifications() async {
    if (!mounted) return;

    setState(() {
      _notificationsLoading = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.user?['_id'];
      if (userId == null) {
        setState(() {
          _employeeSetupNotifications = [];
          _notificationsLoading = false;
        });
        return;
      }

      final apiService = ApiService(baseUrl: ApiConfig.baseUrl);
      // Add timestamp to force fresh data and bypass any caching
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final url =
          '/notifications?actionType=employee_setup_pending&_t=$timestamp';
      final response = await apiService.get(url);

      if (response.success && response.data != null) {
        final notifications = response.data['notifications'] ?? [];

        if (mounted) {
          setState(() {
            _employeeSetupNotifications = List<Map<String, dynamic>>.from(
              notifications,
            );
            _notificationsLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _employeeSetupNotifications = [];
            _notificationsLoading = false;
          });
        }
      }
    } catch (e) {
      Logger.error('Failed to fetch employee setup notifications: $e');
      if (mounted) {
        setState(() {
          _employeeSetupNotifications = [];
          _notificationsLoading = false;
        });
      }
    }
  }

  /// Refresh all dashboard data
  Future<void> _refreshDashboard() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final attendanceProvider = Provider.of<AttendanceProvider>(
      context,
      listen: false,
    );
    final profileProvider = Provider.of<ProfileProvider>(
      context,
      listen: false,
    );
    final connectivityService = Provider.of<ConnectivityService>(
      context,
      listen: false,
    );

    final userId = authProvider.user?['_id'];
    if (userId == null) return;

    // Check connectivity before attempting refresh
    final isOnline = connectivityService.isFullyOnline;

    try {
      Logger.info('Dashboard: Refreshing all data... (online: $isOnline)');

      final notificationService = Provider.of<GlobalNotificationService>(
        context,
        listen: false,
      );

      if (isOnline) {
        // Online - refresh from server
        notificationService.showInfo(
          'Refreshing dashboard data...',
          duration: const Duration(seconds: 2),
        );

        // Use refresh() method for force refresh from server
        // Track if all operations succeeded
        bool allSucceeded = true;
        String? firstError;

        try {
          await Future.wait([
            attendanceProvider.fetchUserAttendance(userId).catchError((e) {
              allSucceeded = false;
              firstError ??= e.toString();
              Logger.error('Dashboard: Attendance fetch failed: $e');
            }),
            profileProvider.fetchProfile().catchError((e) {
              allSucceeded = false;
              firstError ??= e.toString();
              Logger.error('Dashboard: Profile fetch failed: $e');
            }),
            _loadEmployeeSetupNotifications().catchError((e) {
              allSucceeded = false;
              firstError ??= e.toString();
              Logger.error('Dashboard: Notifications fetch failed: $e');
            }),
          ]);
        } catch (e) {
          allSucceeded = false;
          firstError ??= e.toString();
          Logger.error('Dashboard: Refresh operation failed: $e');
        }

        // Double-check server is still reachable after operations
        final stillOnline = connectivityService.isFullyOnline;

        if (allSucceeded && stillOnline) {
          Logger.info('Dashboard: All data refreshed successfully');
          notificationService.showSuccess('Dashboard refreshed successfully!');
        } else if (!stillOnline) {
          Logger.warning('Dashboard: Server became unreachable during refresh');
          notificationService.showError(
            'Server connection lost. Please check your connection.',
          );
        } else {
          Logger.warning('Dashboard: Some operations failed during refresh');
          notificationService.showError(
            'Failed to refresh some data. ${firstError != null
                ? firstError!.length > 50
                      ? "${firstError!.substring(0, 50)}..."
                      : firstError
                : "Please try again."}',
          );
        }
      } else {
        // Offline - show message
        Logger.info('Dashboard: Offline - cannot refresh');
        notificationService.showError(
          'No internet connection. Cannot refresh data.',
        );
      }
    } catch (e) {
      Logger.error('Dashboard: Error refreshing data: $e');
      // Show error notification only if online (offline errors are expected)
      if (isOnline) {
        final notificationService = Provider.of<GlobalNotificationService>(
          context,
          listen: false,
        );
        notificationService.showError(
          'Failed to refresh data: ${e.toString()}',
        );
      }
    }
  }

  Widget _buildMainContent(Map<String, dynamic> profile) {
    final attendanceProvider = Provider.of<AttendanceProvider>(context);
    return RefreshIndicator(
      onRefresh: _refreshDashboard,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacingL,
            vertical: AppTheme.spacingXl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Consumer<ProfileProvider>(
                builder: (context, profileProvider, _) {
                  final profile = profileProvider.profile;
                  return _DashboardHeader(profile: profile);
                },
              ),
              const SizedBox(height: AppTheme.spacingXl),

              // Employee Setup Notification Banner
              _buildEmployeeSetupNotificationBanner(),

              // Timezone Setup Notification Banner
              _buildTimezoneSetupNotificationBanner(),

              StatusCard(),
              const SizedBox(height: AppTheme.spacingXl),

              // Location Information Section (only for plans with location features)
              Consumer<FeatureProvider>(
                builder: (context, featureProvider, _) {
                  final showLocation =
                      featureProvider.hasLocationManagement ||
                      featureProvider.hasLocationBasedAttendance ||
                      featureProvider.hasMultiLocation;
                  if (!showLocation) return const SizedBox.shrink();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildSectionHeader('LOCATION INFORMATION'),
                      const SizedBox(height: AppTheme.spacingL),
                      _buildLocationInfoCard(),
                      const SizedBox(height: AppTheme.spacingXl),
                    ],
                  );
                },
              ),

              // Quick Actions Section with Date Display
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildSectionHeader('QUICK ACTIONS'),
                  // Today's Date Display with Day Name
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spacingL,
                      vertical: AppTheme.spacingS,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.secondary.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                      border: Border.all(
                        color: AppTheme.secondary.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 16,
                          color: AppTheme.secondary,
                        ),
                        const SizedBox(width: AppTheme.spacingS),
                        Consumer2<AuthProvider, CompanyProvider>(
                          builder: (context, authProvider, companyProvider, _) {
                            final user = authProvider.user;
                            final company = companyProvider.currentCompany
                                ?.toJson();
                            // Use company timezone so day and date stay in sync for the timesheet view
                            final companyNow =
                                TimeUtils.convertToEffectiveTimezone(
                                  DateTime.now(),
                                  user,
                                  company,
                                );
                            final dayName = DateFormat(
                              'EEEE',
                            ).format(companyNow); // e.g., "Wednesday"
                            final dateString = TimeUtils.formatReadableDate(
                              companyNow,
                              user: user,
                              company: company,
                            );
                            return Text(
                              '$dayName, $dateString',
                              style: AppTheme.bodyMedium.copyWith(
                                color: AppTheme.secondary,
                                fontWeight: FontWeight.w600,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spacingL),
              Builder(
                builder: (context) {
                  final todayStatus = attendanceProvider.todayStatus;
                  final isClockedIn =
                      todayStatus == 'clocked_in' || todayStatus == 'on_break';

                  // Debug logging

                  return _QuickActions(
                    isOnBreak: todayStatus == 'on_break',
                    isOnLeave: attendanceProvider.leaveInfo != null,
                    isHoliday: attendanceProvider.holidayInfo != null,
                    isNonWorkingDay:
                        attendanceProvider.nonWorkingDayInfo != null,
                    isClockedIn: isClockedIn,
                    leaveEndDate: attendanceProvider.leaveInfo?['endDate'],
                    holidayInfo: attendanceProvider.holidayInfo,
                    nonWorkingDayInfo: attendanceProvider.nonWorkingDayInfo,
                    isBreakActionInProgress:
                        _isStartBreakInProgress || _isEndBreakInProgress,
                    isClockInInProgress: _isClockInInProgress,
                    clockIn: _clockIn,
                    clockOut: _clockOut,
                    startBreak: _startBreak,
                    endBreak: _endBreak,
                    applyLeave: (ctx) => _applyLeave(ctx),
                    openTimesheet: (ctx) => _openTimesheet(ctx),
                    openProfile: (ctx) => _openProfile(ctx),
                    openEvents: (ctx) => _openEvents(ctx),
                    openCompanyInfo: (ctx) => _openCompanyInfo(ctx),
                  );
                },
              ),
              const SizedBox(height: AppTheme.spacingXl),
              // Overview Section with relative/trend metrics
              _buildSectionHeader('OVERVIEW'),
              const SizedBox(height: AppTheme.spacingL),
              // Overview section with proper GlobalKey handling
              Builder(
                builder: (context) {
                  // Coach features disabled for this company
                  // final featureProvider = Provider.of<FeatureProvider>(context, listen: false);
                  // if (featureProvider.hasTutorialCenter || featureProvider.hasBasicTutorials) {
                  //   EmployeeDashboardWithCoachMarks.initializeOverviewKeys();
                  // }

                  return DashboardOverviewTile(
                    onStatTileTap: (label) {
                      // Handle stat tile taps if needed
                      Logger.info('Overview stat tapped: $label');
                    },
                  );
                },
              ),
              // Kick a background refresh so Overview reflects latest today status
              // Attendance data is fetched in initState to avoid setState during build
              const SizedBox(height: AppTheme.spacingXl),
              // Leave Status Section
              if (attendanceProvider.leaveInfo != null) ...[
                _buildSectionHeader('LEAVE STATUS'),
                const SizedBox(height: AppTheme.spacingL),
                _buildLeaveStatusWidget(attendanceProvider),
                const SizedBox(height: AppTheme.spacingXl),
              ],
              // Upcoming Events Section
              Consumer<FeatureProvider>(
                builder: (context, featureProvider, _) {
                  if (!featureProvider.hasEvents) {
                    return const SizedBox.shrink();
                  }

                  if (_upcomingEvents.isEmpty && !_eventsLoading) {
                    return const SizedBox.shrink();
                  }

                  return Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildSectionHeader('UPCOMING EVENTS'),
                          TextButton(
                            onPressed: () =>
                                Navigator.pushNamed(context, '/events'),
                            child: const Text('View All'),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppTheme.spacingL),
                      _buildUpcomingEventsSection(),
                      const SizedBox(height: AppTheme.spacingXl),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUpcomingEventsSection() {
    if (_eventsLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_upcomingEvents.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: _upcomingEvents.take(3).map((event) {
        final eventDate = DateTime.parse(event['startDate'] ?? '');
        final attendees = List<Map<String, dynamic>>.from(
          event['attendees'] ?? [],
        );
        final currentUserId = Provider.of<AuthProvider>(
          context,
          listen: false,
        ).user?['_id'];
        final isAttending = attendees.any(
          (attendee) =>
              attendee['user'] == currentUserId ||
              attendee['userId'] == currentUserId,
        );

        return Container(
          margin: const EdgeInsets.only(bottom: AppTheme.spacingM),
          padding: AppTheme.standardPadding,
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppTheme.spacingS),
                decoration: BoxDecoration(
                  color: isAttending
                      ? AppTheme.success.withValues(alpha: 0.1)
                      : AppTheme.muted.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                ),
                child: Icon(
                  isAttending ? Icons.event_available : Icons.event,
                  color: isAttending ? AppTheme.success : AppTheme.muted,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppTheme.spacingM),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event['title'] ?? 'Untitled Event',
                      style: AppTheme.titleLarge.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingXs),
                    Text(
                      TimeUtils.formatReadableDateTime(
                        eventDate,
                        user: Provider.of<AuthProvider>(
                          context,
                          listen: false,
                        ).user,
                        company: Provider.of<CompanyProvider>(
                          context,
                          listen: false,
                        ).currentCompany?.toJson(),
                      ),
                      style: AppTheme.bodyMedium.copyWith(
                        color: AppTheme.muted,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: AppTheme.inputPadding,
                decoration: BoxDecoration(
                  color: isAttending
                      ? AppTheme.success.withValues(alpha: 0.1)
                      : AppTheme.muted.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                ),
                child: Text(
                  isAttending ? 'Attending' : 'Not Attending',
                  style: AppTheme.smallCaption.copyWith(
                    fontWeight: FontWeight.w500,
                    color: isAttending ? AppTheme.success : AppTheme.muted,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildLocationInfoCard() {
    return Consumer<ProfileProvider>(
      builder: (context, profileProvider, child) {
        final profile = profileProvider.profile;
        final assignedLocation = profile?['assignedLocation'];

        if (assignedLocation == null) {
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: AppTheme.spacingL),
            padding: AppTheme.standardPadding,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.warning.withValues(alpha: 0.05),
                  AppTheme.warning.withValues(alpha: 0.1),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
              border: Border.all(
                color: AppTheme.warning.withValues(alpha: 0.2),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.warning.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: AppTheme.cardPadding,
                  decoration: BoxDecoration(
                    color: AppTheme.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  ),
                  child: Icon(
                    Icons.location_off_rounded,
                    color: AppTheme.warning,
                    size: 24,
                  ),
                ),
                const SizedBox(width: AppTheme.spacingL),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'No Location Assigned',
                        style: AppTheme.titleLarge.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.warning,
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacingXs),
                      Text(
                        'Contact your administrator to assign a work location for clock-in',
                        style: AppTheme.bodyMedium.copyWith(
                          color: AppTheme.warning,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: AppTheme.spacingL),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.secondary.withValues(alpha: 0.05),
                AppTheme.secondary.withValues(alpha: 0.05),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
            border: Border.all(
              color: AppTheme.secondary.withValues(alpha: 0.2),
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.secondary.withValues(alpha: 0.1),
                blurRadius: 15,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            children: [
              // Header with location icon and status
              Container(
                padding: AppTheme.standardPadding,
                child: Row(
                  children: [
                    Container(
                      padding: AppTheme.cardPadding,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppTheme.secondary, AppTheme.secondary],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusMedium,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.secondary.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.location_on_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: AppTheme.spacingL),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Work Location',
                            style: AppTheme.bodyMedium.copyWith(
                              color: AppTheme.secondary,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: AppTheme.spacingXs),
                          Text(
                            assignedLocation['name'] ?? 'Unknown Location',
                            style: AppTheme.titleLarge.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.secondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: AppTheme.inputPadding,
                      decoration: BoxDecoration(
                        color: AppTheme.success.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusLarge,
                        ),
                        border: Border.all(
                          color: AppTheme.success.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_circle_rounded,
                            color: AppTheme.success,
                            size: 16,
                          ),
                          const SizedBox(width: AppTheme.spacingXs),
                          Text(
                            'ACTIVE',
                            style: AppTheme.smallCaption.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.success,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Divider
              Container(
                height: 1,
                margin: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingL,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      AppTheme.secondary.withValues(alpha: 0.2),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),

              // Location details
              Container(
                padding: AppTheme.standardPadding,
                child: Column(
                  children: [
                    // Address
                    if (assignedLocation['address'] != null) ...[
                      _buildDetailRow(
                        icon: Icons.place_rounded,
                        iconColor: AppTheme.secondary,
                        title: 'Address',
                        value: _buildAddressString(assignedLocation['address']),
                        maxLines: 2,
                      ),
                      const SizedBox(height: AppTheme.spacingL),
                    ],

                    // Geofence and coordinates
                    Row(
                      children: [
                        Expanded(
                          child: _buildDetailRow(
                            icon: Icons.radio_button_checked_rounded,
                            iconColor: AppTheme.success,
                            title: 'Geofence',
                            value:
                                '${assignedLocation['settings']?['geofenceRadius'] ?? 100}m radius',
                          ),
                        ),
                        const SizedBox(width: AppTheme.spacingL),
                        Expanded(
                          child: _buildDetailRow(
                            icon: Icons.gps_fixed_rounded,
                            iconColor: AppTheme.primary,
                            title: 'Coordinates',
                            value:
                                '${assignedLocation['coordinates']?['latitude']?.toStringAsFixed(6) ?? 'N/A'}, ${assignedLocation['coordinates']?['longitude']?.toStringAsFixed(6) ?? 'N/A'}',
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: AppTheme.spacingL),

                    // Location Map
                    SizedBox(
                      width: double.infinity,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: AppTheme.secondary.withValues(
                                    alpha: 0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.radiusSmall,
                                  ),
                                ),
                                child: Icon(
                                  Icons.map_rounded,
                                  size: 16,
                                  color: AppTheme.secondary,
                                ),
                              ),
                              const SizedBox(width: AppTheme.spacingM),
                              Text(
                                'Location Map',
                                style: AppTheme.bodyMedium.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.muted,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppTheme.spacingM),
                          EmployeeLocationMapWidget(
                            location: assignedLocation,
                            height:
                                200, // Increased height for better visibility
                            showGeofence: true,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: AppTheme.spacingL),

                    // Working hours
                    if (assignedLocation['settings']?['workingHours'] !=
                        null) ...[
                      _buildDetailRow(
                        icon: Icons.access_time_rounded,
                        iconColor: AppTheme.warning,
                        title: 'Working Hours',
                        value:
                            '${assignedLocation['settings']['workingHours']['start'] ?? '09:00'} - ${assignedLocation['settings']['workingHours']['end'] ?? '17:00'}',
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    int maxLines = 1,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          ),
          child: Icon(icon, size: 16, color: iconColor),
        ),
        const SizedBox(width: AppTheme.spacingM),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTheme.smallCaption.copyWith(
                  color: AppTheme.muted,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: AppTheme.spacingXs),
              Text(
                value,
                style: AppTheme.bodyMedium.copyWith(
                  color: AppTheme.muted,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: maxLines,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _buildAddressString(Map<String, dynamic> address) {
    if (address['fullAddress']?.isNotEmpty == true) {
      return address['fullAddress'];
    }

    // Build address from components
    final parts = <String>[];

    // Add street address if available
    if (address['street']?.isNotEmpty == true) {
      parts.add(address['street']);
    }

    // Add city if available
    if (address['city']?.isNotEmpty == true) {
      parts.add(address['city']);
    }

    // Add state/province if available
    if (address['state']?.isNotEmpty == true) {
      parts.add(address['state']);
    }

    // Add postal code if available
    if (address['postalCode']?.isNotEmpty == true) {
      parts.add(address['postalCode']);
    }

    // Add country if available
    if (address['country']?.isNotEmpty == true) {
      parts.add(address['country']);
    }

    // If no structured address, try to use coordinates
    if (parts.isEmpty) {
      return 'Coordinates available';
    }

    return parts.join(', ');
  }
}

class _DashboardHeader extends StatelessWidget {
  final Map<String, dynamic>? profile;
  const _DashboardHeader({this.profile});
  @override
  Widget build(BuildContext context) {
    // Use local helper for capitalization
    String capitalizeFirstLetter(String text) {
      if (text.isEmpty) return text;
      return text[0].toUpperCase() + text.substring(1).toLowerCase();
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.7),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: AppTheme.standardPadding,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Centered Profile Picture
          Row(
            children: [
              Builder(
                builder: (context) {
                  final auth = context.read<AuthProvider>();
                  String? avatarUrl = context
                      .read<ProfileProvider>()
                      .avatarSignedUrl;
                  if (avatarUrl == null || avatarUrl.isEmpty) {
                    avatarUrl = profile?['avatar'];
                  }
                  if (avatarUrl == null || avatarUrl.isEmpty) {
                    avatarUrl = profile?['profilePicture'];
                  }
                  avatarUrl ??=
                      'https://via.placeholder.com/150x150/CCCCCC/666666?text=User';
                  return UserAvatar(
                    avatarUrl: avatarUrl,
                    radius: 32,
                    userId: auth.user?['_id'],
                  );
                },
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    Text(
                      'Welcome Back,',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white70,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      profile != null
                          ? '${profile?['firstName'] ?? ''} ${profile?['lastName'] ?? ''}'
                                .trim()
                          : 'Guest',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 2),
                    // Show role, position, and department
                    Builder(
                      builder: (context) {
                        final role = capitalizeFirstLetter(
                          profile?['role'] ?? '',
                        );
                        final position = profile?['position'];
                        final department = profile?['department'];

                        // Build subtitle text: show role, position, and department if available
                        String subtitleText = role;
                        if (position != null &&
                            position.toString().isNotEmpty) {
                          subtitleText += ' • $position';
                        }
                        if (department != null &&
                            department.toString().isNotEmpty) {
                          subtitleText += '\n$department';
                        }

                        return Text(
                          subtitleText,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Colors.white70,
                                fontWeight: FontWeight.w500,
                              ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class StatusCard extends StatelessWidget {
  const StatusCard({super.key});
  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: "Today's Status Card",
      container: true,
      child: Consumer<AttendanceProvider>(
        builder: (context, attendanceProvider, child) {
          final todayStatus = attendanceProvider.todayStatus;
          final currentAttendance = attendanceProvider.currentAttendance;
          final leaveInfo = attendanceProvider.leaveInfo;
          final holidayInfo = attendanceProvider.holidayInfo;
          final nonWorkingDayInfo = attendanceProvider.nonWorkingDayInfo;

          // DEBUG: Add logging to track state changes
          Logger.info(
            'StatusCard: Rebuilding - todayStatus=$todayStatus, currentAttendance=${currentAttendance != null ? "exists" : "null"}, isLoading=${attendanceProvider.isLoading}',
          );

          // If status is null and not loading, try to fetch it
          if (todayStatus == null && !attendanceProvider.isLoading) {
            final authProvider = Provider.of<AuthProvider>(
              context,
              listen: false,
            );
            final userId = authProvider.user?['_id'];
            if (userId != null) {
              Logger.info('StatusCard: Status is null, triggering fetch');
              // Trigger fetch in background
              Future.microtask(() {
                attendanceProvider.fetchTodayStatus(userId);
              });
            }
          }
          if (currentAttendance != null) {
            Logger.info(
              'StatusCard: currentAttendance keys=${currentAttendance.keys.toList()}',
            );
            Logger.info(
              'StatusCard: checkInTime=${currentAttendance['checkInTime']}',
            );
          }

          final theme = Theme.of(context);
          String statusLabel = 'Unknown Status';
          IconData statusIcon = Icons.help_outline;
          Color statusColor = theme.colorScheme.onSurface.withValues(
            alpha: 0.5,
          );
          List<Widget> statusDetails = [];

          // Check if today is a holiday or non-working day (show this instead of "Not Clocked In")
          // Priority: Holiday > Non-Working Day (day-specific restrictions take precedence over leave)
          if (holidayInfo != null && todayStatus == 'not_clocked_in') {
            final holidayName = holidayInfo['name'] ?? 'Holiday';
            final holidayType = holidayInfo['type'] ?? 'company';
            final holidayTypeLabel = holidayType == 'public'
                ? 'Public Holiday'
                : 'Company Holiday';
            statusLabel = holidayName;
            statusIcon = Icons.celebration;
            statusColor = Colors.orange[600]!;
            statusDetails.add(
              Text(
                'Today is a $holidayTypeLabel. You cannot clock in on holidays.',
                style: AppTheme.bodyMedium.copyWith(color: AppTheme.muted),
              ),
            );
            if (holidayInfo['description'] != null) {
              statusDetails.add(const SizedBox(height: 4));
              statusDetails.add(
                Text(
                  holidayInfo['description'],
                  style: AppTheme.bodyMedium.copyWith(
                    fontSize: 12,
                    color: AppTheme.muted,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              );
            }
          } else if (nonWorkingDayInfo != null &&
              todayStatus == 'not_clocked_in') {
            final nwdName =
                nonWorkingDayInfo['name'] ??
                nonWorkingDayInfo['reason'] ??
                'Non-Working Day';
            statusLabel = nwdName;
            statusIcon = Icons.event_busy;
            statusColor = Colors.orange[600]!;
            statusDetails.add(
              Text(
                'Today is a company non-working day. You cannot clock in during this period.',
                style: AppTheme.bodyMedium.copyWith(color: AppTheme.muted),
              ),
            );
            if (nonWorkingDayInfo['reason'] != null &&
                nonWorkingDayInfo['reason'] != nwdName) {
              statusDetails.add(const SizedBox(height: 4));
              statusDetails.add(
                Text(
                  'Reason: ${nonWorkingDayInfo['reason']}',
                  style: AppTheme.bodyMedium.copyWith(
                    fontSize: 12,
                    color: AppTheme.muted,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              );
            }
          } else {
            switch (todayStatus) {
              case 'not_clocked_in':
                statusLabel = 'Not Clocked In';
                statusIcon = Icons.highlight_off;
                statusColor = ThemeUtils.getStatusChipColor('error', theme);
                statusDetails.add(
                  Text(
                    'Tap Clock In to start your day',
                    style: AppTheme.bodyMedium.copyWith(color: AppTheme.muted),
                  ),
                );
                break;
              case 'clocked_in':
                statusLabel = 'Clocked In';
                statusIcon = Icons.access_time;
                statusColor =
                    theme.colorScheme.primary; // Use theme primary for branding

                // If currentAttendance is null but status is clocked_in, try to fetch it
                if (currentAttendance == null &&
                    !attendanceProvider.isLoading) {
                  final authProvider = Provider.of<AuthProvider>(
                    context,
                    listen: false,
                  );
                  final userId = authProvider.user?['_id'];
                  if (userId != null) {
                    Logger.info(
                      'StatusCard: currentAttendance is null for clocked_in status, fetching...',
                    );
                    // Trigger fetch in background
                    Future.microtask(() async {
                      try {
                        await attendanceProvider.fetchTodayStatus(userId);
                      } catch (e) {
                        Logger.error(
                          'StatusCard: Error fetching attendance data: $e',
                        );
                      }
                    });
                  }
                  // Show loading/placeholder while fetching
                  statusDetails.add(
                    Text(
                      'Loading attendance details...',
                      style: AppTheme.bodyMedium.copyWith(
                        color: AppTheme.muted,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  );
                } else if (currentAttendance != null) {
                  final checkInTime = currentAttendance['checkInTime'];
                  final breaks = currentAttendance['breaks'] as List?;
                  final dateString = currentAttendance['date'] as String?;
                  if (checkInTime != null) {
                    // Backend sends time strings (HH:mm) that need to be combined with the date
                    final checkInDateTime =
                        TimeUtils.parseTimeWithDate(checkInTime, dateString) ??
                        DateTime.now();
                    final workDuration = DateTime.now().difference(
                      checkInDateTime,
                    );
                    statusDetails.addAll([
                      // Enhanced Clock In Time Display with detailed structure (matching break timer style)
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppTheme.primary.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.login,
                                  size: 16,
                                  color: AppTheme.primary,
                                ),
                                const SizedBox(width: 6),
                                Consumer2<AuthProvider, CompanyProvider>(
                                  builder: (context, authProvider, companyProvider, _) {
                                    final user = authProvider.user;
                                    final company = companyProvider
                                        .currentCompany
                                        ?.toJson();

                                    // LOG: Debug timezone loading
                                    Logger.info(
                                      'EmployeeDashboardScreen: Clock in time display - Company is null: ${company == null}',
                                    );
                                    if (company != null) {
                                      final settings = company['settings'];
                                      if (settings != null) {
                                        Logger.info(
                                          'EmployeeDashboardScreen: Clock in display - Company timezone: ${settings['timezone']}',
                                        );
                                      }
                                    }

                                    return Text(
                                      'Clocked in at ${TimeUtils.formatTimeOnly(checkInDateTime, user: user, company: company)}',
                                      style: AppTheme.bodyMedium.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.primary,
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Working for ${_formatDuration(workDuration)}',
                              style: AppTheme.bodyMedium.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Break status information
                      if (breaks != null && breaks.isNotEmpty) ...[
                        const SizedBox(height: AppTheme.spacingS),
                        _buildBreakStatusSection(
                          context,
                          breaks,
                          currentAttendance: currentAttendance,
                        ),
                      ] else ...[
                        const SizedBox(height: AppTheme.spacingS),
                        _buildNoBreaksSection(context),
                      ],
                    ]);
                  } else {
                    // checkInTime is null - show fallback
                    statusDetails.add(
                      Text(
                        'Attendance data is incomplete',
                        style: AppTheme.bodyMedium.copyWith(
                          color: AppTheme.muted,
                        ),
                      ),
                    );
                  }
                }
                break;
              case 'clocked_out':
                statusLabel = 'Clocked Out';
                statusIcon = Icons.check_circle_outline;
                statusColor = ThemeUtils.getStatusChipColor('approved', theme);
                if (currentAttendance != null) {
                  final checkInTime = currentAttendance['checkInTime'];
                  final checkOutTime = currentAttendance['checkOutTime'];
                  final breaks = currentAttendance['breaks'] as List?;
                  final dateString = currentAttendance['date'] as String?;
                  if (checkOutTime != null) {
                    // Backend sends time strings (HH:mm) that need to be combined with the date
                    final checkOutDateTime =
                        TimeUtils.parseTimeWithDate(checkOutTime, dateString) ??
                        DateTime.now();
                    statusDetails.add(
                      Consumer2<AuthProvider, CompanyProvider>(
                        builder: (context, authProvider, companyProvider, _) {
                          final user = authProvider.user;
                          final company = companyProvider.currentCompany
                              ?.toJson();
                          return Text(
                            'Clocked out at  ${TimeUtils.formatTimeOnly(checkOutDateTime, user: user, company: company)}',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurface
                                      .withValues(alpha: 0.6),
                                  fontWeight: FontWeight.w500,
                                ),
                          );
                        },
                      ),
                    );
                  }
                  if (checkInTime != null && checkOutTime != null) {
                    // Backend sends time strings (HH:mm) that need to be combined with the date
                    final checkInDateTime =
                        TimeUtils.parseTimeWithDate(checkInTime, dateString) ??
                        DateTime.now();
                    final checkOutDateTime =
                        TimeUtils.parseTimeWithDate(checkOutTime, dateString) ??
                        DateTime.now();
                    final totalWorkTime = checkOutDateTime.difference(
                      checkInDateTime,
                    );
                    int totalBreakMinutes = 0;
                    int breakCount = 0;
                    if (breaks != null) {
                      for (final breakEntry in breaks) {
                        // Check if duration is already calculated by backend (in milliseconds)
                        if (breakEntry['duration'] != null) {
                          // Backend provides duration in milliseconds, convert to minutes
                          int durationMs = breakEntry['duration'];
                          int durationMinutes = (durationMs / (1000 * 60))
                              .round();
                          totalBreakMinutes += durationMinutes;
                          breakCount++;
                        } else {
                          // Fallback: calculate duration from start/end times
                          final startTime =
                              breakEntry['startTime'] ??
                              breakEntry['start'] ??
                              breakEntry['beginTime'];
                          final endTime =
                              breakEntry['endTime'] ??
                              breakEntry['end'] ??
                              breakEntry['finishTime'];

                          if (startTime != null && endTime != null) {
                            try {
                              final breakStart = DateTime.parse(
                                startTime,
                              ).toLocal();
                              final breakEnd = DateTime.parse(
                                endTime,
                              ).toLocal();
                              int diff = breakEnd
                                  .difference(breakStart)
                                  .inMinutes;
                              if (diff < 0) diff = 0;
                              totalBreakMinutes += diff;
                              breakCount++;
                            } catch (e) {
                              // Log parsing error but continue
                            }
                          }
                        }
                      }
                    }
                    final totalBreakDuration = Duration(
                      minutes: totalBreakMinutes,
                    );
                    final netWorkTime = totalWorkTime - totalBreakDuration;
                    final safeNetWorkTime = netWorkTime.isNegative
                        ? Duration.zero
                        : netWorkTime;
                    statusDetails.addAll([
                      const SizedBox(height: AppTheme.spacingS),
                      // Enhanced Clocked Out Display with two-column layout
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.success.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppTheme.success.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header
                            Text(
                              'Today\'s Summary',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.success,
                                  ),
                            ),
                            const SizedBox(height: 8),

                            // Two-column layout for the data
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Left Column
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Started Time
                                      Consumer2<AuthProvider, CompanyProvider>(
                                        builder:
                                            (
                                              context,
                                              authProvider,
                                              companyProvider,
                                              _,
                                            ) {
                                              final user = authProvider.user;
                                              final company = companyProvider
                                                  .currentCompany
                                                  ?.toJson();
                                              return _buildTimeRow(
                                                context,
                                                Icons.login,
                                                'Started',
                                                TimeUtils.formatTimeOnly(
                                                  checkInDateTime,
                                                  user: user,
                                                  company: company,
                                                ),
                                                Colors.green[600]!,
                                              );
                                            },
                                      ),
                                      const SizedBox(height: 2),

                                      // Total Time
                                      _buildTimeRow(
                                        context,
                                        Icons.timer,
                                        'Total Time',
                                        '${totalWorkTime.inHours}h ${totalWorkTime.inMinutes % 60}m',
                                        Colors.blue[600]!,
                                      ),
                                      const SizedBox(height: 2),

                                      // Break Time
                                      _buildTimeRow(
                                        context,
                                        Icons.coffee,
                                        'Break Time',
                                        '${totalBreakDuration.inHours}h ${totalBreakDuration.inMinutes % 60}m',
                                        Colors.orange[600]!,
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(
                                  width: 12,
                                ), // Reduced space between columns
                                // Right Column
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Finished Time
                                      Consumer2<AuthProvider, CompanyProvider>(
                                        builder:
                                            (
                                              context,
                                              authProvider,
                                              companyProvider,
                                              _,
                                            ) {
                                              final user = authProvider.user;
                                              final company = companyProvider
                                                  .currentCompany
                                                  ?.toJson();
                                              return _buildTimeRow(
                                                context,
                                                Icons.logout,
                                                'Finished',
                                                TimeUtils.formatTimeOnly(
                                                  checkOutDateTime,
                                                  user: user,
                                                  company: company,
                                                ),
                                                Colors.red[600]!,
                                              );
                                            },
                                      ),
                                      const SizedBox(height: 2),

                                      // Net Work Time
                                      _buildTimeRow(
                                        context,
                                        Icons.work,
                                        'Net Work',
                                        '${safeNetWorkTime.inHours}h ${safeNetWorkTime.inMinutes % 60}m',
                                        Colors.green[700]!,
                                      ),
                                      const SizedBox(height: 2),

                                      // Breaks Taken
                                      _buildTimeRow(
                                        context,
                                        Icons.pause_circle,
                                        'Breaks Taken',
                                        '$breakCount',
                                        Colors.purple[600]!,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ]);
                  }
                }
                break;
              case 'on_break':
                statusLabel = 'On Break';
                statusIcon = Icons.pause_circle_outline;
                statusColor = ThemeUtils.getStatusChipColor('warning', theme);
                if (currentAttendance != null) {
                  final breaks = currentAttendance['breaks'] as List?;
                  if (breaks != null && breaks.isNotEmpty) {
                    // Find the current break (where 'end' is null)
                    final currentBreak =
                        breaks
                            .cast<Map<String, dynamic>>()
                            .where((b) => b['end'] == null)
                            .isNotEmpty
                        ? breaks.cast<Map<String, dynamic>>().lastWhere(
                            (b) => b['end'] == null,
                          )
                        : null;
                    final totalBreaksToday = breaks.length;
                    if (currentBreak != null) {
                      final breakTypeId = currentBreak['type'];
                      final startTime =
                          currentBreak['start'] ?? currentBreak['startTime'];
                      if (breakTypeId != null && startTime != null) {
                        // Parse UTC time (don't convert to local - TimeUtils will handle timezone)
                        final breakStartTime = DateTime.parse(startTime);

                        // Get break type name dynamically from the stored break types
                        String breakTypeName = 'Break'; // Default fallback
                        Map<String, dynamic> breakType = {
                          'name': 'Break',
                          'duration': 15,
                        }; // Default fallback
                        final breakTypes = attendanceProvider.breakTypes;
                        if (breakTypes.isNotEmpty) {
                          breakType = breakTypes.firstWhere(
                            (type) => type['_id'] == breakTypeId,
                            orElse: () => {'name': 'Break', 'duration': 15},
                          );
                          breakTypeName = breakType['name'] ?? 'Break';
                        }
                        statusDetails.addAll([
                          Consumer2<AuthProvider, CompanyProvider>(
                            builder: (context, authProvider, companyProvider, _) {
                              final user = authProvider.user;
                              final company = companyProvider.currentCompany
                                  ?.toJson();
                              return Text(
                                '$breakTypeName since ${TimeUtils.formatTimeOnly(breakStartTime, user: user, company: company)}',
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.7),
                                      fontWeight: FontWeight.w500,
                                    ),
                              );
                            },
                          ),
                          const SizedBox(height: 8),
                          // Real-time break timer widget
                          RealTimeBreakTimer(
                            breakStartTime: breakStartTime,
                            breakTypeName: breakTypeName,
                            maxDurationMinutes:
                                breakType['duration'] ??
                                15, // Use actual break type duration
                            totalBreaksToday: totalBreaksToday,
                          ),
                        ]);
                      }
                    }
                  }
                }
                break;
              case 'on_leave':
                // Check if it's a half-day leave
                final isHalfDay = leaveInfo?['isHalfDay'] == true;
                final halfDayLeaveTime =
                    leaveInfo?['halfDayLeaveTime'] as String?;

                if (isHalfDay) {
                  statusLabel = 'Half Day Leave';
                  statusIcon = Icons.event_busy;
                  statusColor = Colors.orange[600]!;
                  if (halfDayLeaveTime != null) {
                    statusDetails.add(
                      Text(
                        'Leave time: $halfDayLeaveTime',
                        style: AppTheme.bodyMedium.copyWith(
                          color: AppTheme.muted,
                        ),
                      ),
                    );
                  }
                  // Show attendance info if user is clocked in (for half-day leave)
                  if (currentAttendance != null &&
                      currentAttendance['checkInTime'] != null) {
                    final checkInTime = currentAttendance['checkInTime'];
                    final dateString = currentAttendance['date'] as String?;
                    // Backend sends time strings (HH:mm) that need to be combined with the date
                    final checkInDateTime =
                        TimeUtils.parseTimeWithDate(checkInTime, dateString) ??
                        DateTime.now();
                    statusDetails.add(
                      const SizedBox(height: AppTheme.spacingS),
                    );
                    statusDetails.add(
                      Consumer2<AuthProvider, CompanyProvider>(
                        builder: (context, authProvider, companyProvider, _) {
                          final user = authProvider.user;
                          final company = companyProvider.currentCompany
                              ?.toJson();
                          return Text(
                            'Clocked in at ${TimeUtils.formatTimeOnly(checkInDateTime, user: user, company: company)}',
                            style: AppTheme.bodyMedium.copyWith(
                              color: AppTheme.muted,
                            ),
                          );
                        },
                      ),
                    );
                  }
                } else {
                  statusLabel = 'On Leave';
                  statusIcon = Icons.event_busy;
                  statusColor = Colors.orange[600]!;
                  if (leaveInfo != null) {
                    final leaveType = leaveInfo['type'] as String?;
                    if (leaveType != null) {
                      statusDetails.add(
                        Text(
                          'Leave type: $leaveType',
                          style: AppTheme.bodyMedium.copyWith(
                            color: AppTheme.muted,
                          ),
                        ),
                      );
                    }
                  }
                }
                break;
              default:
                statusLabel = 'Status Not Available';
                statusIcon = Icons.info_outline;
                statusColor = theme.colorScheme.onSurface.withValues(
                  alpha: 0.5,
                );
                break;
            }
          }

          return Card(
            elevation: AppTheme.elevationMedium,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
            ),
            child: Padding(
              padding: AppTheme.standardPadding,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Today\'s Status',
                          style: AppTheme.titleLarge.copyWith(
                            color: AppTheme.muted, // Improved contrast
                          ),
                        ),
                        const SizedBox(height: AppTheme.spacingS),
                        Row(
                          children: [
                            Semantics(
                              label: statusLabel,
                              child: Icon(
                                statusIcon,
                                color: statusColor,
                                size: 30,
                              ),
                            ),
                            const SizedBox(width: AppTheme.spacingS),
                            Flexible(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        statusLabel,
                                        style: AppTheme.titleLarge.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: statusColor,
                                        ),
                                      ),
                                      Icon(
                                        Icons.check_circle,
                                        size: 20,
                                        color: AppTheme.success,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: AppTheme.spacingXs),
                                  ...statusDetails,
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ); // Padding
        }, // Consumer
      ), // Semantics
    );
  }

  // Helper method to build time information rows
  Widget _buildTimeRow(
    BuildContext context,
    IconData icon,
    String label,
    String value,
    Color color,
  ) {
    return Row(
      children: [
        Icon(
          icon,
          size: 12, // Smaller icon
          color: color,
        ),
        const SizedBox(width: 3), // Minimal spacing
        Flexible(
          child: Row(
            children: [
              Text(
                '$label: ',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                  fontSize: 11, // Smaller font size
                ),
              ),
              Expanded(
                child: Text(
                  value,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 11, // Smaller font size
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Helper method to build break status section
  Widget _buildBreakStatusSection(
    BuildContext context,
    List breaks, {
    Map<String, dynamic>? currentAttendance,
  }) {
    // Debug logging

    final completedBreaks = breaks.where((b) => b['end'] != null).toList();
    final totalBreaksToday = completedBreaks.length;
    final mostRecentBreak = breaks.isNotEmpty ? breaks.last : null;

    if (mostRecentBreak != null) {
      final breakTypeId = mostRecentBreak['type'];
      final breakStartTime = mostRecentBreak['start'];
      final breakEndTime = mostRecentBreak['end'];
      String breakTypeName = 'Break';
      final attendanceProvider = Provider.of<AttendanceProvider>(
        context,
        listen: false,
      );
      final breakTypes = attendanceProvider.breakTypes;
      if (breakTypes.isNotEmpty) {
        final breakType = breakTypes.firstWhere(
          (type) => type['_id'] == breakTypeId,
          orElse: () => {'name': 'Break'},
        );
        breakTypeName = breakType['name'] ?? 'Break';
      }
      // Parse break times - might be ISO strings or time-only strings
      final dateString = currentAttendance?['date'] as String?;
      final breakStart = breakStartTime != null
          ? TimeUtils.parseTimeWithDate(breakStartTime, dateString)
          : null;
      final breakEnd = breakEndTime != null
          ? TimeUtils.parseTimeWithDate(breakEndTime, dateString)
          : null;
      final now = DateTime.now();
      final isOngoing = breakEndTime == null;
      final breakDuration =
          (breakStart != null && (breakEnd != null || isOngoing))
          ? ((isOngoing ? now : breakEnd!).difference(breakStart))
          : Duration.zero;
      return InkWell(
        onTap: () => _showAllBreaksDialog(
          context,
          breaks,
          attendanceProvider.breakTypes,
          currentAttendance: currentAttendance,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        child: Container(
          padding: AppTheme.cardPadding,
          decoration: BoxDecoration(
            color: AppTheme.success.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            border: Border.all(color: AppTheme.success.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.coffee, size: 16, color: AppTheme.success),
                  const SizedBox(width: AppTheme.spacingXs),
                  Text(
                    'Break Status',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.success,
                    ),
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Text(
                        totalBreaksToday > 1 ? 'View All' : 'View Details',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 12,
                        color: AppTheme.primary,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spacingXs),
              Row(
                children: [
                  Icon(Icons.check_circle, size: 14, color: AppTheme.success),
                  const SizedBox(width: AppTheme.spacingXs),
                  Text(
                    'Breaks taken: ',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    '$totalBreaksToday',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spacingXs),
              Row(
                children: [
                  Icon(Icons.label, size: 14, color: AppTheme.success),
                  const SizedBox(width: AppTheme.spacingXs),
                  Text(
                    'Last break: ',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    breakTypeName,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spacingXs),
              Row(
                children: [
                  Icon(Icons.schedule, size: 14, color: AppTheme.success),
                  const SizedBox(width: AppTheme.spacingXs),
                  Text(
                    'Time: ',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (breakStart != null && isOngoing)
                    Consumer2<AuthProvider, CompanyProvider>(
                      builder: (context, authProvider, companyProvider, _) {
                        final user = authProvider.user;
                        final company = companyProvider.currentCompany
                            ?.toJson();
                        return Text(
                          '${TimeUtils.formatTimeOnly(breakStart, user: user, company: company)} - In Progress',
                          style: Theme.of(context).textTheme.bodySmall,
                        );
                      },
                    )
                  else if (breakStart != null && breakEnd != null)
                    Consumer2<AuthProvider, CompanyProvider>(
                      builder: (context, authProvider, companyProvider, _) {
                        final user = authProvider.user;
                        final company = companyProvider.currentCompany
                            ?.toJson();
                        return Text(
                          '${TimeUtils.formatTimeOnly(breakStart, user: user, company: company)} - ${TimeUtils.formatTimeOnly(breakEnd, user: user, company: company)}',
                          style: Theme.of(context).textTheme.bodySmall,
                        );
                      },
                    ),
                ],
              ),
              const SizedBox(height: AppTheme.spacingXs),
              Row(
                children: [
                  Icon(Icons.timer, size: 14, color: AppTheme.success),
                  const SizedBox(width: AppTheme.spacingXs),
                  Text(
                    'Duration: ',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    isOngoing
                        ? '${breakDuration.inMinutes}m (ongoing)'
                        : '${breakDuration.inHours}h ${breakDuration.inMinutes % 60}m',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }
    // If no breaks at all
    return _buildNoBreaksSection(context);
  }

  // Helper method to build no breaks section
  Widget _buildNoBreaksSection(BuildContext context) {
    return Container(
      padding: AppTheme.cardPadding,
      decoration: BoxDecoration(
        color: AppTheme.muted.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        border: Border.all(color: AppTheme.muted.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 16, color: AppTheme.muted),
          const SizedBox(width: 6),
          Text(
            'No breaks taken today',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.muted,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  // Show dialog with all breaks for today
  void _showAllBreaksDialog(
    BuildContext context,
    List breaks,
    List<Map<String, dynamic>> breakTypes, {
    Map<String, dynamic>? currentAttendance,
  }) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final companyProvider = Provider.of<CompanyProvider>(
      context,
      listen: false,
    );
    final user = authProvider.user;
    final company = companyProvider.currentCompany?.toJson();

    // Get date string from currentAttendance or use today's date as fallback
    final dateString = currentAttendance?['date'] as String?;

    // Sort breaks by start time (most recent first)
    final sortedBreaks = List.from(breaks);
    sortedBreaks.sort((a, b) {
      // Parse break start times for sorting - handle both ISO strings and time-only strings
      final aStartTime = a['start'];
      final bStartTime = b['start'];
      final aStart = aStartTime != null
          ? (TimeUtils.parseTimeWithDate(
                  aStartTime,
                  dateString,
                )?.millisecondsSinceEpoch ??
                0)
          : 0;
      final bStart = bStartTime != null
          ? (TimeUtils.parseTimeWithDate(
                  bStartTime,
                  dateString,
                )?.millisecondsSinceEpoch ??
                0)
          : 0;
      return bStart.compareTo(aStart); // Descending order
    });

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        ),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400, maxHeight: 600),
          padding: const EdgeInsets.all(AppTheme.spacingL),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.coffee, color: AppTheme.primary),
                  const SizedBox(width: AppTheme.spacingS),
                  Text(
                    'All Breaks Today',
                    style: AppTheme.titleLarge.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spacingM),
              Text(
                'Total: ${breaks.length} break${breaks.length != 1 ? 's' : ''}',
                style: AppTheme.bodyMedium.copyWith(
                  color: AppTheme.muted,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: AppTheme.spacingM),
              Flexible(
                child: sortedBreaks.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(AppTheme.spacingL),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 48,
                                color: AppTheme.muted,
                              ),
                              const SizedBox(height: AppTheme.spacingM),
                              Text(
                                'No breaks recorded',
                                style: AppTheme.bodyMedium.copyWith(
                                  color: AppTheme.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: sortedBreaks.length,
                        itemBuilder: (context, index) {
                          final breakRecord = sortedBreaks[index];
                          final breakTypeId = breakRecord['type'];
                          final breakStartTime = breakRecord['start'];
                          final breakEndTime = breakRecord['end'];

                          // Get break type name
                          String breakTypeName = 'Break';
                          if (breakTypes.isNotEmpty && breakTypeId != null) {
                            final breakType = breakTypes.firstWhere(
                              (type) => type['_id'] == breakTypeId,
                              orElse: () => {
                                'displayName': 'Break',
                                'name': 'Break',
                              },
                            );
                            breakTypeName =
                                breakType['displayName'] ??
                                breakType['name'] ??
                                'Break';
                          }

                          // Parse times - break times might be ISO strings or time-only strings
                          // Get date from current attendance record if available
                          final dateString =
                              currentAttendance?['date'] as String?;
                          final breakStart = breakStartTime != null
                              ? TimeUtils.parseTimeWithDate(
                                  breakStartTime,
                                  dateString,
                                )
                              : null;
                          final breakEnd = breakEndTime != null
                              ? TimeUtils.parseTimeWithDate(
                                  breakEndTime,
                                  dateString,
                                )
                              : null;

                          final now = DateTime.now();
                          final isOngoing = breakEndTime == null;
                          final breakDuration =
                              (breakStart != null &&
                                  (breakEnd != null || isOngoing))
                              ? ((isOngoing ? now : breakEnd!).difference(
                                  breakStart,
                                ))
                              : Duration.zero;

                          // Format times with timezone
                          String startTimeStr = 'N/A';
                          String endTimeStr = isOngoing ? 'In Progress' : 'N/A';

                          if (breakStart != null) {
                            final formatted =
                                TimeUtils.formatTimeWithSmartTimezone(
                                  breakStart,
                                  user: user,
                                  company: company,
                                );
                            startTimeStr = formatted.length >= 5
                                ? formatted.substring(0, 5)
                                : formatted;
                          }

                          if (breakEnd != null) {
                            final formatted =
                                TimeUtils.formatTimeWithSmartTimezone(
                                  breakEnd,
                                  user: user,
                                  company: company,
                                );
                            endTimeStr = formatted.length >= 5
                                ? formatted.substring(0, 5)
                                : formatted;
                          }

                          return Container(
                            margin: const EdgeInsets.only(
                              bottom: AppTheme.spacingM,
                            ),
                            padding: const EdgeInsets.all(AppTheme.spacingM),
                            decoration: BoxDecoration(
                              color: AppTheme.success.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(
                                AppTheme.radiusMedium,
                              ),
                              border: Border.all(
                                color: isOngoing
                                    ? AppTheme.warning.withValues(alpha: 0.3)
                                    : AppTheme.success.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.coffee,
                                      size: 18,
                                      color: isOngoing
                                          ? AppTheme.warning
                                          : AppTheme.success,
                                    ),
                                    const SizedBox(width: AppTheme.spacingS),
                                    Expanded(
                                      child: Text(
                                        breakTypeName,
                                        style: AppTheme.bodyLarge.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: isOngoing
                                              ? AppTheme.warning
                                              : AppTheme.success,
                                        ),
                                      ),
                                    ),
                                    if (isOngoing)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: AppTheme.spacingS,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppTheme.warning.withValues(
                                            alpha: 0.2,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            AppTheme.radiusSmall,
                                          ),
                                        ),
                                        child: Text(
                                          'Ongoing',
                                          style: AppTheme.smallCaption.copyWith(
                                            color: AppTheme.warning,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: AppTheme.spacingS),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.schedule,
                                      size: 14,
                                      color: AppTheme.muted,
                                    ),
                                    const SizedBox(width: AppTheme.spacingXs),
                                    Text(
                                      '$startTimeStr - $endTimeStr',
                                      style: AppTheme.bodyMedium,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: AppTheme.spacingXs),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.timer,
                                      size: 14,
                                      color: AppTheme.muted,
                                    ),
                                    const SizedBox(width: AppTheme.spacingXs),
                                    Text(
                                      isOngoing
                                          ? 'Duration: ${breakDuration.inMinutes}m (ongoing)'
                                          : 'Duration: ${breakDuration.inHours}h ${breakDuration.inMinutes % 60}m',
                                      style: AppTheme.bodyMedium,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
              const SizedBox(height: AppTheme.spacingM),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  final bool isOnBreak;
  final bool isOnLeave;
  final bool isHoliday;
  final bool isNonWorkingDay;
  final bool isClockedIn;
  final String? leaveEndDate;
  final Map<String, dynamic>? holidayInfo;
  final Map<String, dynamic>? nonWorkingDayInfo;
  final bool isBreakActionInProgress;
  final bool isClockInInProgress;
  final VoidCallback clockIn;
  final VoidCallback clockOut;
  final Future<void> Function() startBreak;
  final Future<void> Function() endBreak;
  final Function(BuildContext) applyLeave;
  final Function(BuildContext) openTimesheet;
  final Function(BuildContext) openProfile;
  final Function(BuildContext) openEvents;
  final Function(BuildContext) openCompanyInfo;

  const _QuickActions({
    required this.isOnBreak,
    required this.isOnLeave,
    required this.isHoliday,
    required this.isNonWorkingDay,
    required this.isClockedIn,
    this.leaveEndDate,
    this.holidayInfo,
    this.nonWorkingDayInfo,
    required this.isBreakActionInProgress,
    required this.isClockInInProgress,
    required this.clockIn,
    required this.clockOut,
    required this.startBreak,
    required this.endBreak,
    required this.applyLeave,
    required this.openTimesheet,
    required this.openProfile,
    required this.openEvents,
    required this.openCompanyInfo,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Dynamic Quick Actions with better spacing and proportions
        LayoutBuilder(
          builder: (context, constraints) {
            final cardHeight =
                80.0; // Further reduced height to prevent overflow
            final spacing = 12.0; // Consistent spacing

            return Column(
              children: [
                // First row: Clock In (spans both columns) or Clock Out + Start Break
                // CRITICAL FIX: Hide attendance buttons when user is on leave, holiday, or non-working day
                if (!isOnLeave && !isHoliday && !isNonWorkingDay) ...[
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    child: Row(
                      children: [
                        if (!isClockedIn) ...[
                          // Clock In button spanning both columns
                          Expanded(
                            key: const Key('clock_in_button'),
                            child: _buildEnhancedClockInCard(
                              context,
                              onPressed: clockIn,
                              height: cardHeight,
                            ),
                          ),
                        ] else ...[
                          // When clocked in, show Clock Out and Start Break in separate columns
                          Expanded(
                            child: _buildQuickActionCard(
                              context,
                              icon: Icons.logout,
                              label: 'Clock Out',
                              color: const Color(0xFFFF5722),
                              onPressed: clockOut,
                              height: cardHeight,
                            ),
                          ),
                          SizedBox(width: spacing),
                          Expanded(
                            child: Consumer<AttendanceProvider>(
                              builder: (context, attendanceProvider, child) {
                                bool isDisabled = false;

                                // Check minimum duration validation for break end
                                if (attendanceProvider.isOnBreak) {
                                  final currentAttendance =
                                      attendanceProvider.currentAttendance;
                                  if (currentAttendance != null &&
                                      currentAttendance['breaks'] != null) {
                                    final breaks =
                                        currentAttendance['breaks'] as List;
                                    if (breaks.isNotEmpty) {
                                      final currentBreak = breaks.last;
                                      final breakStartTime =
                                          currentBreak['startTime'] ??
                                          currentBreak['start'];

                                      if (breakStartTime != null) {
                                        try {
                                          final startTime = DateTime.parse(
                                            breakStartTime,
                                          ).toLocal();
                                          final now = DateTime.now();
                                          final breakDuration = now.difference(
                                            startTime,
                                          );
                                          final breakDurationMinutes =
                                              breakDuration.inMinutes;

                                          // Use 30 seconds minimum duration
                                          const minDuration = 0.5;

                                          if (breakDurationMinutes <
                                              minDuration) {
                                            isDisabled = true;
                                          }
                                        } catch (e) {
                                          // If parsing fails, allow break end
                                        }
                                      }
                                    }
                                  }
                                }

                                return _buildQuickActionCard(
                                  context,
                                  icon: isBreakActionInProgress
                                      ? Icons.hourglass_empty
                                      : (attendanceProvider.isOnBreak
                                            ? Icons.stop
                                            : Icons.coffee),
                                  label: isBreakActionInProgress
                                      ? 'Processing...'
                                      : (attendanceProvider.isOnBreak
                                            ? 'End Break'
                                            : 'Start Break'),
                                  color: isBreakActionInProgress
                                      ? Colors.grey
                                      : (attendanceProvider.isOnBreak
                                            ? const Color(0xFFE91E63)
                                            : const Color(0xFFFF9800)),
                                  onPressed:
                                      (isDisabled || isBreakActionInProgress)
                                      ? null
                                      : (attendanceProvider.isOnBreak
                                            ? endBreak
                                            : startBreak),
                                  height: cardHeight,
                                  isDisabled:
                                      isDisabled || isBreakActionInProgress,
                                );
                              },
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ] else ...[
                  // Show status message when on holiday, non-working day, or leave
                  // Priority: Holiday > Non-Working Day > Leave (day-specific restrictions take precedence)
                  if (isHoliday && holidayInfo != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.orange.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.celebration,
                            color: Colors.orange,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Attendance actions are disabled on company holidays',
                                  style: TextStyle(
                                    color: Colors.orange[700],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${holidayInfo!['type'] == 'public' ? 'Public Holiday' : 'Company Holiday'}: ${holidayInfo!['name'] ?? 'Holiday'}',
                                  style: TextStyle(
                                    color: Colors.orange[600],
                                    fontSize: 12,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else if (isNonWorkingDay && nonWorkingDayInfo != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.orange.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.event_busy,
                            color: Colors.orange,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Attendance actions are disabled on non-working days',
                                  style: TextStyle(
                                    color: Colors.orange[700],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Non-working day: ${nonWorkingDayInfo!['name'] ?? nonWorkingDayInfo!['reason'] ?? 'Non-Working Day'}',
                                  style: TextStyle(
                                    color: Colors.orange[600],
                                    fontSize: 12,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else if (isOnLeave) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.orange.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Colors.orange,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Attendance actions are disabled during your leave period',
                                  style: TextStyle(
                                    color: Colors.orange[700],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Leave ends: ${leaveEndDate != null ? TimeUtils.formatReadableDate(DateTime.parse(leaveEndDate!), user: Provider.of<AuthProvider>(context, listen: false).user, company: Provider.of<CompanyProvider>(context, listen: false).currentCompany?.toJson()) : 'N/A'}',
                                  style: TextStyle(
                                    color: Colors.orange[600],
                                    fontSize: 12,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
                SizedBox(height: spacing),
                // Second row: Apply Leave and Timesheet
                Consumer<FeatureProvider>(
                  builder: (context, featureProvider, _) {
                    return Row(
                      children: [
                        if (featureProvider.hasLeaveManagement) ...[
                          Expanded(
                            child: _buildQuickActionCard(
                              context,
                              icon: Icons.calendar_today,
                              label: 'Apply Leave',
                              color: const Color(0xFF2196F3),
                              onPressed: () => applyLeave(context),
                              height: cardHeight,
                            ),
                          ),
                          SizedBox(width: spacing),
                        ],
                        if (featureProvider.hasTimeTracking) ...[
                          Expanded(
                            child: _buildQuickActionCard(
                              context,
                              icon: Icons.access_time,
                              label: 'Timesheet',
                              color: const Color(0xFF9C27B0),
                              onPressed: () => openTimesheet(context),
                              height: cardHeight,
                            ),
                          ),
                        ] else if (featureProvider.hasLeaveManagement) ...[
                          // If only leave management is enabled, make it span full width
                          Expanded(
                            child: _buildQuickActionCard(
                              context,
                              icon: Icons.calendar_today,
                              label: 'Apply Leave',
                              color: const Color(0xFF2196F3),
                              onPressed: () => applyLeave(context),
                              height: cardHeight,
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                ),
                SizedBox(height: spacing),
                // Third row: Profile and Events
                Consumer<FeatureProvider>(
                  builder: (context, featureProvider, _) {
                    return Row(
                      children: [
                        if (featureProvider.hasProfile) ...[
                          Expanded(
                            child: _buildQuickActionCard(
                              context,
                              icon: Icons.person,
                              label: 'Profile',
                              color: const Color(0xFF607D8B),
                              onPressed: () => openProfile(context),
                              height: cardHeight,
                            ),
                          ),
                          if (featureProvider.hasEvents) ...[
                            SizedBox(width: spacing),
                            Expanded(
                              child: _buildQuickActionCard(
                                context,
                                icon: Icons.event,
                                label: 'Events',
                                color: const Color(0xFFFF9800),
                                onPressed: () => openEvents(context),
                                height: cardHeight,
                              ),
                            ),
                          ],
                        ] else if (featureProvider.hasEvents) ...[
                          // If only events is enabled, make it span full width
                          Expanded(
                            child: _buildQuickActionCard(
                              context,
                              icon: Icons.event,
                              label: 'Events',
                              color: const Color(0xFFFF9800),
                              onPressed: () => openEvents(context),
                              height: cardHeight,
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildEnhancedClockInCard(
    BuildContext context, {
    required VoidCallback onPressed,
    required double height,
  }) {
    // Check if user has already clocked out today, is on leave, it's a holiday, or it's a non-working day
    final attendanceProvider = Provider.of<AttendanceProvider>(
      context,
      listen: false,
    );
    final todayStatus = attendanceProvider.todayStatus;
    final isOnLeave = attendanceProvider.leaveInfo != null;
    final isHoliday = attendanceProvider.holidayInfo != null;
    final isNonWorkingDay = attendanceProvider.nonWorkingDayInfo != null;
    final isDisabled =
        todayStatus == 'clocked_out' ||
        todayStatus == 'Clocked Out' ||
        isOnLeave ||
        isHoliday ||
        isNonWorkingDay ||
        // Disable while a clock-in request is already in progress
        (isClockInInProgress == true);

    // Determine disabled reason text
    String disabledText = 'Completed for today';
    String disabledSubtext = '';
    if (isHoliday) {
      final holidayName = attendanceProvider.holidayInfo?['name'] ?? 'Holiday';
      disabledText = 'HOLIDAY';
      disabledSubtext = holidayName;
    } else if (isNonWorkingDay) {
      final nwdName =
          attendanceProvider.nonWorkingDayInfo?['name'] ??
          attendanceProvider.nonWorkingDayInfo?['reason'] ??
          'Non-Working Day';
      disabledText = 'NON-WORKING DAY';
      disabledSubtext = nwdName;
    } else if (isOnLeave) {
      disabledText = 'ON LEAVE';
      final leaveType = attendanceProvider.leaveInfo?['type'] ?? 'Leave';
      disabledSubtext = leaveType;
    } else if (todayStatus == 'clocked_out' || todayStatus == 'Clocked Out') {
      disabledText = 'ALREADY CLOCKED OUT';
      disabledSubtext = 'Completed for today';
    }

    return Card(
      elevation: isDisabled ? AppTheme.elevationLow : AppTheme.elevationHigh,
      shadowColor: isDisabled
          ? AppTheme.muted.withValues(alpha: 0.2)
          : AppTheme.success.withValues(alpha: 0.4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
      ),
      child: InkWell(
        onTap: isDisabled ? null : onPressed,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        child: Container(
          height: height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDisabled
                  ? [
                      AppTheme.muted,
                      AppTheme.muted.withValues(alpha: 0.8),
                      AppTheme.muted.withValues(alpha: 0.7),
                    ]
                  : [
                      AppTheme.success,
                      AppTheme.success.withValues(alpha: 0.8),
                      AppTheme.success.withValues(alpha: 0.7),
                    ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
            boxShadow: [
              BoxShadow(
                color: isDisabled
                    ? AppTheme.muted.withValues(alpha: 0.2)
                    : AppTheme.success.withValues(alpha: 0.3),
                blurRadius: isDisabled ? 8 : 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ), // Minimal padding
          child: Row(
            // Changed to Row layout for better space utilization
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon with minimal background
              Container(
                padding: const EdgeInsets.all(6), // Minimal padding
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: isDisabled ? 0.1 : 0.2),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  border: Border.all(
                    color: Colors.white.withValues(
                      alpha: isDisabled ? 0.1 : 0.3,
                    ),
                    width: 1,
                  ),
                ),
                child: Icon(
                  isDisabled ? Icons.block : Icons.login_rounded,
                  color: Colors.white.withValues(alpha: isDisabled ? 0.6 : 1.0),
                  size: 18, // Smaller icon
                ),
              ),
              const SizedBox(width: 12), // Horizontal spacing
              // Text content in column
              Flexible(
                fit: FlexFit.loose,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isDisabled ? disabledText : 'CLOCK IN',
                      style: AppTheme.bodyMedium.copyWith(
                        color: Colors.white.withValues(
                          alpha: isDisabled ? 0.7 : 1.0,
                        ),
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                        shadows: [
                          Shadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            offset: const Offset(0, 1),
                            blurRadius: 2,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 2), // Minimal spacing
                    Text(
                      isDisabled ? disabledSubtext : 'Start Your Day',
                      style: AppTheme.smallCaption.copyWith(
                        color: Colors.white.withValues(
                          alpha: isDisabled ? 0.6 : 0.9,
                        ),
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
              // Action indicator
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: isDisabled ? 0.1 : 0.2),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                  border: Border.all(
                    color: Colors.white.withValues(
                      alpha: isDisabled ? 0.1 : 0.3,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isClockInInProgress == true) ...[
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white.withValues(alpha: 1.0),
                          ),
                        ),
                      ),
                    ] else ...[
                      Icon(
                        isDisabled ? Icons.lock : Icons.touch_app,
                        color: Colors.white.withValues(
                          alpha: isDisabled ? 0.6 : 1.0,
                        ),
                        size: 10, // Very small icon
                      ),
                      const SizedBox(width: 3),
                      Text(
                        isDisabled ? 'LOCKED' : 'TAP',
                        style: AppTheme.smallCaption.copyWith(
                          color: Colors.white.withValues(
                            alpha: isDisabled ? 0.6 : 1.0,
                          ),
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.3,
                          fontSize: 9, // Very small font
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActionCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    VoidCallback? onPressed,
    double? height,
    bool isLarge = false, // For Clock In button when it spans both columns
    bool isDisabled = false, // For minimum duration validation
  }) {
    return Card(
      elevation: isDisabled ? 0 : AppTheme.elevationMedium,
      shadowColor: isDisabled
          ? Colors.transparent
          : color.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
      ),
      child: InkWell(
        onTap: isDisabled ? null : onPressed,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        child: Container(
          height: height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDisabled
                  ? [Colors.grey[300]!, Colors.grey[400]!, Colors.grey[500]!]
                  : [
                      color,
                      color.withValues(alpha: 0.9),
                      color.withValues(alpha: 0.8),
                    ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
            boxShadow: isDisabled
                ? []
                : [
                    BoxShadow(
                      color: color.withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 6,
          ), // Minimal padding
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Compact icon with minimal background
              Container(
                padding: const EdgeInsets.all(4), // Minimal padding
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                ),
                child: Icon(
                  icon,
                  color: isDisabled ? Colors.grey[600] : Colors.white,
                  size: isLarge ? 16 : 14, // Very small icons
                ),
              ),
              const SizedBox(height: 4), // Minimal spacing
              Text(
                label,
                style: AppTheme.smallCaption.copyWith(
                  color: isDisabled ? Colors.grey[600] : Colors.white,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.2,
                  fontSize: 11, // Small font size
                  shadows: isDisabled
                      ? []
                      : [
                          Shadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            offset: const Offset(0, 1),
                            blurRadius: 2,
                          ),
                        ],
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// TODO: Audit for accessibility (color contrast) and add semantic labels for better screen reader support.
// Accessibility: Improved color contrast and added semantic labels for all interactive elements and status displays.
