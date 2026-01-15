# Legacy vs Current Admin Leave Management - Comparison

## Overview
This document compares the legacy admin leave management screen with the current implementation to identify what needs to match.

---

## 1. Layout Structure

### Legacy:
```
┌─────────────────────────────────────┐
│ App Bar: "Leave Management"         │
├─────────────────────────────────────┤
│ Tabs: [Requests | Balances | Accruals | Cash Out] │
├─────────────────────────────────────┤
│ Quick Stats (3 cards: Pending, Approved, Rejected) │
├─────────────────────────────────────┤
│ Filter Section                      │
│  - Employee: [Dropdown]             │
│  - Status: [Dropdown]               │
├─────────────────────────────────────┤
│ Leave Requests List                 │
└─────────────────────────────────────┘
```

### Current:
```
┌─────────────────────────────────────┐
│ Tabs: [Requests | Balances | Accruals | Cash Out] │
├─────────────────────────────────────┤
│ Selected Employee Filter Chip       │
├─────────────────────────────────────┤
│ Status Filter (SegmentedFilterBar)  │
├─────────────────────────────────────┤
│ Leave Requests List                 │
└─────────────────────────────────────┘
```

**What to Match:**
- ❌ **Missing**: Quick stats section at top (Pending, Approved, Rejected)
- ✅ Tabs structure (current matches)
- ❌ **Different**: Current uses SegmentedFilterBar, legacy uses dropdowns
- ❌ **Missing**: Collapsible filter section

---

## 2. Quick Stats Section

### Legacy Stats (Always Visible):
- **Pending** (orange, pending icon) - Clickable, filters to pending
- **Approved** (green, check_circle icon) - Clickable, filters to approved
- **Rejected** (red, cancel icon) - Clickable, filters to rejected

**Layout**: 3 cards in horizontal row, always visible at top
**Behavior**: Clicking a card filters the list to that status

### Current Stats:
- **Pending** (warning, pending icon) - Clickable stat card ✅
- **Approved** (success, check_circle icon) - Clickable stat card ✅
- **Rejected** (error, cancel icon) - Clickable stat card ✅

**Location**: Inside scrollable content (in AdminLeaveScreen, not AdminLeaveOverviewScreen)

**What to Match:**
- ❌ **Missing**: Stats should be at TOP (above filters), always visible
- ✅ Stats are clickable (current matches)
- ❌ **Different**: Current stats are in separate AdminLeaveScreen, not in overview

---

## 3. Filter Section

### Legacy Filters:
- **Employee**: Dropdown with "All Employees" + employee list
- **Status**: Dropdown with "All", "Pending", "Approved", "Rejected"
- **Layout**: White card, always visible
- **Location**: Below stats, above list

### Current Filters:
- **Employee**: SelectedEmployeeFilterChip (shows when selected)
- **Status**: SegmentedFilterBar (All, Pending, Approved, Rejected)
- **Layout**: Different UI pattern
- **Location**: Below tabs, above list

**What to Match:**
- ✅ Employee filter exists (current uses chip, legacy uses dropdown)
- ✅ Status filter exists (current uses segmented bar, legacy uses dropdown)
- ❌ **Add**: Collapsible filter section (like timesheet)
- ❌ **Add**: Date range filter (if needed for leave requests)

---

## 4. Leave Request Display

### Legacy - Request Card:
```
Card Layout:
┌─────────────────────────────────┐
│ Employee Name          [Status] │
│ Date Range                     │
│ Leave Type                     │
│ Days                           │
│ Reason (if available)          │
└─────────────────────────────────┘
```

### Current - Request Card:
```
Card Layout:
┌─────────────────────────────────┐
│ Employee Name          [Status] │
│ Department (if available)       │
│ [Leave Type Chip]               │
│ Date Range • Days               │
│ Reason (max 2 lines)            │
└─────────────────────────────────┘
```

**What to Match:**
- ✅ Card layout (current is good, shows more info)
- ✅ Status chip (current matches)
- ✅ Date range display (current is better - shows days count)
- ✅ Leave type chip (current addition - good)

---

## 5. Date Format

### Legacy:
- Date format: `dd/MM/yyyy` (e.g., "14/01/2026")

### Current:
- Date format: `dd/MM/yyyy` ✅ (matches)

**What to Match:**
- ✅ Date format matches

---

## 6. Responsive Design

### Legacy:
- **All Sizes**: Card list view only
- No DataTable view

### Current:
- **All Sizes**: Card list view only
- No DataTable view

**What to Match:**
- ✅ Both use card view (matches)
- ❌ **Optional**: Could add DataTable for desktop (like timesheet)

---

## Summary: What Needs to Match

### High Priority (Must Match):
1. ❌ **Quick Stats at Top**: Add summary cards (Pending, Approved, Rejected) above filters, always visible
2. ❌ **Collapsible Filter Section**: Make filters collapsible (like timesheet)
3. ❌ **Scrollable Stats**: Make stats scrollable if adding more metrics

### Medium Priority (Should Match):
4. ⚠️ **Filter UI Consistency**: Consider matching filter UI pattern (dropdowns vs segmented bar)
5. ⚠️ **Date Range Filter**: Add date range filter for leave requests (Today, Yesterday, This Week, Custom)

### Low Priority (Nice to Have):
6. 📋 **DataTable View**: Add responsive DataTable for desktop (≥700px)
7. 📋 **Employee Filter UI**: Keep chip or change to dropdown (current chip is fine)

---

## Implementation Checklist

- [ ] Add quick stats section at top (Pending, Approved, Rejected)
- [ ] Make stats scrollable (if adding more metrics)
- [ ] Make filter section collapsible
- [ ] Add date range filter (optional)
- [ ] Ensure stats are always visible (not in scrollable content)
- [ ] Match layout structure with timesheet page
