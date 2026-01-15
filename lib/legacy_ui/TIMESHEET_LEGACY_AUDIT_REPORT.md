# Legacy Timesheet Implementation Audit Report
**Flutter App - SNS Rooster**  
**Date:** January 7, 2026

---

## A. SCREENS

### Employee Timesheet Screen

**File Path:** `lib/screens/timesheet/timesheet_screen.dart`

**Widget Class:** `TimesheetScreen` (StatefulWidget)

**Route Name:** `/timesheet`

**Navigation Access:**
- Employee drawer → "Timesheet" menu item
- Only visible for non-admin users

**What It Shows:**
- **Date Range Selector:** Today / This Week / This Month / Custom date range
- **Summary Statistics Card:**
  - Total Records count
  - Approved count
  - Completed (checked out) count
  - Clocked In count
  - Pending (awaiting approval) count
  - Rejected count
  - Expandable/collapsible summary section
  - Status legend with color coding

- **Attendance Records List:**
  - Grouped by selected date range
  - Each record shows:
    - Clock-in and clock-out times (formatted with timezone awareness)
    - Work duration (hours and minutes)
    - Approval status with colored badge
    - Status icon (check, clock, X, etc.)

**Data Loading:**
- Fetches user's own attendance records using `AttendanceProvider`
- Uses date range filtering (start and end dates)
- Implements cache-first pattern with 1-minute TTL
- Falls back to cached data on network errors
- Includes automatic refresh on network reconnection

---

### Admin Timesheet Screen

**File Path:** Not found in workspace

**Route Name:** `/admin_timesheet`

**Status:** Route registered in navigation but screen not found in scanned files
- Referenced in drawer and navigation config
- Likely in a subdirectory or separate module not scanned

**Expected Functionality (inferred):**
- List of all employees' timesheets
- Pending approval view
- Approved view
- Ability to approve/reject individual timesheets
- Bulk approval actions

---

### Timesheet Approval Screen

**File Path:** Not found in workspace

**Route Name:** `/timesheet_approval`

**Status:** Route mentioned in audit but implementation not found

---

## B. DATA MODELS

### Attendance Record Structure

**Source:** Responses from `/attendance/timesheet`, `/attendance/status` endpoints

**Fields Present:**

```json
{
  "_id": "ObjectId (MongoDB ID)",
  "userId": "String (employee ID)",
  "companyId": "String (company ID)",
  "date": "ISO8601 String (YYYY-MM-DDTHH:mm:ss.sssZ)",
  "checkInTime": "ISO8601 String | null",
  "checkOutTime": "ISO8601 String | null",
  "status": "String (pending|approved|rejected|present|absent|clocked_in|clocked_out|on_break|not_clocked_in)",
  "breaks": [
    {
      "startTime": "ISO8601 String",
      "endTime": "ISO8601 String | null",
      "duration": "Integer (minutes)",
      "breakType": "String"
    }
  ],
  "totalBreakTime": "Integer (minutes)",
  "approvalStatus": "String (pending|approved|rejected)",
  "adminComment": "String | null",
  "approvedBy": "String (admin user ID) | null",
  "approvalDate": "ISO8601 String | null",
  "rejectionReason": "String | null",
  "notes": "String | null",
  "createdAt": "ISO8601 String",
  "updatedAt": "ISO8601 String"
}
```

**Status Values:**
- **Approval Status:** `pending`, `approved`, `rejected`
- **Clock Status:** `clocked_in`, `clocked_out`, `on_break`, `not_clocked_in`
- **Legacy Status:** `present`, `absent` (for backward compatibility)

### Computed Fields (UI Layer)

```dart
// Calculated in TimesheetScreen
bool completed = checkOutTime != null  // User has checked out
bool clocked_in = checkInTime != null && checkOutTime == null  // Working now
Duration totalDuration = checkOutTime - checkInTime  // Work duration
```

### Break Information

**Structure:**
```json
{
  "breakType": "String (Tea Break, Lunch, etc.)",
  "startTime": "ISO8601 String",
  "endTime": "ISO8601 String | null",
  "duration": "Integer (minutes)"
}
```

**Break Types Enum:**
- Fetched dynamically from `/attendance/break-types` endpoint
- Cached for 24 hours

---

## C. API CALLS & ENDPOINTS

### Endpoints Summary

