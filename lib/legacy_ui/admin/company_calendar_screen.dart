import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:sns_rooster/utils/global_navigator.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../providers/company_calendar_provider.dart';
import '../../providers/feature_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/company_provider.dart';
import '../../widgets/modern_card_widget.dart';
import '../../theme/app_theme.dart';
import '../../widgets/admin_side_navigation.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import '../../services/privacy_service.dart';
import 'package:sns_rooster/utils/logger.dart';
import '../../services/global_notification_service.dart';
import 'package:http/http.dart' as http;
import '../../config/api_config.dart';
import '../../utils/theme_utils.dart';

class CompanyCalendarScreen extends StatefulWidget {
  const CompanyCalendarScreen({super.key});

  @override
  State<CompanyCalendarScreen> createState() => _CompanyCalendarScreenState();
}

class _CompanyCalendarScreenState extends State<CompanyCalendarScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  DateTime? _selectedDay;
  DateTime _focusedDay = DateTime.now();
  int _currentYear = DateTime.now().year;

  // Working days state
  Set<String> _selectedWorkingDays = {
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
  };

  // Holiday state
  final String _selectedHolidayGender = 'all';

  // Form controllers
  final _workingDaysController = TextEditingController();
  final _startTimeController = TextEditingController();
  final _endTimeController = TextEditingController();
  final _countryController = TextEditingController();

  // Grace periods and overtime controllers
  final _attendanceGraceController = TextEditingController();
  final _breakGraceController = TextEditingController();
  final _overtimeThresholdController = TextEditingController();

  // Holiday form controllers
  final _holidayNameController = TextEditingController();
  final _holidayDateController = TextEditingController();
  final _holidayDescriptionController = TextEditingController();

  // Non-working day form controllers
  final _nwdNameController = TextEditingController();
  final _nwdStartDateController = TextEditingController();
  final _nwdEndDateController = TextEditingController();
  final _nwdReasonController = TextEditingController();

  // Override working day reason controller
  final _overrideReasonController = TextEditingController();

  // State variables
  String _selectedHolidayType = 'company';
  bool _isHolidayRecurring = false;
  String _holidayRecurrencePattern = 'yearly';
  bool _isCountryLocked = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      setState(() {}); // Rebuild UI when tab changes
    });
    _initializeForm();
    _loadCalendar();
    _loadCompanySettings();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _disposeControllers();
    super.dispose();
  }

  void _disposeControllers() {
    _workingDaysController.dispose();
    _startTimeController.dispose();
    _endTimeController.dispose();
    _countryController.dispose();
    _holidayNameController.dispose();
    _holidayDateController.dispose();
    _holidayDescriptionController.dispose();
    _nwdNameController.dispose();
    _nwdStartDateController.dispose();
    _nwdEndDateController.dispose();
    _nwdReasonController.dispose();
    _overrideReasonController.dispose();
    _attendanceGraceController.dispose();
    _breakGraceController.dispose();
    _overtimeThresholdController.dispose();
  }

  void _initializeForm() {
    _startTimeController.text = '09:00';
    _endTimeController.text = '17:00';
    _countryController.text = 'Nepal';
    _attendanceGraceController.text = '15';
    _breakGraceController.text = '2';
    _overtimeThresholdController.text = '8';
  }

  Future<void> _loadCompanySettings() async {
    try {
      final companyProvider = Provider.of<CompanyProvider>(
        context,
        listen: false,
      );
      final company = companyProvider.currentCompany?.toJson();

      if (company != null && company['settings'] != null) {
        final settings = company['settings'];
        _attendanceGraceController.text =
            (settings['attendanceGracePeriod'] ?? 15).toString();
        _breakGraceController.text = (settings['breakGracePeriod'] ?? 2)
            .toString();
        _overtimeThresholdController.text = (settings['overtimeThreshold'] ?? 8)
            .toString();
      } else {
        // Try to fetch from backend
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        try {
          final response = await http.get(
            Uri.parse('${ApiConfig.baseUrl}/admin/settings/company'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${authProvider.authToken}',
              'x-company-id': authProvider.user?['companyId'] ?? '',
            },
          );

          if (response.statusCode == 200) {
            final data = json.decode(response.body);
            if (data['settings'] != null) {
              final settings = data['settings'];
              _attendanceGraceController.text =
                  (settings['attendanceGracePeriod'] ?? 15).toString();
              _breakGraceController.text = (settings['breakGracePeriod'] ?? 2)
                  .toString();
              _overtimeThresholdController.text =
                  (settings['overtimeThreshold'] ?? 8).toString();
            }
          }
        } catch (e) {
          Logger.error(
            'CompanyCalendarScreen: Error fetching company settings: $e',
          );
        }
      }
    } catch (e) {
      Logger.error('CompanyCalendarScreen: Error loading company settings: $e');
    }
  }

  void _loadExistingData(CompanyCalendarProvider provider) {
    if (provider.calendar != null) {
      // Load working days
      if (provider.calendar!['workingDays'] != null) {
        _selectedWorkingDays = Set<String>.from(
          provider.calendar!['workingDays'],
        );
      }

      // Load working hours
      if (provider.calendar!['workingHours'] != null) {
        final workingHours = provider.calendar!['workingHours'];
        if (workingHours['start'] != null) {
          _startTimeController.text = workingHours['start'];
        }
        if (workingHours['end'] != null) {
          _endTimeController.text = workingHours['end'];
        }
      }

      // Load regional settings
      if (provider.calendar!['regionalSettings'] != null) {
        final regionalSettings = provider.calendar!['regionalSettings'];
        if (regionalSettings['country'] != null) {
          _countryController.text = regionalSettings['country'];
        }
      }

      // Also load country from calendar directly (in case it's stored there)
      if (provider.calendar!['country'] != null) {
        _countryController.text = provider.calendar!['country'];
        // Lock country if it's already set (prevent frequent changes)
        _isCountryLocked = true;
      }
    }
  }

  Future<void> _loadCalendar() async {
    final provider = context.read<CompanyCalendarProvider>();
    await provider.checkFeatureAvailability();
    if (provider.featureAvailable) {
      await provider.fetchCompanyCalendar(_currentYear);
      // Load existing data into form fields
      _loadExistingData(provider);

      // Fix: Ensure focusedDay is within the current year bounds
      final now = DateTime.now();
      if (_currentYear == now.year) {
        _focusedDay = now;
      } else {
        // If viewing different year, set focusedDay to middle of that year
        _focusedDay = DateTime(_currentYear, 6, 15); // June 15th of the year
      }

      // Reset selected day when year changes
      _selectedDay = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: const Text('Company Calendar'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: ThemeUtils.getAutoTextColor(
          Theme.of(context).colorScheme.primary,
        ),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadCalendar,
            tooltip: 'Refresh Calendar',
          ),
        ],
      ),
      drawer: const AdminSideNavigation(currentRoute: '/company_calendar'),
      body: Consumer2<CompanyCalendarProvider, FeatureProvider>(
        builder: (context, calendarProvider, featureProvider, child) {
          // Check if company calendar feature is available
          if (!featureProvider.hasCompanyCalendar) {
            return _buildFeatureNotAvailable();
          }

          if (calendarProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          // Only show error screen for loading/fetching errors, not for user action validation errors
          // User action errors are handled via toasts and marked as user action errors in the provider
          if (calendarProvider.shouldShowErrorScreen) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: ThemeUtils.getStatusChipColor(
                      'error',
                      Theme.of(context),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error: ${calendarProvider.error}',
                    style: AppTheme.bodyLarge.copyWith(
                      color: ThemeUtils.getStatusChipColor(
                        'error',
                        Theme.of(context),
                      ),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _loadCalendar,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              _buildYearSelector(),
              Expanded(
                child: IndexedStack(
                  index: _tabController.index,
                  children: [
                    _buildCalendarView(calendarProvider),
                    _buildWorkingDaysTab(calendarProvider),
                    _buildHolidaysTab(calendarProvider),
                    _buildNonWorkingDaysTab(calendarProvider),
                  ],
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: _buildBottomNavigation(),
    );
  }

  Widget _buildFeatureNotAvailable() {
    return Center(
      child: ModernCard(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.calendar_today_outlined,
                size: 64,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                'Company Calendar Feature Not Available',
                style: AppTheme.titleLarge.copyWith(color: Colors.grey[700]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'This feature is only available in Leave-Oriented and higher subscription plans.',
                style: AppTheme.bodyMedium.copyWith(color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  // Navigate to subscription upgrade
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                ),
                child: const Text('Upgrade Plan'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildYearSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () {
              setState(() {
                _currentYear--;
                // Fix: Reset focused day when changing year
                _focusedDay = DateTime(_currentYear, 6, 15);
                _selectedDay = null;
              });
              _loadCalendar();
            },
          ),
          Text(
            '$_currentYear',
            style: AppTheme.titleLarge.copyWith(
              fontWeight: FontWeight.bold,
              color: AppTheme.primary,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () {
              setState(() {
                _currentYear++;
                // Fix: Reset focused day when changing year
                _focusedDay = DateTime(_currentYear, 6, 15);
                _selectedDay = null;
              });
              _loadCalendar();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarView(CompanyCalendarProvider provider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_tabController.index == 0)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppTheme.primary.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                '📅 Calendar View',
                textAlign: TextAlign.center,
                style: AppTheme.bodyMedium.copyWith(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          const SizedBox(height: 16),
          ModernCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Calendar View',
                    style: AppTheme.titleLarge.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TableCalendar(
                    firstDay: DateTime(_currentYear, 1, 1),
                    lastDay: DateTime(_currentYear, 12, 31),
                    focusedDay: _focusedDay,
                    selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                    calendarFormat: CalendarFormat.month,
                    startingDayOfWeek: StartingDayOfWeek.monday,
                    headerStyle: const HeaderStyle(
                      formatButtonVisible: false,
                      titleCentered: true,
                    ),
                    onDaySelected: (selectedDay, focusedDay) {
                      setState(() {
                        _selectedDay = selectedDay;
                        _focusedDay = focusedDay;
                      });
                      // Info panel will show below calendar - no dialog needed
                    },
                    onPageChanged: (focusedDay) {
                      setState(() {
                        _focusedDay = focusedDay;
                      });
                    },
                    calendarStyle: CalendarStyle(
                      selectedDecoration: BoxDecoration(
                        color: AppTheme.primary,
                        shape: BoxShape.circle,
                      ),
                      todayDecoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                      ),
                      // Remove fixed weekend styling - let eventLoader handle it
                    ),
                    eventLoader: (day) {
                      // Return empty list - no event dots will be shown
                      return <String>[];
                    },
                    calendarBuilders: CalendarBuilders(
                      defaultBuilder: (context, day, focusedDay) {
                        // Check if this day is a working day
                        if (provider.calendar != null &&
                            provider.calendar!['workingDays'] != null) {
                          final workingDays = List<String>.from(
                            provider.calendar!['workingDays'],
                          );
                          final dayName = _getDayName(day.weekday);
                          final isWorkingDay = workingDays.contains(dayName);

                          // Check if this day is a holiday
                          bool isHoliday = false;
                          if (provider.calendar!['holidays'] != null) {
                            final holidays = List<Map<String, dynamic>>.from(
                              provider.calendar!['holidays'],
                            );
                            for (final holiday in holidays) {
                              try {
                                // Check for single-day holiday
                                if (holiday['date'] != null) {
                                  final holidayDate = DateTime.parse(
                                    holiday['date'],
                                  );
                                  if (isSameDay(day, holidayDate)) {
                                    isHoliday = true;
                                    break;
                                  }
                                }

                                // Check for multi-day holiday
                                if (holiday['startDate'] != null &&
                                    holiday['endDate'] != null) {
                                  final startDate = DateTime.parse(
                                    holiday['startDate'],
                                  );
                                  final endDate = DateTime.parse(
                                    holiday['endDate'],
                                  );

                                  // Normalize dates to compare only date parts (ignore time)
                                  final dayDate = DateTime(
                                    day.year,
                                    day.month,
                                    day.day,
                                  );
                                  final startDateOnly = DateTime(
                                    startDate.year,
                                    startDate.month,
                                    startDate.day,
                                  );
                                  final endDateOnly = DateTime(
                                    endDate.year,
                                    endDate.month,
                                    endDate.day,
                                  );

                                  // Check if the day falls within the holiday range
                                  if (dayDate.isAtSameMomentAs(startDateOnly) ||
                                      dayDate.isAtSameMomentAs(endDateOnly) ||
                                      (dayDate.isAfter(startDateOnly) &&
                                          dayDate.isBefore(endDateOnly))) {
                                    isHoliday = true;
                                    break;
                                  }
                                }
                              } catch (e) {
                                // Skip invalid dates
                              }
                            }
                          }

                          // Check if this day is a non-working day
                          bool isNonWorkingDay = false;
                          if (provider.calendar!['nonWorkingDays'] != null) {
                            final nonWorkingDays =
                                List<Map<String, dynamic>>.from(
                                  provider.calendar!['nonWorkingDays'],
                                );
                            for (final nwd in nonWorkingDays) {
                              try {
                                final startDate = DateTime.parse(
                                  nwd['startDate'],
                                ).toLocal();
                                final endDate = DateTime.parse(
                                  nwd['endDate'],
                                ).toLocal();

                                // Normalize dates to compare only date parts (ignore time)
                                final dayDate = DateTime(
                                  day.year,
                                  day.month,
                                  day.day,
                                );
                                final startDateOnly = DateTime(
                                  startDate.year,
                                  startDate.month,
                                  startDate.day,
                                );
                                final endDateOnly = DateTime(
                                  endDate.year,
                                  endDate.month,
                                  endDate.day,
                                );

                                // Check if the day falls within the non-working day range
                                if (dayDate.isAtSameMomentAs(startDateOnly) ||
                                    dayDate.isAtSameMomentAs(endDateOnly) ||
                                    (dayDate.isAfter(startDateOnly) &&
                                        dayDate.isBefore(endDateOnly))) {
                                  isNonWorkingDay = true;
                                  break;
                                }
                              } catch (e) {
                                // Skip invalid dates
                              }
                            }
                          }

                          // Check if this day is an override working day (takes highest priority)
                          bool isOverrideWorkingDay = provider
                              .isOverrideWorkingDay(day);

                          // Determine styling based on day type
                          // Override working days take highest priority
                          Color backgroundColor;
                          Color borderColor;
                          Color textColor;
                          FontWeight fontWeight;
                          String? badgeText;

                          if (isOverrideWorkingDay) {
                            // Override working day: Blue/purple background with special border
                            backgroundColor = Colors.blue.withValues(
                              alpha: 0.25,
                            );
                            borderColor = Colors.blue[700]!;
                            textColor = Colors.blue[900]!;
                            fontWeight = FontWeight.bold;
                            badgeText = 'O'; // Override indicator
                          } else if (isHoliday) {
                            // Holiday: Red background with red border
                            backgroundColor = Colors.red.withValues(alpha: 0.2);
                            borderColor = Colors.red;
                            textColor = Colors.red[800]!;
                            fontWeight = FontWeight.bold;
                          } else if (isNonWorkingDay) {
                            // Non-working day: Orange background with orange border
                            backgroundColor = Colors.orange.withValues(
                              alpha: 0.2,
                            );
                            borderColor = Colors.orange;
                            textColor = Colors.orange[800]!;
                            fontWeight = FontWeight.w600;
                          } else if (isWorkingDay) {
                            // Working day: Green background with green border
                            backgroundColor = Colors.green.withValues(
                              alpha: 0.1,
                            );
                            borderColor = Colors.green.withValues(alpha: 0.3);
                            textColor = Colors.green[700]!;
                            fontWeight = FontWeight.w600;
                          } else {
                            // Non-working day (weekend): Red background with red border
                            backgroundColor = Colors.red.withValues(alpha: 0.1);
                            borderColor = Colors.red.withValues(alpha: 0.3);
                            textColor = Colors.red[700]!;
                            fontWeight = FontWeight.normal;
                          }

                          return Container(
                            margin: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: backgroundColor,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: borderColor,
                                width: isHoliday || isOverrideWorkingDay
                                    ? 2
                                    : 1, // Thicker border for holidays and overrides
                              ),
                            ),
                            child: Stack(
                              children: [
                                Center(
                                  child: Text(
                                    '${day.day}',
                                    style: TextStyle(
                                      color: textColor,
                                      fontWeight: fontWeight,
                                    ),
                                  ),
                                ),
                                if (badgeText != null)
                                  Positioned(
                                    top: 2,
                                    right: 2,
                                    child: Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: BoxDecoration(
                                        color: borderColor,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Text(
                                        badgeText,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 8,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        }
                        return null; // Use default builder
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Feature Info Banner
          _buildOverrideFeatureInfoBanner(),
          const SizedBox(height: 16),
          // Selected Day Details Panel (replaces dialog)
          if (_selectedDay != null)
            _buildSelectedDayDetailsPanel(_selectedDay!, provider),
          if (_selectedDay != null) const SizedBox(height: 16),
          // Clean Up Holidays Button
          _buildCleanUpHolidaysButton(provider),
          const SizedBox(height: 16),

          // Upcoming Holidays Section
          _buildUpcomingHolidaysSection(provider),
        ],
      ),
    );
  }

  Widget _buildWorkingDaysTab(CompanyCalendarProvider provider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_tabController.index == 1)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppTheme.primary.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                '💼 Working Days & Hours',
                textAlign: TextAlign.center,
                style: AppTheme.bodyMedium.copyWith(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          const SizedBox(height: 16),
          ModernCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Working Days & Hours',
                    style: AppTheme.titleLarge.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Working Hours Display
                  if (provider.calendar != null &&
                      provider.calendar!['workingHours'] != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue[200]!),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            color: Colors.blue[700],
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Working Hours: ',
                            style: AppTheme.bodyMedium.copyWith(
                              fontWeight: FontWeight.w500,
                              color: Colors.grey[700],
                            ),
                          ),
                          Text(
                            '${provider.calendar!['workingHours']['start']} - ${provider.calendar!['workingHours']['end']}',
                            style: AppTheme.bodyMedium.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  _buildWorkingDaysSelector(),
                  const SizedBox(height: 24),
                  _buildWorkingHoursSelector(),
                  const SizedBox(height: 24),
                  _buildRegionalSettings(),
                  const SizedBox(height: 24),
                  _buildGracePeriodsAndOvertime(),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: () => _saveWorkingDays(provider),
                      icon: const Icon(Icons.save, size: 20),
                      label: const Text(
                        'Save Working Days',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkingDaysSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Working Days',
          style: AppTheme.bodyLarge.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children:
                [
                      'Monday',
                      'Tuesday',
                      'Wednesday',
                      'Thursday',
                      'Friday',
                      'Saturday',
                      'Sunday',
                    ]
                    .map(
                      (day) => FilterChip(
                        label: Text(
                          day,
                          style: TextStyle(
                            fontWeight: _selectedWorkingDays.contains(day)
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                        selected: _selectedWorkingDays.contains(day),
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _selectedWorkingDays.add(day);
                            } else {
                              _selectedWorkingDays.remove(day);
                            }
                          });
                        },
                        selectedColor: AppTheme.primary.withValues(alpha: 0.2),
                        checkmarkColor: AppTheme.primary,
                        backgroundColor: Colors.white,
                        side: BorderSide(
                          color: _selectedWorkingDays.contains(day)
                              ? AppTheme.primary
                              : Colors.grey[300]!,
                          width: 1.5,
                        ),
                      ),
                    )
                    .toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildWorkingHoursSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Working Hours',
          style: AppTheme.bodyLarge.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Start Time',
                      style: AppTheme.bodyMedium.copyWith(
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _startTimeController,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        hintText: '09:00',
                        prefixIcon: const Icon(Icons.access_time, size: 20),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                      ),
                      keyboardType: TextInputType.datetime,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'End Time',
                      style: AppTheme.bodyMedium.copyWith(
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _endTimeController,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        hintText: '17:00',
                        prefixIcon: const Icon(Icons.access_time, size: 20),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                      ),
                      keyboardType: TextInputType.datetime,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGracePeriodsAndOvertime() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Grace Periods & Overtime',
          style: AppTheme.bodyLarge.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Text(
          'Configure grace periods for attendance and breaks, and set the overtime threshold.',
          style: AppTheme.bodyMedium.copyWith(color: Colors.grey[600]),
        ),
        const SizedBox(height: 12),
        // Attendance Grace Period
        TextFormField(
          controller: _attendanceGraceController,
          decoration: InputDecoration(
            labelText: 'Attendance Grace Period (minutes)',
            hintText: 'e.g., 15',
            helperText:
                'Allowed minutes after scheduled start time before marking as late',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            prefixIcon: const Icon(Icons.timer_outlined, size: 20),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
          ),
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 16),
        // Break Grace Period
        TextFormField(
          controller: _breakGraceController,
          decoration: InputDecoration(
            labelText: 'Break Grace Period (minutes)',
            hintText: 'e.g., 2',
            helperText:
                'Grace period before auto-ending breaks after maximum duration (0-60 minutes)',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            prefixIcon: const Icon(Icons.pause_circle_outline, size: 20),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
          ),
          keyboardType: TextInputType.number,
          onChanged: (value) {
            final parsed = int.tryParse(value) ?? 2;
            final clamped = parsed.clamp(0, 60);
            if (clamped != parsed) {
              _breakGraceController.text = clamped.toString();
            }
          },
        ),
        const SizedBox(height: 16),
        // Overtime Threshold
        TextFormField(
          controller: _overtimeThresholdController,
          decoration: InputDecoration(
            labelText: 'Overtime Threshold (hours)',
            hintText: 'e.g., 8',
            helperText: 'Hours worked per day before overtime is calculated',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            prefixIcon: const Icon(Icons.access_time, size: 20),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
      ],
    );
  }

  Widget _buildRegionalSettings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Regional Settings',
          style: AppTheme.bodyLarge.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Country',
                      style: AppTheme.bodyMedium.copyWith(
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: _countryController.text.isNotEmpty
                          ? _countryController.text
                          : 'Nepal',
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        prefixIcon: const Icon(Icons.flag, size: 20),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        helperText: _isCountryLocked
                            ? 'Country is set and cannot be changed'
                            : 'Select your country for automatic holiday generation',
                        helperStyle: TextStyle(
                          color: _isCountryLocked
                              ? Colors.orange[700]
                              : Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'Nepal', child: Text('Nepal')),
                        DropdownMenuItem(
                          value: 'United States',
                          child: Text('United States'),
                        ),
                        DropdownMenuItem(value: 'India', child: Text('India')),
                        DropdownMenuItem(
                          value: 'United Kingdom',
                          child: Text('United Kingdom'),
                        ),
                        DropdownMenuItem(
                          value: 'Canada',
                          child: Text('Canada'),
                        ),
                        DropdownMenuItem(
                          value: 'Australia',
                          child: Text('Australia'),
                        ),
                        DropdownMenuItem(
                          value: 'Germany',
                          child: Text('Germany'),
                        ),
                        DropdownMenuItem(
                          value: 'France',
                          child: Text('France'),
                        ),
                        DropdownMenuItem(value: 'Japan', child: Text('Japan')),
                        DropdownMenuItem(value: 'China', child: Text('China')),
                        DropdownMenuItem(
                          value: 'Brazil',
                          child: Text('Brazil'),
                        ),
                        DropdownMenuItem(
                          value: 'Mexico',
                          child: Text('Mexico'),
                        ),
                        DropdownMenuItem(
                          value: 'South Africa',
                          child: Text('South Africa'),
                        ),
                        DropdownMenuItem(
                          value: 'Singapore',
                          child: Text('Singapore'),
                        ),
                        DropdownMenuItem(
                          value: 'Malaysia',
                          child: Text('Malaysia'),
                        ),
                        DropdownMenuItem(
                          value: 'Thailand',
                          child: Text('Thailand'),
                        ),
                        DropdownMenuItem(
                          value: 'Philippines',
                          child: Text('Philippines'),
                        ),
                        DropdownMenuItem(
                          value: 'Indonesia',
                          child: Text('Indonesia'),
                        ),
                        DropdownMenuItem(
                          value: 'Vietnam',
                          child: Text('Vietnam'),
                        ),
                        DropdownMenuItem(
                          value: 'South Korea',
                          child: Text('South Korea'),
                        ),
                      ],
                      onChanged: _isCountryLocked
                          ? null
                          : (String? newValue) {
                              if (newValue != null) {
                                _countryController.text = newValue;
                              }
                            },
                    ),
                    if (_isCountryLocked) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.lock, size: 16, color: Colors.orange[700]),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Country is locked to prevent accidental changes. Contact admin to change.',
                              style: TextStyle(
                                color: Colors.orange[700],
                                fontSize: 12,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              _showResetCountryDialog();
                            },
                            child: const Text(
                              'Reset',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showResetCountryDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Reset Country'),
          content: const Text(
            'This will unlock the country selection and allow you to change it. '
            'Changing the country will replace all existing holidays with the new country\'s holidays. '
            'Are you sure you want to continue?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _isCountryLocked = false;
                });
                Navigator.of(context).pop();
                GlobalNotificationService().showWarning(
                  'Country selection unlocked. You can now change the country.',
                );
              },
              child: const Text('Reset'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHolidaysTab(CompanyCalendarProvider provider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_tabController.index == 2)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppTheme.primary.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                '🎉 Company Holidays',
                textAlign: TextAlign.center,
                style: AppTheme.bodyMedium.copyWith(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          const SizedBox(height: 16),
          ModernCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Company Holidays',
                        style: AppTheme.titleLarge.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          IconButton(
                            onPressed: _forceRefreshHolidays,
                            icon: const Icon(Icons.refresh, size: 20),
                            tooltip: 'Refresh Holidays',
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.blue.withValues(
                                alpha: 0.1,
                              ),
                              foregroundColor: Colors.blue[700],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _showImportHolidaysDialog(),
                              icon: const Icon(Icons.upload_file, size: 18),
                              label: const Text(
                                'Import Holidays',
                                style: TextStyle(fontSize: 14),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _showAddHolidayDialog(),
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text(
                                'Add Holiday',
                                style: TextStyle(fontSize: 14),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildHolidaysList(provider),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHolidaysList(CompanyCalendarProvider provider) {
    final calendar = provider.calendar;
    if (calendar == null || calendar['holidays'] == null) {
      return const Center(child: Text('No holidays configured'));
    }

    // Filter out holidays without IDs - accept either `id` or `_id` from backend
    final holidays = List<Map<String, dynamic>>.from(calendar['holidays'])
        .where((holiday) {
          final idVal = holiday['id'] ?? holiday['_id'];
          return idVal != null && idVal.toString().isNotEmpty;
        })
        .toList();

    if (holidays.isEmpty) {
      return const Center(
        child: Text(
          'No valid holidays found. Please refresh or add new holidays.',
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: holidays.length,
      itemBuilder: (context, index) {
        final holiday = holidays[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: Icon(
              _getHolidayIcon(holiday['type']),
              color: _getHolidayColor(holiday['type']),
            ),
            title: Text(holiday['name'] ?? ''),
            subtitle: Text(
              '${_formatDate(holiday['date'])} • ${holiday['type']} • ${_getGenderDisplayText(holiday['gender'])} • ID: ${holiday['id'] ?? holiday['_id']}',
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (holiday['isRecurring'] == true)
                  const Icon(Icons.repeat, size: 16, color: Colors.blue),
                IconButton(
                  icon: const Icon(Icons.edit, size: 20),
                  onPressed: () => _editHoliday(holiday),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, size: 20),
                  onPressed: () => _deleteHoliday(holiday),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _forceRefreshHolidays() async {
    try {
      // Use a navigator-backed context for provider & scaffold lookups to
      // avoid using the State `context` across async gaps.
      final freshCtx = GlobalNavigator.navigatorKey.currentContext;
      final providerCtx = freshCtx ?? context;
      // `providerCtx` captured synchronously above; safe to use for Provider lookups.
      // ignore: use_build_context_synchronously
      final provider = Provider.of<CompanyCalendarProvider>(
        providerCtx,
        listen: false,
      );
      // ignore: use_build_context_synchronously
      final scaffoldMessenger = ScaffoldMessenger.of(providerCtx);

      // Show loading
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('Refreshing holidays and generating IDs...'),
          backgroundColor: Colors.blue,
        ),
      );

      // Force a fresh fetch from backend
      await provider.fetchCompanyCalendar(_currentYear);

      // Show success
      if (!mounted) return;
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('Holidays refreshed! All holidays now have valid IDs.'),
          backgroundColor: Colors.green,
        ),
      );

      // Refresh the UI
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      final scaffoldMessenger = ScaffoldMessenger.of(context);
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Error refreshing: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildNonWorkingDaysTab(CompanyCalendarProvider provider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_tabController.index == 3)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppTheme.primary.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                '🚫 Non-Working Days',
                textAlign: TextAlign.center,
                style: AppTheme.bodyMedium.copyWith(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          const SizedBox(height: 16),
          ModernCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Non-Working Days',
                        style: AppTheme.titleLarge.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _showAddNonWorkingDayDialog(),
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text(
                            'Add Non-Working Day',
                            style: TextStyle(fontSize: 14),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildNonWorkingDaysList(provider),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNonWorkingDaysList(CompanyCalendarProvider provider) {
    final calendar = provider.calendar;
    if (calendar == null || calendar['nonWorkingDays'] == null) {
      return const Center(child: Text('No non-working days configured'));
    }

    final nonWorkingDays = List<Map<String, dynamic>>.from(
      calendar['nonWorkingDays'],
    );

    if (nonWorkingDays.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Text(
          'No non-working days configured',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: nonWorkingDays.length,
      itemBuilder: (context, index) {
        final nwd = nonWorkingDays[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: Icon(
              _getNonWorkingDayIcon(nwd['type']),
              color: _getNonWorkingDayColor(nwd['type']),
            ),
            title: Text(nwd['name'] ?? nwd['reason'] ?? 'Non-Working Day'),
            subtitle: Text(
              '${_formatDate(nwd['startDate'])} - ${_formatDate(nwd['endDate'])}',
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, size: 20),
                  onPressed: () => _editNonWorkingDay(nwd),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, size: 20),
                  onPressed: () => _deleteNonWorkingDay(nwd),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomNavigation() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _tabController.index,
        onTap: (index) {
          _tabController.animateTo(index);
        },
        selectedItemColor: AppTheme.primary,
        unselectedItemColor: Colors.grey,
        backgroundColor: Colors.white,
        elevation: 0,
        selectedFontSize: 12,
        unselectedFontSize: 12,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: 'Calendar',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.work),
            label: 'Working Days',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.celebration),
            label: 'Holidays',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.block),
            label: 'Non-Working',
          ),
        ],
      ),
    );
  }

  // Side navigation is handled by existing admin navigation structure

  // Helper methods
  IconData _getHolidayIcon(String? type) {
    switch (type) {
      case 'public':
        return Icons.public;
      case 'company':
        return Icons.business;
      case 'optional':
        return Icons.check_circle_outline;
      case 'religious':
        return Icons.church;
      case 'national':
        return Icons.flag;
      default:
        return Icons.celebration;
    }
  }

  Color _getHolidayColor(String? type) {
    switch (type) {
      case 'public':
        return Colors.blue;
      case 'company':
        return Colors.green;
      case 'optional':
        return Colors.orange;
      case 'religious':
        return Colors.purple;
      case 'national':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getNonWorkingDayIcon(String? type) {
    switch (type) {
      case 'maintenance':
        return Icons.build;
      case 'company_event':
        return Icons.event;
      case 'training':
        return Icons.school;
      case 'closure':
        return Icons.block;
      default:
        return Icons.block;
    }
  }

  Color _getNonWorkingDayColor(String? type) {
    switch (type) {
      case 'maintenance':
        return Colors.orange;
      case 'company_event':
        return Colors.blue;
      case 'training':
        return Colors.green;
      case 'closure':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'Unknown';
    try {
      final dateTime = DateTime.parse(date.toString());
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    } catch (e) {
      return 'Invalid Date';
    }
  }

  // Action methods
  Future<void> _saveWorkingDays(CompanyCalendarProvider provider) async {
    try {
      // Use navigator-backed context for provider/scaffold lookups to avoid
      // crossing async gaps with the State `context`.
      final freshCtx = GlobalNavigator.navigatorKey.currentContext;
      final providerCtx = freshCtx ?? context;
      // `providerCtx` captured synchronously above; safe to use for Provider lookups.
      // ignore: use_build_context_synchronously
      final scaffoldMessenger = ScaffoldMessenger.of(providerCtx);

      // Show loading state
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
              SizedBox(width: 16),
              Text('Saving working days configuration...'),
            ],
          ),
          backgroundColor: Colors.blue,
          duration: Duration(seconds: 2),
        ),
      );

      // Get current calendar data to preserve existing holidays and non-working days
      final currentCalendar = provider.calendar;

      if (currentCalendar == null) {
        // Try to load calendar data first
        await provider.fetchCompanyCalendar(_currentYear);
        final reloadedCalendar = provider.calendar;

        if (reloadedCalendar == null) {
          throw Exception(
            'Calendar data not found. Please refresh and try again.',
          );
        }
      }

      // Use the current calendar data (either original or reloaded)
      final calendarToUse = currentCalendar ?? provider.calendar;

      // Prepare data for backend - include existing holidays and non-working days
      final workingDaysData = {
        'year': _currentYear,
        'workingDays': _selectedWorkingDays.toList(),
        'workingHours': {
          'start': _startTimeController.text,
          'end': _endTimeController.text,
        },
        'regionalSettings': {'country': _countryController.text},
        // Preserve existing data
        'holidays': calendarToUse?['holidays'] ?? [],
        'nonWorkingDays': calendarToUse?['nonWorkingDays'] ?? [],
        'leaveYear': calendarToUse?['leaveYear'] ?? {},
        // Use existing company timezone from auth provider
        // Capture timezone from a navigator-backed provider context to avoid
        // crossing async gaps with the widget `context`.
        // ignore: use_build_context_synchronously
        'timezone':
            Provider.of<AuthProvider>(
              providerCtx,
              listen: false,
            ).company?['settings']?['timezone'] ??
            'UTC',
        'updatedAt': DateTime.now().toIso8601String(),
      };

      // Prepare data for backend - include existing holidays and non-working days

      // Save to backend via provider
      final success = await provider.updateCompanyCalendar(workingDaysData);

      // Also save grace periods and overtime threshold to company settings
      if (success) {
        try {
          // Use navigator-backed provider context captured earlier.
          // ignore: use_build_context_synchronously
          final authProvider = Provider.of<AuthProvider>(
            providerCtx,
            listen: false,
          );
          final attendanceGrace =
              int.tryParse(_attendanceGraceController.text) ?? 15;
          final breakGrace = int.tryParse(_breakGraceController.text) ?? 2;
          final overtimeThreshold =
              double.tryParse(_overtimeThresholdController.text) ?? 8.0;

          final settingsData = {
            'settings': {
              'attendanceGracePeriod': attendanceGrace,
              'breakGracePeriod': breakGrace.clamp(0, 60),
              'overtimeThreshold': overtimeThreshold,
            },
          };

          final settingsResponse = await http.put(
            Uri.parse('${ApiConfig.baseUrl}/admin/settings/company'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${authProvider.authToken}',
              'x-company-id': authProvider.user?['companyId'] ?? '',
            },
            body: json.encode(settingsData),
          );

          if (settingsResponse.statusCode == 200) {
            // Refresh company provider via navigator-backed context.
            // ignore: use_build_context_synchronously
            final companyProvider = Provider.of<CompanyProvider>(
              providerCtx,
              listen: false,
            );
            await companyProvider.fetchCurrentCompany();
          }
        } catch (e) {
          Logger.error(
            'CompanyCalendarScreen: Error saving company settings: $e',
          );
          // Don't fail the whole operation if settings save fails
        }
      }

      if (success) {
        if (!mounted) return;
        // Success message
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Working days and settings saved successfully! This will affect:\n• Dashboard attendance schedules\n• Leave request calculations\n• Working hour policies\n• Grace periods and overtime calculations',
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
          ),
        );

        // Refresh calendar data to show updated configuration
        await _loadCalendar();
      } else {
        throw Exception('Failed to save working days');
      }
    } catch (e) {
      if (!mounted) return;
      // Error message
      final scaffoldMessenger = ScaffoldMessenger.of(context);
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Error saving working days: ${e.toString()}',
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showAddHolidayDialog() {
    // Reset form controllers
    _holidayNameController.clear();
    _holidayDateController.clear();
    _holidayDescriptionController.clear();
    _selectedHolidayType = 'company';
    _isHolidayRecurring = false;
    _holidayRecurrencePattern = 'yearly';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Add Company Holiday'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: _holidayNameController,
                      decoration: const InputDecoration(
                        labelText: 'Holiday Name *',
                        hintText: 'e.g., New Year, Company Anniversary',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Holiday name is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _holidayDateController,
                      decoration: const InputDecoration(
                        labelText: 'Date *',
                        hintText: 'Select date',
                        border: OutlineInputBorder(),
                        suffixIcon: Icon(Icons.calendar_today),
                      ),
                      readOnly: true,
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime(_currentYear, 1, 1),
                          lastDate: DateTime(_currentYear, 12, 31),
                        );
                        if (date != null) {
                          setState(() {
                            _holidayDateController.text =
                                '${date.day}/${date.month}/${date.year}';
                          });
                          Logger.debug(
                            'Date picker selected (add): ${date.day}/${date.month}/${date.year}',
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedHolidayType,
                      decoration: const InputDecoration(
                        labelText: 'Holiday Type',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'company',
                          child: Text('Company Holiday'),
                        ),
                        DropdownMenuItem(
                          value: 'public',
                          child: Text('Public Holiday'),
                        ),
                        DropdownMenuItem(
                          value: 'national',
                          child: Text('National Holiday'),
                        ),
                        DropdownMenuItem(
                          value: 'religious',
                          child: Text('Religious Holiday'),
                        ),
                        DropdownMenuItem(
                          value: 'optional',
                          child: Text('Optional Holiday'),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedHolidayType = value!;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _holidayDescriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        hintText: 'Optional description',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Checkbox(
                          value: _isHolidayRecurring,
                          onChanged: (value) {
                            setState(() {
                              _isHolidayRecurring = value!;
                            });
                          },
                        ),
                        const Text('Recurring Holiday'),
                      ],
                    ),
                    if (_isHolidayRecurring) ...[
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: _holidayRecurrencePattern,
                        decoration: const InputDecoration(
                          labelText: 'Recurrence Pattern',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'yearly',
                            child: Text('Yearly'),
                          ),
                          DropdownMenuItem(
                            value: 'monthly',
                            child: Text('Monthly'),
                          ),
                          DropdownMenuItem(
                            value: 'weekly',
                            child: Text('Weekly'),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _holidayRecurrencePattern = value!;
                          });
                        },
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => _addHoliday(context),
                  child: const Text('Add Holiday'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _addHoliday(BuildContext context) async {
    // Get provider at the start so it's available in catch block
    final provider = context.read<CompanyCalendarProvider>();

    // Validate form
    if (_holidayNameController.text.isEmpty ||
        _holidayDateController.text.isEmpty) {
      if (mounted) {
        GlobalNotificationService().showError(
          'Please fill in all required fields',
        );
      }
      return;
    }

    try {
      // Parse date - format is day/month/year
      final dateParts = _holidayDateController.text.split('/');
      if (dateParts.length != 3) {
        throw Exception(
          'Invalid date format. Please select a date using the date picker.',
        );
      }
      final day = int.parse(dateParts[0]);
      final month = int.parse(dateParts[1]);
      final year = int.parse(dateParts[2]);

      // Create date in UTC to avoid timezone issues
      final holidayDate = DateTime.utc(year, month, day, 0, 0, 0);

      // Debug: Log the date being sent
      Logger.debug(
        'Holiday date - Input: ${_holidayDateController.text}, Parsed: day=$day, month=$month, year=$year',
      );
      Logger.debug(
        'Holiday date - UTC DateTime: $holidayDate, ISO String: ${holidayDate.toIso8601String()}',
      );

      // Prepare holiday data
      final holidayData = {
        'name': _holidayNameController.text,
        'date': holidayDate.toIso8601String(),
        'type': _selectedHolidayType,
        'gender': _selectedHolidayGender,
        'description': _holidayDescriptionController.text.isNotEmpty
            ? _holidayDescriptionController.text
            : null,
        'isRecurring': _isHolidayRecurring,
        'recurrencePattern': _isHolidayRecurring
            ? _holidayRecurrencePattern
            : null,
        'createdAt': DateTime.now().toIso8601String(),
      };

      // Get current calendar data
      final currentCalendar = provider.calendar;
      if (currentCalendar == null) {
        throw Exception(
          'Calendar data not found. Please refresh and try again.',
        );
      }

      // Add new holiday to the holidays list
      final holidays = List<Map<String, dynamic>>.from(
        currentCalendar['holidays'] ?? [],
      );
      holidays.add(holidayData);

      // Debug: Log the holiday data being sent
      Logger.debug('=== HOLIDAY ADD DEBUG ===');
      Logger.debug('New holiday data: ${holidayData.toString()}');
      Logger.debug('Total holidays being sent: ${holidays.length}');
      Logger.debug('First 3 holidays:');
      for (int i = 0; i < holidays.length && i < 3; i++) {
        Logger.debug(
          '  Holiday $i: name=${holidays[i]['name']}, date=${holidays[i]['date']}, id=${holidays[i]['id'] ?? holidays[i]['_id'] ?? 'NO ID'}',
        );
      }
      Logger.debug('========================');

      // Prepare calendar update data
      final calendarUpdateData = {
        'year': _currentYear,
        'workingDays': currentCalendar['workingDays'] ?? [],
        'workingHours': currentCalendar['workingHours'] ?? {},
        'holidays': holidays,
        'nonWorkingDays': currentCalendar['nonWorkingDays'] ?? [],
        'leaveYear': currentCalendar['leaveYear'] ?? {},
        'timezone': currentCalendar['timezone'] ?? 'UTC',
      };

      // Update the entire calendar
      // Capture a navigator-backed context synchronously to avoid using the
      // function `context` across async gaps when popping or navigating later.
      final freshCtx = GlobalNavigator.navigatorKey.currentContext;
      final navigatorCtx = freshCtx ?? context;
      final navigator = Navigator.of(navigatorCtx);

      final success = await provider.updateCompanyCalendar(calendarUpdateData);

      if (success) {
        navigator.pop();
        if (mounted) {
          GlobalNotificationService().showSuccess(
            'Holiday "${_holidayNameController.text}" added successfully!',
          );
        }

        // Refresh calendar to show new holiday
        await _loadCalendar();
      } else {
        // Get the error message from the provider
        final errorMessage = provider.error ?? 'Failed to add holiday';
        // Clear the error immediately to prevent error screen from showing
        provider.clearError();
        throw Exception(errorMessage);
      }
    } catch (e) {
      if (mounted) {
        // Extract the actual error message, removing "Exception: " prefix if present
        String errorMsg = e.toString();
        if (errorMsg.startsWith('Exception: ')) {
          errorMsg = errorMsg.substring(11);
        }
        // Clear any provider error before showing toast to prevent error screen from appearing
        provider.clearError();
        GlobalNotificationService().showError(errorMsg);
      }
    }
  }

  void _editHoliday(Map<String, dynamic> holiday) {
    // Pre-populate form with existing data
    _holidayNameController.text = holiday['name'] ?? '';
    _holidayDateController.text = _formatDate(holiday['date']);
    _holidayDescriptionController.text = holiday['description'] ?? '';
    _selectedHolidayType = holiday['type'] ?? 'company';
    _isHolidayRecurring = holiday['isRecurring'] ?? false;
    _holidayRecurrencePattern = holiday['recurrencePattern'] ?? 'yearly';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Edit Holiday'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: _holidayNameController,
                      decoration: const InputDecoration(
                        labelText: 'Holiday Name *',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _holidayDateController,
                      decoration: const InputDecoration(
                        labelText: 'Date *',
                        border: OutlineInputBorder(),
                        suffixIcon: Icon(Icons.calendar_today),
                      ),
                      readOnly: true,
                      onTap: () async {
                        // Parse the holiday date and extract only the date part (ignore time)
                        final holidayDate = DateTime.parse(holiday['date']);
                        final dateOnly = DateTime(
                          holidayDate.year,
                          holidayDate.month,
                          holidayDate.day,
                        );

                        final date = await showDatePicker(
                          context: context,
                          initialDate: dateOnly,
                          firstDate: DateTime(_currentYear, 1, 1),
                          lastDate: DateTime(_currentYear, 12, 31),
                        );
                        if (date != null) {
                          setState(() {
                            _holidayDateController.text =
                                '${date.day}/${date.month}/${date.year}';
                          });
                          Logger.debug(
                            'Date picker selected (edit): ${date.day}/${date.month}/${date.year}',
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedHolidayType,
                      decoration: const InputDecoration(
                        labelText: 'Holiday Type',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'company',
                          child: Text('Company Holiday'),
                        ),
                        DropdownMenuItem(
                          value: 'public',
                          child: Text('Public Holiday'),
                        ),
                        DropdownMenuItem(
                          value: 'national',
                          child: Text('National Holiday'),
                        ),
                        DropdownMenuItem(
                          value: 'religious',
                          child: Text('Religious Holiday'),
                        ),
                        DropdownMenuItem(
                          value: 'optional',
                          child: Text('Optional Holiday'),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedHolidayType = value!;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _holidayDescriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Checkbox(
                          value: _isHolidayRecurring,
                          onChanged: (value) {
                            setState(() {
                              _isHolidayRecurring = value!;
                            });
                          },
                        ),
                        const Text('Recurring Holiday'),
                      ],
                    ),
                    if (_isHolidayRecurring) ...[
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: _holidayRecurrencePattern,
                        decoration: const InputDecoration(
                          labelText: 'Recurrence Pattern',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'yearly',
                            child: Text('Yearly'),
                          ),
                          DropdownMenuItem(
                            value: 'monthly',
                            child: Text('Monthly'),
                          ),
                          DropdownMenuItem(
                            value: 'weekly',
                            child: Text('Weekly'),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _holidayRecurrencePattern = value!;
                          });
                        },
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => _updateHoliday(context, holiday),
                  child: const Text('Update Holiday'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _updateHoliday(
    BuildContext context,
    Map<String, dynamic> holiday,
  ) async {
    // Get provider at the start so it's available in catch block
    final provider = context.read<CompanyCalendarProvider>();

    try {
      // Parse date - format is day/month/year
      final dateParts = _holidayDateController.text.split('/');
      if (dateParts.length != 3) {
        throw Exception(
          'Invalid date format. Please select a date using the date picker.',
        );
      }
      final day = int.parse(dateParts[0]);
      final month = int.parse(dateParts[1]);
      final year = int.parse(dateParts[2]);

      // Create date in UTC to avoid timezone issues
      final holidayDate = DateTime.utc(year, month, day, 0, 0, 0);

      // Prepare updated holiday data - preserve the original ID
      final updatedHolidayData = {
        'id': holiday['id'], // CRITICAL: Preserve the original ID
        '_id': holiday['_id'], // CRITICAL: Preserve the original _ID
        'name': _holidayNameController.text,
        'date': holidayDate.toIso8601String(),
        'type': _selectedHolidayType,
        'gender': _selectedHolidayGender,
        'description': _holidayDescriptionController.text.isNotEmpty
            ? _holidayDescriptionController.text
            : null,
        'isRecurring': _isHolidayRecurring,
        'recurrencePattern':
            holiday['recurrencePattern'] ??
            'yearly', // Preserve existing pattern
        'isActive':
            holiday['isActive'] ?? true, // Preserve existing active status
        'updatedAt': DateTime.now().toIso8601String(),
        // Preserve multi-day holiday fields if they exist
        if (holiday['startDate'] != null) 'startDate': holiday['startDate'],
        if (holiday['endDate'] != null) 'endDate': holiday['endDate'],
      };

      // Get provider and update calendar
      final provider = context.read<CompanyCalendarProvider>();

      // Get current calendar data
      final currentCalendar = provider.calendar;
      if (currentCalendar == null) {
        throw Exception(
          'Calendar data not found. Please refresh and try again.',
        );
      }

      // Find and update the specific holiday in the holidays list
      final holidays = List<Map<String, dynamic>>.from(
        currentCalendar['holidays'] ?? [],
      );
      bool holidayFound = false;

      for (int i = 0; i < holidays.length; i++) {
        // Try to match by ID first, then by name and date
        if ((holidays[i]['id'] == holiday['id']) ||
            (holidays[i]['_id'] == holiday['_id'])) {
          holidays[i] = updatedHolidayData;
          holidayFound = true;
          break;
        } else if (holidays[i]['name'] == holiday['name'] &&
            holidays[i]['date'] == holiday['date']) {
          holidays[i] = updatedHolidayData;
          holidayFound = true;
          break;
        }
      }

      if (!holidayFound) {
        throw Exception(
          'Holiday not found in calendar. Please refresh and try again.',
        );
      }

      // Prepare calendar update data
      final calendarUpdateData = {
        'year': _currentYear,
        'workingDays': currentCalendar['workingDays'] ?? [],
        'workingHours': currentCalendar['workingHours'] ?? {},
        'holidays': holidays,
        'nonWorkingDays': currentCalendar['nonWorkingDays'] ?? [],
        'leaveYear': currentCalendar['leaveYear'] ?? {},
        'timezone': currentCalendar['timezone'] ?? 'UTC',
      };

      // Update the entire calendar
      final success = await provider.updateCompanyCalendar(calendarUpdateData);

      if (success) {
        final freshContext = GlobalNavigator.navigatorKey.currentContext;
        if (freshContext != null) {
          // `freshContext` captured from GlobalNavigator.navigatorKey.currentContext.
          // Using it immediately for pop is safe; silence the lint with a narrow ignore.
          // ignore: use_build_context_synchronously
          Navigator.of(freshContext).pop();
        }
        // Check if widget is still mounted before showing snackbar
        if (mounted) {
          GlobalNotificationService().showSuccess(
            'Holiday "${_holidayNameController.text}" updated successfully!',
          );
        }

        // Refresh calendar to show updated holiday
        await _loadCalendar();
      } else {
        // Get the error message from the provider
        final errorMessage = provider.error ?? 'Failed to update holiday';
        // Clear the error immediately to prevent error screen from showing
        provider.clearError();
        throw Exception(errorMessage);
      }
    } catch (e) {
      // Check if widget is still mounted before showing snackbar
      if (mounted) {
        // Extract the actual error message, removing "Exception: " prefix if present
        String errorMsg = e.toString();
        if (errorMsg.startsWith('Exception: ')) {
          errorMsg = errorMsg.substring(11);
        }
        // Clear any provider error before showing toast to prevent error screen from appearing
        provider.clearError();
        GlobalNotificationService().showError(errorMsg);
      }
    }
  }

  void _deleteHoliday(Map<String, dynamic> holiday) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Holiday'),
          content: Text(
            'Are you sure you want to delete "${holiday['name']}"?\n\n'
            'This holiday will be removed from:\n'
            '• Company calendar\n'
            '• Employee leave request calendar\n'
            '• Dashboard attendance calculations',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => _confirmDeleteHoliday(context, holiday),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text(
                'Delete',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmDeleteHoliday(
    BuildContext context,
    Map<String, dynamic> holiday,
  ) async {
    try {
      Navigator.of(context).pop(); // Close confirmation dialog

      // Get provider and update calendar
      final provider = context.read<CompanyCalendarProvider>();

      // Get current calendar data
      final currentCalendar = provider.calendar;
      if (currentCalendar == null) {
        throw Exception(
          'Calendar data not found. Please refresh and try again.',
        );
      }

      // Remove the specific holiday from the holidays list
      final holidays = List<Map<String, dynamic>>.from(
        currentCalendar['holidays'] ?? [],
      );
      bool holidayFound = false;

      holidays.removeWhere((h) {
        // Try to match by ID first (most reliable), then by name and date
        if ((h['id'] != null &&
                holiday['id'] != null &&
                h['id'] == holiday['id']) ||
            (h['_id'] != null &&
                holiday['_id'] != null &&
                h['_id'] == holiday['_id'])) {
          holidayFound = true;
          return true; // Remove this holiday
        }
        // Fallback: match by name and date (for holidays without IDs)
        if (h['name'] == holiday['name'] && h['date'] == holiday['date']) {
          holidayFound = true;
          return true; // Remove this holiday
        }
        return false;
      });

      if (!holidayFound) {
        throw Exception(
          'Holiday not found in calendar. Please refresh and try again.',
        );
      }

      // Prepare calendar update data
      final calendarUpdateData = {
        'year': _currentYear,
        'workingDays': currentCalendar['workingDays'] ?? [],
        'workingHours': currentCalendar['workingHours'] ?? {},
        'holidays': holidays,
        'nonWorkingDays': currentCalendar['nonWorkingDays'] ?? [],
        'leaveYear': currentCalendar['leaveYear'] ?? {},
        'timezone': currentCalendar['timezone'] ?? 'UTC',
      };

      // Update the entire calendar
      final success = await provider.updateCompanyCalendar(calendarUpdateData);

      if (success) {
        // Check if widget is still mounted before showing snackbar
        if (mounted) {
          GlobalNotificationService().showSuccess(
            'Holiday "${holiday['name']}" deleted successfully!',
          );
        }

        // Refresh calendar to show updated data
        await _loadCalendar();
      } else {
        throw Exception('Failed to delete holiday');
      }
    } catch (e) {
      // Check if widget is still mounted before showing snackbar
      if (mounted) {
        GlobalNotificationService().showError(
          'Error deleting holiday: ${e.toString()}',
        );
      }
    }
  }

  void _showAddNonWorkingDayDialog() {
    final formKey = GlobalKey<FormState>();
    DateTime? selectedDate;
    String reason = '';
    String description = '';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Add Non-Working Day'),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Date picker
                    ListTile(
                      leading: const Icon(Icons.calendar_today),
                      title: Text(
                        selectedDate != null
                            ? DateFormat('yyyy-MM-dd').format(selectedDate!)
                            : 'Select Date',
                      ),
                      trailing: const Icon(Icons.arrow_drop_down),
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                        );
                        if (date != null) {
                          setState(() {
                            selectedDate = date;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    // Reason field
                    TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'Reason',
                        hintText: 'e.g., Company Event, Maintenance',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) => reason = value,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter a reason';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    // Description field
                    TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'Description (Optional)',
                        hintText:
                            'Additional details about this non-working day',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                      onChanged: (value) => description = value,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (formKey.currentState!.validate() &&
                        selectedDate != null) {
                      // Capture a navigator-backed context and provider context synchronously
                      final freshCtx =
                          GlobalNavigator.navigatorKey.currentContext;
                      final providerCtx = freshCtx ?? context;
                      final navigator = Navigator.of(providerCtx);
                      try {
                        // `providerCtx` captured synchronously; safe to use for Provider lookups.
                        // ignore: use_build_context_synchronously
                        final provider = Provider.of<CompanyCalendarProvider>(
                          providerCtx,
                          listen: false,
                        );
                        await provider.addNonWorkingDay(
                          date: selectedDate!,
                          reason: reason,
                          description: description.isNotEmpty
                              ? description
                              : null,
                        );

                        // Check for errors from the provider
                        if (provider.error != null) {
                          if (mounted) {
                            final errorMsg = provider.error!;
                            // Clear the error immediately before showing toast to prevent error screen from appearing
                            provider.clearError();
                            GlobalNotificationService().showError(errorMsg);
                          }
                        } else {
                          if (mounted) {
                            navigator.pop();
                            GlobalNotificationService().showSuccess(
                              'Non-working day added successfully',
                            );
                            // Force UI refresh to show the new non-working day
                            await Future.delayed(
                              const Duration(milliseconds: 300),
                            );
                            setState(() {});
                          }
                        }
                      } catch (e) {
                        if (mounted) {
                          // Extract the actual error message, removing "Exception: " prefix if present
                          String errorMsg = e.toString();
                          if (errorMsg.startsWith('Exception: ')) {
                            errorMsg = errorMsg.substring(11);
                          }
                          // Clear any provider error before showing toast to prevent error screen
                          // Use navigator-backed provider context captured earlier.
                          // ignore: use_build_context_synchronously
                          final currentProvider =
                              Provider.of<CompanyCalendarProvider>(
                                providerCtx,
                                listen: false,
                              );
                          currentProvider.clearError();
                          GlobalNotificationService().showError(
                            'Error adding non-working day: $errorMsg',
                          );
                        }
                      }
                    } else if (selectedDate == null) {
                      if (mounted) {
                        GlobalNotificationService().showWarning(
                          'Please select a date',
                        );
                      }
                    }
                  },
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _editNonWorkingDay(Map<String, dynamic> nwd) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        DateTime? selectedDate = DateTime.tryParse(nwd['startDate']);
        final formKey = GlobalKey<FormState>();
        final reasonController = TextEditingController(text: nwd['name'] ?? '');
        final descriptionController = TextEditingController(
          text: nwd['reason'] ?? '',
        );

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Edit Non-Working Day'),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      leading: const Icon(Icons.calendar_today),
                      title: Text(
                        selectedDate != null
                            ? '${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}'
                            : 'Select Date',
                      ),
                      trailing: const Icon(Icons.arrow_drop_down),
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: selectedDate ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                        );
                        if (date != null) {
                          setState(() {
                            selectedDate = date;
                          });
                        }
                      },
                    ),
                    TextFormField(
                      controller: reasonController,
                      decoration: const InputDecoration(
                        labelText: 'Reason *',
                        hintText: 'e.g., Company Event, Maintenance',
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Reason is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Description (Optional)',
                        hintText: 'Additional details...',
                      ),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (formKey.currentState!.validate() &&
                        selectedDate != null) {
                      Navigator.of(context).pop();
                      await _updateNonWorkingDay(
                        nwd,
                        selectedDate!,
                        reasonController.text,
                        descriptionController.text,
                      );
                    } else if (selectedDate == null) {
                      if (mounted) {
                        GlobalNotificationService().showWarning(
                          'Please select a date',
                        );
                      }
                    }
                  },
                  child: const Text('Update'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _deleteNonWorkingDay(Map<String, dynamic> nwd) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Non-Working Day'),
          content: Text('Are you sure you want to delete "${nwd['name']}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => _confirmDeleteNonWorkingDay(context, nwd),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _updateNonWorkingDay(
    Map<String, dynamic> originalNwd,
    DateTime newDate,
    String newReason,
    String newDescription,
  ) async {
    // Get provider at the start so it's available in catch block
    final provider = context.read<CompanyCalendarProvider>();

    try {
      // Get current calendar data
      final currentCalendar = provider.calendar;
      if (currentCalendar == null) {
        throw Exception(
          'Calendar data not found. Please refresh and try again.',
        );
      }

      // Find and update the specific non-working day
      final nonWorkingDays = List<Map<String, dynamic>>.from(
        currentCalendar['nonWorkingDays'] ?? [],
      );
      bool nwdFound = false;

      for (int i = 0; i < nonWorkingDays.length; i++) {
        final nwd = nonWorkingDays[i];
        // Try to match by name and start date
        if (nwd['name'] == originalNwd['name'] &&
            nwd['startDate'] == originalNwd['startDate']) {
          // Convert to UTC first, then toIso8601String() will already include 'Z'
          final utcDate = newDate.toUtc();
          nonWorkingDays[i] = {
            'name': newReason,
            'startDate': utcDate.toIso8601String(),
            'endDate': utcDate.toIso8601String(),
            'reason': newDescription,
            'type': 'company_event',
            'isActive': true,
          };
          nwdFound = true;
          break;
        }
      }

      if (!nwdFound) {
        throw Exception(
          'Non-working day not found in calendar. Please refresh and try again.',
        );
      }

      // Prepare calendar update data
      final calendarUpdateData = {
        'year': _currentYear,
        'workingDays': currentCalendar['workingDays'] ?? [],
        'workingHours': currentCalendar['workingHours'] ?? {},
        'holidays': currentCalendar['holidays'] ?? [],
        'nonWorkingDays': nonWorkingDays,
        'leaveYear': currentCalendar['leaveYear'] ?? {},
        'timezone': currentCalendar['timezone'] ?? 'UTC',
      };

      // Update the entire calendar
      final success = await provider.updateCompanyCalendar(calendarUpdateData);

      if (success) {
        GlobalNotificationService().showSuccess(
          'Non-working day updated successfully',
        );
      } else {
        final errorMsg = provider.error ?? 'Failed to update non-working day';
        GlobalNotificationService().showError(errorMsg);
        // Clear the provider error after showing toast to prevent error screen from appearing
        provider.clearError();
      }
    } catch (e) {
      GlobalNotificationService().showError(
        'Error updating non-working day: $e',
      );
      // Clear any provider error after showing toast
      provider.clearError();
    }
  }

  Future<void> _confirmDeleteNonWorkingDay(
    BuildContext context,
    Map<String, dynamic> nwd,
  ) async {
    // Get provider at the start so it's available in catch block
    final provider = context.read<CompanyCalendarProvider>();

    try {
      Navigator.of(context).pop(); // Close confirmation dialog

      // Get current calendar data
      final currentCalendar = provider.calendar;
      if (currentCalendar == null) {
        throw Exception(
          'Calendar data not found. Please refresh and try again.',
        );
      }

      // Remove the specific non-working day from the list
      final nonWorkingDays = List<Map<String, dynamic>>.from(
        currentCalendar['nonWorkingDays'] ?? [],
      );
      bool nwdFound = false;

      nonWorkingDays.removeWhere((item) {
        // Try to match by name and start date
        if (item['name'] == nwd['name'] &&
            item['startDate'] == nwd['startDate']) {
          nwdFound = true;
          return true; // Remove this non-working day
        }
        return false;
      });

      if (!nwdFound) {
        throw Exception(
          'Non-working day not found in calendar. Please refresh and try again.',
        );
      }

      // Prepare calendar update data
      final calendarUpdateData = {
        'year': _currentYear,
        'workingDays': currentCalendar['workingDays'] ?? [],
        'workingHours': currentCalendar['workingHours'] ?? {},
        'holidays': currentCalendar['holidays'] ?? [],
        'nonWorkingDays': nonWorkingDays,
        'leaveYear': currentCalendar['leaveYear'] ?? {},
        'timezone': currentCalendar['timezone'] ?? 'UTC',
      };

      // Update the entire calendar
      final success = await provider.updateCompanyCalendar(calendarUpdateData);

      if (success) {
        GlobalNotificationService().showSuccess(
          'Non-working day deleted successfully',
        );
      } else {
        final errorMsg = provider.error ?? 'Failed to delete non-working day';
        GlobalNotificationService().showError(errorMsg);
        // Clear the provider error after showing toast to prevent error screen from appearing
        provider.clearError();
      }
    } catch (e) {
      GlobalNotificationService().showError(
        'Error deleting non-working day: $e',
      );
      // Clear any provider error after showing toast
      provider.clearError();
    }
  }

  void _showImportHolidaysDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Import Holidays'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Import holidays from Excel file. The file should have the following columns:',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '• Name (required)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '• Date (required) - Format: DD/MM/YYYY',
                      style: TextStyle(fontSize: 12),
                    ),
                    Text(
                      '• Type (optional) - public, company, optional, religious, national',
                      style: TextStyle(fontSize: 12),
                    ),
                    Text(
                      '• Gender (optional) - all, male, female',
                      style: TextStyle(fontSize: 12),
                    ),
                    Text(
                      '• Description (optional)',
                      style: TextStyle(fontSize: 12),
                    ),
                    Text(
                      '• Is Recurring (optional) - true/false/yes/no/1/0',
                      style: TextStyle(fontSize: 12),
                    ),
                    Text(
                      '• Recurrence Pattern (optional) - yearly, monthly, weekly',
                      style: TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Note: For multi-day holidays, use "StartDate to EndDate" format',
                      style: TextStyle(
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Note: Holiday types are automatically converted to lowercase',
                      style: TextStyle(
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _downloadExcelTemplate(),
                    icon: const Icon(Icons.download),
                    label: const Text('Download Template'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => _selectExcelFile(),
              child: const Text('Select File'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _downloadExcelTemplate() async {
    try {
      // Create CSV template content
      final csvData = [
        [
          'Name',
          'Date',
          'Type',
          'Gender',
          'Description',
          'Is Recurring',
          'Recurrence Pattern',
        ],
        [
          'New Year',
          '01/01/2025',
          'public',
          'all',
          'New Year Celebration',
          'true',
          'yearly',
        ],
        [
          'Company Anniversary',
          '15/03/2025',
          'company',
          'all',
          'Company founding day',
          'true',
          'yearly',
        ],
        [
          'Independence Day',
          '04/07/2025',
          'national',
          'all',
          'National holiday',
          'true',
          'yearly',
        ],
        [
          'International Women\'s Day',
          '08/03/2025',
          'public',
          'female',
          'Women\'s day celebration',
          'true',
          'yearly',
        ],
        [
          'Multi-day Festival',
          '01/01/2025 to 03/01/2025',
          'religious',
          'all',
          'Extended festival period',
          'true',
          'yearly',
        ],
        [
          'Company Retreat',
          '2025-06-15 to 2025-06-17',
          'company',
          'all',
          'Annual company retreat',
          'true',
          'yearly',
        ],
        [
          'Optional Holiday',
          '25/12/2025',
          'optional',
          'all',
          'Christmas Day',
          'false',
          '',
        ],
      ];

      // Convert to CSV string directly
      final csvText = const ListToCsvConverter().convert(csvData);

      if (kIsWeb) {
        // For web, create a data URL and trigger download
        final bytes = utf8.encode(csvText);
        final base64String = base64.encode(bytes);
        final dataUrl = 'data:text/csv;base64,$base64String';

        // Create a temporary link and trigger download
        final uri = Uri.parse(dataUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
        } else {
          // Fallback: show content in dialog
          _showCSVContentDialog(csvText);
        }
      } else {
        // For mobile, use share intent approach (Google Play compliant)
        try {
          // Create temporary file
          final tempDir = await getTemporaryDirectory();
          final file = File('${tempDir.path}/holidays_template.csv');
          await file.writeAsString(csvText);

          // Re-acquire a fresh navigator-backed context after async work
          final freshCtx = GlobalNavigator.navigatorKey.currentContext;
          if (freshCtx != null) {
            await _shareFile(freshCtx, file, 'holidays_template.csv');
          } else {
            GlobalNotificationService().showError(
              'Unable to share file: UI context unavailable.',
            );
          }
        } catch (e) {
          // Fallback: show content in dialog
          _showCSVContentDialog(csvText);
        }
      }

      // Prefer popping using a fresh navigator context captured after async work
      final postPopContext = GlobalNavigator.navigatorKey.currentContext;
      if (postPopContext != null) {
        // Use navigatorKey.currentState to pop without a BuildContext
        GlobalNavigator.navigatorKey.currentState?.pop();
      }
    } catch (e) {
      GlobalNotificationService().showError('Error downloading template: $e');
    }
  }

  Future<void> _selectExcelFile() async {
    try {
      // Close any open dialogs first
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }

      // Check privacy settings before accessing storage
      final privacyService = PrivacyService.instance;
      if (!await privacyService.shouldAllowStorageAccess()) {
        GlobalNotificationService().showError(
          'Storage access is disabled in Privacy Settings. Please enable it to import files.',
        );
        // Use navigatorKey.currentState to safely pop without reusing BuildContext
        if (GlobalNavigator.navigatorKey.currentState?.canPop() ?? false) {
          GlobalNavigator.navigatorKey.currentState?.pop();
        }
        return;
      }

      // Show file picker
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'xlsx', 'xls'],
        allowMultiple: false,
        withData: true, // Ensure file content is read
        withReadStream:
            false, // Use withData instead of stream for better reliability
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;

        // Process the file

        // Show processing message
        GlobalNotificationService().showInfo('Processing ${file.name}...');

        // Validate file before processing
        if (file.bytes == null && file.path == null) {
          GlobalNotificationService().showError(
            'Unable to read file. Please try selecting the file again.',
          );
          return;
        }

        // Process the file
        try {
          await _processImportedFile(file);
        } catch (e) {
          // Error handling is done in _processImportedFile
        }
      }
    } catch (e) {
      GlobalNotificationService().showError('Error selecting file: $e');
    }
  }

  Future<void> _processImportedFile(PlatformFile file) async {
    try {
      if (file.extension?.toLowerCase() == 'csv') {
        await _processCSVFile(file);
      } else {
        // For Excel files, we'll show a message to convert to CSV first
        GlobalNotificationService().showWarning(
          'Please convert Excel files to CSV format for import',
        );
      }
    } catch (e) {
      GlobalNotificationService().showError('Error processing file: $e');
    }
  }

  Future<void> _processCSVFile(PlatformFile file) async {
    // Capture provider/context before any awaits to avoid using the
    // original BuildContext across async gaps which the analyzer warns about.
    final preCapturedContext = GlobalNavigator.navigatorKey.currentContext;
    final CompanyCalendarProvider? preCapturedProvider =
        preCapturedContext != null
        ? Provider.of<CompanyCalendarProvider>(
            preCapturedContext,
            listen: false,
          )
        : null;

    try {
      List<int> cleanBytes;

      // Check if file has content
      if (file.bytes == null || file.bytes!.isEmpty) {
        // Try to read the file from path as fallback
        if (file.path != null) {
          try {
            final fileObj = File(file.path!);
            if (await fileObj.exists()) {
              cleanBytes = await fileObj.readAsBytes();
            } else {
              throw Exception('File not found at path: ${file.path}');
            }
          } catch (e) {
            throw Exception(
              'Unable to read file content. Please try selecting the file again or ensure the file is not corrupted. Error: $e',
            );
          }
        } else {
          throw Exception(
            'File content could not be read. Please try selecting the file again or check if the file is accessible.',
          );
        }
      } else {
        cleanBytes = List<int>.from(file.bytes!);
      }

      // Additional validation - check if file size is reasonable
      if (cleanBytes.isEmpty) {
        throw Exception(
          'File appears to be empty. Please check the file and try again.',
        );
      }

      // Check for UTF-8 BOM (EF BB BF)
      if (cleanBytes.length >= 3 &&
          cleanBytes[0] == 0xEF &&
          cleanBytes[1] == 0xBB &&
          cleanBytes[2] == 0xBF) {
        cleanBytes = cleanBytes.sublist(3);
        // 'Removed UTF-8 BOM from file');
      }

      // Check for UTF-16 LE BOM (FF FE)
      if (cleanBytes.length >= 2 &&
          cleanBytes[0] == 0xFF &&
          cleanBytes[1] == 0xFE) {
        cleanBytes = cleanBytes.sublist(2);
        // 'Removed UTF-16 LE BOM from file');
      }

      // Check for UTF-16 BE BOM (FE FF)
      if (cleanBytes.length >= 2 &&
          cleanBytes[0] == 0xFE &&
          cleanBytes[1] == 0xFF) {
        cleanBytes = cleanBytes.sublist(2);
        // 'Removed UTF-16 BE BOM from file');
      }

      // Parse CSV content from clean bytes
      final csvString = String.fromCharCodes(cleanBytes);

      // Additional string-level BOM removal as fallback
      final cleanCsvString = csvString.replaceFirst(RegExp(r'^\uFEFF'), '');

      final csvTable = const CsvToListConverter().convert(cleanCsvString);

      if (csvTable.length < 2) {
        throw Exception(
          'CSV file must have at least a header row and one data row. Found: ${csvTable.length} rows',
        );
      }

      // Extract headers and data
      final headers = List<String>.from(csvTable[0]);
      final dataRows = csvTable.skip(1).toList();

      // Clean headers to remove any remaining BOM characters
      final cleanHeaders = headers.map((header) {
        // Remove BOM characters from individual headers
        return header
            .replaceFirst(RegExp(r'^\uFEFF'), '') // Remove UTF-8 BOM
            .replaceFirst(RegExp(r'^\uFFFE'), '') // Remove UTF-16 LE BOM
            .replaceFirst(RegExp(r'^\uFFFE'), '') // Remove UTF-16 BE BOM
            .trim();
      }).toList();

      // Debug: Log headers for troubleshooting
      // 'Original CSV Headers: ${headers.join(', ')}');
      // 'Cleaned CSV Headers: ${cleanHeaders.join(', ')}');
      // 'Number of data rows: ${dataRows.length}');

      // Validate headers - check for required columns (case-insensitive)
      final requiredHeaders = ['Name', 'Date'];
      final headerMap =
          <String, String>{}; // Map normalized header to actual header

      for (int i = 0; i < cleanHeaders.length; i++) {
        final cleanHeader = cleanHeaders[i];
        final normalizedHeader = cleanHeader.toLowerCase();
        headerMap[normalizedHeader] = cleanHeader;

        // Also map the original header for data processing
        headerMap[headers[i].trim().toLowerCase()] = cleanHeader;
      }

      // Check if required headers exist (case-insensitive)
      for (final requiredHeader in requiredHeaders) {
        final normalizedRequired = requiredHeader.toLowerCase();
        if (!headerMap.containsKey(normalizedRequired)) {
          throw Exception(
            'Missing required header: $requiredHeader. Found headers: ${cleanHeaders.join(', ')}',
          );
        }
      }

      // Get provider and current calendar (use pre-captured provider)
      if (preCapturedProvider == null) {
        throw Exception('Unable to import holidays: UI context unavailable.');
      }
      final provider = preCapturedProvider;
      final currentCalendar = provider.calendar;
      if (currentCalendar == null) {
        throw Exception(
          'Calendar data not found. Please refresh and try again.',
        );
      }

      // Get existing holidays
      final existingHolidays = List<Map<String, dynamic>>.from(
        currentCalendar['holidays'] ?? [],
      );
      final newHolidays = <Map<String, dynamic>>[];

      // Process each row
      int successCount = 0;
      int errorCount = 0;
      final errors = <String>[];

      for (int i = 0; i < dataRows.length; i++) {
        try {
          final row = dataRows[i];
          final rowData = <String, dynamic>{};

          // Map CSV columns to data using normalized headers
          for (int j = 0; j < headers.length && j < row.length; j++) {
            final header = headers[j];
            final value = row[j]?.toString() ?? '';
            final normalizedHeader = header.trim().toLowerCase();

            switch (normalizedHeader) {
              case 'name':
                rowData['name'] = value;
                break;
              case 'date':
                // Handle range dates (e.g., "2025-01-01 to 2025-01-03")
                // Check for various "to" patterns with different spacing

                bool isDateRange =
                    value.contains(' to ') ||
                    value.contains('to ') ||
                    value.contains(' to') ||
                    value.contains('to') ||
                    (value.contains('-') && value.split('-').length > 2);

                if (isDateRange) {
                  final dates = _parseDateRange(value);
                  if (dates != null) {
                    rowData['startDate'] = dates['start'];
                    rowData['endDate'] = dates['end'];
                    rowData['date'] =
                        dates['start']; // Use start date as primary date
                  } else {
                    rowData['date'] = _parseDate(value);
                  }
                } else {
                  rowData['date'] = _parseDate(value);
                }
                break;
              case 'type':
                if (value.isNotEmpty) {
                  final normalizedType = value.toLowerCase().trim();
                  // Validate and normalize holiday type
                  switch (normalizedType) {
                    case 'public':
                    case 'company':
                    case 'optional':
                    case 'religious':
                    case 'national':
                      rowData['type'] = normalizedType;
                      break;
                    default:
                      // Try to map common variations
                      switch (normalizedType) {
                        case 'public holiday':
                        case 'public holidays':
                          rowData['type'] = 'public';
                          break;
                        case 'company holiday':
                        case 'company holidays':
                        case 'corporate':
                        case 'corporate holiday':
                          rowData['type'] = 'company';
                          break;
                        case 'optional holiday':
                        case 'optional holidays':
                        case 'discretionary':
                          rowData['type'] = 'optional';
                          break;
                        case 'religious holiday':
                        case 'religious holidays':
                        case 'faith':
                        case 'faith-based':
                          rowData['type'] = 'religious';
                          break;
                        case 'national holiday':
                        case 'national holidays':
                        case 'federal':
                        case 'federal holiday':
                          rowData['type'] = 'national';
                          break;
                        default:
                          // If no match found, use company as default and log a warning
                          rowData['type'] = 'company';
                        // 'Warning: Unknown holiday type "$value" in row ${i + 2}, using "company" as default');
                      }
                  }
                } else {
                  rowData['type'] = 'company'; // Default type
                }
                break;
              case 'gender':
                rowData['gender'] = value.isNotEmpty ? value : 'all';
                break;
              case 'description':
                rowData['description'] = value.isNotEmpty ? value : null;
                break;
              case 'is recurring':
              case 'isrecurring':
                rowData['isRecurring'] =
                    value.toLowerCase() == 'true' ||
                    value.toLowerCase() == 'yes' ||
                    value.toLowerCase() == '1';
                break;
              case 'recurrence pattern':
              case 'recurrencepattern':
                rowData['recurrencePattern'] = value.isNotEmpty
                    ? value
                    : 'yearly';
                break;
            }
          }

          // Debug: Log processed row data
          // Validate required fields
          if (rowData['name']?.toString().isEmpty == true ||
              rowData['date'] == null) {
            errors.add('Row ${i + 2}: Missing required fields (Name or Date)');
            errorCount++;
            continue;
          }

          // Add holiday to new holidays list
          newHolidays.add(rowData);
          successCount++;
        } catch (e) {
          errors.add('Row ${i + 2}: ${e.toString()}');
          errorCount++;
        }
      }

      // If we have new holidays, add them to the calendar
      if (newHolidays.isNotEmpty) {
        // Remove duplicates before adding new holidays
        final existingHolidaysSet = <String>{};
        final uniqueExistingHolidays = <Map<String, dynamic>>[];

        // Create a set of existing holidays for duplicate detection
        for (final holiday in existingHolidays) {
          // Create key using name and normalized date
          String dateKey = _normalizeDateForComparison(
            holiday['date'] ?? holiday['startDate'] ?? '',
          );
          final key = '${holiday['name']?.toString().trim()}_$dateKey';
          if (!existingHolidaysSet.contains(key)) {
            existingHolidaysSet.add(key);
            uniqueExistingHolidays.add(holiday);
          }
        }

        // Filter out duplicates from new holidays
        final uniqueNewHolidays = <Map<String, dynamic>>[];
        for (final holiday in newHolidays) {
          // Create key using name and normalized date
          String dateKey = _normalizeDateForComparison(
            holiday['date'] ?? holiday['startDate'] ?? '',
          );
          final key = '${holiday['name']?.toString().trim()}_$dateKey';
          if (!existingHolidaysSet.contains(key)) {
            existingHolidaysSet.add(key);
            uniqueNewHolidays.add(holiday);
          }
        }

        // Combine unique existing and new holidays
        final allHolidays = [...uniqueExistingHolidays, ...uniqueNewHolidays];

        // Prepare calendar update data
        final calendarUpdateData = {
          'year': _currentYear,
          'workingDays': currentCalendar['workingDays'] ?? [],
          'workingHours': currentCalendar['workingHours'] ?? {},
          'holidays': allHolidays,
          'nonWorkingDays': currentCalendar['nonWorkingDays'] ?? [],
          'leaveYear': currentCalendar['leaveYear'] ?? {},
          'timezone': currentCalendar['timezone'] ?? 'UTC',
        };

        // Update the entire calendar
        final success = await provider.updateCompanyCalendar(
          calendarUpdateData,
        );

        if (success) {
          // Show success message with duplicate info
          final duplicatesSkipped =
              newHolidays.length - uniqueNewHolidays.length;
          final message = duplicatesSkipped > 0
              ? 'Successfully imported ${uniqueNewHolidays.length} new holidays ($duplicatesSkipped duplicates skipped)'
              : 'Successfully imported ${uniqueNewHolidays.length} holidays';

          GlobalNotificationService().showSuccess(message);

          // Refresh calendar to show new holidays
          await _loadCalendar();
        } else {
          throw Exception('Failed to update calendar with new holidays');
        }
      } else {
        // No new holidays to add
        if (mounted) {
          GlobalNotificationService().showWarning('No new holidays to import');
        }
      }

      // Show results — prefer a pre-captured context; otherwise fallback to notification
      final resultsContext = preCapturedContext;
      final summaryMessage =
          'Imported $successCount holidays; $errorCount errors.';
      if (resultsContext != null) {
        showDialog(
          // ignore: use_build_context_synchronously
          context: resultsContext,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Import Results'),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Successfully processed: $successCount holidays'),
                    if (errorCount > 0) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Errors: $errorCount',
                        style: const TextStyle(color: Colors.red),
                      ),
                      const SizedBox(height: 8),
                      const Text('Error details:'),
                      ...errors.map(
                        (error) => Text(
                          '• $error',
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('OK'),
                ),
              ],
            );
          },
        );
      } else {
        // Fallback summary notification when UI context is unavailable
        GlobalNotificationService().showInfo(summaryMessage);
      }
    } catch (e) {
      GlobalNotificationService().showError(
        'Error processing file: ${e.toString()}',
      );
    }
  }

  Future<void> _cleanUpHolidays(CompanyCalendarProvider provider) async {
    try {
      final calendar = provider.calendar;
      if (calendar == null || calendar['holidays'] == null) {
        GlobalNotificationService().showWarning(
          'No holidays found to clean up',
        );
        return;
      }

      final holidays = List<Map<String, dynamic>>.from(calendar['holidays']);

      // Remove duplicates and fix dates
      final uniqueHolidays = <String, Map<String, dynamic>>{};
      int duplicatesRemoved = 0;
      int datesFixed = 0;

      for (final holiday in holidays) {
        try {
          // Fix date if it's in wrong format first
          String? fixedDate = holiday['date'];
          if (fixedDate != null) {
            // Try to parse and reformat the date
            final parsedDate = _parseDate(fixedDate);
            if (parsedDate != null && parsedDate != fixedDate) {
              fixedDate = parsedDate;
              datesFixed++;
            }
          }

          // Create unique key for duplicate detection using fixed date
          String dateKey =
              fixedDate ?? holiday['date'] ?? holiday['startDate'] ?? '';
          final key = '${holiday['name']}_$dateKey';

          // Create cleaned holiday
          final cleanedHoliday = {
            ...holiday,
            'date': fixedDate ?? holiday['date'],
          };

          if (!uniqueHolidays.containsKey(key)) {
            uniqueHolidays[key] = cleanedHoliday;
          } else {
            duplicatesRemoved++;
          }
        } catch (e) {
          // Skip invalid holidays
          duplicatesRemoved++;
        }
      }

      final cleanedHolidays = uniqueHolidays.values.toList();

      if (duplicatesRemoved == 0 && datesFixed == 0) {
        GlobalNotificationService().showSuccess(
          'No cleanup needed - holidays are already clean',
        );
        return;
      }

      // Update calendar with cleaned holidays
      final calendarUpdateData = {
        'year': _currentYear,
        'workingDays': calendar['workingDays'] ?? [],
        'workingHours': calendar['workingHours'] ?? {},
        'holidays': cleanedHolidays,
        'nonWorkingDays': calendar['nonWorkingDays'] ?? [],
        'leaveYear': calendar['leaveYear'] ?? {},
        'timezone': calendar['timezone'] ?? 'UTC',
      };

      final success = await provider.updateCompanyCalendar(calendarUpdateData);

      if (success) {
        GlobalNotificationService().showSuccess(
          'Cleanup completed! Removed $duplicatesRemoved duplicates, fixed $datesFixed dates. Total holidays: ${cleanedHolidays.length}',
        );

        // Refresh calendar to show cleaned holidays
        await _loadCalendar();
      } else {
        throw Exception('Failed to update calendar with cleaned holidays');
      }
    } catch (e) {
      GlobalNotificationService().showError(
        'Error cleaning up holidays: ${e.toString()}',
      );
    }
  }

  String? _parseDate(String dateString) {
    if (dateString.isEmpty) return null;

    try {
      // Clean the date string
      String cleanDate = dateString.trim();

      // Handle specific problematic formats first - prioritize MM/DD/YYYY
      if (cleanDate.contains('/')) {
        final parts = cleanDate.split('/');
        if (parts.length == 3) {
          String month = parts[0].padLeft(2, '0');
          String day = parts[1].padLeft(2, '0');
          String year = parts[2];

          // Convert 2-digit year to 4-digit
          if (year.length == 2) {
            int yearInt = int.parse(year);
            if (yearInt < 50) {
              year = '20$year';
            } else {
              year = '19$year';
            }
          }

          // Validate month and day ranges
          int monthInt = int.parse(month);
          int dayInt = int.parse(day);

          if (monthInt >= 1 && monthInt <= 12 && dayInt >= 1 && dayInt <= 31) {
            // Format as yyyy-MM-dd (ISO format) - treating as MM/DD/YYYY
            final result =
                '$year-${month.padLeft(2, '0')}-${day.padLeft(2, '0')}';
            return result;
          }
        }
      }

      // Handle MM-DD-YYYY format (dash separated)
      if (cleanDate.contains('-') && !cleanDate.contains(' to ')) {
        final parts = cleanDate.split('-');
        if (parts.length == 3) {
          String month = parts[0].padLeft(2, '0');
          String day = parts[1].padLeft(2, '0');
          String year = parts[2];

          // Convert 2-digit year to 4-digit
          if (year.length == 2) {
            int yearInt = int.parse(year);
            if (yearInt < 50) {
              year = '20$year';
            } else {
              year = '19$year';
            }
          }

          // Validate month and day ranges
          int monthInt = int.parse(month);
          int dayInt = int.parse(day);

          if (monthInt >= 1 && monthInt <= 12 && dayInt >= 1 && dayInt <= 31) {
            // Format as yyyy-MM-dd (ISO format) - treating as MM-DD-YYYY
            final result =
                '$year-${month.padLeft(2, '0')}-${day.padLeft(2, '0')}';
            return result;
          }
        }
      }

      // Try different date formats (prioritize MM/dd/yyyy for US-style dates)
      final formats = [
        'yyyy-MM-dd', // 2025-01-01
        'dd-MMM-yyyy', // 29-Sep-2025 (day-month-year with month name)
        'dd-MMM-yy', // 29-Sep-25 (day-month-year with month name)
        'MM/dd/yyyy', // 01/01/2025 (US format - month first)
        'MM/dd/yy', // 01/01/25 (US format - month first)
        'MM-dd-yyyy', // 01-01-2025 (US format - month first)
        'MM-dd-yy', // 01-01-25 (US format - month first)
        'dd/MM/yyyy', // 01/01/2025 (European format - day first)
        'dd/MM/yy', // 01/01/25 (European format - day first)
        'dd-MM-yyyy', // 01-01-2025 (European format - day first)
        'dd-MM-yy', // 01-01-25 (European format - day first)
        'dd.MM.yyyy', // 01.01.2025
        'MM.dd.yyyy', // 01.01.2025
        'yyyy/MM/dd', // 2025/01/01
      ];

      for (final format in formats) {
        try {
          final date = DateFormat(format).parse(cleanDate);
          // Return only the date part in yyyy-MM-dd format
          final result = DateFormat('yyyy-MM-dd').format(date);
          return result;
        } catch (e) {
          // Continue to next format
        }
      }

      // If none of the formats work, try to parse as ISO string
      final date = DateTime.parse(cleanDate);
      return DateFormat('yyyy-MM-dd').format(date);
    } catch (e) {
      return null;
    }
  }

  Map<String, String>? _parseDateRange(String dateString) {
    try {
      // Handle various "to" patterns
      List<String> parts = [];

      if (dateString.contains(' to ')) {
        parts = dateString.split(' to ');
      } else if (dateString.contains('to ')) {
        parts = dateString.split('to ');
      } else if (dateString.contains(' to')) {
        parts = dateString.split(' to');
      } else if (dateString.contains('to')) {
        parts = dateString.split('to');
      } else if (dateString.contains(' - ')) {
        parts = dateString.split(' - ');
      } else if (dateString.contains('-')) {
        parts = dateString.split('-');
      }

      if (parts.length == 2) {
        final startDate = _parseDateRangePart(parts[0].trim());
        final endDate = _parseDateRangePart(parts[1].trim());
        if (startDate != null && endDate != null) {
          return {'start': startDate, 'end': endDate};
        }
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  String? _parseDateRangePart(String dateString) {
    if (dateString.isEmpty) return null;

    try {
      // Clean the date string
      String cleanDate = dateString.trim();

      // Handle DD/MM/YYYY format (for date ranges)
      if (cleanDate.contains('/')) {
        final parts = cleanDate.split('/');
        if (parts.length == 3) {
          String day = parts[0].padLeft(2, '0');
          String month = parts[1].padLeft(2, '0');
          String year = parts[2];

          // Convert 2-digit year to 4-digit
          if (year.length == 2) {
            int yearInt = int.parse(year);
            if (yearInt < 50) {
              year = '20$year';
            } else {
              year = '19$year';
            }
          }

          // Validate month and day ranges
          int monthInt = int.parse(month);
          int dayInt = int.parse(day);

          if (monthInt >= 1 && monthInt <= 12 && dayInt >= 1 && dayInt <= 31) {
            // Format as yyyy-MM-dd (ISO format) - treating as DD/MM/YYYY for date ranges
            final result =
                '$year-${month.padLeft(2, '0')}-${day.padLeft(2, '0')}';
            return result;
          }
        }
      }

      // Fallback to regular date parsing
      return _parseDate(dateString);
    } catch (e) {
      return null;
    }
  }

  String _getHolidayDateDisplay(Map<String, dynamic> holiday) {
    // Check if it's a multi-day holiday
    if (holiday['startDate'] != null && holiday['endDate'] != null) {
      final startDate = _formatDate(holiday['startDate']);
      final endDate = _formatDate(holiday['endDate']);
      return '$startDate - $endDate';
    }

    // Single-day holiday
    final singleDate = _formatDate(holiday['date']);
    return singleDate;
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
        return 'Unknown';
    }
  }

  // Clean up holidays that have time components (should be 00:00:00)
  Future<void> _cleanUpHolidayTimes() async {
    try {
      final provider = context.read<CompanyCalendarProvider>();
      final currentCalendar = provider.calendar;
      if (currentCalendar == null) return;

      final holidays = List<Map<String, dynamic>>.from(
        currentCalendar['holidays'] ?? [],
      );
      bool needsUpdate = false;

      for (int i = 0; i < holidays.length; i++) {
        final holiday = holidays[i];
        final dateString = holiday['date']?.toString();

        if (dateString != null &&
            dateString.contains('T') &&
            !dateString.endsWith('T00:00:00.000Z')) {
          // Parse the date and create a new one with time set to 00:00:00
          final date = DateTime.parse(dateString);
          final cleanDate = DateTime(date.year, date.month, date.day, 0, 0, 0);
          holidays[i]['date'] = cleanDate.toIso8601String();
          needsUpdate = true;
        }
      }

      if (needsUpdate) {
        final calendarUpdateData = {
          'year': _currentYear,
          'workingDays': currentCalendar['workingDays'] ?? [],
          'workingHours': currentCalendar['workingHours'] ?? {},
          'holidays': holidays,
          'nonWorkingDays': currentCalendar['nonWorkingDays'] ?? [],
          'leaveYear': currentCalendar['leaveYear'] ?? {},
          'timezone': currentCalendar['timezone'] ?? 'UTC',
        };

        final success = await provider.updateCompanyCalendar(
          calendarUpdateData,
        );
        if (success) {
          await _loadCalendar();
        }
      }
      // ignore: empty_catches
    } catch (e) {}
  }

  String _normalizeDateForComparison(String dateString) {
    if (dateString.isEmpty) return '';

    try {
      // Handle ISO date strings (e.g., "2025-09-22T00:00:00.000Z")
      if (dateString.contains('T')) {
        final date = DateTime.parse(dateString);
        return DateFormat('yyyy-MM-dd').format(date);
      }

      // Handle date-only strings (e.g., "2025-09-22")
      if (dateString.contains('-') && dateString.length == 10) {
        return dateString;
      }

      // Handle other formats by parsing and normalizing
      final date = DateTime.parse(dateString);
      return DateFormat('yyyy-MM-dd').format(date);
    } catch (e) {
      return dateString; // Return original if parsing fails
    }
  }

  void _showCSVContentDialog(String csvContent) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('CSV Template Content'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Copy this content and save it as a .csv file:',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: SelectableText(
                    csvContent,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Instructions:',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                const Text('1. Copy the content above'),
                const Text('2. Create a new text file'),
                const Text('3. Paste the content'),
                const Text('4. Save with .csv extension'),
                const Text('5. Import the file in the app'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCleanUpHolidaysButton(CompanyCalendarProvider provider) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.cleaning_services, color: Colors.orange),
                const SizedBox(width: 8),
                Text(
                  'Clean Up Holidays',
                  style: AppTheme.titleLarge.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Remove duplicates, fix date parsing issues, and clean up time components in existing holidays.',
              style: AppTheme.bodyMedium.copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _cleanUpHolidays(provider),
                    icon: const Icon(Icons.cleaning_services),
                    label: const Text('Clean Up Holidays'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _cleanUpHolidayTimes(),
                    icon: const Icon(Icons.access_time),
                    label: const Text('Fix Times'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUpcomingHolidaysSection(CompanyCalendarProvider provider) {
    final calendar = provider.calendar;
    if (calendar == null || calendar['holidays'] == null) {
      return const Center(child: Text('No holidays found.'));
    }

    // Get all holidays from the calendar
    final allHolidays = List<Map<String, dynamic>>.from(calendar['holidays']);

    if (allHolidays.isEmpty) {
      return const Center(child: Text('No holidays found.'));
    }

    // Filter holidays to only show current year holidays
    final currentYearHolidays = allHolidays.where((holiday) {
      try {
        // Check single-day holiday
        if (holiday['date'] != null) {
          final holidayDate = DateTime.parse(holiday['date']);
          return holidayDate.year == _currentYear;
        }

        // Check multi-day holiday
        if (holiday['startDate'] != null) {
          final startDate = DateTime.parse(holiday['startDate']);
          return startDate.year == _currentYear;
        }

        return false;
      } catch (e) {
        return false; // Skip invalid dates
      }
    }).toList();

    if (currentYearHolidays.isEmpty) {
      return Center(child: Text('No holidays found for $_currentYear.'));
    }

    // Sort holidays by date (earliest first)
    currentYearHolidays.sort((a, b) {
      try {
        DateTime dateA, dateB;

        // Get date for holiday A
        if (a['date'] != null) {
          dateA = DateTime.parse(a['date']);
        } else if (a['startDate'] != null) {
          dateA = DateTime.parse(a['startDate']);
        } else {
          return 0;
        }

        // Get date for holiday B
        if (b['date'] != null) {
          dateB = DateTime.parse(b['date']);
        } else if (b['startDate'] != null) {
          dateB = DateTime.parse(b['startDate']);
        } else {
          return 0;
        }

        return dateA.compareTo(dateB);
      } catch (e) {
        return 0;
      }
    });

    // Separate upcoming and past holidays
    final now = DateTime.now();
    final upcomingHolidays = <Map<String, dynamic>>[];
    final pastHolidays = <Map<String, dynamic>>[];

    for (final holiday in currentYearHolidays) {
      try {
        DateTime holidayDate;

        // Get the appropriate date for comparison
        if (holiday['date'] != null) {
          holidayDate = DateTime.parse(holiday['date']);
        } else if (holiday['startDate'] != null) {
          holidayDate = DateTime.parse(holiday['startDate']);
        } else {
          continue; // Skip holidays without valid dates
        }

        // Check if holiday is today or in the future (including today)
        // Use start of day for accurate comparison
        final today = DateTime(now.year, now.month, now.day);
        final holidayDay = DateTime(
          holidayDate.year,
          holidayDate.month,
          holidayDate.day,
        );

        if (holidayDay.isAtSameMomentAs(today) || holidayDay.isAfter(today)) {
          upcomingHolidays.add(holiday);
        } else {
          pastHolidays.add(holiday);
        }
      } catch (e) {
        // Skip invalid dates
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Upcoming Holidays Section (Limited to 5)
        if (upcomingHolidays.isNotEmpty) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Upcoming Holidays (${upcomingHolidays.length})',
                style: AppTheme.titleLarge.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (upcomingHolidays.length > 5)
                TextButton(
                  onPressed: () => _showAllUpcomingHolidays(upcomingHolidays),
                  child: Text('View All'),
                ),
            ],
          ),
          const SizedBox(height: 16),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: upcomingHolidays.length > 5
                ? 5
                : upcomingHolidays.length,
            itemBuilder: (context, index) {
              final holiday = upcomingHolidays[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: Icon(
                    _getHolidayIcon(holiday['type']),
                    color: _getHolidayColor(holiday['type']),
                  ),
                  title: Text(holiday['name'] ?? ''),
                  subtitle: Text(
                    '${_getHolidayDateDisplay(holiday)} • ${holiday['type']} • ${_getGenderDisplayText(holiday['gender'])}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (holiday['isRecurring'] == true)
                        const Icon(Icons.repeat, size: 16, color: Colors.blue),
                      IconButton(
                        icon: const Icon(Icons.edit, size: 20),
                        onPressed: () => _editHoliday(holiday),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, size: 20),
                        onPressed: () => _deleteHoliday(holiday),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
        ],

        // Past Holidays Section (Limited to 3)
        if (pastHolidays.isNotEmpty) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Past Holidays (${pastHolidays.length})',
                style: AppTheme.titleLarge.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[600],
                ),
              ),
              if (pastHolidays.length > 3)
                TextButton(
                  onPressed: () => _showAllPastHolidays(pastHolidays),
                  child: Text('View All'),
                ),
            ],
          ),
          const SizedBox(height: 16),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: pastHolidays.length > 3 ? 3 : pastHolidays.length,
            itemBuilder: (context, index) {
              final holiday = pastHolidays[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                color: Colors.grey[50],
                child: ListTile(
                  leading: Icon(
                    _getHolidayIcon(holiday['type']),
                    color: Colors.grey[500],
                  ),
                  title: Text(
                    holiday['name'] ?? '',
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                  subtitle: Text(
                    '${_getHolidayDateDisplay(holiday)} • ${holiday['type']} • ${_getGenderDisplayText(holiday['gender'])}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (holiday['isRecurring'] == true)
                        const Icon(Icons.repeat, size: 16, color: Colors.grey),
                      IconButton(
                        icon: const Icon(Icons.edit, size: 20),
                        onPressed: () => _editHoliday(holiday),
                        color: Colors.grey[600],
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, size: 20),
                        onPressed: () => _deleteHoliday(holiday),
                        color: Colors.grey[600],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ],
    );
  }

  String _getGenderDisplayText(dynamic gender) {
    switch (gender) {
      case 'all':
        return 'All Employees';
      case 'male':
        return 'Male Only';
      case 'female':
        return 'Female Only';
      default:
        return 'All';
    }
  }

  String _getHolidayTypeDisplayName(String? type) {
    switch (type?.toLowerCase()) {
      case 'public':
        return 'Public';
      case 'company':
        return 'Company';
      case 'optional':
        return 'Optional';
      case 'religious':
        return 'Religious';
      case 'national':
        return 'National';
      default:
        return 'Company';
    }
  }

  // Helper methods for holiday functionality
  Map<String, dynamic>? _getHolidayForDate(
    DateTime day,
    CompanyCalendarProvider provider,
  ) {
    if (provider.calendar == null || provider.calendar!['holidays'] == null) {
      return null;
    }

    final holidays = List<Map<String, dynamic>>.from(
      provider.calendar!['holidays'],
    );
    final dayDate = DateTime(day.year, day.month, day.day);

    for (final holiday in holidays) {
      try {
        // Check if holiday is active
        if (holiday['isActive'] == false) continue;

        // Check for multi-day holidays
        if (holiday['startDate'] != null && holiday['endDate'] != null) {
          final startDate = DateTime.parse(holiday['startDate']);
          final endDate = DateTime.parse(holiday['endDate']);
          final startDateOnly = DateTime(
            startDate.year,
            startDate.month,
            startDate.day,
          );
          final endDateOnly = DateTime(
            endDate.year,
            endDate.month,
            endDate.day,
          );

          if (dayDate.isAtSameMomentAs(startDateOnly) ||
              dayDate.isAtSameMomentAs(endDateOnly) ||
              (dayDate.isAfter(startDateOnly) &&
                  dayDate.isBefore(endDateOnly))) {
            return holiday;
          }
        } else if (holiday['date'] != null) {
          // Single-day holiday
          final holidayDate = DateTime.parse(holiday['date']);
          final holidayDateOnly = DateTime(
            holidayDate.year,
            holidayDate.month,
            holidayDate.day,
          );

          if (dayDate.isAtSameMomentAs(holidayDateOnly)) {
            return holiday;
          }
        }
      } catch (e) {
        // Skip invalid dates
      }
    }
    return null;
  }

  // Helper methods for "View All" functionality
  void _showAllUpcomingHolidays(List<Map<String, dynamic>> upcomingHolidays) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('All Upcoming Holidays (${upcomingHolidays.length})'),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: ListView.builder(
              itemCount: upcomingHolidays.length,
              itemBuilder: (context, index) {
                final holiday = upcomingHolidays[index];
                return ListTile(
                  leading: Icon(
                    _getHolidayIcon(holiday['type']),
                    color: _getHolidayColor(holiday['type']),
                  ),
                  title: Text(holiday['name'] ?? ''),
                  subtitle: Text(
                    '${_formatDate(holiday['date'])} • ${holiday['type']} • ${_getGenderDisplayText(holiday['gender'])}',
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _showAllPastHolidays(List<Map<String, dynamic>> pastHolidays) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('All Past Holidays (${pastHolidays.length})'),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: ListView.builder(
              itemCount: pastHolidays.length,
              itemBuilder: (context, index) {
                final holiday = pastHolidays[index];
                return ListTile(
                  leading: Icon(
                    _getHolidayIcon(holiday['type']),
                    color: Colors.grey[500],
                  ),
                  title: Text(
                    holiday['name'] ?? '',
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                  subtitle: Text(
                    '${_getHolidayDateDisplay(holiday)} • ${holiday['type']} • ${_getGenderDisplayText(holiday['gender'])}',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  bool _isRegularWorkingDay(DateTime day, CompanyCalendarProvider provider) {
    if (provider.calendar == null) return false;

    // Check if this day is in the workingDays array
    final workingDays = provider.calendar!['workingDays'];
    if (workingDays == null) return false;

    final workingDaysList = List<String>.from(workingDays);
    final dayName = _getDayName(day.weekday);

    return workingDaysList.contains(dayName);
  }

  Widget _buildSelectedDayDetailsPanel(
    DateTime selectedDay,
    CompanyCalendarProvider provider,
  ) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selectedDate = DateTime(
      selectedDay.year,
      selectedDay.month,
      selectedDay.day,
    );
    final isPastDate = selectedDate.isBefore(today);

    final isOverride = provider.isOverrideWorkingDay(selectedDay);
    final holiday = _getHolidayForDate(selectedDay, provider);
    final isNonWorkingDay = _isNonWorkingDay(selectedDay, provider);
    final isRegularWorkingDay = _isRegularWorkingDay(selectedDay, provider);

    // Determine day type
    String dayType;
    IconData dayIcon;
    Color dayColor;
    String? dayDescription;

    if (isOverride) {
      dayType = 'Override Working Day';
      dayIcon = Icons.work;
      dayColor = Colors.blue;
      // Find override reason if available
      if (provider.calendar != null &&
          provider.calendar!['overrideWorkingDays'] != null) {
        final overrides = List<Map<String, dynamic>>.from(
          provider.calendar!['overrideWorkingDays'],
        );
        final overrideInfo = overrides.firstWhere((override) {
          try {
            final overrideDate = DateTime.parse(override['date']);
            return overrideDate.year == selectedDay.year &&
                overrideDate.month == selectedDay.month &&
                overrideDate.day == selectedDay.day;
          } catch (e) {
            return false;
          }
        }, orElse: () => <String, dynamic>{});
        dayDescription = overrideInfo['reason']?.toString().isEmpty == false
            ? overrideInfo['reason']
            : 'No reason provided';
      }
    } else if (holiday != null) {
      // Show holiday type in the day type
      final holidayType = holiday['type'] ?? 'company';
      final holidayTypeName = _getHolidayTypeDisplayName(holidayType);
      dayType = '$holidayTypeName Holiday';
      dayIcon = _getHolidayIcon(holiday['type']);
      dayColor = _getHolidayColor(holiday['type']);
      dayDescription = holiday['name'] ?? 'Holiday';
    } else if (isNonWorkingDay) {
      dayType = 'Non-Working Day';
      dayIcon = Icons.event_busy;
      dayColor = Colors.orange;
      // Find non-working day name
      if (provider.calendar != null &&
          provider.calendar!['nonWorkingDays'] != null) {
        final nonWorkingDays = List<Map<String, dynamic>>.from(
          provider.calendar!['nonWorkingDays'],
        );
        final nwdInfo = nonWorkingDays.firstWhere((nwd) {
          try {
            final startDate = DateTime.parse(nwd['startDate']);
            final endDate = DateTime.parse(nwd['endDate']);
            final dayDate = DateTime(
              selectedDay.year,
              selectedDay.month,
              selectedDay.day,
            );
            final startDateOnly = DateTime(
              startDate.year,
              startDate.month,
              startDate.day,
            );
            final endDateOnly = DateTime(
              endDate.year,
              endDate.month,
              endDate.day,
            );
            return dayDate.isAtSameMomentAs(startDateOnly) ||
                dayDate.isAtSameMomentAs(endDateOnly) ||
                (dayDate.isAfter(startDateOnly) &&
                    dayDate.isBefore(endDateOnly));
          } catch (e) {
            return false;
          }
        }, orElse: () => <String, dynamic>{});
        dayDescription = nwdInfo['name'] ?? 'Company Non-Working Day';
      }
    } else if (isRegularWorkingDay) {
      dayType = 'Regular Working Day';
      dayIcon = Icons.event_available;
      dayColor = Colors.green;
      dayDescription = 'Standard working day';
    } else {
      dayType = 'Weekend / Non-Working Day';
      dayIcon = Icons.weekend;
      dayColor = Colors.grey;
      dayDescription = 'Not in working days list';
    }

    return ModernCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with Clear Selection button
            Row(
              children: [
                Icon(dayIcon, color: dayColor, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DateFormat('EEEE, MMMM d, yyyy').format(selectedDay),
                        style: AppTheme.titleLarge.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        dayType,
                        style: AppTheme.bodyMedium.copyWith(
                          color: dayColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  color: Colors.grey[600],
                  tooltip: 'Clear Selection',
                  onPressed: () {
                    setState(() {
                      _selectedDay = null;
                      _overrideReasonController.clear();
                    });
                  },
                ),
              ],
            ),
            if (dayDescription != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: dayColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: dayColor.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: dayColor, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            dayDescription,
                            style: AppTheme.bodyMedium.copyWith(
                              color: dayColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    // Show additional holiday details (type, gender, recurring)
                    if (holiday != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const SizedBox(width: 28), // Align with icon above
                          Expanded(
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                if (holiday['type'] != null)
                                  Chip(
                                    label: Text(
                                      _getHolidayTypeDisplayName(
                                        holiday['type'],
                                      ),
                                      style: AppTheme.smallCaption.copyWith(
                                        color: dayColor,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    backgroundColor: dayColor.withValues(
                                      alpha: 0.15,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    visualDensity: VisualDensity.compact,
                                  ),
                                if (holiday['gender'] != null &&
                                    holiday['gender'] != 'all')
                                  Chip(
                                    label: Text(
                                      _getGenderDisplayText(holiday['gender']),
                                      style: AppTheme.smallCaption.copyWith(
                                        color: dayColor,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    backgroundColor: dayColor.withValues(
                                      alpha: 0.15,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    visualDensity: VisualDensity.compact,
                                  ),
                                if (holiday['isRecurring'] == true)
                                  Chip(
                                    label: const Text(
                                      'Recurring',
                                      style: AppTheme.smallCaption,
                                    ),
                                    backgroundColor: dayColor.withValues(
                                      alpha: 0.15,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    visualDensity: VisualDensity.compact,
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                    // Show holiday description if available
                    if (holiday != null &&
                        holiday['description'] != null &&
                        holiday['description'].toString().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.only(left: 28),
                        child: Text(
                          holiday['description'],
                          style: AppTheme.smallCaption.copyWith(
                            color: Colors.grey[700],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            if (isOverride &&
                dayDescription != null &&
                dayDescription != 'No reason provided') ...[
              const SizedBox(height: 8),
              Text(
                'Reason: $dayDescription',
                style: AppTheme.smallCaption.copyWith(color: Colors.grey[600]),
              ),
            ],
            // Override Controls (only for future dates and non-regular working days)
            if (!isPastDate && (isOverride || !isRegularWorkingDay)) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),
              Text(
                'Override Settings',
                style: AppTheme.bodyLarge.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              if (isOverride)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () =>
                        _removeOverrideWorkingDay(selectedDay, provider),
                    icon: const Icon(Icons.remove_circle_outline),
                    label: const Text('Remove Override'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                )
              else ...[
                TextField(
                  controller: _overrideReasonController,
                  decoration: const InputDecoration(
                    labelText: 'Reason (Optional)',
                    hintText: 'e.g., Special work day, Make-up day',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () =>
                        _addOverrideWorkingDay(selectedDay, provider),
                    icon: const Icon(Icons.add_circle_outline),
                    label: const Text('Add Override (Make this a Working Day)'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ] else if (isPastDate) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.lock_clock, color: Colors.orange[700], size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This is a past date. Override settings cannot be changed for historical data.',
                        style: AppTheme.smallCaption.copyWith(
                          color: Colors.orange[800],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  bool _isNonWorkingDay(DateTime day, CompanyCalendarProvider provider) {
    if (provider.calendar == null ||
        provider.calendar!['nonWorkingDays'] == null) {
      return false;
    }

    final nonWorkingDays = List<Map<String, dynamic>>.from(
      provider.calendar!['nonWorkingDays'],
    );
    for (final nwd in nonWorkingDays) {
      try {
        final startDate = DateTime.parse(nwd['startDate']).toLocal();
        final endDate = DateTime.parse(nwd['endDate']).toLocal();
        final dayDate = DateTime(day.year, day.month, day.day);
        final startDateOnly = DateTime(
          startDate.year,
          startDate.month,
          startDate.day,
        );
        final endDateOnly = DateTime(endDate.year, endDate.month, endDate.day);
        if (dayDate.isAtSameMomentAs(startDateOnly) ||
            dayDate.isAtSameMomentAs(endDateOnly) ||
            (dayDate.isAfter(startDateOnly) && dayDate.isBefore(endDateOnly))) {
          return true;
        }
      } catch (e) {
        // Skip invalid dates
      }
    }
    return false;
  }

  Future<void> _addOverrideWorkingDay(
    DateTime selectedDay,
    CompanyCalendarProvider provider,
  ) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selectedDate = DateTime(
      selectedDay.year,
      selectedDay.month,
      selectedDay.day,
    );

    if (selectedDate.isBefore(today)) {
      GlobalNotificationService().showError(
        'Cannot override past dates. Only future dates can be modified.',
      );
      return;
    }

    try {
      final success = await provider.addOverrideWorkingDay(
        year: _currentYear,
        date: selectedDay,
        reason: _overrideReasonController.text.trim(),
      );

      if (mounted) {
        if (success) {
          GlobalNotificationService().showSuccess(
            'Override working day added successfully',
          );
          // Clear reason field
          _overrideReasonController.clear();
          // Refresh calendar
          await provider.fetchCompanyCalendar(_currentYear);
          setState(() {});
        } else {
          GlobalNotificationService().showError(
            provider.error ?? 'Operation failed',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        GlobalNotificationService().showError('Error: $e');
      }
    }
  }

  Future<void> _removeOverrideWorkingDay(
    DateTime selectedDay,
    CompanyCalendarProvider provider,
  ) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selectedDate = DateTime(
      selectedDay.year,
      selectedDay.month,
      selectedDay.day,
    );

    if (selectedDate.isBefore(today)) {
      GlobalNotificationService().showError(
        'Cannot modify past dates. Only future dates can be changed.',
      );
      return;
    }

    try {
      final success = await provider.removeOverrideWorkingDay(
        year: _currentYear,
        date: selectedDay,
      );

      if (mounted) {
        if (success) {
          GlobalNotificationService().showSuccess(
            'Override working day removed successfully',
          );
          // Refresh calendar
          await provider.fetchCompanyCalendar(_currentYear);
          setState(() {});
        } else {
          GlobalNotificationService().showError(
            provider.error ?? 'Operation failed',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        GlobalNotificationService().showError('Error: $e');
      }
    }
  }

  Widget _buildOverrideFeatureInfoBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.blue[700], size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Override Working Days',
                  style: AppTheme.bodyMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[900],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Click any day on the calendar to view details and manage overrides. Only future dates can be modified.',
                  style: AppTheme.smallCaption.copyWith(
                    color: Colors.blue[800],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Share file using system share intent (Google Play compliant)
  Future<void> _shareFile(
    BuildContext context,
    File file,
    String fileName,
  ) async {
    try {
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Holidays Template - $fileName',
        subject: 'Holidays Template',
      );

      GlobalNotificationService().showSuccess(
        'Share dialog opened for $fileName',
      );
    } catch (e) {
      GlobalNotificationService().showError('Error sharing file: $e');
    }
  }
}
