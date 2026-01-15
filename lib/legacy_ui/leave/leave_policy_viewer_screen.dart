import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../config/api_config.dart';

class LeavePolicyViewerScreen extends StatefulWidget {
  const LeavePolicyViewerScreen({super.key});

  @override
  State<LeavePolicyViewerScreen> createState() =>
      _LeavePolicyViewerScreenState();
}

class _LeavePolicyViewerScreenState extends State<LeavePolicyViewerScreen> {
  Map<String, dynamic>? _policy;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPolicy();
  }

  Future<void> _loadPolicy() async {
    try {
      final api = ApiService(baseUrl: ApiConfig.baseUrl);
      final response = await api.get('/leave-policies/simple/default');

      if (response.success && response.data != null) {
        setState(() {
          _policy = response.data;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Failed to load policy';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error loading policy';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Leave Policy'),
        backgroundColor: colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _buildErrorState(theme)
          : _buildPolicyContent(theme, colorScheme),
    );
  }

  Widget _buildErrorState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red[400]),
          const SizedBox(height: 16),
          Text(
            'Unable to Load Policy',
            style: theme.textTheme.headlineSmall?.copyWith(
              color: Colors.red[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _error ?? 'An error occurred while loading the leave policy.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(onPressed: _loadPolicy, child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _buildPolicyContent(ThemeData theme, ColorScheme colorScheme) {
    if (_policy == null) return const SizedBox.shrink();

    final policy = _policy!;
    final country = policy['country'] ?? 'Nepal';
    final isAustralian = country == 'Australia';
    final leaveTypes = policy['leaveTypes'] ?? {};
    final rules = policy['rules'] ?? {};

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Policy Header
          _buildPolicyHeader(theme, colorScheme, policy, country, isAustralian),

          const SizedBox(height: 24),

          // Leave Entitlements Section
          _buildLeaveEntitlementsSection(
            theme,
            colorScheme,
            leaveTypes,
            isAustralian,
          ),

          const SizedBox(height: 24),

          // Policy Rules Section
          _buildPolicyRulesSection(theme, colorScheme, rules, isAustralian),

          const SizedBox(height: 24),

          // Employee Type Information (for Australian policies)
          if (isAustralian) ...[
            _buildEmployeeTypeSection(theme, colorScheme, rules),
            const SizedBox(height: 24),
          ],

          // Additional Information
          _buildAdditionalInfoSection(theme, colorScheme, policy),
        ],
      ),
    );
  }

  Widget _buildPolicyHeader(
    ThemeData theme,
    ColorScheme colorScheme,
    Map<String, dynamic> policy,
    String country,
    bool isAustralian,
  ) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isAustralian ? Icons.flag : Icons.business,
                  color: isAustralian ? Colors.green[600] : Colors.blue[600],
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    policy['name'] ?? 'Leave Policy',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (policy['isDefault'] == true)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green[100],
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      'DEFAULT',
                      style: TextStyle(
                        color: Colors.green[700],
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.public, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 6),
                Text(
                  country,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (isAustralian) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green[200]!),
                    ),
                    child: Text(
                      'Fair Work Compliant',
                      style: TextStyle(
                        color: Colors.green[700],
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            if (policy['description'] != null) ...[
              const SizedBox(height: 8),
              Text(
                policy['description'],
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLeaveEntitlementsSection(
    ThemeData theme,
    ColorScheme colorScheme,
    Map<String, dynamic> leaveTypes,
    bool isAustralian,
  ) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  color: colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Leave Entitlements',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              isAustralian
                  ? 'Days per year for each leave type (Australian Fair Work compliant)'
                  : 'Days per year for each leave type',
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
            const SizedBox(height: 16),

            // Leave types based on country
            if (isAustralian) ...[
              _buildLeaveTypeRow(
                'Annual Leave',
                leaveTypes['annualLeave']?['totalDays'] ?? 0,
                Colors.blue,
                '4 weeks per year',
              ),
              _buildLeaveTypeRow(
                'Personal/Carer\'s Leave',
                leaveTypes['sickLeave']?['totalDays'] ?? 0,
                Colors.red,
                'For personal illness or caring for family',
              ),
              _buildLeaveTypeRow(
                'Compassionate Leave',
                leaveTypes['compassionateLeave']?['totalDays'] ?? 0,
                Colors.brown,
                '2 days per occasion',
              ),
              _buildLeaveTypeRow(
                'Parental Leave',
                leaveTypes['parentalLeave']?['totalDays'] ?? 0,
                Colors.pink,
                'Up to 52 weeks unpaid',
              ),
              _buildLeaveTypeRow(
                'Long Service Leave',
                leaveTypes['longServiceLeave']?['totalDays'] ?? 0,
                Colors.blueGrey,
                'After 7+ years of service',
              ),
            ] else ...[
              _buildLeaveTypeRow(
                'Annual Leave',
                leaveTypes['annualLeave']?['totalDays'] ?? 0,
                Colors.blue,
              ),
              _buildLeaveTypeRow(
                'Sick Leave',
                leaveTypes['sickLeave']?['totalDays'] ?? 0,
                Colors.red,
              ),
              _buildLeaveTypeRow(
                'Casual Leave',
                leaveTypes['casualLeave']?['totalDays'] ?? 0,
                Colors.orange,
              ),
              _buildLeaveTypeRow(
                'Maternity Leave',
                leaveTypes['maternityLeave']?['totalDays'] ?? 0,
                Colors.pink,
              ),
              _buildLeaveTypeRow(
                'Paternity Leave',
                leaveTypes['paternityLeave']?['totalDays'] ?? 0,
                Colors.indigo,
              ),
            ],
            _buildLeaveTypeRow(
              'Unpaid Leave',
              leaveTypes['unpaidLeave']?['totalDays'] ?? 0,
              Colors.grey,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeaveTypeRow(
    String name,
    int days,
    Color color, [
    String? description,
  ]) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (description != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ],
            ),
          ),
          Text(
            '$days days',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPolicyRulesSection(
    ThemeData theme,
    ColorScheme colorScheme,
    Map<String, dynamic> rules,
    bool isAustralian,
  ) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.settings, color: colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Policy Rules',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            _buildRuleItem(
              'Minimum Notice',
              '${rules['minNoticeDays'] ?? 1} days',
              Icons.schedule,
            ),
            _buildRuleItem(
              'Maximum Consecutive Days',
              '${rules['maxConsecutiveDays'] ?? 30} days',
              Icons.calendar_view_week,
            ),
            _buildRuleItem(
              'Office Hours Cutoff',
              '${rules['officeHoursCutoff'] ?? 9}:00 AM',
              Icons.access_time,
            ),
            _buildRuleItem(
              'Half-Day Leaves',
              rules['allowHalfDays'] == true ? 'Allowed' : 'Not Allowed',
              Icons.schedule,
            ),
            _buildRuleItem(
              'Leave Cancellation',
              rules['allowCancellation'] == true ? 'Allowed' : 'Not Allowed',
              Icons.cancel,
            ),
            _buildRuleItem(
              'Carry Over Balance',
              rules['carryOverBalance'] == true ? 'Allowed' : 'Not Allowed',
              Icons.forward,
            ),

            if (rules['carryOverBalance'] == true)
              _buildRuleItem(
                'Max Carry Over Days',
                '${rules['maxCarryOverDays'] ?? 5} days',
                Icons.forward,
              ),

            if (isAustralian && rules['progressiveAccrual'] == true)
              _buildRuleItem(
                'Progressive Accrual',
                'Leave accrues throughout the year',
                Icons.trending_up,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRuleItem(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 14))),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmployeeTypeSection(
    ThemeData theme,
    ColorScheme colorScheme,
    Map<String, dynamic> rules,
  ) {
    final entitlements = rules['employeeTypeEntitlements'] ?? {};

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.people, color: colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Employee Type Entitlements',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Different leave entitlements based on employment type',
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
            const SizedBox(height: 16),

            // Full-time entitlements
            if (entitlements['Full-time'] != null)
              _buildEmployeeTypeCard(
                'Full-time',
                entitlements['Full-time'],
                Colors.blue,
              ),

            const SizedBox(height: 12),

            // Part-time entitlements
            if (entitlements['Part-time'] != null)
              _buildEmployeeTypeCard(
                'Part-time',
                entitlements['Part-time'],
                Colors.green,
              ),

            const SizedBox(height: 12),

            // Casual entitlements
            if (entitlements['Casual'] != null)
              _buildEmployeeTypeCard(
                'Casual',
                entitlements['Casual'],
                Colors.orange,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmployeeTypeCard(
    String type,
    Map<String, dynamic> entitlements,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.person, color: color, size: 18),
              const SizedBox(width: 8),
              Text(
                type,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: entitlements.entries
                .where(
                  (entry) => entry.key != 'casualLoading' && entry.value > 0,
                )
                .map(
                  (entry) =>
                      _buildEntitlementChip(entry.key, entry.value, color),
                )
                .toList(),
          ),
          if (entitlements['casualLoading'] != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${entitlements['casualLoading']}% Casual Loading',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.orange[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEntitlementChip(String type, int days, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$type: $days days',
        style: TextStyle(
          fontSize: 12,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildAdditionalInfoSection(
    ThemeData theme,
    ColorScheme colorScheme,
    Map<String, dynamic> policy,
  ) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Additional Information',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            _buildInfoItem('Policy Created', _formatDate(policy['createdAt'])),
            _buildInfoItem('Last Updated', _formatDate(policy['updatedAt'])),
            _buildInfoItem(
              'Policy Status',
              policy['isActive'] == true ? 'Active' : 'Inactive',
            ),
            _buildInfoItem(
              'Leave Year Start',
              '${policy['rules']?['leaveYearStartMonth'] ?? 1}/${policy['rules']?['leaveYearStartDay'] ?? 1}',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'Unknown';
    try {
      final d = DateTime.parse(date.toString()).toLocal();
      return '${d.day}/${d.month}/${d.year}';
    } catch (_) {
      return 'Unknown';
    }
  }
}
