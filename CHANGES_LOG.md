# SNS Clocked In - Changes Log

This document tracks ongoing changes and updates being applied to the codebase. This log is updated incrementally as changes are made.

---

## Change Log Format

Each entry includes:
- **Date**: When the change was documented
- **Component**: What part of the system was changed
- **Description**: What was changed and why
- **Files Modified/Created**: List of affected files
- **Status**: In Progress / Complete / Pending Review

---

## Recent Changes

### [Date: TBD] - Reusable UI Components & Admin Dashboard Refactoring

**Status:** Complete  
**Component:** UI Components & Admin Dashboard

**Description:**
Created reusable UI components to improve code consistency and maintainability, then refactored the admin dashboard to use these components:
- Created `AppScreenScaffold` for consistent screen layouts
- Created `AppCard` for consistent card styling
- Created `SectionHeader` for consistent section titles
- Refactored admin dashboard to use new components
- Reduced code duplication and improved maintainability

**Files Created/Modified:**

#### 1. `lib/core/ui/app_screen_scaffold.dart` (85 lines) - NEW
**Purpose:** Reusable screen scaffold with consistent styling

**Key Features:**
- Consistent background color (`AppColors.background`)
- SafeArea handling
- Optional AppBar with title and actions
- Default horizontal padding (24px)
- Support for floatingActionButton and bottomNavigationBar
- Optional back button with automatic navigation

**API:**
```dart
AppScreenScaffold(
  title: 'Dashboard',           // Optional: shows AppBar
  showBack: true,                // Optional: shows back button
  actions: [IconButton(...)],    // Optional: action buttons
  floatingActionButton: FAB(),   // Optional: FAB
  child: YourContent(),
)
```

**Implementation Details:**
- AppBar only shown if title, showBack, or actions are provided
- Back button uses `context.pop()` for navigation
- AppBar uses design system typography for title
- Background color matches design system

#### 2. `lib/core/ui/app_card.dart` (75 lines) - NEW
**Purpose:** Reusable card widget with consistent styling

**Key Features:**
- White background (`AppColors.surface`)
- Rounded corners (`AppRadius.mediumAll`)
- Soft shadow (0.06 alpha, 8px blur, 2px offset)
- Optional tap handling with InkWell ripple effect
- Optional width constraint
- Flexible padding and margin

**API:**
```dart
AppCard(
  padding: AppSpacing.lgAll,    // Optional: internal padding
  margin: EdgeInsets.all(8),      // Optional: external margin
  width: 200,                    // Optional: width constraint
  onTap: () {},                  // Optional: enables tap ripple
  child: YourContent(),
)
```

**Implementation Details:**
- InkWell only wraps card if `onTap` is provided
- Shadow uses consistent design system values
- Border radius matches design system medium radius (12dp)

#### 3. `lib/core/ui/section_header.dart` (29 lines) - NEW
**Purpose:** Reusable section header widget

**Key Features:**
- Consistent typography (`AppTypography.lightTextTheme.labelLarge`)
- Consistent spacing (bottom padding: `AppSpacing.md`)
- Simple API for section titles

**API:**
```dart
SectionHeader('Actions')
```

**Implementation Details:**
- Uses design system labelLarge typography
- Bottom padding of 16dp (medium spacing)

#### 4. `lib/features/admin/dashboard/presentation/admin_dashboard_screen.dart` (Updated: 470 → 458 lines)
**Refactoring Changes:**
- Replaced custom `Scaffold` with `AppScreenScaffold`
- Replaced custom `Container` cards with `AppCard` components
- Replaced custom section titles with `SectionHeader` component
- Removed duplicate card decoration code
- Improved code consistency and maintainability

**Before:**
```dart
Scaffold(
  backgroundColor: AppColors.background,
  body: SafeArea(
    child: SingleChildScrollView(
      padding: AppSpacing.lgAll,
      ...
    ),
  ),
)
Container(
  decoration: BoxDecoration(
    color: AppColors.surface,
    borderRadius: AppRadius.mediumAll,
    boxShadow: [...],
  ),
  ...
)
```

