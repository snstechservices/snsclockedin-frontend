import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'dart:io';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../providers/attendance_provider.dart';
import '../../providers/company_provider.dart';
import '../../services/attendance_service.dart';
import '../../services/global_notification_service.dart';
import '../../utils/global_navigator.dart';
import '../../services/action_sound_service.dart';
import '../../services/haptic_feedback_service.dart';
import '../../config/api_config.dart';
import 'dart:convert';
import '../../widgets/admin_side_navigation.dart';
import '../../utils/time_utils.dart';
import '../../utils/theme_utils.dart';
import '../../utils/logger.dart';

class AdminAttendanceScreen extends StatefulWidget {
  const AdminAttendanceScreen({super.key});

  @override
  State<AdminAttendanceScreen> createState() => _AdminAttendanceScreenState();
}

class _AdminAttendanceScreenState extends State<AdminAttendanceScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  String _currentStatus = 'Not Clocked In';
  DateTime? _clockInTime;
  DateTime? _clockOutTime;
  Duration _totalWorkTime = Duration.zero;
  Timer? _timer;
  DateTime _currentTime = DateTime.now().toUtc();
  bool _isOnBreak = false;
  DateTime? _breakStartTime;
  Duration _breakDuration = Duration.zero;
  List<Map<String, dynamic>> _allBreaks =
      []; // Store all breaks (active and completed)
  Map<String, dynamic>? _weeklyStats;
  late AnimationController _clockController;
  late Animation<double> _clockAnimation;
  List<Map<String, dynamic>> _breakTypes = [];

  @override
  void initState() {
    super.initState();
    _startTimer();
    _loadCurrentStatus();
    _loadWeeklyStats();
    _fetchBreakTypes(); // Pre-fetch break types so they're available offline

    // Ensure company is loaded for timezone display
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final companyProvider = Provider.of<CompanyProvider>(
        context,
        listen: false,
      );
      if (companyProvider.currentCompany == null) {
        // Try loading from cache first (fast)
        await companyProvider.loadStoredCompany();
        // If still null after cache load, fetch from server
        if (companyProvider.currentCompany == null) {
          await companyProvider.fetchCurrentCompany();
        }
      }
    });

    _clockController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
    _clockAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _clockController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _clockController.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        // Use UTC time to ensure consistent timezone conversion
        _currentTime = DateTime.now().toUtc();
        if (_clockInTime != null && _clockOutTime == null) {
          _calculateWorkTime();
        }
        if (_isOnBreak && _breakStartTime != null) {
          _breakDuration = _currentTime.difference(_breakStartTime!);
        }
      });
    });
  }

  Future<void> _loadCurrentStatus({bool forceRefresh = false}) async {
    setState(() => _isLoading = true);
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.user?['_id'];
      if (userId != null) {
        final attendanceProvider = Provider.of<AttendanceProvider>(
          context,
          listen: false,
        );
        await attendanceProvider.fetchTodayStatus(
          userId,
          forceRefresh: forceRefresh,
        );
        final status = attendanceProvider.todayStatus;
        final currentAttendance = attendanceProvider.currentAttendance;
        setState(() {
          _currentStatus = _getStatusText(status);
          if (currentAttendance != null) {
            final dateString = currentAttendance['date'] as String?;
            // Backend sends time strings (HH:mm) that need to be combined with the date
            _clockInTime = currentAttendance['checkInTime'] != null
                ? TimeUtils.parseTimeWithDate(
                    currentAttendance['checkInTime'],
                    dateString,
                  )
                : null;
            _clockOutTime = currentAttendance['checkOutTime'] != null
                ? TimeUtils.parseTimeWithDate(
                    currentAttendance['checkOutTime'],
                    dateString,
                  )
                : null;
            _calculateWorkTime();
            final breaks = currentAttendance['breaks'] as List<dynamic>?;
            if (breaks != null && breaks.isNotEmpty) {
              // Store all breaks
              _allBreaks = breaks.cast<Map<String, dynamic>>();

              // Check for active break (last break without end time)
              final lastBreak = breaks.last;
              final hasNoEnd =
                  lastBreak['end'] == null && lastBreak['endTime'] == null;
              if (hasNoEnd) {
                _isOnBreak = true;
                // Support both 'start' and 'startTime' formats
                final startTimeStr =
                    lastBreak['start'] ?? lastBreak['startTime'];
                if (startTimeStr != null) {
                  _breakStartTime = DateTime.parse(startTimeStr.toString());
                  _breakDuration = _currentTime.difference(_breakStartTime!);
                } else {
                  _isOnBreak = false;
                  _breakStartTime = null;
                  _breakDuration = Duration.zero;
                }
              } else {
                _isOnBreak = false;
                _breakStartTime = null;
                _breakDuration = Duration.zero;
              }
            } else {
              _allBreaks = [];
              _isOnBreak = false;
              _breakStartTime = null;
              _breakDuration = Duration.zero;
            }
          }
        });
      }
    } catch (e) {
      GlobalNotificationService().showError(
        'Error loading status: ${e.toString()}',
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadWeeklyStats() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.user?['_id'];

      if (userId != null) {
        final attendanceProvider = Provider.of<AttendanceProvider>(
          context,
          listen: false,
        );
        final companyProvider = Provider.of<CompanyProvider>(
          context,
          listen: false,
        );
        final company = companyProvider.currentCompany?.toJson();

        // Use company timezone to get current date
        final nowInCompanyTz = TimeUtils.convertToEffectiveTimezone(
          DateTime.now(),
          authProvider.user,
          company,
        );

        // Calculate start of week (Monday) in company timezone
        // weekday: 1=Monday, 7=Sunday
        final daysFromMonday = nowInCompanyTz.weekday - 1;
        final startOfWeek = DateTime(
          nowInCompanyTz.year,
          nowInCompanyTz.month,
          nowInCompanyTz.day,
        ).subtract(Duration(days: daysFromMonday));

        // End date should be today (not future dates), capped to today in company timezone
        final endOfWeek = DateTime(
          nowInCompanyTz.year,
          nowInCompanyTz.month,
          nowInCompanyTz.day,
          23,
          59,
          59,
        );

        // Convert to UTC for backend (backend expects UTC dates)
        // Set time to midnight UTC for start date and end of day for end date
        final startDateUtc = DateTime.utc(
          startOfWeek.year,
          startOfWeek.month,
          startOfWeek.day,
          0,
          0,
          0,
        );
        final endDateUtc = DateTime.utc(
          endOfWeek.year,
          endOfWeek.month,
          endOfWeek.day,
          23,
          59,
          59,
        );

        Logger.info(
          'Weekly Stats: Company timezone - Start: ${DateFormat('yyyy-MM-dd').format(startOfWeek)}, End: ${DateFormat('yyyy-MM-dd').format(endOfWeek)}',
        );
        Logger.info(
          'Weekly Stats: UTC dates being sent - Start: ${startDateUtc.toIso8601String()}, End: ${endDateUtc.toIso8601String()}',
        );

        await attendanceProvider.fetchAttendanceSummary(
          userId,
          startDate: startDateUtc,
          endDate: endDateUtc,
        );

        // Log the received summary for debugging
        if (attendanceProvider.attendanceSummary != null) {
          final summary = attendanceProvider.attendanceSummary!;
          Logger.info(
            'Weekly Stats: Received summary - Days: ${summary['totalDaysPresent']}, Hours: ${summary['totalHoursWorked']}, Break: ${summary['totalBreakTime']}',
          );
          Logger.info(
            'Weekly Stats: Backend date range - Start: ${summary['startDate']}, End: ${summary['endDate']}',
          );

          setState(() {
            _weeklyStats = attendanceProvider.attendanceSummary;
          });
        } else {
          Logger.warning('Weekly Stats: attendanceSummary is null after fetch');
          // Set empty stats to show the card with zero values
          setState(() {
            _weeklyStats = {
              'totalDaysPresent': 0,
              'totalHoursWorked': 0,
              'totalBreakTime': 0,
              'averageHoursPerDay': 0,
            };
          });
        }
      }
    } catch (e) {
      // Error handling - could log to crash analytics
      Logger.error('Error loading weekly stats: $e');
      // Show the card with zero values even if there's an error
      setState(() {
        _weeklyStats = {
          'totalDaysPresent': 0,
          'totalHoursWorked': 0,
          'totalBreakTime': 0,
          'averageHoursPerDay': 0,
        };
      });
    }
  }

  String _getStatusText(String? status) {
    switch (status) {
      case 'not_clocked_in':
        return 'Not Clocked In';
      case 'clocked_in':
        return 'Clocked In';
      case 'on_break':
        return 'On Break';
      case 'clocked_out':
        return 'Clocked Out';
      default:
        return 'Not Clocked In';
    }
  }

  void _calculateWorkTime() {
    if (_clockInTime != null) {
      final endTime = _clockOutTime ?? _currentTime;
      _totalWorkTime = endTime.difference(_clockInTime!);
    }
  }

  Future<void> _clockIn() async {
    // CRITICAL FIX: Prevent clock in when admin is on leave
    final attendanceProvider = Provider.of<AttendanceProvider>(
      context,
      listen: false,
    );
    if (attendanceProvider.leaveInfo != null) {
      GlobalNotificationService().showError(
        'Cannot clock in while on leave. Attendance actions are disabled during your leave period.',
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.user?['_id'];
      if (userId == null) {
        GlobalNotificationService().showError(
          'User not logged in. Please log in again.',
        );
        return;
      }
      final companyProvider = Provider.of<CompanyProvider>(
        context,
        listen: false,
      );

      // Use AttendanceProvider which uses repository with optimistic updates
      await attendanceProvider.clockIn(userId);
      // Force refresh to get latest data from server immediately after clock-in
      await _loadCurrentStatus(forceRefresh: true);

      // Verify clock-in actually succeeded before showing success
      final currentStatus = attendanceProvider.todayStatus;
      if (currentStatus != 'clocked_in' && currentStatus != 'on_break') {
        throw Exception(
          'Clock-in was not successful. Current status: $currentStatus',
        );
      }

      final user = authProvider.user;
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
    } catch (e) {
      // Enhanced error handling: try to extract server message (JSON or plain)
      String errorMessage = 'An error occurred while clocking in.';
      String errorString = e.toString();

      // If exception contains a JSON payload, try to parse and extract `message`
      try {
        final jsonMatch = RegExp(
          r'(\{[\s\S]*\})',
          dotAll: true,
        ).firstMatch(errorString);
        if (jsonMatch != null) {
          final parsed = json.decode(jsonMatch.group(1)!);
          if (parsed is Map && parsed['message'] != null) {
            errorString = parsed['message'].toString();
          }
        }
      } catch (parseErr) {
        // ignore and continue with original errorString
      }

      final lc = errorString.toLowerCase();

      if (lc.contains('outside working hours') ||
          lc.contains('outside working hour')) {
        // Extract working hours information from the error
        final workingHoursMatch = RegExp(
          r'working hours: (\d{2}:\d{2}) - (\d{2}:\d{2})',
          caseSensitive: false,
        ).firstMatch(errorString);
        final localTimeMatch = RegExp(
          r'your local time: ([^,]+)',
          caseSensitive: false,
        ).firstMatch(errorString);

        if (workingHoursMatch != null && localTimeMatch != null) {
          final startTime = workingHoursMatch.group(1);
          final endTime = workingHoursMatch.group(2);
          final localTime = localTimeMatch.group(1);
          errorMessage =
              'Clock-in failed: Outside working hours.\n\nYour time: $localTime\nWorking hours: $startTime - $endTime\n\nAs an admin, you can still clock in outside working hours for urgent matters.';
        } else {
          errorMessage =
              'Clock-in failed: Outside working hours. Please check your company\'s working hours.';
        }
      } else if (lc.contains('holiday')) {
        errorMessage =
            'Cannot clock in on company holidays. Please check the company calendar.';
      } else if (lc.contains('non-working day') ||
          lc.contains('non working day')) {
        errorMessage =
            'Cannot clock in on non-working days. Please check the company calendar.';
      } else if (lc.contains('working day')) {
        errorMessage =
            'Cannot clock in on non-working days. Please check the company calendar.';
      } else if (lc.contains('already checked in') ||
          lc.contains('already checked in for today')) {
        errorMessage = 'You have already clocked in for today.';
      } else if (lc.contains('on approved') ||
          lc.contains('on leave') ||
          lc.contains('approved leave')) {
        errorMessage = 'Cannot clock in while on approved leave.';
      } else if (lc.contains('clock-in failed:') ||
          lc.contains('cannot clock in')) {
        // Use the detailed error message from the backend
        errorMessage = errorString.replaceFirst('Exception: ', '');
      }

      GlobalNotificationService().showError(errorMessage);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _clockOut() async {
    // CRITICAL FIX: Prevent clock out when admin is on leave
    final attendanceProvider = Provider.of<AttendanceProvider>(
      context,
      listen: false,
    );
    if (attendanceProvider.leaveInfo != null) {
      GlobalNotificationService().showError(
        'Cannot clock out while on leave. Attendance actions are disabled during your leave period.',
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.user?['_id'];
      if (userId == null) {
        GlobalNotificationService().showError(
          'User not logged in. Please log in again.',
        );
        return;
      }
      final companyProvider = Provider.of<CompanyProvider>(
        context,
        listen: false,
      );

      // Use AttendanceProvider which uses repository with optimistic updates
      await attendanceProvider.clockOut(userId);
      // Force refresh to get latest data from server immediately after clock-out
      await _loadCurrentStatus(forceRefresh: true);
      final user = authProvider.user;
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
    } catch (e) {
      GlobalNotificationService().showError(
        'Failed to clock out: ${e.toString()}',
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchBreakTypes() async {
    try {
      final attendanceProvider = Provider.of<AttendanceProvider>(
        context,
        listen: false,
      );
      // Load from cache first (will return cached data immediately if available)
      final breakTypes = await attendanceProvider.getBreakTypes(
        forceRefresh: false,
      );
      if (mounted) {
        setState(() {
          _breakTypes = breakTypes;
        });
      }

      // If no break types found, try force refresh
      if (breakTypes.isEmpty && mounted) {
        Logger.info(
          'AdminAttendanceScreen: No cached break types, trying force refresh',
        );
        final refreshed = await attendanceProvider.getBreakTypes(
          forceRefresh: true,
        );
        if (mounted) {
          setState(() {
            _breakTypes = refreshed;
          });
        }
      }
    } catch (e) {
      Logger.warning('AdminAttendanceScreen: Failed to fetch break types: $e');
      // Try to get cached data even if fetch failed
      try {
        final freshContext = GlobalNavigator.navigatorKey.currentContext;
        if (freshContext != null) {
          // We capture the provider reference from the navigator context
          // immediately and then await the provider's async method. This
          // avoids using the outer `context` across an async gap. The
          // analyzer may still warn; silence it narrowly here because the
          // provider instance is captured synchronously from the fresh
          // navigator context.
          // ignore: use_build_context_synchronously
          final attendanceProvider = Provider.of<AttendanceProvider>(
            freshContext,
            listen: false,
          );
          final cached = await attendanceProvider.getBreakTypes(
            forceRefresh: false,
          );
          if (mounted && cached.isNotEmpty) {
            setState(() {
              _breakTypes = cached;
            });
          }
        } else {
          Logger.warning(
            'AdminAttendanceScreen: No navigator context available to read cached break types',
          );
        }
      } catch (e2) {
        Logger.warning(
          'AdminAttendanceScreen: Failed to get cached break types: $e2',
        );
      }
    }
  }

  Future<void> _startBreak() async {
    // Only fetch break types if we don't have them cached
    if (_breakTypes.isEmpty) {
      await _fetchBreakTypes();
    }
    if (_breakTypes.isEmpty) {
      GlobalNotificationService().showError('No break types available.');
      return;
    }
    if (!mounted) return;
    // Use the global navigator context to capture providers so we don't use
    // the State `context` across an async gap when showing the dialog.
    final freshContext = GlobalNavigator.navigatorKey.currentContext;
    if (freshContext == null || !mounted) {
      GlobalNotificationService().showInfo(
        'Unable to open break selector right now.',
      );
      return;
    }

    // Capture providers from the fresh (navigator) context.
    // ignore: use_build_context_synchronously
    final preAuthProvider = Provider.of<AuthProvider>(
      freshContext,
      listen: false,
    );
    // ignore: use_build_context_synchronously
    final preAttendanceProvider = Provider.of<AttendanceProvider>(
      freshContext,
      listen: false,
    );
    // ignore: use_build_context_synchronously
    final preCompanyProvider = Provider.of<CompanyProvider>(
      freshContext,
      listen: false,
    );

    final selected = await showDialog<Map<String, dynamic>>(
      context: freshContext,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('Select Break Type'),
        children: _breakTypes.map((type) {
          return SimpleDialogOption(
            onPressed: () => Navigator.pop(dialogContext, type),
            child: Row(
              children: [
                Icon(
                  _getMaterialIcon(type['icon']),
                  color: _parseColor(type['color']),
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        type['displayName'] ?? type['name'],
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      if (type['description'] != null &&
                          type['description'].toString().isNotEmpty)
                        Text(
                          type['description'],
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
    if (selected == null) return;
    if (!mounted) return;
    try {
      final authProvider = preAuthProvider;
      final userId = authProvider.user?['_id'];
      if (userId == null) return;
      if (!mounted) return;
      final attendanceProvider = preAttendanceProvider;

      // Start break with optimistic update
      await attendanceProvider.startBreakWithType(userId, selected);

      // Wait a brief moment for optimistic update to complete
      await Future.delayed(const Duration(milliseconds: 100));

      // Get updated attendance from provider (should have optimistic data)
      final currentAttendance = attendanceProvider.currentAttendance;

      if (mounted) {
        setState(() {
          // Extract break start time from provider's current attendance
          if (currentAttendance != null) {
            final breaks = currentAttendance['breaks'] as List<dynamic>?;
            if (breaks != null && breaks.isNotEmpty) {
              final lastBreak = breaks.last;
              final startTimeStr = lastBreak['start'] ?? lastBreak['startTime'];
              if (startTimeStr != null) {
                _breakStartTime = DateTime.parse(startTimeStr);
                _isOnBreak = true;
                _breakDuration = _currentTime.difference(_breakStartTime!);

                // Update all breaks list
                _allBreaks = breaks.cast<Map<String, dynamic>>();
              }
            }
          }
        });
      }

      final user = authProvider.user;
      final companyProvider = preCompanyProvider;
      final timeStr = TimeUtils.formatTimeWithSmartTimezone(
        DateTime.now(),
        user: user,
        company: companyProvider.currentCompany?.toJson(),
      );
      GlobalNotificationService().showEvent(
        'Break Started',
        '${selected['displayName'] ?? selected['name']} started at $timeStr',
      );

      // Haptic feedback for success
      await HapticFeedbackService.instance.success();

      // Play sound for start break
      await ActionSoundService.instance.playStartBreakSound();

      // Force refresh to get latest data from server immediately after starting break
      // Background refresh uses provider directly; use a fresh context if needed inside the callback
      attendanceProvider
          .fetchTodayStatus(userId, forceRefresh: true)
          .then((_) {
            if (mounted) {
              _loadCurrentStatus(forceRefresh: true);
            }
          })
          .catchError((e) {
            Logger.warning(
              'AdminAttendanceScreen: Background refresh failed: $e',
            );
          });
    } catch (e) {
      GlobalNotificationService().showError(
        'Failed to start break: ${e.toString()}',
      );
    }
  }

  Future<void> _endBreak() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.user?['_id'];
      if (userId == null) return;
      final companyProvider = Provider.of<CompanyProvider>(
        context,
        listen: false,
      );
      final attendanceProvider = Provider.of<AttendanceProvider>(
        context,
        listen: false,
      );
      await attendanceProvider.endBreak(userId);

      // CRITICAL FIX: Refresh attendance status immediately with force refresh
      await attendanceProvider.fetchTodayStatus(userId, forceRefresh: true);

      setState(() {
        _isOnBreak = false;
        _breakStartTime = null;
        _breakDuration = Duration.zero;
      });

      // Force refresh to get latest data from server immediately after ending break
      await _loadCurrentStatus(forceRefresh: true);
      final user = authProvider.user;
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
    } catch (e) {
      String errorMessage = e.toString();
      if (errorMessage.contains('not found') ||
          errorMessage.contains('not currently on break')) {
        errorMessage = 'No active break found for this employee.';
      }
      GlobalNotificationService().showError(
        'Failed to end break: $errorMessage',
      );

      // Try to refresh canonical attendance to avoid stale UI
      try {
        // Capture fresh context and providers BEFORE awaiting to avoid using
        // a BuildContext across an async gap. We intentionally capture the
        // provider reference so it can be used after the short delay.
        final freshContext = GlobalNavigator.navigatorKey.currentContext;
        // ignore: use_build_context_synchronously
        final authProvider = freshContext != null
            ? Provider.of<AuthProvider>(freshContext, listen: false)
            : null;
        final userId = authProvider?.user?['_id'];
        await Future.delayed(const Duration(milliseconds: 350));
        if (authProvider != null && userId != null) {
          final attendanceService = AttendanceService(authProvider);
          final response = await attendanceService.getAttendanceStatusWithData(
            userId,
            forceRefresh: true,
          );
          if (response['attendance'] != null) {
            final att = response['attendance'] as Map<String, dynamic>;
            setState(() {
              final dateString = att['date'] as String?;
              _clockInTime = att['checkInTime'] != null
                  ? TimeUtils.parseTimeWithDate(att['checkInTime'], dateString)
                  : null;
              _clockOutTime = att['checkOutTime'] != null
                  ? TimeUtils.parseTimeWithDate(att['checkOutTime'], dateString)
                  : null;
              final breaks = att['breaks'] as List<dynamic>?;
              if (breaks != null && breaks.isNotEmpty) {
                _allBreaks = breaks.cast<Map<String, dynamic>>();
                final lastBreak = breaks.last;
                final hasNoEnd =
                    lastBreak['end'] == null && lastBreak['endTime'] == null;
                if (hasNoEnd) {
                  _isOnBreak = true;
                  final startTimeStr =
                      lastBreak['start'] ?? lastBreak['startTime'];
                  _breakStartTime = startTimeStr != null
                      ? DateTime.parse(startTimeStr.toString())
                      : null;
                  _breakDuration = _breakStartTime != null
                      ? _currentTime.difference(_breakStartTime!)
                      : Duration.zero;
                } else {
                  _isOnBreak = false;
                  _breakStartTime = null;
                  _breakDuration = Duration.zero;
                }
              } else {
                _allBreaks = [];
                _isOnBreak = false;
                _breakStartTime = null;
                _breakDuration = Duration.zero;
              }
            });
            return;
          }
        }
      } catch (fetchErr) {
        Logger.warning(
          'AdminAttendanceScreen: Failed to refresh after endBreak error: $fetchErr',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.7),
          ],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('My Attendance'),
          backgroundColor: Theme.of(context).colorScheme.primary,
          elevation: 0,
          foregroundColor: ThemeUtils.getAutoTextColor(
            Theme.of(context).colorScheme.primary,
          ),
          actions: [],
        ),
        drawer: const AdminSideNavigation(currentRoute: '/admin_attendance'),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth >= 1200) {
                    // Desktop mode: center and constrain width
                    return Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1100),
                        child: _buildMainContent(),
                      ),
                    );
                  } else {
                    // Mobile/tablet mode: full width
                    return _buildMainContent();
                  }
                },
              ),
      ),
    );
  }

  Widget _buildMainContent() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;
    final avatarUrl = user?['avatar'] as String?;
    final name = user?['firstName'] ?? 'Admin';
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Profile Avatar & Greeting
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: Colors.white,
                backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty)
                    ? _getAvatarProvider(avatarUrl)
                    : null,
                child: (avatarUrl == null || avatarUrl.isEmpty)
                    ? Icon(
                        Icons.person,
                        size: 32,
                        color: Theme.of(context).colorScheme.primary,
                      )
                    : null,
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hello, $name!',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Welcome back',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          // Quick Actions (moved to top)
          Card(
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            margin: const EdgeInsets.symmetric(vertical: 6),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  const Text(
                    'Quick Actions',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  // Day-type / Leave Status Banner (Holiday > Non-Working Day > Leave)
                  Builder(
                    builder: (context) {
                      final attendanceProvider =
                          Provider.of<AttendanceProvider>(
                            context,
                            listen: false,
                          );
                      final authProvider = Provider.of<AuthProvider>(
                        context,
                        listen: false,
                      );
                      final user = authProvider.user;
                      final holidayInfo = attendanceProvider.holidayInfo;
                      final nonWorkingDayInfo =
                          attendanceProvider.nonWorkingDayInfo;
                      final isOnLeave = attendanceProvider.leaveInfo != null;

                      if (holidayInfo != null) {
                        final holidayName = holidayInfo['name'] ?? 'Holiday';
                        final holidayType = holidayInfo['type'] ?? 'company';
                        final holidayLabel = holidayType == 'public'
                            ? 'Public Holiday'
                            : 'Company Holiday';
                        return Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          margin: const EdgeInsets.only(bottom: 16),
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
                                      '$holidayLabel: $holidayName',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.orange[700],
                                      ),
                                    ),
                                    if (holidayInfo['description'] != null) ...[
                                      const SizedBox(height: 6),
                                      Text(
                                        holidayInfo['description'],
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.orange[600],
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      } else if (nonWorkingDayInfo != null) {
                        final nwdName =
                            nonWorkingDayInfo['name'] ??
                            nonWorkingDayInfo['reason'] ??
                            'Non-Working Day';
                        return Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          margin: const EdgeInsets.only(bottom: 16),
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
                                      'Non-Working Day: $nwdName',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.orange[700],
                                      ),
                                    ),
                                    if (nonWorkingDayInfo['reason'] != null &&
                                        nonWorkingDayInfo['reason'] !=
                                            nwdName) ...[
                                      const SizedBox(height: 6),
                                      Text(
                                        'Reason: ${nonWorkingDayInfo['reason']}',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.orange[600],
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      } else if (isOnLeave) {
                        final leaveInfo = attendanceProvider.leaveInfo!;
                        final leaveType = leaveInfo['leaveType'] ?? 'Leave';
                        final endDate = leaveInfo['endDate'] != null
                            ? DateTime.parse(leaveInfo['endDate']).toLocal()
                            : null;
                        final endDateStr = endDate != null
                            ? TimeUtils.formatDate(endDate, user: user)
                            : 'Unknown';
                        return Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: ThemeUtils.getStatusChipColor(
                              'warning',
                              Theme.of(context),
                            ).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: ThemeUtils.getStatusChipColor(
                                'warning',
                                Theme.of(context),
                              ).withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.beach_access,
                                color: ThemeUtils.getStatusChipColor(
                                  'warning',
                                  Theme.of(context),
                                ),
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
                                        color: ThemeUtils.getStatusChipColor(
                                          'warning',
                                          Theme.of(context),
                                        ),
                                      ),
                                    ),
                                    Text(
                                      'Until $endDateStr',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: ThemeUtils.getStatusChipColor(
                                          'warning',
                                          Theme.of(context),
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
                  Builder(
                    builder: (context) {
                      final attendanceProvider =
                          Provider.of<AttendanceProvider>(
                            context,
                            listen: false,
                          );
                      final isOnLeave = attendanceProvider.leaveInfo != null;
                      final isHoliday = attendanceProvider.holidayInfo != null;
                      final isNonWorkingDay =
                          attendanceProvider.nonWorkingDayInfo != null;
                      final isRestricted =
                          isOnLeave || isHoliday || isNonWorkingDay;

                      return Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed:
                                  !isRestricted &&
                                      _currentStatus == 'Not Clocked In'
                                  ? _clockIn
                                  : null,
                              icon: const Icon(Icons.login),
                              label: const Text('Clock In'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isRestricted
                                    ? Colors.grey
                                    : ThemeUtils.getStatusChipColor(
                                        'approved',
                                        Theme.of(context),
                                      ),
                                foregroundColor: isRestricted
                                    ? Colors.white
                                    : ThemeUtils.getStatusChipTextColor(
                                        'approved',
                                        Theme.of(context),
                                      ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                textStyle: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: isRestricted ? 0 : 4,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed:
                                  !isRestricted &&
                                      _currentStatus == 'Clocked In'
                                  ? _clockOut
                                  : null,
                              icon: const Icon(Icons.logout),
                              label: const Text('Clock Out'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isRestricted
                                    ? Colors.grey
                                    : ThemeUtils.getStatusChipColor(
                                        'error',
                                        Theme.of(context),
                                      ),
                                foregroundColor: isRestricted
                                    ? Colors.white
                                    : ThemeUtils.getStatusChipTextColor(
                                        'error',
                                        Theme.of(context),
                                      ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                textStyle: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: isRestricted ? 0 : 4,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  if (_currentStatus == 'Clocked In' && !_isOnBreak) ...[
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _startBreak,
                        icon: const Icon(Icons.coffee),
                        label: const Text('Start Break'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ThemeUtils.getStatusChipColor(
                            'warning',
                            Theme.of(context),
                          ),
                          foregroundColor: ThemeUtils.getStatusChipTextColor(
                            'warning',
                            Theme.of(context),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          textStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 4,
                        ),
                      ),
                    ),
                  ],
                  if (_isOnBreak) ...[
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _endBreak,
                        icon: const Icon(Icons.stop),
                        label: const Text('End Break'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.secondary,
                          foregroundColor: ThemeUtils.getAutoTextColor(
                            Theme.of(context).colorScheme.secondary,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          textStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 4,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Live Clock
          Card(
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            margin: const EdgeInsets.symmetric(vertical: 6),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  const Text(
                    'Current Time',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  ScaleTransition(
                    scale: _clockAnimation,
                    child: Consumer2<AuthProvider, CompanyProvider>(
                      builder: (context, authProvider, companyProvider, child) {
                        final user = authProvider.user;
                        // Ensure company is loaded (async, but Consumer will rebuild when it loads)
                        if (companyProvider.currentCompany == null) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            companyProvider.loadStoredCompany();
                          });
                        }
                        final company = companyProvider.currentCompany
                            ?.toJson();

                        // LOG: Debug timezone loading
                        Logger.info(
                          'AdminAttendanceScreen: Current time display - Company is null: ${company == null}',
                        );
                        if (company != null) {
                          Logger.info(
                            'AdminAttendanceScreen: Company keys: ${company.keys.toList()}',
                          );
                          final settings = company['settings'];
                          if (settings != null) {
                            Logger.info(
                              'AdminAttendanceScreen: Settings keys: ${settings.keys.toList()}',
                            );
                            Logger.info(
                              'AdminAttendanceScreen: Company timezone: ${settings['timezone']}',
                            );
                          } else {
                            Logger.warning(
                              'AdminAttendanceScreen: Company settings is null',
                            );
                          }
                        }

                        return Text(
                          TimeUtils.formatTimeOnly(
                            _currentTime,
                            user: user,
                            company: company,
                          ),
                          style: const TextStyle(
                            fontSize: 38,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1976D2),
                            letterSpacing: 2,
                          ),
                        );
                      },
                    ),
                  ),
                  Consumer2<AuthProvider, CompanyProvider>(
                    builder: (context, authProvider, companyProvider, child) {
                      final user = authProvider.user;
                      // Ensure company is loaded (async, but Consumer will rebuild when it loads)
                      if (companyProvider.currentCompany == null) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          companyProvider.loadStoredCompany();
                        });
                      }
                      final company = companyProvider.currentCompany?.toJson();

                      // LOG: Debug timezone loading
                      Logger.info(
                        'AdminAttendanceScreen: DateTime with timezone display - Company is null: ${company == null}',
                      );
                      if (company != null) {
                        final settings = company['settings'];
                        if (settings != null) {
                          Logger.info(
                            'AdminAttendanceScreen: DateTime display - Company timezone: ${settings['timezone']}',
                          );
                        }
                      }

                      return Text(
                        TimeUtils.formatDateTimeWithTimezone(
                          _currentTime,
                          user: user,
                          company: company,
                        ),
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Status Card
          Card(
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            margin: const EdgeInsets.symmetric(vertical: 6),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  const Text(
                    'Current Status',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: _getStatusColor().withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _getStatusIcon(),
                          color: _getStatusColor(),
                          size: 22,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _currentStatus,
                          style: TextStyle(
                            color: _getStatusColor(),
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        // Show break information (active break and/or history)
                        if (_allBreaks.isNotEmpty) ...[
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Show active break if on break
                                if (_isOnBreak && _breakStartTime != null) ...[
                                  Consumer2<AuthProvider, CompanyProvider>(
                                    builder:
                                        (
                                          context,
                                          authProvider,
                                          companyProvider,
                                          child,
                                        ) {
                                          final user = authProvider.user;
                                          final lastBreak = _allBreaks.last;
                                          final breakType =
                                              lastBreak['breakType']
                                                  as Map<String, dynamic>?;
                                          final breakTypeName =
                                              breakType?['displayName'] ??
                                              breakType?['name'] ??
                                              'Break';
                                          return Text(
                                            '$breakTypeName started at: ${TimeUtils.formatTimeWithSmartTimezone(_breakStartTime!, user: user, company: companyProvider.currentCompany?.toJson())}',
                                            style: const TextStyle(
                                              fontSize: 14,
                                              color: Colors.black54,
                                            ),
                                          );
                                        },
                                  ),
                                  Text(
                                    'Break duration: ${_formatDuration(_breakDuration)}',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.black54,
                                    ),
                                  ),
                                  // Add separator if there are completed breaks
                                  if (_allBreaks
                                      .where(
                                        (breakItem) => breakItem['end'] != null,
                                      )
                                      .isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Container(
                                      height: 1,
                                      color: Colors.black12,
                                      margin: const EdgeInsets.only(bottom: 8),
                                    ),
                                  ],
                                ],
                                // Show break history (completed breaks) - show all completed breaks with visual separation
                                ..._allBreaks
                                    .where(
                                      (breakItem) => breakItem['end'] != null,
                                    )
                                    .toList()
                                    .asMap()
                                    .entries
                                    .map((entry) {
                                      final index = entry.key;
                                      final breakItem = entry.value;
                                      final startTime =
                                          breakItem['start'] != null
                                          ? DateTime.tryParse(
                                              breakItem['start'].toString(),
                                            )
                                          : null;
                                      final endTime = breakItem['end'] != null
                                          ? DateTime.tryParse(
                                              breakItem['end'].toString(),
                                            )
                                          : null;
                                      final breakType =
                                          breakItem['breakType']
                                              as Map<String, dynamic>?;
                                      final breakTypeName =
                                          breakType?['displayName'] ??
                                          breakType?['name'] ??
                                          'Break';

                                      if (startTime != null &&
                                          endTime != null) {
                                        final duration = endTime.difference(
                                          startTime,
                                        );
                                        return Consumer2<
                                          AuthProvider,
                                          CompanyProvider
                                        >(
                                          builder:
                                              (
                                                context,
                                                authProvider,
                                                companyProvider,
                                                child,
                                              ) {
                                                final user = authProvider.user;
                                                return Padding(
                                                  padding: EdgeInsets.only(
                                                    top: index > 0
                                                        ? 8
                                                        : 0, // Add spacing between breaks
                                                    bottom: 4,
                                                  ),
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      // Add divider before each break (except the first one)
                                                      if (index > 0)
                                                        Container(
                                                          margin:
                                                              const EdgeInsets.only(
                                                                bottom: 8,
                                                              ),
                                                          height: 1,
                                                          color: Colors.black12,
                                                        ),
                                                      Text(
                                                        '$breakTypeName: ${TimeUtils.formatTimeWithSmartTimezone(startTime, user: user, company: companyProvider.currentCompany?.toJson())} - ${TimeUtils.formatTimeWithSmartTimezone(endTime, user: user, company: companyProvider.currentCompany?.toJson())}',
                                                        style: const TextStyle(
                                                          fontSize: 13,
                                                          color: Colors.black54,
                                                        ),
                                                      ),
                                                      Text(
                                                        'Duration: ${_formatDuration(duration)}',
                                                        style: const TextStyle(
                                                          fontSize: 12,
                                                          color: Colors.black45,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              },
                                        );
                                      }
                                      return const SizedBox.shrink();
                                    }),
                              ],
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
          const SizedBox(height: 10),
          // Today's Time
          Card(
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            margin: const EdgeInsets.symmetric(vertical: 6),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  const Text(
                    "Today's Time",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 15),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildTimeDisplay(
                        'Clock In',
                        _clockInTime,
                        icon: Icons.login,
                        color: ThemeUtils.getStatusChipColor(
                          'approved',
                          Theme.of(context),
                        ),
                      ),
                      _buildTimeDisplay(
                        'Clock Out',
                        _clockOutTime,
                        icon: Icons.logout,
                        color: ThemeUtils.getStatusChipColor(
                          'error',
                          Theme.of(context),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  _buildTimeDisplay(
                    'Total Work Time',
                    null,
                    customText: _formatDuration(_totalWorkTime),
                    icon: Icons.access_time,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Weekly Summary Card
          if (_weeklyStats != null) ...[
            Card(
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              margin: const EdgeInsets.symmetric(vertical: 6),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    Column(
                      children: [
                        const Text(
                          'This Week Summary',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Builder(
                          builder: (context) {
                            final authProvider = Provider.of<AuthProvider>(
                              context,
                              listen: false,
                            );
                            final companyProvider =
                                Provider.of<CompanyProvider>(
                                  context,
                                  listen: false,
                                );
                            final company = companyProvider.currentCompany
                                ?.toJson();

                            // Calculate date range for display
                            final nowInCompanyTz =
                                TimeUtils.convertToEffectiveTimezone(
                                  DateTime.now(),
                                  authProvider.user,
                                  company,
                                );
                            final daysFromMonday = nowInCompanyTz.weekday - 1;
                            final startOfWeek = DateTime(
                              nowInCompanyTz.year,
                              nowInCompanyTz.month,
                              nowInCompanyTz.day,
                            ).subtract(Duration(days: daysFromMonday));

                            final startDateStr = DateFormat(
                              'MMM d',
                            ).format(startOfWeek);
                            final endDateStr = DateFormat(
                              'MMM d',
                            ).format(nowInCompanyTz);

                            return Text(
                              '$startDateStr - $endDateStr',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatCard(
                          'Days Present',
                          _weeklyStats!['totalDaysPresent']?.toString() ?? '0',
                          Icons.check_circle,
                          ThemeUtils.getStatusChipColor(
                            'approved',
                            Theme.of(context),
                          ),
                        ),
                        _buildStatCard(
                          'Total Hours',
                          _formatDurationFromHours(
                            (_weeklyStats!['totalHoursWorked'] ?? 0).toDouble(),
                          ),
                          Icons.access_time,
                          Theme.of(context).colorScheme.primary,
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatCard(
                          'Avg. Hours/Day',
                          _formatDurationFromHours(
                            (_weeklyStats!['averageHoursPerDay'] ?? 0)
                                .toDouble(),
                          ),
                          Icons.trending_up,
                          ThemeUtils.getStatusChipColor(
                            'warning',
                            Theme.of(context),
                          ),
                        ),
                        _buildStatCard(
                          'Break Time',
                          _formatDurationFromHours(
                            (_weeklyStats!['totalBreakTime'] ?? 0).toDouble(),
                          ),
                          Icons.coffee,
                          Colors.purple,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildTimeDisplay(
    String label,
    DateTime? time, {
    String? customText,
    IconData? icon,
    Color? color,
  }) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) Icon(icon, color: color ?? Colors.blue, size: 20),
            if (icon != null) const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: (color ?? Colors.blue).withValues(alpha: 0.8),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Consumer2<AuthProvider, CompanyProvider>(
          builder: (context, authProvider, companyProvider, child) {
            final user = authProvider.user;
            return Text(
              customText ??
                  (time != null
                      ? TimeUtils.formatTimeWithSmartTimezone(
                          time,
                          user: user,
                          company: companyProvider.currentCompany?.toJson(),
                        )
                      : '--:--'),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            );
          },
        ),
      ],
    );
  }

  Color _getStatusColor() {
    switch (_currentStatus) {
      case 'Not Clocked In':
        return Colors.grey;
      case 'Clocked In':
        return Colors.green;
      case 'On Break':
        return Colors.orange;
      case 'Clocked Out':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon() {
    switch (_currentStatus) {
      case 'Not Clocked In':
        return Icons.access_time;
      case 'Clocked In':
        return Icons.login;
      case 'On Break':
        return Icons.coffee;
      case 'Clocked Out':
        return Icons.logout;
      default:
        return Icons.access_time;
    }
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';
  }

  String _formatDurationFromHours(double hours) {
    final wholeHours = hours.floor();
    final minutes = ((hours - wholeHours) * 60).round();
    return '${wholeHours}h ${minutes}m';
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: color.withValues(alpha: 0.8),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  ImageProvider? _getAvatarProvider(String url) {
    if (url.startsWith('http')) {
      return NetworkImage(url);
    } else if (url.startsWith('/uploads')) {
      // Prepend the backend base URL (remove trailing /api if present)
      String base = ApiConfig.baseUrl;
      if (base.endsWith('/api')) base = base.substring(0, base.length - 4);
      return NetworkImage(base + url);
    } else if (url.startsWith('file://')) {
      return FileImage(File(url.replaceFirst('file://', '')));
    }
    return null;
  }

  IconData _getMaterialIcon(String? iconName) {
    // Map backend icon names to Material icons
    switch (iconName) {
      case 'free_breakfast':
        return Icons.free_breakfast;
      case 'lunch_dining':
        return Icons.lunch_dining;
      case 'coffee':
        return Icons.coffee;
      case 'local_cafe':
        return Icons.local_cafe;
      case 'restaurant':
        return Icons.restaurant;
      case 'self_improvement':
        return Icons.self_improvement;
      default:
        return Icons.free_breakfast;
    }
  }

  Color _parseColor(String? hex) {
    if (hex == null || hex.isEmpty) return Colors.grey;
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xff')));
    } catch (_) {
      return Colors.grey;
    }
  }
}
