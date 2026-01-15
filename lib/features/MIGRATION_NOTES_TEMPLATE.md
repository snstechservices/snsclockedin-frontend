# [Feature Name] Migration Notes

**Date:** [Date]  
**Status:** [Planning/In Progress/Complete]

## Scope Definition

### Screens
- [ ] Screen 1: [Description]
- [ ] Screen 2: [Description]

### Actions
- [ ] Action 1: [Description]
- [ ] Action 2: [Description]

### Validations/Rules
- [ ] Rule 1: [Description]
- [ ] Rule 2: [Description]

### Role Access
- **Employee:** [What employee can do]
- **Admin:** [What admin can do]
- **Super Admin:** [What super admin can do (if applicable)]

## Legacy Reference

### Legacy Routes
- `/legacy_route_1` → `/v2_route_1`
- `/legacy_route_2` → `/v2_route_2`

### Legacy API Calls
- `GET /api/endpoint1` → [New endpoint or mock]
- `POST /api/endpoint2` → [New endpoint or mock]

### UI States
- Loading state: [Description]
- Empty state: [Description]
- Error state: [Description]

### Edge Cases
- [ ] Edge case 1: [Description]
- [ ] Edge case 2: [Description]

## Migration Plan

### Step 1: Domain Model
- [ ] Create domain models
- [ ] Create enums
- [ ] Create formatters/helpers

### Step 2: Store
- [ ] Create store
- [ ] Implement loading/error states
- [ ] Implement commands

### Step 3: Data Layer
- [ ] Create API wrapper (mock for now)
- [ ] Define method signatures

### Step 4: Presentation
- [ ] Create screen(s)
- [ ] Use AppScreenScaffold
- [ ] Use AppCard, SectionHeader
- [ ] Implement responsive layout

### Step 5: Navigation
- [ ] Add routes
- [ ] Add drawer items
- [ ] Test deep links

## Notes
[Any additional notes or considerations]

