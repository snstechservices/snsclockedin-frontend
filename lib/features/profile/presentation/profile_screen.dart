import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sns_clocked_in/core/state/app_state.dart';
import 'package:sns_clocked_in/core/ui/app_screen_scaffold.dart';
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      profileStore.updateRoleLabel(roleLabel);
    });
    
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

    return AppScreenScaffold(
      skipScaffold: true,
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.md),
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
              const SizedBox(height: AppSpacing.lg),
            ],
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
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              CircleAvatar(
                radius: 42,
                backgroundColor: AppColors.primary,
                child: Text(
                  initials,
                  style: AppTypography.lightTextTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                  ),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                padding: EdgeInsets.all(AppSpacing.xs + 2), // 6dp for camera icon button
                child: Icon(
                  Icons.camera_alt_outlined,
                  size: 16,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            profile.fullName,
            style: AppTypography.lightTextTheme.headlineMedium?.copyWith(
              letterSpacing: -0.2,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            profile.email,
            style: AppTypography.lightTextTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
              letterSpacing: -0.1,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              _pill(label: profile.roleLabel, color: AppColors.primary),
              if (profile.employeeId != null)
                _pill(label: 'ID: ${profile.employeeId!}', color: AppColors.muted),
            ],
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
            style: AppTypography.lightTextTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.1,
            ),
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
            style: AppTypography.lightTextTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.1,
            ),
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
              fontWeight: FontWeight.w700,
              letterSpacing: -0.1,
            ),
          ),
          Text(
            value,
            style: AppTypography.lightTextTheme.bodySmall?.copyWith(
              color: color,
              letterSpacing: -0.1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _pill({required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: AppRadius.smAll,
      ),
      child: Text(
        label,
        style: AppTypography.lightTextTheme.bodySmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.1,
        ),
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

