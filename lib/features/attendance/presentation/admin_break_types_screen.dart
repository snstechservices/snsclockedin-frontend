import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:sns_clocked_in/core/ui/app_card.dart';
import 'package:sns_clocked_in/core/ui/app_screen_scaffold.dart';
import 'package:sns_clocked_in/features/attendance/application/break_types_store.dart';
import 'package:sns_clocked_in/features/attendance/data/break_types_repository.dart';
import 'package:sns_clocked_in/design_system/app_colors.dart';
import 'package:sns_clocked_in/design_system/app_radius.dart';
import 'package:sns_clocked_in/design_system/app_spacing.dart';
import 'package:sns_clocked_in/design_system/app_typography.dart';

/// Admin break types management screen
class AdminBreakTypesScreen extends StatefulWidget {
  const AdminBreakTypesScreen({super.key});

  @override
  State<AdminBreakTypesScreen> createState() => _AdminBreakTypesScreenState();
}

class _AdminBreakTypesScreenState extends State<AdminBreakTypesScreen> {
  @override
  void initState() {
    super.initState();
    // Load break types on first load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BreakTypesStore>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<BreakTypesStore>();

    final totalCount = store.breakTypes.length;
    final activeCount = store.activeBreakTypes.length;
    final inactiveCount = totalCount - activeCount;

    return AppScreenScaffold(
      skipScaffold: true,
      child: Column(
        children: [
          // Quick Stats at top (always visible, match pattern)
          _buildQuickStatsSection(totalCount, activeCount, inactiveCount),
          // Header with Add button
          Padding(
            padding: AppSpacing.lgAll,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Compact add button
                ElevatedButton.icon(
                  onPressed: () => _showBreakTypeDialog(context, null),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.mediumAll,
                    ),
                    elevation: 2,
                  ),
                ),
              ],
            ),
          ),
          // Break Types List
          Expanded(
            child: store.isLoading && store.breakTypes.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : store.error != null && store.breakTypes.isEmpty
                    ? _buildErrorState(context, store)
                    : store.breakTypes.isEmpty
                        ? _buildEmptyState()
                        : RefreshIndicator(
                            onRefresh: () => store.load(forceRefresh: true),
                            child: ListView.builder(
                              padding: AppSpacing.lgAll,
                              itemCount: store.breakTypes.length,
                              itemBuilder: (context, index) {
                                return _buildBreakTypeCard(
                                  context,
                                  store.breakTypes[index],
                                  store,
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStatsSection(int total, int active, int inactive) {
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
              Icon(Icons.coffee, size: 18, color: AppColors.textSecondary),
              const SizedBox(width: AppSpacing.xs),
              Text(
                'Break Types Summary',
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
                    'Total',
                    total.toString(),
                    AppColors.primary,
                    Icons.coffee,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                SizedBox(
                  width: 140,
                  child: _buildStatCard(
                    'Active',
                    active.toString(),
                    AppColors.success,
                    Icons.check_circle,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                SizedBox(
                  width: 140,
                  child: _buildStatCard(
                    'Inactive',
                    inactive.toString(),
                    AppColors.warning,
                    Icons.person_off,
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

  Widget _buildErrorState(BuildContext context, BreakTypesStore store) {
    return Center(
      child: Padding(
        padding: AppSpacing.xlAll,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: AppColors.error,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Failed to load break types',
              style: AppTypography.lightTextTheme.titleMedium?.copyWith(
                color: AppColors.error,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              store.error ?? 'Unknown error',
              style: AppTypography.lightTextTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton.icon(
              onPressed: () => store.load(forceRefresh: true),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
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
              Icons.coffee_outlined,
              size: 80,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'No Break Types',
              style: AppTypography.lightTextTheme.headlineMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Add your first break type to get started',
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

  Widget _buildBreakTypeCard(
    BuildContext context,
    BreakType breakType,
    BreakTypesStore store,
  ) {
    // Parse color
    Color? color;
    if (breakType.color != null) {
      try {
        color = Color(int.parse(breakType.color!.replaceFirst('#', '0xFF')));
      } catch (_) {
        color = AppColors.primary;
      }
    } else {
      color = AppColors.primary;
    }

    // Get icon
    IconData icon = _getIconData(breakType.icon ?? 'coffee');

    return AppCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: AppSpacing.lgAll,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Icon
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: breakType.isActive ? color : AppColors.textSecondary,
                  borderRadius: AppRadius.mediumAll,
                ),
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              // Name and details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            breakType.label,
                            style: AppTypography.lightTextTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: breakType.isActive
                                  ? AppColors.textPrimary
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ),
                        // Status chip
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: breakType.isActive
                                ? AppColors.success.withValues(alpha: 0.1)
                                : AppColors.textSecondary.withValues(alpha: 0.1),
                            borderRadius: AppRadius.smAll,
                          ),
                          child: Text(
                            breakType.isActive ? 'Active' : 'Inactive',
                            style: AppTypography.lightTextTheme.bodySmall?.copyWith(
                              color: breakType.isActive
                                  ? AppColors.success
                                  : AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (breakType.description != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        breakType.description!,
                        style: AppTypography.lightTextTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                    if (breakType.durationRange.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 14,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            breakType.durationRange,
                            style: AppTypography.lightTextTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              // Action buttons
              PopupMenuButton<String>(
                icon: Icon(
                  Icons.more_vert,
                  color: AppColors.textSecondary,
                ),
                onSelected: (value) {
                  if (value == 'edit') {
                    _showBreakTypeDialog(context, breakType);
                  } else if (value == 'delete') {
                    _showDeleteConfirmDialog(context, breakType, store);
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
        ],
      ),
    );
  }

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'coffee':
        return Icons.coffee;
      case 'restaurant':
        return Icons.restaurant;
      case 'person':
        return Icons.person;
      case 'lunch_dining':
        return Icons.lunch_dining;
      default:
        return Icons.coffee;
    }
  }

  void _showBreakTypeDialog(BuildContext context, BreakType? breakType) {
    final isEdit = breakType != null;
    final formKey = GlobalKey<FormState>();
    final displayNameController = TextEditingController(
      text: breakType?.displayName ?? '',
    );
    final descriptionController = TextEditingController(
      text: breakType?.description ?? '',
    );
    final minDurationController = TextEditingController(
      text: breakType?.minDurationMinutes?.toString() ?? '',
    );
    final maxDurationController = TextEditingController(
      text: breakType?.maxDurationMinutes?.toString() ?? '',
    );
    String selectedIcon = breakType?.icon ?? 'coffee';
    String selectedColor = breakType?.color ?? '#6B7280';
    bool isActive = breakType?.isActive ?? true;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEdit ? 'Edit Break Type' : 'Add Break Type'),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: displayNameController,
                  decoration: const InputDecoration(
                    labelText: 'Display Name *',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Display name is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: minDurationController,
                        decoration: const InputDecoration(
                          labelText: 'Min Duration (minutes)',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: TextFormField(
                        controller: maxDurationController,
                        decoration: const InputDecoration(
                          labelText: 'Max Duration (minutes)',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                // Icon selector
                DropdownButtonFormField<String>(
                  value: selectedIcon,
                  decoration: const InputDecoration(
                    labelText: 'Icon',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'coffee', child: Text('Coffee')),
                    DropdownMenuItem(value: 'restaurant', child: Text('Restaurant')),
                    DropdownMenuItem(value: 'person', child: Text('Person')),
                    DropdownMenuItem(value: 'lunch_dining', child: Text('Lunch Dining')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        selectedIcon = value;
                      });
                    }
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                // Color picker (simplified - using predefined colors)
                DropdownButtonFormField<String>(
                  value: selectedColor,
                  decoration: const InputDecoration(
                    labelText: 'Color',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: '#2E7D32', child: Text('Green')),
                    DropdownMenuItem(value: '#7B1FA2', child: Text('Purple')),
                    DropdownMenuItem(value: '#ED6C02', child: Text('Orange')),
                    DropdownMenuItem(value: '#1976D2', child: Text('Blue')),
                    DropdownMenuItem(value: '#6B7280', child: Text('Gray')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        selectedColor = value;
                      });
                    }
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                // Active toggle
                SwitchListTile(
                  title: const Text('Active'),
                  value: isActive,
                  onChanged: (value) {
                    setState(() {
                      isActive = value;
                    });
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;

              final store = context.read<BreakTypesStore>();
              final data = {
                'displayName': displayNameController.text.trim(),
                'name': displayNameController.text
                    .trim()
                    .toLowerCase()
                    .replaceAll(RegExp(r'[^a-z0-9]+'), '_'),
                'description': descriptionController.text.trim(),
                'icon': selectedIcon,
                'color': selectedColor,
                if (minDurationController.text.isNotEmpty)
                  'minDuration': int.tryParse(minDurationController.text),
                if (maxDurationController.text.isNotEmpty)
                  'maxDuration': int.tryParse(maxDurationController.text),
                'isActive': isActive,
              };

              try {
                if (isEdit) {
                  // Use ID if available, otherwise use name
                  final id = breakType!.id ?? breakType.name;
                  await store.updateBreakType(id, data);
                } else {
                  await store.createBreakType(data);
                }
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        isEdit
                            ? 'Break type updated successfully'
                            : 'Break type created successfully',
                      ),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: ${e.toString()}'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              }
            },
            child: Text(isEdit ? 'Update' : 'Create'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmDialog(
    BuildContext context,
    BreakType breakType,
    BreakTypesStore store,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Break Type'),
        content: Text('Are you sure you want to delete "${breakType.label}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                // Use ID if available, otherwise use name
                final id = breakType.id ?? breakType.name;
                await store.deleteBreakType(id);
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Break type deleted successfully'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: ${e.toString()}'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
