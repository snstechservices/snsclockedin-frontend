import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sns_rooster/providers/auth_provider.dart';
import 'package:sns_rooster/providers/feature_provider.dart';
import 'package:sns_rooster/services/api_service.dart';
import 'package:sns_rooster/config/api_config.dart';
import 'package:sns_rooster/widgets/admin_side_navigation.dart';
import 'package:sns_rooster/widgets/google_maps_location_widget.dart';
import 'package:sns_rooster/widgets/web_google_maps_widget.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sns_rooster/utils/logger.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:shimmer/shimmer.dart';
import 'package:sns_rooster/widgets/company_style_location_picker.dart';
import 'package:sns_rooster/widgets/employee_assignment_dialog.dart';
import 'package:sns_rooster/services/location_settings_service.dart';
import 'package:sns_rooster/services/global_notification_service.dart';

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';

class LocationManagementScreen extends StatefulWidget {
  const LocationManagementScreen({super.key});

  @override
  State<LocationManagementScreen> createState() =>
      _LocationManagementScreenState();
}

class _LocationManagementScreenState extends State<LocationManagementScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _streetController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _postalCodeController = TextEditingController();
  final _countryController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _capacityController = TextEditingController(text: '50');
  final _gracePeriodController = TextEditingController(text: '15');
  final _timezoneController = TextEditingController(text: 'UTC');
  final _startTimeController = TextEditingController(text: '09:00');
  final _endTimeController = TextEditingController(text: '17:00');
  final _descriptionController = TextEditingController();
  final _latController = TextEditingController();
  final _lngController = TextEditingController();
  final _searchController = TextEditingController();

  List<Map<String, dynamic>> _locations = [];
  List<Map<String, dynamic>> _filteredLocations = [];
  bool _isLoading = false;
  bool _isCreating = false;
  Map<String, dynamic>? _editingLocation;

  // Location related variables
  double? _selectedLatitude;
  double? _selectedLongitude;
  double _geofenceRadius = 100.0;
  bool _isLoadingLocation = false;
  bool _isSearching = false;
  bool _showSearchResults = false;
  List<Placemark> _searchResults = [];
  bool _useCustomCoordinates = false;
  bool _showCreateForm = false;
  final LocationSettingsService _locationSettingsService =
      LocationSettingsService();

  // Settings state variables
  int _defaultGeofenceRadius = 100;
  String _defaultStartTime = '09:00';
  String _defaultEndTime = '17:00';
  int _defaultCapacity = 50;
  bool _locationUpdatesEnabled = true;
  bool _employeeAssignmentsEnabled = true;
  bool _capacityAlertsEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadLocations();
    _getCurrentLocation();
    _loadLocationSettings();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _streetController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _postalCodeController.dispose();
    _countryController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _capacityController.dispose();
    _gracePeriodController.dispose();
    _timezoneController.dispose();
    _startTimeController.dispose();
    _endTimeController.dispose();
    _descriptionController.dispose();
    _latController.dispose();
    _lngController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoadingLocation = true;
    });

    try {
      // Skip location service on web for now
      if (kIsWeb) {
        // Set default coordinates for web testing
        setState(() {
          _selectedLatitude = -33.8688; // Sydney coordinates
          _selectedLongitude = 151.2093;
          _isLoadingLocation = false;
        });
        // Auto-fill coordinate fields and attempt reverse geocoding
        _latController.text = _selectedLatitude!.toStringAsFixed(6);
        _lngController.text = _selectedLongitude!.toStringAsFixed(6);
        await _getAddressFromCoordinates();
        return;
      }

      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _setDefaultLocation();
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _setDefaultLocation();
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _setDefaultLocation();
        return;
      }

      Position position =
          await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
            timeLimit: const Duration(seconds: 10),
          ).timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              throw Exception('Location request timed out');
            },
          );

      setState(() {
        _selectedLatitude = position.latitude;
        _selectedLongitude = position.longitude;
        _isLoadingLocation = false;
      });
      // Auto-fill coordinate fields and attempt reverse geocoding
      _latController.text = position.latitude.toStringAsFixed(6);
      _lngController.text = position.longitude.toStringAsFixed(6);
      await _getAddressFromCoordinates();
    } catch (e) {
      _setDefaultLocation();
      if (mounted) {
        GlobalNotificationService().showError(
          'Could not get current location: ${e.toString()}',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingLocation = false;
        });
      }
    }
  }

  void _setDefaultLocation() {
    setState(() {
      _selectedLatitude = -33.8688; // Sydney coordinates
      _selectedLongitude = 151.2093;
      _isLoadingLocation = false;
    });
  }

  Future<void> _loadLocations() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final apiService = ApiService(baseUrl: ApiConfig.baseUrl);

      // Debug: Check if we have authentication
      final authHeader = await apiService.getAuthorizationHeader();
      Logger.info('Auth header: $authHeader');
      Logger.info('API Base URL: ${ApiConfig.baseUrl}');

      // Check if user is authenticated
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      Logger.info('User authenticated: ${authProvider.isAuthenticated}');
      Logger.info('User role: ${authProvider.user?['role']}');
      Logger.info('User company ID: ${authProvider.user?['companyId']}');

      final response = await apiService.get('/locations');

      if (response.success) {
        if (!mounted) return;
        setState(() {
          _locations = List<Map<String, dynamic>>.from(
            response.data['locations'] ?? [],
          );
          _filteredLocations = _locations; // Initialize filtered list
        });
        Logger.info('Successfully loaded ${_locations.length} locations');
      } else {
        Logger.error('Failed to load locations: ${response.message}');
        if (!mounted) return;
        final scaffoldMessenger = ScaffoldMessenger.of(context);
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text(response.message)),
        );

        // Set empty list to show the empty state
        setState(() {
          _locations = [];
          _filteredLocations = [];
        });
      }
    } catch (e) {
      Logger.error('Error loading locations: $e');
      if (!mounted) return;
      final scaffoldMessenger = ScaffoldMessenger.of(context);
      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('Error loading locations')),
      );

      // Set empty list to show the empty state
      setState(() {
        _locations = [];
        _filteredLocations = [];
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedLatitude == null || _selectedLongitude == null) {
      GlobalNotificationService().showWarning(
        'Please set location coordinates',
      );
      return;
    }

    setState(() {
      _isCreating = true;
    });

    try {
      final apiService = ApiService(baseUrl: ApiConfig.baseUrl);

      // Get the current user ID for createdBy field
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final currentUserId =
          authProvider.user?['_id'] ?? authProvider.user?['id'];

      // Debug logging
      Logger.info('Current user ID: $currentUserId');
      Logger.info('User authenticated: ${authProvider.isAuthenticated}');
      Logger.info('User data: ${authProvider.user}');

      // Check if we have a valid user ID
      if (currentUserId == null) {
        Logger.error('No valid user ID found for createdBy field');
        GlobalNotificationService().showError(
          'Authentication error. Please log in again.',
        );
        return;
      }

      final locationData = {
        'name': _nameController.text.trim(),
        'address': {
          'street': _streetController.text.trim(),
          'city': _cityController.text.trim(),
          'state': _stateController.text.trim(),
          'postalCode': _postalCodeController.text.trim(),
          'country': _countryController.text.trim(),
        },
        'coordinates': {
          'latitude': _selectedLatitude,
          'longitude': _selectedLongitude,
        },
        'contactInfo': {
          'phone': _phoneController.text.trim(),
          'email': _emailController.text.trim(),
        },
        'settings': {
          'capacity': int.tryParse(_capacityController.text) ?? 50,
          'geofenceRadius': _geofenceRadius,
          'gracePeriod': int.tryParse(_gracePeriodController.text) ?? 15,
          'timezone': _timezoneController.text.trim(),
          'workingHours': {
            'start': _startTimeController.text.trim(),
            'end': _endTimeController.text.trim(),
          },
        },
        'description': _descriptionController.text.trim(),
        'createdBy': currentUserId, // Add the createdBy field
      };

      // Debug logging for location data
      Logger.info('Location data being sent: $locationData');

      ApiResponse response;

      if (_editingLocation != null) {
        // Update existing location
        response = await apiService.put(
          '/locations/${_editingLocation!['_id']}',
          locationData,
        );
        Logger.info('Update response success: ${response.success}');
        Logger.info('Update response message: ${response.message}');
      } else {
        // Create new location
        response = await apiService.post('/locations', locationData);
        Logger.info('Create response success: ${response.success}');
        Logger.info('Create response message: ${response.message}');
      }

      // Debug logging for response
      Logger.info('Server response data: ${response.data}');

      if (response.success) {
        final message = _editingLocation != null
            ? 'Location updated successfully!'
            : 'Location created successfully!';
        GlobalNotificationService().showSuccess(message);
        _hideCreateForm();
        _loadLocations();
      } else {
        final action = _editingLocation != null ? 'updating' : 'creating';
        Logger.error('Location $action failed: ${response.message}');
        GlobalNotificationService().showError(response.message);
      }
    } catch (e) {
      final action = _editingLocation != null ? 'updating' : 'creating';
      Logger.error('Error $action location: $e');
      GlobalNotificationService().showError('Error $action location');
    } finally {
      setState(() {
        _isCreating = false;
      });
    }
  }

  void _showInteractiveMapPicker() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CompanyStyleLocationPicker(
          initialLatitude: _selectedLatitude,
          initialLongitude: _selectedLongitude,
          initialRadius: _geofenceRadius,
          onLocationSelected: (latitude, longitude, radius) {
            setState(() {
              _selectedLatitude = latitude;
              _selectedLongitude = longitude;
              _geofenceRadius = radius;
            });

            // Auto-fill coordinates
            _latController.text = latitude.toStringAsFixed(6);
            _lngController.text = longitude.toStringAsFixed(6);

            // Get address from coordinates
            _getAddressFromCoordinates();
          },
        ),
      ),
    );
  }

  // Location selection methods integrated into the form

  Future<void> _searchLocation(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _showSearchResults = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _showSearchResults = true;
    });

    try {
      List<Location> locations = await locationFromAddress(query);
      List<Placemark> placemarks = [];

      for (Location location in locations.take(5)) {
        List<Placemark> results = await placemarkFromCoordinates(
          location.latitude,
          location.longitude,
        );
        if (results.isNotEmpty) {
          placemarks.add(results.first);
        }
      }

      setState(() {
        _searchResults = placemarks;
      });
    } catch (e) {
      setState(() {
        _searchResults = [];
      });
    } finally {
      setState(() {
        _isSearching = false;
      });
    }
  }

  void _selectSearchResult(Placemark placemark) async {
    try {
      List<Location> locations = await locationFromAddress(
        [
          placemark.street,
          placemark.locality,
          placemark.administrativeArea,
        ].where((part) => part != null && part.isNotEmpty).join(', '),
      );

      if (locations.isNotEmpty) {
        setState(() {
          _selectedLatitude = locations.first.latitude;
          _selectedLongitude = locations.first.longitude;
          _showSearchResults = false;
          _searchController.clear();
        });

        // Auto-fill address fields
        _streetController.text = placemark.street ?? '';
        _cityController.text = placemark.locality ?? '';
        _stateController.text = placemark.administrativeArea ?? '';
        _postalCodeController.text = placemark.postalCode ?? '';
        _countryController.text = placemark.country ?? '';

        _getAddressFromCoordinates();
      }
    } catch (e) {
      if (mounted) {
        GlobalNotificationService().showError(
          'Could not get coordinates for this location',
        );
      }
    }
  }

  void _onCoordinatesChanged() {
    try {
      final lat = double.tryParse(_latController.text);
      final lng = double.tryParse(_lngController.text);

      if (lat != null &&
          lng != null &&
          lat >= -90 &&
          lat <= 90 &&
          lng >= -180 &&
          lng <= 180) {
        setState(() {
          _selectedLatitude = lat;
          _selectedLongitude = lng;
        });
        _getAddressFromCoordinates();
      }
    } catch (e) {
      // Handle invalid coordinates silently
    }
  }

  Future<void> _getAddressFromCoordinates() async {
    if (_selectedLatitude == null || _selectedLongitude == null) return;

    try {
      List<Placemark> placemarks =
          await placemarkFromCoordinates(
            _selectedLatitude!,
            _selectedLongitude!,
          ).timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw Exception('Address lookup timed out');
            },
          );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        // Auto-fill address fields if they're empty
        if (_streetController.text.isEmpty) {
          _streetController.text = place.street ?? '';
        }
        if (_cityController.text.isEmpty) {
          _cityController.text = place.locality ?? '';
        }
        if (_stateController.text.isEmpty) {
          _stateController.text = place.administrativeArea ?? '';
        }
        if (_postalCodeController.text.isEmpty) {
          _postalCodeController.text = place.postalCode ?? '';
        }
        if (_countryController.text.isEmpty) {
          _countryController.text = place.country ?? '';
        }
      }
    } catch (e) {
      // Handle error silently
    }
  }

  Widget _buildMethodCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
    bool isLoading = false,
    bool isSelected = false,
    required Color color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.1)
              : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade200,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    icon,
                    color: isSelected ? color : Colors.grey[600],
                    size: 24,
                  ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isSelected ? color : Colors.black87,
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final featureProvider = Provider.of<FeatureProvider>(context);

    // Check if multi-location feature is available
    if (!featureProvider.isFeatureEnabled('multiLocation')) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Location Management'),
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
        ),
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.blue.shade50, Colors.white],
            ),
          ),
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.location_off, size: 80, color: Colors.blue),
                SizedBox(height: 16),
                Text(
                  'Multi-Location Support',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'This feature is available in Professional and Enterprise plans',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
                SizedBox(height: 16),
                Text(
                  'Upgrade your plan to access location management features',
                  style: TextStyle(fontSize: 14, color: Colors.blue),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Location Management',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadLocations,
          ),
        ],
      ),
      drawer: const AdminSideNavigation(currentRoute: '/location_management'),
      body: RefreshIndicator(
        onRefresh: _loadLocations,
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Header Section
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue, Colors.blue.shade700],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.location_on,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Manage Your Locations',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Create and manage locations for attendance tracking',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.white.withValues(alpha: 0.9),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Consumer<FeatureProvider>(
                                builder: (context, featureProvider, child) {
                                  return Text(
                                    'Plan: ${featureProvider.subscriptionPlanName}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white.withValues(
                                        alpha: 0.8,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        _buildStatCard(
                          icon: Icons.location_on,
                          title: 'Total Locations',
                          value: '${_locations.length}',
                          color: Colors.white.withValues(alpha: 0.15),
                          iconColor: Colors.white,
                          textColor: Colors.white,
                        ),
                        const SizedBox(width: 12),
                        _buildStatCard(
                          icon: Icons.check_circle,
                          title: 'Active Locations',
                          value:
                              '${_locations.where((l) => l['status'] == 'active').length}',
                          color: Colors.white.withValues(alpha: 0.15),
                          iconColor: Colors.white,
                          textColor: Colors.white,
                        ),
                        const SizedBox(width: 12),
                        _buildStatCard(
                          icon: Icons.people,
                          title: 'Total Capacity',
                          value:
                              '${_locations.fold<int>(0, (sum, l) => sum + (int.tryParse(l['settings']?['capacity']?.toString() ?? '0') ?? 0))}',
                          color: Colors.white.withValues(alpha: 0.15),
                          iconColor: Colors.white,
                          textColor: Colors.white,
                        ),
                        const SizedBox(width: 12),
                        _buildStatCard(
                          icon: Icons.person,
                          title: 'Active Users',
                          value:
                              '${_locations.fold<int>(0, (sum, l) => sum + (int.tryParse(l['activeUsers']?.toString() ?? '0') ?? 0))}',
                          color: Colors.white.withValues(alpha: 0.15),
                          iconColor: Colors.white,
                          textColor: Colors.white,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Action Bar
              Container(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // Search Bar
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search locations...',
                          prefixIcon: const Icon(
                            Icons.search,
                            color: Colors.grey,
                          ),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(
                                    Icons.clear,
                                    color: Colors.grey,
                                  ),
                                  onPressed: () {
                                    _searchController.clear();
                                    _filterLocations();
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        onChanged: (value) => _filterLocations(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Action Buttons
                    Row(
                      children: [
                        // Primary Action Button
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            onPressed: _showCreateLocationForm,
                            icon: const Icon(Icons.add_location),
                            label: const Text(
                              'Create Location',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 2,
                              shadowColor: Colors.blue.withValues(alpha: 0.3),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Actions Menu Button
                        if (_locations.isNotEmpty)
                          Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: IconButton(
                              onPressed: () {
                                _showActionsMenu(context);
                              },
                              icon: const Icon(Icons.more_vert),
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.white,
                                padding: const EdgeInsets.all(16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              // Create Form or Locations List
              Consumer<FeatureProvider>(
                builder: (context, featureProvider, child) {
                  Logger.debug('🔍 DEBUG: Building Consumer widget');
                  Logger.debug(
                    '🔍 DEBUG: hasLocationManagement: ${featureProvider.hasLocationManagement}',
                  );
                  Logger.debug('🔍 DEBUG: _showCreateForm: $_showCreateForm');
                  Logger.debug('🔍 DEBUG: _isLoading: $_isLoading');
                  Logger.debug(
                    '🔍 DEBUG: _filteredLocations.isEmpty: ${_filteredLocations.isEmpty}',
                  );

                  if (!featureProvider.hasLocationManagement) {
                    Logger.debug('🔍 DEBUG: Showing feature unavailable state');
                    return _buildFeatureUnavailableState();
                  }

                  if (_showCreateForm) {
                    Logger.debug('🔍 DEBUG: Showing create form');
                    return _buildCreateForm();
                  } else if (_isLoading) {
                    Logger.debug('🔍 DEBUG: Showing loading shimmer');
                    return _buildLoadingShimmer();
                  } else if (_filteredLocations.isEmpty) {
                    Logger.debug('🔍 DEBUG: Showing empty state');
                    return _buildEmptyState();
                  } else {
                    Logger.debug('🔍 DEBUG: Showing locations list');
                    return _buildLocationsList();
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
    Color? iconColor,
    Color? textColor,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: iconColor ?? Colors.blue, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: textColor ?? Colors.black87,
              ),
            ),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: iconColor ?? Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingShimmer() {
    return Column(
      children: List.generate(3, (index) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Shimmer.fromColors(
            baseColor: Colors.grey.shade300,
            highlightColor: Colors.grey.shade100,
            child: Container(
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.location_off, size: 80, color: Colors.blue),
          ),
          const SizedBox(height: 24),
          const Text(
            'No Locations Found',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create your first location to get started with attendance tracking',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _showCreateLocationForm,
            icon: const Icon(Icons.add_location),
            label: const Text('Create First Location'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureUnavailableState() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.lock, size: 80, color: Colors.orange),
          ),
          const SizedBox(height: 24),
          const Text(
            'Location Management Unavailable',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Location management features are not available in your current subscription plan.',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Column(
              children: [
                const Text(
                  'Available Plans:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 12),
                const Text('• Professional: Basic location management'),
                const Text('• Enterprise: Advanced location features'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    _showUpgradeDialog('Location Management');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Learn More'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationsList() {
    // Sanitize location data before passing to map widgets
    final sanitizedLocations = _filteredLocations
        .map((location) => _sanitizeLocationData(location))
        .toList();

    return Column(
      children: [
        // Map Section
        Padding(
          padding: const EdgeInsets.all(16),
          child: Container(
            height: MediaQuery.of(context).size.height * 0.4,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
              color: Colors.grey.shade100,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                children: [
                  // Google Maps - Use web-specific widget for web, original widget for mobile
                  kIsWeb
                      ? WebGoogleMapsWidget(
                          locations: sanitizedLocations,
                          height: MediaQuery.of(context).size.height * 0.4,
                          onMarkerTap: (location) {
                            _showLocationDetails(location);
                          },
                          onMapTap: () {
                            // Handle map tap if needed
                          },
                        )
                      : GoogleMapsLocationWidget(
                          locations: sanitizedLocations,
                          height: MediaQuery.of(context).size.height * 0.4,
                          onMarkerTap: (location) {
                            _showLocationDetails(location);
                          },
                          onMapTap: () {
                            // Handle map tap if needed
                          },
                        ),
                ],
              ),
            ),
          ),
        ),

        // Tab Section
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.4,
          child: DefaultTabController(
            length: 2,
            child: Column(
              children: [
                // Tab Bar
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TabBar(
                    indicator: BoxDecoration(
                      color: Colors.blue,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.grey.shade600,
                    labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                    indicatorSize: TabBarIndicatorSize.tab,
                    tabs: const [
                      Tab(icon: Icon(Icons.list), text: 'Locations'),
                      Tab(icon: Icon(Icons.info_outline), text: 'Details'),
                    ],
                  ),
                ),

                // Tab Content
                Expanded(
                  child: TabBarView(
                    children: [
                      // Locations List Tab
                      _buildLocationsTab(),
                      // Details Tab
                      _buildDetailsTab(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Locations Tab Content
  Widget _buildLocationsTab() {
    try {
      if (_filteredLocations.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.location_off, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(
                'No Locations Found',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Create your first location to get started',
                style: TextStyle(color: Colors.grey.shade500),
              ),
            ],
          ),
        );
      }

      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _filteredLocations.length,
        itemBuilder: (context, index) {
          try {
            final location = _filteredLocations[index];
            // Sanitize location data to prevent type errors
            final sanitizedLocation = _sanitizeLocationData(location);

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.location_on,
                    color: Colors.blue,
                    size: 24,
                  ),
                ),
                title: Text(
                  sanitizedLocation['name'] ?? 'Unnamed Location',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(
                      _getLocationAddress(sanitizedLocation),
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _buildInfoChip(
                          icon: Icons.person_add,
                          label:
                              '${int.tryParse(sanitizedLocation['currentEmployees']?.toString() ?? '0') ?? 0} assigned',
                          color: Colors.orange,
                        ),
                        _buildInfoChip(
                          icon: Icons.people,
                          label:
                              '${int.tryParse(sanitizedLocation['activeUsers']?.toString() ?? '0') ?? 0} active',
                          color: Colors.green,
                        ),
                        _buildInfoChip(
                          icon: Icons.business,
                          label:
                              'Cap: ${int.tryParse(sanitizedLocation['settings']?['capacity']?.toString() ?? '0') ?? 0}',
                          color: Colors.blue,
                        ),
                      ],
                    ),
                  ],
                ),
                trailing: PopupMenuButton<String>(
                  onSelected: (value) {
                    switch (value) {
                      case 'edit':
                        _editLocation(sanitizedLocation);
                        break;
                      case 'delete':
                        _deleteLocation(sanitizedLocation);
                        break;
                      case 'assign':
                        _showEmployeeAssignmentDialog(sanitizedLocation);
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, color: Colors.blue),
                          SizedBox(width: 8),
                          Text('Edit'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'assign',
                      child: Row(
                        children: [
                          Icon(Icons.person_add, color: Colors.green),
                          SizedBox(width: 8),
                          Text('Assign Employee'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Delete'),
                        ],
                      ),
                    ),
                  ],
                ),
                onTap: () {
                  _showLocationDetails(sanitizedLocation);
                },
              ),
            );
          } catch (e) {
            Logger.error('Error building location item $index: $e');
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                title: Text('Error loading location $index'),
                subtitle: Text('Error: $e'),
              ),
            );
          }
        },
      );
    } catch (e) {
      Logger.error('Error in _buildLocationsTab: $e');
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error, size: 64, color: Colors.red.shade400),
            const SizedBox(height: 16),
            Text(
              'Error Loading Locations',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.red.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Error: $e',
              style: TextStyle(color: Colors.grey.shade500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
  }

  // Details Tab Content
  Widget _buildDetailsTab() {
    try {
      if (_filteredLocations.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.info_outline, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(
                'No Location Details',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Select a location to view details',
                style: TextStyle(color: Colors.grey.shade500),
              ),
            ],
          ),
        );
      }

      // Sanitize all locations for safe processing
      final sanitizedLocations = _filteredLocations
          .map((location) => _sanitizeLocationData(location))
          .toList();

      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Summary Cards
            Row(
              children: [
                Expanded(
                  child: _buildDetailCard(
                    title: 'Total Locations',
                    value: '${sanitizedLocations.length}',
                    icon: Icons.location_on,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDetailCard(
                    title: 'Assigned Users',
                    value:
                        '${sanitizedLocations.fold<int>(0, (sum, l) => sum + (int.tryParse(l['currentEmployees']?.toString() ?? '0') ?? 0))}',
                    icon: Icons.person_add,
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDetailCard(
                    title: 'Active Users',
                    value:
                        '${sanitizedLocations.fold<int>(0, (sum, l) => sum + (int.tryParse(l['activeUsers']?.toString() ?? '0') ?? 0))}',
                    icon: Icons.people,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildDetailCard(
                    title: 'Total Capacity',
                    value:
                        '${sanitizedLocations.fold<int>(0, (sum, l) => sum + (int.tryParse(l['settings']?['capacity']?.toString() ?? '0') ?? 0))}',
                    icon: Icons.business,
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDetailCard(
                    title: 'Avg Radius',
                    value:
                        '${(sanitizedLocations.fold<double>(0, (sum, l) => sum + (double.tryParse(l['settings']?['geofenceRadius']?.toString() ?? '100') ?? 100.0)) / sanitizedLocations.length).round()}m',
                    icon: Icons.radio_button_checked,
                    color: Colors.purple,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Location Details List
            const Text(
              'Location Details',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            ...sanitizedLocations.map(
              (location) => _buildLocationDetailCard(location),
            ),
          ],
        ),
      );
    } catch (e) {
      Logger.error('Error in _buildDetailsTab: $e');
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error, size: 64, color: Colors.red.shade400),
            const SizedBox(height: 16),
            Text(
              'Error Loading Details',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.red.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Error: $e',
              style: TextStyle(color: Colors.grey.shade500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildLocationDetailCard(Map<String, dynamic> location) {
    try {
      // Safely get nested values with type checking
      final settings = location['settings'];
      final workingHours = settings is Map ? settings['workingHours'] : null;
      final startTime = workingHours is Map ? workingHours['start'] : null;
      final endTime = workingHours is Map ? workingHours['end'] : null;

      return Card(
        margin: const EdgeInsets.only(bottom: 12),
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.location_on, color: Colors.blue, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      location['name'] ?? 'Unnamed Location',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      location['status'] ?? 'active',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.green,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildDetailRow('Address', _getLocationAddress(location)),
              _buildDetailRow(
                'Capacity',
                '${location['settings']?['capacity'] ?? 0} people',
              ),
              _buildDetailRow(
                'Active Users',
                '${location['activeUsers'] ?? 0}',
              ),
              _buildDetailRow(
                'Geofence Radius',
                '${location['settings']?['geofenceRadius'] ?? 100}m',
              ),
              if (startTime != null && endTime != null)
                _buildDetailRow('Working Hours', '$startTime - $endTime'),
            ],
          ),
        ),
      );
    } catch (e) {
      Logger.error('Error building location detail card: $e');
      return Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.error, color: Colors.red, size: 20),
              const SizedBox(height: 8),
              Text(
                location['name'] ?? 'Unnamed Location',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'Error loading details: $e',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  // Helper method to sanitize location data for map widgets
  Map<String, dynamic> _sanitizeLocationData(Map<String, dynamic> location) {
    try {
      // Create a new map to avoid modifying the original
      final sanitized = <String, dynamic>{};

      // Copy all string fields directly
      for (final entry in location.entries) {
        final key = entry.key;
        final value = entry.value;

        if (value is Map) {
          // Recursively sanitize nested maps
          sanitized[key] = _sanitizeMap(value);
        } else if (value is List) {
          // Keep lists as-is
          sanitized[key] = value;
        } else {
          // For coordinates and settings, apply special handling
          if (key == 'coordinates' && value is Map) {
            sanitized[key] = _sanitizeCoordinates(value);
          } else if (key == 'settings' && value is Map) {
            sanitized[key] = _sanitizeSettings(value);
          } else if (key == 'activeUsers') {
            sanitized[key] = int.tryParse(value?.toString() ?? '0') ?? 0;
          } else {
            // Copy other fields as-is
            sanitized[key] = value;
          }
        }
      }

      return sanitized;
    } catch (e) {
      Logger.error('Error sanitizing location data: $e');
      // Return original data if sanitization fails
      return location;
    }
  }

  Map<String, dynamic> _sanitizeMap(Map map) {
    final sanitized = <String, dynamic>{};
    for (final entry in map.entries) {
      if (entry.value is Map) {
        sanitized[entry.key.toString()] = _sanitizeMap(entry.value);
      } else {
        sanitized[entry.key.toString()] = entry.value;
      }
    }
    return sanitized;
  }

  Map<String, dynamic> _sanitizeCoordinates(Map coordinates) {
    final sanitized = <String, dynamic>{};
    try {
      if (coordinates['latitude'] != null) {
        sanitized['latitude'] =
            double.tryParse(coordinates['latitude'].toString()) ?? 0.0;
      }
      if (coordinates['longitude'] != null) {
        sanitized['longitude'] =
            double.tryParse(coordinates['longitude'].toString()) ?? 0.0;
      }
    } catch (e) {
      Logger.error('Error sanitizing coordinates: $e');
    }
    return sanitized;
  }

  Map<String, dynamic> _sanitizeSettings(Map settings) {
    final sanitized = <String, dynamic>{};
    try {
      for (final entry in settings.entries) {
        final key = entry.key.toString();
        final value = entry.value;

        if (key == 'capacity') {
          sanitized[key] = int.tryParse(value?.toString() ?? '50') ?? 50;
        } else if (key == 'geofenceRadius') {
          sanitized[key] = double.tryParse(value?.toString() ?? '100') ?? 100.0;
        } else if (value is Map) {
          sanitized[key] = _sanitizeMap(value);
        } else {
          sanitized[key] = value;
        }
      }
    } catch (e) {
      Logger.error('Error sanitizing settings: $e');
    }
    return sanitized;
  }

  void _showCreateLocationForm() {
    Logger.debug('🔍 DEBUG: _showCreateLocationForm called');
    Logger.debug('🔍 DEBUG: Current _showCreateForm: $_showCreateForm');

    // Reset form
    _formKey.currentState?.reset();
    _nameController.clear();
    _streetController.clear();
    _cityController.clear();
    _stateController.clear();
    _postalCodeController.clear();
    _countryController.clear();
    _phoneController.clear();
    _emailController.clear();

    // Use loaded settings from backend instead of hardcoded values
    _capacityController.text = _defaultCapacity.toString();
    _geofenceRadius = _defaultGeofenceRadius.toDouble();
    _gracePeriodController.text = '15';
    _timezoneController.text = 'UTC';
    _startTimeController.text = _defaultStartTime;
    _endTimeController.text = _defaultEndTime;

    _descriptionController.clear();
    _latController.clear();
    _lngController.clear();
    _searchController.clear();
    _selectedLatitude = null;
    _selectedLongitude = null;
    _showSearchResults = false;
    _useCustomCoordinates = false;

    Logger.debug('🔍 DEBUG: Setting _showCreateForm to true');
    setState(() {
      _showCreateForm = true;
    });
    Logger.debug('🔍 DEBUG: After setState, _showCreateForm: $_showCreateForm');
  }

  void _hideCreateForm() {
    setState(() {
      _showCreateForm = false;
      _editingLocation = null; // Reset editing state
    });
  }

  void _showActionsMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.refresh, color: Colors.blue),
              title: const Text('Refresh Locations'),
              onTap: () {
                Navigator.pop(context);
                _loadLocations();
              },
            ),
            ListTile(
              leading: const Icon(Icons.file_download, color: Colors.green),
              title: const Text('Export Data'),
              onTap: () {
                Navigator.pop(context);
                _exportLocationData();
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings, color: Colors.orange),
              title: const Text('Settings'),
              onTap: () {
                Navigator.pop(context);
                _showLocationSettings();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showEmployeeAssignmentDialog(Map<String, dynamic> location) {
    showDialog(
      context: context,
      builder: (context) => EmployeeAssignmentDialog(
        location: location,
        onAssign: (employeeId) async {
          await _assignEmployeeToLocation(employeeId, location['_id']);
        },
        onRemove: (employeeId) async {
          await _removeEmployeeFromLocation(employeeId, location['_id']);
        },
        onChangeLocation: (employeeId, newLocationId) async {
          await _changeEmployeeLocation(employeeId, newLocationId);
        },
      ),
    );
  }

  Future<void> _assignEmployeeToLocation(
    String employeeId,
    String locationId,
  ) async {
    try {
      final apiService = ApiService(baseUrl: ApiConfig.baseUrl);
      final response = await apiService.put('/employees/$employeeId/location', {
        'locationId': locationId,
      });

      if (response.success) {
        // Send notification to company admins about the assignment
        await _sendLocationAssignmentNotification(employeeId, locationId);

        GlobalNotificationService().showSuccess(
          'Employee assigned to location successfully',
        );
      } else {
        GlobalNotificationService().showError(response.message);
      }
    } catch (e) {
      GlobalNotificationService().showError('Error assigning employee: $e');
    }
  }

  Widget _buildCreateForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Colors.blue, Colors.blueAccent],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.add_location,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _editingLocation != null
                              ? 'Edit Location'
                              : 'Create New Location',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _editingLocation != null
                              ? 'Update location details and settings'
                              : 'Add a new location for attendance tracking',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _hideCreateForm,
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.close, size: 20),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Location Selection Section
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Location Selection',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Search Section
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.grey.shade50,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Search for a Location',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _searchController,
                          onChanged: (value) => _searchLocation(value),
                          decoration: InputDecoration(
                            hintText: 'Search for a location...',
                            prefixIcon: const Icon(
                              Icons.search,
                              color: Colors.blue,
                            ),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() {
                                        _showSearchResults = false;
                                      });
                                    },
                                  )
                                : null,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                        if (_showSearchResults) ...[
                          const SizedBox(height: 8),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade200),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: _isSearching
                                ? const Padding(
                                    padding: EdgeInsets.all(16),
                                    child: Row(
                                      children: [
                                        SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        ),
                                        SizedBox(width: 12),
                                        Text('Searching...'),
                                      ],
                                    ),
                                  )
                                : _searchResults.isEmpty
                                ? const Padding(
                                    padding: EdgeInsets.all(16),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.search_off,
                                          color: Colors.grey,
                                        ),
                                        SizedBox(width: 12),
                                        Text('No locations found'),
                                      ],
                                    ),
                                  )
                                : ListView.builder(
                                    shrinkWrap: true,
                                    padding: EdgeInsets.zero,
                                    itemCount: _searchResults.length,
                                    itemBuilder: (context, index) {
                                      final placemark = _searchResults[index];
                                      final address =
                                          [
                                                placemark.street,
                                                placemark.locality,
                                                placemark.administrativeArea,
                                              ]
                                              .where(
                                                (part) =>
                                                    part != null &&
                                                    part.isNotEmpty,
                                              )
                                              .join(', ');

                                      return ListTile(
                                        leading: Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Colors.blue.withValues(
                                              alpha: 0.1,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.location_on,
                                            color: Colors.blue,
                                            size: 20,
                                          ),
                                        ),
                                        title: Text(
                                          address,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w500,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        subtitle: Text(
                                          placemark.country ?? '',
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 12,
                                          ),
                                        ),
                                        onTap: () =>
                                            _selectSearchResult(placemark),
                                      );
                                    },
                                  ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Location Methods Section
                  Row(
                    children: [
                      Expanded(
                        child: _buildMethodCard(
                          icon: Icons.my_location,
                          title: 'Current Location',
                          subtitle: 'Use GPS location',
                          onTap: _isLoadingLocation
                              ? null
                              : _getCurrentLocation,
                          isLoading: _isLoadingLocation,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildMethodCard(
                          icon: Icons.map,
                          title: 'Interactive Map',
                          subtitle: 'Select on map',
                          onTap: _showInteractiveMapPicker,
                          color: Colors.purple,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildMethodCard(
                          icon: Icons.edit_location,
                          title: 'Custom Coordinates',
                          subtitle: 'Enter manually',
                          onTap: () {
                            setState(() {
                              _useCustomCoordinates = !_useCustomCoordinates;
                            });
                          },
                          isSelected: _useCustomCoordinates,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),

                  if (_useCustomCoordinates) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.grey.shade50,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Enter Coordinates',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _latController,
                                  onChanged: (_) => _onCoordinatesChanged(),
                                  decoration: const InputDecoration(
                                    labelText: 'Latitude',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: _lngController,
                                  onChanged: (_) => _onCoordinatesChanged(),
                                  decoration: const InputDecoration(
                                    labelText: 'Longitude',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],

                  if (_selectedLatitude != null &&
                      _selectedLongitude != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle, color: Colors.green),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Location Set: ${_selectedLatitude!.toStringAsFixed(6)}, ${_selectedLongitude!.toStringAsFixed(6)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),

                  // Geofence Radius
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.radio_button_checked,
                          color: Colors.blue,
                        ),
                        const SizedBox(width: 8),
                        const Text('Geofence Radius: '),
                        Text(
                          '${_geofenceRadius.round()}m',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Adjust Geofence Radius'),
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'Current radius: ${_geofenceRadius.round()}m',
                                    ),
                                    const SizedBox(height: 16),
                                    Slider(
                                      value: _geofenceRadius,
                                      min: 25,
                                      max: 1000,
                                      divisions: 39,
                                      onChanged: (value) {
                                        setState(() {
                                          _geofenceRadius = value;
                                        });
                                      },
                                    ),
                                    Text('${_geofenceRadius.round()}m'),
                                  ],
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(context).pop(),
                                    child: const Text('Cancel'),
                                  ),
                                  ElevatedButton(
                                    onPressed: () =>
                                        Navigator.of(context).pop(),
                                    child: const Text('OK'),
                                  ),
                                ],
                              ),
                            );
                          },
                          child: const Text('Adjust'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Basic Information
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Basic Information',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Location Name *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value?.trim().isEmpty == true) {
                        return 'Location name is required';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Address Information
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Address Information',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _streetController,
                    decoration: const InputDecoration(
                      labelText: 'Street Address *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value?.trim().isEmpty == true) {
                        return 'Street address is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _cityController,
                          decoration: const InputDecoration(
                            labelText: 'City *',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value?.trim().isEmpty == true) {
                              return 'City is required';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _stateController,
                          decoration: const InputDecoration(
                            labelText: 'State/Province',
                            border: OutlineInputBorder(),
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
                          controller: _postalCodeController,
                          decoration: const InputDecoration(
                            labelText: 'Postal Code *',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value?.trim().isEmpty == true) {
                              return 'Postal code is required';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _countryController,
                          decoration: const InputDecoration(
                            labelText: 'Country *',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value?.trim().isEmpty == true) {
                              return 'Country is required';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Contact Information
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Contact Information',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _phoneController,
                          decoration: const InputDecoration(
                            labelText: 'Phone',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _emailController,
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Settings
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Settings',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _capacityController,
                          decoration: const InputDecoration(
                            labelText: 'Capacity',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _gracePeriodController,
                          decoration: const InputDecoration(
                            labelText: 'Grace Period (minutes)',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _timezoneController,
                          decoration: const InputDecoration(
                            labelText: 'Timezone',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _startTimeController,
                          decoration: const InputDecoration(
                            labelText: 'Start Time',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _endTimeController,
                          decoration: const InputDecoration(
                            labelText: 'End Time',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Action Buttons
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _hideCreateForm,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
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
                      onPressed: _isCreating ? null : _submitForm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                        shadowColor: Colors.blue.withValues(alpha: 0.3),
                      ),
                      child: _isCreating
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : Text(
                              _editingLocation != null
                                  ? 'Update Location'
                                  : 'Create Location',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _filterLocations() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredLocations = _locations.where((location) {
        final name = location['name'].toString().toLowerCase();
        final address =
            location['address']['street']?.toString().toLowerCase() ?? '';
        final city =
            location['address']['city']?.toString().toLowerCase() ?? '';
        final state =
            location['address']['state']?.toString().toLowerCase() ?? '';
        final postalCode =
            location['address']['postalCode']?.toString().toLowerCase() ?? '';
        final country =
            location['address']['country']?.toString().toLowerCase() ?? '';

        return name.contains(query) ||
            address.contains(query) ||
            city.contains(query) ||
            state.contains(query) ||
            postalCode.contains(query) ||
            country.contains(query);
      }).toList();
    });
  }

  void _showLocationDetails(Map<String, dynamic> location) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(location['name'] ?? 'Location Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Address: ${_getLocationAddress(location)}'),
            const SizedBox(height: 8),
            Text('Status: ${location['status'] ?? 'Unknown'}'),
            if (location['settings']?['capacity'] != null)
              Text('Capacity: ${location['settings']['capacity']} people'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Implement edit functionality
            },
            child: const Text('Edit'),
          ),
        ],
      ),
    );
  }

  String _getLocationAddress(Map<String, dynamic> location) {
    try {
      final address = location['address'];
      if (address == null || address is! Map) return 'No address available';

      final parts = <String>[];

      // Safely extract address parts
      final street = address['street']?.toString();
      final city = address['city']?.toString();
      final state = address['state']?.toString();

      if (street != null && street.isNotEmpty) parts.add(street);
      if (city != null && city.isNotEmpty) parts.add(city);
      if (state != null && state.isNotEmpty) parts.add(state);

      return parts.isEmpty ? 'No address available' : parts.join(', ');
    } catch (e) {
      Logger.error('Error getting location address: $e');
      return 'Address unavailable';
    }
  }

  void _editLocation(Map<String, dynamic> location) {
    // Store the location being edited
    _editingLocation = location;

    // Populate form with location data
    _nameController.text = location['name'] ?? '';
    _streetController.text = location['address']?['street'] ?? '';
    _cityController.text = location['address']?['city'] ?? '';
    _stateController.text = location['address']?['state'] ?? '';
    _postalCodeController.text = location['address']?['postalCode'] ?? '';
    _countryController.text = location['address']?['country'] ?? '';
    _phoneController.text = location['contactInfo']?['phone'] ?? '';
    _emailController.text = location['contactInfo']?['email'] ?? '';
    _capacityController.text = '${location['settings']?['capacity'] ?? 50}';
    _geofenceRadius = (location['settings']?['geofenceRadius'] ?? 100)
        .toDouble();
    _gracePeriodController.text =
        '${location['settings']?['gracePeriod'] ?? 15}';
    _timezoneController.text = location['settings']?['timezone'] ?? 'UTC';
    _startTimeController.text =
        location['settings']?['workingHours']?['start'] ?? '09:00';
    _endTimeController.text =
        location['settings']?['workingHours']?['end'] ?? '17:00';
    _descriptionController.text = location['description'] ?? '';

    // Set coordinates
    if (location['coordinates'] != null) {
      _selectedLatitude = location['coordinates']['latitude']?.toDouble();
      _selectedLongitude = location['coordinates']['longitude']?.toDouble();
      _latController.text = '${_selectedLatitude ?? ''}';
      _lngController.text = '${_selectedLongitude ?? ''}';
    }

    setState(() {
      _showCreateForm = true;
      _isCreating = false; // This is edit mode, not create mode
    });
  }

  void _deleteLocation(Map<String, dynamic> location) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Location'),
        content: Text(
          'Are you sure you want to delete "${location['name']}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _performDeleteLocation(location['_id']);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _performDeleteLocation(String locationId) async {
    try {
      setState(() {
        _isLoading = true;
      });

      final apiService = ApiService(baseUrl: ApiConfig.baseUrl);
      final response = await apiService.delete('/locations/$locationId');

      if (response.success) {
        // Remove from local list
        setState(() {
          _locations.removeWhere((location) => location['_id'] == locationId);
          _filterLocations();
        });

        GlobalNotificationService().showSuccess(
          'Location deleted successfully',
        );
      } else {
        throw Exception(response.message);
      }
    } catch (error) {
      GlobalNotificationService().showError(
        'Error deleting location: ${error.toString()}',
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _removeEmployeeFromLocation(
    String employeeId,
    String locationId,
  ) async {
    try {
      final apiService = ApiService(baseUrl: ApiConfig.baseUrl);
      final response = await apiService.delete(
        '/employees/$employeeId/location',
      );

      if (response.success) {
        GlobalNotificationService().showSuccess(
          'Employee removed from location successfully',
        );
        // Refresh locations to update counts
        _loadLocations();
      } else {
        throw Exception(response.message);
      }
    } catch (error) {
      GlobalNotificationService().showError(
        'Error removing employee: ${error.toString()}',
      );
    }
  }

  Future<void> _changeEmployeeLocation(
    String employeeId,
    String newLocationId,
  ) async {
    try {
      final apiService = ApiService(baseUrl: ApiConfig.baseUrl);
      final response = await apiService.put('/employees/$employeeId/location', {
        'locationId': newLocationId,
      });

      if (response.success) {
        GlobalNotificationService().showSuccess(
          'Employee location changed successfully',
        );
        // Refresh locations to update counts
        _loadLocations();
      } else {
        throw Exception(response.message);
      }
    } catch (error) {
      GlobalNotificationService().showError(
        'Error changing employee location: ${error.toString()}',
      );
    }
  }

  Future<void> _loadLocationSettings() async {
    try {
      // 'Loading location settings from backend...');

      final geofenceRadius = await _locationSettingsService
          .getDefaultGeofenceRadius();
      final workingHours = await _locationSettingsService
          .getDefaultWorkingHours();
      final capacity = await _locationSettingsService.getDefaultCapacity();
      final notifications = await _locationSettingsService
          .getNotificationSettings();

      // 'Loaded settings:');
      // '  - Geofence Radius: $geofenceRadius');
      // '  - Working Hours: ${workingHours['start']} - ${workingHours['end']}');
      // '  - Capacity: $capacity');
      // '  - Notifications: $notifications');

      setState(() {
        _defaultGeofenceRadius = geofenceRadius;
        _defaultStartTime = workingHours['start'] ?? '09:00';
        _defaultEndTime = workingHours['end'] ?? '17:00';
        _defaultCapacity = capacity;
        _locationUpdatesEnabled = notifications['locationUpdates'] ?? true;
        _employeeAssignmentsEnabled =
            notifications['employeeAssignments'] ?? true;
        _capacityAlertsEnabled = notifications['capacityAlerts'] ?? false;
      });

      // 'Settings loaded successfully and applied to state');
    } catch (error) {
      // Use default values if loading fails
      // 'Error loading location settings: $error');
      // 'Using default values:');
      // '  - Geofence Radius: $_defaultGeofenceRadius');
      // '  - Working Hours: $_defaultStartTime - $_defaultEndTime');
      // '  - Capacity: $_defaultCapacity');
    }
  }

  Future<void> _exportLocationData() async {
    try {
      // 'Starting export process...');

      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      // Prepare data for export
      final exportData = {
        'exportDate': DateTime.now().toIso8601String(),
        'totalLocations': _locations.length,
        'activeLocations': _locations
            .where((l) => l['status'] == 'active')
            .length,
        'totalCapacity': _locations.fold<int>(
          0,
          (sum, l) => sum + ((l['settings']?['capacity'] ?? 0) as int),
        ),
        'totalActiveUsers': _locations.fold<int>(
          0,
          (sum, l) => sum + ((l['activeUsers'] ?? 0) as int),
        ),
        'locations': _locations
            .map(
              (location) => {
                'name': location['name'],
                'address': location['address'],
                'status': location['status'],
                'capacity': location['settings']?['capacity'] ?? 0,
                'activeUsers': location['activeUsers'] ?? 0,
                'currentEmployees': location['currentEmployees'] ?? 0,
                'geofenceRadius':
                    location['settings']?['geofenceRadius'] ?? 100,
                'workingHours': location['settings']?['workingHours'],
                'createdAt': location['createdAt'],
                'updatedAt': location['updatedAt'],
              },
            )
            .toList(),
      };

      // Convert to JSON string
      final jsonString = const JsonEncoder.withIndent('  ').convert(exportData);

      // 'JSON data prepared, length: ${jsonString.length}');
      // 'Platform: ${kIsWeb ? 'Web' : 'Mobile'}');

      // Close loading dialog first
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      // Wait a bit for the dialog to close properly
      await Future.delayed(const Duration(milliseconds: 200));

      // Now show the export dialog for all platforms
      // 'Showing export dialog');
      // ignore: use_build_context_synchronously
      _showExportDialog(context, jsonString);
    } catch (error) {
      // Close loading dialog if open
      // ignore: use_build_context_synchronously
      if (Navigator.canPop(context)) {
        // ignore: use_build_context_synchronously
        Navigator.pop(context);
      }

      GlobalNotificationService().showError(
        'Error exporting data: ${error.toString()}',
      );
    }
  }

  void _showLocationSettings() {
    showDialog(
      context: context,
      builder: (context) => Consumer<FeatureProvider>(
        builder: (context, featureProvider, child) {
          final hasLocationSettings = featureProvider.hasLocationSettings;
          final hasLocationNotifications =
              featureProvider.hasLocationNotifications;
          final hasLocationGeofencing = featureProvider.hasLocationGeofencing;
          final hasLocationCapacity = featureProvider.hasLocationCapacity;

          return AlertDialog(
            title: const Text('Location Management Settings'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Configure location management preferences and default settings.',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 20),
                if (hasLocationGeofencing) ...[
                  _buildSettingsOption(
                    icon: Icons.location_on,
                    title: 'Default Geofence Radius',
                    subtitle: 'Set default radius for new locations',
                    onTap: () => _showGeofenceSettings(),
                  ),
                  const SizedBox(height: 10),
                ] else ...[
                  _buildFeatureLockOption(
                    icon: Icons.location_on,
                    title: 'Default Geofence Radius',
                    subtitle: 'Available in Professional plan and above',
                    featureName: 'Geofencing',
                  ),
                  const SizedBox(height: 10),
                ],
                if (hasLocationSettings) ...[
                  _buildSettingsOption(
                    icon: Icons.access_time,
                    title: 'Default Working Hours',
                    subtitle: 'Set default working hours for new locations',
                    onTap: () => _showWorkingHoursSettings(),
                  ),
                  const SizedBox(height: 10),
                ] else ...[
                  _buildFeatureLockOption(
                    icon: Icons.access_time,
                    title: 'Default Working Hours',
                    subtitle: 'Available in Professional plan and above',
                    featureName: 'Location Settings',
                  ),
                  const SizedBox(height: 10),
                ],
                if (hasLocationCapacity) ...[
                  _buildSettingsOption(
                    icon: Icons.people,
                    title: 'Default Capacity',
                    subtitle: 'Set default capacity for new locations',
                    onTap: () => _showCapacitySettings(),
                  ),
                  const SizedBox(height: 10),
                ] else ...[
                  _buildFeatureLockOption(
                    icon: Icons.people,
                    title: 'Default Capacity',
                    subtitle: 'Available in Professional plan and above',
                    featureName: 'Location Capacity',
                  ),
                  const SizedBox(height: 10),
                ],
                if (hasLocationNotifications) ...[
                  _buildSettingsOption(
                    icon: Icons.notifications,
                    title: 'Notification Settings',
                    subtitle: 'Configure location-related notifications',
                    onTap: () => _showNotificationSettings(),
                  ),
                ] else ...[
                  _buildFeatureLockOption(
                    icon: Icons.notifications,
                    title: 'Notification Settings',
                    subtitle: 'Available in Professional plan and above',
                    featureName: 'Location Notifications',
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSettingsOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        child: Row(
          children: [
            Icon(icon, color: Colors.blue, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureLockOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required String featureName,
  }) {
    return InkWell(
      onTap: () => _showUpgradeDialog(featureName),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        child: Row(
          children: [
            Icon(icon, color: Colors.grey.shade400, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
            Icon(Icons.lock, size: 16, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }

  Future<void> _sendLocationAssignmentNotification(
    String employeeId,
    String locationId,
  ) async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.user;
      final userName = user?['name'] ?? 'Admin';

      // Get employee and location details for the notification
      final apiService = ApiService(baseUrl: ApiConfig.baseUrl);

      // Get employee details
      final employeeResponse = await apiService.get('/employees/$employeeId');
      final employeeName = employeeResponse.success
          ? employeeResponse.data['name']
          : 'Employee';

      // Get location details
      final locationResponse = await apiService.get('/locations/$locationId');
      final locationName = locationResponse.success
          ? locationResponse.data['name']
          : 'Location';

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/notifications'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${authProvider.token}',
        },
        body: jsonEncode({
          'title': 'Employee Location Assignment',
          'message':
              '$employeeName has been assigned to $locationName by $userName',
          'type': 'location_assignment',
          'role': 'admin',
          'link': '/admin/location-management',
        }),
      );

      if (response.statusCode == 201) {
        // 'Location assignment notification sent successfully');
      } else {
        // 'Failed to send location assignment notification: ${response.statusCode}');
      }
    } catch (error) {
      // 'Error sending location assignment notification: $error');
    }
  }

  Future<void> _sendLocationSettingsNotification(
    String settingType,
    String details,
  ) async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.user;
      final userName = user?['name'] ?? 'Admin';

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/notifications'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${authProvider.token}',
        },
        body: jsonEncode({
          'title': 'Location Settings Updated',
          'message':
              '$settingType settings have been updated by $userName. $details',
          'type': 'location_settings',
          'role': 'admin',
          'link': '/admin/location-management',
        }),
      );

      if (response.statusCode == 201) {
        // 'Location settings notification sent successfully');
      } else {
        // 'Failed to send location settings notification: ${response.statusCode}');
      }
    } catch (error) {
      // 'Error sending location settings notification: $error');
    }
  }

  void _showUpgradeDialog(String featureName) {
    showDialog(
      context: context,
      builder: (context) => Consumer<FeatureProvider>(
        builder: (context, featureProvider, child) {
          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.lock, color: Colors.orange),
                SizedBox(width: 8),
                Text('Feature Locked'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'The "$featureName" feature is not available in your current plan (${featureProvider.subscriptionPlanName}).',
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 16),
                const Text(
                  'To access this feature, please contact your administrator to upgrade your subscription plan.',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Available Plans:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text('• Professional: Location management features'),
                      Text('• Enterprise: All features included'),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showGeofenceSettings() {
    Navigator.pop(context); // Close settings dialog

    showDialog(
      context: context,
      builder: (context) => Consumer<FeatureProvider>(
        builder: (context, featureProvider, child) {
          if (!featureProvider.hasLocationGeofencing) {
            return AlertDialog(
              title: const Text('Feature Not Available'),
              content: const Text(
                'Geofence settings are not available in your current subscription plan. Please upgrade to access this feature.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ],
            );
          }

          final radiusController = TextEditingController(
            text: _defaultGeofenceRadius.toString(),
          );

          return AlertDialog(
            title: const Text('Default Geofence Radius'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Set the default geofence radius for new locations:',
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: radiusController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Radius (meters)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  try {
                    final radius = int.tryParse(radiusController.text) ?? 100;
                    await _locationSettingsService.updateLocationSettings({
                      'defaultGeofenceRadius': radius,
                    });

                    setState(() {
                      _defaultGeofenceRadius = radius;
                    });

                    // Send notification to company admins
                    await _sendLocationSettingsNotification(
                      'Geofence Radius',
                      'Updated default radius to $radius meters',
                    );

                    Navigator.pop(context);
                    GlobalNotificationService().showSuccess(
                      'Default geofence radius updated',
                    );
                  } catch (error) {
                    GlobalNotificationService().showError(
                      'Error updating settings: $error',
                    );
                  }
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showWorkingHoursSettings() {
    Navigator.pop(context); // Close settings dialog

    final startController = TextEditingController(text: _defaultStartTime);
    final endController = TextEditingController(text: _defaultEndTime);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Default Working Hours'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Set the default working hours for new locations:'),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: startController,
                    decoration: const InputDecoration(
                      labelText: 'Start Time',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: endController,
                    decoration: const InputDecoration(
                      labelText: 'End Time',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await _locationSettingsService.updateLocationSettings({
                  'defaultWorkingHours': {
                    'start': startController.text,
                    'end': endController.text,
                  },
                });

                setState(() {
                  _defaultStartTime = startController.text;
                  _defaultEndTime = endController.text;
                });

                // Send notification to company admins
                await _sendLocationSettingsNotification(
                  'Working Hours',
                  'Updated default working hours to ${startController.text} - ${endController.text}',
                );

                Navigator.pop(context);
                GlobalNotificationService().showSuccess(
                  'Default working hours updated',
                );
              } catch (error) {
                GlobalNotificationService().showError(
                  'Error updating settings: $error',
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showCapacitySettings() {
    Navigator.pop(context); // Close settings dialog

    final capacityController = TextEditingController(
      text: _defaultCapacity.toString(),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Default Capacity'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Set the default capacity for new locations:'),
            const SizedBox(height: 20),
            TextFormField(
              controller: capacityController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Capacity (people)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                final capacity = int.tryParse(capacityController.text) ?? 50;
                await _locationSettingsService.updateLocationSettings({
                  'defaultCapacity': capacity,
                });

                setState(() {
                  _defaultCapacity = capacity;
                });

                // Send notification to company admins
                await _sendLocationSettingsNotification(
                  'Capacity',
                  'Updated default capacity to $capacity employees',
                );

                Navigator.pop(context);
                GlobalNotificationService().showSuccess(
                  'Default capacity updated',
                );
              } catch (error) {
                GlobalNotificationService().showError(
                  'Error updating settings: $error',
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showNotificationSettings() {
    Navigator.pop(context); // Close settings dialog

    bool locationUpdates = _locationUpdatesEnabled;
    bool employeeAssignments = _employeeAssignmentsEnabled;
    bool capacityAlerts = _capacityAlertsEnabled;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Notification Settings'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Configure location-related notifications:'),
              const SizedBox(height: 20),
              SwitchListTile(
                title: const Text('Location Updates'),
                subtitle: const Text('Notify when location details change'),
                value: locationUpdates,
                onChanged: (value) {
                  setDialogState(() {
                    locationUpdates = value;
                  });
                },
              ),
              SwitchListTile(
                title: const Text('Employee Assignments'),
                subtitle: const Text(
                  'Notify when employees are assigned/removed',
                ),
                value: employeeAssignments,
                onChanged: (value) {
                  setDialogState(() {
                    employeeAssignments = value;
                  });
                },
              ),
              SwitchListTile(
                title: const Text('Capacity Alerts'),
                subtitle: const Text('Notify when location reaches capacity'),
                value: capacityAlerts,
                onChanged: (value) {
                  setDialogState(() {
                    capacityAlerts = value;
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  await _locationSettingsService.updateLocationSettings({
                    'notifications': {
                      'locationUpdates': locationUpdates,
                      'employeeAssignments': employeeAssignments,
                      'capacityAlerts': capacityAlerts,
                    },
                  });

                  setState(() {
                    _locationUpdatesEnabled = locationUpdates;
                    _employeeAssignmentsEnabled = employeeAssignments;
                    _capacityAlertsEnabled = capacityAlerts;
                  });

                  // Send notification to company admins
                  final enabledFeatures = <String>[];
                  if (locationUpdates) enabledFeatures.add('Location Updates');
                  if (employeeAssignments) {
                    enabledFeatures.add('Employee Assignments');
                  }
                  if (capacityAlerts) enabledFeatures.add('Capacity Alerts');

                  await _sendLocationSettingsNotification(
                    'Notification Settings',
                    'Updated notification preferences: ${enabledFeatures.join(', ')}',
                  );

                  Navigator.pop(context);
                  GlobalNotificationService().showSuccess(
                    'Notification settings updated',
                  );
                } catch (error) {
                  GlobalNotificationService().showError(
                    'Error updating settings: $error',
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  // Show export dialog for mobile or fallback
  void _showExportDialog(BuildContext context, String jsonString) {
    // 'Showing export dialog with data length: ${jsonString.length}');

    // Use a post-frame callback to ensure the context is valid
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Location Data Export'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Location data has been prepared for export. You can copy the data below:',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: SizedBox(
                    height: 300,
                    child: SingleChildScrollView(
                      child: SelectableText(
                        jsonString,
                        style: const TextStyle(
                          fontSize: 12,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Close'),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  // Copy to clipboard
                  Clipboard.setData(ClipboardData(text: jsonString));
                  GlobalNotificationService().showSuccess(
                    'Data copied to clipboard',
                  );
                },
                icon: const Icon(Icons.copy),
                label: const Text('Copy'),
              ),
            ],
          ),
        );
      }
    });
  }
}
