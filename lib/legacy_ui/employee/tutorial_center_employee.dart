import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/feature_provider.dart';
import '../../tutorial/tutorial_service.dart';
import '../../widgets/app_drawer.dart';

class TutorialCenterEmployeeScreen extends StatefulWidget {
  const TutorialCenterEmployeeScreen({super.key});

  @override
  State<TutorialCenterEmployeeScreen> createState() =>
      _TutorialCenterEmployeeScreenState();
}

class _TutorialCenterEmployeeScreenState
    extends State<TutorialCenterEmployeeScreen> {
  final Map<String, String> _tutorials = const {
    'employee_dashboard_coach_seen_v1': 'Employee Dashboard',
  };

  final Map<String, String> _routes = const {
    'employee_dashboard_coach_seen_v1': '/employee_dashboard',
  };

  late Future<Map<String, bool>> _statusFuture;

  @override
  void initState() {
    super.initState();
    _statusFuture = _loadStatus();
  }

  Future<Map<String, bool>> _loadStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final auth = context.read<AuthProvider>();
    final String? userId = auth.user?['_id'] as String?;

    final map = <String, bool>{};
    for (final k in _tutorials.keys) {
      final key = TutorialService.userScopedKey(k, userId);
      map[k] = prefs.getBool(key) ?? false;
    }
    return map;
  }

  Future<void> _reset(String key) async {
    final auth = context.read<AuthProvider>();
    final String? userId = auth.user?['_id'] as String?;
    final userScopedKey = TutorialService.userScopedKey(key, userId);

    await TutorialService.setSeen(userScopedKey, seen: false);
    setState(() {
      _statusFuture = _loadStatus();
    });
  }

  Future<void> _resetAll() async {
    await TutorialService.resetAll();
    setState(() {
      _statusFuture = _loadStatus();
    });
  }

  // Check if tutorial center is accessible
  bool isTutorialCenterAccessible(BuildContext context) {
    final featureProvider = Provider.of<FeatureProvider>(
      context,
      listen: false,
    );
    return featureProvider.hasTutorialCenter;
  }

  // Build subscription required view
  Widget _buildSubscriptionRequiredView(
    BuildContext context,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline, size: 80, color: colorScheme.primary),
            const SizedBox(height: 24),
            Text(
              'Tutorial Center',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'This feature requires a premium subscription plan.',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'To access comprehensive tutorials and learning resources, please contact your administrator to upgrade your company\'s subscription.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Go Back'),
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Consumer<FeatureProvider>(
      builder: (context, featureProvider, child) {
        // Check if tutorial center feature is enabled
        if (!featureProvider.hasTutorialCenter) {
          return Scaffold(
            appBar: AppBar(
              leading: Builder(
                builder: (context) => IconButton(
                  icon: const Icon(Icons.menu),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                  tooltip: 'Menu',
                ),
              ),
              title: const Text('Tutorial Center'),
              backgroundColor: cs.primary,
              foregroundColor: cs.onPrimary,
            ),
            drawer: const AppDrawer(),
            body: _buildSubscriptionRequiredView(context, theme, cs),
          );
        }

        return Scaffold(
          appBar: AppBar(
            leading: Builder(
              builder: (context) => IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () => Scaffold.of(context).openDrawer(),
                tooltip: 'Menu',
              ),
            ),
            title: const Text('Tutorial Center'),
            backgroundColor: cs.primary,
            foregroundColor: cs.onPrimary,
          ),
          drawer: const AppDrawer(),
          body: FutureBuilder<Map<String, bool>>(
            future: _statusFuture,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final status = snapshot.data!;
              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _resetAll,
                      icon: const Icon(Icons.restart_alt),
                      label: const Text('Reset All'),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView(
                        children: _tutorials.entries.map((entry) {
                          final seen = status[entry.key] ?? false;
                          return Card(
                            child: ListTile(
                              title: Text(entry.value),
                              subtitle: Text(
                                seen ? 'Completed' : 'Not shown yet',
                              ),
                              trailing: Wrap(
                                spacing: 8,
                                children: [
                                  OutlinedButton(
                                    onPressed: () => Navigator.of(
                                      context,
                                    ).pushNamed(_routes[entry.key]!),
                                    child: const Text('Run'),
                                  ),
                                  OutlinedButton(
                                    onPressed: () => _reset(entry.key),
                                    child: const Text('Reset'),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}
