import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/company_info_service.dart';
import '../../widgets/app_drawer.dart';
import '../../theme/app_theme.dart';
import '../../services/global_notification_service.dart';

class CompanyInfoScreen extends StatefulWidget {
  const CompanyInfoScreen({super.key});

  @override
  State<CompanyInfoScreen> createState() => _CompanyInfoScreenState();
}

class _CompanyInfoScreenState extends State<CompanyInfoScreen> {
  bool _isLoading = false;
  Map<String, dynamic>? _companyInfo;
  Map<String, dynamic>? _usageInfo;
  Map<String, dynamic>? _subscriptionInfo;
  List<Map<String, dynamic>>? _companyUpdates;

  @override
  void initState() {
    super.initState();
    _loadCompanyInfo();
  }

  @override
  void dispose() {
    // Clean up any resources if needed
    super.dispose();
  }

  Future<void> _loadCompanyInfo() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final companyInfoService = CompanyInfoService(authProvider);

      // Load all company information in parallel
      final results = await Future.wait([
        companyInfoService.getCompanyInfo(),
        companyInfoService.getCompanyUsage(),
        companyInfoService.getSubscriptionInfo(),
        companyInfoService.getCompanyUpdates(),
      ]);

      if (!mounted) return;

      setState(() {
        _companyInfo = results[0] as Map<String, dynamic>;
        _usageInfo = results[1] as Map<String, dynamic>;
        _subscriptionInfo = results[2] as Map<String, dynamic>;
        _companyUpdates = results[3] as List<Map<String, dynamic>>;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        GlobalNotificationService().showError('Error loading company info: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Company Information'),
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadCompanyInfo,
          ),
        ],
      ),
      drawer: const AppDrawer(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadCompanyInfo,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AppTheme.spacingL),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Company Overview Card
                    Card(
                      elevation: AppTheme.elevationMedium,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusMedium,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(AppTheme.spacingL),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.business,
                                  color: AppTheme.primary,
                                  size: 24,
                                ),
                                const SizedBox(width: AppTheme.spacingS),
                                Text(
                                  'Company Overview',
                                  style: AppTheme.titleLarge.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                const Spacer(),
                                IconButton(
                                  icon: const Icon(Icons.refresh, size: 20),
                                  onPressed: _loadCompanyInfo,
                                ),
                              ],
                            ),
                            const SizedBox(height: AppTheme.spacingL),
                            _buildCompanyOverview(),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: AppTheme.spacingL),

                    // Workplace Information Card
                    Card(
                      elevation: AppTheme.elevationMedium,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusMedium,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(AppTheme.spacingL),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.work,
                                  color: AppTheme.success,
                                  size: 24,
                                ),
                                const SizedBox(width: AppTheme.spacingS),
                                Text(
                                  'Workplace Information',
                                  style: AppTheme.titleLarge.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                const Spacer(),
                                IconButton(
                                  icon: const Icon(Icons.refresh, size: 20),
                                  onPressed: _loadCompanyInfo,
                                ),
                              ],
                            ),
                            const SizedBox(height: AppTheme.spacingL),
                            _buildWorkplaceInfo(),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: AppTheme.spacingL),

                    // Available Tools Card
                    Card(
                      elevation: AppTheme.elevationMedium,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusMedium,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(AppTheme.spacingL),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.build,
                                  color: AppTheme.warning,
                                  size: 24,
                                ),
                                const SizedBox(width: AppTheme.spacingS),
                                Text(
                                  'Available Tools',
                                  style: AppTheme.titleLarge.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                const Spacer(),
                                IconButton(
                                  icon: const Icon(Icons.refresh, size: 20),
                                  onPressed: _loadCompanyInfo,
                                ),
                              ],
                            ),
                            const SizedBox(height: AppTheme.spacingL),
                            _buildAvailableTools(),
                          ],
                        ),
                      ),
                    ),

                    // Company Updates Card
                    Card(
                      elevation: AppTheme.elevationMedium,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusMedium,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(AppTheme.spacingL),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.announcement,
                                  color: AppTheme.secondary,
                                  size: 24,
                                ),
                                const SizedBox(width: AppTheme.spacingS),
                                Text(
                                  'Company Updates',
                                  style: AppTheme.titleLarge.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                const Spacer(),
                                IconButton(
                                  icon: const Icon(Icons.refresh, size: 20),
                                  onPressed: _loadCompanyInfo,
                                ),
                              ],
                            ),
                            const SizedBox(height: AppTheme.spacingL),
                            _buildCompanyUpdates(),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: AppTheme.spacingXl),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildCompanyOverview() {
    if (_companyInfo == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingL),
          child: Column(
            children: [
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(height: AppTheme.spacingS),
              Text(
                'Loading company information...',
                style: AppTheme.smallCaption.copyWith(color: AppTheme.muted),
              ),
            ],
          ),
        ),
      );
    }

    final info = _companyInfo!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Company Name
        if (info['name'] != null && info['name'].toString().isNotEmpty)
          _buildInfoRow('Company Name', info['name']),

        // Company Status
        if (info['status'] != null && info['status'].toString().isNotEmpty)
          _buildInfoRow(
            'Status',
            info['status'].toString().toUpperCase() == 'TRIAL' &&
                    info['trialPlanName'] != null
                ? 'TRIAL - ${info['trialPlanName']}'
                : info['status'].toString().toUpperCase(),
          ),

        // Employee Count
        if (_usageInfo != null)
          _buildInfoRow(
            'Total Employees',
            '${_usageInfo!['employees']?['current'] ?? 0}',
          ),

        const SizedBox(height: AppTheme.spacingL),
        Container(
          padding: const EdgeInsets.all(AppTheme.spacingM),
          decoration: BoxDecoration(
            color: info['status'] == 'trial'
                ? AppTheme.warning.withValues(alpha: 0.1)
                : AppTheme.success.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            border: Border.all(
              color: info['status'] == 'trial'
                  ? AppTheme.warning.withValues(alpha: 0.3)
                  : AppTheme.success.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              Icon(
                info['status'] == 'trial'
                    ? Icons.access_time
                    : Icons.check_circle,
                color: info['status'] == 'trial'
                    ? AppTheme.warning
                    : AppTheme.success,
                size: 20,
              ),
              const SizedBox(width: AppTheme.spacingS),
              Expanded(
                child: Text(
                  info['status'] == 'trial'
                      ? 'Your company is in trial period. Enjoy full access to all features!'
                      : 'Your company is active and ready for work!',
                  style: AppTheme.smallCaption.copyWith(
                    color: info['status'] == 'trial'
                        ? AppTheme.warning
                        : AppTheme.success,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWorkplaceInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildWorkplaceRow(
          'Working Hours',
          '9:00 AM - 5:00 PM',
          Icons.access_time,
          AppTheme.primary,
        ),
        const SizedBox(height: AppTheme.spacingM),
        _buildWorkplaceRow(
          'Work Days',
          'Monday - Friday',
          Icons.calendar_today,
          AppTheme.success,
        ),
        const SizedBox(height: AppTheme.spacingM),
        _buildWorkplaceRow(
          'Break Time',
          '1 hour lunch break',
          Icons.restaurant,
          AppTheme.warning,
        ),
        const SizedBox(height: AppTheme.spacingM),
        _buildWorkplaceRow(
          'Location Tracking',
          'Enabled for attendance',
          Icons.location_on,
          AppTheme.error,
        ),
        const SizedBox(height: AppTheme.spacingL),
        Container(
          padding: const EdgeInsets.all(AppTheme.spacingM),
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: AppTheme.primary, size: 20),
              const SizedBox(width: AppTheme.spacingS),
              Expanded(
                child: Text(
                  'Contact your manager for specific workplace policies and procedures.',
                  style: AppTheme.smallCaption.copyWith(
                    color: AppTheme.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAvailableTools() {
    if (_subscriptionInfo == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final features = _subscriptionInfo!['features'] ?? [];

    return Column(
      children: [
        _buildToolRow(
          'Clock In/Out',
          'Track your work hours',
          Icons.access_time,
          AppTheme.success,
        ),
        const SizedBox(height: AppTheme.spacingS),
        _buildToolRow(
          'Leave Requests',
          'Submit time-off requests',
          Icons.beach_access,
          AppTheme.primary,
        ),
        const SizedBox(height: AppTheme.spacingS),
        _buildToolRow(
          'Payroll Access',
          'View your payslips',
          Icons.account_balance_wallet,
          AppTheme.warning,
        ),
        const SizedBox(height: AppTheme.spacingS),
        _buildToolRow(
          'Document Center',
          'Access company documents',
          Icons.folder,
          AppTheme.secondary,
        ),
        const SizedBox(height: AppTheme.spacingS),
        _buildToolRow(
          'Notifications',
          'Stay updated with alerts',
          Icons.notifications,
          AppTheme.error,
        ),
        if (features.isNotEmpty) ...[
          const SizedBox(height: AppTheme.spacingL),
          const Divider(),
          const SizedBox(height: AppTheme.spacingS),
          Text(
            'Additional Features:',
            style: AppTheme.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
              color: AppTheme.muted,
            ),
          ),
          const SizedBox(height: AppTheme.spacingS),
          ...features
              .take(5)
              .map(
                (feature) => Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: AppTheme.spacingXs,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_circle,
                        color: AppTheme.success,
                        size: 16,
                      ),
                      const SizedBox(width: AppTheme.spacingS),
                      Expanded(
                        child: Text(feature, style: AppTheme.smallCaption),
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingXs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: AppTheme.bodyMedium.copyWith(
                fontWeight: FontWeight.w500,
                color: AppTheme.muted,
              ),
            ),
          ),
          const SizedBox(width: AppTheme.spacingL),
          Expanded(
            child: Text(
              value,
              style: AppTheme.bodyMedium.copyWith(color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkplaceRow(
    String title,
    String subtitle,
    IconData icon,
    Color color,
  ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(AppTheme.spacingS),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: AppTheme.spacingM),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTheme.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              Text(
                subtitle,
                style: AppTheme.smallCaption.copyWith(color: AppTheme.muted),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildToolRow(
    String title,
    String subtitle,
    IconData icon,
    Color color,
  ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(AppTheme.spacingS),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: AppTheme.spacingM),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTheme.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              Text(
                subtitle,
                style: AppTheme.smallCaption.copyWith(color: AppTheme.muted),
              ),
            ],
          ),
        ),
        Icon(Icons.arrow_forward_ios, size: 16, color: AppTheme.muted),
      ],
    );
  }

  IconData _getUpdateIcon(String type) {
    switch (type) {
      case 'maintenance':
        return Icons.build;
      case 'feature':
        return Icons.new_releases;
      case 'holiday':
        return Icons.event;
      case 'announcement':
        return Icons.announcement;
      case 'urgent':
        return Icons.warning;
      default:
        return Icons.info;
    }
  }

  Color _getUpdateColor(String type) {
    switch (type) {
      case 'maintenance':
        return AppTheme.warning;
      case 'feature':
        return AppTheme.success;
      case 'holiday':
        return AppTheme.error;
      case 'announcement':
        return AppTheme.primary;
      case 'urgent':
        return AppTheme.error;
      default:
        return AppTheme.muted;
    }
  }

  String _getTimeAgo(String createdAt) {
    try {
      final date = DateTime.parse(createdAt);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays > 0) {
        return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
      } else {
        return 'Just now';
      }
    } catch (e) {
      return 'Recently';
    }
  }

  Widget _buildCompanyUpdates() {
    if (_companyUpdates == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_companyUpdates!.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(AppTheme.spacingXl),
        child: Column(
          children: [
            Icon(Icons.notifications_none, size: 48, color: AppTheme.muted),
            const SizedBox(height: AppTheme.spacingL),
            Text(
              'No updates available',
              style: AppTheme.bodyLarge.copyWith(
                fontWeight: FontWeight.w500,
                color: AppTheme.muted,
              ),
            ),
            const SizedBox(height: AppTheme.spacingS),
            Text(
              'Check back later for company announcements',
              style: AppTheme.smallCaption.copyWith(color: AppTheme.muted),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        ..._companyUpdates!.map((update) {
          final icon = _getUpdateIcon(update['type']);
          final color = _getUpdateColor(update['type']);
          final timeAgo = _getTimeAgo(update['createdAt']);

          return Column(
            children: [
              _buildUpdateItem(
                update['title'] ?? 'Update',
                update['message'] ?? '',
                icon,
                color,
                timeAgo,
              ),
              if (update != _companyUpdates!.last)
                const SizedBox(height: AppTheme.spacingM),
            ],
          );
        }),
        const SizedBox(height: AppTheme.spacingL),
        Container(
          padding: const EdgeInsets.all(AppTheme.spacingM),
          decoration: BoxDecoration(
            color: AppTheme.muted.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            border: Border.all(color: AppTheme.muted.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: AppTheme.muted, size: 20),
              const SizedBox(width: AppTheme.spacingS),
              Expanded(
                child: Text(
                  'Check the main dashboard for real-time updates and notifications.',
                  style: AppTheme.smallCaption.copyWith(color: AppTheme.muted),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildUpdateItem(
    String title,
    String description,
    IconData icon,
    Color color,
    String time,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(AppTheme.spacingS),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: AppTheme.spacingM),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTheme.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: AppTheme.spacingXs),
              Text(
                description,
                style: AppTheme.smallCaption.copyWith(color: AppTheme.muted),
              ),
              const SizedBox(height: AppTheme.spacingXs),
              Text(
                time,
                style: AppTheme.smallCaption.copyWith(color: AppTheme.muted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
