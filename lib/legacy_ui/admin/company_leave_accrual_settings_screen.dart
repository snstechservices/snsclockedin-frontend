import 'package:flutter/material.dart';
import 'package:sns_rooster/services/api_service.dart';
import 'package:sns_rooster/config/api_config.dart';
import 'package:sns_rooster/services/global_notification_service.dart';

class CompanyLeaveAccrualSettingsScreen extends StatefulWidget {
  const CompanyLeaveAccrualSettingsScreen({super.key});

  @override
  State<CompanyLeaveAccrualSettingsScreen> createState() =>
      _CompanyLeaveAccrualSettingsScreenState();
}

class _CompanyLeaveAccrualSettingsScreenState
    extends State<CompanyLeaveAccrualSettingsScreen> {
  final ApiService _api = ApiService(baseUrl: ApiConfig.baseUrl);

  bool _loading = true;
  bool _saving = false;
  DateTime? _lastSavedAt;

  bool _dailyEnabled = false;
  TimeOfDay _dailyTime = const TimeOfDay(hour: 3, minute: 0);

  bool _weeklyEnabled = false;
  String _weeklyDay = 'Sunday';
  TimeOfDay _weeklyTime = const TimeOfDay(hour: 4, minute: 0);

  final List<String> _daysOfWeek = const [
    'Sunday',
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
    });
    try {
      final data = await _api.getCompanyAccrualSettings();
      if (data != null) {
        // Backend returns leaveAccrual object as data; support both shapes
        final Map<String, dynamic> root = Map<String, dynamic>.from(data);
        final Map<String, dynamic> leave = root.containsKey('leaveAccrual')
            ? Map<String, dynamic>.from(root['leaveAccrual'] ?? {})
            : root;
        final Map<String, dynamic> daily = Map<String, dynamic>.from(
          leave['daily'] ?? {},
        );
        final Map<String, dynamic> weekly = Map<String, dynamic>.from(
          leave['weeklyReconciliation'] ?? {},
        );

        _dailyEnabled = (daily['enabled'] ?? false) == true;
        final dailyTimeStr = (daily['time'] ?? '03:00') as String;
        _dailyTime = _parseHHmm(dailyTimeStr);

        _weeklyEnabled = (weekly['enabled'] ?? false) == true;
        _weeklyDay = (weekly['dayOfWeek'] ?? 'Sunday') as String;
        final weeklyTimeStr = (weekly['time'] ?? '04:00') as String;
        _weeklyTime = _parseHHmm(weeklyTimeStr);
      }
    } catch (_) {
      // fallthrough, defaults already set
    } finally {
      if (mounted)
        setState(() {
          _loading = false;
        });
    }
  }

  TimeOfDay _parseHHmm(String hhmm) {
    try {
      final parts = hhmm.split(':');
      final h = int.parse(parts[0]);
      final m = int.parse(parts[1]);
      return TimeOfDay(hour: h, minute: m);
    } catch (_) {
      return const TimeOfDay(hour: 0, minute: 0);
    }
  }

  String _formatHHmm(TimeOfDay t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  Future<void> _pickTime({required bool isDaily}) async {
    final initial = isDaily ? _dailyTime : _weeklyTime;
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked != null) {
      setState(() {
        if (isDaily) {
          _dailyTime = picked;
        } else {
          _weeklyTime = picked;
        }
      });
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _saving = true;
    });
    final payload = {
      'daily': {'enabled': _dailyEnabled, 'time': _formatHHmm(_dailyTime)},
      'weeklyReconciliation': {
        'enabled': _weeklyEnabled,
        'dayOfWeek': _weeklyDay,
        'time': _formatHHmm(_weeklyTime),
      },
    };

    final ok = await _api.updateCompanyAccrualSettings(payload);
    if (ok) {
      GlobalNotificationService().showSuccess('Accrual settings updated');
      setState(() {
        _lastSavedAt = DateTime.now();
      });
      // Re-fetch to ensure UI reflects the persisted values
      await _load();
    } else {
      GlobalNotificationService().showError(
        'Failed to update accrual settings',
      );
    }
    if (mounted)
      setState(() {
        _saving = false;
      });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Leave & Accrual Settings'),
        backgroundColor: color.primary,
        foregroundColor: color.onPrimary,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_lastSavedAt != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Text(
                        'Last saved: '
                        '${_lastSavedAt!.hour.toString().padLeft(2, '0')}:${_lastSavedAt!.minute.toString().padLeft(2, '0')}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  Text('Company Time', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SwitchListTile(
                            value: _dailyEnabled,
                            onChanged: (v) => setState(() => _dailyEnabled = v),
                            title: const Text('Daily Accrual Enabled'),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: InputDecorator(
                                  decoration: const InputDecoration(
                                    labelText:
                                        'Daily Accrual Time (Company Time)',
                                  ),
                                  child: Text(_formatHHmm(_dailyTime)),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.access_time),
                                onPressed: () => _pickTime(isDaily: true),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SwitchListTile(
                            value: _weeklyEnabled,
                            onChanged: (v) =>
                                setState(() => _weeklyEnabled = v),
                            title: const Text('Weekly Reconciliation Enabled'),
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            initialValue: _weeklyDay,
                            items: _daysOfWeek
                                .map(
                                  (d) => DropdownMenuItem(
                                    value: d,
                                    child: Text(d),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) => setState(() {
                              if (v != null) _weeklyDay = v;
                            }),
                            decoration: const InputDecoration(
                              labelText: 'Day of Week',
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: InputDecorator(
                                  decoration: const InputDecoration(
                                    labelText: 'Weekly Time (Company Time)',
                                  ),
                                  child: Text(_formatHHmm(_weeklyTime)),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.access_time),
                                onPressed: () => _pickTime(isDaily: false),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save),
                      label: Text(_saving ? 'Saving...' : 'Save Changes'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
