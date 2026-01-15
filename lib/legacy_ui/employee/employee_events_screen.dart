import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/admin_side_navigation.dart';
import '../../theme/app_theme.dart';
import '../../providers/feature_provider.dart';
import '../../services/global_notification_service.dart';
import '../../core/repository/event_repository.dart';
import '../../services/connectivity_service.dart';
import '../../core/services/hive_service.dart';
import '../../services/api_service.dart';
import '../../config/api_config.dart';

class EmployeeEventsScreen extends StatefulWidget {
  const EmployeeEventsScreen({super.key});

  @override
  State<EmployeeEventsScreen> createState() => _EmployeeEventsScreenState();
}

class _EmployeeEventsScreenState extends State<EmployeeEventsScreen> {
  late final EventRepository _eventRepository;
  List<Map<String, dynamic>> _events = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _filter = 'All'; // All, Upcoming, Past, My Events

  @override
  void initState() {
    super.initState();
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    _eventRepository = EventRepository(
      connectivityService: ConnectivityService(),
      hiveService: HiveService(),
      apiService: ApiService(baseUrl: ApiConfig.baseUrl),
      authProvider: authProvider,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final featureProvider = Provider.of<FeatureProvider>(
        context,
        listen: false,
      );
      if (featureProvider.hasEvents) {
        _fetchEvents();
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Events feature is not enabled for your account.';
        });
      }
    });
  }

  Future<void> _fetchEvents({bool forceRefresh = false}) async {
    setState(() {
      _isLoading = forceRefresh || _events.isEmpty;
      _errorMessage = null;
    });

    try {
      // 1. Load from cache immediately
      if (!forceRefresh) {
        final cached = await _eventRepository.getCachedEvents(
          allowExpired: true,
        );
        if (cached.isNotEmpty) {
          setState(() {
            _events = cached;
            _isLoading = false;
          });
        }
      }

      // 2. Fetch from server
      final events = await _eventRepository.getEvents(
        forceRefresh: forceRefresh,
      );
      setState(() {
        _events = events;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        if (forceRefresh || _events.isEmpty) {
          _errorMessage = e.toString();
        }
        _isLoading = false;
      });
    }
  }

  Future<void> _joinEvent(String eventId) async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.user?['_id'];

      if (userId == null) {
        throw Exception('Authentication required');
      }

      await _eventRepository.registerForEvent(eventId, userId: userId);

      // Refresh events to update attendance status
      await _fetchEvents(forceRefresh: true);
      if (mounted) {
        GlobalNotificationService().showSuccess('Successfully joined event!');
      }
    } catch (e) {
      if (mounted) {
        GlobalNotificationService().showError('Error joining event: $e');
      }
    }
  }

  Future<void> _leaveEvent(String eventId) async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.user?['_id'];

      if (userId == null) {
        throw Exception('Authentication required');
      }

      await _eventRepository.unregisterFromEvent(eventId, userId: userId);

      // Refresh events to update attendance status
      await _fetchEvents(forceRefresh: true);
      if (mounted) {
        GlobalNotificationService().showSuccess('Successfully left event!');
      }
    } catch (e) {
      if (mounted) {
        GlobalNotificationService().showError('Error leaving event: $e');
      }
    }
  }

  List<Map<String, dynamic>> _getFilteredEvents() {
    final now = DateTime.now();
    final userId = Provider.of<AuthProvider>(
      context,
      listen: false,
    ).user?['_id'];

    switch (_filter) {
      case 'Upcoming':
        return _events.where((event) {
          final eventDate = DateTime.parse(event['startDate'] ?? '');
          return eventDate.isAfter(now);
        }).toList();
      case 'Past':
        return _events.where((event) {
          final eventDate = DateTime.parse(event['startDate'] ?? '');
          return eventDate.isBefore(now);
        }).toList();
      case 'Active':
        return _events.where((event) {
          final eventDate = DateTime.parse(event['startDate'] ?? '');
          return eventDate.isBefore(now) || eventDate.isAtSameMomentAs(now);
        }).toList();
      case 'My Events':
        return _events.where((event) {
          final attendees = List<Map<String, dynamic>>.from(
            event['attendees'] ?? [],
          );
          return attendees.any((attendee) => attendee['user'] == userId);
        }).toList();
      default:
        return _events;
    }
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    final isUpcoming = _filter == 'Upcoming';
    final isPast = _filter == 'Past';
    final isMyEvents = _filter == 'My Events';

    String title;
    String subtitle;
    IconData icon;
    Color iconColor;

    if (isUpcoming) {
      title = 'No Upcoming Events';
      subtitle =
          'There are no upcoming events scheduled at the moment. Check back later for new events!';
      icon = Icons.event_busy;
      iconColor = AppTheme.warning;
    } else if (isPast) {
      title = 'No Past Events';
      subtitle = 'There are no past events to display.';
      icon = Icons.history;
      iconColor = AppTheme.muted;
    } else if (isMyEvents) {
      title = 'No Events Joined';
      subtitle =
          'You haven\'t joined any events yet. Browse available events and join the ones that interest you!';
      icon = Icons.person_off;
      iconColor = AppTheme.primary;
    } else {
      title = 'No Events Available';
      subtitle =
          'There are currently no events scheduled. Events will appear here once they are created by administrators.';
      icon = Icons.event_note;
      iconColor = theme.colorScheme.primary;
    }

    return Center(
      child: Padding(
        padding: EdgeInsets.all(AppTheme.spacingXl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Large icon with background
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 60, color: iconColor),
            ),
            SizedBox(height: AppTheme.spacingL),

            // Title
            Text(
              title,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: AppTheme.spacingM),

            // Subtitle
            Text(
              subtitle,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: AppTheme.spacingXl),

            // Action buttons
            if (_filter != 'All') ...[
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _filter = 'All';
                  });
                },
                icon: const Icon(Icons.list),
                label: const Text('View All Events'),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppTheme.spacingL,
                    vertical: AppTheme.spacingM,
                  ),
                ),
              ),
              SizedBox(height: AppTheme.spacingL),
            ],

            // Refresh button
            OutlinedButton.icon(
              onPressed: () => _fetchEvents(forceRefresh: true),
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingL,
                  vertical: AppTheme.spacingM,
                ),
              ),
            ),

            // Additional info for different filters
            SizedBox(height: AppTheme.spacingL),
            Container(
              padding: EdgeInsets.all(AppTheme.spacingL),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.3,
                ),
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                border: Border.all(
                  color: theme.colorScheme.outline.withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 20,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  SizedBox(height: AppTheme.spacingS),
                  Text(
                    _getFilterInfoText(),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getFilterInfoText() {
    switch (_filter) {
      case 'Upcoming':
        return 'Upcoming events are those scheduled for future dates.';
      case 'Past':
        return 'Past events are those that have already occurred.';
      case 'My Events':
        return 'My Events shows events you have joined or are attending.';
      case 'Active':
        return 'Active events are currently ongoing or have started.';
      default:
        return 'All events from your organization will be displayed here.';
    }
  }

  Widget _buildLoadingState() {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Animated loading icon
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const CircularProgressIndicator(strokeWidth: 3),
          ),
          SizedBox(height: AppTheme.spacingL),

          // Loading text
          Text(
            'Loading Events...',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurface,
            ),
          ),
          SizedBox(height: AppTheme.spacingS),

          Text(
            'Please wait while we fetch your events',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: EdgeInsets.all(AppTheme.spacingXl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Error icon
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppTheme.error.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.error_outline, size: 50, color: AppTheme.error),
            ),
            SizedBox(height: AppTheme.spacingL),

            // Error title
            Text(
              'Failed to Load Events',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: AppTheme.spacingM),

            // Error message
            Text(
              _errorMessage ?? 'An unknown error occurred',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: AppTheme.spacingXl),

            // Retry button
            ElevatedButton.icon(
              onPressed: () => _fetchEvents(forceRefresh: true),
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingL,
                  vertical: AppTheme.spacingM,
                ),
              ),
            ),

            SizedBox(height: AppTheme.spacingL),

            // Alternative action
            OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  _errorMessage = null;
                  _isLoading = true;
                });
                _fetchEvents(forceRefresh: true);
              },
              icon: const Icon(Icons.settings),
              label: const Text('Check Connection'),
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingL,
                  vertical: AppTheme.spacingM,
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
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Not logged in. Please log in.')),
      );
    }
    final isAdmin = user['role'] == 'admin';
    if (isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Events')),
        body: const Center(child: Text('Access denied')),
        drawer: const AdminSideNavigation(currentRoute: '/events'),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Events'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _fetchEvents(forceRefresh: true),
          ),
        ],
      ),
      drawer: const AppDrawer(),
      body: Column(
        children: [
          // Filter section
          Container(
            padding: EdgeInsets.all(AppTheme.spacingL),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(
                    context,
                  ).colorScheme.outline.withValues(alpha: 0.1),
                  width: 1,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.filter_list,
                      size: 20,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    SizedBox(width: AppTheme.spacingS),
                    Text(
                      'Filter Events',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: AppTheme.spacingM),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppTheme.spacingM,
                    vertical: AppTheme.spacingXs,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Theme.of(
                        context,
                      ).colorScheme.outline.withValues(alpha: 0.3),
                    ),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                  ),
                  child: DropdownButton<String>(
                    value: _filter,
                    underline: const SizedBox.shrink(),
                    icon: Icon(
                      Icons.keyboard_arrow_down,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    items:
                        [
                              {
                                'value': 'All',
                                'label': 'All Events',
                                'icon': Icons.list,
                              },
                              {
                                'value': 'Upcoming',
                                'label': 'Upcoming',
                                'icon': Icons.event,
                              },
                              {
                                'value': 'Active',
                                'label': 'Active Now',
                                'icon': Icons.play_circle,
                              },
                              {
                                'value': 'Past',
                                'label': 'Past Events',
                                'icon': Icons.history,
                              },
                              {
                                'value': 'My Events',
                                'label': 'My Events',
                                'icon': Icons.person,
                              },
                            ]
                            .map(
                              (item) => DropdownMenuItem(
                                value: item['value'] as String,
                                child: Row(
                                  children: [
                                    Icon(
                                      item['icon'] as IconData,
                                      size: 18,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    ),
                                    SizedBox(width: AppTheme.spacingS),
                                    Text(item['label'] as String),
                                  ],
                                ),
                              ),
                            )
                            .toList(),
                    onChanged: (value) {
                      setState(() {
                        _filter = value!;
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
          // Events list
          Expanded(
            child: _isLoading
                ? _buildLoadingState()
                : _errorMessage != null
                ? _buildErrorState()
                : _getFilteredEvents().isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
                    onRefresh: () => _fetchEvents(forceRefresh: true),
                    child: ListView.builder(
                      padding: EdgeInsets.all(AppTheme.spacingL),
                      itemCount: _getFilteredEvents().length,
                      itemBuilder: (context, index) {
                        final event = _getFilteredEvents()[index];
                        return _EventCard(
                          event: event,
                          onJoin: () => _joinEvent(event['_id']),
                          onLeave: () => _leaveEvent(event['_id']),
                          currentUserId: authProvider.user?['_id'],
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  final Map<String, dynamic> event;
  final VoidCallback onJoin;
  final VoidCallback onLeave;
  final String? currentUserId;

  const _EventCard({
    required this.event,
    required this.onJoin,
    required this.onLeave,
    required this.currentUserId,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final eventDate = DateTime.parse(event['startDate'] ?? '');
    final now = DateTime.now();
    final isUpcoming = eventDate.isAfter(now);
    final isStarted =
        eventDate.isBefore(now) || eventDate.isAtSameMomentAs(now);
    final canJoin = isStarted && !isUpcoming; // Can join when event has started
    final attendees = List<Map<String, dynamic>>.from(event['attendees'] ?? []);
    final isAttending = attendees.any(
      (attendee) => attendee['user'] == currentUserId,
    );
    final isPublic = event['isPublic'] ?? false;

    // Debug logging
    //
    //     'Event debug: ${event['title']} - isUpcoming: $isUpcoming, isStarted: $isStarted, canJoin: $canJoin, isPublic: $isPublic, createdBy: $createdBy, currentUserId: $currentUserId, isAttending: $isAttending');

    return Card(
      margin: EdgeInsets.only(bottom: AppTheme.spacingL),
      elevation: AppTheme.elevationMedium,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        side: BorderSide(
          color: theme.colorScheme.outline.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(AppTheme.spacingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event['title'] ?? 'Untitled Event',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: AppTheme.spacingXs),
                      Text(
                        event['description'] ?? 'No description',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppTheme.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isPublic)
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppTheme.spacingS,
                      vertical: AppTheme.spacingXs,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.success.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(
                        AppTheme.radiusMedium,
                      ),
                    ),
                    child: Text(
                      'Public',
                      style: TextStyle(
                        color: AppTheme.success,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(height: AppTheme.spacingM),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 16, color: AppTheme.muted),
                SizedBox(width: AppTheme.spacingS),
                Text(
                  DateFormat('MMM dd, yyyy').format(eventDate),
                  style: theme.textTheme.bodyMedium,
                ),
                SizedBox(width: AppTheme.spacingL),
                Icon(Icons.access_time, size: 16, color: AppTheme.muted),
                SizedBox(width: AppTheme.spacingS),
                Text(
                  DateFormat('HH:mm').format(eventDate),
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
            if (event['location'] != null) ...[
              SizedBox(height: AppTheme.spacingS),
              Row(
                children: [
                  Icon(Icons.location_on, size: 16, color: AppTheme.muted),
                  SizedBox(width: AppTheme.spacingS),
                  Text(event['location'], style: theme.textTheme.bodyMedium),
                ],
              ),
            ],
            SizedBox(height: AppTheme.spacingM),
            Row(
              children: [
                Icon(Icons.people, size: 16, color: AppTheme.muted),
                SizedBox(width: AppTheme.spacingS),
                Text(
                  '${attendees.length} attending',
                  style: theme.textTheme.bodyMedium,
                ),
                const Spacer(),
                if (canJoin)
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: isAttending ? onLeave : onJoin,
                      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: AppTheme.spacingL,
                          vertical: AppTheme.spacingS,
                        ),
                        decoration: BoxDecoration(
                          color: isAttending
                              ? AppTheme.error
                              : theme.colorScheme.primary,
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusSmall,
                          ),
                        ),
                        child: Text(
                          isAttending ? 'Leave' : 'Join',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  )
                else if (isUpcoming)
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppTheme.spacingM,
                      vertical: AppTheme.spacingS,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.warning.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                      border: Border.all(
                        color: AppTheme.warning.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.schedule, size: 14, color: AppTheme.warning),
                        SizedBox(width: AppTheme.spacingXs),
                        Text(
                          'Upcoming',
                          style: TextStyle(
                            color: AppTheme.warning,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
