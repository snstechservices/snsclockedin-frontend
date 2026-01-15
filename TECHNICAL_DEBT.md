# Technical Debt Documentation

## Overview
This document identifies technical debt, architectural improvements, and missing features that should be addressed before Phase 2.

## Duplicated Code

### 1. Stat Card Building Logic
**Location**: Multiple screens have custom `_buildStatCard` methods
**Files**:
- `lib/features/admin/dashboard/presentation/admin_dashboard_screen.dart`
- `lib/features/employees/presentation/admin_employees_screen.dart`
- `lib/features/timesheet_admin/presentation/admin_timesheet_screen.dart`
- `lib/features/admin/presentation/reports_screen.dart`
- `lib/features/attendance/presentation/my_attendance_screen.dart`

**Recommendation**: All screens should use the `StatCard` component directly instead of custom implementations.

### 2. Error State Building
**Location**: Some screens have custom error state implementations
**Files**: Various screen files

**Recommendation**: Standardize on `ErrorState` component for all error displays.

### 3. Empty State Building
**Location**: Some screens have custom empty state implementations
**Files**: Various screen files

**Recommendation**: Standardize on `EmptyState` component for all empty displays.

## Architectural Improvements

### 1. Store Error Handling
**Current**: Stores use `e.toString()` for error messages
**Recommendation**: Use `ErrorMessageHelper.toUserFriendlyMessage()` for consistent error formatting

**Files to Update**:
- All store files in `lib/features/*/application/*_store.dart`

### 2. Context.select Optimization
**Current**: Many screens use `context.watch<T>()` which rebuilds on any store change
**Recommendation**: Use `context.select<T>((store) => store.specificValue)` for granular rebuilds

**Files to Review**:
- All screen files that watch stores

### 3. Const Constructors
**Current**: Many widgets don't use `const` constructors
**Recommendation**: Add `const` keywords where possible to improve performance

**Files to Review**:
- All widget files

## Missing Features from SNS-Rooster

### 1. Offline Support
**Status**: Not implemented
**Priority**: High
**Description**: App should work offline with local caching and sync when online

### 2. Push Notifications
**Status**: Not implemented
**Priority**: Medium
**Description**: Real-time push notifications for leave approvals, timesheet updates, etc.

### 3. Advanced Reporting
**Status**: Basic reports only
**Priority**: Medium
**Description**: Export reports to PDF/Excel, custom date ranges, advanced filters

### 4. Employee Profile Photos
**Status**: Not implemented
**Priority**: Low
**Description**: Upload and display employee profile photos

### 5. Multi-language Support
**Status**: Not implemented
**Priority**: Low
**Description**: Internationalization (i18n) support for multiple languages

## Code Quality Issues

### 1. Unused Imports
**Status**: Some files have unused imports
**Action**: Run `flutter analyze` and remove unused imports

### 2. Commented Code
**Status**: Some files may have commented-out code
**Action**: Remove all commented code

### 3. Magic Numbers
**Status**: Some hardcoded values exist
**Action**: Extract to constants or use design tokens

## Performance Optimizations

### 1. ListView.builder Usage
**Status**: Most lists use ListView.builder (good)
**Action**: Verify all long lists use ListView.builder

### 2. Image Optimization
**Status**: Not applicable (no images currently)
**Action**: When images are added, use appropriate caching and optimization

### 3. Pagination
**Status**: Not implemented
**Priority**: Medium
**Description**: Implement pagination for large datasets (employees, timesheets, etc.)

## Testing Coverage

### 1. Widget Tests
**Status**: Minimal coverage
**Priority**: High
**Action**: Add widget tests for all reusable components

### 2. Integration Tests
**Status**: Not implemented
**Priority**: Medium
**Action**: Add integration tests for critical user flows

### 3. Unit Tests
**Status**: Minimal coverage
**Priority**: Medium
**Action**: Add unit tests for store logic and domain models

## Documentation

### 1. Component Documentation
**Status**: Partially complete
**Action**: Add comprehensive dartdoc comments to all components

### 2. API Documentation
**Status**: Not documented
**Action**: Document all public APIs in stores and repositories

### 3. README Updates
**Status**: Needs UI/UX guidelines section
**Action**: Add UI/UX guidelines to README.md

## Recommendations

### High Priority (Before Phase 2)
1. Standardize error handling using ErrorMessageHelper
2. Optimize rebuilds using context.select
3. Add const constructors where possible
4. Remove duplicated stat card code
5. Add widget tests for components

### Medium Priority
1. Implement pagination for large lists
2. Add integration tests
3. Complete component documentation
4. Remove unused imports and commented code

### Low Priority
1. Offline support
2. Push notifications
3. Advanced reporting features
4. Multi-language support
