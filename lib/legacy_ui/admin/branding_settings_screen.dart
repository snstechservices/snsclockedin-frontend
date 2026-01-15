import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/branding_provider.dart';
import '../../widgets/admin_side_navigation.dart';
import '../../widgets/branding/logo_uploader.dart';
import '../../widgets/branding/color_picker.dart';
import '../../services/global_notification_service.dart';
import '../../theme/app_theme.dart';
import '../../models/branding_model.dart';

/// Screen for managing company branding (white-label customization)
class BrandingSettingsScreen extends StatefulWidget {
  const BrandingSettingsScreen({super.key});

  @override
  State<BrandingSettingsScreen> createState() => _BrandingSettingsScreenState();
}

class _BrandingSettingsScreenState extends State<BrandingSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _companyNameController;
  late TextEditingController _taglineController;
  String? _primaryColor;
  String? _secondaryColor;
  String? _themePreset;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _companyNameController = TextEditingController();
    _taglineController = TextEditingController();
    _primaryColor = '#1976D2';
    _secondaryColor = '#424242';
    _themePreset = 'light';

    // Load branding when screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadBranding();
    });
  }

  @override
  void dispose() {
    _companyNameController.dispose();
    _taglineController.dispose();
    super.dispose();
  }

  Future<void> _loadBranding() async {
    final brandingProvider = Provider.of<BrandingProvider>(
      context,
      listen: false,
    );
    await brandingProvider.loadBranding();

    final branding = brandingProvider.branding;
    if (branding != null) {
      setState(() {
        _companyNameController.text = branding.companyName ?? '';
        _taglineController.text = branding.tagline ?? '';
        _primaryColor = branding.primaryColor ?? '#1976D2';
        _secondaryColor = branding.secondaryColor ?? '#424242';
        _themePreset = branding.themePreset ?? 'light';
      });
    }
  }

  Future<void> _saveBranding() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final brandingProvider = Provider.of<BrandingProvider>(
      context,
      listen: false,
    );
    final currentBranding = brandingProvider.branding;

    final updatedBranding = (currentBranding ?? BrandingModel()).copyWith(
      companyName: _companyNameController.text.trim().isEmpty
          ? null
          : _companyNameController.text.trim(),
      tagline: _taglineController.text.trim().isEmpty
          ? null
          : _taglineController.text.trim(),
      primaryColor: _primaryColor,
      secondaryColor: _secondaryColor,
      themePreset: _themePreset,
    );

    final success = await brandingProvider.updateBranding(updatedBranding);

    if (mounted) {
      setState(() {
        _isSaving = false;
      });

      if (success) {
        GlobalNotificationService().showSuccess(
          'Branding updated successfully!',
        );
      } else {
        GlobalNotificationService().showError(
          brandingProvider.error ??
              'Failed to update branding. Please try again.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final brandingProvider = Provider.of<BrandingProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Branding Settings'),
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 0,
      ),
      drawer: const AdminSideNavigation(currentRoute: '/branding-settings'),
      body: brandingProvider.isLoading && brandingProvider.branding == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppTheme.spacingL),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header
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
                                Icon(Icons.palette, color: colorScheme.primary),
                                const SizedBox(width: AppTheme.spacingS),
                                const Text(
                                  'Company Branding',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppTheme.spacingS),
                            const Text(
                              'Customize your company\'s appearance across the app. '
                              'Changes will be applied immediately.',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppTheme.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: AppTheme.spacingL),

                    // Logo Upload
                    LogoUploader(
                      currentLogoUrl: brandingProvider.logoUrl,
                      onLogoChanged: (url) {
                        // Logo is automatically saved when uploaded
                      },
                    ),

                    const SizedBox(height: AppTheme.spacingL),

                    // Company Information
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
                                Icon(
                                  Icons.business,
                                  color: colorScheme.primary,
                                ),
                                const SizedBox(width: AppTheme.spacingS),
                                const Text(
                                  'Company Information',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppTheme.spacingL),
                            TextFormField(
                              controller: _companyNameController,
                              decoration: const InputDecoration(
                                labelText: 'Company Name',
                                hintText: 'Your Company Name',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.business_center),
                              ),
                              maxLength: 200,
                            ),
                            const SizedBox(height: AppTheme.spacingM),
                            TextFormField(
                              controller: _taglineController,
                              decoration: const InputDecoration(
                                labelText: 'Tagline (Optional)',
                                hintText: 'A short slogan or description',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.tag),
                              ),
                              maxLength: 500,
                              maxLines: 2,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: AppTheme.spacingL),

                    // Brand Colors
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        BrandingColorPicker(
                          label: 'Primary Color',
                          currentColor: _primaryColor,
                          onColorChanged: (color) {
                            setState(() {
                              _primaryColor = color;
                            });
                          },
                        ),
                        const SizedBox(height: AppTheme.spacingM),
                        BrandingColorPicker(
                          label: 'Secondary Color',
                          currentColor: _secondaryColor,
                          onColorChanged: (color) {
                            setState(() {
                              _secondaryColor = color;
                            });
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: AppTheme.spacingL),

                    // Theme Preset
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
                                Icon(
                                  Icons.brightness_6,
                                  color: colorScheme.primary,
                                ),
                                const SizedBox(width: AppTheme.spacingS),
                                const Text(
                                  'Theme Preset',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppTheme.spacingM),
                            DropdownButtonFormField<String>(
                              initialValue: _themePreset,
                              decoration: const InputDecoration(
                                labelText: 'Theme Mode',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.palette),
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'light',
                                  child: Text('Light'),
                                ),
                                DropdownMenuItem(
                                  value: 'dark',
                                  child: Text('Dark'),
                                ),
                                DropdownMenuItem(
                                  value: 'custom',
                                  child: Text('Custom'),
                                ),
                              ],
                              onChanged: (value) {
                                setState(() {
                                  _themePreset = value;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: AppTheme.spacingL),

                    // Preview Card
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
                                Icon(Icons.preview, color: colorScheme.primary),
                                const SizedBox(width: AppTheme.spacingS),
                                const Text(
                                  'Preview',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppTheme.spacingM),
                            Container(
                              padding: const EdgeInsets.all(AppTheme.spacingL),
                              decoration: BoxDecoration(
                                color:
                                    _parseColor(_primaryColor) ?? Colors.blue,
                                borderRadius: BorderRadius.circular(
                                  AppTheme.radiusSmall,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    _companyNameController.text.isEmpty
                                        ? 'Your Company Name'
                                        : _companyNameController.text,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (_taglineController.text.isNotEmpty) ...[
                                    const SizedBox(height: AppTheme.spacingS),
                                    Text(
                                      _taglineController.text,
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: AppTheme.spacingM),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () {},
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          _parseColor(_primaryColor) ??
                                          Colors.blue,
                                    ),
                                    child: const Text('Primary Button'),
                                  ),
                                ),
                                const SizedBox(width: AppTheme.spacingM),
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () {},
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor:
                                          _parseColor(_secondaryColor) ??
                                          Colors.grey,
                                      side: BorderSide(
                                        color:
                                            _parseColor(_secondaryColor) ??
                                            Colors.grey,
                                      ),
                                    ),
                                    child: const Text('Secondary Button'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: AppTheme.spacingXl),

                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isSaving ? null : _saveBranding,
                        icon: _isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.save),
                        label: Text(_isSaving ? 'Saving...' : 'Save Branding'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            vertical: AppTheme.spacingM,
                          ),
                          backgroundColor: colorScheme.primary,
                          foregroundColor: colorScheme.onPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Color? _parseColor(String? hexColor) {
    if (hexColor == null || hexColor.isEmpty) return null;

    try {
      String hex = hexColor.replaceAll('#', '');
      if (hex.length == 3) {
        hex = hex.split('').map((c) => '$c$c').join();
      }
      final colorValue = int.parse(hex, radix: 16);
      return Color(0xFF000000 | colorValue);
    } catch (e) {
      return null;
    }
  }
}