**After:**
```dart
AppScreenScaffold(
  floatingActionButton: kDebugMode ? _buildDebugFAB(context) : null,
  child: SingleChildScrollView(...),
)
AppCard(
  padding: AppSpacing.lgAll,
  child: ...
)
```

**Additional Changes:**
- Debug FAB changed to `FloatingActionButton.small` with bottom padding (72px)
- Uses `SectionHeader` for "Actions" section title
- All cards now use `AppCard` for consistency

**Benefits:**
1. **Code Reusability:** Components can be used across all screens
2. **Consistency:** All screens will have consistent styling
3. **Maintainability:** Design changes only need to be made in one place
4. **Reduced Code:** Less duplicate code in individual screens
5. **Type Safety:** Components enforce design system usage

---

### [Date: TBD] - Enhanced Navigation with "More" Pattern

**Status:** Complete  
**Component:** Navigation System Enhancement

**Description:**
Enhanced the role-based navigation system with a "More" button pattern to improve UX and scalability:
- Created reusable `MoreBottomNav` component with bottom sheet functionality
- Split navigation items into main (4 items) and "More" (additional items) for employee/admin roles
- Enhanced deep-linking support with route prefix matching for sub-routes
- Updated both `EmployeeShell` and `AdminShell` to use the new pattern
- Maintained backward compatibility with existing navigation item getters

**Files Created/Modified:**

#### 1. `lib/core/navigation/more_bottom_nav.dart` (153 lines) - NEW
**Purpose:** Reusable bottom navigation component with "More" functionality

**Key Features:**
- Custom navigation bar with 4 main destinations + "More" button
- Modal bottom sheet for additional navigation items
- Label behavior: `onlyShowSelected` to prevent text wrapping
- Drag handle and proper sheet styling
- Design system integration throughout

**Components:**
- `MoreBottomNav` - Main navigation bar widget
- `_MoreBottomSheet` - Private bottom sheet widget for "More" items

**UI Details:**
- Bottom sheet with rounded top corners (large radius)
- Drag handle indicator
- "More" title header
- List items with icons and labels
- Safe area handling

#### 2. `lib/core/navigation/nav_config.dart` (Updated: 131 → 151 lines)
**Changes:**
- Split employee navigation: `employeeMainNavItems` (4) + `employeeMoreNavItems` (1)
- Split admin navigation: `adminMainNavItems` (4) + `adminMoreNavItems` (2)
- Added backward-compatible getters: `employeeNavItems` and `adminNavItems`
- Maintains existing `superAdminNavItems` structure (unchanged)

**Navigation Split:**

**Employee:**
- Main: Dashboard, Attendance, Leave, Profile
- More: Notifications

**Admin:**
- Main: Dashboard, Attendance, Leave, Employees
- More: Reports, Settings

#### 3. `lib/core/navigation/employee_shell.dart` (Updated: 44 → 56 lines)
**Changes:**
- Replaced standard `NavigationBar` with `MoreBottomNav` component
- Enhanced route detection with prefix matching for deep-linking
- Handles sub-routes correctly (e.g., `/e/leave/apply` highlights Leave tab)
- Highlights "More" button when in a "More" route
- Uses split navigation items (`employeeMainNavItems` + `employeeMoreNavItems`)

**Route Detection Enhancement:**
```dart
// Now handles sub-routes correctly
final selectedIndex = mainNavItems.indexWhere(
  (item) => currentRoute == item.route || 
            currentRoute.startsWith('${item.route}/'),
);
```

#### 4. `lib/core/navigation/admin_shell.dart` (Updated: 44 → 56 lines)
**Changes:**
- Identical updates to `EmployeeShell`
- Uses `MoreBottomNav` component
- Enhanced deep-linking support
- Uses split navigation items (`adminMainNavItems` + `adminMoreNavItems`)