| Method | Endpoint | Purpose | Cache TTL |
|--------|----------|---------|-----------|
| GET | `/attendance/timesheet` | Get attendance history with date range | 1 min |
| GET | `/attendance/status/{userId}` | Get today's clock status | 1 min |
| GET | `/attendance/summary/{userId}` | Get attendance summary | 5 min |
| GET | `/attendance/break-types` | Get available break types | 24 hr |
| POST | `/attendance/check-in` | Clock in | On-demand |
| PATCH/POST | `/attendance/check-out` | Clock out | On-demand |
| POST | `/attendance/start-break` | Start break | On-demand |
| PATCH/POST | `/attendance/end-break` | End break | On-demand |
| GET | `/attendance/pending` | Get pending timesheets (admin) | 1 min |
| GET | `/attendance/approved` | Get approved timesheets (admin) | 1 min |
| PUT | `/attendance/{id}/approve` | Approve timesheet (admin) | On-demand |
| PUT | `/attendance/{id}/reject` | Reject timesheet (admin) | On-demand |
| POST | `/attendance/bulk-auto-approve` | Bulk approve timesheets (admin) | On-demand |

### Request/Response Examples

#### Get Attendance History (Timesheet View)

**Request:**
```http
GET /attendance/timesheet?start=2026-01-01T00:00:00Z&end=2026-01-31T23:59:59Z
```

**Response:**
```json
{
  "success": true,
  "data": {
    "attendance": [
      {
        "_id": "507f1f77bcf86cd799439011",
        "userId": "user123",
        "date": "2026-01-07T00:00:00Z",
        "checkInTime": "2026-01-07T09:00:00Z",
        "checkOutTime": "2026-01-07T18:00:00Z",
        "status": "approved",
        "breaks": [
          {
            "breakType": "Lunch",
            "startTime": "2026-01-07T13:00:00Z",
            "endTime": "2026-01-07T14:00:00Z",
            "duration": 60
          }
        ],
        "totalBreakTime": 60,
        "approvalStatus": "approved",
        "adminComment": "Approved on time",
        "approvedBy": "admin123",
        "approvalDate": "2026-01-07T19:00:00Z"
      }
    ]
  }
}
```

#### Get Today's Status

**Request:**
```http
GET /attendance/status/user123
```

**Response:**
```json
{
  "success": true,
  "data": {
    "_id": "507f...",
    "userId": "user123",
    "date": "2026-01-07T00:00:00Z",
    "checkInTime": "2026-01-07T09:15:00Z",
    "checkOutTime": null,
    "status": "clocked_in",
    "breaks": []
  }
}
```

#### Check In (Clock In)

**Request:**
```http
POST /attendance/check-in
Content-Type: application/json

{
  "companyId": "company123",
  "timestamp": "2026-01-07T09:00:00Z",
  "latitude": 37.7749,
  "longitude": -122.4194,
  "location": "Office",
  "notes": "Optional note"
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "_id": "507f...",
    "userId": "user123",
    "status": "clocked_in",
    "checkInTime": "2026-01-07T09:00:00Z",
    "checkOutTime": null
  }
}
```

#### Check Out (Clock Out)

**Request:**
```http
PATCH /attendance/check-out
Content-Type: application/json

{
  "companyId": "company123",
  "timestamp": "2026-01-07T18:00:00Z",
  "latitude": 37.7749,
  "longitude": -122.4194,
  "location": "Office",
  "notes": "Optional note"
}
```

#### Approve Timesheet (Admin)

**Request:**
```http
PUT /attendance/507f1f77bcf86cd799439011/approve
Content-Type: application/json

{
  "adminComment": "Approved - all looks good"
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "_id": "507f1f77bcf86cd799439011",
    "status": "approved",
    "approvalStatus": "approved",
    "approvedBy": "admin123",
    "approvalDate": "2026-01-07T19:00:00Z",
    "adminComment": "Approved - all looks good"
  }
}
```

#### Reject Timesheet (Admin)

**Request:**
```http
PUT /attendance/507f1f77bcf86cd799439011/reject
Content-Type: application/json

{
  "adminComment": "Clock out time missing - please verify"
}
```

### Caching & Offline Behavior

**Cache Strategy:** Cache-First with Background Refresh

**TTL Values:**
- **Today's Status:** 1 minute
- **Attendance History:** 1 minute
- **Attendance Summary:** 5 minutes
- **Break Types:** 24 hours
- **Current Attendance:** 1 minute

**Offline Behavior:**
- Loads immediately from cache (even if expired)
- Does not attempt network request
- Returns empty list if no cache available
- On reconnection: Auto-refreshes in background with 1-second delay

**Optimistic Updates:**
- Clock in/out: Updates UI immediately with predicted state
- Rolls back on server rejection with user-friendly error message
- Validates server response (presence of required fields)

---

## D. BUSINESS RULES

### Employee Edit Permissions

**When can an employee edit/submit?**
- Employees cannot directly edit records in the UI
- Records are auto-generated by clock-in/out actions
- Once clocked out, record awaits admin approval
- Status progression: `pending` → `approved`/`rejected`

**Cannot Clock In If:**
- Already clocked in today
- On approved leave
- Outside of working hours (may be enforced server-side)
- Company is on non-working day or holiday

**Cannot Clock Out If:**
- Not clocked in
- Already clocked out today

