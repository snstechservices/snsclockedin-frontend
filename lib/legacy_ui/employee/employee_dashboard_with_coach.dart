import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'package:provider/provider.dart';
import 'package:sns_rooster/providers/auth_provider.dart';
import 'package:sns_rooster/providers/feature_provider.dart';
import 'package:sns_rooster/tutorial/tutorial_service.dart';
import 'package:sns_rooster/services/global_notification_service.dart';
import 'employee_dashboard_screen.dart';
import 'dart:ui' as ui;

class EmployeeDashboardWithCoachMarks extends StatefulWidget {
  const EmployeeDashboardWithCoachMarks({super.key});

  static const String seenKey = 'employee_dashboard_coach_seen_v1';

  static final GlobalKey timesheetCardKey = GlobalKey(
    debugLabel: 'empTimesheet',
  );
  static final GlobalKey profileCardKey = GlobalKey(debugLabel: 'empProfile');
  static final GlobalKey eventsCardKey = GlobalKey(debugLabel: 'empEvents');
  static final GlobalKey companyInfoCardKey = GlobalKey(
    debugLabel: 'empCompanyInfo',
  );
  // New group/card keys from overview tile - only create when needed
  static GlobalKey? get overviewGroupKey => _overviewGroupKey;
  static GlobalKey? get weeklyAttendanceKey => _weeklyAttendanceKey;
  static GlobalKey? get breakStatsKey => _breakStatsKey;
  static GlobalKey? get workHoursKey => _workHoursKey;
  static GlobalKey? get quickStatsKey => _quickStatsKey;

  // Private static keys - only created when actually used
  static GlobalKey? _overviewGroupKey;
  static GlobalKey? _weeklyAttendanceKey;
  static GlobalKey? _breakStatsKey;
  static GlobalKey? _workHoursKey;
  static GlobalKey? _quickStatsKey;

  // Initialize keys only when needed
  static void _initializeOverviewKeys() {
    _overviewGroupKey ??= GlobalKey(debugLabel: 'empOverview');
    _weeklyAttendanceKey ??= GlobalKey(debugLabel: 'empWeeklyAttendance');
    _breakStatsKey ??= GlobalKey(debugLabel: 'empBreakStats');
    _workHoursKey ??= GlobalKey(debugLabel: 'empWorkHours');
    _quickStatsKey ??= GlobalKey(debugLabel: 'empQuickStats');
  }

  // Public method to initialize overview keys when overview tile is used
  static void initializeOverviewKeys() {
    _initializeOverviewKeys();
  }

  static final GlobalKey quickCheckKey = GlobalKey(debugLabel: 'empQuickCheck');
  static final GlobalKey leaveQuickKey = GlobalKey(debugLabel: 'empLeaveQuick');
  static final GlobalKey notifBellKey = GlobalKey(debugLabel: 'empNotifBell');

  @override
  State<EmployeeDashboardWithCoachMarks> createState() =>
      _EmployeeDashboardWithCoachMarksState();
}

