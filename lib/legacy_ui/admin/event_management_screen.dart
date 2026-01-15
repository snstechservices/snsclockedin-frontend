import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/admin_side_navigation.dart';
import '../../providers/feature_provider.dart';
import '../../providers/company_provider.dart';
import '../../utils/time_utils.dart';
import '../../services/global_notification_service.dart';
import '../../core/repository/event_repository.dart';
import '../../services/connectivity_service.dart';
import '../../core/services/hive_service.dart';
import '../../services/api_service.dart';
import '../../config/api_config.dart';

class EventManagementScreen extends StatefulWidget {
  const EventManagementScreen({super.key});

  @override
  State<EventManagementScreen> createState() => _EventManagementScreenState();
}

class _EventManagementScreenState extends State<EventManagementScreen> {
  late final EventRepository _eventRepository;
  List<Map<String, dynamic>> _events = [];
  bool _isLoading = true;
  String? _error;

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
          _error = 'Events feature is not enabled for your account.';
        });
      }
    });
  }

  Future<void> _fetchEvents({bool forceRefresh = false}) async {
    setState(() {
      _isLoading = forceRefresh || _events.isEmpty;
      _error = null;
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
          _error = e.toString();
        }
        _isLoading = false;
      });
    }
  }

  void _showCreateEventDialog() {
    showDialog(
      context: context,
      builder: (context) =>
          CreateEventDialog(eventRepository: _eventRepository),
    ).then((_) => _fetchEvents(forceRefresh: true));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Event Management'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
      ),
      drawer: const AdminSideNavigation(currentRoute: '/event_management'),
      body: RefreshIndicator(
        onRefresh: () => _fetchEvents(forceRefresh: true),
        child: _isLoading && _events.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : _error != null && _events.isEmpty
            ? Center(child: Text('Error: $_error'))
            : _events.isEmpty
            ? const Center(child: Text('No events found'))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _events.length,
                itemBuilder: (context, index) {
                  final event = _events[index];
                  return _buildEventCard(event);
                },
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateEventDialog,
        icon: const Icon(Icons.add),
        label: const Text('Create Event'),
      ),
    );
  }

  Widget _buildEventCard(Map<String, dynamic> event) {
    final startDate = DateTime.parse(event['startDate']);
    final organizer = event['organizer'] as Map<String, dynamic>?;
    final organizerName = organizer != null
        ? '${organizer['firstName'] ?? ''} ${organizer['lastName'] ?? ''}'
              .trim()
        : 'Unknown';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ListTile(
        leading: _getEventIcon(event['type']),
        title: Text(
          event['title'] ?? 'Untitled Event',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(event['description'] ?? 'No description'),
            const SizedBox(height: 4),
            Builder(
              builder: (context) {
                final authProvider = Provider.of<AuthProvider>(
                  context,
                  listen: false,
                );
                final companyProvider = Provider.of<CompanyProvider>(
                  context,
                  listen: false,
                );
                final user = authProvider.user;
                final company = companyProvider.currentCompany?.toJson();
                final formattedDate = TimeUtils.formatReadableDate(
                  startDate,
                  user: user,
                  company: company,
                );
                final formattedTime = TimeUtils.formatTimeOnly(
                  startDate,
                  user: user,
                  company: company,
                );
                return Text(
                  '$formattedDate at $formattedTime',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                );
              },
            ),
            if (event['location'] != null)
              Text(
                '📍 ${event['location']}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            Text(
              'Organized by: $organizerName',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        trailing: _getPriorityChip(event['priority']),
        onTap: () {
          // TODO: Navigate to event details
        },
      ),
    );
  }

  Widget _getEventIcon(String? eventType) {
    switch (eventType) {
      case 'meeting':
        return const Icon(Icons.meeting_room, color: Colors.blue);
      case 'training':
        return const Icon(Icons.school, color: Colors.green);
      case 'holiday':
        return const Icon(Icons.beach_access, color: Colors.orange);
      case 'announcement':
        return const Icon(Icons.announcement, color: Colors.red);
      case 'deadline':
        return const Icon(Icons.schedule, color: Colors.purple);
      case 'celebration':
        return const Icon(Icons.celebration, color: Colors.pink);
      case 'maintenance':
        return const Icon(Icons.build, color: Colors.grey);
      default:
        return const Icon(Icons.event, color: Colors.blue);
    }
  }

  Widget _getPriorityChip(String? priority) {
    Color color;
    String text;

    switch (priority) {
      case 'urgent':
        color = Colors.red;
        text = 'Urgent';
        break;
      case 'high':
        color = Colors.orange;
        text = 'High';
        break;
      case 'medium':
        color = Colors.blue;
        text = 'Medium';
        break;
      case 'low':
        color = Colors.green;
        text = 'Low';
        break;
      default:
        color = Colors.grey;
        text = 'Medium';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class CreateEventDialog extends StatefulWidget {
  final EventRepository eventRepository;

  const CreateEventDialog({super.key, required this.eventRepository});

  @override
  State<CreateEventDialog> createState() => _CreateEventDialogState();
}

class _CreateEventDialogState extends State<CreateEventDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();

  String _selectedType = 'meeting';
  String _selectedPriority = 'medium';
  DateTime _startDate = DateTime.now().add(const Duration(days: 1));
  DateTime _endDate = DateTime.now().add(const Duration(days: 1, hours: 1));
  bool _isLoading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _createEvent() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await widget.eventRepository.createEvent({
        'title': _titleController.text,
        'description': _descriptionController.text,
        'type': _selectedType,
        'startDate': _startDate.toIso8601String(),
        'endDate': _endDate.toIso8601String(),
        'location': _locationController.text,
        'priority': _selectedPriority,
        'isPublic': true,
      });

      if (mounted) {
        Navigator.of(context).pop();
        GlobalNotificationService().showSuccess('Event created successfully!');
      }
    } catch (e) {
      if (mounted) {
        GlobalNotificationService().showError('Error: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create New Event'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Event Title',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter event title';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter description';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _selectedType,
                decoration: const InputDecoration(
                  labelText: 'Event Type',
                  border: OutlineInputBorder(),
                ),
                items:
                    [
                          'meeting',
                          'training',
                          'holiday',
                          'announcement',
                          'deadline',
                          'celebration',
                          'maintenance',
                          'other',
                        ]
                        .map(
                          (type) => DropdownMenuItem(
                            value: type,
                            child: Text(type.toUpperCase()),
                          ),
                        )
                        .toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedType = value!;
                  });
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _locationController,
                decoration: const InputDecoration(
                  labelText: 'Location (Optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _selectedPriority,
                decoration: const InputDecoration(
                  labelText: 'Priority',
                  border: OutlineInputBorder(),
                ),
                items: ['low', 'medium', 'high', 'urgent']
                    .map(
                      (priority) => DropdownMenuItem(
                        value: priority,
                        child: Text(priority.toUpperCase()),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedPriority = value!;
                  });
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ListTile(
                      title: const Text('Start Date'),
                      subtitle: Builder(
                        builder: (context) {
                          final authProvider = Provider.of<AuthProvider>(
                            context,
                            listen: false,
                          );
                          final companyProvider = Provider.of<CompanyProvider>(
                            context,
                            listen: false,
                          );
                          final user = authProvider.user;
                          final company = companyProvider.currentCompany
                              ?.toJson();
                          return Text(
                            TimeUtils.formatReadableDateTime(
                              _startDate,
                              user: user,
                              company: company,
                            ),
                          );
                        },
                      ),
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: _startDate,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(
                            const Duration(days: 365),
                          ),
                        );
                        if (date != null) {
                          setState(() {
                            _startDate = DateTime(
                              date.year,
                              date.month,
                              date.day,
                              _startDate.hour,
                              _startDate.minute,
                            );
                          });
                        }
                      },
                    ),
                  ),
                  Expanded(
                    child: ListTile(
                      title: const Text('End Date'),
                      subtitle: Builder(
                        builder: (context) {
                          final authProvider = Provider.of<AuthProvider>(
                            context,
                            listen: false,
                          );
                          final companyProvider = Provider.of<CompanyProvider>(
                            context,
                            listen: false,
                          );
                          final user = authProvider.user;
                          final company = companyProvider.currentCompany
                              ?.toJson();
                          return Text(
                            TimeUtils.formatReadableDateTime(
                              _endDate,
                              user: user,
                              company: company,
                            ),
                          );
                        },
                      ),
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: _endDate,
                          firstDate: _startDate,
                          lastDate: DateTime.now().add(
                            const Duration(days: 365),
                          ),
                        );
                        if (date != null) {
                          setState(() {
                            _endDate = DateTime(
                              date.year,
                              date.month,
                              date.day,
                              _endDate.hour,
                              _endDate.minute,
                            );
                          });
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _createEvent,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Create'),
        ),
      ],
    );
  }
}
