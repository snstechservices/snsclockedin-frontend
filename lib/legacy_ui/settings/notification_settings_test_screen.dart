import 'package:flutter/material.dart';
import '../../services/notification_preferences_service.dart';
import '../../services/action_sound_service.dart';
import '../../services/haptic_feedback_service.dart';
import '../../services/global_notification_service.dart';
import '../../utils/logger.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:typed_data';

/// Test screen for notification settings - helps verify sound/vibration/haptic feedback
class NotificationSettingsTestScreen extends StatefulWidget {
  const NotificationSettingsTestScreen({super.key});

  @override
  State<NotificationSettingsTestScreen> createState() =>
      _NotificationSettingsTestScreenState();
}

class _NotificationSettingsTestScreenState
    extends State<NotificationSettingsTestScreen> {
  final NotificationPreferencesService _prefsService =
      NotificationPreferencesService.instance;
  final ActionSoundService _soundService = ActionSoundService.instance;
  final HapticFeedbackService _hapticService = HapticFeedbackService.instance;
  final GlobalNotificationService _globalNotifService =
      GlobalNotificationService();
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  bool _soundEnabled = true;
  bool _vibrationEnabled = true;
  bool _hapticEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await _prefsService.getAllPreferences();
    setState(() {
      _soundEnabled = prefs['sound'] ?? true;
      _vibrationEnabled = prefs['vibration'] ?? true;
      _hapticEnabled = prefs['hapticFeedback'] ?? true;
    });
  }

  Future<void> _testActionSound(String actionName) async {
    Logger.info('TEST: Testing action sound for: $actionName');
    switch (actionName) {
      case 'Clock In':
        await _soundService.playClockInSound();
        break;
      case 'Clock Out':
        await _soundService.playClockOutSound();
        break;
      case 'Start Break':
        await _soundService.playStartBreakSound();
        break;
      case 'End Break':
        await _soundService.playEndBreakSound();
        break;
    }
    _showResult('Action Sound Test', '$actionName sound/vibration triggered');
  }

  Future<void> _testGlobalNotification(String type) async {
    Logger.info('TEST: Testing global notification type: $type');
    switch (type) {
      case 'Success':
        _globalNotifService.showSuccess('Test success notification');
        break;
      case 'Error':
        _globalNotifService.showError('Test error notification');
        break;
      case 'Info':
        _globalNotifService.showInfo('Test info notification');
        break;
      case 'Warning':
        _globalNotifService.showWarning('Test warning notification');
        break;
    }
    _showResult('Global Notification Test', '$type notification shown');
  }

  Future<void> _testPushNotification() async {
    Logger.info('TEST: Testing push notification');

    // Skip push notification test on web - not supported
    if (kIsWeb) {
      _showResult(
        'Push Notification Test',
        'Push notifications not supported on web. Use browser notifications instead.',
      );
      return;
    }

    final soundEnabled = await _prefsService.isSoundEnabled();
    final vibrationEnabled = await _prefsService.isVibrationEnabled();

    final String channelId;
    final String channelName;

    if (soundEnabled && vibrationEnabled) {
      channelId = 'high_importance_channel';
      channelName = 'High Importance Notifications';
    } else if (soundEnabled && !vibrationEnabled) {
      channelId = 'sound_only_channel';
      channelName = 'Sound Only Notifications';
    } else if (!soundEnabled && vibrationEnabled) {
      channelId = 'vibration_only_channel';
      channelName = 'Vibration Only Notifications';
    } else {
      channelId = 'silent_notifications_channel';
      channelName = 'Silent Notifications';
    }

    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          channelId,
          channelName,
          channelDescription: 'Test notification',
          importance: Importance.max,
          priority: Priority.high,
          showWhen: true,
          vibrationPattern: (!kIsWeb && vibrationEnabled)
              ? Int64List.fromList([0, 500, 250, 500])
              : null,
          enableVibration: vibrationEnabled,
          playSound: soundEnabled,
        );

    const DarwinNotificationDetails iOSDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iOSDetails,
    );

    await _localNotifications.show(
      99999,
      'Test Push Notification',
      'This is a test push notification',
      platformDetails,
    );

    _showResult('Push Notification Test', 'Push notification sent');
  }

  void _showResult(String title, String message) {
    if (mounted) {
      GlobalNotificationService().showSuccess('$title: $message');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Settings Test'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Current Settings
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Current Settings',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('Sound: $_soundEnabled'),
                    Text('Vibration: $_vibrationEnabled'),
                    Text('Haptic Feedback: $_hapticEnabled'),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _loadPreferences,
                      child: const Text('Refresh Settings'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Action Sounds Tests
            Text(
              'Action Sounds (Clock In/Out, Break)',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildTestButton(
                  'Clock In',
                  () => _testActionSound('Clock In'),
                ),
                _buildTestButton(
                  'Clock Out',
                  () => _testActionSound('Clock Out'),
                ),
                _buildTestButton(
                  'Start Break',
                  () => _testActionSound('Start Break'),
                ),
                _buildTestButton(
                  'End Break',
                  () => _testActionSound('End Break'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Global Notifications Tests
            Text(
              'Global Notifications (In-App Banners)',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildTestButton(
                  'Success',
                  () => _testGlobalNotification('Success'),
                ),
                _buildTestButton(
                  'Error',
                  () => _testGlobalNotification('Error'),
                ),
                _buildTestButton('Info', () => _testGlobalNotification('Info')),
                _buildTestButton(
                  'Warning',
                  () => _testGlobalNotification('Warning'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Push Notification Test
            Text(
              'Push Notifications',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            _buildTestButton('Test Push Notification', _testPushNotification),
            const SizedBox(height: 16),

            // Haptic Feedback Tests
            Text(
              'Haptic Feedback',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildTestButton(
                  'Light',
                  () => _hapticService.testLightImpact(),
                ),
                _buildTestButton(
                  'Medium',
                  () => _hapticService.testMediumImpact(),
                ),
                _buildTestButton(
                  'Heavy',
                  () => _hapticService.testHeavyImpact(),
                ),
                _buildTestButton('Success', () => _hapticService.testSuccess()),
                _buildTestButton('Error', () => _hapticService.testError()),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTestButton(String label, VoidCallback onPressed) {
    return ElevatedButton(onPressed: onPressed, child: Text(label));
  }
}