**Key Benefits:**
1. **Better UX:** Only 4 main items in bottom nav (optimal for thumb reach zone)
2. **Scalability:** Can add more navigation items without cluttering bottom nav
3. **Deep-linking:** Correctly highlights active tab even for nested routes
4. **Consistency:** Same pattern used for both Employee and Admin roles
5. **Backward Compatible:** Existing code using `employeeNavItems`/`adminNavItems` still works

**Technical Details:**
- Bottom sheet opens when "More" button (5th position) is tapped
- Sheet auto-closes on item selection
- Current route detection works for both exact matches and prefix matches
- "More" button highlighted when user is in any "More" route

---

### [Date: TBD] - Admin Dashboard Implementation

**Status:** Complete  
**Component:** Admin Dashboard Screen

**Description:**
Full admin dashboard screen implementation with:
- Mock data placeholders for admin metrics
- Summary cards grid (Employees, On Leave, Pending Approvals, Attendance)
- Action cards for quick navigation
- Debug menu integration (debug mode only)
- Role switching functionality in debug menu
- Entrance animations for UI elements
- Professional card-based layout with design system tokens
- **Refactored to use reusable UI components** (see "Reusable UI Components" entry)

**Files Created/Modified:**
- `lib/features/admin/dashboard/presentation/admin_dashboard_screen.dart` (458 lines, reduced from 470)
  - Complete dashboard implementation
  - Mock data: admin name, company name, employee count, leave count, approvals, attendance percentage
  - Header card with welcome message and role chips
  - Summary grid with 4 metric cards
  - Action section with primary "My Attendance" button and secondary action cards
  - Overview placeholder section
  - Debug FAB (small floating action button) in debug mode
  - Debug menu sheet with role switching capabilities
  - **Uses `AppScreenScaffold`, `AppCard`, and `SectionHeader` components**

**Key Features:**
- Uses `Entrance` widget for fade + slide animations
- Responsive grid layout using `LayoutBuilder` and `Wrap`
- Design system integration (`AppColors`, `AppTypography`, `AppSpacing`, `AppRadius`)
- Debug menu allows switching between Employee, Admin, and Super Admin roles
- Role switching ensures authentication state is maintained
- **Reusable components for consistent styling**

**Navigation:**
- Primary action: "My Attendance" → `/a/attendance`
- Secondary actions:
  - Employees → `/a/employees`
  - Leave → `/a/leave` (updated from `/a/attendance`)
  - Reports → `/a/reports`

**Technical Details:**
- StatefulWidget for potential future state management
- Uses `context.go()` for navigation
- Debug menu uses `AppState` for role management
- SnackBar feedback on role switch
- Automatic navigation to `/home` after role switch (router handles role-based redirect)
- **Refactored to use `AppScreenScaffold` instead of custom Scaffold**
- **All cards use `AppCard` component for consistency**
- **Section headers use `SectionHeader` component**

---

### [Date: TBD] - Role-Based Navigation System

**Status:** Complete  
**Component:** Navigation Architecture & Role-Based Routing

**Description:**
Implemented a comprehensive role-based navigation system with dedicated shell widgets and navigation configuration for each user role:
- Role enum with route prefix and default route functionality
- Navigation configuration system (NavConfig) with role-specific navigation items
- Shell widgets for each role (EmployeeShell, AdminShell, SuperAdminShell)
- Role-based route prefix enforcement in router
- Different navigation patterns per role (bottom nav for employee/admin, drawer for super admin)

**Files Created/Modified:**

#### 1. `lib/core/role/role.dart` (60 lines)
**Purpose:** Role enum with routing utilities

**Key Features:**
- Three roles: `superAdmin`, `admin`, `employee`
- `fromString()` - Parse role from string (defaults to employee)
- `defaultRouteForRole()` - Get default dashboard route per role:
  - Super Admin: `/sa/dashboard`
  - Admin: `/a/dashboard`
  - Employee: `/e/dashboard`
