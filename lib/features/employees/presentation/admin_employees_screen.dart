import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:sns_clocked_in/core/role/role.dart';
import 'package:sns_clocked_in/core/ui/app_card.dart';
import 'package:sns_clocked_in/core/ui/app_screen_scaffold.dart';
import 'package:sns_clocked_in/core/ui/stat_card.dart';
import 'package:sns_clocked_in/core/ui/list_skeleton.dart';
import 'package:sns_clocked_in/core/ui/status_badge.dart';
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
  EmployeeStatus? _statusFilter;

  @override
  void initState() {
    super.initState();
    // Seed sample data on first load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<EmployeesStore>().seedSampleData();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final state = GoRouterState.of(context);
    final statusParam = state.uri.queryParameters['status'];
    if (statusParam == null) return;

    final store = context.read<EmployeesStore>();
    EmployeeStatus? parsed;
    if (statusParam == 'active') {
      parsed = EmployeeStatus.active;
    } else if (statusParam == 'inactive') {
      parsed = EmployeeStatus.inactive;
    }

    if (parsed != _statusFilter) {
      setState(() => _statusFilter = parsed);
      store.filterByStatus(parsed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final employeesStore = context.watch<EmployeesStore>();
    final employees = employeesStore.filteredEmployees;

    return AppScreenScaffold(
      skipScaffold: true,
      child: Column(
          children: [
            // Quick Stats at top (always visible, match pattern)
            _buildQuickStatsSection(context, employeesStore),
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
    );
  }

  Widget _buildQuickStatsSection(BuildContext context, EmployeesStore store) {
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
              Icon(Icons.people, size: 18, color: AppColors.textSecondary),
              const SizedBox(width: AppSpacing.xs),
              Text(
                'Employees Summary',
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
                    'Total Employees',
                    store.totalCount.toString(),
                    AppColors.primary,
                    Icons.people,
                    onTap: () => _applyStatusFilter(null, store),
                    isSelected: _statusFilter == null,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                SizedBox(
                  width: 140,
                  child: _buildStatCard(
                    'Active',
                    store.activeCount.toString(),
                    AppColors.success,
                    Icons.check_circle,
                    onTap: () => _applyStatusFilter(EmployeeStatus.active, store),
                    isSelected: _statusFilter == EmployeeStatus.active,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                SizedBox(
                  width: 140,
                  child: _buildStatCard(
                    'Inactive',
                    store.inactiveCount.toString(),
                    AppColors.warning,
                    Icons.person_off,
                    onTap: () => _applyStatusFilter(EmployeeStatus.inactive, store),
                    isSelected: _statusFilter == EmployeeStatus.inactive,
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
    {
    VoidCallback? onTap,
    bool isSelected = false,
    }
  ) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      onTap: onTap,
      borderColor: isSelected ? color.withValues(alpha: 0.6) : null,
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

  void _applyStatusFilter(EmployeeStatus? status, EmployeesStore store) {
    setState(() => _statusFilter = status);
    store.filterByStatus(status);
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
    // Get initials for avatar
    final initials = employee.fullName
        .split(' ')
        .map((name) => name.isNotEmpty ? name[0].toUpperCase() : '')
        .take(2)
        .join();

    return AppCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: AppSpacing.mdAll,
      onTap: () => _showEmployeeDetail(employee),
      child: Row(
        children: [
          // Avatar
          CircleAvatar(
            radius: 28,
            backgroundColor: AppColors.primary,
            child: Text(
              initials,
              style: AppTypography.lightTextTheme.bodyLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          // Employee Info - Improved layout with proper text overflow
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Name - single line with ellipsis
                Text(
                  employee.fullName,
                  style: AppTypography.lightTextTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                // Department and Status in a row
                Row(
                  children: [
                    Icon(
                      Icons.business_outlined,
                      size: 14,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        employee.department,
                        style: AppTypography.lightTextTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                // Email - single line with ellipsis
                Row(
                  children: [
                    Icon(
                      Icons.email_outlined,
                      size: 14,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        employee.email,
                        style: AppTypography.lightTextTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          // Status Chip - moved before actions
           _buildStatusBadge(employee.status),
          const SizedBox(width: AppSpacing.xs),
          // Action Icons - more compact
          PopupMenuButton<String>(
            icon: Icon(
              Icons.more_vert,
              color: AppColors.textSecondary,
              size: 20,
            ),
            onSelected: (value) {
              if (value == 'edit') {
                _showEditEmployeeDialog(employee);
              } else if (value == 'delete') {
                _showDeleteEmployeeDialog(employee);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit_outlined, size: 18),
                    SizedBox(width: AppSpacing.sm),
                    Text('Edit'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                    SizedBox(width: AppSpacing.sm),
                    Text('Delete', style: TextStyle(color: AppColors.error)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(EmployeeStatus status) {
    final isActive = status == EmployeeStatus.active;
    final (label, type) = isActive
        ? ('Active', StatusBadgeType.approved)
        : ('Inactive', StatusBadgeType.cancelled);

    return StatusBadge(label: label, type: type, compact: true);
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

  void _showEditEmployeeDialog(Employee employee) {
    final nameController = TextEditingController(text: employee.fullName);
    final emailController = TextEditingController(text: employee.email);
    final deptController = TextEditingController(text: employee.department);
    EmployeeStatus status = employee.status;
    Role role = employee.role;

    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Employee'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Full name'),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: deptController,
                  decoration: const InputDecoration(labelText: 'Department'),
                ),
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<EmployeeStatus>(
                  value: status,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: EmployeeStatus.values
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(value == EmployeeStatus.active ? 'Active' : 'Inactive'),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => status = value ?? status,
                ),
                const SizedBox(height: AppSpacing.sm),
                DropdownButtonFormField<Role>(
                  value: role,
                  decoration: const InputDecoration(labelText: 'Role'),
                  items: Role.values
                      .where((value) => value != Role.superAdmin)
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(value == Role.admin ? 'Admin' : 'Employee'),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => role = value ?? role,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final store = context.read<EmployeesStore>();
                store.updateEmployee(
                  employee.copyWith(
                    fullName: nameController.text.trim(),
                    email: emailController.text.trim(),
                    department: deptController.text.trim(),
                    status: status,
                    role: role,
                  ),
                );
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Employee updated (demo)')),
                );
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteEmployeeDialog(Employee employee) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Employee'),
          content: Text('Remove ${employee.fullName} from this list?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final store = context.read<EmployeesStore>();
                store.deleteEmployee(employee.id);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Employee removed (demo)')),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
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
                context.go('/a/attendance');
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
                context.go('/a/leave/history?employeeId=${employee.id}');
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

