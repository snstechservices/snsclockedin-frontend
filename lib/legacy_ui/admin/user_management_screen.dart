import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../config/api_config.dart';
import '../../widgets/admin_side_navigation.dart';
import '../../services/api_service.dart';
import '../../services/secure_storage_service.dart';
import '../../utils/logger.dart';
import '../../theme/app_theme.dart';
import '../../services/global_notification_service.dart';

// (previously had a local print redirect; removed to avoid ambiguous symbol imports)

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  _UserManagementScreenState createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();

  bool _isLoading = false;
  String? _error;
  List<Map<String, dynamic>> _users = [];
  bool _showInactive = false; // show inactive users toggle

  String? _selectedRole;
  final List<String> _roles = ['employee', 'admin'];
  String? _selectedGender;
  final List<String> _genders = [
    'male',
    'female',
    'other',
    'prefer_not_to_say',
  ];
  bool _isAddUserExpanded = false; // Track whether add user section is expanded
  bool _obscurePassword = true; // Track password visibility
  Map<String, bool> _passwordStrength = {}; // Track password strength criteria

  @override
  void initState() {
    super.initState();
    _selectedGender = _genders[3]; // Default to 'prefer_not_to_say'
    _loadUsers();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers({bool showErrors = true}) async {
    setState(() {
      _isLoading = true;
      _error = null; // Always clear error at the start of loading
    });

    Logger.info('Attempting to load users...');

    try {
      final apiService = ApiService(baseUrl: ApiConfig.baseUrl);

      final endpoint =
          '/auth/users${_showInactive ? '?showInactive=true' : ''}';
      Logger.info('Requesting users from: ${ApiConfig.baseUrl}$endpoint');

      // Temporary debug: check whether an auth token exists (do NOT log the token)
      try {
        final token = await SecureStorageService.getAuthToken();
        if (token != null && token.isNotEmpty) {
          Logger.info(
            'Auth token present (length=${token.length}). App should send Authorization header.',
          );
        } else {
          Logger.warning(
            'No auth token found in SecureStorage. Requests will be unauthenticated.',
          );
          if (mounted && showErrors) {
            GlobalNotificationService().showWarning(
              'Auth token missing — you may be logged out',
            );
          }
        }
      } catch (e) {
        Logger.error('Error reading auth token for debug: $e');
      }

      final response = await apiService.get(endpoint);

      Logger.info('Load users response success: ${response.success}');
      Logger.info('Load users response message: ${response.message}');

      if (response.success) {
        // Parse and store users
        final loaded = List<Map<String, dynamic>>.from(response.data ?? []);
        final inactiveCount = loaded
            .where((u) => u['isActive'] == false)
            .length;

        setState(() {
          _users = loaded;
          _isLoading = false;
          _error = null; // Clear error on successful load
        });

        Logger.info('Users loaded successfully: ${_users.length} users');
        Logger.info('Inactive users in response: $inactiveCount');

        // If user requested inactive users but none were returned, notify and log response for debugging
        if (_showInactive && inactiveCount == 0) {
          Logger.warning(
            'ShowInactive requested but no inactive users returned. Response data preview: ${response.data}',
          );
          if (mounted && showErrors) {
            GlobalNotificationService().showWarning(
              'No inactive users found for this company',
            );
          }
        }
      } else {
        setState(() {
          _error = response.message;
          _isLoading = false;
        });
        // Show a notification for better UX
        if (mounted && showErrors) {
          GlobalNotificationService().showError(
            _error ?? 'Failed to load users',
          );
        }
      }
    } catch (e) {
      Logger.error('Error loading users: $e');
      setState(() {
        _error = 'Network error occurred';
        _isLoading = false;
      });
      if (mounted && showErrors) {
        GlobalNotificationService().showError('Network error occurred');
      }
    }
  }

  void _resetFormFields() {
    _formKey.currentState?.reset();
    _emailController.clear();
    _passwordController.clear();
    _firstNameController.clear();
    _lastNameController.clear();
    setState(() {
      _selectedRole = null;
      _selectedGender = _genders[3]; // Reset to 'prefer_not_to_say'
    });
    // _generateEmployeeId(); // Also, auto-generate Employee ID after form reset
  }

  void _toggleAddUserSection() {
    setState(() {
      _isAddUserExpanded = !_isAddUserExpanded;
      // Reset form when collapsing
      if (!_isAddUserExpanded) {
        _resetFormFields();
      }
    });
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
    password += lowercase[DateTime.now().millisecond % lowercase.length];
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
      _passwordController.text = password;
      _passwordStrength = _calculatePasswordStrength(password);
    });
  }

  Future<void> _createUser() async {
    Logger.info('_createUser called');

    // Prevent multiple simultaneous calls
    if (_isLoading) {
      if (kDebugMode)
        Logger.debug('Duplicate _createUser call ignored: already loading');
      return;
    }
    Logger.info('Form validation starting');

    if (!_formKey.currentState!.validate()) {
      Logger.error('Form validation failed');
      return;
    }

    Logger.info('Form validation passed');
    Logger.info('Starting user creation process');
    if (kDebugMode)
      Logger.debug(
        'Selected role: $_selectedRole, selected gender: $_selectedGender',
      );

    if (_selectedRole == null) {
      Logger.error('No role selected');
      if (mounted) {
        setState(() {
          _error = 'Please select a role';
          _isLoading = false;
        });
      }
      return;
    }

    if (kDebugMode) Logger.debug('Role validation passed: $_selectedRole');
    if (kDebugMode) Logger.debug('Setting loading state to true');

    if (mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
      if (kDebugMode)
        Logger.debug('Loading state set - _isLoading: $_isLoading');
    } else {
      if (kDebugMode) Logger.debug('Widget not mounted - skipping setState');
    }

    if (kDebugMode) Logger.debug('Entering try block for user creation');
    try {
      if (kDebugMode) Logger.debug('Creating ApiService');
      final apiService = ApiService(baseUrl: ApiConfig.baseUrl);

      if (kDebugMode) Logger.debug('Obtaining company ID from AuthProvider');
      // Get company ID from AuthProvider user data
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final companyId = authProvider.user?['companyId']?.toString();
      if (kDebugMode)
        Logger.debug(
          'Company ID present: ${companyId != null && companyId.isNotEmpty}',
        );

      if (companyId == null || companyId.isEmpty) {
        Logger.error('Company context not found in user data');
        if (mounted) {
          setState(() {
            _error = 'Company context not found. Please log in again.';
            _isLoading = false;
          });
        }
        return;
      }

      final userData = {
        'email': _emailController.text,
        'password': _passwordController.text,
        'firstName': _firstNameController.text,
        'lastName': _lastNameController.text,
        'role': _selectedRole
            ?.toLowerCase(), // Convert to lowercase for backend validation
        'gender': _selectedGender,
        'department': '', // Optional field for backend compatibility
        'position': '', // Optional field for backend compatibility
        'companyId': companyId,
      };

      Logger.info('Creating user with data: $userData');
      Logger.info('API Base URL: ${ApiConfig.baseUrl}');
      Logger.info('Making POST request to: ${ApiConfig.baseUrl}/auth/register');

      ApiResponse response;
      try {
        // Add timeout to prevent hanging
        response = await apiService
            .post('/auth/register', userData)
            .timeout(
              const Duration(seconds: 30),
              onTimeout: () {
                throw Exception('Request timeout - please try again');
              },
            );
        Logger.info('API call completed successfully');
      } catch (apiError) {
        Logger.error('API call failed with error: $apiError');
        rethrow;
      }

      Logger.info('Create user response success: ${response.success}');
      Logger.info('Create user response message: ${response.message}');
      Logger.info('Create user response data: ${response.data}');

      if (!mounted) return;

      if (response.success) {
        // Check if this is an employee user that requires setup
        final requiresEmployeeSetup =
            response.data?['requiresEmployeeSetup'] == true;

        final message = requiresEmployeeSetup
            ? 'User created successfully\n\n⚠️ IMPORTANT: This employee must be added to Employee Management\n\nThe employee will be notified and cannot access full features until setup is complete.'
            : 'User created successfully\n\n💡 Tip: Add this user to Employee Management to complete their profile';

        if (requiresEmployeeSetup) {
          GlobalNotificationService().showWarning(
            message,
            duration: const Duration(seconds: 8),
          );
        } else {
          GlobalNotificationService().showSuccess(
            message,
            duration: const Duration(seconds: 8),
          );
        }
        _resetFormFields();
        // Await user list reload before finishing
        await _loadUsers(showErrors: true);
        // Do NOT call setState here; _loadUsers handles _isLoading and _error
      } else {
        final errorMessage = response.message;
        Logger.error('User creation failed: $errorMessage');
        Logger.error('Response data: ${response.data}');

        // Extract specific validation errors if available
        String displayError = errorMessage;
        if (response.data != null && response.data['details'] != null) {
          final details = response.data['details'] as List<dynamic>?;
          if (details != null && details.isNotEmpty) {
            final fieldErrors = details
                .map((e) => '${e['field']}: ${e['message']}')
                .join('\n');
            displayError = 'Validation failed:\n$fieldErrors';
          }
        }

        if (mounted) {
          setState(() {
            _error = displayError;
            _isLoading = false;
          });
        }
        // Show error notification for visibility
        if (mounted) {
          GlobalNotificationService().showError(
            displayError,
            duration: const Duration(seconds: 8),
          );
        }
      }
    } catch (e) {
      Logger.error('Error creating user: $e');
      if (!mounted) return;

      String errorMessage = 'Network error occurred';
      if (e.toString().contains('timeout')) {
        errorMessage =
            'Request timed out. Please check your connection and try again.';
      } else if (e.toString().contains('SocketException')) {
        errorMessage =
            'Connection failed. Please check your internet connection.';
      } else if (e.toString().contains('FormatException')) {
        errorMessage = 'Invalid response from server. Please try again.';
      }

      setState(() {
        _error = errorMessage;
        _isLoading = false;
      });

      // Show error notification for better visibility
      if (mounted) {
        GlobalNotificationService().showError(
          errorMessage,
          duration: const Duration(seconds: 5),
        );
      }
    }
  }

  Future<void> _toggleUserStatus(String userId, bool currentStatus) async {
    if (!mounted) return;
    try {
      final apiService = ApiService(baseUrl: ApiConfig.baseUrl);
      final response = await apiService.patch('/auth/users/$userId', {
        'isActive': !currentStatus,
      });

      if (!mounted) return;
      if (response.success) {
        // Update local copy so the user doesn't disappear unexpectedly from the list.
        setState(() {
          final idx = _users.indexWhere((u) => u['_id'] == userId);
          if (idx != -1) {
            _users[idx]['isActive'] = !currentStatus;
          }
          // If the admin just deactivated a user, ensure inactive users are shown
          // so the deactivated user remains visible in the list.
          if (currentStatus == true) {
            _showInactive = true;
          }
        });

        final newStatus = !currentStatus;
        GlobalNotificationService().showSuccess(
          newStatus
              ? 'User activated'
              : 'User deactivated — now visible in the list',
        );
      } else {
        GlobalNotificationService().showError(response.message);
      }
    } catch (e) {
      Logger.error('Error toggling user status: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Network error occurred')));
    }
  }

  Future<void> _deleteUser(String userId) async {
    if (!mounted) return;

    // Show confirmation dialog
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Delete'),
          content: const Text(
            'Are you sure you want to delete this user? This action cannot be undone.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text('Delete', style: TextStyle(color: AppTheme.error)),
            ),
          ],
        );
      },
    );

    if (confirmed == null || !confirmed) {
      return; // User cancelled the dialog
    }

    setState(() {
      _isLoading = true; // Show loading indicator
    });

    try {
      final apiService = ApiService(baseUrl: ApiConfig.baseUrl);
      final response = await apiService.delete('/auth/users/$userId');

      if (!mounted) return;

      if (response.success) {
        GlobalNotificationService().showSuccess('User deleted successfully');
        _loadUsers(); // Refresh the user list
      } else {
        GlobalNotificationService().showError(response.message);
      }
    } catch (e) {
      Logger.error('Error deleting user: $e');
      if (!mounted) return;
      GlobalNotificationService().showError('Network error occurred');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false; // Hide loading indicator
        });
      }
    }
  }

  Widget _buildStatCard(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Card(
      elevation: AppTheme.elevationMedium,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      ),
      child: Padding(
        padding: EdgeInsets.all(AppTheme.spacingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 30),
            SizedBox(height: AppTheme.spacingS),
            Text(
              title,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: AppTheme.spacingXs),
            Text(
              value,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserCard(
    BuildContext context,
    Map<String, dynamic> user,
    String? currentUserId,
  ) {
    final theme = Theme.of(context);
    // Compute card color based on active status
    final cardColor = user['isActive'] == false
        ? AppTheme.error.withValues(alpha: 0.04)
        : Colors.white;

    // Build the inner card content
    final card = Card(
      color: cardColor,
      elevation: AppTheme.elevationMedium,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      ),
      child: Padding(
        padding: EdgeInsets.all(AppTheme.spacingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  child: Text(
                    (user['firstName'] != null && user['firstName'].isNotEmpty)
                        ? user['firstName'][0].toUpperCase()
                        : '?',
                  ),
                ),
                SizedBox(width: AppTheme.spacingM),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (user['firstName'] ?? '') +
                            (user['lastName'] != null &&
                                    user['lastName'].isNotEmpty
                                // ignore: prefer_interpolation_to_compose_strings
                                ? ' ' + user['lastName']
                                : ''),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(user['email'] ?? ''),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: AppTheme.spacingS),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Status chip
                if (user['isActive'] == false) ...[
                  Chip(
                    label: const Text('Inactive'),
                    backgroundColor: AppTheme.error.withValues(alpha: 0.12),
                    labelStyle: const TextStyle(color: AppTheme.error),
                  ),
                  SizedBox(width: AppTheme.spacingM),
                ] else ...[
                  Chip(
                    label: const Text('Active'),
                    backgroundColor: AppTheme.success.withValues(alpha: 0.12),
                    labelStyle: const TextStyle(color: AppTheme.success),
                  ),
                  SizedBox(width: AppTheme.spacingM),
                ],

                Switch(
                  value: user['isActive'] ?? false,
                  onChanged: (value) =>
                      _toggleUserStatus(user['_id'], user['isActive']),
                  activeThumbColor: AppTheme.success,
                  inactiveThumbColor: AppTheme.error,
                ),
                SizedBox(width: AppTheme.spacingM),
                IconButton(
                  icon: Icon(Icons.delete, color: AppTheme.error),
                  onPressed: user['_id'] == currentUserId
                      ? () {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Action Not Allowed'),
                              content: const Text(
                                'You cannot delete your own admin account.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  child: const Text('OK'),
                                ),
                              ],
                            ),
                          );
                        }
                      : () => _deleteUser(user['_id']),
                  tooltip: 'Delete User',
                ),
              ],
            ),
          ],
        ),
      ),
    );

    // Wrap card in Dismissible to allow swipe-to-view
    return Dismissible(
      key: ValueKey(user['_id']),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        final open = await showDialog<bool>(
          context: context,
          builder: (ctx) {
            return AlertDialog(
              title: Text('User Details'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Name: ${user['firstName'] ?? ''} ${user['lastName'] ?? ''}',
                  ),
                  SizedBox(height: 8),
                  Text('Email: ${user['email'] ?? ''}'),
                  SizedBox(height: 8),
                  Text('Role: ${user['role'] ?? ''}'),
                  SizedBox(height: 8),
                  Text(
                    'Status: ${user['isActive'] == false ? 'Inactive' : 'Active'}',
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('Close'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: const Text('View'),
                ),
              ],
            );
          },
        );

        if (open == true) {
          _showUserDetails(user);
        }
        return false; // never actually dismiss
      },
      background: Container(),
      secondaryBackground: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        ),
        alignment: Alignment.centerRight,
        padding: EdgeInsets.only(right: AppTheme.spacingL),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.visibility, color: Colors.white),
            SizedBox(width: 8),
            Text(
              'View',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      child: card,
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

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline,
            size: 60,
            color: colorScheme.onSurfaceVariant,
          ),
          SizedBox(height: AppTheme.spacingL),
          Text(
            'No users found.',
            style: theme.textTheme.titleMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          SizedBox(height: AppTheme.spacingS),
          Text(
            'Add new users to get started.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  void _showUserDetails(Map<String, dynamic> user) {
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.all(AppTheme.spacingL),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              SizedBox(height: AppTheme.spacingS),
              Text('Email: ${user['email'] ?? ''}'),
              SizedBox(height: AppTheme.spacingS),
              Text('Role: ${user['role'] ?? ''}'),
              SizedBox(height: AppTheme.spacingS),
              Text(
                'Status: ${user['isActive'] == false ? 'Inactive' : 'Active'}',
              ),
              SizedBox(height: AppTheme.spacingM),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                    },
                    child: const Text('Close'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      _toggleUserStatus(user['_id'], user['isActive']);
                    },
                    child: Text(
                      user['isActive'] == false ? 'Activate' : 'Deactivate',
                    ),
                  ),
                  SizedBox(width: AppTheme.spacingS),
                  OutlinedButton(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      _deleteUser(user['_id']);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.error,
                    ),
                    child: const Text('Delete'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (kDebugMode) Logger.debug('🔴 USER MANAGEMENT SCREEN BUILDING');
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final currentUserId = Provider.of<AuthProvider>(
      context,
      listen: false,
    ).user?['_id'];

    return Scaffold(
      appBar: AppBar(
        title: const Text('User Management'),
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _loadUsers(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      drawer: const AdminSideNavigation(currentRoute: '/user_management'),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(AppTheme.spacingL),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Quick Stats Section
                  Container(
                    margin: EdgeInsets.only(bottom: AppTheme.spacingL),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            context,
                            'Total Users',
                            '${_users.length}',
                            Icons.people,
                            colorScheme.primary,
                          ),
                        ),
                        SizedBox(width: AppTheme.spacingM),
                        Expanded(
                          child: _buildStatCard(
                            context,
                            'Active',
                            '${_users.where((user) => user['isActive'] != false).length}',
                            Icons.check_circle,
                            AppTheme.success,
                          ),
                        ),
                        SizedBox(width: AppTheme.spacingM),
                        Expanded(
                          child: _buildStatCard(
                            context,
                            'Admins',
                            '${_users.where((user) => user['role'] == 'admin').length}',
                            Icons.admin_panel_settings,
                            AppTheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Note: manual toggle removed — inactive visibility is handled automatically

                  // Add User Section
                  Container(
                    margin: EdgeInsets.only(bottom: AppTheme.spacingL),
                    padding: EdgeInsets.all(AppTheme.spacingL),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(
                        AppTheme.radiusMedium,
                      ),
                      border: Border.all(
                        color: AppTheme.muted.withValues(alpha: 0.2),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.person_add,
                                  color: colorScheme.primary,
                                  size: 18,
                                ),
                                SizedBox(width: AppTheme.spacingS),
                                Text(
                                  'Add New User',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: colorScheme.primary,
                                  ),
                                ),
                              ],
                            ),
                            IconButton(
                              icon: Icon(
                                _isAddUserExpanded
                                    ? Icons.expand_less
                                    : Icons.expand_more,
                                color: colorScheme.primary,
                              ),
                              onPressed: _toggleAddUserSection,
                              tooltip: _isAddUserExpanded
                                  ? 'Collapse'
                                  : 'Expand',
                            ),
                          ],
                        ),
                        if (_isAddUserExpanded) ...[
                          SizedBox(height: AppTheme.spacingL),
                          Form(
                            key: _formKey,
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        controller: _firstNameController,
                                        decoration: const InputDecoration(
                                          labelText: 'First Name',
                                          border: OutlineInputBorder(),
                                        ),
                                        validator: (value) {
                                          if (value == null || value.isEmpty) {
                                            return 'Please enter a first name';
                                          }
                                          return null;
                                        },
                                      ),
                                    ),
                                    SizedBox(width: AppTheme.spacingM),
                                    Expanded(
                                      child: TextFormField(
                                        controller: _lastNameController,
                                        decoration: const InputDecoration(
                                          labelText: 'Last Name',
                                          border: OutlineInputBorder(),
                                        ),
                                        validator: (value) {
                                          if (value == null || value.isEmpty) {
                                            return 'Please enter a last name';
                                          }
                                          return null;
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: AppTheme.spacingM),
                                // Email field - full width
                                TextFormField(
                                  controller: _emailController,
                                  decoration: const InputDecoration(
                                    labelText: 'Email',
                                    border: OutlineInputBorder(),
                                  ),
                                  keyboardType: TextInputType.emailAddress,
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter an email';
                                    }
                                    if (!value.contains('@')) {
                                      return 'Please enter a valid email';
                                    }
                                    return null;
                                  },
                                ),
                                SizedBox(height: AppTheme.spacingM),
                                // Role field - full width
                                DropdownButtonFormField<String>(
                                  initialValue: _selectedRole,
                                  decoration: const InputDecoration(
                                    labelText: 'Role',
                                    border: OutlineInputBorder(),
                                  ),
                                  items: _roles.map((role) {
                                    return DropdownMenuItem(
                                      value: role,
                                      child: Text(role.toUpperCase()),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedRole = value;
                                    });
                                  },
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please select a role';
                                    }
                                    return null;
                                  },
                                ),
                                SizedBox(height: AppTheme.spacingM),
                                // Gender field - full width
                                DropdownButtonFormField<String>(
                                  initialValue: _selectedGender,
                                  decoration: const InputDecoration(
                                    labelText: 'Gender',
                                    border: OutlineInputBorder(),
                                    hintText: 'Select gender (optional)',
                                  ),
                                  items: _genders.map((gender) {
                                    return DropdownMenuItem(
                                      value: gender,
                                      child: Text(
                                        gender
                                            .replaceAll('_', ' ')
                                            .toUpperCase(),
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedGender = value;
                                    });
                                  },
                                ),
                                SizedBox(height: AppTheme.spacingM),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    TextFormField(
                                      controller: _passwordController,
                                      decoration: InputDecoration(
                                        labelText: 'Password',
                                        border: const OutlineInputBorder(),
                                        helperText:
                                            'Enter a strong password or use auto-generate',
                                        suffixIcon: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              icon: const Icon(
                                                Icons.visibility,
                                              ),
                                              onPressed: () {
                                                setState(() {
                                                  _obscurePassword =
                                                      !_obscurePassword;
                                                });
                                              },
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.refresh),
                                              onPressed:
                                                  _generateStrongPassword,
                                              tooltip:
                                                  'Generate strong password',
                                            ),
                                          ],
                                        ),
                                      ),
                                      obscureText: _obscurePassword,
                                      onChanged: (value) {
                                        setState(() {
                                          _passwordStrength =
                                              _calculatePasswordStrength(value);
                                        });
                                      },
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Please enter a password';
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
                                    const SizedBox(height: 8),
                                    // Password strength indicator
                                    if (_passwordController
                                        .text
                                        .isNotEmpty) ...[
                                      _buildPasswordStrengthIndicator(),
                                      const SizedBox(height: 8),
                                      _buildPasswordRequirementsChecklist(),
                                    ],
                                  ],
                                ),
                                SizedBox(height: AppTheme.spacingL),
                                SizedBox(
                                  width: double.infinity,
                                  child: Builder(
                                    builder: (context) {
                                      if (kDebugMode)
                                        Logger.debug(
                                          '🔴 BUTTON BEING BUILT - _isLoading: $_isLoading',
                                        );
                                      return ElevatedButton(
                                        onPressed: _isLoading
                                            ? () {
                                                if (kDebugMode)
                                                  Logger.debug(
                                                    '🔴 BUTTON DISABLED - Loading state active',
                                                  );
                                              }
                                            : () {
                                                Logger.info(
                                                  '🔴 BUTTON CLICKED - Create User button pressed',
                                                );
                                                if (kDebugMode)
                                                  Logger.debug(
                                                    '🔴 Button state - _isLoading: $_isLoading',
                                                  );
                                                _createUser();
                                              },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: colorScheme.primary,
                                          foregroundColor:
                                              colorScheme.onPrimary,
                                          padding: EdgeInsets.symmetric(
                                            vertical: AppTheme.spacingM,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              AppTheme.radiusSmall,
                                            ),
                                          ),
                                        ),
                                        child: _isLoading
                                            ? const Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  SizedBox(
                                                    width: 20,
                                                    height: 20,
                                                    child: CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      valueColor:
                                                          AlwaysStoppedAnimation<
                                                            Color
                                                          >(Colors.white),
                                                    ),
                                                  ),
                                                  SizedBox(width: 10),
                                                  Text('Creating User...'),
                                                ],
                                              )
                                            : const Text('Create User'),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // User List Section
                  if (_users.isNotEmpty) ...[
                    Container(
                      margin: EdgeInsets.only(bottom: AppTheme.spacingL),
                      child: Row(
                        children: [
                          Icon(
                            Icons.list,
                            color: colorScheme.primary,
                            size: 20,
                          ),
                          SizedBox(width: AppTheme.spacingS),
                          Text(
                            'User List',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ..._users.map(
                      (user) => _buildUserCard(context, user, currentUserId),
                    ),
                  ] else ...[
                    _buildEmptyState(context),
                  ],
                ],
              ),
            ),
    );
  }
}
