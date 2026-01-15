# Feature Migration Checklist

Use this checklist for each feature migrated from legacy to v2.

## Pre-Migration

- [ ] **MIGRATION_NOTES.md created** (scope + rules + role access)
  - What screens exist
  - What actions exist
  - What validations/rules exist
  - What role can do what
  - Location: `lib/features/<feature>/MIGRATION_NOTES.md`

## Step 1: Domain Model

- [ ] **Domain model done** (enums, helpers)
  - Location: `lib/features/<feature>/domain/*.dart`
  - Pure Dart, UI-free, API-free
  - Includes formatters and helper methods

## Step 2: Store (Application Layer)

- [ ] **Store done** (loading/error + commands)
  - Location: `lib/features/<feature>/application/<feature>_store.dart`
  - Responsibilities:
    - Current view state
    - Loading/error states
    - Commands (e.g., clockIn, startBreak, applyLeave)
    - Mapping API → domain

## Step 3: Data Layer (Optional but Structure It)

- [ ] **Repository/API wrapper created** (even if mock)
  - Location: `lib/features/<feature>/data/<feature>_api.dart` or `data/<feature>_repository.dart`
  - Method signatures match future backend
  - Can be mock/in-memory for now

## Step 4: Presentation Layer

- [ ] **Screen UI built with AppScreenScaffold + AppCard**
  - Location: `lib/features/<feature>/presentation/*_screen.dart`
  - Uses AppScreenScaffold (not legacy Scaffold)
  - Uses AppCard, SectionHeader
  - Only calls store methods
  - Consistent spacing rhythm (AppSpacing tokens)
  - No repeated titles (AppBar owns title; body uses section headers)

## Step 5: Navigation & Routing

- [ ] **Drawer item + route wired**
  - Route added in `lib/app/router/app_router.dart`
  - Drawer nav item added in `lib/core/navigation/nav_config.dart`
  - Role guard still holds
  - Deep links work correctly

## Step 6: Quality Checks

- [ ] **Works on small Android screen** (no overflow)
  - Test on small device (5" screen)
  - Test on large device (6.5" screen)
  - No overflow warnings
  - Responsive layout

- [ ] **Lint clean**
  - Passes `very_good_analysis`
  - No warnings or errors

- [ ] **Old placeholder removed**
  - Delete/retire placeholder screens once feature is live in v2

## Non-Negotiables (Every Migrated Screen Must Follow)

✅ **Navigation:** go_router + role shells (EmployeeShell/AdminShell)  
✅ **State:** Provider stores (feature-owned store), no global singleton logic  
✅ **UI:** AppScreenScaffold, AppCard, SectionHeader, design tokens only  
✅ **No repeated titles:** AppBar owns title; body uses section headers  
✅ **Actions visible:** Sticky bottom CTA where needed (no hunting for buttons)

## Folder Rules

- `lib/legacy_ui/` - Reference-only. Allowed: reading, copying small snippets for understanding. Not allowed: importing legacy widgets into v2 routes/shells.
- `lib/features/* + lib/core/*` - All production v2 code lives here.

