import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../widgets/admin_side_navigation.dart';
import '../../widgets/shared_app_bar.dart';
import '../../providers/admin_settings_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/feature_provider.dart';
import '../../utils/logger.dart';
import '../../services/fcm_service.dart';
import '../../services/global_notification_service.dart';
import '../../screens/debug/debug_settings_screen.dart';
import 'package:flutter/foundation.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String? _refreshKey;

  void _refreshToken() {
    setState(() {
      _refreshKey = DateTime.now().millisecondsSinceEpoch.toString();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: SharedAppBar(
        title: 'Settings',
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
      ),
      drawer: const AdminSideNavigation(currentRoute: '/settings'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Admin Preferences', style: theme.textTheme.titleLarge),
            const SizedBox(height: 16),
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Consumer<AdminSettingsProvider>(
                      builder: (context, settings, _) {
                        return SwitchListTile(
                          title: const Text('Enable Dark Mode'),
                          value: settings.darkModeEnabled,
                          onChanged: (value) {
                            settings.setDarkModeEnabled(value);
                          },
                        );
                      },
                    ),
                    Consumer<AdminSettingsProvider>(
                      builder: (context, settings, _) {
                        return SwitchListTile(
                          title: const Text('Receive Email Notifications'),
                          value: settings.notificationsEnabled,
                          onChanged: (value) {
                            settings.setNotificationsEnabled(value);
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text('Profile Settings', style: theme.textTheme.titleLarge),
            const SizedBox(height: 16),
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Control which sections are visible in employee profiles',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Consumer<AdminSettingsProvider>(
                      builder: (context, settings, _) {
                        return SwitchListTile(
                          title: const Text('Enable Education Section'),
                          subtitle: const Text(
                            'Allow employees to add education information',
                          ),
                          value: settings.educationSectionEnabled,
                          onChanged: (value) {
                            settings.setEducationSectionEnabled(value);
                            GlobalNotificationService().showSuccess(
                              value
                                  ? 'Education section enabled'
                                  : 'Education section disabled',
                            );
                          },
                        );
                      },
                    ),
                    Consumer<AdminSettingsProvider>(
                      builder: (context, settings, _) {
                        return SwitchListTile(
                          title: const Text('Enable Certificates Section'),
                          subtitle: const Text(
                            'Allow employees to add certificates',
                          ),
                          value: settings.certificatesSectionEnabled,
                          onChanged: (value) {
                            settings.setCertificatesSectionEnabled(value);
                            GlobalNotificationService().showSuccess(
                              value
                                  ? 'Certificates section enabled'
                                  : 'Certificates section disabled',
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text('System Configuration', style: theme.textTheme.titleLarge),
            const SizedBox(height: 16),
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Consumer<AuthProvider>(
                      builder: (ctx, auth, _) {
                        final features = Provider.of<FeatureProvider>(
                          ctx,
                          listen: false,
                        );
                        final hasPayroll = features.hasPayroll;
                        return Column(
                          children: [
                            if (hasPayroll)
                              ListTile(
                                title: const Text('Payroll Cycle Settings'),
                                trailing: const Icon(Icons.arrow_forward_ios),
                                onTap: () {
                                  Navigator.of(
                                    context,
                                  ).pushNamed('/admin/payroll_cycle_settings');
                                },
                              ),
                            if (hasPayroll)
                              ListTile(
                                title: const Text('Tax Configuration'),
                                subtitle: const Text(
                                  'Configure income tax, social security & deductions',
                                ),
                                trailing: const Icon(Icons.arrow_forward_ios),
                                onTap: () {
                                  Navigator.of(
                                    context,
                                  ).pushNamed('/admin/tax_settings');
                                },
                              ),
                          ],
                        );
                      },
                    ),
                    ListTile(
                      title: const Text('Leave Policy Settings'),
                      trailing: const Icon(Icons.arrow_forward_ios),
                      onTap: () {
                        Navigator.of(
                          context,
                        ).pushNamed('/admin/leave_policy_settings');
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Debug Section (only in debug mode)
            if (kDebugMode) ...[
              Text(
                'Debug Tools',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: Colors.orange,
                ),
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // FCM Token Display and Manual Request
                      FutureBuilder<String?>(
                        key: ValueKey(_refreshKey),
                        future: FCMService().getTokenFromPrefs(),
                        builder: (context, snapshot) {
                          final token = snapshot.data;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ListTile(
                                leading: const Icon(
                                  Icons.token,
                                  color: Colors.blue,
                                ),
                                title: const Text('FCM Token'),
                                subtitle: Text(
                                  token != null && token.isNotEmpty
                                      ? '${token.substring(0, 30)}...'
                                      : 'No token available',
                                  style: TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 12,
                                  ),
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.copy),
                                  onPressed: token != null && token.isNotEmpty
                                      ? () async {
                                          // Copy to clipboard
                                          await Clipboard.setData(
                                            ClipboardData(text: token),
                                          );
                                          Logger.info(
                                            'FCM Token copied to clipboard: $token',
                                          );
                                          if (context.mounted) {
                                            GlobalNotificationService()
                                                .showSuccess(
                                                  'FCM Token copied to clipboard',
                                                  duration: const Duration(
                                                    seconds: 2,
                                                  ),
                                                );
                                          }
                                        }
                                      : null,
                                ),
                              ),
                              if (token != null && token.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16.0,
                                  ),
                                  child: Text(
                                    'Full Token: $token',
                                    style: TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 10,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 8),
                              ListTile(
                                leading: const Icon(
                                  Icons.refresh,
                                  color: Colors.green,
                                ),
                                title: const Text('Request FCM Token'),
                                subtitle: const Text(
                                  'Manually request FCM token generation',
                                ),
                                trailing: const Icon(Icons.arrow_forward_ios),
                                onTap: () async {
                                  try {
                                    final fcmService = FCMService();
                                    final authProvider =
                                        Provider.of<AuthProvider>(
                                          context,
                                          listen: false,
                                        );

                                    // Show loading
                                    if (context.mounted) {
                                      GlobalNotificationService().showInfo(
                                        'Requesting FCM token...',
                                      );
                                    }

                                    // Request token
                                    await fcmService.testFCMTokenGeneration();

                                    // Try to save if auth is available
                                    final user = authProvider.user;
                                    final authToken = authProvider.token;
                                    if (user != null && authToken != null) {
                                      final userId =
                                          user['_id'] ?? user['id'] ?? '';
                                      if (userId.isNotEmpty) {
                                        await fcmService.saveTokenToDatabase(
                                          authToken,
                                          userId,
                                        );
                                      }
                                    }

                                    // Refresh the token display
                                    if (context.mounted) {
                                      _refreshToken(); // Trigger rebuild
                                      GlobalNotificationService().showSuccess(
                                        'FCM token requested. Check logs for details.',
                                      );
                                    }
                                  } catch (e) {
                                    Logger.error(
                                      'Error requesting FCM token: $e',
                                    );
                                    if (context.mounted) {
                                      GlobalNotificationService().showError(
                                        'Error: $e',
                                      );
                                    }
                                  }
                                },
                              ),
                              const Divider(),
                              ListTile(
                                leading: const Icon(
                                  Icons.bug_report,
                                  color: Colors.orange,
                                ),
                                title: const Text('Save FCM Token to Database'),
                                subtitle: const Text(
                                  'Manually trigger FCM token saving',
                                ),
                                trailing: const Icon(Icons.send),
                                onTap: () async {
                                  try {
                                    final authProvider =
                                        Provider.of<AuthProvider>(
                                          context,
                                          listen: false,
                                        );
                                    await authProvider.saveFCMTokenManually();
                                    if (context.mounted) {
                                      GlobalNotificationService().showInfo(
                                        'FCM token save attempted. Check logs for details.',
                                      );
                                    }
                                  } catch (e) {
                                    Logger.error('Error saving FCM token: $e');
                                    if (context.mounted) {
                                      GlobalNotificationService().showError(
                                        'Error: $e',
                                      );
                                    }
                                  }
                                },
                              ),
                              // Test features - only show in debug mode
                              if (kDebugMode) ...[
                                ListTile(
                                  leading: const Icon(
                                    Icons.token,
                                    color: Colors.green,
                                  ),
                                  title: const Text(
                                    'Test FCM Token Generation',
                                  ),
                                  subtitle: const Text(
                                    'Manually test FCM token generation',
                                  ),
                                  trailing: const Icon(Icons.refresh),
                                  onTap: () async {
                                    try {
                                      // Import FCMService
                                      final fcmService = FCMService();
                                      await fcmService.testFCMTokenGeneration();
                                      if (context.mounted) {
                                        GlobalNotificationService().showSuccess(
                                          'FCM token test completed. Check logs for details.',
                                        );
                                      }
                                    } catch (e) {
                                      Logger.error(
                                        'Error testing FCM token: $e',
                                      );
                                      if (context.mounted) {
                                        GlobalNotificationService().showError(
                                          'Error: $e',
                                        );
                                      }
                                    }
                                  },
                                ),
                                ListTile(
                                  leading: const Icon(
                                    Icons.access_time,
                                    color: Colors.blue,
                                  ),
                                  title: const Text('Test Clock-In Reminder'),
                                  subtitle: const Text(
                                    'Test clock-in reminder functionality',
                                  ),
                                  trailing: const Icon(Icons.arrow_forward_ios),
                                  onTap: () {
                                    Navigator.of(
                                      context,
                                    ).pushNamed('/clock-in-reminder-test');
                                  },
                                ),
                              ],
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text('Debug Settings', style: theme.textTheme.titleLarge),
              const SizedBox(height: 16),
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ListTile(
                        leading: const Icon(
                          Icons.bug_report,
                          color: Colors.orange,
                        ),
                        title: const Text('Offline-First Debug'),
                        subtitle: const Text(
                          'Toggle offline-first architecture (for debugging)',
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const DebugSettingsScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