### Approval Workflow

**Employee Perspective:**
1. Employee clocks in/out via mobile app
2. Record created with status `pending`
3. Employee views record in timesheet with `pending` badge
4. Admin approves/rejects
5. Record status updates to `approved` or `rejected`

**Admin Perspective:**
1. Admin views pending timesheets in admin dashboard
2. Reviews each timesheet entry
3. Clicks "Approve" (with optional comment) or "Reject" (with reason)
4. Bulk approve action available for multiple records
5. Approved/rejected records moved to respective views

**Approval Status Values:**
- `pending` - Awaiting admin review
- `approved` - Admin approved the record
- `rejected` - Admin rejected with reason/comment

### Validation Rules

**Timesheet Data Validation:**

| Rule | Error Handling |
|------|-----------------|
| Cannot have gaps between clock-in and first break | Warning (not blocking) |
| Cannot have overlapping breaks | Server rejection |
| Break end time cannot be before start time | Server rejection |
| Total break time cannot exceed work duration | Server rejection |
| Clock out time must be after clock in time | Server rejection |
| Must have clock-in and clock-out for full record | Status: `clocked_in` (incomplete) |
| Date cannot be in future | Server rejection |
| Cannot check-in twice same day | Server rejection: "Already clocked in" |
| Cannot clock out without clocking in | Server rejection: "Not checked in" |
| Cannot start break without clocking in | Server rejection: "Not checked in" |

**Leave Conflict Handling:**
- If employee is on approved leave, clock-in rejected
- Error message: "Cannot check-in while on approved leave"
- Prevents timesheet entries during leave periods

### Role-Based Checks

| Action | Employee | Admin |
|--------|----------|-------|
| View own timesheet | ✓ | ✓ |
| View own pending records | ✓ | ✓ |
| View all employees' timesheets | ✗ | ✓ |
| View pending timesheets | Own only | All |
| Approve timesheet | ✗ | ✓ |
| Reject timesheet with reason | ✗ | ✓ |
| Bulk auto-approve | ✗ | ✓ |
| Add admin comment | ✗ | ✓ on approve/reject |

**Role Detection:**
```dart
final isAdmin = user?['role'] == 'admin';
```

### Break Rules

**Break Management:**
- Multiple breaks per day allowed
- Break type must be from predefined list
- Each break must have start and end time
- Break end time must be after start time
- Total break duration calculated automatically

**Current Behavior:**
- Break types fetched from `/attendance/break-types`
- Cached for 24 hours
- No validation on max breaks per day (server-side may enforce)
- No validation on break duration limits (server-side may enforce)

---

## E. UI PATTERNS

### List Layout

**Date Range Selection:**
- 4 buttons in responsive row: Today | This Week | This Month | Custom
- Selected button highlighted with primary color
- Custom range opens date picker dialog
- Filters records dynamically on selection

**Summary Statistics Card:**
- Collapsible/expandable section with expand/collapse button
- Grid layout showing 6 summary metrics:
  - Total Records
  - Approved (green)
  - Completed (blue)
  - Clocked In (blue)
  - Pending (orange)
  - Rejected (red)
- Status legend with color dots

**Records List:**
- Each record in transparent card with subtle border
- Responsive single or multi-column layout
- No pagination (loads all records for range at once)

### Record Item Layout

**Per-Record Card Structure:**

```
┌─────────────────────────────────────┐
│ [Status Icon]  Time Range  Duration │
│                [Status Badge]       │
│                                     │
│ Status icon (circle, border)        │
│ Left: Clock in/out times (formatted)│
│ Right: Duration in hours:minutes    │
│                                     │
│ Status shown as colored badge       │
│ (green=approved, orange=pending...)│
└─────────────────────────────────────┘
```

### Status Colours

**Color Scheme:**

