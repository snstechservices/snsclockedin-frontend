import 'package:flutter/material.dart';
import '../../widgets/app_drawer.dart';

class EmployeeHelpSupportScreen extends StatelessWidget {
  const EmployeeHelpSupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text('Help & Support'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Frequently Asked Questions',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    ListTile(
                      title: Text('How do I clock in and out?'),
                      subtitle: Text(
                        'Use the main dashboard to clock in when you arrive and clock out when you leave. Your attendance is automatically tracked.',
                      ),
                    ),
                    Divider(),
                    ListTile(
                      title: Text('How do I take a break?'),
                      subtitle: Text(
                        'On the dashboard, tap the break button to start your break. Remember to end your break when you return.',
                      ),
                    ),
                    Divider(),
                    ListTile(
                      title: Text('How do I view my timesheet?'),
                      subtitle: Text(
                        'Go to the Timesheet section to see your daily, weekly, and monthly attendance records.',
                      ),
                    ),
                    Divider(),
                    ListTile(
                      title: Text('How do I apply for leave?'),
                      subtitle: Text(
                        'Navigate to the Leave section and click "Apply for Leave" to submit your request.',
                      ),
                    ),
                    Divider(),
                    ListTile(
                      title: Text('How do I update my profile?'),
                      subtitle: Text(
                        'Go to Profile in the menu to update your personal information, emergency contacts, and other details.',
                      ),
                    ),
                    Divider(),
                    ListTile(
                      title: Text('Why is my timesheet showing wrong time?'),
                      subtitle: Text(
                        'Check your timezone settings in the menu. Make sure your timezone is set correctly for accurate time tracking.',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text('Contact Support', style: theme.textTheme.titleLarge),
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
                      'If you need further assistance, please contact us:',
                      style: theme.textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      leading: Icon(
                        Icons.email,
                        color: theme.colorScheme.primary,
                      ),
                      title: const Text('support@clockedin.com'),
                      onTap: () {
                        // Implement email launch
                      },
                    ),
                    const SizedBox(height: 8),
                    ListTile(
                      leading: Icon(
                        Icons.phone,
                        color: theme.colorScheme.primary,
                      ),
                      title: const Text('Contact your HR department'),
                      subtitle: const Text(
                        'For urgent matters, reach out to your HR team',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text('Quick Tips', style: theme.textTheme.titleLarge),
            const SizedBox(height: 16),
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    ListTile(
                      leading: Icon(
                        Icons.lightbulb_outline,
                        color: Colors.amber,
                      ),
                      title: Text('Set up notifications'),
                      subtitle: Text(
                        'Enable push notifications to stay updated on important updates.',
                      ),
                    ),
                    Divider(),
                    ListTile(
                      leading: Icon(Icons.schedule, color: Colors.blue),
                      title: Text('Check your timezone'),
                      subtitle: Text(
                        'Make sure your timezone is set correctly for accurate time tracking.',
                      ),
                    ),
                    Divider(),
                    ListTile(
                      leading: Icon(Icons.person, color: Colors.green),
                      title: Text('Complete your profile'),
                      subtitle: Text(
                        'Add your profile picture and emergency contact information.',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
