import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sns_clocked_in/core/ui/app_card.dart';
import 'package:sns_clocked_in/core/ui/app_screen_scaffold.dart';
import 'package:sns_clocked_in/features/company_calendar/application/company_calendar_store.dart';
import 'package:sns_clocked_in/features/company_calendar/domain/calendar_day.dart';
import 'package:sns_clocked_in/features/company_calendar/presentation/company_calendar_widget.dart';
import 'package:sns_clocked_in/design_system/app_colors.dart';
import 'package:sns_clocked_in/design_system/app_radius.dart';
import 'package:sns_clocked_in/design_system/app_spacing.dart';
import 'package:sns_clocked_in/design_system/app_typography.dart';

/// Admin company calendar management screen with tabs
class AdminCompanyCalendarScreen extends StatefulWidget {
  const AdminCompanyCalendarScreen({super.key});

  @override
  State<AdminCompanyCalendarScreen> createState() =>
      _AdminCompanyCalendarScreenState();
}

class _AdminCompanyCalendarScreenState
    extends State<AdminCompanyCalendarScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    // Load current month calendar days for stats
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final store = context.read<CompanyCalendarStore>();
        final now = DateTime.now();
        store.loadCalendarDays(year: now.year, month: now.month);
        if (store.config == null) {
          store.loadConfig();
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<CompanyCalendarStore>();
    final now = DateTime.now();
    final currentMonthDays = store.getCalendarDays(now.year, now.month);
    
    // Calculate stats from current month
    final workingDaysCount = currentMonthDays.where((d) => d.type == DayType.working).length;
    final holidaysCount = currentMonthDays.where((d) => d.type == DayType.holiday).length;
    final nonWorkingCount = currentMonthDays.where((d) => d.type == DayType.weekend || d.type == DayType.nonWorking).length;

    return AppScreenScaffold(
      skipScaffold: true,
      child: Column(
        children: [
          // Quick Stats at top (always visible, match pattern)
          _buildQuickStatsSection(workingDaysCount, holidaysCount, nonWorkingCount),
          // Tab Content
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: const [
                // Calendar Tab
                _CalendarTabContent(),
                // Working Days Tab
                _WorkingDaysTabContent(),
                // Holidays Tab
                _HolidaysTabContent(),
                // Non-Working Tab
                _NonWorkingTabContent(),
              ],
            ),
          ),
          // Bottom Navigation Bar
          _buildBottomNavBar(),
        ],
      ),
    );
  }

  Widget _buildBottomNavBar() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(
            color: AppColors.textSecondary.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(
              icon: Icons.calendar_today,
              label: 'Calendar',
              index: 0,
            ),
            _buildNavItem(
              icon: Icons.work_outline,
              label: 'Working Days',
              index: 1,
            ),
            _buildNavItem(
              icon: Icons.celebration_outlined,
              label: 'Holidays',
              index: 2,
            ),
            _buildNavItem(
              icon: Icons.block,
              label: 'Non-Working',
              index: 3,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required int index,
  }) {
    final isSelected = _currentIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _currentIndex = index;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isSelected
                    ? AppColors.primary
                    : AppColors.textSecondary,
                size: 24,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: AppTypography.lightTextTheme.bodySmall?.copyWith(
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.textSecondary,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickStatsSection(int workingDays, int holidays, int nonWorking) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.05),
        border: Border(
          bottom: BorderSide(
            color: AppColors.textSecondary.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.calendar_today, size: 18, color: AppColors.textSecondary),
              const SizedBox(width: AppSpacing.xs),
              Text(
                'Calendar Summary (This Month)',
                style: AppTypography.lightTextTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                SizedBox(
                  width: 140,
                  child: _buildStatCard(
                    'Working Days',
                    workingDays.toString(),
                    AppColors.success,
                    Icons.work_outline,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                SizedBox(
                  width: 140,
                  child: _buildStatCard(
                    'Holidays',
                    holidays.toString(),
                    AppColors.secondary,
                    Icons.celebration_outlined,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                SizedBox(
                  width: 140,
                  child: _buildStatCard(
                    'Non-Working',
                    nonWorking.toString(),
                    AppColors.warning,
                    Icons.block,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String count,
    Color color,
    IconData icon,
  ) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: AppSpacing.sm),
          Text(
            title,
            style: AppTypography.lightTextTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            count,
            style: AppTypography.lightTextTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Calendar tab content
class _CalendarTabContent extends StatelessWidget {
  const _CalendarTabContent();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: const CompanyCalendarWidget(),
    );
  }
}

/// Working Days tab content
class _WorkingDaysTabContent extends StatefulWidget {
  const _WorkingDaysTabContent();

  @override
  State<_WorkingDaysTabContent> createState() => _WorkingDaysTabContentState();
}

class _WorkingDaysTabContentState extends State<_WorkingDaysTabContent> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final store = context.read<CompanyCalendarStore>();
        if (store.config == null) {
          store.loadConfig();
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<CompanyCalendarStore>();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Working Days Configuration',
            style: AppTypography.lightTextTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          if (store.isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.xl),
                child: CircularProgressIndicator(),
              ),
            )
          else if (store.config != null) ...[
            _buildWorkingDaysList(store.config!.workingDays),
            if (store.config!.workingHours != null)
              _buildWorkingHours(store.config!.workingHours!),
          ] else
            Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Text(
                  'No working days configuration found',
                  style: AppTypography.lightTextTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildWorkingDaysList(List<String> workingDays) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Working Days',
          style: AppTypography.lightTextTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: workingDays.map((day) {
            return Chip(
              label: Text(day),
              backgroundColor: AppColors.success.withValues(alpha: 0.1),
              labelStyle: AppTypography.lightTextTheme.bodyMedium?.copyWith(
                color: AppColors.success,
                fontWeight: FontWeight.w600,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildWorkingHours(Map<String, String> hours) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpacing.lg),
        Text(
          'Working Hours',
          style: AppTypography.lightTextTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: _buildTimeCard('Start Time', hours['start'] ?? 'N/A'),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _buildTimeCard('End Time', hours['end'] ?? 'N/A'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTimeCard(String label, String time) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.textSecondary.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTypography.lightTextTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            time,
            style: AppTypography.lightTextTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

/// Holidays tab content
class _HolidaysTabContent extends StatelessWidget {
  const _HolidaysTabContent();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Holidays Management',
            style: AppTypography.lightTextTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                children: [
                  Icon(
                    Icons.celebration_outlined,
                    size: 64,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Holiday management coming soon',
                    style: AppTypography.lightTextTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Non-Working tab content
class _NonWorkingTabContent extends StatelessWidget {
  const _NonWorkingTabContent();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Non-Working Days Management',
            style: AppTypography.lightTextTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                children: [
                  Icon(
                    Icons.block,
                    size: 64,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Non-working days management coming soon',
                    style: AppTypography.lightTextTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
