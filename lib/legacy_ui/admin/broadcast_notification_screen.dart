import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/notification_api_service.dart';
import '../../services/global_notification_service.dart';
import '../../config/api_config.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class BroadcastNotificationScreen extends StatefulWidget {
  const BroadcastNotificationScreen({super.key});

  @override
  State<BroadcastNotificationScreen> createState() =>
      _BroadcastNotificationScreenState();
}

class _BroadcastNotificationScreenState
    extends State<BroadcastNotificationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();

  String _targetType = 'COMPANY_ALL';
  String? _selectedRole;
  List<String> _selectedUserIds = [];

  String _type = 'announcement';
  String _priority = 'normal';
  final List<String> _channels = ['in_app_list', 'push'];
  String? _deepLink;

  bool _isLoading = false;
  bool _isLoadingUsers = false;

  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _filteredUsers = [];
  final TextEditingController _userSearchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      _loadInitialData(authProvider);
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _userSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData(AuthProvider authProvider) async {
    final user = authProvider.user;
    final userCompanyId = user?['companyId'];

    // Company admin only - set default target type and load users
    setState(() {
      _targetType = 'COMPANY_ALL';
    });
    await _loadUsers(userCompanyId);
  }

  Future<void> _loadUsers(String? companyId) async {
    if (companyId == null || companyId.isEmpty) return;
    if (!mounted) return;

    setState(() {
      _isLoadingUsers = true;
      _users = [];
      _filteredUsers = [];
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      // Use /auth/users endpoint which returns users directly (not employees)
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/auth/users?limit=1000'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${authProvider.token}',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // The /auth/users endpoint returns an array directly
        List<Map<String, dynamic>> users = [];
        if (data is List) {
          users = List<Map<String, dynamic>>.from(data);
        } else if (data is Map && data.containsKey('users')) {
          users = List<Map<String, dynamic>>.from(data['users'] ?? []);
        } else if (data is Map && data.containsKey('data')) {
          // Some endpoints wrap in 'data'
          final innerData = data['data'];
          if (innerData is List) {
            users = List<Map<String, dynamic>>.from(innerData);
          }
        }

        // Map user data to expected format and filter by companyId for security
        final formattedUsers = users
            .map((user) {
              final userId = user['_id']?.toString() ?? user['id']?.toString();
              if (userId == null) return null;
              // CRITICAL: Filter users by companyId to prevent exposing other companies' data
              final userCompanyId = user['companyId']?.toString();
              if (userCompanyId != companyId) {
                return null; // Skip users from other companies
              }
              return {
                '_id': userId,
                'id': userId,
                'name': '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}'
                    .trim(),
                'firstName': user['firstName'] ?? '',
                'lastName': user['lastName'] ?? '',
                'email': user['email'] ?? '',
                'role': user['role'] ?? 'employee',
              };
            })
            .where((u) => u != null)
            .cast<Map<String, dynamic>>()
            .toList();

        setState(() {
          _users = formattedUsers;
          _filteredUsers = formattedUsers;
          // Reset search when users are loaded
          _userSearchController.clear();
        });
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to load users');
      }
    } catch (e) {
      if (mounted) {
        GlobalNotificationService().showError('Failed to load users: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingUsers = false;
        });
      }
    }
  }

  void _filterUsersByRole(String? role) {
    List<Map<String, dynamic>> filtered = _users;

    // Apply role filter
    if (role != null && role.isNotEmpty) {
      filtered = filtered.where((user) => user['role'] == role).toList();
    }

    // Apply search filter if exists
    final searchQuery = _userSearchController.text;
    if (searchQuery.isNotEmpty) {
      final lowerQuery = searchQuery.toLowerCase();
      filtered = filtered.where((user) {
        final name = (user['name'] ?? '').toLowerCase();
        final email = (user['email'] ?? '').toLowerCase();
        return name.contains(lowerQuery) || email.contains(lowerQuery);
      }).toList();
    }

    setState(() {
      _filteredUsers = filtered;
    });
  }

  void _filterUsersBySearch(String query) {
    List<Map<String, dynamic>> filtered = _users;

    // Apply role filter if exists
    if (_selectedRole != null && _selectedRole!.isNotEmpty) {
      filtered = filtered
          .where((user) => user['role'] == _selectedRole)
          .toList();
    }

    // Apply search filter
    if (query.isNotEmpty) {
      final lowerQuery = query.toLowerCase();
      filtered = filtered.where((user) {
        final name = (user['name'] ?? '').toLowerCase();
        final email = (user['email'] ?? '').toLowerCase();
        return name.contains(lowerQuery) || email.contains(lowerQuery);
      }).toList();
    }

    setState(() {
      _filteredUsers = filtered;
    });
  }

  int _getTargetUserCount() {
    switch (_targetType) {
      case 'COMPANY_ALL':
        return _users.length;
      case 'ROLE_IN_COMPANY':
        if (_selectedRole == null) return 0;
        return _users.where((u) => u['role'] == _selectedRole).length;
      case 'SPECIFIC_USERS':
        return _selectedUserIds.length;
      default:
        return 0;
    }
  }

  Future<void> _broadcastNotification() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final notificationService = NotificationApiService(authProvider);

      // Get user info from authProvider
      final currentUser = authProvider.user;
      final userCompanyId = currentUser?['companyId'];

      // Build payload with conditional fields
      final Map<String, dynamic> payload = {
        'title': _titleController.text.trim(),
        'body': _bodyController.text.trim(),
        'type': _type,
        'priority': _priority,
        'target_type': _targetType,
        'channels': _channels,
      };

      // Add conditional fields - company admin always uses their own company ID
      if (_targetType == 'COMPANY_ALL') {
        payload['target_company_id'] = userCompanyId;
      }

      if (_targetType == 'ROLE_IN_COMPANY') {
        payload['target_company_id'] = userCompanyId;
        if (_selectedRole != null) {
          payload['target_role'] = _selectedRole;
        }
      }

      if (_targetType == 'SPECIFIC_USERS' && _selectedUserIds.isNotEmpty) {
        payload['target_user_ids'] = _selectedUserIds;
      }

      if (_deepLink != null && _deepLink!.isNotEmpty) {
        payload['deep_link'] = _deepLink;
      }

      final response = await notificationService.broadcastNotification(
        title: payload['title'] as String,
        body: payload['body'] as String,
        targetType: payload['target_type'] as String,
        targetCompanyId: payload['target_company_id'] as String?,
        targetRole: payload['target_role'] as String?,
        targetUserIds: payload['target_user_ids'] as List<String>?,
        channels: payload['channels'] as List<String>,
        deepLink: payload['deep_link'] as String?,
        type: payload['type'] as String,
        priority: payload['priority'] as String,
      );

      if (mounted) {
        if (response['success'] == true) {
          final createdForUsers = response['data']?['createdForUsers'] ?? 0;
          GlobalNotificationService().showSuccess(
            'Notification sent successfully to $createdForUsers users!',
          );
          Navigator.of(context).pop(true); // Return true to indicate success
        } else {
          GlobalNotificationService().showError(
            response['message'] ?? 'Failed to send notification',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        GlobalNotificationService().showError('Error: ${e.toString()}');
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
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Broadcast Notification'),
        backgroundColor: Colors.indigo[800],
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Summary Card
              if (_titleController.text.isNotEmpty ||
                  _bodyController.text.isNotEmpty)
                Card(
                  elevation: 2,
                  color: Colors.blue[50],
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Colors.blue[700],
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Preview',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue[900],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (_titleController.text.isNotEmpty)
                          Text(
                            _titleController.text,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        if (_bodyController.text.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            _bodyController.text,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[700],
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const SizedBox(height: 8),
                        Text(
                          'Will be sent to: ${_getTargetUserCount()} user(s)',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue[900],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (_titleController.text.isNotEmpty ||
                  _bodyController.text.isNotEmpty)
                const SizedBox(height: 16),
              // Title Field
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'Title *',
                  border: const OutlineInputBorder(),
                  hintText: 'Enter notification title',
                  prefixIcon: const Icon(Icons.title),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
                onChanged: (_) =>
                    setState(() {}), // Trigger rebuild for preview
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Title is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Body Field
              TextFormField(
                controller: _bodyController,
                decoration: InputDecoration(
                  labelText: 'Message *',
                  border: const OutlineInputBorder(),
                  hintText: 'Enter notification message',
                  prefixIcon: const Icon(Icons.message),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
                maxLines: 4,
                onChanged: (_) =>
                    setState(() {}), // Trigger rebuild for preview
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Message is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Type and Priority Row
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _type,
                      decoration: InputDecoration(
                        labelText: 'Type',
                        border: const OutlineInputBorder(),
                        filled: true,
                        fillColor: Colors.grey[50],
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 16,
                        ),
                      ),
                      selectedItemBuilder: (BuildContext context) {
                        return [
                          'announcement',
                          'info',
                          'warning',
                          'success',
                          'error',
                          'system',
                        ].map((type) {
                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(_getTypeIcon(type), size: 14),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  _getTypeShortName(type),
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                            ],
                          );
                        }).toList();
                      },
                      items: [
                        _buildDropdownItem('announcement', Icons.campaign),
                        _buildDropdownItem('info', Icons.info),
                        _buildDropdownItem('warning', Icons.warning),
                        _buildDropdownItem('success', Icons.check_circle),
                        _buildDropdownItem('error', Icons.error),
                        _buildDropdownItem('system', Icons.settings),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _type = value;
                          });
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _priority,
                      decoration: InputDecoration(
                        labelText: 'Priority',
                        border: const OutlineInputBorder(),
                        filled: true,
                        fillColor: Colors.grey[50],
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 16,
                        ),
                      ),
                      selectedItemBuilder: (BuildContext context) {
                        return ['low', 'normal', 'high', 'critical'].map((
                          priority,
                        ) {
                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _getPriorityIcon(priority),
                                size: 14,
                                color: _getPriorityColor(priority),
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  priority.toUpperCase(),
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                            ],
                          );
                        }).toList();
                      },
                      items: [
                        _buildDropdownItem(
                          'low',
                          Icons.arrow_downward,
                          color: Colors.grey,
                        ),
                        _buildDropdownItem(
                          'normal',
                          Icons.remove,
                          color: Colors.blue,
                        ),
                        _buildDropdownItem(
                          'high',
                          Icons.arrow_upward,
                          color: Colors.orange,
                        ),
                        _buildDropdownItem(
                          'critical',
                          Icons.priority_high,
                          color: Colors.red,
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _priority = value;
                          });
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Target Type Dropdown
              DropdownButtonFormField<String>(
                initialValue: _targetType,
                decoration: const InputDecoration(
                  labelText: 'Target Audience *',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'COMPANY_ALL',
                    child: Text('All Users in Company'),
                  ),
                  DropdownMenuItem(
                    value: 'ROLE_IN_COMPANY',
                    child: Text('Role in Company'),
                  ),
                  DropdownMenuItem(
                    value: 'SPECIFIC_USERS',
                    child: Text('Specific Users'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _targetType = value;
                      _selectedRole = null;
                      _selectedUserIds = [];
                    });

                    if (value == 'ROLE_IN_COMPANY' ||
                        value == 'SPECIFIC_USERS') {
                      final userCompanyId = user?['companyId'];
                      if (userCompanyId != null) {
                        _loadUsers(userCompanyId);
                      }
                    }
                  }
                },
              ),
              const SizedBox(height: 16),

              // Show company name (read-only for company admin)
              TextFormField(
                initialValue: user?['companyName'] ?? 'Your Company',
                decoration: InputDecoration(
                  labelText: 'Company',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.business),
                  filled: true,
                  fillColor: Colors.grey[100],
                ),
                enabled: false,
              ),
              const SizedBox(height: 16),

              // Role Selection (for ROLE_IN_COMPANY)
              if (_targetType == 'ROLE_IN_COMPANY')
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: _selectedRole,
                      decoration: const InputDecoration(
                        labelText: 'Role *',
                        border: OutlineInputBorder(),
                      ),
                      items: ['employee', 'admin']
                          .map(
                            (role) => DropdownMenuItem(
                              value: role,
                              child: Text(role.toUpperCase()),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedRole = value;
                        });
                        _filterUsersByRole(value);
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Role is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                  ],
                ),

              // User Selection (for SPECIFIC_USERS)
              if (_targetType == 'SPECIFIC_USERS')
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Search field
                    TextField(
                      controller: _userSearchController,
                      decoration: InputDecoration(
                        labelText: 'Search users',
                        hintText: 'Search by name or email',
                        prefixIcon: const Icon(Icons.search),
                        border: const OutlineInputBorder(),
                        filled: true,
                        fillColor: Colors.grey[50],
                        suffixIcon: _userSearchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  setState(() {
                                    _userSearchController.clear();
                                    _filterUsersBySearch('');
                                  });
                                },
                              )
                            : null,
                      ),
                      onChanged: (value) {
                        setState(() {
                          _filterUsersBySearch(value);
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    // Selected count badge
                    if (_selectedUserIds.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue[100],
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.people,
                              size: 16,
                              color: Colors.blue[900],
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${_selectedUserIds.length} user(s) selected',
                              style: TextStyle(
                                color: Colors.blue[900],
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (_selectedUserIds.isNotEmpty) const SizedBox(height: 12),
                    // User list
                    if (_isLoadingUsers)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(20.0),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        constraints: const BoxConstraints(maxHeight: 250),
                        child: _filteredUsers.isEmpty
                            ? const Padding(
                                padding: EdgeInsets.all(20.0),
                                child: Center(
                                  child: Text(
                                    'No users available',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                ),
                              )
                            : ListView.builder(
                                shrinkWrap: true,
                                itemCount: _filteredUsers.length,
                                itemBuilder: (context, index) {
                                  final user = _filteredUsers[index];
                                  final userId =
                                      user['_id']?.toString() ??
                                      user['id']?.toString();
                                  final isSelected = _selectedUserIds.contains(
                                    userId,
                                  );
                                  final userName =
                                      user['name'] ??
                                      user['firstName'] ??
                                      'Unknown';
                                  final userEmail = user['email'] ?? '';
                                  final userRole = user['role'] ?? 'employee';

                                  return Container(
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? Colors.blue[50]
                                          : null,
                                      border: Border(
                                        bottom: BorderSide(
                                          color: Colors.grey[200]!,
                                        ),
                                      ),
                                    ),
                                    child: CheckboxListTile(
                                      title: Text(
                                        userName,
                                        style: TextStyle(
                                          fontWeight: isSelected
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                        ),
                                      ),
                                      subtitle: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(userEmail),
                                          const SizedBox(height: 4),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: userRole == 'admin'
                                                  ? Colors.purple[100]
                                                  : Colors.green[100],
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              userRole.toUpperCase(),
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: userRole == 'admin'
                                                    ? Colors.purple[900]
                                                    : Colors.green[900],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      value: isSelected,
                                      onChanged: (checked) {
                                        setState(() {
                                          if (checked == true) {
                                            if (userId != null) {
                                              _selectedUserIds.add(userId);
                                            }
                                          } else {
                                            _selectedUserIds.remove(userId);
                                          }
                                        });
                                      },
                                    ),
                                  );
                                },
                              ),
                      ),
                    if (_selectedUserIds.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 16,
                              color: Colors.red[700],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Please select at least one user',
                              style: TextStyle(
                                color: Colors.red[700],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 16),
                  ],
                ),

              // Channels Section
              Card(
                elevation: 1,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.notifications_active,
                            color: Colors.indigo[800],
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Channels *',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Row(
                          children: [
                            Icon(Icons.list, size: 20, color: Colors.blue[700]),
                            const SizedBox(width: 8),
                            const Text('In-App List'),
                          ],
                        ),
                        subtitle: const Text('Show in notification list'),
                        value: _channels.contains('in_app_list'),
                        onChanged: (checked) {
                          setState(() {
                            if (checked == true) {
                              _channels.add('in_app_list');
                            } else {
                              _channels.remove('in_app_list');
                            }
                          });
                        },
                      ),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Row(
                          children: [
                            Icon(
                              Icons.notifications,
                              size: 20,
                              color: Colors.orange[700],
                            ),
                            const SizedBox(width: 8),
                            const Text('Push Notification'),
                          ],
                        ),
                        subtitle: const Text('Send push notification'),
                        value: _channels.contains('push'),
                        onChanged: (checked) {
                          setState(() {
                            if (checked == true) {
                              _channels.add('push');
                            } else {
                              _channels.remove('push');
                            }
                          });
                        },
                      ),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Row(
                          children: [
                            Icon(
                              Icons.campaign,
                              size: 20,
                              color: Colors.purple[700],
                            ),
                            const SizedBox(width: 8),
                            const Text('In-App Banner'),
                          ],
                        ),
                        subtitle: const Text('Show as banner at top'),
                        value: _channels.contains('in_app_banner'),
                        onChanged: (checked) {
                          setState(() {
                            if (checked == true) {
                              _channels.add('in_app_banner');
                            } else {
                              _channels.remove('in_app_banner');
                            }
                          });
                        },
                      ),
                      if (_channels.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 16,
                                color: Colors.red[700],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Please select at least one channel',
                                style: TextStyle(
                                  color: Colors.red[700],
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Deep Link (Optional)
              TextFormField(
                initialValue: _deepLink,
                decoration: InputDecoration(
                  labelText: 'Deep Link (Optional)',
                  border: const OutlineInputBorder(),
                  hintText: '/admin/dashboard',
                  prefixIcon: const Icon(Icons.link),
                  filled: true,
                  fillColor: Colors.grey[50],
                  helperText: 'Where to navigate when notification is tapped',
                ),
                onChanged: (value) {
                  _deepLink = value.trim().isEmpty ? null : value.trim();
                },
              ),
              const SizedBox(height: 24),

              // Send Button
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _broadcastNotification,
                icon: _isLoading
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
                    : const Icon(Icons.send),
                label: Text(
                  _isLoading ? 'Sending...' : 'Send Notification',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo[800],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  elevation: 2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'announcement':
        return Icons.campaign;
      case 'info':
        return Icons.info;
      case 'warning':
        return Icons.warning;
      case 'success':
        return Icons.check_circle;
      case 'error':
        return Icons.error;
      case 'system':
        return Icons.settings;
      default:
        return Icons.notifications;
    }
  }

  String _getTypeShortName(String type) {
    switch (type) {
      case 'announcement':
        return 'ANNOUNCE';
      case 'info':
        return 'INFO';
      case 'warning':
        return 'WARN';
      case 'success':
        return 'SUCCESS';
      case 'error':
        return 'ERROR';
      case 'system':
        return 'SYSTEM';
      default:
        return type.toUpperCase();
    }
  }

  IconData _getPriorityIcon(String priority) {
    switch (priority) {
      case 'low':
        return Icons.arrow_downward;
      case 'normal':
        return Icons.remove;
      case 'high':
        return Icons.arrow_upward;
      case 'critical':
        return Icons.priority_high;
      default:
        return Icons.circle;
    }
  }

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'low':
        return Colors.grey;
      case 'normal':
        return Colors.blue;
      case 'high':
        return Colors.orange;
      case 'critical':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  DropdownMenuItem<String> _buildDropdownItem(
    String value,
    IconData icon, {
    Color? color,
  }) {
    return DropdownMenuItem(
      value: value,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value.toUpperCase(),
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
