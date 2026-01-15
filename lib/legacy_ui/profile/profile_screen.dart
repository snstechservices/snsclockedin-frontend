import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:async';
import 'package:sns_rooster/utils/logger.dart';
import 'package:provider/provider.dart';
import 'package:sns_rooster/theme/app_theme.dart';
import '../../providers/profile_provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../config/api_config.dart'; // Import ApiConfig
import 'package:sns_rooster/widgets/app_drawer.dart'; // Add this import
import 'package:sns_rooster/widgets/user_avatar.dart'; // Add UserAvatar import
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../providers/admin_settings_provider.dart';
import '../../widgets/admin_side_navigation.dart';
import 'package:flutter/services.dart';
import 'package:sns_rooster/services/global_notification_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:sns_rooster/services/fcm_service.dart';
import '../../services/privacy_service.dart';

void showDocumentDialog(
  BuildContext context,
  String? url, {
  String? documentName,
  String? documentType,
}) async {
  if (url == null || url.isEmpty) {
    if (kDebugMode) {
      Logger.warning('showDocumentDialog: URL is null or empty');
    }
    GlobalNotificationService().showError('Document URL is not available');
    return;
  }

  // Log the URL for debugging
  if (kDebugMode) {
    Logger.info('showDocumentDialog: Attempting to load document from: $url');
  }

  // If URL doesn't start with http, it might need authentication
  // Try to fetch via API endpoint with auth token
  String finalUrl = url;
  if (!url.startsWith('http://') && !url.startsWith('https://')) {
    // This shouldn't happen, but handle it
    if (kDebugMode) {
      Logger.warning('showDocumentDialog: Invalid URL format: $url');
    }
    GlobalNotificationService().showError('Invalid document URL');
    return;
  }

  // Check if URL is a direct file path that might need API endpoint
  // If URL contains /uploads/ but returns 404, we need to use API endpoint
  final authProvider = Provider.of<AuthProvider>(context, listen: false);
  if (url.contains('/uploads/') && authProvider.token != null) {
    // Try to construct API endpoint URL
    final baseUrl = ApiConfig.baseUrl;
    // Extract the path after /uploads/
    final pathMatch = RegExp(r'/uploads/(.+)$').firstMatch(url);
    if (pathMatch != null) {
      final filePath = pathMatch.group(1);
      // Try API endpoint: /api/auth/document?path=/uploads/...
      final apiUrl = '$baseUrl/auth/document?path=/uploads/$filePath';
      if (kDebugMode) {
        Logger.info('showDocumentDialog: Trying API endpoint: $apiUrl');
      }
      // For now, keep original URL but log the alternative
      // The backend should serve documents via /api/auth/document endpoint
    }
  }

  // Determine document display name
  String displayName = 'Document';
  if (documentName != null && documentName.isNotEmpty) {
    displayName = documentName;
  } else if (documentType != null && documentType.isNotEmpty) {
    // Convert document type to readable name
    switch (documentType.toLowerCase()) {
      case 'idcard':
      case 'id_card':
        displayName = 'ID Card';
        break;
      case 'passport':
        displayName = 'Passport';
        break;
      case 'education':
        displayName = 'Education Certificate';
        break;
      case 'certificates':
        displayName = 'Certificate';
        break;
      default:
        // Capitalize first letter
        displayName = documentType[0].toUpperCase() + documentType.substring(1);
    }
  }

  final isPdf = finalUrl.toLowerCase().endsWith('.pdf');
  showDialog(
    context: context,
    builder: (context) {
      return Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: SizedBox(
          width: 350,
          height: 500,
          child: Column(
            children: [
              // Header with document name and close button
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            isPdf ? 'PDF Document' : 'Image Document',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(),
              // Document viewer
              Expanded(
                child: isPdf
                    ? SfPdfViewer.network(
                        finalUrl,
                        onDocumentLoadFailed: (details) {
                          if (kDebugMode) {
                            Logger.error('PDF load failed: ${details.error}');
                            Logger.error('URL: $finalUrl');
                          }
                          // Show error in dialog
                          GlobalNotificationService().showError(
                            'Failed to load PDF. The document may not be accessible.',
                          );
                        },
                      )
                    : InteractiveViewer(
                        child: Image.network(
                          finalUrl,
                          fit: BoxFit.contain,
                          headers: authProvider.token != null
                              ? {
                                  'Authorization':
                                      'Bearer ${authProvider.token}',
                                }
                              : null,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Center(
                              child: CircularProgressIndicator(
                                value:
                                    loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                          loadingProgress.expectedTotalBytes!
                                    : null,
                              ),
                            );
                          },
                          errorBuilder: (ctx, error, stack) {
                            if (kDebugMode) {
                              Logger.error('Image load failed: $error');
                              Logger.error('Stack: $stack');
                              Logger.error('URL: $finalUrl');
                            }
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.error_outline,
                                    color: Colors.red,
                                    size: 48,
                                  ),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'Failed to load document',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                    ),
                                    child: Text(
                                      'URL: ${finalUrl.length > 50 ? "${finalUrl.substring(0, 50)}..." : finalUrl}',
                                      style: const TextStyle(fontSize: 12),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'The document may require authentication or the file may not exist.',
                                    style: TextStyle(fontSize: 10),
                                    textAlign: TextAlign.center,
                                  ),
                                  if (kDebugMode) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      'Error: $error',
                                      style: const TextStyle(fontSize: 10),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ],
                              ),
                            );
                          },
                        ),
                      ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// Convert gender value to Camel case
String _formatGender(String? gender) {
  if (gender == null || gender.isEmpty) return 'Prefer Not To Say';

  // Handle different formats
  final lower = gender.toLowerCase();
  switch (lower) {
    case 'male':
      return 'Male';
    case 'female':
      return 'Female';
    case 'other':
      return 'Other';
    case 'prefer_not_to_say':
    case 'prefer not to say':
      return 'Prefer Not To Say';
    default:
      // Convert to Camel case: capitalize first letter of each word
      return gender
          .split('_')
          .map(
            (word) => word.isEmpty
                ? ''
                : word[0].toUpperCase() + word.substring(1).toLowerCase(),
          )
          .join(' ');
  }
}

/// Get display name for document based on type or name
String _getDocumentDisplayName(Map<String, dynamic> document) {
  // First try to use the document name if available
  final docName = document['name']?.toString();
  if (docName != null && docName.isNotEmpty) {
    return docName;
  }

  // Otherwise, convert document type to readable name
  final docType = document['type']?.toString() ?? '';
  switch (docType.toLowerCase()) {
    case 'idcard':
    case 'id_card':
      return 'ID Card';
    case 'passport':
      return 'Passport';
    case 'education':
      return 'Education Certificate';
    case 'certificates':
      return 'Certificate';
    default:
      if (docType.isNotEmpty) {
        // Capitalize first letter
        return docType[0].toUpperCase() + docType.substring(1);
      }
      return 'Document';
  }
}

String formatDate(String? isoString) {
  if (isoString == null || isoString.isEmpty) return '';
  try {
    final date = DateTime.parse(isoString);
    return DateFormat('yyyy-MM-dd').format(date);
  } catch (_) {
    return isoString;
  }
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _emergencyContactController =
      TextEditingController();
  final TextEditingController _emergencyPhoneController =
      TextEditingController();
  final TextEditingController _emergencyContactRelationshipController =
      TextEditingController();
  final TextEditingController _currentPasswordController =
      TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _isLoading = false; // For local operations like save, image pick
  bool _isEditingPersonal = false;
  bool _isEditingEmergency = false;
  bool _isPasswordLoading = false;
  bool _showCurrentPassword = false;
  bool _showNewPassword = false;
  bool _showConfirmPassword = false;

  // Gender selection
  String? _selectedGender;
  final List<String> _genders = [
    'male',
    'female',
    'other',
    'prefer_not_to_say',
  ];

  // Key to force UserAvatar rebuild after profile picture update
  int _avatarKey = DateTime.now().millisecondsSinceEpoch;

  // Timer for delayed tooltips
  final bool _showTooltips = false;

  @override
  void initState() {
    super.initState();

    // Start timer to show tooltips after 3 seconds
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final profileProvider = Provider.of<ProfileProvider>(
        context,
        listen: false,
      );
      if (!profileProvider.isInitialized) {
        profileProvider.refreshProfile().then((_) {
          if (mounted) {
            _loadUserDataInternal(profileProvider);
            // Ensure avatar signed URL is fetched
            profileProvider.fetchAvatarSignedUrl();
          }
        });
      } else {
        _loadUserDataInternal(profileProvider);
        // Ensure avatar signed URL is fetched
        profileProvider.fetchAvatarSignedUrl();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Only reload user data from provider when NOT editing to avoid overwriting user changes
    if (!_isEditingPersonal && !_isEditingEmergency) {
      final profileProvider = Provider.of<ProfileProvider>(context);
      _loadUserDataInternal(profileProvider, preserveGender: false);
    }
  }

  void _loadUserDataInternal(
    ProfileProvider profileProvider, {
    bool preserveGender = false,
  }) {
    final userProfile = profileProvider.profile;
    if (userProfile != null) {
      _firstNameController.text = userProfile['firstName'] ?? '';
      _lastNameController.text = userProfile['lastName'] ?? '';
      _emailController.text = userProfile['email'] ?? '';
      _phoneController.text = userProfile['phone'] ?? '';
      _addressController.text = userProfile['address'] ?? '';

      // Only update gender if we're not preserving it (i.e., not actively editing)
      if (!preserveGender) {
        // Normalize gender value to match dropdown options (backend uses lowercase)
        final genderValue = userProfile['gender']
            ?.toString()
            .toLowerCase()
            .trim();
        if (genderValue != null &&
            genderValue.isNotEmpty &&
            _genders.contains(genderValue)) {
          _selectedGender = genderValue;
        } else {
          _selectedGender = 'prefer_not_to_say';
        }

        if (kDebugMode) {
          Logger.info(
            'Profile loaded - Gender from backend: ${userProfile['gender']}, Normalized: $_selectedGender',
          );
        }
      } else {
        if (kDebugMode) {
          Logger.info(
            'Profile loaded - Preserving current gender selection: $_selectedGender',
          );
        }
      }

      var emergencyContactData = userProfile['emergencyContact'];
      if (emergencyContactData is Map) {
        _emergencyContactController.text = emergencyContactData['name'] ?? '';
        _emergencyPhoneController.text = emergencyContactData['phone'] ?? '';
        _emergencyContactRelationshipController.text =
            emergencyContactData['relationship'] ?? '';
      } else if (emergencyContactData is String) {
        _emergencyContactController.text = emergencyContactData;
        _emergencyPhoneController.text = userProfile['emergencyPhone'] ?? '';
        _emergencyContactRelationshipController.text =
            userProfile['emergencyRelationship'] ?? '';
      } else {
        _emergencyContactController.text =
            userProfile['emergencyContactName'] ?? '';
        _emergencyPhoneController.text =
            userProfile['emergencyContactPhone'] ?? '';
        _emergencyContactRelationshipController.text =
            userProfile['emergencyContactRelationship'] ?? '';
      }
    }
  }

  Future<void> _pickAndUploadImage() async {
    // Check privacy settings before accessing media
    final privacyService = PrivacyService.instance;
    if (!await privacyService.shouldAllowCameraAccess()) {
      GlobalNotificationService().showError(
        'Media access is disabled in Privacy Settings. Please enable it to upload images.',
      );
      return;
    }

    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      // Client-side file type validation
      final allowedExtensions = ['jpg', 'jpeg', 'png', 'gif', 'webp', 'svg'];
      final ext = image.name.split('.').last.toLowerCase();
      if (!allowedExtensions.contains(ext)) {
        GlobalNotificationService().showError(
          'Only image files are allowed for avatars.',
        );
        return;
      }

      setState(() {
        _isLoading = true;
      });

      final profileProvider = Provider.of<ProfileProvider>(
        context,
        listen: false,
      );
      bool success;

      if (kIsWeb) {
        final bytes = await image.readAsBytes();
        success = await profileProvider.updateProfilePicture(
          imageBytes: bytes,
          fileName: image.name,
        );
      } else {
        success = await profileProvider.updateProfilePicture(
          imagePath: image.path,
        );
      }

      setState(() {
        _isLoading = false;
      });

      if (success) {
        // Force refresh avatar signed URL and profile immediately
        try {
          final pp = Provider.of<ProfileProvider>(context, listen: false);

          // print('🔍 DEBUG: Before refresh - Avatar URL: ${pp.avatarSignedUrl}');
          // print('🔍 DEBUG: Before refresh - Profile avatar: ${pp.profile?['avatar']}');

          // First, refresh the profile data to get the new avatar URL
          await pp.refreshProfile();
          // print('🔍 DEBUG: After first refresh - Avatar URL: ${pp.avatarSignedUrl}');

          // Wait a bit longer for backend processing and file availability
          await Future.delayed(const Duration(milliseconds: 500));

          // Force refresh the avatar URL with cache busting
          await pp.forceRefreshAvatarUrl();
          // print('🔍 DEBUG: After force refresh - Avatar URL: ${pp.avatarSignedUrl}');

          // Force another profile refresh to ensure UI updates
          await pp.refreshProfile();
          // print('🔍 DEBUG: After second refresh - Avatar URL: ${pp.avatarSignedUrl}');

          // Force a rebuild of the current screen
          if (mounted) {
            setState(() {});
          }

          // Force UserAvatar to rebuild by updating a key
          _avatarKey = DateTime.now().millisecondsSinceEpoch;
        } catch (e) {
          // print('Error refreshing profile after avatar upload: $e');
        }

        GlobalNotificationService().showSuccess(
          'Profile picture updated successfully!',
        );
      } else {
        GlobalNotificationService().showError(
          profileProvider.error ?? 'Failed to update profile picture.',
        );
      }
    } else {
      // User canceled the picker
      log('No image selected.');
    }
  }

  Future<void> _pickAndUploadDocument(String documentType) async {
    // Check privacy settings before accessing storage
    final privacyService = PrivacyService.instance;
    if (!await privacyService.shouldAllowStorageAccess()) {
      GlobalNotificationService().showError(
        'Storage access is disabled in Privacy Settings. Please enable it to upload files.',
      );
      return;
    }

    try {
      log('Attempting to upload $documentType');

      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'png'],
        allowMultiple: false,
      );

      if (result == null) {
        log('No file selected.');
        GlobalNotificationService().showError('No file selected.');
        return;
      }

      final file = result.files.first;

      // File extension validation
      final fileName = file.name.toLowerCase();
      final validExtensions = ['.pdf', '.jpg', '.jpeg', '.png'];
      final hasValidExtension = validExtensions.any(
        (ext) => fileName.endsWith(ext),
      );

      if (!hasValidExtension) {
        log('Invalid file type: $fileName');
        GlobalNotificationService().showError(
          'Please select a PDF, JPG, or PNG file.',
        );
        return;
      }

      // File size validation
      final fileSize = file.size;
      if (fileSize > 5 * 1024 * 1024) {
        log(
          'File size exceeds limit: ${(fileSize / (1024 * 1024)).toStringAsFixed(2)}MB',
        );
        GlobalNotificationService().showError(
          'File size must be less than 5MB.',
        );
        return;
      }

      setState(() {
        _isLoading = true;
      });

      log('Starting document upload for type: $documentType');
      log(
        'File details - Name: ${file.name}, Size: ${(file.size / 1024).toStringAsFixed(2)}KB',
      );

      final profileProvider = Provider.of<ProfileProvider>(
        context,
        listen: false,
      );
      bool success = false;
      if (kIsWeb) {
        // On web, upload using bytes
        log('Uploading document on web using bytes');
        success = await profileProvider.uploadDocument(
          fileBytes: file.bytes!,
          fileName: file.name,
          documentType: documentType,
        );
      } else {
        // On mobile/desktop, upload using file path
        log(
          'Uploading document on mobile/desktop using file path: ${file.path}',
        );
        success = await profileProvider.uploadDocument(
          filePath: file.path!,
          documentType: documentType,
        );
      }

      setState(() {
        _isLoading = false;
      });

      if (success) {
        log('Document uploaded successfully.');
        await profileProvider.refreshProfile();
        GlobalNotificationService().showSuccess(
          'Document uploaded successfully!',
        );
      } else {
        log('Failed to upload document: ${profileProvider.error}');
        final errorMessage =
            profileProvider.error ?? 'Failed to upload document.';
        GlobalNotificationService().showError(errorMessage);

        // Show more detailed error in debug mode
        if (kDebugMode) {
          log('Detailed upload error: ${profileProvider.error}');
        }
      }
    } catch (e) {
      log('Error during document upload: $e');
      GlobalNotificationService().showError(
        'An error occurred during upload. Please try again.',
      );
    }
  }

  Future<void> _savePersonalInfo() async {
    // Validation for personal information only
    String firstName = _firstNameController.text.trim();
    String lastName = _lastNameController.text.trim();
    String phone = _phoneController.text.trim();
    String address = _addressController.text.trim();
    final phoneRegex = RegExp(r'^\+?[0-9]{8,15}$');

    if (firstName.isEmpty) {
      GlobalNotificationService().showError('First name is required.');
      return;
    }
    if (lastName.isEmpty) {
      GlobalNotificationService().showError('Last name is required.');
      return;
    }
    // Email validation removed since email is read-only and already verified
    if (phone.isEmpty || !phoneRegex.hasMatch(phone)) {
      GlobalNotificationService().showError(
        'Please enter a valid phone number (8-15 digits, digits only).',
      );
      return;
    }
    if (address.isEmpty) {
      GlobalNotificationService().showError('Address is required.');
      return;
    }
    if (_selectedGender == null || _selectedGender!.isEmpty) {
      GlobalNotificationService().showError('Please select your gender.');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final profileProvider = Provider.of<ProfileProvider>(
      context,
      listen: false,
    );

    // CRITICAL: Capture the gender value directly from the dropdown's current state
    // Don't rely on _selectedGender variable which might be stale
    String genderToSave = _selectedGender ?? 'prefer_not_to_say';

    // Ensure gender is set before saving
    if (genderToSave.isEmpty || !_genders.contains(genderToSave)) {
      if (kDebugMode) {
        Logger.warning(
          '[SAVE] Invalid gender value: $genderToSave, defaulting to prefer_not_to_say',
        );
      }
      genderToSave = 'prefer_not_to_say';
    }

    if (kDebugMode) {
      Logger.info('[SAVE] ===== SAVING PERSONAL INFO =====');
      Logger.info('[SAVE] _selectedGender variable: $_selectedGender');
      Logger.info('[SAVE] genderToSave (final value): $genderToSave');
      Logger.info('[SAVE] Is editing: $_isEditingPersonal');
    }

    Map<String, dynamic> updates = {
      'firstName': _firstNameController.text,
      'lastName': _lastNameController.text,
      'phone': _phoneController.text,
      'address': _addressController.text,
      'gender': genderToSave, // Use the captured value
    };

    if (kDebugMode) {
      Logger.info('[SAVE] Updates payload: $updates');
      Logger.info('[SAVE] Gender in payload: ${updates['gender']}');
      Logger.info('[SAVE] ===== END SAVE PREP =====');
    }

    try {
      final ok = await profileProvider.updateProfile(updates);
      if (ok) {
        await profileProvider.refreshProfile();
        // Re-sync controllers with latest provider data
        final p = profileProvider.profile;
        if (p != null) {
          _firstNameController.text = (p['firstName'] ?? '').toString();
          _lastNameController.text = (p['lastName'] ?? '').toString();
          _phoneController.text = (p['phone'] ?? p['phoneNumber'] ?? '')
              .toString();
          _addressController.text = (p['address'] ?? '').toString();

          // Update gender from backend response - backend should return the saved value
          final backendGender = p['gender']?.toString().toLowerCase().trim();
          if (backendGender != null &&
              backendGender.isNotEmpty &&
              _genders.contains(backendGender)) {
            _selectedGender = backendGender;
          } else {
            // Fallback to what we just saved if backend doesn't return it
            _selectedGender = _selectedGender ?? 'prefer_not_to_say';
          }

          if (kDebugMode) {
            Logger.info(
              'After save - Backend gender: ${p['gender']}, Normalized: $backendGender, Using: $_selectedGender',
            );
          }
        }

        // Turn off editing mode after successful save
        setState(() {
          _isEditingPersonal = false;
        });

        GlobalNotificationService().showSuccess(
          'Personal information updated successfully!',
        );
      } else {
        GlobalNotificationService().showError(
          profileProvider.error ?? 'Failed to update personal information.',
        );
      }
    } catch (e) {
      GlobalNotificationService().showError(
        'Failed to update personal information: $e',
      );
    } finally {
      setState(() {
        _isLoading = false;
        _isEditingPersonal = false;
      });
    }
  }

  Future<void> _saveEmergencyContact() async {
    // Validation for emergency contact only
    String emergencyContact = _emergencyContactController.text.trim();
    String emergencyPhone = _emergencyPhoneController.text.trim();
    String emergencyRelationship = _emergencyContactRelationshipController.text
        .trim();

    if (emergencyContact.isEmpty) {
      GlobalNotificationService().showError(
        'Emergency contact name is required.',
      );
      return;
    }
    if (emergencyPhone.isEmpty || emergencyPhone.length < 8) {
      GlobalNotificationService().showError(
        'Please enter a valid emergency contact phone (at least 8 digits).',
      );
      return;
    }
    if (emergencyRelationship.isEmpty) {
      GlobalNotificationService().showError('Relationship is required.');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final profileProvider = Provider.of<ProfileProvider>(
      context,
      listen: false,
    );
    Map<String, dynamic> updates = {
      'emergencyContact': _emergencyContactController.text,
      'emergencyPhone': _emergencyPhoneController.text,
      'emergencyRelationship': _emergencyContactRelationshipController.text,
    };

    try {
      final ok = await profileProvider.updateProfile(updates);
      if (ok) {
        await profileProvider.refreshProfile();
        final p = profileProvider.profile;
        if (p != null) {
          _emergencyContactController.text = (p['emergencyContact'] ?? '')
              .toString();
          _emergencyPhoneController.text = (p['emergencyPhone'] ?? '')
              .toString();
          _emergencyContactRelationshipController.text =
              (p['emergencyRelationship'] ?? '').toString();
        }
        GlobalNotificationService().showSuccess(
          'Emergency contact updated successfully!',
        );
      } else {
        GlobalNotificationService().showError(
          profileProvider.error ?? 'Failed to update emergency contact.',
        );
      }
    } catch (e) {
      GlobalNotificationService().showError(
        'Failed to update emergency contact: $e',
      );
    } finally {
      setState(() {
        _isLoading = false;
        _isEditingEmergency = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;
    if (user == null) {
      // Not logged in, show fallback or redirect
      return const Scaffold(
        body: Center(child: Text('Not logged in. Please log in.')),
      );
    }
    final isAdmin = user['role'] == 'admin';
    if (isAdmin) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Profile'),
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Theme.of(context).colorScheme.onPrimary,
          elevation: 0,
        ),
        body: const Center(child: Text('Access denied')), // Or redirect
        drawer: const AdminSideNavigation(currentRoute: '/profile'),
      );
    }
    final theme = Theme.of(context);
    return Consumer<ProfileProvider>(
      builder: (context, profileProvider, _) {
        if (profileProvider.isLoading || profileProvider.profile == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Profile')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        // Only update text fields with latest profile data when not editing
        // This prevents overwriting user changes while they're editing
        if (!_isEditingPersonal && !_isEditingEmergency) {
          _loadUserDataInternal(profileProvider, preserveGender: false);
        }

        // Fix avatar URL priority: Use profile.avatar first, then profilePicture, then signed URL as fallback
        String? avatarUrl = profileProvider.profile?['avatar'];

        // Only check profilePicture if avatar is not available
        if (avatarUrl == null || avatarUrl.isEmpty || avatarUrl.trim() == '') {
          avatarUrl = profileProvider.profile?['profilePicture'];
        }

        // Only use signed URL if neither avatar nor profilePicture are available
        if (avatarUrl == null || avatarUrl.isEmpty || avatarUrl.trim() == '') {
          final signedUrl = profileProvider.avatarSignedUrl;
          if (signedUrl != null &&
              signedUrl.isNotEmpty &&
              signedUrl.trim() != '' &&
              !signedUrl.contains('appspot.com/firebasestorage.app')) {
            avatarUrl = signedUrl;
          }
        }

        // Debug logging
        if (kDebugMode) {
          Logger.info(
            '[AVATAR] Profile avatar: ${profileProvider.profile?['avatar']}',
          );
          Logger.info(
            '[AVATAR] Profile profilePicture: ${profileProvider.profile?['profilePicture']}',
          );
          Logger.info(
            '[AVATAR] ProfileProvider avatarSignedUrl: ${profileProvider.avatarSignedUrl}',
          );
          Logger.info('[AVATAR] Final avatarUrl: $avatarUrl');
        }

        // Only use placeholder as absolute last resort
        if (avatarUrl == null || avatarUrl.isEmpty || avatarUrl.trim() == '') {
          avatarUrl = null; // Let UserAvatar widget handle the placeholder
        }

        // print(
        //     'DEBUG: Profile Screen - avatarSignedUrl = ${profileProvider.avatarSignedUrl}');
        // print(
        //     'DEBUG: Profile Screen - profile.avatar = ${profileProvider.profile?['avatar']}');
        // print(
        //     'DEBUG: Profile Screen - profile.profilePicture = ${profileProvider.profile?['profilePicture']}');
        // print('DEBUG: Profile Screen - Final avatarUrl used = $avatarUrl');
        return Scaffold(
          appBar: AppBar(
            title: const Text('Profile'),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () async {
                  final profileProvider = Provider.of<ProfileProvider>(
                    context,
                    listen: false,
                  );
                  await profileProvider.forceRefreshProfile();
                },
                tooltip: 'Refresh Profile',
              ),
            ],
          ),
          drawer: const AppDrawer(),
          body: profileProvider.isLoading && !_isLoading
              ? const Center(child: CircularProgressIndicator())
              : Stack(
                  children: [
                    // Dotted background throughout the entire page
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _DotPatternPainter(
                          color: AppTheme.primary.withValues(alpha: 0.15),
                        ),
                      ),
                    ),
                    // Main content
                    SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Profile Header
                          Center(
                            child: Consumer<ProfileProvider>(
                              builder: (context, profileProvider, _) {
                                final profile = profileProvider.profile;

                                // Get the best available avatar URL from provider
                                String? displayAvatarUrl =
                                    profileProvider.avatarSignedUrl;
                                if (displayAvatarUrl == null ||
                                    displayAvatarUrl.isEmpty) {
                                  displayAvatarUrl = profile?['avatar'];
                                }
                                if (displayAvatarUrl == null ||
                                    displayAvatarUrl.isEmpty) {
                                  displayAvatarUrl = profile?['profilePicture'];
                                }
                                // Fallback to outer scope avatarUrl if still null
                                if (displayAvatarUrl == null ||
                                    displayAvatarUrl.isEmpty) {
                                  displayAvatarUrl = avatarUrl;
                                }

                                // Fetch signed URL if profile exists but signed URL is missing
                                if (profile != null &&
                                    (profileProvider.avatarSignedUrl == null ||
                                        profileProvider
                                            .avatarSignedUrl!
                                            .isEmpty) &&
                                    (profile['avatar'] != null ||
                                        profile['profilePicture'] != null)) {
                                  WidgetsBinding.instance.addPostFrameCallback((
                                    _,
                                  ) {
                                    profileProvider.fetchAvatarSignedUrl();
                                  });
                                }

                                if (kDebugMode) {
                                  Logger.info(
                                    '[AVATAR HEADER] Using displayAvatarUrl: $displayAvatarUrl',
                                  );
                                  Logger.info(
                                    '[AVATAR HEADER] Provider signedUrl: ${profileProvider.avatarSignedUrl}',
                                  );
                                  Logger.info(
                                    '[AVATAR HEADER] Profile avatar: ${profile?['avatar']}',
                                  );
                                  Logger.info(
                                    '[AVATAR HEADER] Profile profilePicture: ${profile?['profilePicture']}',
                                  );
                                }

                                return Column(
                                  children: [
                                    Container(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: AppTheme.primary,
                                          width: 3,
                                        ),
                                      ),
                                      child: UserAvatar(
                                        key: ValueKey(
                                          'avatar_${_avatarKey}_$displayAvatarUrl',
                                        ),
                                        avatarUrl: displayAvatarUrl,
                                        radius: 48,
                                        userId: user['_id'],
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      profile?['fullName'] ??
                                          profile?['firstName'] ??
                                          '',
                                      style: theme.textTheme.titleLarge,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      profile?['email'] ?? '',
                                      style: theme.textTheme.bodyMedium,
                                    ),
                                    const SizedBox(height: 8),
                                    // Employment Type/Subtype display
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const Icon(
                                          Icons.work_outline,
                                          size: 18,
                                          color: Colors.blueGrey,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Employment: '
                                          '${(profile?['employeeType'] ?? 'Not set')}'
                                          '${(profile?['employeeSubType'] != null && (profile?['employeeSubType'] as String).isNotEmpty) ? ' - ${profile?['employeeSubType']}' : ''}',
                                          style: theme.textTheme.bodyMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.w500,
                                              ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    // Department and Position display
                                    if (profile?['department'] != null ||
                                        profile?['position'] != null) ...[
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          const Icon(
                                            Icons.business,
                                            size: 16,
                                            color: Colors.blueGrey,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            '${profile?['department'] ?? 'Unknown Department'}',
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w500,
                                                  color: Colors.blue[700],
                                                ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          const Icon(
                                            Icons.work,
                                            size: 16,
                                            color: Colors.blueGrey,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            '${profile?['position'] ?? 'Unknown Position'}',
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w500,
                                                  color: Colors.blue[700],
                                                ),
                                          ),
                                        ],
                                      ),
                                    ],
                                    const SizedBox(height: 8),
                                    ElevatedButton.icon(
                                      onPressed: _pickAndUploadImage,
                                      icon: const Icon(Icons.camera_alt),
                                      label: const Text('Change Photo'),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 24),
                          // Personal Information Section
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surface,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 10,
                                  spreadRadius: 0,
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Personal Information',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        _isEditingPersonal
                                            ? Icons.check
                                            : Icons.edit,
                                        color: Colors.blueAccent,
                                      ),
                                      onPressed: () async {
                                        if (_isEditingPersonal) {
                                          await _savePersonalInfo();
                                        } else {
                                          // Log current gender before entering edit mode
                                          if (kDebugMode) {
                                            Logger.info(
                                              '[EDIT MODE] Entering edit mode. Current _selectedGender: $_selectedGender',
                                            );
                                          }
                                          setState(() {
                                            _isEditingPersonal = true;
                                          });
                                          // Log after entering edit mode
                                          if (kDebugMode) {
                                            Logger.info(
                                              '[EDIT MODE] Edit mode enabled. _selectedGender: $_selectedGender',
                                            );
                                          }
                                        }
                                      },
                                      tooltip: _showTooltips
                                          ? (_isEditingPersonal
                                                ? 'Save Personal Information'
                                                : 'Edit Personal Information')
                                          : null,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                _buildTextField(
                                  controller: _firstNameController,
                                  label: 'First Name',
                                  icon: Icons.person,
                                  enabled: _isEditingPersonal,
                                ),
                                _buildTextField(
                                  controller: _lastNameController,
                                  label: 'Last Name',
                                  icon: Icons.person,
                                  enabled: _isEditingPersonal,
                                ),
                                _buildTextField(
                                  controller: _emailController,
                                  label: 'Email',
                                  icon: Icons.email,
                                  enabled: false,
                                  keyboardType: TextInputType.emailAddress,
                                ),
                                _buildTextField(
                                  controller: _phoneController,
                                  label: 'Phone',
                                  icon: Icons.phone,
                                  enabled: _isEditingPersonal,
                                  keyboardType: TextInputType.phone,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                ),
                                _buildTextField(
                                  controller: _addressController,
                                  label: 'Address',
                                  icon: Icons.home,
                                  enabled: _isEditingPersonal,
                                ),
                                // Gender Selection - Use TextFormField when not editing to match other fields
                                _isEditingPersonal
                                    ? Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 16,
                                        ),
                                        child: Builder(
                                          builder: (context) {
                                            // Log the current value when dropdown is built
                                            if (kDebugMode) {
                                              Logger.info(
                                                '[GENDER DROPDOWN] Building dropdown with _selectedGender: $_selectedGender',
                                              );
                                            }
                                            final currentValue =
                                                (_selectedGender != null &&
                                                    _genders.contains(
                                                      _selectedGender,
                                                    ))
                                                ? _selectedGender
                                                : 'prefer_not_to_say';
                                            if (kDebugMode &&
                                                currentValue !=
                                                    _selectedGender) {
                                              Logger.warning(
                                                '[GENDER DROPDOWN] Value mismatch! _selectedGender: $_selectedGender, currentValue: $currentValue',
                                              );
                                            }
                                            return DropdownButtonFormField<
                                              String
                                            >(
                                              key: ValueKey(
                                                'gender_dropdown_$_selectedGender',
                                              ),
                                              initialValue: currentValue,
                                              decoration: InputDecoration(
                                                labelText: 'Gender',
                                                prefixIcon: const Icon(
                                                  Icons.person_outline,
                                                ),
                                                border: OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                                filled: true,
                                                fillColor: Colors.white,
                                              ),
                                              items: _genders.map((
                                                String gender,
                                              ) {
                                                return DropdownMenuItem<String>(
                                                  value: gender,
                                                  child: Text(
                                                    _formatGender(gender),
                                                  ),
                                                );
                                              }).toList(),
                                              onChanged: (String? newValue) {
                                                if (kDebugMode) {
                                                  Logger.info(
                                                    '[GENDER DROPDOWN] ===== onChanged TRIGGERED =====',
                                                  );
                                                  Logger.info(
                                                    '[GENDER DROPDOWN] newValue: $newValue',
                                                  );
                                                  Logger.info(
                                                    '[GENDER DROPDOWN] current _selectedGender: $_selectedGender',
                                                  );
                                                }
                                                if (newValue != null &&
                                                    _genders.contains(
                                                      newValue,
                                                    )) {
                                                  // CRITICAL: Update state immediately and synchronously
                                                  if (kDebugMode) {
                                                    Logger.info(
                                                      '[GENDER DROPDOWN] Updating _selectedGender from "$_selectedGender" to "$newValue"',
                                                    );
                                                  }

                                                  // Update the variable first
                                                  _selectedGender = newValue;

                                                  // Then trigger rebuild
                                                  if (mounted) {
                                                    setState(() {
                                                      // Explicitly set it again in setState to ensure it's captured
                                                      _selectedGender =
                                                          newValue;
                                                    });
                                                  }

                                                  if (kDebugMode) {
                                                    Logger.info(
                                                      '[GENDER DROPDOWN] After setState - _selectedGender: $_selectedGender',
                                                    );
                                                    Logger.info(
                                                      '[GENDER DROPDOWN] ===== onChanged COMPLETE =====',
                                                    );
                                                  }
                                                } else {
                                                  if (kDebugMode) {
                                                    Logger.warning(
                                                      '[GENDER DROPDOWN] Invalid value! newValue: $newValue, valid genders: $_genders',
                                                    );
                                                  }
                                                }
                                              },
                                            );
                                          },
                                        ),
                                      )
                                    : Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 16,
                                        ),
                                        child: TextFormField(
                                          controller: TextEditingController(
                                            text: _selectedGender != null
                                                ? _formatGender(_selectedGender)
                                                : 'Not specified',
                                          ),
                                          enabled: false,
                                          decoration: InputDecoration(
                                            labelText: 'Gender',
                                            prefixIcon: const Icon(
                                              Icons.person_outline,
                                            ),
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            filled: true,
                                            fillColor: Colors.grey[100],
                                          ),
                                        ),
                                      ),
                              ],
                            ),
                          ),
                          if (kDebugMode) ...[
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
                                    const Row(
                                      children: [
                                        Icon(
                                          Icons.bug_report,
                                          color: Colors.orange,
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          'Debug Tools',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const Divider(),
                                    // Test features - only show in debug mode
                                    if (kDebugMode)
                                      ListTile(
                                        leading: const Icon(
                                          Icons.token,
                                          color: Colors.green,
                                        ),
                                        title: const Text(
                                          'Test FCM Token Generation',
                                        ),
                                        subtitle: const Text(
                                          'Manually test FCM token generation',
                                        ),
                                        trailing: const Icon(Icons.refresh),
                                        onTap: () async {
                                          try {
                                            final fcmService = FCMService();
                                            await fcmService
                                                .testFCMTokenGeneration();
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    'FCM token test completed. Check logs for details.',
                                                  ),
                                                  backgroundColor: Colors.green,
                                                ),
                                              );
                                            }
                                          } catch (e) {
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text('Error: $e'),
                                                  backgroundColor: Colors.red,
                                                ),
                                              );
                                            }
                                          }
                                        },
                                      ),
                                    ListTile(
                                      leading: const Icon(
                                        Icons.cloud_upload,
                                        color: Colors.blue,
                                      ),
                                      title: const Text(
                                        'Save FCM Token to Database',
                                      ),
                                      subtitle: const Text(
                                        'Manually trigger FCM token saving',
                                      ),
                                      trailing: const Icon(Icons.send),
                                      onTap: () async {
                                        try {
                                          final authProvider =
                                              Provider.of<AuthProvider>(
                                                context,
                                                listen: false,
                                              );
                                          await authProvider
                                              .saveFCMTokenManually();
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'FCM token save attempted. Check logs for details.',
                                                ),
                                                backgroundColor: Colors.blue,
                                              ),
                                            );
                                          }
                                        } catch (e) {
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text('Error: $e'),
                                                backgroundColor: Colors.red,
                                              ),
                                            );
                                          }
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 24),
                          Card(
                            elevation: 2,
                            margin: const EdgeInsets.symmetric(horizontal: 16),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'Emergency Contact',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      IconButton(
                                        icon: Icon(
                                          _isEditingEmergency
                                              ? Icons.check
                                              : Icons.edit,
                                          color: Colors.blueAccent,
                                        ),
                                        onPressed: () async {
                                          if (_isEditingEmergency) {
                                            await _saveEmergencyContact();
                                          } else {
                                            setState(() {
                                              _isEditingEmergency = true;
                                            });
                                          }
                                        },
                                        tooltip: _showTooltips
                                            ? (_isEditingEmergency
                                                  ? 'Save Emergency Contact'
                                                  : 'Edit Emergency Contact')
                                            : null,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  _buildTextField(
                                    controller: _emergencyContactController,
                                    label: 'Contact Name',
                                    icon: Icons.person_pin_rounded,
                                    enabled: _isEditingEmergency,
                                  ),
                                  _buildTextField(
                                    controller: _emergencyPhoneController,
                                    label: 'Contact Phone',
                                    icon: Icons.phone_iphone,
                                    enabled: _isEditingEmergency,
                                    keyboardType: TextInputType.phone,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                    ],
                                  ),
                                  _buildTextField(
                                    controller:
                                        _emergencyContactRelationshipController,
                                    label: 'Relationship',
                                    icon: Icons.people,
                                    enabled: _isEditingEmergency,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),
                          // Password Change Section
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surface,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 10,
                                  spreadRadius: 0,
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.lock_outline,
                                      color: theme.colorScheme.primary,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Change Password',
                                      style: theme.textTheme.titleLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                _buildPasswordField(
                                  controller: _currentPasswordController,
                                  label: 'Current Password',
                                  icon: Icons.lock,
                                  showPassword: _showCurrentPassword,
                                  onToggleVisibility: () {
                                    setState(() {
                                      _showCurrentPassword =
                                          !_showCurrentPassword;
                                    });
                                  },
                                ),
                                const SizedBox(height: 16),
                                _buildPasswordField(
                                  controller: _newPasswordController,
                                  label: 'New Password',
                                  icon: Icons.lock_outline,
                                  showPassword: _showNewPassword,
                                  onToggleVisibility: () {
                                    setState(() {
                                      _showNewPassword = !_showNewPassword;
                                    });
                                  },
                                ),
                                const SizedBox(height: 16),
                                _buildPasswordField(
                                  controller: _confirmPasswordController,
                                  label: 'Confirm New Password',
                                  icon: Icons.lock_outline,
                                  showPassword: _showConfirmPassword,
                                  onToggleVisibility: () {
                                    setState(() {
                                      _showConfirmPassword =
                                          !_showConfirmPassword;
                                    });
                                  },
                                ),
                                const SizedBox(height: 24),
                                SizedBox(
                                  width: double.infinity,
                                  height: 50,
                                  child: ElevatedButton(
                                    onPressed: _isPasswordLoading
                                        ? null
                                        : _changePassword,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          theme.colorScheme.secondary,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      elevation: 2,
                                    ),
                                    child: _isPasswordLoading
                                        ? const SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                    Colors.white,
                                                  ),
                                            ),
                                          )
                                        : const Text(
                                            'Change Password',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 32),
                          // Document Upload Section
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surface,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 10,
                                  spreadRadius: 0,
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.file_present,
                                      color: theme.colorScheme.primary,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Document Upload',
                                      style: theme.textTheme.titleLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        icon: const Icon(Icons.file_present),
                                        label: const Text('Upload ID Card'),
                                        onPressed: () async {
                                          await _pickAndUploadDocument(
                                            'idCard',
                                          );
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        icon: const Icon(Icons.file_present),
                                        label: const Text('Upload Passport'),
                                        onPressed: () async {
                                          await _pickAndUploadDocument(
                                            'passport',
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Accepted formats: PDF, JPG, PNG',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                // Document status display
                                Consumer<ProfileProvider>(
                                  builder: (context, profileProvider, _) {
                                    final profile = profileProvider.profile;
                                    final documents =
                                        profile?['documents'] ?? [];
                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        ...documents.asMap().entries.map((
                                          entry,
                                        ) {
                                          final document = entry.value;
                                          final String? docPath =
                                              document['path']?.toString();
                                          final bool hasFile =
                                              docPath != null &&
                                              docPath.isNotEmpty;

                                          // Construct document URL
                                          String? docUrl;
                                          if (hasFile) {
                                            // Check if document has a signedUrl or fullUrl field
                                            final signedUrl =
                                                document['signedUrl']
                                                    ?.toString();
                                            final fullUrl = document['url']
                                                ?.toString();

                                            if (signedUrl != null &&
                                                signedUrl.isNotEmpty) {
                                              docUrl = signedUrl;
                                            } else if (fullUrl != null &&
                                                fullUrl.isNotEmpty) {
                                              docUrl = fullUrl;
                                            } else {
                                              // Check if docPath is already a full URL
                                              if (docPath.startsWith(
                                                    'http://',
                                                  ) ||
                                                  docPath.startsWith(
                                                    'https://',
                                                  )) {
                                                docUrl = docPath;
                                              } else {
                                                // Documents need to be accessed via API endpoint with authentication
                                                // Direct /uploads/ paths return 404, so use API endpoint
                                                final baseUrl =
                                                    ApiConfig.baseUrl;
                                                // Ensure docPath starts with /
                                                final path =
                                                    docPath.startsWith('/')
                                                    ? docPath
                                                    : '/$docPath';

                                                // Use API endpoint: /api/auth/document?path=...
                                                // This endpoint should serve documents with authentication
                                                docUrl =
                                                    '$baseUrl/auth/document?path=${Uri.encodeComponent(path)}';

                                                if (kDebugMode) {
                                                  Logger.info(
                                                    'Using API endpoint for document: $docUrl',
                                                  );
                                                }
                                              }
                                            }

                                            if (kDebugMode) {
                                              Logger.info(
                                                'Document URL constructed: $docUrl',
                                              );
                                              Logger.info(
                                                'Original path: $docPath',
                                              );
                                              Logger.info(
                                                'Document data: $document',
                                              );
                                            }
                                          }
                                          String status =
                                              (document['status'] ?? 'pending')
                                                  .toString();
                                          if (!hasFile) {
                                            status = 'not_uploaded';
                                          }
                                          Color statusColor;
                                          String statusLabel;
                                          switch (status) {
                                            case 'verified':
                                              statusColor = Colors.green;
                                              statusLabel = 'Verified';
                                              break;
                                            case 'rejected':
                                              statusColor = Colors.red;
                                              statusLabel = 'Rejected';
                                              break;
                                            case 'not_uploaded':
                                              statusColor = Colors.grey;
                                              statusLabel = 'Not Uploaded';
                                              break;
                                            default:
                                              statusColor = Colors.orange;
                                              statusLabel = 'Pending';
                                          }
                                          return ListTile(
                                            leading: const Icon(
                                              Icons.file_present,
                                              color: Colors.blue,
                                            ),
                                            title: Row(
                                              children: [
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      // Show document type/name
                                                      Text(
                                                        _getDocumentDisplayName(
                                                          document,
                                                        ),
                                                        style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                      // Show file name if available
                                                      if (hasFile &&
                                                          (document['fileName'] !=
                                                                  null ||
                                                              document['filename'] !=
                                                                  null))
                                                        Text(
                                                          document['fileName'] ??
                                                              document['filename'] ??
                                                              '',
                                                          style: TextStyle(
                                                            fontSize: 12,
                                                            color: Colors
                                                                .grey[600],
                                                          ),
                                                          maxLines: 1,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                        ),
                                                    ],
                                                  ),
                                                ),
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 2,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: statusColor
                                                        .withValues(
                                                          alpha: 0.15,
                                                        ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                  ),
                                                  child: Text(
                                                    statusLabel,
                                                    style: TextStyle(
                                                      color: statusColor,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            subtitle: hasFile
                                                ? Text(
                                                    'Uploaded: ${document['fileName'] ?? (document['filename'] ?? 'Unknown file')}',
                                                  )
                                                : const Text(
                                                    'No file uploaded',
                                                  ),
                                            trailing: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                IconButton(
                                                  icon: const Icon(
                                                    Icons.visibility,
                                                  ),
                                                  tooltip: 'View',
                                                  onPressed: hasFile
                                                      ? () {
                                                          // Get document name and type for display
                                                          final docName =
                                                              document['name']
                                                                  ?.toString();
                                                          final docType =
                                                              document['type']
                                                                  ?.toString();
                                                          showDocumentDialog(
                                                            context,
                                                            docUrl,
                                                            documentName:
                                                                docName,
                                                            documentType:
                                                                docType,
                                                          );
                                                        }
                                                      : null,
                                                ),
                                                if (status == 'rejected')
                                                  IconButton(
                                                    icon: const Icon(
                                                      Icons.refresh,
                                                      color: Colors.orange,
                                                    ),
                                                    tooltip: 'Replace',
                                                    onPressed: () async {
                                                      await _pickAndUploadDocument(
                                                        document['type'] ?? '',
                                                      );
                                                    },
                                                  ),
                                              ],
                                            ),
                                          );
                                        }).toList(),
                                      ],
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 32),
                          // Education Section (conditional)
                          Consumer<AdminSettingsProvider>(
                            builder: (context, adminSettings, _) {
                              // Only show if explicitly enabled
                              if (adminSettings.educationSectionEnabled) {
                                return Column(
                                  children: [
                                    _EducationSection(
                                      showTooltips: _showTooltips,
                                    ),
                                    const SizedBox(height: 32),
                                  ],
                                );
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                          // Certificates Section (conditional)
                          Consumer<AdminSettingsProvider>(
                            builder: (context, adminSettings, _) {
                              // Only show if explicitly enabled
                              if (adminSettings.certificatesSectionEnabled) {
                                return _CertificateSection(
                                  showTooltips: _showTooltips,
                                );
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                          // Save buttons are now integrated into individual sections
                        ],
                      ),
                    ),
                    if (_isLoading)
                      Positioned.fill(
                        child: Container(
                          color: Colors.black.withValues(alpha: 0.3),
                          child: const Center(
                            child: CircularProgressIndicator(),
                          ),
                        ),
                      ),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool enabled = true,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        enabled: enabled,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: enabled ? Colors.white : Colors.grey[100],
        ),
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
      ),
    );
  }

  Future<void> _changePassword() async {
    if (_newPasswordController.text != _confirmPasswordController.text) {
      GlobalNotificationService().showError('New passwords do not match.');
      return;
    }

    if (_newPasswordController.text.length < 6) {
      GlobalNotificationService().showError(
        'New password must be at least 6 characters long.',
      );
      return;
    }

    setState(() {
      _isPasswordLoading = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final result = await authProvider.changePassword(
        _currentPasswordController.text,
        _newPasswordController.text,
      );

      if (result['success'] == true) {
        GlobalNotificationService().showSuccess(
          'Password changed successfully!',
        );
        _currentPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();
      } else {
        GlobalNotificationService().showError(
          result['message'] ?? 'Failed to change password.',
        );
      }
    } catch (e) {
      log('Error changing password: $e');
      GlobalNotificationService().showError(
        'An error occurred while changing your password.',
      );
    } finally {
      setState(() {
        _isPasswordLoading = false;
      });
    }
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool showPassword,
    required VoidCallback onToggleVisibility,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        obscureText: !showPassword,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          suffixIcon: IconButton(
            icon: Icon(showPassword ? Icons.visibility_off : Icons.visibility),
            onPressed: onToggleVisibility,
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _emergencyContactController.dispose();
    _emergencyPhoneController.dispose();
    _emergencyContactRelationshipController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _emergencyContactRelationshipController.dispose();
    super.dispose();
  }
}

// --- Education Section Widget ---
class _EducationSection extends StatelessWidget {
  final bool showTooltips;

  const _EducationSection({this.showTooltips = false});

  @override
  Widget build(BuildContext context) {
    final profileProvider = Provider.of<ProfileProvider>(context);
    final educationList = List<Map<String, dynamic>>.from(
      profileProvider.profile?['education'] ?? [],
    );
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Education',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.add, color: Colors.blueAccent),
                  onPressed: () => _showEducationDialog(context, null, null),
                ),
              ],
            ),
            ...educationList.isEmpty
                ? [
                    const Text(
                      'No education added.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ]
                : educationList.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final edu = entry.value;
                    final startDate =
                        edu['startDate'] != null &&
                            edu['startDate'].toString().isNotEmpty
                        ? edu['startDate'].toString().substring(0, 10)
                        : null;
                    final endDate =
                        edu['endDate'] != null &&
                            edu['endDate'].toString().isNotEmpty
                        ? edu['endDate'].toString().substring(0, 10)
                        : null;
                    final dateRange = (startDate != null && endDate != null)
                        ? '$startDate to $endDate'
                        : (startDate ?? (endDate ?? ''));
                    return ListTile(
                      leading: const Icon(Icons.school, color: Colors.blue),
                      title: Text(edu['degree'] ?? ''),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            [
                                  edu['institution'] ?? '',
                                  edu['fieldOfStudy'] ?? '',
                                  if (dateRange.isNotEmpty) dateRange,
                                ]
                                .where(
                                  (e) => e != null && e.toString().isNotEmpty,
                                )
                                .join(' â€¢ '),
                          ),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if ((edu['certificate'] ?? '').toString().isNotEmpty)
                            IconButton(
                              icon: const Icon(
                                Icons.remove_red_eye,
                                color: Colors.blueAccent,
                              ),
                              tooltip: 'View Certificate',
                              onPressed: () async {
                                showDocumentDialog(
                                  context,
                                  edu['certificate'],
                                  documentName: 'Education Certificate',
                                  documentType: 'education',
                                );
                              },
                            ),
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.orange),
                            onPressed: () =>
                                _showEducationDialog(context, edu, idx),
                            tooltip: showTooltips ? 'Edit Education' : null,
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _deleteEducation(context, idx),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
          ],
        ),
      ),
    ); // <-- closes the Card widget
  }

  void _showEducationDialog(
    BuildContext context,
    Map<String, dynamic>? edu,
    int? idx,
  ) {
    final degreeController = TextEditingController(text: edu?['degree'] ?? '');
    final institutionController = TextEditingController(
      text: edu?['institution'] ?? '',
    );
    final fieldOfStudyController = TextEditingController(
      text: edu?['fieldOfStudy'] ?? '',
    );
    final startDateController = TextEditingController(
      text: formatDate(edu?['startDate']),
    );
    final endDateController = TextEditingController(
      text: formatDate(edu?['endDate']),
    );
    String? documentPath = edu?['certificate'] ?? edu?['document'];
    ValueNotifier<bool> isUploading = ValueNotifier(false);
    ValueNotifier<bool> isSaving = ValueNotifier(false);
    ValueNotifier<String?> errorText = ValueNotifier(null);
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(idx == null ? 'Add Education' : 'Edit Education'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: degreeController,
                  decoration: const InputDecoration(labelText: 'Degree'),
                ),
                TextField(
                  controller: institutionController,
                  decoration: const InputDecoration(labelText: 'Institution'),
                ),
                TextField(
                  controller: fieldOfStudyController,
                  decoration: const InputDecoration(
                    labelText: 'Field of Study',
                  ),
                ),
                TextField(
                  controller: startDateController,
                  decoration: const InputDecoration(
                    labelText: 'Start Date (YYYY-MM-DD)',
                  ),
                ),
                TextField(
                  controller: endDateController,
                  decoration: const InputDecoration(
                    labelText: 'End Date (YYYY-MM-DD)',
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    ElevatedButton.icon(
                      icon: const Icon(Icons.upload_file),
                      label: const Text('Upload Certificate'),
                      onPressed: isUploading.value
                          ? null
                          : () async {
                              final picker = ImagePicker();
                              final XFile? file = await picker.pickImage(
                                source: ImageSource.gallery,
                              );
                              if (file != null) {
                                setState(() => isUploading.value = true);
                                final profileProvider =
                                    Provider.of<ProfileProvider>(
                                      context,
                                      listen: false,
                                    );
                                final success = await profileProvider
                                    .uploadDocument(
                                      filePath: file.path,
                                      documentType: 'education',
                                    );
                                if (success) {
                                  await profileProvider.refreshProfile();
                                  final updatedProfile =
                                      profileProvider.profile;
                                  final updatedList =
                                      List<Map<String, dynamic>>.from(
                                        updatedProfile?['education'] ?? [],
                                      );
                                  if (idx != null && idx < updatedList.length) {
                                    documentPath =
                                        updatedList[idx]['certificate'] ??
                                        updatedList[idx]['document'];
                                  } else if (updatedList.isNotEmpty) {
                                    documentPath =
                                        updatedList.last['certificate'] ??
                                        updatedList.last['document'];
                                  }
                                }
                                setState(() => isUploading.value = false);
                              }
                            },
                    ),
                    if ((documentPath?.isNotEmpty ?? false))
                      Padding(
                        padding: const EdgeInsets.only(left: 8.0),
                        child: Text(
                          documentPath!.split('/').last,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                  ],
                ),
                ValueListenableBuilder<String?>(
                  valueListenable: errorText,
                  builder: (context, value, _) => value == null
                      ? const SizedBox.shrink()
                      : Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            value,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ValueListenableBuilder<bool>(
              valueListenable: isSaving,
              builder: (context, saving, _) => TextButton(
                onPressed: saving
                    ? null
                    : () async {
                        if (degreeController.text.trim().isEmpty ||
                            institutionController.text.trim().isEmpty ||
                            fieldOfStudyController.text.trim().isEmpty) {
                          setState(
                            () => errorText.value =
                                'Degree, Institution, and Field of Study are required.',
                          );
                          return;
                        }
                        final startDate = startDateController.text.trim();
                        final endDate = endDateController.text.trim();
                        final dateRegex = RegExp(r'^\d{4}-\d{2}-\d{2}$');
                        if (!dateRegex.hasMatch(startDate) ||
                            !dateRegex.hasMatch(endDate)) {
                          setState(
                            () => errorText.value =
                                'Start and End Date must be in YYYY-MM-DD format.',
                          );
                          return;
                        }
                        setState(() {
                          errorText.value = null;
                          isSaving.value = true;
                        });
                        final profileProvider = Provider.of<ProfileProvider>(
                          context,
                          listen: false,
                        );
                        final educationList = List<Map<String, dynamic>>.from(
                          profileProvider.profile?['education'] ?? [],
                        );
                        final newEdu = <String, dynamic>{
                          'degree': degreeController.text.trim(),
                          'institution': institutionController.text.trim(),
                          'fieldOfStudy': fieldOfStudyController.text.trim(),
                          'startDate': startDate,
                          'endDate': endDate,
                        };
                        if (documentPath?.isNotEmpty == true) {
                          newEdu['certificate'] = documentPath;
                        }
                        // Remove any keys with empty string values
                        newEdu.removeWhere(
                          (k, v) =>
                              v == null || (v is String && v.trim().isEmpty),
                        );
                        if (idx == null) {
                          educationList.add(newEdu);
                        } else {
                          educationList[idx] = newEdu;
                        }
                        // Optionally log the payload for debugging
                        // log({'education': educationList});
                        final success = await profileProvider.updateProfile({
                          'education': educationList,
                        });
                        setState(() => isSaving.value = false);
                        if (success) {
                          Navigator.pop(ctx);
                          GlobalNotificationService().showSuccess(
                            'Education saved.',
                          );
                        } else {
                          setState(
                            () => errorText.value =
                                profileProvider.error ?? 'Failed to save.',
                          );
                        }
                      },
                child: saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save'),
              ),
            ),
          ],
        ),
      ),
    ); // <-- closes the Card widget
  }

  void _deleteEducation(BuildContext context, int? idx) async {
    final profileProvider = Provider.of<ProfileProvider>(
      context,
      listen: false,
    );
    final educationList = List<Map<String, dynamic>>.from(
      profileProvider.profile?['education'] ?? [],
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Education'),
        content: const Text(
          'Are you sure you want to delete this education entry?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (idx != null && idx < educationList.length) {
                educationList.removeAt(idx);
              }
              await profileProvider.updateProfile({'education': educationList});
              Navigator.pop(ctx);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

// --- Certificate Section Widget ---
class _CertificateSection extends StatelessWidget {
  final bool showTooltips;

  const _CertificateSection({this.showTooltips = false});

  @override
  Widget build(BuildContext context) {
    final profileProvider = Provider.of<ProfileProvider>(context);
    final certList = List<Map<String, dynamic>>.from(
      profileProvider.profile?['certificates'] ?? [],
    );
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Certificates',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.add, color: Colors.blueAccent),
                  onPressed: () => _showCertificateDialog(context, null, null),
                ),
              ],
            ),
            if (certList.isEmpty)
              const Text(
                'No certificates added.',
                style: TextStyle(color: Colors.grey),
              )
            else
              ...certList.asMap().entries.map((entry) {
                final idx = entry.key;
                final cert = entry.value;
                final issuer = cert['issuer'] ?? '';
                final date = cert['date'] ?? '';
                return ListTile(
                  leading: const Icon(
                    Icons.workspace_premium,
                    color: Colors.green,
                  ),
                  title: Text(cert['name'] ?? ''),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        [issuer, date]
                            .where((e) => e != null && e.toString().isNotEmpty)
                            .join(' • '),
                      ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if ((cert['document'] ?? cert['file'] ?? '')
                          .toString()
                          .isNotEmpty)
                        IconButton(
                          icon: const Icon(
                            Icons.remove_red_eye,
                            color: Colors.blueAccent,
                          ),
                          tooltip: 'View Document',
                          onPressed: () async {
                            final certName =
                                cert['name']?.toString() ??
                                cert['title']?.toString() ??
                                'Certificate';
                            showDocumentDialog(
                              context,
                              cert['document'] ?? cert['file'],
                              documentName: certName,
                              documentType: 'certificates',
                            );
                          },
                        ),
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.orange),
                        onPressed: () =>
                            _showCertificateDialog(context, cert, idx),
                        tooltip: showTooltips ? 'Edit Certificate' : null,
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteCertificate(context, idx),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    ); // <-- closes the Card widget
  }

  void _showCertificateDialog(
    BuildContext context,
    Map<String, dynamic>? cert,
    int? idx,
  ) {
    final nameController = TextEditingController(text: cert?['name'] ?? '');
    final issuerController = TextEditingController(text: cert?['issuer'] ?? '');
    final dateController = TextEditingController(
      text: cert?['date']?.toString() ?? '',
    );
    String? documentPath = cert?['document'];
    ValueNotifier<bool> isUploading = ValueNotifier(false);
    ValueNotifier<bool> isSaving = ValueNotifier(false);
    ValueNotifier<String?> errorText = ValueNotifier(null);
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          return AlertDialog(
            title: Text(idx == null ? 'Add Certificate' : 'Edit Certificate'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Certificate Name',
                  ),
                ),
                TextField(
                  controller: issuerController,
                  decoration: const InputDecoration(labelText: 'Issuer'),
                ),
                TextField(
                  controller: dateController,
                  decoration: const InputDecoration(labelText: 'Date'),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    ElevatedButton.icon(
                      icon: const Icon(Icons.upload_file),
                      label: const Text('Upload Document'),
                      onPressed: isUploading.value
                          ? null
                          : () async {
                              final picker = ImagePicker();
                              final XFile? file = await picker.pickImage(
                                source: ImageSource.gallery,
                              );
                              if (file != null) {
                                setState(() => isUploading.value = true);
                                final profileProvider =
                                    Provider.of<ProfileProvider>(
                                      context,
                                      listen: false,
                                    );
                                final success = await profileProvider
                                    .uploadDocument(
                                      filePath: file.path,
                                      documentType: 'certificates',
                                    );
                                if (success) {
                                  await profileProvider.refreshProfile();
                                  final updatedProfile =
                                      profileProvider.profile;
                                  final updatedList =
                                      List<Map<String, dynamic>>.from(
                                        updatedProfile?['certificates'] ?? [],
                                      );
                                  if (idx != null && idx < updatedList.length) {
                                    documentPath = updatedList[idx]['document'];
                                  } else if (updatedList.isNotEmpty) {
                                    documentPath = updatedList.last['document'];
                                  }
                                }
                                setState(() => isUploading.value = false);
                              }
                            },
                    ),
                    if ((documentPath?.isNotEmpty ?? false))
                      Padding(
                        padding: const EdgeInsets.only(left: 8.0),
                        child: Text(
                          documentPath!.split('/').last,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                  ],
                ),
                ValueListenableBuilder<String?>(
                  valueListenable: errorText,
                  builder: (context, value, _) => value == null
                      ? const SizedBox.shrink()
                      : Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            value,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ValueListenableBuilder<bool>(
                valueListenable: isSaving,
                builder: (context, saving, _) => TextButton(
                  onPressed: saving
                      ? null
                      : () async {
                          if (nameController.text.trim().isEmpty ||
                              issuerController.text.trim().isEmpty) {
                            setState(
                              () => errorText.value =
                                  'Certificate Name and Issuer are required.',
                            );
                            return;
                          }
                          setState(() {
                            errorText.value = null;
                            isSaving.value = true;
                          });
                          final profileProvider = Provider.of<ProfileProvider>(
                            context,
                            listen: false,
                          );
                          final certList = List<Map<String, dynamic>>.from(
                            profileProvider.profile?['certificates'] ?? [],
                          );
                          final newCert = {
                            'name': nameController.text,
                            'issuer': issuerController.text,
                            'date': dateController.text,
                            'document': documentPath ?? '',
                          };
                          if (idx == null) {
                            certList.add(newCert);
                          } else {
                            certList[idx] = newCert;
                          }
                          final success = await profileProvider.updateProfile({
                            'certificates': certList,
                          });
                          setState(() => isSaving.value = false);
                          if (success) {
                            Navigator.pop(ctx);
                            GlobalNotificationService().showSuccess(
                              'Certificate saved.',
                            );
                          } else {
                            setState(
                              () => errorText.value =
                                  profileProvider.error ?? 'Failed to save.',
                            );
                          }
                        },
                  child: saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save'),
                ),
              ),
            ],
          );
        },
      ),
    ); // showDialog
  }

  void _deleteCertificate(BuildContext context, int? idx) async {
    final profileProvider = Provider.of<ProfileProvider>(
      context,
      listen: false,
    );
    final certList = List<Map<String, dynamic>>.from(
      profileProvider.profile?['certificates'] ?? [],
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Certificate'),
        content: const Text(
          'Are you sure you want to delete this certificate?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (idx != null && idx < certList.length) {
                certList.removeAt(idx);
              }
              await profileProvider.updateProfile({'certificates': certList});
              Navigator.pop(ctx);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

// Custom painter for abstract dot pattern background
class _DotPatternPainter extends CustomPainter {
  final Color color;

  _DotPatternPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    const double dotSize = 3.0;
    const int numberOfDots = 50; // Random number of dots

    // Draw dots in random positions
    for (int i = 0; i < numberOfDots; i++) {
      final randomX =
          (i * 37.0) % size.width; // Pseudo-random but deterministic
      final randomY = (i * 73.0) % size.height;

      // Add some variation to dot sizes
      final currentDotSize = dotSize + (i % 3) * 1.0;

      canvas.drawCircle(Offset(randomX, randomY), currentDotSize, paint);
    }

    // Add various types of lines for more abstract feel
    final linePaint = Paint()
      ..color = color.withValues(alpha: 0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // Diagonal lines
    for (double i = 0; i < size.width + size.height; i += 120) {
      canvas.drawLine(
        Offset(i, 0),
        Offset(i - size.height, size.height),
        linePaint,
      );
    }

    // Horizontal wavy lines
    final wavyPaint = Paint()
      ..color = color.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (double y = 50; y < size.height; y += 100) {
      final path = Path();
      path.moveTo(0, y);

      for (double x = 0; x <= size.width; x += 20) {
        final waveY = y + 10 * sin(x / 50);
        path.lineTo(x, waveY);
      }

      canvas.drawPath(path, wavyPaint);
    }

    // Curved arc lines
    final curvePaint = Paint()
      ..color = color.withValues(alpha: 0.06)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    for (double x = 100; x < size.width; x += 150) {
      final path = Path();
      path.moveTo(x, 0);
      path.quadraticBezierTo(x + 50, size.height / 3, x, size.height * 0.6);
      path.quadraticBezierTo(x - 50, size.height * 0.8, x, size.height);
      canvas.drawPath(path, curvePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