class _EmployeeDashboardWithCoachMarksState
    extends State<EmployeeDashboardWithCoachMarks> {
  TutorialCoachMark? _coach;
  bool _coachActive = false;

  @override
  void initState() {
    super.initState();
    // Add a delay to ensure the widget tree is fully built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _maybeShow();
      }
    });
  }

  Future<void> _maybeShow() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final auth = context.read<AuthProvider>();
      final String? userId = auth.user?['_id'] as String?;

      // Check if tutorial features are enabled (subscription check)
      final featureProvider = context.read<FeatureProvider>();
      if (!featureProvider.hasTutorialCenter &&
          !featureProvider.hasBasicTutorials) {
        // Tutorial features not enabled in subscription, don't show coaching
        return;
      }

      // user-scoped key so existing users who already saw it won't be re-prompted
      final key = TutorialService.userScopedKey(
        EmployeeDashboardWithCoachMarks.seenKey,
        userId,
      );

      final seen = prefs.getBool(key) ?? false;

      // Only show tutorial for new users (accounts created within last 7 days)
      if (!seen && mounted && userId != null) {
        final userCreatedAt = DateTime.tryParse(auth.user?['createdAt'] ?? '');
        final isNewUser =
            userCreatedAt != null &&
            DateTime.now().difference(userCreatedAt).inDays <= 7;

        if (isNewUser) {
          final ready = await _waitForTargets();
          if (!mounted) return;
          if (ready) {
            _show();
            await prefs.setBool(key, true);
          }
        }
      }
    } catch (e) {
      // 'Error in _maybeShow: $e');
    }
  }

  Future<bool> _waitForTargets() async {
    // Wait up to ~6s for widgets to lay out
    for (int i = 0; i < 40; i++) {
      try {
        final ok =
            (EmployeeDashboardWithCoachMarks.quickCheckKey.currentContext !=
                null) ||
            (EmployeeDashboardWithCoachMarks.leaveQuickKey.currentContext !=
                null) ||
            (EmployeeDashboardWithCoachMarks.timesheetCardKey.currentContext !=
                null) ||
            (EmployeeDashboardWithCoachMarks.profileCardKey.currentContext !=
                null) ||
            (EmployeeDashboardWithCoachMarks.eventsCardKey.currentContext !=
                null) ||
            (EmployeeDashboardWithCoachMarks
                    .companyInfoCardKey
                    .currentContext !=
                null) ||
            (EmployeeDashboardWithCoachMarks.notifBellKey.currentContext !=
                null);
        if (ok) return true;
      } catch (e) {
        // 'Error checking target contexts: $e');
        return false;
      }
      await Future.delayed(const Duration(milliseconds: 150));
    }
    return false;
  }

  Future<void> _show() async {
    final targets = <TargetFocus>[];
    if (EmployeeDashboardWithCoachMarks.quickCheckKey.currentContext != null) {
      targets.add(
        TargetFocus(
          identify: 'checkin',
          keyTarget: EmployeeDashboardWithCoachMarks.quickCheckKey,
          shape: ShapeLightFocus.RRect,
          radius: 28,
          contents: [
            TargetContent(
              align: ContentAlign.top,
              child: _tip(
                'Use Check In/Out here to start and end your day.',
                icon: Icons.login,
              ),
            ),
          ],
        ),
      );
    }
    if (EmployeeDashboardWithCoachMarks.leaveQuickKey.currentContext != null) {
      targets.add(
        TargetFocus(
          identify: 'leave',
          keyTarget: EmployeeDashboardWithCoachMarks.leaveQuickKey,
          shape: ShapeLightFocus.RRect,
          radius: 18,
          contents: [
            TargetContent(
              align: ContentAlign.bottom,
              child: _tip(
                'Apply for leave quickly from here.',
                icon: Icons.event_available,
              ),
            ),
          ],
        ),
      );
    }
    if (EmployeeDashboardWithCoachMarks.notifBellKey.currentContext != null) {
      targets.add(
        TargetFocus(
          identify: 'notifications',
          keyTarget: EmployeeDashboardWithCoachMarks.notifBellKey,
          shape: ShapeLightFocus.Circle,
          radius: 42,
          contents: [
            TargetContent(
              align: ContentAlign.bottom,
              child: _tip(
                'Stay informed about approvals and announcements.',
                icon: Icons.notifications_active,
              ),
            ),
          ],
        ),
      );
    }
    if (EmployeeDashboardWithCoachMarks.timesheetCardKey.currentContext !=
        null) {
      targets.add(
        TargetFocus(
          identify: 'timesheet',
          keyTarget: EmployeeDashboardWithCoachMarks.timesheetCardKey,
          shape: ShapeLightFocus.RRect,
          radius: 18,
          contents: [
            TargetContent(
              align: ContentAlign.top,
              child: _tip(
                'Timesheet: view and submit your working hours.',
                icon: Icons.access_time,
              ),
            ),
          ],
        ),
      );
    }
    if (EmployeeDashboardWithCoachMarks.profileCardKey.currentContext != null) {
      targets.add(
        TargetFocus(
          identify: 'profile',
          keyTarget: EmployeeDashboardWithCoachMarks.profileCardKey,
          shape: ShapeLightFocus.RRect,
          radius: 18,
          contents: [
            TargetContent(
              align: ContentAlign.top,
              child: _tip(
                'Profile: review and update your personal details.',
                icon: Icons.person,
              ),
            ),
          ],
        ),
      );
    }
    if (EmployeeDashboardWithCoachMarks.eventsCardKey.currentContext != null) {
      targets.add(
        TargetFocus(
          identify: 'events',
          keyTarget: EmployeeDashboardWithCoachMarks.eventsCardKey,
          shape: ShapeLightFocus.RRect,
          radius: 18,
          contents: [
            TargetContent(
              align: ContentAlign.top,
              child: _tip(
                'Events: check upcoming company events.',
                icon: Icons.event,
              ),
            ),
          ],
        ),
      );
    }
    if (EmployeeDashboardWithCoachMarks.companyInfoCardKey.currentContext !=
        null) {
      // Overview groups and cards
      if (EmployeeDashboardWithCoachMarks.overviewGroupKey?.currentContext !=
          null) {
        targets.add(
          TargetFocus(
            identify: 'overview_group',
            keyTarget: EmployeeDashboardWithCoachMarks.overviewGroupKey!,
            shape: ShapeLightFocus.RRect,
            radius: 18,
            contents: [
              TargetContent(
                align: ContentAlign.top,
                child: _tip(
                  'Attendance & Work Overview: weekly attendance, break stats, work hours, and quick stats in one place.',
                ),
              ),
            ],
          ),
        );
      }
      if (EmployeeDashboardWithCoachMarks.weeklyAttendanceKey?.currentContext !=
          null) {
        targets.add(
          TargetFocus(
            identify: 'weekly_attendance',
            keyTarget: EmployeeDashboardWithCoachMarks.weeklyAttendanceKey!,
            shape: ShapeLightFocus.RRect,
            radius: 16,
            contents: [
              TargetContent(
                align: ContentAlign.bottom,
                child: _tip(
                  'Weekly Attendance: present/leave/absent per day with check-in time or worked hours.',
                ),
              ),
            ],
          ),
        );
      }
      if (EmployeeDashboardWithCoachMarks.breakStatsKey?.currentContext !=
          null) {
        targets.add(
          TargetFocus(
            identify: 'break_stats',
            keyTarget: EmployeeDashboardWithCoachMarks.breakStatsKey!,
            shape: ShapeLightFocus.RRect,
            radius: 16,
            contents: [
              TargetContent(
                align: ContentAlign.bottom,
                child: _tip(
                  'Break Statistics: total breaks and total break time with change vs yesterday.',
                ),
              ),
            ],
          ),
        );
      }
      if (EmployeeDashboardWithCoachMarks.workHoursKey?.currentContext !=
          null) {
        targets.add(
          TargetFocus(
            identify: 'work_hours',
            keyTarget: EmployeeDashboardWithCoachMarks.workHoursKey!,
            shape: ShapeLightFocus.RRect,
            radius: 24,
            contents: [
              TargetContent(
                align: ContentAlign.bottom,
                child: _tip(
                  'Work Hours: total and average hours over the last 7 days with trend vs previous week.',
                ),
              ),
            ],
          ),
        );
      }
      if (EmployeeDashboardWithCoachMarks.quickStatsKey?.currentContext !=
          null) {
        targets.add(
          TargetFocus(
            identify: 'quick_stats',
            keyTarget: EmployeeDashboardWithCoachMarks.quickStatsKey!,
            shape: ShapeLightFocus.RRect,
            radius: 16,
            contents: [
              TargetContent(
                align: ContentAlign.top,
                child: _tip(
                  'Quick Stats: attendance streak and punctuality score at a glance.',
                ),
              ),
            ],
          ),
        );
      }
      targets.add(
        TargetFocus(
          identify: 'company_info',
          keyTarget: EmployeeDashboardWithCoachMarks.companyInfoCardKey,
          shape: ShapeLightFocus.RRect,
          radius: 18,
          contents: [
            TargetContent(
              align: ContentAlign.top,
              child: _tip(
                'Company Info: view organization details and contacts.',
                icon: Icons.apartment,
              ),
            ),
          ],
        ),
      );
    }
    if (targets.isEmpty) return;
    // Replace multi-target session with sequential steps to avoid race conditions
    await _showStepAtIndex(targets, 0);
  }

  Future<void> _showStepAtIndex(List<TargetFocus> steps, int index) async {
    if (index >= steps.length) {
      if (mounted) setState(() => _coachActive = false);
      return;
    }
    if (mounted) setState(() => _coachActive = true);
    final current = steps[index];
    await _scrollTo(current);
    try {
      await WidgetsBinding.instance.endOfFrame;
    } catch (_) {}
    await Future.delayed(const Duration(milliseconds: 120));

    _coach = TutorialCoachMark(
      targets: [current],
      colorShadow: Colors.black.withValues(alpha: 0.6),
      opacityShadow: 0.35,
      imageFilter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
      textSkip: 'SKIP',
      paddingFocus: 8,
      useSafeArea: true,
      hideSkip: false,
      onClickTarget: (_) => _coach?.next(),
      onClickOverlay: (_) => _coach?.next(),
      onFinish: () async {
        await _showStepAtIndex(steps, index + 1);
      },
    );
    _coach!.show(context: context);
  }

  Future<void> _scrollTo(TargetFocus? t) async {
    final key = t?.keyTarget;
    final ctx = key?.currentContext;
    if (ctx != null) {
      try {
        // Center some deeper cards a bit lower for stability
        double alignment = 0.1;
        if (identical(key, EmployeeDashboardWithCoachMarks.workHoursKey) ||
            identical(key, EmployeeDashboardWithCoachMarks.breakStatsKey) ||
            identical(key, EmployeeDashboardWithCoachMarks.quickStatsKey)) {
          alignment = 0.25;
        }

        await Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 800),
          alignment: alignment,
          curve: Curves.easeInOutCubic,
        );
        // Wait for layout to settle
        try {
          await WidgetsBinding.instance.endOfFrame;
        } catch (_) {}
        // Extra wait for work-hours which is farther down
        final extra =
            identical(key, EmployeeDashboardWithCoachMarks.workHoursKey)
            ? 160
            : 60;
        await Future.delayed(Duration(milliseconds: extra));
      } catch (_) {}
    }
  }

  Widget _tip(String text, {IconData? icon, Color? color}) {
    return Material(
      color: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 280),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8)],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon ?? Icons.info_outline,
              color: color ?? Colors.blue,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 14,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
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
    return Stack(
      children: [
        const EmployeeDashboardScreen(suppressProfilePrompt: true),
        if (!_coachActive)
          Positioned(
            right: 16,
            bottom: 16,
            child: GestureDetector(
              onLongPress: () async {
                final prefs = await SharedPreferences.getInstance();
                final auth = context.read<AuthProvider>();
                final String? userId = auth.user?['_id'] as String?;

                // Reset user-scoped tutorial flag
                final key = TutorialService.userScopedKey(
                  EmployeeDashboardWithCoachMarks.seenKey,
                  userId,
                );
                await prefs.remove(key);

                if (mounted) {
                  GlobalNotificationService().showInfo(
                    'Employee tutorial flag reset',
                  );
                }
              },
              child: FloatingActionButton.small(
                heroTag: 'employee_tutorial_btn',
                onPressed: _show,
                tooltip: 'Show tutorial',
                child: const Icon(Icons.help_outline),
              ),
            ),
          ),
        // QA buttons removed; use FAB and long-press to reset
      ],
    );
  }
}
