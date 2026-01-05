# SNS-Rooster UI/UX & Design System Documentation

## Project Branding
**Brand Name:** S&S Clocked In
**App Name:** SNS Rooster
**Logo:** Clock-based logo design
**Design Philosophy:** Modern, clean, professional employee management interface

---

## Table of Contents
1. [Design System Overview](#design-system-overview)
2. [Color Palette](#color-palette)
3. [Typography](#typography)
4. [Spacing & Layout](#spacing--layout)
5. [Component Library](#component-library)
6. [Custom Branding System](#custom-branding-system)
7. [Theming Architecture](#theming-architecture)
8. [UI Patterns](#ui-patterns)
9. [Responsive Design](#responsive-design)
10. [Accessibility](#accessibility)
11. [Animation & Transitions](#animation--transitions)
12. [Assets & Resources](#assets--resources)

---

## 1. Design System Overview

### Design Token System
The app uses a centralized design token system defined in `lib/theme/app_theme.dart` for consistent UI across all platforms.

### Material Design 3
- **Framework:** Flutter Material Design 3
- **useMaterial3:** `true`
- **Design Language:** Modern, adaptive, accessible

### Multi-Tenant Branding
- **Dynamic Theming:** Companies can customize primary/secondary colors
- **Logo Customization:** Company-specific logos
- **Safe Theming Rules:** Prevents UI readability issues

---

## 2. Color Palette

### Default Color System

#### Primary Colors
```dart
Primary Color:      #1976D2 (Blue 700)
Primary Variant:    #1565C0 (Blue 800)
Secondary Color:    #2196F3 (Blue 500)
```

**RGB Values:**
- Primary: `rgb(25, 118, 210)`
- Primary Variant: `rgb(21, 101, 192)`
- Secondary: `rgb(33, 150, 243)`

#### Semantic Colors
```dart
Success:   #2E7D32 (Green 800)
Warning:   #ED6C02 (Orange 700)
Error:     #D32F2F (Red 700)
Muted:     #9E9E9E (Grey 500)
```

#### Background Colors
```dart
Background: #F6F8FB (Light grey-blue)
Surface:    #FFFFFF (White)
```

#### Dark Theme Colors
```dart
Surface (Dark):     #1E1E1E (Dark grey)
Input Fill (Dark):  #2A2A2A (Darker grey)
Divider (Dark):     #424242 (Medium grey)
```

### Color Usage Guidelines

#### DO's ✅
- Use primary color for AppBar, FAB, primary buttons
- Use secondary color for secondary actions
- Use semantic colors (success/warning/error) for status indicators
- Use surface color for cards and elevated components
- Calculate text colors dynamically for contrast

#### DON'Ts ❌
- Don't use primary color for dashboard cards (use surface)
- Don't use tenant colors for charts (use predefined palettes)
- Don't use low-contrast color combinations
- Don't apply branding colors to all UI elements

---

## 3. Typography

### Primary Font Family
**Product Sans** - Google's geometric sans-serif

#### Font Files
```
assets/fonts/
├── ProductSans-Regular.ttf   (Weight: 400)
├── ProductSans-Bold.ttf       (Weight: 700)
└── ProductSans-Italic.ttf     (Style: italic)
```

#### Fallback Fonts
```
OpenSans-Regular.ttf
OpenSans-Bold.ttf
```

### Typography Scale

#### Display Hero
```dart
Font Size:     28px
Font Weight:   900 (Black)
Line Height:   22/28
Use Case:      Hero sections, splash screens
```

#### Title Large
```dart
Font Size:     20px
Font Weight:   700 (Bold)
Use Case:      Page titles, dialog titles, AppBar titles
```

#### Body Large
```dart
Font Size:     16px
Font Weight:   400 (Regular)
Use Case:      Primary body text, descriptions
```

#### Body Medium
```dart
Font Size:     14px
Font Weight:   400 (Regular)
Use Case:      Secondary text, form labels
```

#### Small Caption
```dart
Font Size:     12px
Font Weight:   300 (Light)
Use Case:      Captions, helper text, timestamps
```

### AppBar Typography
```dart
Font Size:     20px
Font Weight:   600 (Semi-bold)
Color:         White (on primary background)
```

---

## 4. Spacing & Layout

### Spacing Scale (Design Tokens)

```dart
XS:  4dp   - Minimal spacing, icon padding
S:   8dp   - Tight spacing, compact lists
M:   12dp  - Standard spacing, input padding
L:   16dp  - Comfortable spacing, card padding
XL:  24dp  - Generous spacing, section gaps
```

### Layout Constants

#### Border Radius
```dart
Small:   8dp   - Chips, small buttons
Medium:  12dp  - Cards, buttons, inputs
Large:   16dp  - Dialogs, large cards
```

#### Elevation (Shadow Depth)
```dart
Low:     1.5dp  - Subtle elevation (cards, app bar)
Medium:  4.0dp  - Standard elevation (FAB, dialogs)
High:    8.0dp  - High elevation (menus, tooltips)
```

### Component Sizing

#### Minimum Touch Targets
```dart
Minimum Size:  48 x 48 dp (WCAG Accessibility)
```

#### Button Padding
```dart
Horizontal: 16dp (spacingL)
Vertical:   12dp (spacingM)
```

#### Input Padding
```dart
Horizontal: 12dp (spacingM)
Vertical:   12dp (spacingM)
```

#### Card Margins
```dart
All Sides: 8dp (spacingS)
```

---

## 5. Component Library

### Button Components

#### Elevated Button
```dart
Style:
- Background: Primary color
- Foreground: White
- Elevation: 1.5dp
- Border Radius: 12dp
- Padding: 16h x 12v dp
- Min Size: 48x48dp

Use Cases:
- Primary actions (Submit, Save, Confirm)
- Clock In/Out buttons
- Main CTAs
```

#### Outlined Button
```dart
Style:
- Foreground: Primary color
- Border: 1.5px solid primary
- Border Radius: 12dp
- Padding: 16h x 12v dp
- Background: Transparent

Use Cases:
- Secondary actions (Cancel, Back)
- Alternative options
- Less prominent actions
```

#### Text Button
```dart
Style:
- Foreground: Primary color
- Border Radius: 12dp
- Background: Transparent
- Padding: 16h x 12v dp

Use Cases:
- Tertiary actions
- Dialog actions
- Navigation links
```

### Card Components

#### Standard Card
```dart
Style:
- Elevation: 1.5dp
- Border Radius: 12dp
- Background: Surface color (white)
- Margin: 8dp all sides

Variants:
- Dashboard cards
- List item cards
- Info cards
```

#### Quick Action Tile
```dart
Style:
- Background: Surface color
- Border Radius: 12dp
- Box Shadow: 0 1px blur 1.5dp rgba(0,0,0,0.08)

Use Cases:
- Dashboard quick actions
- Feature tiles
- Navigation tiles
```

#### Primary Action Tile
```dart
Style:
- Gradient: Linear (Primary → Primary Variant)
- Border Radius: 12dp
- Box Shadow: 0 2px blur 4dp primary(30%)

Use Cases:
- Clock In/Out cards
- Primary feature access
- Highlighted actions
```

### Input Components

#### Text Field
```dart
Style:
- Filled: true
- Fill Color: Surface (light) / #2A2A2A (dark)
- Border: 1px solid muted
- Focused Border: 2px solid primary
- Border Radius: 12dp
- Content Padding: 12dp horizontal, 12dp vertical
```

#### Dropdown
```dart
Style:
- Same as text field
- Icon Color: Muted
```

### Navigation Components

#### Bottom Navigation Bar
```dart
Style:
- Background: Surface
- Selected Color: Primary
- Unselected Color: Muted
- Type: Fixed
- Elevation: 1.5dp

Max Items: 5
```

#### Navigation Drawer
```dart
Style:
- Background: Surface
- Elevation: 1.5dp
- Indicator Color: Primary (10% opacity)
- Tile Height: 56dp
- Label Font: 14px, weight 500
```

#### AppBar
```dart
Style:
- Background: Primary color
- Foreground: White
- Elevation: 1.5dp
- Center Title: true
- Title Font: 20px, weight 600

Height: 56dp (standard)
```

### Dialog Components

```dart
Style:
- Background: Surface
- Elevation: 4dp
- Border Radius: 16dp
- Title Font: Title Large (20px, bold)
- Content Font: Body Medium (14px, regular)
```

### Chip Components

```dart
Style:
- Background: Surface
- Selected: Primary (10% opacity)
- Border Radius: 16dp
- Elevation: 1.5dp
- Label Font: 14px, regular

Use Cases:
- Filters
- Tags
- Status indicators
```

### SnackBar

```dart
Style:
- Background: Black (87% opacity)
- Content Font: Body Medium, white
- Border Radius: 12dp
- Behavior: Floating

Duration: 4 seconds (default)
```

### Floating Action Button (FAB)

```dart
Style:
- Background: Primary
- Foreground: White
- Elevation: 4dp

Size: 56x56dp (standard)
Use: Primary screen action
```

---

## 6. Custom Branding System

### Multi-Tenant Branding Architecture

#### Customizable Elements
1. **Logo** (PNG/JPG/SVG)
2. **Primary Color** (Hex color code)
3. **Secondary Color** (Hex color code)
4. **Email Branding** (HTML header/footer)

#### Branding Storage
```javascript
{
  companyId: ObjectId,
  logoUrl: String,
  logoFileId: String,
  primaryColor: String,      // e.g., "#1976D2"
  secondaryColor: String,    // e.g., "#2196F3"
  themePreset: Enum ['light', 'dark', 'custom'],
  emailHeader: String,       // HTML
  emailFooter: String,       // HTML
  companyName: String
}
```

#### Safe Theming Rules

**MUST Use Surface Color:**
- Dashboard cards
- List backgrounds
- Input backgrounds
- Dialog backgrounds

**MUST Use Predefined Palette:**
- Chart colors
- Graph data series
- Analytics visualizations

**CAN Use Branding Colors:**
- AppBar background ✅
- Floating Action Button ✅
- Primary buttons ✅
- Secondary buttons (outline) ✅
- Toggle switches ✅
- Chips (selected state) ✅

#### Color Contrast Validation
- Text colors calculated dynamically
- Minimum contrast ratio: 4.5:1 (WCAG AA)
- Automatic light/dark text on colored backgrounds

---

## 7. Theming Architecture

### Theme Presets

#### Light Theme (Default)
```dart
Brightness: light
Background: #F6F8FB
Surface: #FFFFFF
Text: Black87
```

#### Dark Theme
```dart
Brightness: dark
Background: #1E1E1E
Surface: #1E1E1E
Text: White
Input Fill: #2A2A2A
```

#### Custom Theme
- Uses light theme as base
- Applies custom primary/secondary colors
- Maintains accessibility standards

### Theme Switching
- **Admin Only:** Dark mode toggle in settings
- **User Preference:** Stored in AdminSettings
- **Dynamic:** Real-time theme switching without restart

### Theme Caching
- Branding cached in SharedPreferences
- Offline access to custom themes
- Cache cleared on logout

---

## 8. UI Patterns

### Loading States

#### Shimmer Loading
```dart
Package: shimmer ^3.0.0
Use Cases:
- List items loading
- Card content loading
- Profile data loading

Style:
- Base color: Light grey
- Highlight color: White
- Animation: Slow sweep
```

#### Spinner Loading
```dart
Package: flutter_spinkit ^5.2.0
Variants:
- Circle
- Fading circle
- Wave
- Three bounce

Use Cases:
- Full screen loading
- Button loading state
- Async operations
```

### Empty States
- Icon + Message + Action button
- Friendly, encouraging copy
- Clear call-to-action

### Error States
- Error icon (red)
- Error message
- Retry action button
- Context-specific guidance

### Success Feedback
- Green checkmark icon
- Success message
- Auto-dismiss after 2-3 seconds
- Optional action button

### Status Indicators

#### Attendance Status
```dart
Present:    Green (#2E7D32)
Absent:     Red (#D32F2F)
Late:       Orange (#ED6C02)
Half-Day:   Yellow (#F9A825)
On-Leave:   Blue (#1976D2)
```

#### Leave Status
```dart
Pending:    Orange (#ED6C02)
Approved:   Green (#2E7D32)
Rejected:   Red (#D32F2F)
```

#### Connection Status
```dart
Online:     Green + "Online" text
Offline:    Red + "Offline" text
Weak:       Orange + "Poor connection" text
```

---

## 9. Responsive Design

### Breakpoints

```dart
Mobile:     < 600dp
Tablet:     600dp - 1024dp
Desktop:    > 1024dp
```

### Adaptive Layouts

#### Mobile (<600dp)
- Single column layouts
- Bottom navigation
- Hamburger menu
- Full-width cards
- Stacked forms

#### Tablet (600-1024dp)
- Two-column layouts
- Side navigation (optional)
- Grid layouts (2 columns)
- Larger touch targets

#### Desktop (>1024dp)
- Multi-column layouts
- Persistent side navigation
- Grid layouts (3-4 columns)
- Hover states
- Keyboard navigation

### Widget Responsiveness
```dart
Package: responsive_row (custom)

Usage:
- Responsive grids
- Adaptive spacing
- Breakpoint-aware layouts
```

---

## 10. Accessibility

### WCAG 2.1 Compliance

#### Level AA Standards
- Minimum touch target: 48x48dp ✅
- Color contrast: 4.5:1 minimum ✅
- Focus indicators: Visible ✅
- Screen reader support: Yes ✅

### Semantic Structure
- Proper heading hierarchy
- Descriptive labels
- Alt text for images
- Meaningful link text

### Keyboard Navigation
- Tab order logical
- Focus visible
- Escape to close dialogs
- Enter to submit forms

### Color Blindness Support
- Not relying solely on color
- Icons + text for status
- Patterns in charts
- High contrast mode support

---

## 11. Animation & Transitions

### Animation Packages

```yaml
flutter_staggered_animations: ^1.1.1  # Staggered list animations
introduction_screen: ^3.1.12           # Onboarding animations
tutorial_coach_mark: ^1.2.10           # Tutorial animations
```

### Standard Transitions

#### Page Transitions
```dart
Duration: 300ms
Curve: easeInOut
Type: Slide up (default)
```

#### Button Press
```dart
Duration: 100ms
Curve: easeOut
Scale: 0.95
```

#### Card Reveal
```dart
Duration: 400ms
Curve: easeOutCubic
Type: Fade + Scale
```

#### Drawer Slide
```dart
Duration: 250ms
Curve: easeInOut
```

### Loading Animations
- Circular progress indicator
- Linear progress bar
- Shimmer effect
- Pulse animation

### Micro-interactions
- Ripple effect on tap
- Button elevation change
- Icon bounce on success
- Shake on error

---

## 12. Assets & Resources

### Logo Assets

```
assets/images/
├── clock_logo.png          # Primary logo
├── app_log.png             # Alternative logo
├── splash_logo.png         # Splash screen logo
├── S&SClockedIn.svg        # Vector logo
└── logo.png                # Generic logo
```

### Icon Assets

```
App Icon: clock_logo.png
Launcher Icon: ic_launcher (Android)
Sizes: 192x192, 512x512
```

### Default Avatars

```
default-avatar.png          # Generic user avatar
profile_placeholder.png     # Profile placeholder
```

### Third-Party Logos

```
google_logo.png             # Google Sign-In button
```

### App Icon Configuration

```yaml
flutter_launcher_icons:
  android: "ic_launcher"
  image_path: "assets/images/clock_logo.png"
  min_sdk_android: 21
```

---

## 13. Component Widget Library

### Custom Widgets (60+ Components)

#### Layout Widgets
- `ResponsiveRow` - Responsive grid layout
- `ModernCard` - Modern card component
- `PersistentNavigationWrapper` - Persistent nav

#### Navigation Widgets
- `AppDrawer` - Main navigation drawer
- `AdminSideNavigation` - Admin panel sidebar
- `SharedAppBar` - Reusable app bar
- `NavigationDrawer` - Custom drawer

#### Feature Widgets
- `FeatureGuard` - Feature access control
- `FeatureLockWidget` - Locked feature UI
- `FeatureDashboard` - Feature overview
- `FeatureInitializer` - Feature init wrapper

#### Status Widgets
- `ConnectivityBanner` - Connection status
- `EnhancedConnectivityBanner` - Enhanced version
- `GlobalConnectivityWrapper` - Global wrapper
- `NetworkStatusBanner` - Network status
- `ConnectionStatusBanner` - Connection indicator

#### Notification Widgets
- `GlobalNotificationBanner` - Global notifications
- `NotificationBell` - Notification icon + badge
- `BreakTimeWarningWidget` - Break time alerts

#### Map/Location Widgets
- `GoogleMapsLocationWidget` - Google Maps
- `InteractiveLocationMap` - Interactive map
- `MapLocationPicker` - Location picker
- `ModernLocationPicker` - Modern picker UI
- `LocationMapPreview` - Map preview
- `LocationListItem` - Location list item
- `LocationStatusIndicator` - Location status

#### Profile Widgets
- `ProfileAvatar` - User avatar component
- `UserAvatar` - Alternative avatar

#### Company/Admin Widgets
- `CompanyDetailsWidget` - Company info
- `CompanyInfoWidget` - Company details
- `CompanyUsageWidget` - Usage metrics
- `CompanyNotificationsWidget` - Company notifications
- `UsageLimitWidget` - Usage limit display

#### Leave Management
- `LeaveBalanceCard` - Leave balance
- `LeavePolicyInfoWidget` - Policy info
- `LeaveRequestModal` - Request dialog

#### Time Tracking
- `RealTimeBreakTimer` - Live break timer

#### Dialogs
- `EmployeeAssignmentDialog` - Assign employees
- `EmployeeCashOutDialog` - Cash out request
- `ExportOptionsDialog` - Export options

#### Filter/Selection
- `RoleFilterChip` - Role filter chips
- `TimezoneSelector` - Timezone picker

#### Utility Widgets
- `MaintenanceGate` - Maintenance mode
- `DebugOverlay` - Debug information
- `OfflinePlaceholder` - Offline state
- `NetworkErrorWidget` - Network errors
- `NetworkErrorHandlerWidget` - Error handler

---

## 14. Design Tokens Summary

### Quick Reference Card

```dart
// Colors
Primary:        #1976D2
Secondary:      #2196F3
Success:        #2E7D32
Warning:        #ED6C02
Error:          #D32F2F
Background:     #F6F8FB
Surface:        #FFFFFF

// Typography
Display:        28px / 900
Title:          20px / 700
Body Large:     16px / 400
Body Medium:    14px / 400
Caption:        12px / 300

// Spacing
XS:   4dp
S:    8dp
M:    12dp
L:    16dp
XL:   24dp

// Radius
Small:   8dp
Medium:  12dp
Large:   16dp

// Elevation
Low:     1.5dp
Medium:  4.0dp
High:    8.0dp

// Font
Family:  Product Sans
Fallback: OpenSans
```

---

## 15. UI/UX Best Practices

### General Principles

1. **Consistency** - Use design tokens consistently
2. **Simplicity** - Keep interfaces clean and uncluttered
3. **Feedback** - Provide immediate visual feedback
4. **Accessibility** - Follow WCAG guidelines
5. **Performance** - Optimize animations and images
6. **Responsiveness** - Adapt to all screen sizes

### User Experience Guidelines

#### Information Hierarchy
- Most important actions: Elevated buttons
- Secondary actions: Outlined buttons
- Tertiary actions: Text buttons

#### Error Prevention
- Input validation
- Confirmation dialogs for destructive actions
- Clear error messages with solutions

#### Loading Experience
- Skeleton screens for list content
- Progress indicators for long operations
- Optimistic UI updates where possible

#### Mobile-First Design
- Design for mobile first
- Scale up for tablets/desktop
- Touch-friendly interfaces
- Thumb-friendly navigation

---

## 16. Platform-Specific Considerations

### Android
- Material Design 3 components
- Floating Action Button for primary action
- Bottom navigation for main sections
- Swipe gestures supported

### iOS
- Cupertino widgets where appropriate
- Native iOS feel maintained
- Respects iOS design guidelines
- Safe area handling

### Web
- Responsive layouts
- Hover states for interactive elements
- Keyboard navigation
- Desktop-optimized spacing
- Pointer cursor for clickable elements

---

## 17. Branding Implementation Example

### Backend Branding Model
```javascript
{
  _id: ObjectId,
  companyId: ObjectId,
  logoUrl: "/uploads/company/logo-abc123.png",
  logoFileId: "firebase-file-id-xyz",
  primaryColor: "#1976D2",
  secondaryColor: "#2196F3",
  accentColor: "#FF9800",
  themePreset: "light",
  emailHeader: "<div style='...'>Header HTML</div>",
  emailFooter: "<div style='...'>Footer HTML</div>",
  companyName: "Acme Corporation",
  createdAt: ISODate,
  updatedAt: ISODate
}
```

### Frontend Branding Usage
```dart
// In BrandingProvider
final theme = brandingProvider.currentTheme;
final logo = brandingProvider.logoUrl;
final companyName = brandingProvider.companyName;

// Apply to MaterialApp
MaterialApp(
  theme: theme,
  // ... routes, etc.
)

// Display logo
if (logo != null) {
  Image.network(logo, height: 40)
}
```

---

## Version History

- **v1.0** - Initial UI/UX documentation
- **Date:** 2025-01-02
- **Author:** UI/UX Analysis

---

**END OF UI/UX DOCUMENTATION**
