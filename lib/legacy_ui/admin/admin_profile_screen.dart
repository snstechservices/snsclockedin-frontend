import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'dart:math';
import 'package:image_picker/image_picker.dart';
import '../../providers/auth_provider.dart';
import '../../providers/profile_provider.dart';
import '../../utils/logger.dart';
import '../../widgets/admin_side_navigation.dart';
import '../../widgets/user_avatar.dart';
import 'package:sns_rooster/services/global_notification_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../theme/app_theme.dart';
import '../../services/privacy_service.dart';

class AdminProfileScreen extends StatefulWidget {
  const AdminProfileScreen({super.key});

  @override
  State<AdminProfileScreen> createState() => _AdminProfileScreenState();
}

class _AdminProfileScreenState extends State<AdminProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _imagePicker = ImagePicker();

  bool _isLoading = false;
  bool _isPasswordLoading = false;
  bool _isUploadingAvatar = false;
  bool _showCurrentPassword = false;
  bool _showNewPassword = false;
  bool _showConfirmPassword = false;
  String? _error;
  String? _success;
  XFile? _selectedImageWeb;
  File? _selectedImageMobile;
  bool _isEditingProfile = false;

  // Password strength tracking
  Map<String, bool> _passwordStrength = {};

  // Gender selection
  String? _selectedGender;
  final List<String> _genders = [
    'male',
    'female',
    'other',
    'prefer_not_to_say',
  ];

  @override
  void initState() {
    super.initState();
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    _nameController.text = user?['firstName'] ?? '';
    _emailController.text = user?['email'] ?? '';
    _phoneController.text = user?['phone'] ?? '';
    _selectedGender =
        user?['gender'] ?? 'prefer_not_to_say'; // Initialize gender
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Always reload user data from provider when dependencies change
    final profileProvider = Provider.of<ProfileProvider>(context);
    _loadUserDataInternal(profileProvider);
  }

  void _loadUserDataInternal(ProfileProvider profileProvider) {
    final userProfile = profileProvider.profile;
    if (userProfile != null) {
      _nameController.text = userProfile['firstName'] ?? '';
      _emailController.text = userProfile['email'] ?? '';
      _phoneController.text = userProfile['phone'] ?? '';
      _selectedGender = userProfile['gender'] ?? 'prefer_not_to_say';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // Calculate password strength based on criteria
  Map<String, bool> _calculatePasswordStrength(String password) {
    return {
      'length': password.length >= 8,
      'uppercase': RegExp(r'[A-Z]').hasMatch(password),
      'lowercase': RegExp(r'[a-z]').hasMatch(password),
      'number': RegExp(r'[0-9]').hasMatch(password),
    };
  }

  // Generate a strong password that meets all requirements
  void _generateStrongPassword() {
    const String uppercase = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    const String lowercase = 'abcdefghijklmnopqrstuvwxyz';
    const String numbers = '0123456789';

    String password = '';

    // Ensure at least one of each required character type
    password += uppercase[DateTime.now().millisecond % uppercase.length];
    password += lowercase[DateTime.now().millisecond % uppercase.length];
    password += numbers[DateTime.now().millisecond % numbers.length];

    // Fill remaining characters randomly
    const String allChars = uppercase + lowercase + numbers;
    for (int i = 0; i < 5; i++) {
      password += allChars[DateTime.now().microsecond % allChars.length];
    }

    // Shuffle the password
    List<String> passwordList = password.split('');
    passwordList.shuffle();
    password = passwordList.join('');

    setState(() {
      _newPasswordController.text = password;
      _confirmPasswordController.text = password;
      _passwordStrength = _calculatePasswordStrength(password);
    });
  }

  Future<void> _pickImage(ImageSource source) async {
    // Check privacy settings before accessing media
    final privacyService = PrivacyService.instance;
    if (!await privacyService.shouldAllowCameraAccess()) {
      GlobalNotificationService().showError(
        'Media access is disabled in Privacy Settings. Please enable it to upload images.',
      );
      return;
    }

    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      if (pickedFile != null) {
        setState(() {
          if (kIsWeb) {
            _selectedImageWeb = pickedFile;
          } else {
            _selectedImageMobile = File(pickedFile.path);
          }
        });
        await _uploadProfilePicture();
      }
    } catch (e) {
      log('Error picking image: $e');
      setState(() {
        _error = 'Failed to pick image. Please try again.';
      });
    }
  }

  Future<void> _uploadProfilePicture() async {
    if (kIsWeb && _selectedImageWeb == null) return;
    if (!kIsWeb && _selectedImageMobile == null) return;
    setState(() {
      _isUploadingAvatar = true;
      _error = null;
      _success = null;
    });
    try {
      final profileProvider = Provider.of<ProfileProvider>(
        context,
        listen: false,
      );
      if (kIsWeb) {
        final bytes = await _selectedImageWeb!.readAsBytes();
        await profileProvider.updateProfilePicture(
          imageBytes: bytes,
          fileName: _selectedImageWeb!.name,
        );
      } else {
        await profileProvider.updateProfilePicture(
          imagePath: _selectedImageMobile!.path,
        );
      }
      setState(() {
        _success = 'Profile picture updated successfully!';
        _selectedImageWeb = null;
        _selectedImageMobile = null;
      });
      // Clear success message after 3 seconds
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _success = null;
          });
        }
      });
    } catch (e) {
      log('Error uploading profile picture: $e');
      setState(() {
        _error = 'An error occurred while uploading your profile picture.';
      });
    } finally {
      setState(() {
        _isUploadingAvatar = false;
      });
    }
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusLarge),
        ),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.all(AppTheme.spacingL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Choose Image Source',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: AppTheme.spacingL),
            ListTile(
              leading: Icon(Icons.camera_alt, color: AppTheme.primary),
              title: const Text('Camera'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: Icon(Icons.photo_library, color: AppTheme.success),
              title: const Text('Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            SizedBox(height: AppTheme.spacingM),
          ],
        ),
      ),
    );
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
      _success = null;
    });

    try {
      final profileProvider = Provider.of<ProfileProvider>(
        context,
        listen: false,
      );
      final result = await profileProvider.updateProfile({
        'firstName': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'gender': _selectedGender,
      });

      if (result) {
        // Refresh profile data to get the latest information
        await profileProvider.refreshProfile();

        // Re-sync controllers with latest provider data
        final p = profileProvider.profile;
        if (p != null) {
          _nameController.text = (p['firstName'] ?? '').toString();
          _emailController.text = (p['email'] ?? '').toString();
          _phoneController.text = (p['phone'] ?? '').toString();
          _selectedGender = p['gender'] ?? 'prefer_not_to_say';
        }

        setState(() {
          _success = 'Profile updated successfully!';
        });
        // Clear success message after 3 seconds
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() {
              _success = null;
            });
          }
        });
      } else {
        setState(() {
          _error = profileProvider.error ?? 'Failed to update profile.';
        });
      }
    } catch (e) {
      log('Error updating profile: $e');
      setState(() {
        _error = 'An error occurred while updating your profile.';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _clearPasswordError() {
    if (_error != null) {
      setState(() {
        _error = null;
      });
    }
  }

  Future<void> _changePassword() async {
    if (_newPasswordController.text != _confirmPasswordController.text) {
      setState(() {
        _error = 'New passwords do not match.';
      });
      return;
    }

    if (_newPasswordController.text.length < 8) {
      setState(() {
        _error = 'New password must be at least 8 characters long.';
      });
      return;
    }

    if (!RegExp(
      r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)',
    ).hasMatch(_newPasswordController.text)) {
      setState(() {
        _error = 'Password must contain uppercase, lowercase, and number.';
      });
      return;
    }

    setState(() {
      _isPasswordLoading = true;
      _error = null;
      _success = null;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final result = await authProvider.changePassword(
        _currentPasswordController.text,
        _newPasswordController.text,
      );

      if (result['success'] == true) {
        setState(() {
          _success = 'Password changed successfully!';
        });
        GlobalNotificationService().showSuccess(
          'Password changed successfully!',
        );
        _currentPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();
        // Clear success message after 3 seconds
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() {
              _success = null;
            });
          }
        });
      } else {
        setState(() {
          _error = result['message'] ?? 'Failed to change password.';
        });
        GlobalNotificationService().showError(
          result['message'] ?? 'Failed to change password.',
        );
      }
    } catch (e) {
      log('Error changing password: $e');
      setState(() {
        _error = 'An error occurred while changing your password.';
      });
      GlobalNotificationService().showError(
        'An error occurred while changing your password.',
      );
    } finally {
      setState(() {
        _isPasswordLoading = false;
      });
    }
  }

  void _startEditProfile() {
    setState(() {
      _isEditingProfile = true;
    });
  }

  void _cancelEditProfile() {
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    setState(() {
      _nameController.text = user?['firstName'] ?? '';
      _emailController.text = user?['email'] ?? '';
      _phoneController.text = user?['phone'] ?? '';
      _selectedGender = user?['gender'] ?? 'male'; // Reset gender
      _isEditingProfile = false;
    });
  }

  Widget _buildHeroSection() {
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    final profileProvider = Provider.of<ProfileProvider>(
      context,
      listen: false,
    );
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(AppTheme.spacingXl),
      child: Column(
        children: [
          SizedBox(height: AppTheme.spacingL),
          Center(
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.primary, width: 3),
              ),
              child: Stack(
                children: [
                  // Profile Picture
                  _selectedImageWeb != null
                      ? CircleAvatar(
                          radius: 50,
                          backgroundImage: FileImage(
                            File(_selectedImageWeb!.path),
                          ),
                          backgroundColor: Colors.white,
                        )
                      : _selectedImageMobile != null
                      ? CircleAvatar(
                          radius: 50,
                          backgroundImage: FileImage(_selectedImageMobile!),
                          backgroundColor: Colors.white,
                        )
                      : UserAvatar(
                          avatarUrl:
                              profileProvider.profile?['avatar'] ??
                              user?['avatar'],
                          radius: 50,
                        ),
                  // Upload Button Overlay
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                      ),
                      child: IconButton(
                        icon: _isUploadingAvatar
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : Icon(
                                Icons.camera_alt,
                                color: Colors.white,
                                size: 20,
                              ),
                        onPressed: _isUploadingAvatar
                            ? null
                            : _showImageSourceDialog,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: AppTheme.spacingL),
          Text(
            user?['firstName'] ?? 'Admin User',
            style: theme.textTheme.headlineSmall?.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: AppTheme.spacingXs),
          Text(
            user?['email'] ?? 'admin@example.com',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          SizedBox(height: AppTheme.spacingS),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: AppTheme.spacingM,
              vertical: AppTheme.spacingXs,
            ),
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
              border: Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Text(
              'Administrator',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          SizedBox(height: AppTheme.spacingL),
        ],
      ),
    );
  }

  Widget _buildProfileCard() {
    final theme = Theme.of(context);

    return Card(
      elevation: AppTheme.elevationHigh,
      margin: EdgeInsets.all(AppTheme.spacingL),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
      ),
      child: Padding(
        padding: EdgeInsets.all(AppTheme.spacingXl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.person_outline,
                  color: theme.colorScheme.primary,
                  size: 24,
                ),
                SizedBox(width: AppTheme.spacingM),
                Text(
                  'Personal Information',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (!_isEditingProfile)
                  IconButton(
                    icon: const Icon(Icons.edit),
                    tooltip: 'Edit',
                    onPressed: _startEditProfile,
                  ),
              ],
            ),
            SizedBox(height: AppTheme.spacingXl),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  _buildTextField(
                    controller: _nameController,
                    label: 'Full Name',
                    icon: Icons.person,
                    readOnly: !_isEditingProfile,
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Please enter your name'
                        : null,
                  ),
                  SizedBox(height: AppTheme.spacingL),
                  _buildTextField(
                    controller: _emailController,
                    label: 'Email Address',
                    icon: Icons.email,
                    keyboardType: TextInputType.emailAddress,
                    readOnly:
                        true, // Email is read-only since it's already verified
                  ),
                  SizedBox(height: AppTheme.spacingL),
                  _buildTextField(
                    controller: _phoneController,
                    label: 'Phone Number',
                    icon: Icons.phone,
                    keyboardType: TextInputType.phone,
                    readOnly: !_isEditingProfile,
                  ),
                  SizedBox(height: AppTheme.spacingL),
                  // Gender Selection
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedGender,
                      decoration: InputDecoration(
                        labelText: 'Gender',
                        prefixIcon: Icon(
                          Icons.person_outline,
                          color: _isEditingProfile ? null : Colors.grey[600],
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: _isEditingProfile
                            ? Colors.white
                            : Colors.grey[100],
                        labelStyle: TextStyle(
                          color: _isEditingProfile ? null : Colors.grey[600],
                        ),
                      ),
                      items: _genders.map((String gender) {
                        return DropdownMenuItem<String>(
                          value: gender,
                          child: Text(
                            gender.replaceAll('_', ' ').toUpperCase(),
                            style: TextStyle(
                              color: _isEditingProfile
                                  ? null
                                  : Colors.grey[600],
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: _isEditingProfile
                          ? (String? newValue) {
                              setState(() {
                                _selectedGender = newValue;
                              });
                            }
                          : null,
                      icon: Icon(
                        Icons.arrow_drop_down,
                        color: _isEditingProfile ? null : Colors.grey[400],
                      ),
                    ),
                  ),
                  SizedBox(height: AppTheme.spacingXl),
                  if (_isEditingProfile)
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 50,
                            child: ElevatedButton(
                              onPressed: _isLoading
                                  ? null
                                  : () async {
                                      await _saveProfile();
                                      setState(() {
                                        _isEditingProfile = false;
                                      });
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: theme.colorScheme.primary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 2,
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                      ),
                                    )
                                  : const Text(
                                      'Save Changes',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SizedBox(
                            height: 50,
                            child: OutlinedButton(
                              onPressed: _cancelEditProfile,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: theme.colorScheme.primary,
                                side: BorderSide(
                                  color: theme.colorScheme.primary,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'Cancel',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  if (!_isEditingProfile)
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary.withValues(
                            alpha: 0.5,
                          ),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                        child: const Text(
                          'Save Changes',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPasswordCard() {
    final theme = Theme.of(context);

    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.lock_outline,
                  color: theme.colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  'Change Password',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _currentPasswordController,
              obscureText: !_showCurrentPassword,
              onChanged: (_) => _clearPasswordError(),
              decoration: InputDecoration(
                labelText: 'Current Password',
                prefixIcon: Icon(Icons.lock, color: theme.colorScheme.primary),
                suffixIcon: IconButton(
                  icon: Icon(
                    _showCurrentPassword
                        ? Icons.visibility
                        : Icons.visibility_off,
                    color: theme.colorScheme.primary,
                  ),
                  onPressed: () {
                    setState(() {
                      _showCurrentPassword = !_showCurrentPassword;
                    });
                  },
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  borderSide: BorderSide(color: theme.colorScheme.outline),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  borderSide: BorderSide(color: theme.colorScheme.outline),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  borderSide: BorderSide(
                    color: theme.colorScheme.primary,
                    width: 2,
                  ),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  borderSide: BorderSide(color: theme.colorScheme.outline),
                ),
                filled: true,
                fillColor: theme.colorScheme.surface,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingL,
                  vertical: AppTheme.spacingL,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _newPasswordController,
                  obscureText: !_showNewPassword,
                  onChanged: (value) {
                    _clearPasswordError();
                    setState(() {
                      _passwordStrength = _calculatePasswordStrength(value);
                    });
                  },
                  decoration: InputDecoration(
                    labelText: 'New Password',
                    prefixIcon: Icon(
                      Icons.lock_outline,
                      color: theme.colorScheme.primary,
                    ),
                    helperText: 'Enter a strong password or use auto-generate',
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.refresh),
                          onPressed: _generateStrongPassword,
                          tooltip: 'Generate strong password',
                        ),
                        IconButton(
                          icon: Icon(
                            _showNewPassword
                                ? Icons.visibility
                                : Icons.visibility_off,
                            color: theme.colorScheme.primary,
                          ),
                          onPressed: () {
                            setState(() {
                              _showNewPassword = !_showNewPassword;
                            });
                          },
                        ),
                      ],
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        AppTheme.radiusMedium,
                      ),
                      borderSide: BorderSide(color: theme.colorScheme.outline),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        AppTheme.radiusMedium,
                      ),
                      borderSide: BorderSide(color: theme.colorScheme.outline),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        AppTheme.radiusMedium,
                      ),
                      borderSide: BorderSide(
                        color: theme.colorScheme.primary,
                        width: 2,
                      ),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        AppTheme.radiusMedium,
                      ),
                      borderSide: BorderSide(color: theme.colorScheme.outline),
                    ),
                    filled: true,
                    fillColor: theme.colorScheme.surface,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: AppTheme.spacingL,
                      vertical: AppTheme.spacingL,
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a new password';
                    }
                    if (value.length < 8) {
                      return 'Password must be at least 8 characters';
                    }
                    if (!RegExp(
                      r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)',
                    ).hasMatch(value)) {
                      return 'Password must contain uppercase, lowercase, and number';
                    }
                    return null;
                  },
                ),

                // Password strength indicator
                if (_newPasswordController.text.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _buildPasswordStrengthIndicator(),
                  const SizedBox(height: 4),
                  _buildPasswordRequirementsChecklist(),
                ],
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _confirmPasswordController,
              obscureText: !_showConfirmPassword,
              onChanged: (_) => _clearPasswordError(),
              decoration: InputDecoration(
                labelText: 'Confirm New Password',
                prefixIcon: Icon(
                  Icons.lock_outline,
                  color: theme.colorScheme.primary,
                ),
                helperText: 'Re-enter your new password',
                suffixIcon: IconButton(
                  icon: Icon(
                    _showConfirmPassword
                        ? Icons.visibility
                        : Icons.visibility_off,
                    color: theme.colorScheme.primary,
                  ),
                  onPressed: () {
                    setState(() {
                      _showConfirmPassword = !_showConfirmPassword;
                    });
                  },
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  borderSide: BorderSide(color: theme.colorScheme.outline),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  borderSide: BorderSide(color: theme.colorScheme.outline),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  borderSide: BorderSide(
                    color: theme.colorScheme.primary,
                    width: 2,
                  ),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  borderSide: BorderSide(color: theme.colorScheme.outline),
                ),
                filled: true,
                fillColor: theme.colorScheme.surface,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingL,
                  vertical: AppTheme.spacingL,
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please confirm your new password';
                }
                if (value != _newPasswordController.text) {
                  return 'Passwords do not match';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isPasswordLoading ? null : _changePassword,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.secondary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
                child: _isPasswordLoading
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
                        'Change Password',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    bool readOnly = false,
  }) {
    final theme = Theme.of(context);

    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      readOnly: readOnly,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: theme.colorScheme.primary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          borderSide: BorderSide(color: theme.colorScheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          borderSide: BorderSide(color: theme.colorScheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          borderSide: BorderSide(color: theme.colorScheme.error),
        ),
        filled: true,
        fillColor: theme.colorScheme.surface,
        contentPadding: EdgeInsets.symmetric(
          horizontal: AppTheme.spacingL,
          vertical: AppTheme.spacingL,
        ),
      ),
    );
  }

  Widget _buildFeedbackMessage() {
    if (_error == null && _success == null) return const SizedBox.shrink();

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: AppTheme.spacingL,
        vertical: AppTheme.spacingS,
      ),
      padding: EdgeInsets.all(AppTheme.spacingL),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(
          color: _error != null
              ? AppTheme.error.withValues(alpha: 0.3)
              : AppTheme.success.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            _error != null ? Icons.error_outline : Icons.check_circle_outline,
            color: _error != null ? AppTheme.error : AppTheme.success,
          ),
          SizedBox(width: AppTheme.spacingM),
          Expanded(
            child: Text(
              _error ?? _success ?? '',
              style: TextStyle(
                color: _error != null
                    ? Colors.red.shade700
                    : Colors.green.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () {
              setState(() {
                _error = null;
                _success = null;
              });
            },
            color: _error != null ? Colors.red : Colors.green,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AdminSideNavigation(currentRoute: '/admin_profile'),
      body: Stack(
        children: [
          // Dotted background throughout the entire page
          Positioned.fill(
            child: CustomPaint(
              painter: _DotPatternPainter(
                color: AppTheme.primary.withValues(alpha: 0.05),
              ),
            ),
          ),
          // Main content
          CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 0,
                floating: false,
                pinned: true,
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                title: const Text('My Profile'),
                elevation: 0,
              ),
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    _buildHeroSection(),
                    _buildFeedbackMessage(),
                    _buildProfileCard(),
                    _buildPasswordCard(),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Build password strength indicator
  Widget _buildPasswordStrengthIndicator() {
    final theme = Theme.of(context);

    int metCriteria = _passwordStrength.values.where((met) => met).length;
    int totalCriteria = _passwordStrength.length;
    double strengthPercentage = metCriteria / totalCriteria;

    Color strengthColor;
    String strengthText;

    if (strengthPercentage == 1.0) {
      strengthColor = Colors.green;
      strengthText = 'Strong';
    } else if (strengthPercentage >= 0.75) {
      strengthColor = Colors.orange;
      strengthText = 'Good';
    } else if (strengthPercentage >= 0.5) {
      strengthColor = Colors.yellow[700]!;
      strengthText = 'Fair';
    } else {
      strengthColor = Colors.red;
      strengthText = 'Weak';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Password Strength: ',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              strengthText,
              style: theme.textTheme.bodySmall?.copyWith(
                color: strengthColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: strengthPercentage,
          backgroundColor: Colors.grey[300],
          valueColor: AlwaysStoppedAnimation<Color>(strengthColor),
        ),
      ],
    );
  }

  // Build password requirements checklist
  Widget _buildPasswordRequirementsChecklist() {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Requirements:',
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        _buildRequirementItem(
          'At least 8 characters',
          _passwordStrength['length'] ?? false,
        ),
        _buildRequirementItem(
          'Contains uppercase letter',
          _passwordStrength['uppercase'] ?? false,
        ),
        _buildRequirementItem(
          'Contains lowercase letter',
          _passwordStrength['lowercase'] ?? false,
        ),
        _buildRequirementItem(
          'Contains number',
          _passwordStrength['number'] ?? false,
        ),
      ],
    );
  }

  // Build individual requirement item
  Widget _buildRequirementItem(String text, bool isMet) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          Icon(
            isMet ? Icons.check_circle : Icons.circle_outlined,
            size: 16,
            color: isMet ? Colors.green : Colors.grey,
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(
              color: isMet ? Colors.green : Colors.grey[600],
              decoration: isMet ? TextDecoration.lineThrough : null,
            ),
          ),
        ],
      ),
    );
  }
}