- `routePrefix` getter - Get route prefix per role:
  - Super Admin: `/sa`
  - Admin: `/a`
  - Employee: `/e`

**Implementation:**
```dart
enum Role {
  superAdmin('super_admin'),
  admin('admin'),
  employee('employee');
  
  static String defaultRouteForRole(Role role) { ... }
  String get routePrefix { ... }
}
```

#### 2. `lib/core/navigation/nav_config.dart` (151 lines)
**Purpose:** Centralized navigation configuration per role with split main/more items

**Key Features:**
- `NavItem` class - Navigation item model (label, icon, route)
- `NavConfig` class - Static navigation item lists per role
- Split navigation items: `mainNavItems` and `moreNavItems` for employee/admin
- Backward compatibility: `employeeNavItems` and `adminNavItems` getters
- `navItemsForRole()` - Helper to get nav items for any role

**Navigation Structure:**

**Employee:**
- **Main Nav Items (4):**
  - Dashboard (`/e/dashboard`)
  - Attendance (`/e/attendance`)
  - Leave (`/e/leave`)
  - Profile (`/e/profile`)
- **More Items (1):**
  - Notifications (`/e/notifications`)

**Admin:**
- **Main Nav Items (4):**
  - Dashboard (`/a/dashboard`)
  - Attendance (`/a/attendance`)
  - Leave (`/a/leave`)
  - Employees (`/a/employees`)
- **More Items (2):**
  - Reports (`/a/reports`)
  - Settings (`/a/settings`)

**Backward Compatibility:**
- `employeeNavItems` getter combines main + more items (5 total)
- `adminNavItems` getter combines main + more items (6 total)
- Maintains compatibility with code expecting single list

**Super Admin (5 items):**
- Dashboard (`/sa/dashboard`)
- Companies (`/sa/companies`)
- Users (`/sa/users`)
- System (`/sa/system`)
- Reports (`/sa/reports`)

#### 3. `lib/core/navigation/more_bottom_nav.dart` (153 lines)
**Purpose:** Reusable bottom navigation component with "More" functionality

**Features:**
- Custom bottom navigation with "More" button pattern
- Main destinations (4 items) shown in bottom nav bar
- Additional items accessible via "More" bottom sheet
- Label behavior: `onlyShowSelected` to prevent text wrapping
- Bottom sheet with drag handle and proper styling
- Design system integration (colors, spacing, typography, radius)

**Implementation:**
- `MoreBottomNav` widget - Main navigation bar component
- `_MoreBottomSheet` widget - Bottom sheet for additional items
- Handles main destination taps and "More" button tap
- Opens modal bottom sheet when "More" is selected
- Auto-closes sheet on item selection

**UI Details:**
- Bottom sheet: Rounded top corners (large radius)
- Drag handle: Visual indicator for sheet dragging
- Sheet title: "More" heading
- List items: Icon + label layout
- Safe area handling for notches

#### 4. `lib/core/navigation/employee_shell.dart` (56 lines)
**Purpose:** Shell widget for employee role with enhanced bottom navigation

**Features:**
- Uses `MoreBottomNav` component instead of standard `NavigationBar`
- Split navigation: 4 main items + "More" sheet items
- Enhanced deep-linking support with route prefix matching
- Handles sub-routes correctly (e.g., `/e/leave/apply` highlights Leave tab)
- Highlights "More" button when in a "More" route
- Uses `NavConfig.employeeMainNavItems` and `NavConfig.employeeMoreNavItems`

**Route Detection:**
```dart
// Handles deep-linking correctly
final selectedIndex = mainNavItems.indexWhere(
  (item) => currentRoute == item.route || 
            currentRoute.startsWith('${item.route}/'),
);
```

**Navigation Items:**
- **Main (4 items):** Dashboard, Attendance, Leave, Profile
- **More (1 item):** Notifications

