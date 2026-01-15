import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/logger.dart';
import '../../services/privacy_service.dart';
import '../../services/notification_preferences_service.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/admin_side_navigation.dart';
import '../../services/haptic_feedback_service.dart';
import '../../services/global_notification_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'dart:typed_data';

class PrivacySettingsScreen extends StatefulWidget {
  const PrivacySettingsScreen({super.key});

  @override
  State<PrivacySettingsScreen> createState() => _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends State<PrivacySettingsScreen> {
  bool _locationEnabled = true;
  bool _notificationsEnabled = true;
  bool _analyticsEnabled = true;
  bool _cameraEnabled = true;
  bool _storageEnabled = true;
  bool _isLoading = true;

  // Notification preferences
  bool _notificationSoundEnabled = true;
  bool _notificationVibrationEnabled = true;
  bool _hapticFeedbackEnabled = true;

  final PrivacyService _privacyService = PrivacyService.instance;
  final NotificationPreferencesService _notificationPreferencesService =
      NotificationPreferencesService.instance;

  @override
  void initState() {
    super.initState();
    _loadPrivacySettings();
  }

  Future<void> _loadPrivacySettings() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final settings = await _privacyService.getAllPrivacySettings();
      final notificationSettings = await _notificationPreferencesService
          .getAllPreferences();

      setState(() {
        _locationEnabled = settings['location'] ?? true;
        _notificationsEnabled = settings['notifications'] ?? true;
        _analyticsEnabled = settings['analytics'] ?? true;
        _cameraEnabled = settings['camera'] ?? true;
        _storageEnabled = settings['storage'] ?? true;
        _notificationSoundEnabled = notificationSettings['sound'] ?? true;
        _notificationVibrationEnabled =
            notificationSettings['vibration'] ?? true;
        _hapticFeedbackEnabled = notificationSettings['hapticFeedback'] ?? true;
        _isLoading = false;
      });
    } catch (e) {
      Logger.error('Error loading privacy settings: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _updatePrivacySetting(String key, bool value) async {
    try {
      await _privacyService.updatePrivacySetting(key, value);
      Logger.info('Privacy setting updated: $key = $value');
    } catch (e) {
      Logger.error('Error updating privacy setting: $e');
      if (mounted) {
        GlobalNotificationService().showError(
          'Failed to update privacy setting: $e',
        );
      }
    }
  }

  Future<void> _resetToDefaults() async {
    if (mounted) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Reset Privacy Settings'),
          content: const Text(
            'This will reset all privacy settings to their default values. Are you sure you want to proceed?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Reset'),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        await _privacyService.resetToDefaults();
        await _notificationPreferencesService.resetToDefaults();
        await _loadPrivacySettings();
        if (mounted) {
          GlobalNotificationService().showSuccess(
            'Privacy settings reset to defaults',
          );
        }
      }
    }
  }

  Future<void> _testNotification() async {
    try {
      // Force save any pending preference changes
      await _notificationPreferencesService.setSoundEnabled(
        _notificationSoundEnabled,
      );
      await _notificationPreferencesService.setVibrationEnabled(
        _notificationVibrationEnabled,
      );

      // Small delay to ensure SharedPreferences is written
      await Future.delayed(const Duration(milliseconds: 200));

      // Get current preferences directly from service (not state variable) - force fresh read
      final prefs = await SharedPreferences.getInstance();
      final soundEnabled = prefs.getBool('notification_sound_enabled') ?? true;
      final vibrationEnabled =
          prefs.getBool('notification_vibration_enabled') ?? true;

      Logger.info(
        'Test notification - Sound: $soundEnabled, Vibration: $vibrationEnabled',
      );
      Logger.info(
        'Test notification - State vars - Sound: $_notificationSoundEnabled, Vibration: $_notificationVibrationEnabled',
      );

      final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

      // Use different channel based on sound/vibration preferences
      // Android notification channels override individual notification settings,
      // so we need to use a channel that matches our preferences exactly
      final String channelId;
      final String channelName;

      if (soundEnabled && vibrationEnabled) {
        // Both enabled
        channelId = 'high_importance_channel';
        channelName = 'High Importance Notifications';
      } else if (soundEnabled && !vibrationEnabled) {
        // Sound only
        channelId = 'sound_only_channel';
        channelName = 'Sound Only Notifications';
      } else if (!soundEnabled && vibrationEnabled) {
        // Vibration only
        channelId = 'vibration_only_channel';
        channelName = 'Vibration Only Notifications';
      } else {
        // Both disabled
        channelId = 'silent_notifications_channel';
        channelName = 'Silent Notifications';
      }

      final AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
            channelId,
            channelName,
            channelDescription: 'Notifications for SNS Clocked In app',
            importance: Importance.max,
            priority: Priority.high,
            showWhen: true,
            vibrationPattern: (!kIsWeb && vibrationEnabled)
                ? Int64List.fromList([0, 500, 250, 500])
                : null,
            enableVibration: vibrationEnabled,
            playSound: soundEnabled,
          );

      final DarwinNotificationDetails iOSDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: soundEnabled, // Respect user preference
      );

      final NotificationDetails platformDetails = NotificationDetails(
        android: androidDetails,
        iOS: iOSDetails,
      );

      await flutterLocalNotificationsPlugin.show(
        9999, // Unique ID for test notification
        'Test Notification',
        soundEnabled && vibrationEnabled
            ? 'You should hear a sound and feel vibration'
            : soundEnabled
            ? 'You should hear a sound'
            : vibrationEnabled
            ? 'You should feel vibration'
            : 'Notification without sound or vibration',
        platformDetails,
      );

      if (mounted) {
        final message = soundEnabled && vibrationEnabled
            ? 'Test notification sent! Check for sound and vibration.'
            : soundEnabled
            ? 'Test notification sent! Check for sound.'
            : vibrationEnabled
            ? 'Test notification sent! Check for vibration.'
            : 'Test notification sent (silent mode).';
        GlobalNotificationService().showSuccess(message);
      }
    } catch (e) {
      Logger.error('Error sending test notification: $e');
      if (mounted) {
        GlobalNotificationService().showError(
          'Failed to send test notification: $e',
        );
      }
    }
  }

  Future<void> _testHapticFeedback() async {
    if (mounted) {
      // Force enable haptic feedback for testing (temporarily bypass preference check)
      // This ensures the test works even if haptic feedback is disabled
      final hapticService = HapticFeedbackService.instance;

      // Show dialog with options
      final result = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Test Haptic Feedback'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.touch_app),
                title: const Text('Light Impact'),
                subtitle: const Text('Double tap for better feel'),
                onTap: () => Navigator.pop(context, 'light'),
              ),
              ListTile(
                leading: const Icon(Icons.touch_app),
                title: const Text('Medium Impact'),
                subtitle: const Text('Double tap for better feel'),
                onTap: () => Navigator.pop(context, 'medium'),
              ),
              ListTile(
                leading: const Icon(Icons.touch_app),
                title: const Text('Heavy Impact'),
                onTap: () => Navigator.pop(context, 'heavy'),
              ),
              ListTile(
                leading: const Icon(Icons.check_circle),
                title: const Text('Success'),
                subtitle: const Text('Double medium impact'),
                onTap: () => Navigator.pop(context, 'success'),
              ),
              ListTile(
                leading: const Icon(Icons.error),
                title: const Text('Error'),
                subtitle: const Text('Heavy impact'),
                onTap: () => Navigator.pop(context, 'error'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      );

      if (result != null) {
        try {
          Logger.info('Testing haptic feedback type: $result');

          // Use test methods that bypass preference check
          switch (result) {
            case 'light':
              await hapticService.testLightImpact();
              break;
            case 'medium':
              await hapticService.testMediumImpact();
              break;
            case 'heavy':
              await hapticService.testHeavyImpact();
              break;
            case 'success':
              await hapticService.testSuccess();
              break;
            case 'error':
              await hapticService.testError();
              break;
          }

          Logger.info('Haptic feedback test completed: $result');

          if (mounted) {
            GlobalNotificationService().showSuccess(
              'Haptic feedback triggered: $result',
            );
          }
        } catch (e) {
          Logger.error('Error testing haptic feedback: $e');
          if (mounted) {
            GlobalNotificationService().showError(
              'Error testing haptic feedback: $e',
            );
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;
    final isAdmin = user?['role'] == 'admin';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Settings'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadPrivacySettings,
            tooltip: 'Refresh Settings',
          ),
        ],
      ),
      drawer: isAdmin
          ? const AdminSideNavigation(currentRoute: '/privacy-settings')
          : const AppDrawer(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Privacy Overview
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.privacy_tip,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Privacy Overview',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Control how your data is collected and used. You can change these settings at any time.',
                            style: TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Permission Settings
                  Text(
                    'App Permissions',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Location Permission
                  Card(
                    child: SwitchListTile(
                      title: const Text('Location Services'),
                      subtitle: const Text(
                        'Required for attendance tracking and geofencing',
                      ),
                      value: _locationEnabled,
                      onChanged: (value) {
                        setState(() {
                          _locationEnabled = value;
                        });
                        _updatePrivacySetting(
                          'privacy_location_enabled',
                          value,
                        );
                      },
                      secondary: const Icon(Icons.location_on),
                    ),
                  ),

                  // Media Access (covers gallery/files). Rename from Camera if no camera capture feature.
                  Card(
                    child: SwitchListTile(
                      title: const Text('Media Access'),
                      subtitle: const Text(
                        'Allow picking photos/files from gallery or storage',
                      ),
                      value: _cameraEnabled,
                      onChanged: (value) {
                        setState(() {
                          _cameraEnabled = value;
                        });
                        _updatePrivacySetting('privacy_camera_enabled', value);
                      },
                      secondary: const Icon(Icons.photo_library),
                    ),
                  ),

                  // Storage Permission
                  Card(
                    child: SwitchListTile(
                      title: const Text('Storage Access'),
                      subtitle: const Text('For app data and file storage'),
                      value: _storageEnabled,
                      onChanged: (value) {
                        setState(() {
                          _storageEnabled = value;
                        });
                        _updatePrivacySetting('privacy_storage_enabled', value);
                      },
                      secondary: const Icon(Icons.storage),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Data Usage Settings
                  Text(
                    'Data Usage',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Notifications
                  Card(
                    child: SwitchListTile(
                      title: const Text('Push Notifications'),
                      subtitle: const Text(
                        'Receive attendance reminders and updates',
                      ),
                      value: _notificationsEnabled,
                      onChanged: (value) {
                        setState(() {
                          _notificationsEnabled = value;
                        });
                        _updatePrivacySetting(
                          'privacy_notifications_enabled',
                          value,
                        );
                      },
                      secondary: const Icon(Icons.notifications),
                    ),
                  ),

                  // Analytics
                  Card(
                    child: SwitchListTile(
                      title: const Text('Usage Analytics'),
                      subtitle: const Text(
                        'Help us improve the app (anonymous data only)',
                      ),
                      value: _analyticsEnabled,
                      onChanged: (value) {
                        setState(() {
                          _analyticsEnabled = value;
                        });
                        _updatePrivacySetting(
                          'privacy_analytics_enabled',
                          value,
                        );
                      },
                      secondary: const Icon(Icons.analytics),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Notification Preferences
                  Text(
                    'Notification Preferences',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Notification Sound
                  Card(
                    child: SwitchListTile(
                      title: const Text('Notification Sounds'),
                      subtitle: const Text(
                        'Play sound when receiving notifications',
                      ),
                      value: _notificationSoundEnabled,
                      onChanged: (value) {
                        setState(() {
                          _notificationSoundEnabled = value;
                        });
                        _notificationPreferencesService.setSoundEnabled(value);
                      },
                      secondary: const Icon(Icons.volume_up),
                    ),
                  ),

                  // Notification Vibration
                  Card(
                    child: SwitchListTile(
                      title: const Text('Notification Vibration'),
                      subtitle: const Text(
                        'Vibrate when receiving notifications',
                      ),
                      value: _notificationVibrationEnabled,
                      onChanged: (value) {
                        setState(() {
                          _notificationVibrationEnabled = value;
                        });
                        _notificationPreferencesService.setVibrationEnabled(
                          value,
                        );
                      },
                      secondary: const Icon(Icons.vibration),
                    ),
                  ),

                  // Haptic Feedback
                  Card(
                    child: SwitchListTile(
                      title: const Text('Haptic Feedback'),
                      subtitle: const Text(
                        'Vibrate on button taps and interactions',
                      ),
                      value: _hapticFeedbackEnabled,
                      onChanged: (value) {
                        setState(() {
                          _hapticFeedbackEnabled = value;
                        });
                        _notificationPreferencesService
                            .setHapticFeedbackEnabled(value);
                      },
                      secondary: const Icon(Icons.touch_app),
                    ),
                  ),

                  // Test features - only show in debug mode
                  if (kDebugMode) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Test Features (Debug Only)',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Test Notification Button
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.notifications_active),
                        title: const Text('Test Notification'),
                        subtitle: const Text(
                          'Send a test notification to verify sound and vibration',
                        ),
                        trailing: const Icon(Icons.play_arrow),
                        onTap: _testNotification,
                      ),
                    ),

                    // Test Haptic Feedback Button
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.vibration),
                        title: const Text('Test Haptic Feedback'),
                        subtitle: const Text(
                          'Test haptic feedback (light, medium, heavy, success, error)',
                        ),
                        trailing: const Icon(Icons.play_arrow),
                        onTap: _testHapticFeedback,
                      ),
                    ),
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.bug_report),
                        title: const Text('Comprehensive Test Screen'),
                        subtitle: const Text(
                          'Open full test screen for all notification types',
                        ),
                        trailing: const Icon(Icons.arrow_forward),
                        onTap: () {
                          Navigator.pushNamed(context, '/notification-test');
                        },
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),

                  // Additional Options
                  Text(
                    'Additional Options',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Reset to Defaults
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.restore),
                      title: const Text('Reset to Defaults'),
                      subtitle: const Text(
                        'Reset all privacy settings to default values',
                      ),
                      onTap: _resetToDefaults,
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    ),
                  ),

                  // Note about Privacy Policy and Support
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: theme.colorScheme.outline.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: theme.colorScheme.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'For privacy policy and support, please visit the About screen.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Privacy Notice
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Privacy Notice',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Your privacy is important to us. We collect and use your data to provide HR management services. We do not sell your data to third parties. You can control your privacy settings and exercise your data rights at any time.',
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
