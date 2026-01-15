import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:sns_rooster/config/api_config.dart';
import 'package:sns_rooster/providers/attendance_provider.dart';
import 'package:sns_rooster/providers/auth_provider.dart';
import 'package:sns_rooster/providers/company_provider.dart';
import 'package:sns_rooster/providers/feature_provider.dart';
import 'package:sns_rooster/screens/admin/admin_timesheet_screen.dart';
import 'package:sns_rooster/screens/admin/analytics_reports_screen.dart';
import 'package:sns_rooster/screens/admin/attendance_management_screen.dart';
import 'package:sns_rooster/screens/admin/break_management_screen.dart';
import 'package:sns_rooster/screens/admin/company_settings_screen.dart';
import 'package:sns_rooster/screens/admin/employee_management_screen.dart';
import 'package:sns_rooster/screens/admin/leave_management_screen.dart';
import 'package:sns_rooster/screens/admin/payroll_management_screen.dart';
import 'package:sns_rooster/screens/admin/settings_screen.dart';
import 'package:sns_rooster/services/secure_storage_service.dart';
import 'package:sns_rooster/theme/app_theme.dart';
import 'package:sns_rooster/utils/admin_leave_restrictions.dart';
import 'package:sns_rooster/utils/logger.dart';
import 'package:sns_rooster/utils/theme_utils.dart';
import 'package:sns_rooster/utils/time_utils.dart';
import 'package:sns_rooster/utils/global_navigator.dart';
import 'package:sns_rooster/widgets/admin_side_navigation.dart';

