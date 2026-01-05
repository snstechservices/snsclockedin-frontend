import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sns_clocked_in/core/state/app_state.dart';
import 'package:sns_clocked_in/design_system/app_colors.dart';
import 'package:sns_clocked_in/design_system/app_spacing.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('SNS Clocked In'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () {
              // Clear auth state - router will handle navigation
              context.read<AppState>().logout();
            },
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: AppSpacing.xlAll,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.check_circle_outline,
                size: 100,
                color: Theme.of(context).colorScheme.primary,
              ),
              SizedBox(height: AppSpacing.xl),
              Text(
                'Welcome to SNS Clocked In',
                style: Theme.of(context).textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              SizedBox(height: AppSpacing.l),
              Text(
                'Foundation setup complete!\nReady for feature implementation.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: AppSpacing.xl * 2),
              Card(
                child: Padding(
                  padding: AppSpacing.lAll,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Next Steps (Step 2+):',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      SizedBox(height: AppSpacing.m),
                      _buildBulletPoint(context, 'Implement authentication flow'),
                      _buildBulletPoint(context, 'Add time tracking features'),
                      _buildBulletPoint(context, 'Integrate with backend API'),
                      _buildBulletPoint(context, 'Add offline sync capability'),
                      _buildBulletPoint(context, 'Migrate old code features'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBulletPoint(BuildContext context, String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: AppSpacing.s),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.circle,
            size: 8,
            color: Theme.of(context).colorScheme.primary,
          ),
          SizedBox(width: AppSpacing.s),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