#### 5. `lib/core/navigation/admin_shell.dart` (56 lines)
**Purpose:** Shell widget for admin role with enhanced bottom navigation

**Features:**
- Identical structure to `EmployeeShell`
- Uses `MoreBottomNav` component
- Split navigation: 4 main items + "More" sheet items
- Enhanced deep-linking support
- Uses `NavConfig.adminMainNavItems` and `NavConfig.adminMoreNavItems`

**Navigation Items:**
- **Main (4 items):** Dashboard, Attendance, Leave, Employees
- **More (2 items):** Reports, Settings

#### 6. `lib/core/navigation/super_admin_shell.dart` (90 lines)
**Purpose:** Shell widget for super admin role with drawer navigation

**Features:**
- Drawer navigation (side menu) instead of bottom nav
- AppBar with menu icon to open drawer
- Drawer header with "Super Admin" branding
- Uses `NavConfig.superAdminNavItems` (5 items)
- Highlights selected route in drawer
- Primary color styling for drawer header

**UI Details:**
- Drawer header: Primary color background with white text
- ListTile items with icon and label
- Selected item highlighted with primary color
- Auto-closes drawer on navigation

#### 7. `lib/app/router/app_router.dart` (Modified)
**Changes:**
- Enhanced redirect logic with role-based route prefix enforcement
- Super admin redirects to `/unsupported` screen (not yet implemented)
- Employee and Admin routes enforce prefix matching
- Routes wrapped in appropriate shell widgets:
  - Employee routes → `EmployeeShell`
  - Admin routes → `AdminShell`
  - Super Admin routes → `SuperAdminShell` (when implemented)

**Route Prefix Enforcement:**
```dart
// Enforce prefix rule: user can only access routes matching their role prefix
if (location.startsWith(rolePrefix)) {
  return null; // Allow access
}
// Redirect to default route if prefix doesn't match
return defaultRoute;
```

**Key Routes:**
- `/e/*` - Employee routes (wrapped in EmployeeShell)
- `/a/*` - Admin routes (wrapped in AdminShell)
- `/sa/*` - Super Admin routes (wrapped in SuperAdminShell)
- `/home` - Redirects to role-specific default route
- `/unsupported` - Super admin placeholder screen

**Technical Details:**
- Router uses `appState.currentRole` for role detection
- Route guards prevent cross-role navigation
- Default routes redirect based on current role
- Debug route (`/debug`) accessible in all states (debug mode only)

**Architecture Benefits:**
1. **Separation of Concerns:** Each role has dedicated navigation structure
2. **Type Safety:** Role enum prevents invalid role values
3. **Centralized Config:** NavConfig makes it easy to update navigation items
4. **Consistent UX:** Each role has appropriate navigation pattern (bottom nav vs drawer)
5. **Security:** Router enforces role-based route access

**Navigation Patterns:**
- **Employee/Admin:** Enhanced bottom navigation with "More" pattern
  - 4 main items always visible in bottom nav bar
  - Additional items accessible via "More" bottom sheet
  - Prevents bottom nav from being cluttered
  - Better UX for apps with 5+ navigation items
  - Deep-linking support for sub-routes
  
- **Super Admin:** Drawer navigation
  - More items can be accommodated
  - Better for complex admin interfaces
  - Drawer header provides branding space

**Benefits of "More" Pattern:**
1. **Cleaner UI:** Only 4 main items in bottom nav (optimal for thumb reach)
2. **Scalability:** Can add more navigation items without cluttering bottom nav
3. **Better UX:** Most-used items remain accessible, less-used items in "More"
4. **Deep-linking:** Correctly highlights active tab even for sub-routes
5. **Consistent:** Same pattern used for both Employee and Admin roles

---

## Pending Documentation

_This section will be updated as new changes are identified and documented._

---

## Notes

- All changes should maintain existing architecture patterns
- Design system tokens should be used consistently
- Animations should respect reduced motion preferences
- Debug features should only be available in debug mode

