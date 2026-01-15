import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import '../../widgets/timezone_selector.dart';
import '../../widgets/network_error_handler_widget.dart';
import '../../providers/auth_provider.dart';
import '../../providers/company_provider.dart';
import '../../config/api_config.dart';
import '../../services/api_service.dart';
import '../../services/global_notification_service.dart';
import '../../utils/logger.dart';

class CompanyTimezoneSettingsScreen extends StatefulWidget {
  const CompanyTimezoneSettingsScreen({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _CompanyTimezoneSettingsScreenState createState() =>
      _CompanyTimezoneSettingsScreenState();
}

class _CompanyTimezoneSettingsScreenState
    extends State<CompanyTimezoneSettingsScreen> {
  String? _companyTimezone;
  String _timezoneDisplayFormat = '24h';
  bool _showTimezoneInfo = true;
  String _dateFormat = 'MMM dd, yyyy';
  bool _isLoading = false;
  final ApiService _apiService = ApiService(baseUrl: ApiConfig.baseUrl);

  @override
  void initState() {
    super.initState();
    _loadCompanySettings();
  }

  /// Validate and normalize date format value
  String _validateDateFormat(String? dateFormat) {
    // Map backend formats to our expected formats
    const formatMapping = {
      'MM/DD/YYYY': 'MM/dd/yyyy',
      'DD/MM/YYYY': 'dd/MM/yyyy',
      'YYYY-MM-DD': 'yyyy-MM-dd',
      'DD-MM-YYYY': 'dd-MM-yyyy',
      'MMM DD, YYYY': 'MMM dd, yyyy',
    };

    const validFormats = [
      'MMM dd, yyyy',
      'dd/MM/yyyy',
      'MM/dd/yyyy',
      'yyyy-MM-dd',
      'dd-MM-yyyy',
    ];

    Logger.debug('Validating date format: "$dateFormat"');

    if (dateFormat != null) {
      // Check if it's already in the correct format
      if (validFormats.contains(dateFormat)) {
        Logger.debug('Date format is already valid: $dateFormat');
        return dateFormat;
      }

      // Check if it needs mapping from backend format
      if (formatMapping.containsKey(dateFormat)) {
        final mappedFormat = formatMapping[dateFormat]!;
        Logger.debug('Mapped backend format "$dateFormat" to "$mappedFormat"');
        return mappedFormat;
      }
    }

    Logger.debug('Date format is invalid, using default: MMM dd, yyyy');
    return 'MMM dd, yyyy'; // Default fallback
  }

  Future<void> _loadCompanySettings({bool forceRefresh = false}) async {
    try {
      Provider.of<AuthProvider>(context, listen: false);
      final companyProvider = Provider.of<CompanyProvider>(
        context,
        listen: false,
      );

      // If forceRefresh is true, always fetch from backend
      // Otherwise, try to get from local company data first
      Map<String, dynamic>? company;
      if (forceRefresh) {
        Logger.debug('Force refresh requested, fetching from backend');
        company = await _fetchCompanyDataFromBackend();
      } else {
        company = companyProvider.currentCompany?.toJson();

        // If no local data, fetch directly from backend
        if (company == null) {
          Logger.debug('No local company data, fetching from backend');
          company = await _fetchCompanyDataFromBackend();
        }
      }

      if (company != null) {
        setState(() {
          _companyTimezone = company!['settings']?['timezone'] ?? 'UTC';
          _timezoneDisplayFormat =
              company['settings']?['timezoneDisplayFormat'] ?? '24h';
          _showTimezoneInfo = company['settings']?['showTimezoneInfo'] ?? true;
          _dateFormat = _validateDateFormat(company['settings']?['dateFormat']);
        });
        Logger.info(
          'Loaded settings - timezone: $_companyTimezone, format: $_timezoneDisplayFormat, dateFormat: $_dateFormat, showTimezoneInfo: $_showTimezoneInfo',
        );
      } else {
        // Fallback if no company data
        setState(() {
          _companyTimezone = 'UTC';
          _timezoneDisplayFormat = '24h';
          _showTimezoneInfo = true;
          _dateFormat = 'MMM dd, yyyy';
        });
        Logger.info('Using default settings');
      }
    } catch (e) {
      Logger.error('Error loading company settings: $e');

      // Check if this is a network error and handle appropriately
      if (NetworkErrorHandlerWidget.isNetworkError(e)) {
        // Show network error message but don't crash the UI
        if (mounted) {
          NetworkErrorHandlerWidget.showNetworkErrorSnackBar(
            context,
            customMessage:
                'Unable to load settings. Please check your connection.',
            onRetry: () => _loadCompanySettings(),
          );
        }
      }

      // Fallback if error - use default values but don't crash
      setState(() {
        _companyTimezone = 'UTC';
        _timezoneDisplayFormat = '24h';
        _showTimezoneInfo = true;
        _dateFormat = 'MMM dd, yyyy';
      });
    }
  }

  Future<Map<String, dynamic>?> _fetchCompanyDataFromBackend() async {
    try {
      final response = await _apiService.get('/companies/timezone-settings');

      if (response.success && response.data != null) {
        final data = response.data is Map<String, dynamic>
            ? response.data as Map<String, dynamic>
            : json.decode(json.encode(response.data)) as Map<String, dynamic>;

        Logger.debug('Backend response data keys: ${data.keys.toList()}');
        Logger.debug(
          'Settings from backend present: ${data['settings'] != null}',
        );
        Logger.debug('Success flag from backend: ${data['success']}');
        // The backend returns { success: true, settings: {...} }
        if (data['settings'] != null) {
          return {'settings': data['settings']};
        } else {
          Logger.warning('Settings is null in backend response');
          return null;
        }
      } else {
        Logger.warning('Failed to fetch company data: ${response.message}');
        return null;
      }
    } catch (e) {
      Logger.error('Error fetching company data: $e');
      return null;
    }
  }

  Future<void> _saveSettings() async {
    // Validate timezone is set
    if (_companyTimezone == null || _companyTimezone!.isEmpty) {
      GlobalNotificationService().showWarning(
        'Please select a timezone before saving.',
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      Logger.debug(
        'About to save settings: timezone=$_companyTimezone, timezoneDisplayFormat=$_timezoneDisplayFormat, showTimezoneInfo=$_showTimezoneInfo, dateFormat=$_dateFormat',
      );

      // Update company timezone settings
      await authProvider.updateCompanyTimezoneSettings(
        timezone: _companyTimezone!,
        timezoneDisplayFormat: _timezoneDisplayFormat,
        showTimezoneInfo: _showTimezoneInfo,
        dateFormat: _dateFormat,
      );

      Logger.info('Settings saved successfully, reloading');

      // Reset user changes flag
      setState(() {});

      // Reload settings to reflect the changes - force refresh from server
      await _loadCompanySettings(forceRefresh: true);

      Logger.info('Settings reloaded, new timezone: $_companyTimezone');

      if (mounted) {
        GlobalNotificationService().showSuccess(
          'Company timezone settings saved successfully!',
        );
      }
    } catch (error) {
      Logger.error('Error saving settings: $error');
      Logger.debug('Error type: ${error.runtimeType}');

      if (mounted) {
        // Check if this is a network error and handle appropriately
        if (NetworkErrorHandlerWidget.isNetworkError(error)) {
          NetworkErrorHandlerWidget.showNetworkErrorSnackBar(
            context,
            customMessage:
                'Unable to save settings. Please check your connection and try again.',
            onRetry: () => _saveSettings(),
          );
        } else {
          GlobalNotificationService().showError(
            'Error saving settings: ${error.toString()}',
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Listen to CompanyProvider changes
    Provider.of<CompanyProvider>(context, listen: true);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Timezone Settings'),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Company Timezone
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Company Timezone',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'This is the timezone for your company. All users will see times in this timezone. This is the only place to configure timezone settings.',
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    TimezoneSelector(
                      selectedTimezone:
                          _companyTimezone ?? 'UTC', // Ensure it's never null
                      onTimezoneChanged: (timezone) {
                        setState(() {
                          _companyTimezone = timezone;
                        });
                      },
                      label: 'Select Company Timezone',
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Display Settings
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Display Settings',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Time Format
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Default Time Format',
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        ),
                        DropdownButton<String>(
                          value: _timezoneDisplayFormat.isNotEmpty
                              ? _timezoneDisplayFormat
                              : '24h',
                          onChanged: (String? newValue) {
                            if (newValue != null) {
                              setState(() {
                                _timezoneDisplayFormat = newValue;
                              });
                            }
                          },
                          items: const [
                            DropdownMenuItem(
                              value: '12h',
                              child: Text('12-hour (AM/PM)'),
                            ),
                            DropdownMenuItem(
                              value: '24h',
                              child: Text('24-hour'),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Show Timezone Information
                    SwitchListTile(
                      title: const Text('Show Timezone Information'),
                      subtitle: const Text(
                        'Display timezone offset (e.g., UTC+5:45) next to times',
                      ),
                      value: _showTimezoneInfo,
                      onChanged: (bool value) {
                        setState(() {
                          _showTimezoneInfo = value;
                        });
                      },
                    ),
                    const SizedBox(height: 16),

                    // Date Format
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Date Format',
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        ),
                        DropdownButton<String>(
                          value: _dateFormat.isNotEmpty
                              ? _dateFormat
                              : 'MMM dd, yyyy',
                          onChanged: (String? newValue) {
                            if (newValue != null) {
                              setState(() {
                                _dateFormat = newValue;
                              });
                            }
                          },
                          items: const [
                            DropdownMenuItem(
                              value: 'MMM dd, yyyy',
                              child: Text('Jan 15, 2024'),
                            ),
                            DropdownMenuItem(
                              value: 'dd/MM/yyyy',
                              child: Text('15/01/2024'),
                            ),
                            DropdownMenuItem(
                              value: 'MM/dd/yyyy',
                              child: Text('01/15/2024'),
                            ),
                            DropdownMenuItem(
                              value: 'yyyy-MM-dd',
                              child: Text('2024-01-15'),
                            ),
                            DropdownMenuItem(
                              value: 'dd-MM-yyyy',
                              child: Text('15-01-2024'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Save Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveSettings,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[600],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : const Text(
                        'Save Company Settings',
                        style: TextStyle(fontSize: 16),
                      ),
              ),
            ),

            const SizedBox(height: 16),

            // Info Card
            Card(
              color: Colors.amber[50],
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.warning_amber_outlined,
                          color: Colors.amber[700],
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Important Information',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.amber[700],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '• Changing the company timezone will affect all scheduled reports\n'
                      '• All users will use the company timezone\n'
                      '• All times are stored in UTC in the database\n'
                      '• Existing scheduled reports will be recalculated with the new timezone',
                      style: TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
