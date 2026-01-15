import 'package:flutter/material.dart';
import 'package:sns_rooster/utils/logger.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/attendance_provider.dart';
import '../../providers/company_provider.dart';
import '../../config/api_config.dart';
import '../../widgets/admin_side_navigation.dart';
import '../../services/global_notification_service.dart';
import '../../services/attendance_service.dart';
import '../../utils/admin_leave_restrictions.dart';
import '../../utils/time_utils.dart';

class BreakManagementScreen extends StatefulWidget {
  const BreakManagementScreen({super.key});

  @override
  State<BreakManagementScreen> createState() => _BreakManagementScreenState();
}

class _BreakManagementScreenState extends State<BreakManagementScreen> {
  List<Map<String, dynamic>> _employees = [];
  List<Map<String, dynamic>> _breakTypes = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _searchQuery = '';

  bool _breakItemIsActive(Map<String, dynamic> breakItem) {
    final hasNoEnd =
        (breakItem['end'] == null) && (breakItem['endTime'] == null);
    return hasNoEnd || (breakItem['isActive'] == true);
  }

  @override
  void initState() {
    super.initState();
    _fetchBreakTypes();
    _fetchEmployees();
  }

  Future<void> _fetchBreakTypes() async {
    if (kDebugMode) Logger.debug('DEBUG: Entered _fetchBreakTypes');
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/admin/break-types'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${authProvider.token}',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (kDebugMode) Logger.debug('DEBUG breakTypes response: $data');
        setState(() {
          _breakTypes = List<Map<String, dynamic>>.from(data['breakTypes']);
        });
      }
    } catch (e) {
      if (kDebugMode)
        Logger.debug('DEBUG: Caught error in _fetchBreakTypes: $e');
      Logger.error('Error fetching break types: $e');
    }
  }

  Future<void> _fetchEmployees() async {
    if (!mounted) return; // Early return if not mounted

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final attendanceService = AttendanceService(authProvider);
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/auth/users'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${authProvider.token}',
        },
      );

      if (!mounted) return; // Check again before processing response

      if (response.statusCode == 200) {
        final users = jsonDecode(response.body) as List;
        if (kDebugMode) Logger.debug('DEBUG users response: $users');

        // Fetch break status for each employee using AttendanceService - OPTIMIZED with parallel calls
        List<Map<String, dynamic>> employeesWithBreakStatus = [];

        // Filter employees first
        final employeeUsers = users
            .where((user) => user['role'] == 'employee')
            .toList();

        // Make parallel API calls for all employees
        final attendanceFutures = employeeUsers.map((user) async {
          try {
            // 'DEBUG: Fetching attendance for ${user['email']} at timestamp: $timestamp');
            final attendance = await attendanceService
                .getAttendanceStatusWithData(user['_id'], forceRefresh: true);
            // 'DEBUG: Attendance response for ${user['email']}: ${attendance != null ? 'success' : 'null'}');
            return {'user': user, 'attendance': attendance};
          } catch (e) {
            // 'DEBUG: Error fetching attendance for ${user['email']}: $e');
            return {'user': user, 'attendance': null};
          }
        }).toList();

        // Wait for all API calls to complete
        final attendanceResults = await Future.wait(attendanceFutures);

        // Process results
        for (var result in attendanceResults) {
          if (!mounted) return; // Check mounted before processing

          final user = result['user'];
          final attendance = result['attendance'];
          // Extract break information from attendance data
          Map<String, dynamic>? breakStatus;
          if (attendance != null && attendance['attendance'] != null) {
            final att = attendance['attendance'];
            if (kDebugMode)
              Logger.debug('DEBUG: Attendance for ${user['email']}: $att');
            final breaks = att['breaks'] as List<dynamic>? ?? [];
            if (kDebugMode)
              Logger.debug('DEBUG: Breaks for ${user['email']}: $breaks');
            if (kDebugMode)
              Logger.debug(
                'DEBUG: Break details - start: ${breaks.map((b) => b['start']).toList()}',
              );
            if (kDebugMode)
              Logger.debug(
                'DEBUG: Break details - end: ${breaks.map((b) => b['end']).toList()}',
              );
            if (kDebugMode)
              Logger.debug(
                'DEBUG: Break details - type: ${breaks.map((b) => b['type']).toList()}',
              );

            final isOnBreak = breaks.any((b) {
              if (b is Map<String, dynamic>) return _breakItemIsActive(b);
              final mb = Map<String, dynamic>.from(b);
              return _breakItemIsActive(mb);
            });
            log('DEBUG: isOnBreak for ${user['email']}: $isOnBreak');

            final totalBreaks = breaks.length;
            // Use the totalBreakDuration from the database instead of calculating manually
            final totalBreakDuration = att['totalBreakDuration'] ?? 0;
            breakStatus = {
              'isOnBreak': isOnBreak,
              'isCheckedIn': att['checkInTime'] != null,
              'isCheckedOut': att['checkOutTime'] != null,
              'checkOutTime': att['checkOutTime'],
              'totalBreaks': totalBreaks,
              'totalBreakDuration': totalBreakDuration,
              'currentBreak': isOnBreak
                  ? breaks.firstWhere((b) {
                      final mb = b is Map<String, dynamic>
                          ? b
                          : Map<String, dynamic>.from(b);
                      return _breakItemIsActive(mb);
                    }, orElse: () => null)
                  : null,
            };

            log('DEBUG: breakStatus for ${user['email']}: $breakStatus');
            if (isOnBreak) {
              log(
                'DEBUG: Current break for ${user['email']}: ${breakStatus['currentBreak']}',
              );
            }
          }
          employeesWithBreakStatus.add({...user, 'breakStatus': breakStatus});
        }

        if (!mounted) return; // Final check before setState

        // 'DEBUG: Updating state with ${employeesWithBreakStatus.length} employees');
        // Preserve recently refreshed single-user entries (marked with _fresh) to avoid
        // being overwritten by cached bulk GET responses. Fresh entries expire after 10s.
        final now = DateTime.now();
        for (var i = 0; i < employeesWithBreakStatus.length; i++) {
          final entry = employeesWithBreakStatus[i];
          final existingIdx = _employees.indexWhere(
            (e) => e['_id'] == entry['_id'],
          );
          if (existingIdx != -1) {
            final existing = _employees[existingIdx];
            if (existing['_fresh'] == true) {
              final expiresAtStr = existing['_freshExpiresAt'] as String?;
              if (expiresAtStr != null) {
                try {
                  final expiresAt = DateTime.parse(expiresAtStr);
                  if (expiresAt.isAfter(now)) {
                    employeesWithBreakStatus[i] = existing;
                  }
                } catch (_) {}
              }
            }
          }
        }

        setState(() {
          _employees = employeesWithBreakStatus;
          _isLoading = false;
        });
        // 'DEBUG: State updated, _employees length: ${_employees.length}');
      } else {
        if (!mounted) return;
        setState(() {
          _errorMessage = 'Failed to fetch employees';
          _isLoading = false;
        });
      }
    } catch (e) {
      log('DEBUG: Caught error in _fetchEmployees: $e');
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _startBreak(
    String userId,
    Map<String, dynamic> breakType,
  ) async {
    // CRITICAL FIX: Prevent break management when admin is on leave
    final attendanceProvider = Provider.of<AttendanceProvider>(
      context,
      listen: false,
    );
    if (attendanceProvider.leaveInfo != null) {
      GlobalNotificationService().showError(
        'Cannot manage breaks while on leave. Break management is disabled during your leave period.',
      );
      return;
    }

    try {
      // Show duration confirmation dialog
      final confirmed = await _showBreakDurationConfirmation(breakType);
      if (!confirmed) return; // User cancelled

      setState(() {
        _isLoading = true;
      });

      if (!mounted) return;

      // Use repository pattern via AttendanceProvider
      final breakTypeName = breakType['name'] as String;
      final responseData = await attendanceProvider.adminStartBreak(
        userId,
        breakTypeName,
        reason: '',
      );

      if (mounted) {
        // Parse response data
        final attendance = responseData['attendance'] as Map<String, dynamic>?;

        // CRITICAL FIX: Immediately update local state for instant UI feedback
        setState(() {
          final employeeIndex = _employees.indexWhere(
            (emp) => emp['_id'] == userId,
          );
          if (employeeIndex != -1 && attendance != null) {
            // Extract break information from attendance data
            final breaks = attendance['breaks'] as List<dynamic>? ?? [];
            final isOnBreak = breaks.any((b) {
              if (b is Map<String, dynamic>) return _breakItemIsActive(b);
              final mb = Map<String, dynamic>.from(b);
              return _breakItemIsActive(mb);
            });
            final currentBreak = isOnBreak
                ? breaks.firstWhere((b) {
                    final mb = b is Map<String, dynamic>
                        ? b
                        : Map<String, dynamic>.from(b);
                    return _breakItemIsActive(mb);
                  }, orElse: () => null)
                : null;
            final totalBreaks = breaks.length;
            final totalBreakDuration = attendance['totalBreakDuration'] ?? 0;

            // Update the employee's break status immediately
            _employees[employeeIndex] = {
              ..._employees[employeeIndex],
              'breakStatus': {
                'isOnBreak': isOnBreak,
                'isCheckedIn': attendance['checkInTime'] != null,
                'isCheckedOut': attendance['checkOutTime'] != null,
                'checkOutTime': attendance['checkOutTime'],
                'totalBreaks': totalBreaks,
                'totalBreakDuration': totalBreakDuration,
                'currentBreak': currentBreak,
              },
            };
          }
        });

        GlobalNotificationService().showSuccess(
          responseData['message'] ?? 'Break started successfully',
        );
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = e.toString();

        // Make error messages more user-friendly
        if (errorMessage.contains('must be at least')) {
          errorMessage =
              'Break duration requirement not met. Please try again.';
        } else if (errorMessage.contains('already on break')) {
          errorMessage = 'Employee is already on break.';
        } else if (errorMessage.contains('not checked in')) {
          errorMessage = 'Employee must check in first.';
        }

        GlobalNotificationService().showError(
          'Error starting break: $errorMessage',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Format break duration from milliseconds to human-readable format
  String _formatBreakDuration(dynamic milliseconds) {
    // Handle null or invalid values
    if (milliseconds == null) return '0 min';

    // Convert to int if it's a double or string
    final int durationMs;
    if (milliseconds is int) {
      durationMs = milliseconds;
    } else if (milliseconds is double) {
      durationMs = milliseconds.round();
    } else if (milliseconds is String) {
      durationMs = int.tryParse(milliseconds) ?? 0;
    } else {
      return '0 min';
    }

    if (durationMs == 0) return '0 min';

    // Convert milliseconds to minutes
    final minutes = (durationMs / (1000 * 60)).round();

    if (minutes < 60) {
      return '$minutes min';
    } else {
      final hours = minutes ~/ 60;
      final remainingMinutes = minutes % 60;
      if (remainingMinutes == 0) {
        return '$hours ${hours == 1 ? 'hr' : 'hrs'}';
      } else {
        return '$hours ${hours == 1 ? 'hr' : 'hrs'} $remainingMinutes min';
      }
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
                  Text(
                    'You are about to start a $displayName for this employee.',
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Duration: $durationText',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  if (minDuration > 1)
                    Text(
                      '⚠️ This break type requires a minimum duration of $minDuration minutes.',
                      style: TextStyle(
                        color: Colors.orange[700],
                        fontWeight: FontWeight.w500,
                      ),
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

  Future<void> _endBreak(String userId, String employeeName) async {
    // CRITICAL FIX: Prevent break management when admin is on leave
    final attendanceProvider = Provider.of<AttendanceProvider>(
      context,
      listen: false,
    );
    if (attendanceProvider.leaveInfo != null) {
      GlobalNotificationService().showError(
        'Cannot manage breaks while on leave. Break management is disabled during your leave period.',
      );
      return;
    }

    try {
      if (!mounted) return;

      // Use repository pattern via AttendanceProvider
      final responseData = await attendanceProvider.adminEndBreak(userId);

      if (mounted) {
        // If server signalled an error but returned attendance, update UI from canonical attendance
        if (responseData['_server_error'] == true) {
          final serverMsg =
              responseData['_server_error_message'] as String? ??
              'Action rejected by server';
          GlobalNotificationService().showError('❌ $serverMsg');

          // Server says not on break → ALWAYS clear break state locally and DON'T re-fetch
          // The server state is transient/invalid at this point (break wasn't actually ended)
          // so we just clear locally and trust the next natural update or manual refresh
          setState(() {
            final employeeIndex = _employees.indexWhere(
              (emp) => emp['_id'] == userId,
            );
            if (employeeIndex != -1) {
              final existing = _employees[employeeIndex];
              _employees[employeeIndex] = {
                ...existing,
                'breakStatus': {
                  'isOnBreak': false,
                  'isCheckedIn':
                      existing['breakStatus']?['isCheckedIn'] ?? false,
                  'isCheckedOut':
                      existing['breakStatus']?['isCheckedOut'] ?? false,
                  'checkOutTime': existing['breakStatus']?['checkOutTime'],
                  'totalBreaks': existing['breakStatus']?['totalBreaks'] ?? 0,
                  'totalBreakDuration':
                      existing['breakStatus']?['totalBreakDuration'] ?? 0,
                  'currentBreak': null,
                },
                '_fresh': true,
                '_freshExpiresAt': DateTime.now()
                    .add(const Duration(seconds: 10))
                    .toIso8601String(),
              };
            }
          });
          return;
        }

        GlobalNotificationService().showSuccess(
          '✅ $employeeName is now back to work',
        );

        // Parse response to update local state immediately
        final attendance = responseData['attendance'] as Map<String, dynamic>?;

        if (attendance != null) {
          // Update local state immediately for instant UI feedback
          setState(() {
            final employeeIndex = _employees.indexWhere(
              (emp) => emp['_id'] == userId,
            );
            if (employeeIndex != -1) {
              final breaks = attendance['breaks'] as List<dynamic>? ?? [];
              final isOnBreak = breaks.any((b) {
                if (b is Map<String, dynamic>) return _breakItemIsActive(b);
                final mb = Map<String, dynamic>.from(b);
                return _breakItemIsActive(mb);
              });
              final totalBreaks = breaks.length;
              final totalBreakDuration = attendance['totalBreakDuration'] ?? 0;

              // Update the employee's break status immediately
              _employees[employeeIndex] = {
                ..._employees[employeeIndex],
                'breakStatus': {
                  'isOnBreak': isOnBreak,
                  'isCheckedIn': attendance['checkInTime'] != null,
                  'isCheckedOut': attendance['checkOutTime'] != null,
                  'checkOutTime': attendance['checkOutTime'],
                  'totalBreaks': totalBreaks,
                  'totalBreakDuration': totalBreakDuration,
                  'currentBreak': isOnBreak
                      ? breaks.firstWhere((b) {
                          final mb = b is Map<String, dynamic>
                              ? b
                              : Map<String, dynamic>.from(b);
                          return _breakItemIsActive(mb);
                        }, orElse: () => null)
                      : null,
                },
              };
            }
          });
          // Ensure canonical server state is reflected for this user only
          try {
            await _refreshSingleEmployee(userId);
          } catch (e) {
            log('DEBUG: _refreshSingleEmployee after adminEndBreak failed: $e');
            // Fallback to full refresh
            try {
              await _fetchEmployees();
            } catch (_) {}
          }
        }
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = e.toString();

        // Make error messages more user-friendly
        if (errorMessage.contains('must be at least')) {
          // Keep the original error message as it's already user-friendly
        } else if (errorMessage.contains('not found') ||
            errorMessage.contains('not currently on break')) {
          errorMessage = 'No active break found for this employee.';
        }

        GlobalNotificationService().showError(
          '❌ Error ending break: $errorMessage',
        );
      }
      // Refresh canonical state for this user (in case of race or stale cache)
      try {
        await _refreshSingleEmployee(userId);
      } catch (fetchErr) {
        log(
          'DEBUG: _refreshSingleEmployee after failed adminEndBreak failed: $fetchErr',
        );
        try {
          await _fetchEmployees();
        } catch (_) {}
      }
    }
  }

  /// Refresh attendance status for a single user and update local list
  Future<void> _refreshSingleEmployee(String userId) async {
    try {
      // Small delay to allow backend cache invalidation to propagate
      await Future.delayed(const Duration(milliseconds: 350));
      log('DEBUG: Refreshing attendance for user $userId');
      // ignore: use_build_context_synchronously
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final attendanceService = AttendanceService(authProvider);
      final response = await attendanceService.getAttendanceStatusWithData(
        userId,
        forceRefresh: true,
      );
      // If response is null or attendance is missing, clear the breakStatus
      if (response['attendance'] == null) {
        // Clear break status for this user to avoid stale 'On Break' UI
        if (!mounted) return;
        final idxNull = _employees.indexWhere((e) => e['_id'] == userId);
        if (idxNull != -1) {
          setState(() {
            _employees[idxNull] = {
              ..._employees[idxNull],
              'breakStatus': {
                'isOnBreak': false,
                'isCheckedIn':
                    _employees[idxNull]['breakStatus']?['isCheckedIn'] ?? false,
                'isCheckedOut':
                    _employees[idxNull]['breakStatus']?['isCheckedOut'] ??
                    false,
                'checkOutTime':
                    _employees[idxNull]['breakStatus']?['checkOutTime'],
                'totalBreaks':
                    _employees[idxNull]['breakStatus']?['totalBreaks'] ?? 0,
                'totalBreakDuration':
                    _employees[idxNull]['breakStatus']?['totalBreakDuration'] ??
                    0,
                'currentBreak': null,
              },
            };
          });
        }
        return;
      }

      final att = response['attendance'] as Map<String, dynamic>;
      final breaks = att['breaks'] as List<dynamic>? ?? [];
      final isOnBreak = breaks.any((b) {
        if (b is Map<String, dynamic>) return _breakItemIsActive(b);
        final mb = Map<String, dynamic>.from(b);
        return _breakItemIsActive(mb);
      });
      final totalBreaks = breaks.length;
      final totalBreakDuration = att['totalBreakDuration'] ?? 0;
      final breakStatus = {
        'isOnBreak': isOnBreak,
        'isCheckedIn': att['checkInTime'] != null,
        'isCheckedOut': att['checkOutTime'] != null,
        'checkOutTime': att['checkOutTime'],
        'totalBreaks': totalBreaks,
        'totalBreakDuration': totalBreakDuration,
        'currentBreak': isOnBreak
            ? breaks.firstWhere((b) {
                final mb = b is Map<String, dynamic>
                    ? b
                    : Map<String, dynamic>.from(b);
                return _breakItemIsActive(mb);
              }, orElse: () => null)
            : null,
      };

      if (!mounted) return;
      final idx = _employees.indexWhere((e) => e['_id'] == userId);
      if (idx != -1) {
        setState(() {
          _employees[idx] = {
            ..._employees[idx],
            'breakStatus': breakStatus,
            '_fresh': true,
            '_freshExpiresAt': DateTime.now()
                .add(const Duration(seconds: 10))
                .toIso8601String(),
          };
        });
      }
    } catch (e) {
      log('DEBUG: _refreshSingleEmployee error: $e');
    }
  }

  Future<Map<String, dynamic>?> _showBreakTypeDialog() async {
    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Select Break Type'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Choose the type of break:'),
                    const SizedBox(height: 16),
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _breakTypes.length,
                        itemBuilder: (context, index) {
                          final breakType = _breakTypes[index];
                          final color = _parseColor(
                            breakType['color'] ?? '#6B7280',
                          );
                          String durationText = '';
                          final min = breakType['minDuration'];
                          final max = breakType['maxDuration'];
                          if (min != null && max != null) {
                            durationText = 'Duration: $min–$max min';
                          } else if (max != null) {
                            durationText = 'Duration: up to $max min';
                          } else if (min != null) {
                            durationText = 'Duration: at least $min min';
                          }
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            child: ListTile(
                              leading: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: color,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  _getIconData(
                                    breakType['icon'] ?? 'more_horiz',
                                  ),
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              title: Text(
                                breakType['displayName'] ?? breakType['name'],
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(breakType['description'] ?? ''),
                                  if (durationText.isNotEmpty)
                                    Text(
                                      durationText,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withValues(alpha: 0.6),
                                      ),
                                    ),
                                  if (breakType['dailyLimit'] != null)
                                    Text(
                                      'Daily limit: ${breakType['dailyLimit']}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withValues(alpha: 0.6),
                                      ),
                                    ),
                                ],
                              ),
                              trailing: breakType['requiresApproval'] == true
                                  ? const Icon(
                                      Icons.admin_panel_settings,
                                      size: 16,
                                    )
                                  : null,
                              onTap: () {
                                if (breakType['requiresApproval'] == true) {
                                  // For approval-required breaks, return complete break type info
                                  Navigator.of(context).pop({
                                    '_id': breakType['_id'],
                                    'name': breakType['name'],
                                    'displayName': breakType['displayName'],
                                    'minDuration': breakType['minDuration'],
                                    'maxDuration': breakType['maxDuration'],
                                    'description': breakType['description'],
                                    'icon': breakType['icon'],
                                    'color': breakType['color'],
                                  });
                                } else {
                                  Navigator.of(context).pop({
                                    '_id':
                                        breakType['_id'], // ✅ CORRECT: include the MongoDB ObjectId
                                    'name': breakType['name'],
                                    'displayName': breakType['displayName'],
                                    'minDuration': breakType['minDuration'],
                                    'maxDuration': breakType['maxDuration'],
                                    'description': breakType['description'],
                                    'icon': breakType['icon'],
                                    'color': breakType['color'],
                                  });
                                }
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Color _parseColor(String colorString) {
    try {
      return Color(int.parse(colorString.replaceFirst('#', '0xFF')));
    } catch (e) {
      return Colors.grey;
    }
  }

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'restaurant':
        return Icons.restaurant;
      case 'local_cafe':
        return Icons.local_cafe;
      case 'person':
        return Icons.person;
      case 'local_hospital':
        return Icons.local_hospital;
      case 'smoking_rooms':
        return Icons.smoking_rooms;
      default:
        return Icons.more_horiz;
    }
  }

  Future<void> _showBreakHistoryModal(
    String userId,
    String employeeName,
  ) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final attendanceService = AttendanceService(authProvider);
    Map<String, dynamic>? attendance;
    try {
      final result = await attendanceService.getAttendanceStatusWithData(
        userId,
      );
      attendance = result['attendance'];
    } catch (e) {
      attendance = null;
    }

    // Ensure break types are loaded for lookup
    if (_breakTypes.isEmpty) {
      await _fetchBreakTypes();
    }

    final breaks = attendance != null
        ? (attendance['breaks'] as List<dynamic>? ?? [])
        : [];
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Break History for $employeeName'),
          content: attendance == null
              ? const Text('No attendance data for today.')
              : breaks.isEmpty
              ? const Text('No breaks taken today.')
              : SizedBox(
                  width: 350,
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: breaks.length,
                    separatorBuilder: (context, i) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      // CRITICAL FIX: Ensure index is int and breaks is a List
                      if (index < 0 || index >= breaks.length) {
                        return const SizedBox.shrink();
                      }

                      final br = breaks[index];
                      if (br == null) {
                        return const SizedBox.shrink();
                      }

                      // Only the LAST break in the list can be "Ongoing"
                      final isLastBreak = (index == breaks.length - 1);
                      final isOngoing = isLastBreak && _breakItemIsActive(br);

                      // Get break type name - check multiple possible fields
                      // Handle case where 'type' might be a String (ID) or Map
                      String breakType = 'Break';
                      if (br['breakTypeName'] != null) {
                        final name = br['breakTypeName'].toString();
                        // Don't display ObjectIds or long IDs
                        if (!_isObjectId(name)) {
                          breakType = name;
                        }
                      } else if (br['typeName'] != null) {
                        final name = br['typeName'].toString();
                        if (!_isObjectId(name)) {
                          breakType = name;
                        }
                      } else if (br['type'] != null) {
                        // Check if 'type' is a Map or String
                        if (br['type'] is Map) {
                          final typeMap = br['type'] as Map;
                          final displayName = typeMap['displayName']
                              ?.toString();
                          final name = typeMap['name']?.toString();
                          if (displayName != null &&
                              !_isObjectId(displayName)) {
                            breakType = displayName;
                          } else if (name != null && !_isObjectId(name)) {
                            breakType = name;
                          }
                        } else {
                          // 'type' is likely a String ID - try to look it up from break types
                          final typeId = br['type'].toString();
                          if (!_isObjectId(typeId)) {
                            // Not an ObjectId, might be a name
                            breakType = typeId;
                          } else {
                            // It's an ObjectId, try to find the break type from our list
                            final foundType = _breakTypes.firstWhere((bt) {
                              final btId = bt['_id']?.toString();
                              if (btId == null) return false;
                              // Check exact match
                              if (btId == typeId) return true;
                              // Check partial matches (in case of split ObjectIds)
                              final parts = typeId.split(' ');
                              if (parts.isNotEmpty &&
                                  btId.contains(parts.first)) {
                                return true;
                              }
                              if (parts.length > 1 &&
                                  btId.contains(parts.last)) {
                                return true;
                              }
                              return false;
                            }, orElse: () => {});
                            if (foundType.isNotEmpty) {
                              breakType =
                                  foundType['displayName']?.toString() ??
                                  foundType['name']?.toString() ??
                                  'Break';
                            }
                            // If not found, keep default 'Break'
                          }
                        }
                      }
                      // Safely parse start/startTime and end/endTime - handle both field names
                      final startValue = br['start'] ?? br['startTime'];
                      final endValue = br['end'] ?? br['endTime'];
                      final start = startValue != null
                          ? (startValue is String
                                ? DateTime.tryParse(startValue)
                                : startValue is DateTime
                                ? startValue
                                : DateTime.tryParse(startValue.toString()))
                          : null;
                      final end = endValue != null
                          ? (endValue is String
                                ? DateTime.tryParse(endValue)
                                : endValue is DateTime
                                ? endValue
                                : DateTime.tryParse(endValue.toString()))
                          : null;

                      // Use backend calculated duration if available, otherwise calculate from start/end times
                      int? duration;
                      if (br['duration'] != null) {
                        // Backend provides duration in milliseconds, convert to minutes
                        // Handle both int and String types for duration
                        final durationValue = br['duration'];
                        int durationMs;
                        if (durationValue is int) {
                          durationMs = durationValue;
                        } else if (durationValue is double) {
                          durationMs = durationValue.round();
                        } else if (durationValue is String) {
                          durationMs = int.tryParse(durationValue) ?? 0;
                        } else {
                          durationMs = 0;
                        }
                        duration = durationMs > 0
                            ? (durationMs / (1000 * 60)).round()
                            : null;
                      } else if (start != null && end != null) {
                        // Use utility function for consistent duration calculation
                        duration = TimeUtils.calculateDurationMinutes(
                          start,
                          end,
                        );
                      }
                      return Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: ListTile(
                          leading: const Icon(
                            Icons.free_breakfast,
                            color: Colors.orange,
                          ),
                          title: Text(
                            breakType,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Start: ${start != null ? _formatDateTime(start) : '-'}',
                              ),
                              Text(
                                'End: ${end != null ? _formatDateTime(end) : (isOngoing ? '🔴 Ongoing' : '-')}',
                                style: TextStyle(
                                  fontWeight: isOngoing
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: isOngoing ? Colors.red : null,
                                ),
                              ),
                              if (duration != null)
                                Text('Duration: $duration min'),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  String _formatDateTime(DateTime dt) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final companyProvider = Provider.of<CompanyProvider>(
      context,
      listen: false,
    );
    final company = companyProvider.currentCompany?.toJson();
    return TimeUtils.formatDateTime(
      dt,
      user: auth.user,
      company: company ?? auth.company,
    );
  }

  /// Check if a string looks like a MongoDB ObjectId
  /// ObjectIds are 24-character hex strings
  bool _isObjectId(String? value) {
    if (value == null || value.isEmpty) return false;
    // Check if it's a 24-character hex string (ObjectId format)
    // Also check for longer strings that might contain ObjectIds
    final trimmed = value.trim();
    if (trimmed.length == 24) {
      return RegExp(r'^[0-9a-fA-F]{24}$').hasMatch(trimmed);
    }
    // Check if it contains ObjectId-like patterns (e.g., "68b6b3e318e846e6a facfd83")
    if (trimmed.length > 20 && RegExp(r'^[0-9a-fA-F]{20,}').hasMatch(trimmed)) {
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // Check if admin is on leave and restrict break management
    final attendanceProvider = Provider.of<AttendanceProvider>(
      context,
      listen: false,
    );
    final isOnLeave = attendanceProvider.leaveInfo != null;

    // Debug logging for leave detection

    if (isOnLeave) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Break Management'),
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
        ),
        drawer: const AdminSideNavigation(currentRoute: '/break-management'),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                AdminLeaveRestrictions.getRestrictionIcon('breakManagement'),
                size: 64,
                color: Colors.orange[700],
              ),
              const SizedBox(height: 16),
              Text(
                'Break Management Restricted',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange[700],
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  AdminLeaveRestrictions.getRestrictionMessage(
                    'breakManagement',
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Go Back'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange[700],
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Filter employees by search query
    final filteredEmployees = _searchQuery.isEmpty
        ? _employees
        : _employees.where((emp) {
            final name = '${emp['firstName'] ?? ''} ${emp['lastName'] ?? ''}'
                .toLowerCase();
            final email = (emp['email'] ?? '').toLowerCase();
            final query = _searchQuery.toLowerCase();
            return name.contains(query) || email.contains(query);
          }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Break Management'),
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        actions: [],
      ),
      drawer: const AdminSideNavigation(currentRoute: '/break_management'),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _errorMessage!,
                    style: TextStyle(color: colorScheme.error),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _fetchEmployees,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _fetchEmployees,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: TextField(
                      decoration: InputDecoration(
                        labelText: 'Search employees',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value;
                        });
                      },
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16.0),
                      itemCount: filteredEmployees.length,
                      itemBuilder: (context, index) {
                        final employee = filteredEmployees[index];
                        final breakStatus = employee['breakStatus'];
                        final isCheckedIn =
                            breakStatus?['isCheckedIn'] ?? false;
                        final isCheckedOut =
                            breakStatus?['isCheckedOut'] ?? false;
                        final isOnBreak = breakStatus?['isOnBreak'] ?? false;
                        final totalBreaks = breakStatus?['totalBreaks'] ?? 0;
                        final totalBreakDuration =
                            breakStatus?['totalBreakDuration'] ?? 0;

                        // Get current break type information
                        String currentBreakType = 'Unknown';
                        String currentBreakDuration = '0 min';
                        if (isOnBreak && breakStatus?['currentBreak'] != null) {
                          final currentBreak = Map<String, dynamic>.from(
                            breakStatus['currentBreak'],
                          );
                          final breakTypeId = currentBreak['type'];

                          // Find break type name from fetched break types
                          if (breakTypeId != null && _breakTypes.isNotEmpty) {
                            final breakType = _breakTypes.firstWhere(
                              (type) => type['_id'] == breakTypeId,
                              orElse: () => {
                                'displayName': 'Break',
                                'name': 'Break',
                              },
                            );
                            currentBreakType =
                                breakType['displayName'] ??
                                breakType['name'] ??
                                'Break';
                          }

                          // Calculate current break duration
                          final startStr =
                              currentBreak['start'] ??
                              currentBreak['startTime'];
                          if (startStr != null) {
                            // Check if backend already calculated duration
                            if (currentBreak['duration'] != null) {
                              // Backend provides duration in milliseconds, convert to minutes
                              int durationMs = currentBreak['duration'];
                              currentBreakDuration =
                                  '${(durationMs / (1000 * 60)).round()} min';
                            } else {
                              // Fallback: calculate duration from start time to now
                              final startTime = DateTime.parse(startStr);
                              final now = DateTime.now();
                              final duration =
                                  TimeUtils.calculateDurationMinutes(
                                    startTime,
                                    now,
                                  );
                              currentBreakDuration =
                                  TimeUtils.formatDurationReadable(duration);
                            }
                          }
                        }

                        bool canEndBreak =
                            isOnBreak &&
                            isCheckedIn &&
                            breakStatus['checkOutTime'] == null;

                        return GestureDetector(
                          onTap: () => _showBreakHistoryModal(
                            employee['_id'],
                            ((employee['firstName'] != null &&
                                    employee['lastName'] != null)
                                ? '${employee['firstName']} ${employee['lastName']}'
                                : employee['email'] ?? 'Unknown User'),
                          ),
                          child: Card(
                            margin: const EdgeInsets.symmetric(vertical: 8.0),
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        backgroundColor: colorScheme.primary,
                                        child: Text(
                                          ((employee['firstName'] != null &&
                                                  employee['firstName']
                                                      .isNotEmpty)
                                              ? employee['firstName'][0]
                                                    .toUpperCase()
                                              : (employee['email'] != null &&
                                                    employee['email']
                                                        .isNotEmpty)
                                              ? employee['email'][0]
                                                    .toUpperCase()
                                              : '?'),
                                          style: TextStyle(
                                            color: colorScheme.onPrimary,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              ((employee['firstName'] != null &&
                                                      employee['lastName'] !=
                                                          null)
                                                  ? '${employee['firstName']} ${employee['lastName']}'
                                                  : employee['email'] ??
                                                        'Unknown User'),
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                            ),
                                            Text(
                                              employee['email'] ?? 'No email',
                                              style: TextStyle(
                                                color: colorScheme.onSurface
                                                    .withValues(alpha: 0.7),
                                                fontSize: 14,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isCheckedOut
                                              ? Colors.blue
                                              : (isCheckedIn
                                                    ? (isOnBreak
                                                          ? Colors.orange
                                                          : Colors.green)
                                                    : Colors.grey),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Text(
                                          isCheckedOut
                                              ? 'Checked Out'
                                              : (isCheckedIn
                                                    ? (isOnBreak
                                                          ? 'On Break'
                                                          : 'Working')
                                                    : 'Not Checked In'),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'Total Breaks Today: $totalBreaks',
                                          style: TextStyle(
                                            color: colorScheme.onSurface
                                                .withValues(alpha: 0.8),
                                          ),
                                        ),
                                      ),
                                      Text(
                                        'Break Time: ${_formatBreakDuration(totalBreakDuration)}',
                                        style: TextStyle(
                                          color: colorScheme.onSurface
                                              .withValues(alpha: 0.8),
                                        ),
                                      ),
                                    ],
                                  ),
                                  // Show current break type and duration when on break
                                  if (isOnBreak) ...[
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.withValues(
                                          alpha: 0.1,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: Colors.orange.withValues(
                                            alpha: 0.3,
                                          ),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.coffee,
                                            size: 16,
                                            color: Colors.orange,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Current Break: $currentBreakType',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.orange[700],
                                                    fontSize: 14,
                                                  ),
                                                ),
                                                Text(
                                                  'Duration: $currentBreakDuration',
                                                  style: TextStyle(
                                                    color: Colors.orange[600],
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
                                  const SizedBox(height: 12),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      if (isCheckedIn &&
                                          !isCheckedOut &&
                                          !isOnBreak)
                                        ElevatedButton.icon(
                                          onPressed: () =>
                                              _showBreakTypeDialog().then((
                                                selectedBreakType,
                                              ) {
                                                if (selectedBreakType != null) {
                                                  _startBreak(
                                                    employee['_id'],
                                                    selectedBreakType,
                                                  );
                                                }
                                              }),
                                          icon: const Icon(
                                            Icons.free_breakfast,
                                            size: 16,
                                          ),
                                          label: const Text('Start Break'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.orange,
                                            foregroundColor: Colors.white,
                                          ),
                                        ),
                                      if (canEndBreak)
                                        ElevatedButton.icon(
                                          onPressed: () => _endBreak(
                                            employee['_id'],
                                            ((employee['firstName'] != null &&
                                                    employee['lastName'] !=
                                                        null)
                                                ? '${employee['firstName']} ${employee['lastName']}'
                                                : employee['email'] ??
                                                      'Unknown User'),
                                          ),
                                          icon: const Icon(
                                            Icons.stop_circle,
                                            size: 16,
                                          ),
                                          label: const Text('End Break'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.red,
                                            foregroundColor: Colors.white,
                                          ),
                                        ),
                                      if (!isCheckedIn)
                                        Text(
                                          'Employee must check in first',
                                          style: TextStyle(
                                            color: colorScheme.onSurface
                                                .withValues(alpha: 0.5),
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