| Status | Color | Icon |
|--------|-------|------|
| `approved` | Green (#4CAF50) | `Icons.check_circle` |
| `pending` | Orange (#FF9800) | `Icons.schedule` |
| `rejected` | Red (#F44336) | `Icons.cancel` |
| `clocked_in` | Blue (#2196F3) | `Icons.schedule` |
| `completed` | Blue (#2196F3) | `Icons.check_circle` |
| `present` | Gray | `Icons.check_circle_outline` |
| `absent` | Gray | `Icons.do_not_disturb` |

### Detail View

**No dedicated detail/modal view in current implementation.**

**Expansion Strategy:**
- Current: Click record to view → Not implemented
- Future: Could expand card in-place or navigate to detail screen
- Suggested detail fields:
  - Full timestamp (with timezone)
  - Location (if available)
  - Notes/comments
  - Break details (if any)
  - Admin comment (if approved/rejected)

### Filters (Current)

**Implemented:**
1. **Date Range:** Today, This Week, This Month, Custom
2. **Status Filter:** Calculated from records, shown in legend only (not as UI filter buttons)

**Not Implemented:**
- Filter by approval status (pending/approved/rejected)
- Filter by presence (clocked_in/completed/absent)
- Search by employee name (single-user only view)
- Sort options (displays in order from API)

---

## F. DEPENDENCIES & PROVIDERS

### State Management

**Primary Provider:** `AttendanceProvider`

**File Path:** `lib/providers/attendance_provider.dart` (812 lines)

**Key Methods:**
```dart
Future<void> fetchUserAttendance(
  String userId,
  {bool forceRefresh = false, DateTime? startDate, DateTime? endDate}
)

Future<void> fetchTodayStatus(String userId, {bool forceRefresh = false})

Future<void> fetchAttendanceSummary(String userId)

Future<void> checkIn({required DateTime timestamp, required String companyId})

Future<void> checkOut({required DateTime timestamp, required String companyId})

Future<void> startBreak({required DateTime timestamp, required String companyId})

Future<void> endBreak({required DateTime timestamp, required String companyId})

// Admin methods
Future<List<Map<String, dynamic>>> getPendingTimesheets()

Future<List<Map<String, dynamic>>> getApprovedTimesheets()

Future<void> approveTimesheet(String attendanceId, {String? adminComment})

Future<void> rejectTimesheet(String attendanceId, {required String reason})

Future<void> bulkAutoApproveTimesheets({DateTime? startDate, DateTime? endDate})
```

**Getters:**
```dart
List<Map<String, dynamic>> attendanceRecords  // Cached history
bool isLoading
String? error
Map<String, dynamic>? currentAttendance
Map<String, dynamic>? attendanceSummary
String? todayStatus  // 'clocked_in', 'clocked_out', 'on_break', etc.
Map<String, dynamic>? leaveInfo
bool isClockedIn
bool isOnBreak
bool hasCheckedInToday
```

### Repository Layer

**AttendanceRepository**

**File Path:** `lib/core/repository/attendance_repository.dart` (2200+ lines)

**Responsibilities:**
- Cache-first data fetching
- Optimistic updates for clock in/out/breaks
- Server validation with rollback on rejection
- Break type management
- Admin approval/rejection operations

**Key Cache Keys:**
```
attendance_status_{companyId}_{userId}
attendance_history_{companyId}_{userId}_{startDate}_{endDate}
attendance_summary_{companyId}_{userId}
current_attendance_{companyId}_{userId}
pending_timesheets_{companyId}
approved_timesheets_{companyId}
```

### Supporting Providers

**AuthProvider:** For user role and identity
**CompanyProvider:** For company context and timezone
**NotificationProvider:** For UI notifications (errors, success)

### Services Used

```dart
ConnectivityService()  // Network detection
HiveService()          // Local cache storage
ApiService()           // HTTP requests
SyncService()          // Background sync listener
```

---

## G. SUMMARY TABLE

| Aspect | Details |
|--------|---------|
| **Employee Screen** | `TimesheetScreen` → `/timesheet` |
| **Admin Screen** | `/admin_timesheet` (route exists, file not found) |
| **Primary Provider** | `AttendanceProvider` (812 lines) |
| **Repository** | `AttendanceRepository` (2200+ lines) |
| **Data Model** | Map<String, dynamic> (no typed model class) |
| **Cache TTL** | 1-5 min (history/status), 24h (break types) |
| **Approval Flow** | pending → approved/rejected |
| **Clock Actions** | Check-in, Check-out, Start/End Break |
| **Status Values** | pending, approved, rejected, clocked_in, clocked_out, on_break |
| **Date Filtering** | Today, Week, Month, Custom range |
| **Bulk Actions** | Bulk auto-approve (admin only) |
| **Offline Support** | Cache-first, no sync queue |

---

## H. ARCHITECTURAL NOTES

### Current Limitations

1. **No Typed Models:** Uses `Map<String, dynamic>` everywhere; no data classes or freezed models
2. **No Pagination:** Loads all records for date range at once
3. **No Detail View:** Records display only in list, no drill-down
4. **No Filtering UI:** Status and presence filters calculated but not exposed to user
5. **No Sorting Options:** Displays in order from API
6. **Admin Screens:** Referenced in routes but implementation files not found
7. **No Offline Queue:** Changes don't sync when offline (relies on cache)

### Recommended v2 Updates

1. Create typed `AttendanceRecord` data class with freezed
2. Implement detail view modal/screen
3. Add filter chips for status and presence
4. Add sorting options (date, duration, status)
5. Implement pagination for large datasets
6. Create dedicated admin timesheet management screen
7. Add search by date/employee name
8. Implement offline sync queue for approvals
9. Add export/download functionality
10. Add charts/analytics for attendance patterns

---

**End of Report**
