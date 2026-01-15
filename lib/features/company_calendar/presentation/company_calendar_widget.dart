import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sns_clocked_in/core/ui/app_card.dart';
import 'package:sns_clocked_in/features/company_calendar/application/company_calendar_store.dart';
import 'package:sns_clocked_in/features/company_calendar/domain/calendar_day.dart';
import 'package:sns_clocked_in/design_system/app_colors.dart';
import 'package:sns_clocked_in/design_system/app_radius.dart';
import 'package:sns_clocked_in/design_system/app_spacing.dart';
import 'package:sns_clocked_in/design_system/app_typography.dart';
import 'package:intl/intl.dart';

/// Company calendar widget showing month view with day types
class CompanyCalendarWidget extends StatefulWidget {
  const CompanyCalendarWidget({super.key});

  @override
  State<CompanyCalendarWidget> createState() => _CompanyCalendarWidgetState();
}

class _CompanyCalendarWidgetState extends State<CompanyCalendarWidget> {
  DateTime _focusedMonth = DateTime.now();
  CalendarDay? _selectedDay;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadCalendarData();
      }
    });
  }

  void _loadCalendarData() {
    final store = context.read<CompanyCalendarStore>();
    store.loadConfig();
    store.loadCalendarDays(
      year: _focusedMonth.year,
      month: _focusedMonth.month,
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<CompanyCalendarStore>();

    return Column(
      children: [
        // Calendar Card
        AppCard(
          padding: AppSpacing.lgAll,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Month Navigation
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: () {
                      setState(() {
                        _focusedMonth = DateTime(
                          _focusedMonth.year,
                          _focusedMonth.month - 1,
                        );
                      });
                      store.loadCalendarDays(
                        year: _focusedMonth.year,
                        month: _focusedMonth.month,
                      );
                    },
                  ),
                  Text(
                    DateFormat('MMMM yyyy').format(_focusedMonth),
                    style: AppTypography.lightTextTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: () {
                      setState(() {
                        _focusedMonth = DateTime(
                          _focusedMonth.year,
                          _focusedMonth.month + 1,
                        );
                      });
                      store.loadCalendarDays(
                        year: _focusedMonth.year,
                        month: _focusedMonth.month,
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              // Calendar Grid
              if (store.isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(AppSpacing.xl),
                    child: CircularProgressIndicator(),
                  ),
                )
              else
                _buildCalendarGrid(store),
              const SizedBox(height: AppSpacing.md),
              // Legend
              _buildLegend(),
            ],
          ),
        ),
        // Selected Day Details
        if (_selectedDay != null) ...[
          const SizedBox(height: AppSpacing.md),
          _buildDayDetailsCard(_selectedDay!, store),
        ],
      ],
    );
  }

  Widget _buildCalendarGrid(CompanyCalendarStore store) {
    // Get first day of month and calculate offset
    final firstDay = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    // Convert to Sunday = 0 format (Dart weekday: 1=Mon, 7=Sun)
    // We want: 0=Sun, 1=Mon, ..., 6=Sat
    final firstWeekday = firstDay.weekday == 7 ? 0 : firstDay.weekday;
    final daysInMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0).day;

    // Get previous month's days for padding
    final prevMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1);
    final daysInPrevMonth = DateTime(prevMonth.year, prevMonth.month + 1, 0).day;

    // Calculate weeks needed (always show 6 weeks for consistent layout)
    final weeksNeeded = 6;

    return Column(
      children: [
        // Day headers
        Row(
          children: ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
              .map((day) => Expanded(
                    child: Center(
                      child: Text(
                        day,
                        style: AppTypography.lightTextTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ))
              .toList(),
        ),
        const SizedBox(height: AppSpacing.sm),
        // Calendar days
        ...List.generate(weeksNeeded, (weekIndex) {
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Row(
              children: List.generate(7, (dayIndex) {
                final dayNumber = weekIndex * 7 + dayIndex - firstWeekday + 1;

                // Previous month days
                if (dayNumber <= 0) {
                  final prevDay = daysInPrevMonth + dayNumber;
                  return Expanded(
                    child: _buildDayCell(
                      date: DateTime(prevMonth.year, prevMonth.month, prevDay),
                      isCurrentMonth: false,
                      store: store,
                    ),
                  );
                }
                // Next month days
                else if (dayNumber > daysInMonth) {
                  final nextDay = dayNumber - daysInMonth;
                  return Expanded(
                    child: _buildDayCell(
                      date: DateTime(
                        _focusedMonth.year,
                        _focusedMonth.month + 1,
                        nextDay,
                      ),
                      isCurrentMonth: false,
                      store: store,
                    ),
                  );
                }
                // Current month days
                else {
                  return Expanded(
                    child: _buildDayCell(
                      date: DateTime(
                        _focusedMonth.year,
                        _focusedMonth.month,
                        dayNumber,
                      ),
                      isCurrentMonth: true,
                      store: store,
                    ),
                  );
                }
              }),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildDayCell({
    required DateTime date,
    required bool isCurrentMonth,
    required CompanyCalendarStore store,
  }) {
    final days = store.getCalendarDays(date.year, date.month);
    final calendarDay = days.firstWhere(
      (d) => d.date.year == date.year &&
          d.date.month == date.month &&
          d.date.day == date.day,
      orElse: () {
        // Determine default type
        DayType type;
        if (date.weekday == 6 || date.weekday == 7) {
          type = DayType.weekend;
        } else {
          final config = store.config;
          if (config != null) {
            final dayName = _getDayName(date.weekday);
            type = config.workingDays.contains(dayName)
                ? DayType.working
                : DayType.weekend;
          } else {
            type = date.weekday >= 1 && date.weekday <= 5
                ? DayType.working
                : DayType.weekend;
          }
        }
        return CalendarDay(date: date, type: type);
      },
    );

    final isSelected = _selectedDay != null &&
        _selectedDay!.date.year == date.year &&
        _selectedDay!.date.month == date.month &&
        _selectedDay!.date.day == date.day;
    final isToday = date.year == DateTime.now().year &&
        date.month == DateTime.now().month &&
        date.day == DateTime.now().day;

    final color = _getDayTypeColor(calendarDay.type);

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedDay = calendarDay;
        });
        store.setSelectedDay(calendarDay);
        store.loadDayDetails(date);
      },
      child: Container(
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary
              : isToday
                  ? color.withValues(alpha: 0.2)
                  : color.withValues(alpha: 0.1),
          borderRadius: AppRadius.smAll,
          border: isSelected
              ? Border.all(color: AppColors.primary, width: 2)
              : isToday
                  ? Border.all(color: color, width: 1.5)
                  : null,
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                date.day.toString(),
                style: AppTypography.lightTextTheme.bodySmall?.copyWith(
                  color: isCurrentMonth
                      ? (isSelected
                          ? Colors.white
                          : AppColors.textPrimary)
                      : AppColors.textSecondary.withValues(alpha: 0.5),
                  fontWeight: isToday || isSelected
                      ? FontWeight.bold
                      : FontWeight.normal,
                ),
              ),
              if (calendarDay.name != null)
                Text(
                  calendarDay.name!,
                  style: AppTypography.lightTextTheme.bodySmall?.copyWith(
                    fontSize: 8,
                    color: isSelected
                        ? Colors.white
                        : AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getDayTypeColor(DayType type) {
    switch (type) {
      case DayType.working:
        return AppColors.success;
      case DayType.holiday:
      case DayType.weekend:
        return AppColors.error;
      case DayType.nonWorking:
        return AppColors.warning;
      case DayType.override:
        return AppColors.primary;
    }
  }

  String _getDayName(int weekday) {
    switch (weekday) {
      case 1:
        return 'Monday';
      case 2:
        return 'Tuesday';
      case 3:
        return 'Wednesday';
      case 4:
        return 'Thursday';
      case 5:
        return 'Friday';
      case 6:
        return 'Saturday';
      case 7:
        return 'Sunday';
      default:
        return 'Monday';
    }
  }

  Widget _buildLegend() {
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.sm,
      children: [
        _buildLegendItem('Working Day', AppColors.success),
        _buildLegendItem('Holiday / Weekend', AppColors.error),
        _buildLegendItem('Non-Working', AppColors.warning),
        _buildLegendItem('Override', AppColors.primary),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.3),
            borderRadius: AppRadius.smAll,
            border: Border.all(color: color, width: 1),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(
          label,
          style: AppTypography.lightTextTheme.bodySmall?.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildDayDetailsCard(CalendarDay day, CompanyCalendarStore store) {
    final dateStr = DateFormat('MMM dd, yyyy').format(day.date);
    final icon = _getDayTypeIcon(day.type);
    final color = _getDayTypeColor(day.type);

    return AppCard(
      padding: AppSpacing.lgAll,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  dateStr,
                  style: AppTypography.lightTextTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  setState(() {
                    _selectedDay = null;
                  });
                  store.setSelectedDay(null);
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Text(
                day.typeDisplay,
                style: AppTypography.lightTextTheme.bodyLarge?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          if (day.name != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              day.name!,
              style: AppTypography.lightTextTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
          if (day.description != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              day.description!,
              style: AppTypography.lightTextTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: AppRadius.mediumAll,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    day.type == DayType.working
                        ? 'Standard working day'
                        : day.type == DayType.weekend
                            ? 'Weekend - Not in working days list'
                            : day.type == DayType.holiday
                                ? 'Company holiday'
                                : day.type == DayType.nonWorking
                                    ? 'Non-working day'
                                    : 'Override working day',
                    style: AppTypography.lightTextTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getDayTypeIcon(DayType type) {
    switch (type) {
      case DayType.working:
        return Icons.event_available;
      case DayType.holiday:
        return Icons.celebration;
      case DayType.weekend:
        return Icons.weekend;
      case DayType.nonWorking:
        return Icons.event_busy;
      case DayType.override:
        return Icons.work;
    }
  }
}
