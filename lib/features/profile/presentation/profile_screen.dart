import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sns_clocked_in/core/state/app_state.dart';
import 'package:sns_clocked_in/features/profile/application/profile_store.dart';
import 'package:sns_clocked_in/features/profile/domain/user_profile.dart';
import 'package:sns_clocked_in/design_system/app_colors.dart';
import 'package:sns_clocked_in/design_system/app_radius.dart';
import 'package:sns_clocked_in/design_system/app_spacing.dart';
import 'package:sns_clocked_in/design_system/app_typography.dart';

/// Profile screen for viewing and editing user profile
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _phoneController;
  late TextEditingController _departmentController;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    final profileStore = context.read<ProfileStore>();
    final appState = context.read<AppState>();
    
    // Initialize profile with current role
    final roleLabel = appState.currentRole.value == 'super_admin'
        ? 'Super Admin'
        : appState.currentRole.value == 'admin'
            ? 'Admin'
            : 'Employee';
    profileStore.updateRoleLabel(roleLabel);
    
    _phoneController = TextEditingController(text: profileStore.profile.phone ?? '');
    _departmentController = TextEditingController(text: profileStore.profile.department ?? '');
    
    _phoneController.addListener(_onFieldChanged);
    _departmentController.addListener(_onFieldChanged);
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _departmentController.dispose();
    super.dispose();
  }

  void _onFieldChanged() {
    final profileStore = context.read<ProfileStore>();
    final hasChanges = _phoneController.text != (profileStore.profile.phone ?? '') ||
        _departmentController.text != (profileStore.profile.department ?? '');
    
    if (hasChanges != _hasChanges) {
      setState(() {
        _hasChanges = hasChanges;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileStore = context.watch<ProfileStore>();
    final profile = profileStore.profile;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text(
          'Profile',
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
                // Profile Card
                _buildProfileCard(profile),
                const SizedBox(height: AppSpacing.lg),

                // Editable Fields
                _buildEditableFields(),
                const SizedBox(height: AppSpacing.lg),

                // Read-only Chips
                _buildReadOnlyChips(profile),
                const SizedBox(height: AppSpacing.xl),

                // Save Button
                ElevatedButton(
                  onPressed: _hasChanges ? _handleSave : null,
                  style: ElevatedButton.styleFrom(
                    padding: AppSpacing.lgAll,
                  ),
                  child: const Text('Save'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileCard(UserProfile profile) {
    // Get initials from full name
    final initials = profile.fullName
        .split(' ')
        .map((name) => name.isNotEmpty ? name[0].toUpperCase() : '')
        .take(2)
        .join();

    return Container(
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
      padding: AppSpacing.lgAll,
      child: Column(
        children: [
          // Avatar
          CircleAvatar(
            radius: 40,
            backgroundColor: AppColors.primary,
            child: Text(
              initials,
              style: AppTypography.lightTextTheme.headlineMedium?.copyWith(
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          // Name (read-only)
          Text(
            profile.fullName,
            style: AppTypography.lightTextTheme.headlineMedium,
          ),
          const SizedBox(height: AppSpacing.xs),
          // Email (read-only)
          Text(
            profile.email,
            style: AppTypography.lightTextTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditableFields() {
    return Container(
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
      padding: AppSpacing.lgAll,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Contact Information',
            style: AppTypography.lightTextTheme.labelLarge,
          ),
          const SizedBox(height: AppSpacing.md),
          // Phone field
          TextFormField(
            controller: _phoneController,
            decoration: InputDecoration(
              labelText: 'Phone',
              hintText: 'Enter phone number',
              border: OutlineInputBorder(
                borderRadius: AppRadius.mediumAll,
              ),
            ),
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: AppSpacing.md),
          // Department field
          TextFormField(
            controller: _departmentController,
            decoration: InputDecoration(
              labelText: 'Department',
              hintText: 'Enter department',
              border: OutlineInputBorder(
                borderRadius: AppRadius.mediumAll,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReadOnlyChips(UserProfile profile) {
    return Container(
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
      padding: AppSpacing.lgAll,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Details',
            style: AppTypography.lightTextTheme.labelLarge,
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              _buildChip(
                label: 'Role',
                value: profile.roleLabel,
                color: AppColors.primary,
              ),
              if (profile.employeeId != null)
                _buildChip(
                  label: 'Employee ID',
                  value: profile.employeeId!,
                  color: AppColors.textSecondary,
                ),
              _buildChip(
                label: 'Company',
                value: 'S&S Accounting', // Placeholder
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChip({
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: AppRadius.smAll,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: AppTypography.lightTextTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            value,
            style: AppTypography.lightTextTheme.bodySmall?.copyWith(
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  void _handleSave() {
    if (!_formKey.currentState!.validate()) return;

    final profileStore = context.read<ProfileStore>();
    profileStore.updateProfile(
      phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
      department: _departmentController.text.trim().isEmpty ? null : _departmentController.text.trim(),
    );

    setState(() {
      _hasChanges = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Saved')),
    );
  }
}

