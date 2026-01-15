import 'package:flutter/material.dart';

// Public GlobalKeys used by the admin dashboard and the coach-marks wrapper.
// Attach these keys to the real widgets so the tutorial can highlight them.
final GlobalKey adminMenuKey = GlobalKey(debugLabel: 'adminMenu');
final GlobalKey employeeQuickActionKey = GlobalKey(
  debugLabel: 'employeeQuickAction',
);
final GlobalKey todaysAttendanceCardKey = GlobalKey(
  debugLabel: 'todaysAttendance',
);
final GlobalKey leaveQuickActionKey = GlobalKey(debugLabel: 'leaveQuickAction');
final GlobalKey notificationsBellKey = GlobalKey(
  debugLabel: 'notificationsBell',
);

// Top stat cards on dashboard
final GlobalKey topTotalEmployeesKey = GlobalKey(debugLabel: 'topTotal');
final GlobalKey topPresentKey = GlobalKey(debugLabel: 'topPresent');
final GlobalKey topOnLeaveKey = GlobalKey(debugLabel: 'topOnLeave');
final GlobalKey topAbsentKey = GlobalKey(debugLabel: 'topAbsent');
final GlobalKey topPendingKey = GlobalKey(debugLabel: 'topPending');
