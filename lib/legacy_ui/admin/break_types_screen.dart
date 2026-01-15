import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../widgets/admin_side_navigation.dart';
import '../../services/global_notification_service.dart';
import '../../core/repository/attendance_repository.dart';
import '../../services/connectivity_service.dart';
import '../../core/services/hive_service.dart';
import '../../services/api_service.dart';
import '../../providers/auth_provider.dart';
import '../../config/api_config.dart';
import '../../utils/logger.dart';

class BreakTypesScreen extends StatefulWidget {
  const BreakTypesScreen({super.key});

  @override
  State<BreakTypesScreen> createState() => _BreakTypesScreenState();
}

class _BreakTypesScreenState extends State<BreakTypesScreen> {
  List<Map<String, dynamic>> _breakTypes = [];
  bool _isLoading = true;
  String? _errorMessage;
  late AttendanceRepository _attendanceRepository;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeRepository();
      _fetchBreakTypes();
    });
  }

  void _initializeRepository() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    _attendanceRepository = AttendanceRepository(
      connectivityService: ConnectivityService(),
      hiveService: HiveService(),
      apiService: ApiService(baseUrl: ApiConfig.baseUrl),
      authProvider: authProvider,
    );
  }

  Future<void> _fetchBreakTypes({bool forceRefresh = false}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Use repository's cache-first pattern
      final breakTypes = await _attendanceRepository.getBreakTypes(
        forceRefresh: forceRefresh,
      );

      if (mounted) {
        setState(() {
          _breakTypes = breakTypes;
          _isLoading = false;
        });
      }
    } catch (e) {
      Logger.error('BreakTypesScreen: Failed to fetch break types: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Error: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _toggleBreakTypeStatus(String id, bool currentStatus) async {
    try {
      await _attendanceRepository.toggleBreakTypeStatus(id, !currentStatus);

      if (!mounted) return;
      GlobalNotificationService().showSuccess(
        currentStatus ? 'Break type deactivated' : 'Break type activated',
      );
      await _fetchBreakTypes(forceRefresh: true);
    } catch (e) {
      if (!mounted) return;
      GlobalNotificationService().showError('Error: $e');
    }
  }

  Color _parseColor(String colorString) {
    try {
      return Color(int.parse(colorString.replaceFirst('#', '0xFF')));
    } catch (e) {
      return Colors.grey;
    }
  }

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'restaurant':
        return Icons.restaurant;
      case 'local_cafe':
        return Icons.local_cafe;
      case 'person':
        return Icons.person;
      case 'local_hospital':
        return Icons.local_hospital;
      case 'smoking_rooms':
        return Icons.smoking_rooms;
      default:
        return Icons.more_horiz;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Break Types Management'),
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_home),
            tooltip: 'Initialize Default Break Types',
            onPressed: _initializeDefaultBreakTypes,
          ),
        ],
      ),
      drawer: const AdminSideNavigation(currentRoute: '/break_types'),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _errorMessage!,
                    style: TextStyle(color: colorScheme.error),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _fetchBreakTypes,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : _breakTypes.isEmpty
          ? const Center(child: Text('No break types found'))
          : RefreshIndicator(
              onRefresh: () => _fetchBreakTypes(forceRefresh: true),
              child: ListView.builder(
                padding: const EdgeInsets.all(16.0),
                itemCount: _breakTypes.length,
                itemBuilder: (context, index) {
                  final breakType = _breakTypes[index];
                  final color = _parseColor(breakType['color'] ?? '#6B7280');
                  final isActive = breakType['isActive'] ?? true;

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 8.0),
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: isActive ? color : Colors.grey,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  _getIconData(
                                    breakType['icon'] ?? 'more_horiz',
                                  ),
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            breakType['displayName'] ??
                                                breakType['name'],
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 18,
                                              color: isActive
                                                  ? null
                                                  : Colors.grey,
                                            ),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isActive
                                                ? Colors.green
                                                : Colors.grey,
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: Text(
                                            isActive ? 'Active' : 'Inactive',
                                            style: TextStyle(
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.onPrimary,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.edit,
                                            size: 18,
                                          ),
                                          tooltip: 'Edit',
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          onPressed: () => _showBreakTypeDialog(
                                            breakType: breakType,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      breakType['description'] ?? '',
                                      style: TextStyle(
                                        color: colorScheme.onSurface.withValues(
                                          alpha: 0.7,
                                        ),
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              if (breakType['minDuration'] != null ||
                                  breakType['maxDuration'] != null)
                                _buildInfoChip(
                                  'Duration: ${breakType['minDuration'] ?? 0}-${breakType['maxDuration'] ?? '∞'} min',
                                  Icons.timer,
                                  colorScheme,
                                ),
                              if (breakType['dailyLimit'] != null)
                                _buildInfoChip(
                                  'Daily: ${breakType['dailyLimit']}',
                                  Icons.today,
                                  colorScheme,
                                ),
                              if (breakType['weeklyLimit'] != null)
                                _buildInfoChip(
                                  'Weekly: ${breakType['weeklyLimit']}',
                                  Icons.date_range,
                                  colorScheme,
                                ),
                              if (breakType['requiresApproval'] == true)
                                _buildInfoChip(
                                  'Requires Approval',
                                  Icons.admin_panel_settings,
                                  colorScheme,
                                ),
                              if (breakType['isPaid'] == true)
                                _buildInfoChip(
                                  'Paid',
                                  Icons.attach_money,
                                  colorScheme,
                                ),
                              if (breakType['isPaid'] == false)
                                _buildInfoChip(
                                  'Unpaid',
                                  Icons.money_off,
                                  colorScheme,
                                ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton.icon(
                                onPressed: () => _toggleBreakTypeStatus(
                                  breakType['_id'],
                                  isActive,
                                ),
                                icon: Icon(
                                  isActive
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                  size: 16,
                                ),
                                label: Text(
                                  isActive ? 'Deactivate' : 'Activate',
                                ),
                                style: TextButton.styleFrom(
                                  foregroundColor: isActive
                                      ? Colors.orange
                                      : Colors.green,
                                ),
                              ),
                              const SizedBox(width: 8),
                              TextButton.icon(
                                onPressed: () =>
                                    _showDeleteConfirmation(breakType),
                                icon: const Icon(Icons.delete, size: 16),
                                label: const Text('Delete'),
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.red,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showBreakTypeDialog(),
        tooltip: 'Add Break Type',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildInfoChip(String label, IconData icon, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: colorScheme.onPrimaryContainer),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showBreakTypeDialog({Map<String, dynamic>? breakType}) async {
    final isEdit = breakType != null;
    final formKey = GlobalKey<FormState>();
    String displayName = breakType?['displayName'] ?? '';
    String name = breakType?['name'] ?? '';
    String description = breakType?['description'] ?? '';
    String icon = breakType?['icon'] ?? 'more_horiz';
    String color = breakType?['color'] ?? '#6B7280';
    int? minDuration = breakType?['minDuration'];
    int? maxDuration = breakType?['maxDuration'];
    int? dailyLimit = breakType?['dailyLimit'];
    int? weeklyLimit = breakType?['weeklyLimit'];
    bool isPaid = breakType?['isPaid'] ?? true;
    bool requiresApproval = breakType?['requiresApproval'] ?? false;
    bool isActive = breakType?['isActive'] ?? true;

    String generateName(String displayName) {
      return displayName.trim().toLowerCase().replaceAll(
        RegExp(r'[^a-z0-9]+'),
        '_',
      );
    }

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Container(
                width: MediaQuery.of(context).size.width * 0.9,
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.85,
                ),
                child: Column(
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isEdit ? Icons.edit : Icons.add,
                            color: Colors.white,
                            size: 28,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              isEdit ? 'Edit Break Type' : 'Add New Break Type',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close, color: Colors.white),
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.white.withValues(
                                alpha: 0.2,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Content
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Form(
                          key: formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Basic Information Section
                              _buildSectionHeader(
                                'Basic Information',
                                Icons.info_outline,
                              ),
                              const SizedBox(height: 16),

                              TextFormField(
                                initialValue: displayName,
                                decoration: InputDecoration(
                                  labelText: 'Display Name *',
                                  hintText: 'e.g., Lunch Break, Coffee Break',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  prefixIcon: const Icon(Icons.label),
                                ),
                                validator: (v) => v == null || v.trim().isEmpty
                                    ? 'Display name is required'
                                    : null,
                                onChanged: (v) => setState(() {
                                  displayName = v;
                                  name = generateName(v);
                                }),
                              ),

                              if (isEdit) ...[
                                const SizedBox(height: 16),
                                TextFormField(
                                  initialValue: name,
                                  decoration: InputDecoration(
                                    labelText: 'System Name (auto-generated)',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    prefixIcon: const Icon(Icons.code),
                                    filled: true,
                                    fillColor: Colors.grey[100],
                                  ),
                                  enabled: false,
                                ),
                              ],

                              const SizedBox(height: 16),
                              TextFormField(
                                initialValue: description,
                                decoration: InputDecoration(
                                  labelText: 'Description',
                                  hintText:
                                      'Brief description of this break type',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  prefixIcon: const Icon(Icons.description),
                                ),
                                maxLines: 2,
                                onChanged: (v) =>
                                    setState(() => description = v),
                              ),

                              const SizedBox(height: 24),

                              // Visual Customization Section
                              _buildSectionHeader(
                                'Visual Customization',
                                Icons.palette,
                              ),
                              const SizedBox(height: 16),

                              // Icon Selection
                              const Text(
                                'Choose Icon',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey[300]!),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Wrap(
                                  spacing: 12,
                                  runSpacing: 12,
                                  children:
                                      [
                                        {
                                          'icon': 'restaurant',
                                          'widget': Icons.restaurant,
                                          'label': 'Restaurant',
                                        },
                                        {
                                          'icon': 'local_cafe',
                                          'widget': Icons.local_cafe,
                                          'label': 'Coffee',
                                        },
                                        {
                                          'icon': 'person',
                                          'widget': Icons.person,
                                          'label': 'Personal',
                                        },
                                        {
                                          'icon': 'local_hospital',
                                          'widget': Icons.local_hospital,
                                          'label': 'Medical',
                                        },
                                        {
                                          'icon': 'smoking_rooms',
                                          'widget': Icons.smoking_rooms,
                                          'label': 'Smoking',
                                        },
                                        {
                                          'icon': 'more_horiz',
                                          'widget': Icons.more_horiz,
                                          'label': 'More',
                                        },
                                      ].map((item) {
                                        final selected = icon == item['icon'];
                                        return GestureDetector(
                                          onTap: () => setState(
                                            () => icon = item['icon'] as String,
                                          ),
                                          child: Column(
                                            children: [
                                              Container(
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  border: Border.all(
                                                    color: selected
                                                        ? Theme.of(
                                                            context,
                                                          ).colorScheme.primary
                                                        : Colors.grey[300]!,
                                                    width: selected ? 3 : 2,
                                                  ),
                                                  color: selected
                                                      ? Theme.of(context)
                                                            .colorScheme
                                                            .primary
                                                            .withValues(
                                                              alpha: 0.1,
                                                            )
                                                      : Colors.transparent,
                                                ),
                                                padding: const EdgeInsets.all(
                                                  12,
                                                ),
                                                child: Icon(
                                                  item['widget'] as IconData,
                                                  color: selected
                                                      ? Theme.of(
                                                          context,
                                                        ).colorScheme.primary
                                                      : Colors.grey[600],
                                                  size: 28,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                item['label'] as String,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: selected
                                                      ? Theme.of(
                                                          context,
                                                        ).colorScheme.primary
                                                      : Colors.grey[600],
                                                  fontWeight: selected
                                                      ? FontWeight.w600
                                                      : FontWeight.normal,
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                ),
                              ),

                              const SizedBox(height: 16),

                              // Color Selection
                              const Text(
                                'Choose Color',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey[300]!),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  children: [
                                    Wrap(
                                      spacing: 12,
                                      runSpacing: 12,
                                      children: [
                                        ...[
                                          {'color': '#10B981', 'name': 'Green'},
                                          {
                                            'color': '#F59E42',
                                            'name': 'Orange',
                                          },
                                          {'color': '#3B82F6', 'name': 'Blue'},
                                          {'color': '#EF4444', 'name': 'Red'},
                                          {
                                            'color': '#8B5CF6',
                                            'name': 'Purple',
                                          },
                                          {'color': '#6B7280', 'name': 'Gray'},
                                          {'color': '#F97316', 'name': 'Amber'},
                                          {'color': '#06B6D4', 'name': 'Cyan'},
                                        ].map((c) {
                                          final selected =
                                              color.toLowerCase() ==
                                              c['color']!.toLowerCase();
                                          return GestureDetector(
                                            onTap: () => setState(
                                              () => color = c['color']!,
                                            ),
                                            child: Column(
                                              children: [
                                                Container(
                                                  decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    border: Border.all(
                                                      color: selected
                                                          ? Theme.of(context)
                                                                .colorScheme
                                                                .primary
                                                          : Colors.grey[300]!,
                                                      width: selected ? 3 : 2,
                                                    ),
                                                  ),
                                                  padding: const EdgeInsets.all(
                                                    2,
                                                  ),
                                                  child: Container(
                                                    width: 32,
                                                    height: 32,
                                                    decoration: BoxDecoration(
                                                      color: Color(
                                                        int.parse(
                                                          c['color']!
                                                              .replaceFirst(
                                                                '#',
                                                                '0xFF',
                                                              ),
                                                        ),
                                                      ),
                                                      shape: BoxShape.circle,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  c['name']!,
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: selected
                                                        ? Theme.of(
                                                            context,
                                                          ).colorScheme.primary
                                                        : Colors.grey[600],
                                                    fontWeight: selected
                                                        ? FontWeight.w600
                                                        : FontWeight.normal,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        }),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: TextFormField(
                                            initialValue: color,
                                            decoration: InputDecoration(
                                              labelText: 'Custom Hex Color',
                                              hintText: '#FF9800',
                                              border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              prefixIcon: const Icon(
                                                Icons.color_lens,
                                              ),
                                            ),
                                            onChanged: (v) =>
                                                setState(() => color = v),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Container(
                                          width: 40,
                                          height: 40,
                                          decoration: BoxDecoration(
                                            color: Color(
                                              int.parse(
                                                color.replaceFirst('#', '0xFF'),
                                              ),
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            border: Border.all(
                                              color: Colors.grey[300]!,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 24),

                              // Duration & Limits Section
                              _buildSectionHeader(
                                'Duration & Limits',
                                Icons.timer,
                              ),
                              const SizedBox(height: 16),

                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      initialValue:
                                          minDuration?.toString() ?? '',
                                      decoration: InputDecoration(
                                        labelText: 'Min Duration (min)',
                                        hintText: '5',
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        prefixIcon: const Icon(
                                          Icons.timer_outlined,
                                        ),
                                      ),
                                      keyboardType: TextInputType.number,
                                      onChanged: (v) => setState(
                                        () => minDuration = int.tryParse(v),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: TextFormField(
                                      initialValue:
                                          maxDuration?.toString() ?? '',
                                      decoration: InputDecoration(
                                        labelText: 'Max Duration (min)',
                                        hintText: '30',
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        prefixIcon: const Icon(Icons.timer),
                                      ),
                                      keyboardType: TextInputType.number,
                                      onChanged: (v) => setState(
                                        () => maxDuration = int.tryParse(v),
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 16),

                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      initialValue:
                                          dailyLimit?.toString() ?? '',
                                      decoration: InputDecoration(
                                        labelText: 'Daily Limit',
                                        hintText: '3',
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        prefixIcon: const Icon(Icons.today),
                                      ),
                                      keyboardType: TextInputType.number,
                                      onChanged: (v) => setState(
                                        () => dailyLimit = int.tryParse(v),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: TextFormField(
                                      initialValue:
                                          weeklyLimit?.toString() ?? '',
                                      decoration: InputDecoration(
                                        labelText: 'Weekly Limit',
                                        hintText: '15',
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        prefixIcon: const Icon(
                                          Icons.date_range,
                                        ),
                                      ),
                                      keyboardType: TextInputType.number,
                                      onChanged: (v) => setState(
                                        () => weeklyLimit = int.tryParse(v),
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 24),

                              // Settings Section
                              _buildSectionHeader('Settings', Icons.settings),
                              const SizedBox(height: 16),

                              Container(
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey[300]!),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  children: [
                                    SwitchListTile(
                                      value: isPaid,
                                      onChanged: (v) =>
                                          setState(() => isPaid = v),
                                      title: const Text('Paid Break'),
                                      subtitle: const Text(
                                        'Employee is paid during this break',
                                      ),
                                      secondary: Icon(
                                        isPaid
                                            ? Icons.attach_money
                                            : Icons.money_off,
                                        color: isPaid
                                            ? Colors.green
                                            : Colors.grey,
                                      ),
                                    ),
                                    Divider(height: 1, color: Colors.grey[300]),
                                    SwitchListTile(
                                      value: requiresApproval,
                                      onChanged: (v) =>
                                          setState(() => requiresApproval = v),
                                      title: const Text('Requires Approval'),
                                      subtitle: const Text(
                                        'Manager must approve this break type',
                                      ),
                                      secondary: Icon(
                                        requiresApproval
                                            ? Icons.admin_panel_settings
                                            : Icons.check_circle,
                                        color: requiresApproval
                                            ? Colors.orange
                                            : Colors.grey,
                                      ),
                                    ),
                                    if (isEdit) ...[
                                      Divider(
                                        height: 1,
                                        color: Colors.grey[300],
                                      ),
                                      SwitchListTile(
                                        value: isActive,
                                        onChanged: (v) =>
                                            setState(() => isActive = v),
                                        title: const Text('Active'),
                                        subtitle: const Text(
                                          'This break type is available for use',
                                        ),
                                        secondary: Icon(
                                          isActive
                                              ? Icons.check_circle
                                              : Icons.cancel,
                                          color: isActive
                                              ? Colors.green
                                              : Colors.red,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Footer Actions
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(20),
                          bottomRight: Radius.circular(20),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.of(context).pop(),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'Cancel',
                                style: TextStyle(fontSize: 16),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () async {
                                if (!formKey.currentState!.validate()) return;

                                final body = {
                                  'displayName': displayName.trim(),
                                  'name': generateName(displayName),
                                  'description': description.trim(),
                                  'icon': icon,
                                  'color': color,
                                  'minDuration': minDuration,
                                  'maxDuration': maxDuration,
                                  'dailyLimit': dailyLimit,
                                  'weeklyLimit': weeklyLimit,
                                  'isPaid': isPaid,
                                  'requiresApproval': requiresApproval,
                                  'isActive': isActive,
                                };

                                try {
                                  if (isEdit) {
                                    await _attendanceRepository.updateBreakType(
                                      breakType['_id'],
                                      body,
                                    );
                                  } else {
                                    await _attendanceRepository.createBreakType(
                                      body,
                                    );
                                  }

                                  if (!mounted) return;
                                  Navigator.of(context).pop();
                                  await _fetchBreakTypes(forceRefresh: true);
                                  if (!mounted) return;
                                  GlobalNotificationService().showSuccess(
                                    isEdit
                                        ? 'Break type updated successfully! 🎉'
                                        : 'Break type added successfully! 🎉',
                                  );
                                } catch (e) {
                                  if (!mounted) return;
                                  GlobalNotificationService().showError(
                                    'Error: $e',
                                  );
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Theme.of(
                                  context,
                                ).colorScheme.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                isEdit
                                    ? 'Update Break Type'
                                    : 'Create Break Type',
                                style: const TextStyle(
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
          },
        );
      },
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ],
    );
  }

  Future<void> _showDeleteConfirmation(Map<String, dynamic> breakType) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Confirm Deletion'),
          content: Text(
            'Are you sure you want to delete "${breakType['displayName'] ?? breakType['name']}"? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      try {
        await _attendanceRepository.deleteBreakType(breakType['_id']);

        if (!mounted) return;
        GlobalNotificationService().showSuccess(
          'Break type deleted successfully!',
        );
        await _fetchBreakTypes(forceRefresh: true);
      } catch (e) {
        if (!mounted) return;
        GlobalNotificationService().showError('Error: $e');
      }
    }
  }

  Future<void> _initializeDefaultBreakTypes() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Initialize Default Break Types'),
          content: const Text(
            'This will create default break types (Lunch, Coffee, Personal) for your company. This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              child: const Text('Initialize'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      try {
        await _attendanceRepository.initializeDefaultBreakTypes();

        if (!mounted) return;
        GlobalNotificationService().showSuccess(
          'Default break types initialized successfully!',
        );
        await _fetchBreakTypes(
          forceRefresh: true,
        ); // Re-fetch to show new break types
      } catch (e) {
        if (!mounted) return;
        GlobalNotificationService().showError('Error: $e');
      }
    }
  }
}
