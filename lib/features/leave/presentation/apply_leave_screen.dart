import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:sns_clocked_in/core/state/app_state.dart';
import 'package:sns_clocked_in/features/leave/application/leave_store.dart';
import 'package:sns_clocked_in/features/leave/domain/leave_request.dart';
import 'package:sns_clocked_in/design_system/app_colors.dart';
import 'package:sns_clocked_in/design_system/app_radius.dart';
import 'package:sns_clocked_in/design_system/app_spacing.dart';
import 'package:sns_clocked_in/design_system/app_typography.dart';

/// Apply leave screen
class ApplyLeaveScreen extends StatefulWidget {
  const ApplyLeaveScreen({super.key});

  @override
  State<ApplyLeaveScreen> createState() => _ApplyLeaveScreenState();
}

class _ApplyLeaveScreenState extends State<ApplyLeaveScreen> {
  final _formKey = GlobalKey<FormState>();
  LeaveType _selectedLeaveType = LeaveType.annual;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isHalfDay = false;
  HalfDayPart _halfDayPart = HalfDayPart.am;
  final _reasonController = TextEditingController();

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Apply Leave',
          style: AppTypography.lightTextTheme.headlineMedium,
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: AppSpacing.lgAll,
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Leave Type Dropdown
                _buildSectionTitle('Leave Type'),
                const SizedBox(height: AppSpacing.sm),
                _buildLeaveTypeDropdown(),
                const SizedBox(height: AppSpacing.lg),

                // Date Range
                _buildSectionTitle('Date Range'),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: _buildDatePicker(
                        label: 'Start Date',
                        date: _startDate,
                        onDateSelected: (date) {
                          setState(() {
                            _startDate = date;
                            if (_endDate != null && _endDate!.isBefore(date)) {
                              _endDate = null;
                            }
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: _buildDatePicker(
                        label: 'End Date',
                        date: _endDate,
                        onDateSelected: (date) {
                          setState(() {
                            _endDate = date;
                          });
                        },
                        minDate: _startDate,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),

                // Half Day Toggle
                _buildHalfDayToggle(),
                if (_isHalfDay) ...[
                  const SizedBox(height: AppSpacing.md),
                  _buildHalfDayPartSelector(),
                ],
                const SizedBox(height: AppSpacing.lg),

                // Reason
                _buildSectionTitle('Reason'),
                const SizedBox(height: AppSpacing.sm),
                TextFormField(
                  controller: _reasonController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: 'Enter reason for leave',
                    border: OutlineInputBorder(
                      borderRadius: AppRadius.mediumAll,
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a reason';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.lg),

                // Attachment placeholder
                OutlinedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Attachment feature coming soon')),
                    );
                  },
                  icon: const Icon(Icons.attach_file),
                  label: const Text('Add Attachment'),
                ),
                const SizedBox(height: AppSpacing.xl),

                // Submit Button
                ElevatedButton(
                  onPressed: _handleSubmit,
                  style: ElevatedButton.styleFrom(
                    padding: AppSpacing.lgAll,
                  ),
                  child: const Text('Submit Leave Request'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: AppTypography.lightTextTheme.labelLarge,
    );
  }

  Widget _buildLeaveTypeDropdown() {
    return DropdownButtonFormField<LeaveType>(
      value: _selectedLeaveType,
      decoration: InputDecoration(
        border: OutlineInputBorder(
          borderRadius: AppRadius.mediumAll,
        ),
      ),
      items: LeaveType.values.map((type) {
        String label;
        switch (type) {
          case LeaveType.annual:
            label = 'Annual';
            break;
          case LeaveType.sick:
            label = 'Sick';
            break;
          case LeaveType.unpaid:
            label = 'Unpaid';
            break;
        }
        return DropdownMenuItem(
          value: type,
          child: Text(label),
        );
      }).toList(),
      onChanged: (value) {
        if (value != null) {
          setState(() {
            _selectedLeaveType = value;
          });
        }
      },
    );
  }

  Widget _buildDatePicker({
    required String label,
    required DateTime? date,
    required Function(DateTime) onDateSelected,
    DateTime? minDate,
  }) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date ?? DateTime.now(),
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 365)),
        );
        if (picked != null) {
          if (minDate != null && picked.isBefore(minDate)) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('End date must be after start date')),
            );
            return;
          }
          onDateSelected(picked);
        }
      },
      child: Container(
        padding: AppSpacing.mdAll,
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.textSecondary.withValues(alpha: 0.3)),
          borderRadius: AppRadius.mediumAll,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              date == null ? label : _formatDate(date),
              style: AppTypography.lightTextTheme.bodyMedium?.copyWith(
                color: date == null ? AppColors.textSecondary : AppColors.textPrimary,
              ),
            ),
            const Icon(Icons.calendar_today, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildHalfDayToggle() {
    return Row(
      children: [
        Checkbox(
          value: _isHalfDay,
          onChanged: (value) {
            setState(() {
              _isHalfDay = value ?? false;
              // When half-day is checked, set end date to start date
              if (_isHalfDay) {
                _endDate = _startDate;
              }
            });
          },
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(
          'Half Day',
          style: AppTypography.lightTextTheme.bodyMedium,
        ),
      ],
    );
  }

  Widget _buildHalfDayPartSelector() {
    return Row(
      children: [
        Expanded(
          child: RadioListTile<HalfDayPart>(
            title: const Text('AM'),
            value: HalfDayPart.am,
            groupValue: _halfDayPart,
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _halfDayPart = value;
                });
              }
            },
          ),
        ),
        Expanded(
          child: RadioListTile<HalfDayPart>(
            title: const Text('PM'),
            value: HalfDayPart.pm,
            groupValue: _halfDayPart,
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _halfDayPart = value;
                });
              }
            },
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _handleSubmit() {
    if (!_formKey.currentState!.validate()) return;
    if (_startDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a start date')),
      );
      return;
    }
    if (!_isHalfDay && _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an end date')),
      );
      return;
    }

    final appState = context.read<AppState>();
    final leaveStore = context.read<LeaveStore>();

    final leaveRequest = LeaveRequest(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userId: appState.userId ?? 'current_user',
      leaveType: _selectedLeaveType,
      startDate: _startDate!,
      endDate: _isHalfDay ? _startDate! : _endDate!,
      isHalfDay: _isHalfDay,
      halfDayPart: _isHalfDay ? _halfDayPart : null,
      reason: _reasonController.text.trim(),
      status: LeaveStatus.pending,
      createdAt: DateTime.now(),
    );

    leaveStore.addLeave(leaveRequest);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Leave request submitted successfully')),
    );
    context.pop();
  }
}