// Custom painter for abstract dot pattern background

// Custom painter for abstract dot pattern background
class _DotPatternPainter extends CustomPainter {
  final Color color;

  _DotPatternPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    const double dotSize = 3.0;
    const int numberOfDots = 50; // Random number of dots

    // Draw dots in random positions
    for (int i = 0; i < numberOfDots; i++) {
      final randomX =
          (i * 37.0) % size.width; // Pseudo-random but deterministic
      final randomY = (i * 73.0) % size.height;

      // Add some variation to dot sizes
      final currentDotSize = dotSize + (i % 3) * 1.0;

      canvas.drawCircle(Offset(randomX, randomY), currentDotSize, paint);
    }

    // Add various types of lines for more abstract feel
    final linePaint = Paint()
      ..color = color.withValues(alpha: 0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // Diagonal lines
    for (double i = 0; i < size.width + size.height; i += 120) {
      canvas.drawLine(
        Offset(i, 0),
        Offset(i - size.height, size.height),
        linePaint,
      );
    }

    // Horizontal wavy lines
    final wavyPaint = Paint()
      ..color = color.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (double y = 50; y < size.height; y += 100) {
      final path = Path();
      path.moveTo(0, y);

      for (double x = 0; x <= size.width; x += 20) {
        final waveY = y + 10 * sin(x / 50);
        path.lineTo(x, waveY);
      }

      canvas.drawPath(path, wavyPaint);
    }

    // Curved arc lines
    final curvePaint = Paint()
      ..color = color.withValues(alpha: 0.06)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    for (double x = 100; x < size.width; x += 150) {
      final path = Path();
      path.moveTo(x, 0);
      path.quadraticBezierTo(x + 50, size.height / 3, x, size.height * 0.6);
      path.quadraticBezierTo(x - 50, size.height * 0.8, x, size.height);
      canvas.drawPath(path, curvePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