import '../../api/exceptions.dart' as api_exceptions;
import '../../core/repository/dashboard_repository.dart';
import '../../core/services/hive_service.dart';
import '../../providers/notification_provider.dart';
import '../../services/api_service.dart';
import '../../services/connectivity_service.dart';
import '../../services/global_notification_service.dart';
import '../../widgets/company_notifications_widget.dart';
import '../../widgets/shared_app_bar.dart';
import '../onboarding/setup_guide_screen.dart';
import 'broadcast_notification_screen.dart';
import 'dashboard_coach_keys.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  bool _navCardTapped = false;
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic> _dashboardData = {};
  final GlobalKey employeeQuickActionKey = GlobalKey();
  final GlobalKey todaysAttendanceCardKey = GlobalKey();

  // Move PageController and currentPage to class level
  late final PageController _pageController;
  // Scroll controller for quick actions horizontal row (reused across builds)
  final ScrollController _quickActionsScrollController = ScrollController();

  // Real-time update mechanisms
  Timer? _periodicRefreshTimer;
  StreamSubscription<RemoteMessage>? _fcmSubscription;
  bool _isRefreshing = false; // Prevent concurrent refreshes
  DateTime? _lastRefreshTime;
  static const Duration _refreshInterval = Duration(
    minutes: 1,
  ); // Periodic fallback refresh every 1 minute
  static const Duration _minRefreshGap = Duration(
    seconds: 10,
  ); // Minimum gap between refreshes
  // Cache TTL - matches dashboard_repository.dart

  // GlobalKeys now declared in dashboard_coach_keys.dart for reuse
  late final DashboardRepository _dashboardRepository;
  late final ConnectivityService _connectivityService;
  late final ApiService _apiService;
  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    // initialize reusable service instance once
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    // Get ConnectivityService from Provider, with fallback to new instance if not found
    try {
      _connectivityService = Provider.of<ConnectivityService>(
        context,
        listen: false,
      );
    } catch (e) {
      // Fallback: create new instance if Provider is not available (shouldn't happen in normal flow)
      Logger.warning(
        'Admin Dashboard: ConnectivityService not found in Provider tree, creating new instance',
      );
      _connectivityService = ConnectivityService();
    }
    _apiService = ApiService(baseUrl: ApiConfig.baseUrl);
    _dashboardRepository = DashboardRepository(
      connectivityService: _connectivityService,
      hiveService: HiveService(),
      apiService: _apiService,
      authProvider: authProvider,
    );

    WidgetsBinding.instance.addObserver(this); // Listen to app lifecycle
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<NotificationProvider>(
        context,
        listen: false,
      ).fetchNotifications();
      // Load features for the dashboard
      if (authProvider.featureProvider != null) {
        Logger.info('Dashboard: Loading features on init');
        authProvider.featureProvider!
            .loadFeatures()
            .then((_) {
              Logger.info('Dashboard: Features loaded successfully');
            })
            .catchError((e) {
              Logger.error('Dashboard: Failed to load features: $e');
            });
      } else {
        Logger.warning('Dashboard: FeatureProvider is null during init');
      }
    });
    _loadDashboardData();
    _checkOnboardingStatus();
    _setupConnectivityListener();
    _setupFCMListener();
    _startPeriodicRefresh();
  }

  void _setupConnectivityListener() {
    // Listen to connectivity changes for automatic retry
    final connectivityService = Provider.of<ConnectivityService>(
      context,
      listen: false,
    );
    bool wasOffline = !connectivityService.isFullyOnline;

    connectivityService.addConnectivityListener((isOnline) {
      final previouslyOffline = wasOffline;
      wasOffline = !isOnline;

      // If we just came back online and were previously offline, automatically retry
      if (mounted && isOnline && previouslyOffline) {
        Logger.info(
          'Admin Dashboard: Connectivity restored, auto-retrying data load',
        );

        // Show connection restored message
        GlobalNotificationService().showSuccess(
          'Connection restored! Refreshing data...',
          duration: const Duration(seconds: 3),
        );

        // Clear error state and retry loading dashboard data
        setState(() {
          _errorMessage = null;
        });

        // Retry after a short delay to ensure server is ready
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            _loadDashboardData();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _periodicRefreshTimer?.cancel();
    _fcmSubscription?.cancel();
    _pageController.dispose();
    _quickActionsScrollController.dispose();
    super.dispose();
  }

  /// Handle app lifecycle changes - pause/resume periodic refresh
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // App resumed - restart periodic refresh and refresh data
      Logger.info('Admin Dashboard: App resumed, restarting refresh');
      _startPeriodicRefresh();
      _refreshDashboardDataIfNeeded();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      // App paused - stop periodic refresh to save resources
      Logger.info('Admin Dashboard: App paused, stopping periodic refresh');
      _stopPeriodicRefresh();
    }
  }

  /// Setup FCM listener for real-time attendance updates
  void _setupFCMListener() {
    try {
      _fcmSubscription = FirebaseMessaging.onMessage.listen((
        RemoteMessage msg,
      ) async {
        // Only refresh if message is related to attendance or dashboard
        final messageType = msg.data['type'] as String?;
        if (messageType == 'attendance' ||
            messageType == 'dashboard' ||
            messageType == 'admin_dashboard') {
          Logger.info(
            'Admin Dashboard: Received FCM update notification, refreshing data immediately',
          );
          // Force refresh to bypass cache and get latest data
          _refreshDashboardDataIfNeeded(forceRefresh: true);
        }
      });
      Logger.info('Admin Dashboard: FCM listener setup complete');
    } catch (e) {
      Logger.warning('Admin Dashboard: Error setting up FCM listener: $e');
    }
  }

  /// Start periodic refresh timer (only when screen is active)
  void _startPeriodicRefresh() {
    _stopPeriodicRefresh(); // Cancel any existing timer

    final connectivityService = Provider.of<ConnectivityService>(
      context,
      listen: false,
    );

    _periodicRefreshTimer = Timer.periodic(_refreshInterval, (timer) {
      // Only refresh if:
      // 1. Screen is still mounted
      // 2. App is in foreground (resumed state)
      // 3. Online
      // 4. Not already refreshing
      if (!mounted) {
        timer.cancel();
        return;
      }

      final lifecycleState = WidgetsBinding.instance.lifecycleState;
      if (lifecycleState != AppLifecycleState.resumed) {
        Logger.info(
          'Admin Dashboard: Skipping periodic refresh - app not in foreground',
        );
        return;
      }

      if (!connectivityService.isFullyOnline) {
        Logger.info('Admin Dashboard: Skipping periodic refresh - offline');
        return;
      }

      if (_isRefreshing) {
        Logger.info(
          'Admin Dashboard: Skipping periodic refresh - already refreshing',
        );
        return;
      }

      Logger.info(
        'Admin Dashboard: Periodic refresh triggered (checking cache expiration)',
      );
      // Use cache-aware refresh - only refresh if cache is expired (respects API call limits)
      _refreshDashboardDataIfNeeded(forceRefresh: false);
    });

    Logger.info(
      'Admin Dashboard: Periodic refresh started (every ${_refreshInterval.inMinutes} minute(s), cache-aware)',
    );
  }

  /// Stop periodic refresh timer
  void _stopPeriodicRefresh() {
    _periodicRefreshTimer?.cancel();
    _periodicRefreshTimer = null;
    Logger.info('Admin Dashboard: Periodic refresh stopped');
  }

  /// Refresh dashboard data if needed (with debouncing and cache awareness)
  Future<void> _refreshDashboardDataIfNeeded({
    bool forceRefresh = false,
  }) async {
    // Use a fresh navigator context for any Provider lookups to avoid
    // using the widget `context` across async gaps.
    final freshCtx = GlobalNavigator.navigatorKey.currentContext;
    final providerCtx = freshCtx ?? context;
    // For force refresh (FCM or manual), skip debouncing and cache check
    if (!forceRefresh) {
      // Debounce: Don't refresh if we just refreshed recently
      if (_lastRefreshTime != null) {
        final timeSinceLastRefresh = DateTime.now().difference(
          _lastRefreshTime!,
        );
        if (timeSinceLastRefresh < _minRefreshGap) {
          Logger.info(
            'Admin Dashboard: Skipping refresh - too soon since last refresh (${timeSinceLastRefresh.inSeconds}s)',
          );
          return;
        }
      }

      // Cache-aware: Check if cache is still valid before making API call
      // This respects API call limits by only refreshing when cache expires
      try {
        final freshCtx = GlobalNavigator.navigatorKey.currentContext;
        final providerCtx = freshCtx ?? context;
        // `providerCtx` is captured synchronously from `GlobalNavigator.navigatorKey` above,
        // so using it for Provider lookups here is safe across async gaps.
        // ignore: use_build_context_synchronously
        final authProvider = Provider.of<AuthProvider>(
          providerCtx,
          listen: false,
        );
        final userId = authProvider.user?['_id'];
        if (userId != null) {
          final cached = await _dashboardRepository.getCachedAdminDashboard(
            userId,
          );
          if (cached != null) {
            // Cache exists and is valid (repository checks TTL internally)
            Logger.info(
              'Admin Dashboard: Cache is valid, skipping API call to conserve API quota',
            );
            return;
          }
        }
      } catch (e) {
        Logger.warning(
          'Admin Dashboard: Error checking cache, proceeding with refresh: $e',
        );
        // If cache check fails, proceed with refresh to ensure data is available
      }
    }

    // Prevent concurrent refreshes - _loadDashboardData now manages _isRefreshing internally
    if (_isRefreshing) {
      Logger.info('Admin Dashboard: Refresh already in progress, skipping');
      return;
    }

    // Only refresh if online
    // `providerCtx` is captured from GlobalNavigator.navigatorKey at function start,
    // so this Provider lookup is safe across async gaps.
    // ignore: use_build_context_synchronously
    final connectivityService = Provider.of<ConnectivityService>(
      providerCtx,
      listen: false,
    );
    if (!connectivityService.isFullyOnline) {
      Logger.info('Admin Dashboard: Skipping refresh - offline');
      return;
    }

    _lastRefreshTime = DateTime.now();

    // Use forceRefresh parameter to bypass cache when needed (FCM/manual)
    // For periodic refresh, forceRefresh=false respects cache TTL
    // _loadDashboardData manages _isRefreshing flag internally
    await _loadDashboardData(forceRefresh: forceRefresh);
  }

  /// Manual refresh (for pull-to-refresh)
  Future<void> _handleManualRefresh() async {
    Logger.info('Admin Dashboard: Manual refresh triggered');
    await _loadDashboardData(forceRefresh: true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Listen for user changes and refresh dashboard data
    final authProvider = Provider.of<AuthProvider>(context);
    if (authProvider.user != null) {
      // If the user has changed, re-fetch dashboard data
      _loadDashboardData(forceRefresh: true);

      // Also force refresh features to ensure UI is up to date
      if (authProvider.featureProvider != null) {
        Logger.info(
          'Dashboard: Force refreshing features on dependency change',
        );
        authProvider.featureProvider!
            .forceRefreshFeatures()
            .then((_) {
              if (mounted) {
                Logger.info('Dashboard: Features force refreshed successfully');
              }
            })
            .catchError((e) {
              if (mounted) {
                Logger.error('Dashboard: Failed to force refresh features: $e');
              }
            });
      }
    }
  }

  Future<void> _loadDashboardData({bool forceRefresh = false}) async {
    // Prevent concurrent loads - always respect _isRefreshing flag
    // forceRefresh only bypasses cache, not concurrency protection
    if (_isRefreshing) {
      Logger.info(
        'Admin Dashboard: Load already in progress, skipping (forceRefresh=$forceRefresh)',
      );
      return;
    }

    // Set refreshing flag before starting
    _isRefreshing = true;

    // Prefer a navigator-backed context for provider reads to avoid using
    // the State `context` across async gaps in this long-running function.
    final freshCtx = GlobalNavigator.navigatorKey.currentContext;
    final providerCtx = freshCtx ?? context;
    // `providerCtx` is captured synchronously from the global navigator above,
    // so Provider lookups using it are safe even in long-running async methods.
    // ignore: use_build_context_synchronously
    final authProvider = Provider.of<AuthProvider>(providerCtx, listen: false);

    // Wait for auth to be ready
    int authRetries = 0;
    while ((authProvider.token == null || authProvider.user == null) &&
        authRetries < 10) {
      await Future.delayed(const Duration(milliseconds: 100));
      authRetries++;
    }

    final userId = authProvider.user?['_id'];
    if (userId == null) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'User not authenticated';
        });
      }
      _isRefreshing = false; // Clear flag before returning
      return;
    }

    // 1. Load from cache immediately
    if (!forceRefresh) {
      final cached = await _dashboardRepository.getCachedAdminDashboard(userId);
      if (cached != null) {
        setState(() {
          _dashboardData = cached;
          _isLoading = false;
          _errorMessage = null;
        });
        Logger.info('Admin dashboard: Loaded cached data');
      } else {
        setState(() {
          _isLoading = true;
        });
      }
    } else {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      // 2. Fetch main dashboard data from server
      final overviewData = await _dashboardRepository.getAdminDashboardOverview(
        userId,
        forceRefresh: forceRefresh,
      );

      if (overviewData != null && mounted) {
        setState(() {
          _dashboardData = overviewData;
        });
      }

      // 3. Fetch user's attendance status (uses AttendanceProvider which has cache-first)
      // Only fetch if forceRefresh is true or if we don't have cached data
      // This avoids unnecessary API calls during periodic refresh
      if (mounted && (forceRefresh || _dashboardData.isEmpty)) {
        // `providerCtx` captured earlier from GlobalNavigator.navigatorKey.currentContext.
        // ignore: use_build_context_synchronously
        final attendanceProvider = Provider.of<AttendanceProvider>(
          providerCtx,
          listen: false,
        );
        try {
          await attendanceProvider.fetchTodayStatus(
            userId,
            forceRefresh: forceRefresh,
          );
          Logger.info('Admin dashboard: Attendance status loaded');
        } catch (e) {
          Logger.warning(
            'Admin dashboard: Failed to load attendance status: $e',
          );
        }
      }

      // 4. Fetch upcoming events if feature is enabled (only on force refresh or initial load)
      if (mounted &&
          (forceRefresh || _dashboardData['upcomingEvents'] == null)) {
        // `providerCtx` captured earlier from GlobalNavigator.navigatorKey.currentContext.
        // ignore: use_build_context_synchronously
        final featureProvider = Provider.of<FeatureProvider>(
          providerCtx,
          listen: false,
        );
        if (featureProvider.hasEvents) {
          try {
            final events = await _dashboardRepository.getUpcomingEvents(
              limit: 5,
              forceRefresh: forceRefresh,
            );
            if (mounted) {
              setState(() {
                _dashboardData['upcomingEvents'] = events;
              });
            }
          } catch (e) {
            Logger.warning('Admin dashboard: Failed to load events: $e');
            if (mounted) {
              setState(() {
                _dashboardData['upcomingEvents'] = [];
              });
            }
          }
        }
      }

      // 5. Fetch recent activities (only on force refresh or initial load)
      if (mounted &&
          (forceRefresh || _dashboardData['recentActivities'] == null)) {
        try {
          final activities = await _dashboardRepository.getRecentActivities(
            limit: 10,
            forceRefresh: forceRefresh,
          );
          if (mounted) {
            setState(() {
              _dashboardData['recentActivities'] = activities;
            });
          }
        } catch (e) {
          Logger.warning('Admin dashboard: Failed to load activities: $e');
          if (mounted) {
            setState(() {
              _dashboardData['recentActivities'] = [];
            });
          }
        }
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = null;
        });
        Logger.info('Admin dashboard: Data loaded successfully');
      }
    } catch (e) {
      Logger.warning('Admin dashboard: Error loading dashboard data: $e');
      // If the widget has been disposed while async work completed, bail out
      if (!mounted) {
        _isRefreshing = false;
        return;
      }

      // If we have cached data, don't show error - just keep showing cached data
      if (_dashboardData.isNotEmpty) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = null; // Suppress error when we have cached data
          });
        }
        _isRefreshing = false; // Clear flag before returning
        return;
      }

      // Check if this is a connection error
      final connectivityService = Provider.of<ConnectivityService>(
        context,
        listen: false,
      );
      final isConnectionError =
          e is SocketException ||
          e.toString().toLowerCase().contains('connection refused') ||
          e.toString().toLowerCase().contains('connection reset') ||
          e.toString().toLowerCase().contains('failed to fetch') ||
          e.toString().toLowerCase().contains('network is unreachable') ||
          (e is api_exceptions.TimeoutException);

      // If it's a connection error and server is known to be unreachable, suppress the error
      if (isConnectionError && !connectivityService.isServerReachable) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage =
                null; // Suppress error when server is known to be down
          });
        }
        _isRefreshing = false; // Clear flag before returning
        return;
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = forceRefresh
              ? 'Failed to refresh dashboard data. Please try again.'
              : null;
        });
      }
    } finally {
      // Always clear refreshing flag when done
      _isRefreshing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;
    if (user == null || user['role'] != 'admin') {
      // Redirect to employee dashboard or another appropriate screen
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacementNamed('/employee_dashboard');
      });
      return const SizedBox.shrink();
    }
    final userName = user['name'] ?? 'Admin';
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final now = DateTime.now();

    // Ensure features are loaded when dashboard is rendered
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (authProvider.featureProvider != null) {
        final featureProvider = authProvider.featureProvider!;

        if (!featureProvider.isSubscriptionPlanLoaded) {
          if (!featureProvider.isLoading) {
            featureProvider.forceRefreshFeatures();
          }
        }
      }
    });

    return Scaffold(
      appBar: SharedAppBar(
        title: 'Dashboard',
        leading: Builder(
          builder: (context) => IconButton(
            key: adminMenuKey,
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        actions: [
          // Dev: Seed tokens & test refresh (debug-only) - placed to the left of the existing debug button
          if (kDebugMode)
            IconButton(
              icon: const Icon(Icons.developer_mode),
              onPressed: () async {
                // Capture fresh navigator context synchronously to use for
                // dialogs and error toasts later without crossing async gaps.
                final freshContext =
                    GlobalNavigator.navigatorKey.currentContext;
                // Prefer navigator key context; fall back to local `context` only
                // when immediately available. This is captured synchronously.
                // ignore: use_build_context_synchronously
                final dialogContext = freshContext ?? context;
                try {
                  final currentAuth = await SecureStorageService.getAuthToken();
                  final currentRefresh =
                      await SecureStorageService.getRefreshToken();

                  final authController = TextEditingController(
                    text: currentAuth ?? '',
                  );
                  final refreshController = TextEditingController(
                    text: currentRefresh ?? '',
                  );

                  // `dialogContext` was captured synchronously from
                  // `GlobalNavigator.navigatorKey.currentContext` above, so
                  // passing it to `showDialog` is safe across async gaps.
                  // ignore: use_build_context_synchronously
                  await showDialog<void>(
                    context: dialogContext,
                    builder: (dialogCtx) => AlertDialog(
                      title: const Text('Dev: Tokens'),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextField(
                            controller: authController,
                            decoration: const InputDecoration(
                              labelText: 'Auth Token',
                            ),
                            maxLines: 2,
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: refreshController,
                            decoration: const InputDecoration(
                              labelText: 'Refresh Token',
                            ),
                            maxLines: 2,
                          ),
                        ],
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(dialogCtx).pop(),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () async {
                            // Capture the dialog navigator synchronously so we don't
                            // use the builder `dialogCtx` across async gaps.
                            final dialogNavigator = Navigator.of(dialogCtx);
                            // Persist any provided tokens (useful for manual testing)
                            final a = authController.text.trim();
                            final r = refreshController.text.trim();
                            if (a.isNotEmpty)
                              await SecureStorageService.storeAuthToken(a);
                            if (r.isNotEmpty)
                              await SecureStorageService.storeRefreshToken(r);
                            dialogNavigator.pop();
                          },
                          child: const Text('Save'),
                        ),
                        TextButton(
                          onPressed: () async {
                            Navigator.of(dialogCtx).pop();
                            final resp = await _apiService.get(
                              '/analytics/admin/overview',
                            );
                            if (!mounted) return;
                            final freshContext2 =
                                GlobalNavigator.navigatorKey.currentContext;
                            if (freshContext2 != null) {
                              // freshContext2 was captured synchronously from the global
                              // navigator key immediately after the dialog closed, so
                              // using it here is safe across the async gap.
                              // ignore: use_build_context_synchronously
                              ScaffoldMessenger.of(freshContext2).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'DBG: ${resp.success} ${resp.message}',
                                  ),
                                ),
                              );
                            } else {
                              GlobalNotificationService().showInfo(
                                'DBG: ${resp.success} ${resp.message}',
                              );
                            }
                          },
                          child: const Text('Call API'),
                        ),
                      ],
                    ),
                  );
                } catch (e) {
                  if (!mounted) return;
                  if (freshContext != null) {
                    // freshContext was captured synchronously at the start of the handler.
                    // ignore: use_build_context_synchronously
                    ScaffoldMessenger.of(
                      freshContext,
                    ).showSnackBar(SnackBar(content: Text('DBG error: $e')));
                  } else {
                    GlobalNotificationService().showError('DBG error: $e');
                  }
                }
              },
              tooltip: 'Dev: View / paste tokens & test',
            ),
          // Debug: Clear company ID button (only in debug mode)
          if (kDebugMode)
            IconButton(
              icon: const Icon(Icons.bug_report),
              onPressed: () async {
                // Capture fresh navigator context before awaits to avoid
                // using State `context` across async gaps in this handler.
                final freshContext =
                    GlobalNavigator.navigatorKey.currentContext;
                try {
                  await SecureStorageService.clearCompanyId();
                  if (!mounted) return;
                  if (freshContext != null) {
                    // freshContext captured synchronously at the start of the handler.
                    // It's safe to use it here to show a SnackBar.
                    // ignore: use_build_context_synchronously
                    ScaffoldMessenger.of(freshContext).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Company ID cleared. Please logout and login again.',
                        ),
                        backgroundColor: AppTheme.warning,
                        duration: Duration(seconds: 3),
                      ),
                    );
                  } else {
                    GlobalNotificationService().showSuccess(
                      'Company ID cleared. Please logout and login again.',
                    );
                  }
                } catch (e) {
                  if (!mounted) return;
                  if (freshContext != null) {
                    // freshContext captured synchronously at the start of the handler.
                    // It's safe to use it here to show a SnackBar.
                    // ignore: use_build_context_synchronously
                    ScaffoldMessenger.of(freshContext).showSnackBar(
                      SnackBar(
                        content: Text('Failed to clear company ID: $e'),
                        backgroundColor: AppTheme.error,
                      ),
                    );
                  } else {
                    GlobalNotificationService().showError(
                      'Failed to clear company ID: $e',
                    );
                  }
                }
              },
              tooltip: 'Clear Company ID (Debug)',
            ),
        ],
      ),
      drawer: const AdminSideNavigation(currentRoute: '/admin_dashboard'),
      body: Consumer<FeatureProvider>(
        builder: (context, featureProvider, child) {
          return LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth >= 1200) {
                // Desktop: Centered, constrained width
                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1100),
                    child: _buildMainContent(
                      theme,
                      colorScheme,
                      userName,
                      now,
                      featureProvider,
                    ),
                  ),
                );
              } else {
                // Mobile/tablet: Full width
                return _buildMainContent(
                  theme,
                  colorScheme,
                  userName,
                  now,
                  featureProvider,
                );
              }
            },
          );
        },
      ),
    );
  }

  /// Build timezone setup notification banner for admin
  Widget _buildTimezoneSetupNotificationBanner(
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
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

    // Use safe header background color from ThemeUtils
    final headerBgColor = ThemeUtils.getSafeHeaderBackgroundColor(theme);
    final headerColor = ThemeUtils.getSafeHeaderColor(theme);
    final textColor = ThemeUtils.getAutoTextColor(headerColor);
    final iconColor = ThemeUtils.getSafeIconColor(headerColor, theme);

    return Container(
      margin: const EdgeInsets.only(
        bottom: AppTheme.spacingL,
        top: AppTheme.spacingM,
      ),
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
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Configure your timezone to see accurate times in reports and attendance records.',
                  style: theme.textTheme.bodyMedium?.copyWith(
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

  bool _onboardingGuideShown =
      false; // Track if guide has been shown in this session

  /// Check if user needs onboarding guide
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

    final freshContext = GlobalNavigator.navigatorKey.currentContext;
    if (freshContext == null) {
      // Can't show onboarding guide without a navigator context
      return;
    }

    // Check if there's already a dialog open
    final navigator = Navigator.of(freshContext);
    if (navigator.canPop()) {
      // There's already a route/dialog, don't show another
      return;
    }

    _onboardingGuideShown = true; // Mark as shown before displaying

    // Capture onboarding completion state synchronously from the fresh
    // navigator context so we don't need to access providers after the
    // dialog Future completes (avoids crossing BuildContext async gaps).
    final authProviderForOnboarding = Provider.of<AuthProvider>(
      freshContext,
      listen: false,
    );
    final bool hasCompletedOnboardingAtShow =
        authProviderForOnboarding.hasCompletedOnboarding;

    showDialog(
      context: freshContext,
      barrierDismissible: false, // Prevent dismissing by tapping outside
      builder: (BuildContext context) {
        return const SetupGuideScreen();
      },
    ).then((_) {
      // Reset flag when dialog is closed (in case user needs to see it again)
      // Re-acquire a fresh context for provider access to avoid using the
      // original `context` across the async gap of the dialog.
      final freshContext = GlobalNavigator.navigatorKey.currentContext;
      if (freshContext == null) {
        // If no context, schedule the reset defensively after a delay
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            _onboardingGuideShown = false;
          }
        });
        return;
      }

      // Use the captured completion state taken before showing the dialog.
      if (hasCompletedOnboardingAtShow) {
        // Onboarding was already completed at time of showing; keep flag
        return;
      }

      // If dialog was closed without completing, reset flag after a delay
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          _onboardingGuideShown = false;
        }
      });
    });
  }

  Widget _buildMainContent(
    ThemeData theme,
    ColorScheme colorScheme,
    String userName,
    DateTime now,
    FeatureProvider featureProvider,
  ) {
    return RefreshIndicator(
      onRefresh: _handleManualRefresh,
      child: SingleChildScrollView(
        physics:
            const AlwaysScrollableScrollPhysics(), // Required for RefreshIndicator
        padding: EdgeInsets.all(AppTheme.spacingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_isLoading) ...[
              const Center(child: CircularProgressIndicator()),
            ] else if (_errorMessage != null) ...[
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: theme.colorScheme.error,
                        size: 48,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Error: $_errorMessage',
                        style: TextStyle(
                          color: theme.colorScheme.error,
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () {
                          _loadDashboardData(forceRefresh: true);
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: theme.colorScheme.onPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              // --- Modern Analytics Section ---
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome, $userName!',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),

                  // Timezone Setup Notification Banner
                  _buildTimezoneSetupNotificationBanner(theme, colorScheme),
                  SizedBox(height: AppTheme.spacingS),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          TimeUtils.formatReadableDate(
                            now,
                            user: Provider.of<AuthProvider>(
                              context,
                              listen: false,
                            ).user,
                            company: Provider.of<CompanyProvider>(
                              context,
                              listen: false,
                            ).currentCompany?.toJson(),
                          ),
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                      Consumer<AttendanceProvider>(
                        builder: (context, attendanceProvider, _) {
                          final holiday = attendanceProvider.holidayInfo;
                          if (holiday == null) return const SizedBox.shrink();
                          final holidayName = holiday['name'] ?? 'Holiday';
                          final holidayType = holiday['type'] ?? 'company';
                          final holidayLabel = holidayType == 'public'
                              ? 'Public Holiday'
                              : 'Company Holiday';
                          return Container(
                            margin: const EdgeInsets.only(left: 12),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: Colors.orange.withValues(alpha: 0.16),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.celebration,
                                  size: 16,
                                  color: Colors.orange[700],
                                ),
                                const SizedBox(width: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      holidayLabel,
                                      style: TextStyle(
                                        color: Colors.orange[800],
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12,
                                      ),
                                    ),
                                    Text(
                                      holidayName,
                                      style: TextStyle(
                                        color: Colors.orange[700],
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  SizedBox(height: AppTheme.spacingL),
                  // Modern Stat Card Row
                  _buildStatCardRow(),
                  SizedBox(height: AppTheme.spacingL),
                  // Leave Status Banner
                  Builder(
                    builder: (context) {
                      final attendanceProvider =
                          Provider.of<AttendanceProvider>(
                            context,
                            listen: false,
                          );
                      final isOnLeave = attendanceProvider.leaveInfo != null;

                      if (isOnLeave) {
                        final leaveInfo = attendanceProvider.leaveInfo!;
                        final leaveType = leaveInfo['leaveType'] ?? 'Leave';
                        final endDate = leaveInfo['endDate'] != null
                            ? DateTime.parse(leaveInfo['endDate']).toLocal()
                            : null;
                        final endDateStr = endDate != null
                            ? TimeUtils.formatReadableDate(
                                endDate,
                                user: Provider.of<AuthProvider>(
                                  context,
                                  listen: false,
                                ).user,
                                company: Provider.of<CompanyProvider>(
                                  context,
                                  listen: false,
                                ).currentCompany?.toJson(),
                              )
                            : 'Unknown';

                        // Use safe status chip color for leave warning
                        final warningColor = ThemeUtils.getStatusChipColor(
                          'warning',
                          theme,
                        );
                        ThemeUtils.getAutoTextColor(warningColor);

                        return Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: warningColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: warningColor.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.beach_access,
                                color: warningColor,
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'On $leaveType Leave',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: warningColor,
                                      ),
                                    ),
                                    Text(
                                      'Until $endDateStr - Some features are restricted during leave',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: warningColor.withValues(
                                          alpha: 0.8,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      return const SizedBox.shrink();
                    },
                  ),

                  // Quick Actions & Shortcuts
                  Text(
                    'Quick Actions & Shortcuts',
                    style: theme.textTheme.titleLarge,
                  ),
                  SizedBox(height: AppTheme.spacingL),
                  KeyedSubtree(
                    key: employeeQuickActionKey,
                    child: _buildPaginatedQuickActions(
                      context,
                      featureProvider,
                    ),
                  ),
                  SizedBox(height: AppTheme.spacingL),
                  // Attendance Pie Chart
                  Card(
                    key: todaysAttendanceCardKey,
                    elevation: AppTheme.elevationMedium,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppTheme.radiusMedium,
                      ),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(AppTheme.spacingL),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Title row
                          Text(
                            'Today\'s Attendance',
                            style: theme.textTheme.titleLarge,
                          ),
                          SizedBox(height: AppTheme.spacingS),
                          // Legend row - aligned to the right, above the pie chart
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [_buildAttendanceLegend()],
                          ),
                          SizedBox(height: AppTheme.spacingL),
                          SizedBox(
                            height: 200,
                            child: _buildAttendancePieChart(),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: AppTheme.spacingL),
                  // Department Stats Table
                  Card(
                    elevation: AppTheme.elevationMedium,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppTheme.radiusMedium,
                      ),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(AppTheme.spacingL),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Department-wise Attendance',
                            style: theme.textTheme.titleLarge,
                          ),
                          SizedBox(height: AppTheme.spacingL),
                          _buildDepartmentStatsTable(),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: AppTheme.spacingL),
                  // Company Notifications for Admins
                  const CompanyNotificationsWidget(),
                ],
              ),
              SizedBox(height: AppTheme.spacingL),
            ],
            Text(
              'Real-Time Data & Analytics',
              style: theme.textTheme.titleLarge,
            ),
            SizedBox(height: AppTheme.spacingL),
            Card(
              elevation: AppTheme.elevationHigh,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              ),
              child: Padding(
                padding: EdgeInsets.all(AppTheme.spacingL),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Charts & Graphs', style: theme.textTheme.titleMedium),
                    SizedBox(height: AppTheme.spacingL),
                    // Only show chart if real data is available
                    if (_dashboardData['chartData'] != null &&
                        (_dashboardData['chartData']['attendance'] as List)
                            .isNotEmpty)
                      _buildChartsSection(theme),
                    SizedBox(height: AppTheme.spacingL),
                    Text('Live Metrics', style: theme.textTheme.titleMedium),
                    SizedBox(height: AppTheme.spacingL),
                    // Only show metrics if real data is available
                    if (_dashboardData['quickStats'] != null)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildSummaryItem(
                            context,
                            icon: Icons.people,
                            label: 'Employees',
                            value:
                                _dashboardData['quickStats']['totalEmployees']
                                    .toString(),
                          ),
                          _buildSummaryItem(
                            context,
                            icon: Icons.payments,
                            label: 'Payslips',
                            value: (_dashboardData['payslipCount'] ?? '-')
                                .toString(),
                          ),
                          _buildSummaryItem(
                            context,
                            icon: Icons.notifications,
                            label: 'Notifications',
                            value: (_dashboardData['notificationCount'] ?? '-')
                                .toString(),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),

            SizedBox(height: AppTheme.spacingL),
            // Placeholder sections removed (Help & Support, Security & Compliance, Integration)
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    final theme = Theme.of(context);
    // Use safe surface color for icons, not tenant primaryColor
    final iconColor =
        theme.colorScheme.primary; // Keep primary for icons in summary
    return Column(
      children: [
        Icon(icon, size: 40, color: iconColor),
        SizedBox(height: AppTheme.spacingS),
        Text(label, style: theme.textTheme.bodyMedium),
        Text(value, style: theme.textTheme.titleLarge),
      ],
    );
  }

  Widget _buildActionCard(
    BuildContext context, {
    Key? cardKey,
    required IconData icon,
    required String title,
    required Future<void> Function() onTap,
  }) {
    final theme = Theme.of(context);
    // Action cards can use tenant primaryColor (safe for buttons/actions)
    final primaryColor = theme.colorScheme.primary;
    final textColor = ThemeUtils.getAutoTextColor(primaryColor);

    return GestureDetector(
      onTap: () async {
        if (_navCardTapped) return;
        setState(() {
          _navCardTapped = true;
        });
        try {
          await Future.delayed(
            const Duration(milliseconds: 100),
          ); // Optional debounce
          await onTap();
        } finally {
          if (mounted) {
            setState(() {
              _navCardTapped = false;
            });
          }
        }
      },
      child: AbsorbPointer(
        absorbing: _navCardTapped,
        child: Card(
          key: cardKey,
          elevation: AppTheme.elevationHigh,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          ),
          child: Container(
            constraints: BoxConstraints(minHeight: 92),
            padding: EdgeInsets.symmetric(
              vertical: AppTheme.spacingM,
              horizontal: AppTheme.spacingS,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [primaryColor.withValues(alpha: 0.75), primaryColor],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 10,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 34, color: textColor),
                SizedBox(height: AppTheme.spacingS),
                Flexible(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: textColor,
                      fontSize: 13,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    Color color, {
    String? subtitle,
  }) {
    final theme = Theme.of(context);
    // Use safe text color based on card background
    final textColor = ThemeUtils.getAutoTextColor(color);
    final iconColor = ThemeUtils.getSafeIconColor(color, theme);

    return Card(
      elevation: AppTheme.elevationHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      ),
      child: Container(
        padding: EdgeInsets.all(AppTheme.spacingM), // Reduced from 16
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withValues(alpha: 0.7), color],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center, // Center vertically
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: iconColor, size: 24),
                SizedBox(width: AppTheme.spacingS),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 14, // Reduced from 16
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            SizedBox(height: AppTheme.spacingS), // Reduced from 12
            Text(
              value,
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.bold,
                fontSize: 20, // Reduced from 24
              ),
            ),
            if (subtitle != null) ...[
              SizedBox(height: AppTheme.spacingXs),
              Text(
                subtitle,
                style: TextStyle(
                  color: textColor.withValues(alpha: 0.9),
                  fontWeight: FontWeight.normal,
                  fontSize: 11,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }

  // --- Modern Dashboard Widgets ---
  bool _statCardTapped = false;
  Widget _buildStatCardRow() {
    final theme = Theme.of(context);
    // Use safe colors for stat cards - don't use tenant primaryColor for cards
    // Only use semantic colors (success, error, warning) or neutral colors
    final stats = [
      {
        'title': 'Total Users',
        'value':
            _dashboardData['quickStats']?['totalUsers']?.toString() ??
            _dashboardData['totalUsers']?.toString() ??
            '0',
        'icon': Icons.people,
        'color': theme
            .colorScheme
            .primary, // Keep primary for "Total Users" as it's informational
        'onTap': () => _showEmployeeListModal('All'), // Make clickable
        'key': topTotalEmployeesKey,
      },
      {
        'title': 'Present',
        'value':
            _dashboardData['quickStats']?['presentToday']?.toString() ??
            _dashboardData['present']?.toString() ??
            '0',
        'icon': Icons.check_circle,
        'color': AppTheme.success,
        'onTap': () => _showEmployeeListModal('Present'),
        'key': topPresentKey,
      },
      {
        'title': 'On Leave',
        'value':
            _dashboardData['quickStats']?['onLeave']?.toString() ??
            _dashboardData['onLeave']?.toString() ??
            '0',
        'icon': Icons.event_busy,
        'color': Theme.of(context).colorScheme.secondary,
        'onTap': () => _showEmployeeListModal('On Leave'),
        'key': topOnLeaveKey,
      },
      {
        'title': 'Absent',
        'value':
            _dashboardData['quickStats']?['absentToday']?.toString() ??
            _dashboardData['absent']?.toString() ??
            '0',
        'icon': Icons.cancel,
        'color': AppTheme.error,
        'onTap': () => _showEmployeeListModal('Absent'),
        'key': topAbsentKey,
      },
      {
        'title': 'Pending',
        'value':
            _dashboardData['quickStats']?['pending']?.toString() ??
            _dashboardData['pending']?.toString() ??
            _dashboardData['quickStats']?['pendingRequests']?.toString() ??
            '0',
        'icon': Icons.pending_actions,
        'color': AppTheme.warning,
        'onTap': () => _showEmployeeListModal('Pending'),
        'key': topPendingKey,
      },
    ];
    return SizedBox(
      height: 110,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const ClampingScrollPhysics(),
        child: Row(
          children: stats
              .map(
                (stat) => Container(
                  width: 160,
                  margin: EdgeInsets.only(right: AppTheme.spacingM),
                  child: (stat['onTap'] != null)
                      ? GestureDetector(
                          onTap: () async {
                            if (_statCardTapped) return;
                            setState(() {
                              _statCardTapped = true;
                            });
                            try {
                              await Future.delayed(
                                const Duration(milliseconds: 100),
                              ); // Optional: debounce
                              await (stat['onTap']
                                  as FutureOr<void> Function())();
                            } finally {
                              if (mounted) {
                                setState(() {
                                  _statCardTapped = false;
                                });
                              }
                            }
                          },
                          child: AbsorbPointer(
                            absorbing: _statCardTapped,
                            child: _buildStatCard(
                              context,
                              stat['title'] as String,
                              stat['value'] as String,
                              stat['icon'] as IconData,
                              stat['color'] as Color,
                            ),
                          ),
                        )
                      : _buildStatCard(
                          context,
                          stat['title'] as String,
                          stat['value'] as String,
                          stat['icon'] as IconData,
                          stat['color'] as Color,
                        ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  void _showEmployeeListModal(String status) async {
    // Refresh dashboard data when modal opens to ensure card and modal show same data
    // This prevents cache inconsistency where card shows cached data but modal shows fresh data
    Logger.info('Admin Dashboard: Modal opened for $status, fetching data');

    // Check connectivity first
    final isOnline = _connectivityService.isFullyOnline;

    // Get current cached card value before attempting to fetch
    // This way we can preserve it if backend is down
    final cachedCardValue = _getCachedCardValue(status);

    // Try to fetch employee list from backend
    List<Map<String, dynamic>> employees = [];
    bool fetchedFromBackend = false;
    bool backendError = false;

    try {
      employees = await _fetchEmployeesByStatus(status);
      fetchedFromBackend = true;
      Logger.info(
        'Admin Dashboard: Successfully fetched ${employees.length} employees from backend',
      );
    } catch (e) {
      Logger.warning(
        'Admin Dashboard: Failed to fetch employees from backend: $e',
      );
      backendError = true;

      // If offline or backend is down, we can't show the employee list
      // But we'll preserve the cached card value (don't update it)
      if (!isOnline ||
          e.toString().contains('connection') ||
          e.toString().contains('timeout')) {
        Logger.info(
          'Admin Dashboard: Offline or backend unavailable - preserving cached card value',
        );
        // Don't update card - keep showing cached value
        // employees remains empty, so modal will show appropriate message
      }
    }

    // Only update card value if we successfully fetched fresh data from backend
    // This ensures:
    // 1. When online: Card updates to match fresh backend data
    // 2. When offline: Card keeps showing cached value (not overwritten)
    if (fetchedFromBackend && (employees.isNotEmpty || status == 'All')) {
      final actualCount = employees.length;
      _updateCardValueForStatus(status, actualCount);
      Logger.info(
        'Admin Dashboard: Updated $status card to $actualCount based on fresh backend data',
      );
    } else if (backendError) {
      // Backend failed - preserve cached card value (don't update it)
      Logger.info(
        'Admin Dashboard: Backend unavailable - preserving cached card value ($cachedCardValue)',
      );
      // Card will continue showing cached value from _dashboardData
    }

    // Show modal with the fetched data
    if (!mounted) return;

    // Refresh dashboard in background if online and fetch succeeded (but don't wait for it)
    // The card is already updated above, so this refresh won't cause inconsistency
    // CRITICAL: Check mounted before calling refresh to prevent accessing disposed widget
    if (isOnline && fetchedFromBackend && mounted) {
      _refreshDashboardDataIfNeeded(forceRefresh: true).catchError((e) {
        Logger.warning('Admin Dashboard: Failed to refresh dashboard: $e');
        // Continue even if refresh fails - card is already updated
      });
    }

    final freshContext = GlobalNavigator.navigatorKey.currentContext;
    if (freshContext == null || !mounted) {
      // UI context unavailable; surface info via global notification instead
      if (backendError) {
        GlobalNotificationService().showError(
          'Unable to open list: backend unavailable. Card shows cached count: $cachedCardValue',
        );
      } else {
        GlobalNotificationService().showInfo(
          'Unable to open list: UI context unavailable',
        );
      }
      return;
    }

    // `freshContext` was captured synchronously from
    // `GlobalNavigator.navigatorKey.currentContext` above and verified
    // non-null, so using it for `showDialog` here is safe.
    // ignore: use_build_context_synchronously
    showDialog(
      context: freshContext,
      builder: (context) {
        // If backend failed, show appropriate message
        if (backendError && employees.isEmpty) {
          return AlertDialog(
            title: Text(status),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  !isOnline ? Icons.wifi_off : Icons.error_outline,
                  size: 48,
                  color: Theme.of(context).colorScheme.error,
                ),
                SizedBox(height: 16),
                Text(
                  !isOnline
                      ? 'Unable to fetch data. Please check your connection.\n\nCard shows cached count: $cachedCardValue'
                      : 'Unable to fetch data from server.\n\nCard shows cached count: $cachedCardValue',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          );
        }

        final admins = employees.where((e) => e['role'] == 'admin').toList();
        final otherEmployees = employees
            .where((e) => e['role'] == 'employee')
            .toList();

        if (employees.isEmpty) {
          return AlertDialog(content: Text('No employees found.'));
        }

        return _EmployeeModalContent(
          employeesList: otherEmployees,
          adminsList: admins,
          totalCount: employees.length,
        );
      },
    ).then((_) {
      // Refresh again when modal closes to ensure card is fully updated (if online)
      // CRITICAL: Check mounted before calling refresh to prevent accessing disposed widget
      if (isOnline && mounted) {
        Logger.info(
          'Admin Dashboard: Modal closed, ensuring dashboard is up to date',
        );
        _refreshDashboardDataIfNeeded(forceRefresh: false).catchError((e) {
          Logger.warning(
            'Admin Dashboard: Failed to refresh after modal closed: $e',
          );
        });
      }
    });
  }

  /// Get current cached card value for a status
  int _getCachedCardValue(String status) {
    switch (status.toLowerCase()) {
      case 'present':
        return _dashboardData['quickStats']?['presentToday'] ??
            _dashboardData['present'] ??
            0;
      case 'absent':
        return _dashboardData['quickStats']?['absentToday'] ??
            _dashboardData['absent'] ??
            0;
      case 'on leave':
        return _dashboardData['quickStats']?['onLeave'] ??
            _dashboardData['onLeave'] ??
            0;
      case 'pending':
        return _dashboardData['quickStats']?['pending'] ??
            _dashboardData['pending'] ??
            0;
      case 'all':
        return _dashboardData['quickStats']?['totalUsers'] ??
            _dashboardData['totalUsers'] ??
            0;
      default:
        return 0;
    }
  }

  /// Update card value for a specific status based on fetched data
  /// This ensures card and modal show the same count
  void _updateCardValueForStatus(String status, int actualCount) {
    if (!mounted) return;

    try {
      setState(() {
        // Update the dashboard data with the actual count from the API
        if (_dashboardData['quickStats'] == null) {
          _dashboardData['quickStats'] = {};
        }

        switch (status.toLowerCase()) {
          case 'present':
            _dashboardData['quickStats']!['presentToday'] = actualCount;
            _dashboardData['present'] = actualCount;
            Logger.info(
              'Admin Dashboard: Updated Present card to $actualCount',
            );
            break;
          case 'absent':
            _dashboardData['quickStats']!['absentToday'] = actualCount;
            _dashboardData['absent'] = actualCount;
            Logger.info('Admin Dashboard: Updated Absent card to $actualCount');
            break;
          case 'on leave':
            _dashboardData['quickStats']!['onLeave'] = actualCount;
            _dashboardData['onLeave'] = actualCount;
            Logger.info(
              'Admin Dashboard: Updated On Leave card to $actualCount',
            );
            break;
          case 'pending':
            _dashboardData['quickStats']!['pending'] = actualCount;
            _dashboardData['pending'] = actualCount;
            Logger.info(
              'Admin Dashboard: Updated Pending card to $actualCount',
            );
            break;
          case 'all':
            _dashboardData['quickStats']!['totalUsers'] = actualCount;
            _dashboardData['totalUsers'] = actualCount;
            Logger.info(
              'Admin Dashboard: Updated Total Users card to $actualCount',
            );
            break;
        }
      });
    } catch (e) {
      Logger.warning('Admin Dashboard: Failed to update card value: $e');
    }
  }

  String _statusToParam(String status) {
    switch (status.toLowerCase()) {
      case 'present':
        return 'present';
      case 'absent':
        return 'absent';
      case 'on leave':
        return 'onleave';
      case 'pending':
        return 'pending';
      default:
        return status.toLowerCase();
    }
  }

  Future<List<Map<String, dynamic>>> _fetchEmployeesByStatus(
    String status,
  ) async {
    try {
      final freshCtx = GlobalNavigator.navigatorKey.currentContext;
      final providerCtx = freshCtx ?? context;
      final authProvider = Provider.of<AuthProvider>(
        providerCtx,
        listen: false,
      );
      final token = authProvider.token;
      if (status == 'All') {
        final response = await http
            .get(
              Uri.parse('${ApiConfig.baseUrl}/analytics/admin/active-users'),
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $token',
              },
            )
            .timeout(
              const Duration(seconds: 60),
              onTimeout: () {
                throw api_exceptions.TimeoutException(
                  'Active users request timed out after 60 seconds',
                );
              },
            );
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['users'] != null && data['users'] is List) {
            return List<Map<String, dynamic>>.from(data['users']);
          }
        }
        return [];
      }
      final statusParam = _statusToParam(status);
      final response = await http
          .get(
            Uri.parse(
              '${ApiConfig.baseUrl}/attendance/today-list?status=$statusParam',
            ),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(
            const Duration(seconds: 60),
            onTimeout: () {
              throw api_exceptions.TimeoutException(
                'Today list request timed out after 60 seconds',
              );
            },
          );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['employees'] != null && data['employees'] is List) {
          return List<Map<String, dynamic>>.from(data['employees']);
        }
      } else {
        dev.log('Failed to fetch employees by status: ${response.body}');
      }
    } catch (e) {
      dev.log('Error fetching employees by status: $e');
    }
    return [];
  }

  Widget _buildAttendancePieChart() {
    final theme = Theme.of(context);
    ThemeUtils.getSafeChartColors(theme);

    final present = (_dashboardData['quickStats']?['presentToday'] ?? 0)
        .toDouble();
    final absent = (_dashboardData['quickStats']?['absentToday'] ?? 0)
        .toDouble();
    final onLeave = (_dashboardData['quickStats']?['onLeave'] ?? 0).toDouble();
    final total = present + absent + onLeave;
    if (total == 0) {
      return const Center(child: Text('No attendance data.'));
    }
    return PieChart(
      PieChartData(
        sections: [
          PieChartSectionData(
            value: present,
            color: ThemeUtils.getStatusChipColor(
              'approved',
              theme,
            ), // Green for Present
            radius: 60,
          ),
          PieChartSectionData(
            value: absent,
            color: ThemeUtils.getStatusChipColor(
              'error',
              theme,
            ), // Red for Absent
            radius: 60,
          ),
          PieChartSectionData(
            value: onLeave,
            color: ThemeUtils.getStatusChipColor(
              'warning',
              theme,
            ), // Orange for On Leave
            radius: 60,
          ),
        ],
        sectionsSpace: 2,
        centerSpaceRadius: 40,
      ),
    );
  }

  Widget _buildAttendanceLegend() {
    final present = (_dashboardData['quickStats']?['presentToday'] ?? 0)
        .toDouble();
    final absent = (_dashboardData['quickStats']?['absentToday'] ?? 0)
        .toDouble();
    final onLeave = (_dashboardData['quickStats']?['onLeave'] ?? 0).toDouble();
    final total = present + absent + onLeave;

    return Builder(
      builder: (context) {
        final theme = Theme.of(context);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _buildLegendItem(
              'Present',
              ThemeUtils.getStatusChipColor('approved', theme),
              present,
              total,
            ),
            SizedBox(height: AppTheme.spacingXs),
            _buildLegendItem(
              'Absent',
              ThemeUtils.getStatusChipColor('error', theme),
              absent,
              total,
            ),
            SizedBox(height: AppTheme.spacingXs),
            _buildLegendItem(
              'On Leave',
              ThemeUtils.getStatusChipColor('warning', theme),
              onLeave,
              total,
            ),
          ],
        );
      },
    );
  }

  Widget _buildLegendItem(
    String label,
    Color color,
    double value,
    double total,
  ) {
    final percentage = total > 0
        ? ((value / total) * 100).toStringAsFixed(1)
        : '0.0';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        SizedBox(width: 6),
        Text(
          '$label ($percentage%)',
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }

  Widget _buildDepartmentStatsTable() {
    final deptStats =
        _dashboardData['departmentStats'] as Map<String, dynamic>?;
    if (deptStats == null || deptStats.isEmpty) {
      return const Text('No department stats available.');
    }
    final columns = ['Department', 'Present', 'Absent', 'On Leave'];

    // Filter out "Unknown" department entries and map them to "Unassigned"
    final rows = deptStats.entries.map((entry) {
      final dept = entry.key;
      final value = entry.value;

      // Normalize department name - replace "Unknown" with "Unassigned"
      String displayDept = dept;
      if (dept.toLowerCase() == 'unknown' ||
          dept.toLowerCase() == 'unknown department') {
        displayDept = 'Unassigned';
      }

      if (value is Map<String, dynamic>) {
        return DataRow(
          cells: [
            DataCell(Text(displayDept)),
            DataCell(Text(value['present']?.toString() ?? '0')),
            DataCell(Text(value['absent']?.toString() ?? '0')),
            DataCell(Text(value['onLeave']?.toString() ?? '0')),
          ],
        );
      } else if (value is int) {
        // If value is just an int, treat as present count
        return DataRow(
          cells: [
            DataCell(Text(displayDept)),
            DataCell(Text(value.toString())),
            const DataCell(Text('0')),
            const DataCell(Text('0')),
          ],
        );
      } else {
        // Unknown type, show zeros
        return DataRow(
          cells: [
            DataCell(Text(displayDept)),
            const DataCell(Text('0')),
            const DataCell(Text('0')),
            const DataCell(Text('0')),
          ],
        );
      }
    }).toList();
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 220),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const ClampingScrollPhysics(),
        child: SingleChildScrollView(
          scrollDirection: Axis.vertical,
          physics: const ClampingScrollPhysics(),
          child: DataTable(
            columns: columns.map((c) => DataColumn(label: Text(c))).toList(),
            rows: rows,
          ),
        ),
      ),
    );
  }

  // Essential Quick Actions - Only what's actually available
  Widget _buildPaginatedQuickActions(
    BuildContext context,
    FeatureProvider featureProvider,
  ) {
    // Check if admin is on leave
    final attendanceProvider = Provider.of<AttendanceProvider>(
      context,
      listen: false,
    );
    final isOnLeave = attendanceProvider.leaveInfo != null;

    // Get all possible actions first
    final allActions = [
      // Core Management
      {
        'icon': Icons.people,
        'title': 'Employees',
        'feature': 'employeeManagement',
        'onTap': () {
          final ctx = GlobalNavigator.navigatorKey.currentContext;
          if (ctx != null) {
            Navigator.push(
              ctx,
              MaterialPageRoute(
                builder: (_) => const EmployeeManagementScreen(),
              ),
            );
          } else {
            GlobalNotificationService().showInfo(
              'Unable to open Employees screen',
            );
          }
        },
      },
      {
        'icon': Icons.beach_access,
        'title': 'Leave',
        'feature': 'leaveManagement',
        'onTap': () {
          final ctx = GlobalNavigator.navigatorKey.currentContext;
          if (ctx != null) {
            Navigator.push(
              ctx,
              MaterialPageRoute(builder: (_) => const LeaveManagementScreen()),
            );
          } else {
            GlobalNotificationService().showInfo('Unable to open Leave screen');
          }
        },
      },
      {
        'icon': Icons.payments,
        'title': 'Payroll',
        'feature': 'payroll',
        'onTap': () {
          final ctx = GlobalNavigator.navigatorKey.currentContext;
          if (ctx != null) {
            Navigator.push(
              ctx,
              MaterialPageRoute(
                builder: (_) => const PayrollManagementScreen(),
              ),
            );
          } else {
            GlobalNotificationService().showInfo(
              'Unable to open Payroll screen',
            );
          }
        },
      },
      {
        'icon': Icons.access_time,
        'title': 'Attendance',
        'feature': 'attendance',
        'onTap': () {
          final ctx = GlobalNavigator.navigatorKey.currentContext;
          if (ctx != null) {
            Navigator.push(
              ctx,
              MaterialPageRoute(
                builder: (_) => const AttendanceManagementScreen(),
              ),
            );
          } else {
            GlobalNotificationService().showInfo(
              'Unable to open Attendance screen',
            );
          }
        },
      },
      // Time & Work Management
      {
        'icon': Icons.schedule,
        'title': 'Timesheet',
        'feature': 'timeTracking',
        'onTap': () {
          final ctx = GlobalNavigator.navigatorKey.currentContext;
          if (ctx != null) {
            Navigator.push(
              ctx,
              MaterialPageRoute(builder: (_) => const AdminTimesheetScreen()),
            );
          } else {
            GlobalNotificationService().showInfo(
              'Unable to open Timesheet screen',
            );
          }
        },
      },
      {
        'icon': Icons.free_breakfast,
        'title': 'Break',
        'feature': 'breakManagement', // Assuming this is always available
        'onTap': () {
          final ctx = GlobalNavigator.navigatorKey.currentContext;
          if (ctx != null) {
            Navigator.push(
              ctx,
              MaterialPageRoute(builder: (_) => const BreakManagementScreen()),
            );
          } else {
            GlobalNotificationService().showInfo('Unable to open Break screen');
          }
        },
      },
      // Analytics & Reporting
      {
        'icon': Icons.analytics,
        'title': 'Analytics',
        'feature': 'analytics',
        'onTap': () {
          final ctx = GlobalNavigator.navigatorKey.currentContext;
          if (ctx != null) {
            Navigator.push(
              ctx,
              MaterialPageRoute(builder: (_) => const AdminAnalyticsScreen()),
            );
          } else {
            GlobalNotificationService().showInfo(
              'Unable to open Analytics screen',
            );
          }
        },
      },
      // Company & Settings
      {
        'icon': Icons.business,
        'title': 'Company',
        'feature': 'companySettings', // Assuming this is always available
        'onTap': () {
          final ctx = GlobalNavigator.navigatorKey.currentContext;
          if (ctx != null) {
            Navigator.push(
              ctx,
              MaterialPageRoute(builder: (_) => const CompanySettingsScreen()),
            );
          } else {
            GlobalNotificationService().showInfo(
              'Unable to open Company settings',
            );
          }
        },
      },
      {
        'icon': Icons.settings,
        'title': 'Settings',
        'feature': 'settings', // Assuming this is always available
        'onTap': () {
          final ctx = GlobalNavigator.navigatorKey.currentContext;
          if (ctx != null) {
            Navigator.push(
              ctx,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            );
          } else {
            GlobalNotificationService().showInfo('Unable to open Settings');
          }
        },
      },
      {
        'icon': Icons.campaign,
        'title': 'Broadcast',
        'feature': 'notifications', // Assuming this is always available
        'onTap': () {
          final ctx = GlobalNavigator.navigatorKey.currentContext;
          if (ctx != null) {
            Navigator.push(
              ctx,
              MaterialPageRoute(
                builder: (_) => const BroadcastNotificationScreen(),
              ),
            );
          } else {
            GlobalNotificationService().showInfo(
              'Unable to open Broadcast screen',
            );
          }
        },
      },
    ];

    // Filter actions based on enabled features and leave restrictions
    final actions = allActions.where((action) {
      final feature = action['feature'] as String;

      // Check if feature is available when on leave
      if (isOnLeave &&
          !AdminLeaveRestrictions.isFeatureAvailableOnLeave(feature)) {
        if (kDebugMode) {}
        return false;
      }

      // Always show core features that don't have specific feature flags
      if ([
        'breakManagement',
        'companySettings',
        'settings',
        'notifications',
      ].contains(feature)) {
        return true;
      }

      // Check if the feature is enabled
      bool isEnabled = false;
      switch (feature) {
        case 'employeeManagement':
          isEnabled = featureProvider.hasEmployeeManagement;
          break;
        case 'leaveManagement':
          isEnabled = featureProvider.hasLeaveManagement;
          break;
        case 'payroll':
          isEnabled = featureProvider.hasPayroll;
          break;
        case 'attendance':
          isEnabled = featureProvider.hasAttendance;
          break;
        case 'timeTracking':
          isEnabled = featureProvider.hasTimeTracking;
          break;
        case 'analytics':
          isEnabled = featureProvider.hasAnalytics;
          break;
        default:
          isEnabled =
              true; // Default to showing if feature check is not implemented
      }

      // Debug logging
      if (kDebugMode) {}

      return isEnabled;
    }).toList();

    // Debug logging for final actions
    if (kDebugMode) {}

    // Render quick actions as a single horizontal row across all platforms.
    // If they don't fit the view, the row becomes horizontally scrollable.
    const cardWidth = 140.0;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: AppTheme.spacingS),
      child: SizedBox(
        height: 140,
        child: Listener(
          onPointerSignal: (pointerSignal) {
            // Support mouse wheel / touchpad scroll on web to scroll horizontally.
            // Avoid referencing `PointerScrollEvent` type directly (platform-specific),
            // instead treat the signal as dynamic and attempt to read `scrollDelta`.
            try {
              final dyn = pointerSignal as dynamic;
              final Offset? delta = dyn.scrollDelta as Offset?;
              if (delta != null) {
                final dx = delta.dy != 0 ? delta.dy : delta.dx;
                if (_quickActionsScrollController.hasClients) {
                  final newOffset = _quickActionsScrollController.offset + dx;
                  final min =
                      _quickActionsScrollController.position.minScrollExtent;
                  final max =
                      _quickActionsScrollController.position.maxScrollExtent;
                  _quickActionsScrollController.jumpTo(
                    newOffset.clamp(min, max),
                  );
                }
              }
            } catch (_) {}
          },
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragUpdate: (details) {
              try {
                if (_quickActionsScrollController.hasClients) {
                  final newOffset =
                      _quickActionsScrollController.offset - details.delta.dx;
                  final min =
                      _quickActionsScrollController.position.minScrollExtent;
                  final max =
                      _quickActionsScrollController.position.maxScrollExtent;
                  _quickActionsScrollController.jumpTo(
                    newOffset.clamp(min, max),
                  );
                }
              } catch (_) {}
            },
            child: SingleChildScrollView(
              controller: _quickActionsScrollController,
              scrollDirection: Axis.horizontal,
              physics: const ClampingScrollPhysics(),
              padding: EdgeInsets.symmetric(horizontal: AppTheme.spacingS),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: actions.map((action) {
                  return Padding(
                    padding: EdgeInsets.only(right: AppTheme.spacingM),
                    child: SizedBox(
                      width: cardWidth,
                      height: 110,
                      child: _buildActionCard(
                        context,
                        cardKey: null,
                        icon: action['icon'] as IconData,
                        title: action['title'] as String,
                        onTap: () async {
                          final callback = action['onTap'] as VoidCallback?;
                          if (callback != null) callback();
                          return;
                        },
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChartsSection(ThemeData theme) {
    if (_isLoading || _dashboardData['chartData'] == null) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          border: Border.all(
            color: AppTheme.muted.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: const Center(
          child: Text('Chart data loading or unavailable...'),
        ),
      );
    }

    // Example: Display a simple text representation of chart data
    return Container(
      height: 200,
      padding: EdgeInsets.all(AppTheme.spacingL),
      decoration: BoxDecoration(
        color: Colors.transparent,
        border: Border.all(color: AppTheme.muted.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Attendance Trend (Example)', style: theme.textTheme.titleSmall),
          SizedBox(height: AppTheme.spacingS),
          Expanded(
            child: Center(
              child: Text(
                _dashboardData['chartData']['attendance']?.join(', ') ??
                    'No chart data',
                style: TextStyle(color: AppTheme.muted),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmployeeModalContent extends StatefulWidget {
  final List<Map<String, dynamic>> employeesList;
  final List<Map<String, dynamic>> adminsList;
  final int totalCount;

  const _EmployeeModalContent({
    required this.employeesList,
    required this.adminsList,
    required this.totalCount,
  });

  @override
  State<_EmployeeModalContent> createState() => _EmployeeModalContentState();
}

class _EmployeeModalContentState extends State<_EmployeeModalContent> {
  bool employeesExpanded = true;
  bool adminsExpanded = true;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        'All (${widget.totalCount})',
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
      ),
      content: SizedBox(
        width: 350,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.employeesList.isNotEmpty) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Employees: All (${widget.employeesList.length})',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: Icon(
                        employeesExpanded
                            ? Icons.expand_less
                            : Icons.expand_more,
                      ),
                      onPressed: () => setState(
                        () => employeesExpanded = !employeesExpanded,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      iconSize: 20,
                    ),
                  ],
                ),
                if (employeesExpanded) ...[
                  SizedBox(height: AppTheme.spacingS),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: widget.employeesList.length,
                    itemBuilder: (context, index) {
                      final e = widget.employeesList[index];
                      return Column(
                        children: [
                          ListTile(
                            leading: const Icon(Icons.person),
                            title: Text(
                              '${e['firstName'] ?? ''} ${e['lastName'] ?? ''}'
                                      .trim()
                                      .isEmpty
                                  ? 'Unknown'
                                  : '${e['firstName'] ?? ''} ${e['lastName'] ?? ''}'
                                        .trim(),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(e['email'] ?? 'No email'),
                                // Show leave duration information if available
                                if (e['leaveInfo'] != null) ...[
                                  const SizedBox(height: 4),
                                  _buildLeaveDurationInfo(e['leaveInfo']),
                                ],
                              ],
                            ),
                          ),
                          const Divider(height: 1),
                        ],
                      );
                    },
                  ),
                ],
              ],
              if (widget.adminsList.isNotEmpty) ...[
                SizedBox(height: AppTheme.spacingL),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Admins: All (${widget.adminsList.length})',
                      style: TextStyle(
                        color: AppTheme.secondary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        adminsExpanded ? Icons.expand_less : Icons.expand_more,
                      ),
                      onPressed: () =>
                          setState(() => adminsExpanded = !adminsExpanded),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      iconSize: 20,
                      color: AppTheme.secondary,
                    ),
                  ],
                ),
                if (adminsExpanded) ...[
                  SizedBox(height: AppTheme.spacingS),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: widget.adminsList.length,
                    itemBuilder: (context, index) {
                      final a = widget.adminsList[index];
                      return Column(
                        children: [
                          ListTile(
                            leading: Icon(
                              Icons.admin_panel_settings,
                              color: AppTheme.secondary,
                            ),
                            title: Text(
                              '${a['firstName'] ?? ''} ${a['lastName'] ?? ''}'
                                      .trim()
                                      .isEmpty
                                  ? 'Unknown'
                                  : '${a['firstName'] ?? ''} ${a['lastName'] ?? ''}'
                                        .trim(),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(a['email'] ?? 'No email'),
                                // Show leave duration information if available
                                if (a['leaveInfo'] != null) ...[
                                  const SizedBox(height: 4),
                                  _buildLeaveDurationInfo(a['leaveInfo']),
                                ],
                              ],
                            ),
                          ),
                          const Divider(height: 1),
                        ],
                      );
                    },
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _buildLeaveDurationInfo(Map<String, dynamic> leaveInfo) {
    final totalDays = leaveInfo['totalDays'] ?? 0;
    final daysRemaining = leaveInfo['daysRemaining'] ?? 0;

    final theme = Theme.of(context);
    final warningColor = ThemeUtils.getStatusChipColor('warning', theme);

    return GestureDetector(
      onTap: () => _showLeaveDetailsDialog(leaveInfo),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: warningColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: warningColor.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.beach_access, size: 14, color: warningColor),
            const SizedBox(width: 4),
            Text(
              '$totalDays days',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: warningColor,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '($daysRemaining remaining)',
              style: TextStyle(
                fontSize: 10,
                color: warningColor.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.info_outline,
              size: 12,
              color: warningColor.withValues(alpha: 0.8),
            ),
          ],
        ),
      ),
    );
  }

  void _showLeaveDetailsDialog(Map<String, dynamic> leaveInfo) {
    final leaveType = leaveInfo['leaveType'] ?? 'Leave';
    final startDate = DateTime.tryParse(leaveInfo['startDate'] ?? '');
    final endDate = DateTime.tryParse(leaveInfo['endDate'] ?? '');
    final totalDays = leaveInfo['totalDays'] ?? 0;
    final daysRemaining = leaveInfo['daysRemaining'] ?? 0;
    final daysElapsed = leaveInfo['daysElapsed'] ?? 0;
    final reason = leaveInfo['reason'] ?? 'No reason provided';

    final freshContext = GlobalNavigator.navigatorKey.currentContext;
    final authProvider = freshContext != null
        ? Provider.of<AuthProvider>(freshContext, listen: false)
        : Provider.of<AuthProvider>(context, listen: false);
    final companyProvider = freshContext != null
        ? Provider.of<CompanyProvider>(freshContext, listen: false)
        : Provider.of<CompanyProvider>(context, listen: false);

    showDialog(
      context: freshContext ?? context,
      builder: (context) => AlertDialog(
        title: Text('$leaveType Leave Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (startDate != null && endDate != null) ...[
              _buildDetailRow(
                'From:',
                TimeUtils.formatReadableDate(
                  startDate,
                  user: authProvider.user,
                  company: companyProvider.currentCompany?.toJson(),
                ),
              ),
              _buildDetailRow(
                'To:',
                TimeUtils.formatReadableDate(
                  endDate,
                  user: authProvider.user,
                  company: companyProvider.currentCompany?.toJson(),
                ),
              ),
              const SizedBox(height: 8),
            ],
            _buildDetailRow('Total Duration:', '$totalDays days'),
            _buildDetailRow('Days Remaining:', '$daysRemaining days'),
            _buildDetailRow('Days Elapsed:', '$daysElapsed days'),
            if (reason.isNotEmpty && reason != 'No reason provided') ...[
              const SizedBox(height: 8),
              _buildDetailRow('Reason:', reason, isMultiline: true),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(
    String label,
    String value, {
    bool isMultiline = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: isMultiline
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.9),
              ),
              maxLines: isMultiline ? null : 1,
              overflow: isMultiline ? null : TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
