import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sns_clocked_in/features/employees/application/employees_store.dart';
import 'package:sns_clocked_in/features/employees/domain/employee.dart';
import 'package:sns_clocked_in/design_system/app_colors.dart';
import 'package:sns_clocked_in/design_system/app_radius.dart';
import 'package:sns_clocked_in/design_system/app_spacing.dart';
import 'package:sns_clocked_in/design_system/app_typography.dart';

/// Admin employees management screen
class AdminEmployeesScreen extends StatefulWidget {
  const AdminEmployeesScreen({super.key});

  @override
  State<AdminEmployeesScreen> createState() => _AdminEmployeesScreenState();
}

class _AdminEmployeesScreenState extends State<AdminEmployeesScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Seed sample data on first load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<EmployeesStore>().seedSampleData();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final employeesStore = context.watch<EmployeesStore>();
    final employees = employeesStore.filteredEmployees;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text(
          'Employees',
          style: AppTypography.lightTextTheme.headlineMedium,
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search Bar
            Padding(
              padding: AppSpacing.lgAll,
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search employees...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            employeesStore.search('');
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: AppRadius.mediumAll,
                  ),
                ),
                onChanged: (value) => employeesStore.search(value),
              ),
            ),

            // Filter Chips
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip('All', null, employeesStore),
                    const SizedBox(width: AppSpacing.sm),
                    _buildFilterChip('Active', EmployeeStatus.active, employeesStore),
                    const SizedBox(width: AppSpacing.sm),
                    _buildFilterChip('Inactive', EmployeeStatus.inactive, employeesStore),
                  ],
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            // Employee List
            Expanded(
              child: employees.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: AppSpacing.lgAll,
                      itemCount: employees.length,
                      itemBuilder: (context, index) {
                        return _buildEmployeeCard(employees[index]);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(
    String label,
    EmployeeStatus? status,
    EmployeesStore store,
  ) {
    final isSelected = store.statusFilter == status;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        store.filterByStatus(selected ? status : null);
      },
      selectedColor: AppColors.primary.withValues(alpha: 0.2),
      checkmarkColor: AppColors.primary,
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: AppSpacing.xlAll,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 80,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'No Employees Found',
              style: AppTypography.lightTextTheme.headlineMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Try adjusting your search or filters',
              style: AppTypography.lightTextTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmployeeCard(Employee employee) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.mediumAll,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _showEmployeeDetail(employee),
        borderRadius: AppRadius.mediumAll,
        child: Padding(
          padding: AppSpacing.lgAll,
          child: Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.primary,
                child: Text(
                  employee.fullName
                      .split(' ')
                      .map((name) => name.isNotEmpty ? name[0].toUpperCase() : '')
                      .take(2)
                      .join(),
                  style: AppTypography.lightTextTheme.bodyMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              // Employee Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      employee.fullName,
                      style: AppTypography.lightTextTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      employee.department,
                      style: AppTypography.lightTextTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              // Status Chip
              _buildStatusChip(employee.status),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(EmployeeStatus status) {
    final isActive = status == EmployeeStatus.active;
    final color = isActive ? AppColors.success : AppColors.textSecondary;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: AppRadius.smAll,
      ),
      child: Text(
        isActive ? 'Active' : 'Inactive',
        style: AppTypography.lightTextTheme.bodySmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  void _showEmployeeDetail(Employee employee) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _EmployeeDetailSheet(employee: employee),
    );
  }
}

class _EmployeeDetailSheet extends StatelessWidget {
  const _EmployeeDetailSheet({required this.employee});

  final Employee employee;

  @override
  Widget build(BuildContext context) {
    // Get initials
    final initials = employee.fullName
        .split(' ')
        .map((name) => name.isNotEmpty ? name[0].toUpperCase() : '')
        .take(2)
        .join();

    return SafeArea(
      child: Padding(
        padding: AppSpacing.lgAll,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header with avatar and name
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: AppColors.primary,
                  child: Text(
                    initials,
                    style: AppTypography.lightTextTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        employee.fullName,
                        style: AppTypography.lightTextTheme.headlineMedium,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        employee.email,
                        style: AppTypography.lightTextTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            // Details
            _buildDetailRow('Department', employee.department),
            _buildDetailRow('Role', employee.roleDisplay),
            _buildDetailRow('Status', employee.statusDisplay),
            const SizedBox(height: AppSpacing.lg),

            // Action Buttons
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('View Attendance - Coming soon')),
                );
              },
              icon: const Icon(Icons.access_time),
              label: const Text('View Attendance'),
              style: ElevatedButton.styleFrom(
                padding: AppSpacing.mdAll,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('View Leave - Coming soon')),
                );
              },
              icon: const Icon(Icons.calendar_today),
              label: const Text('View Leave'),
              style: OutlinedButton.styleFrom(
                padding: AppSpacing.mdAll,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: AppTypography.lightTextTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTypography.lightTextTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

