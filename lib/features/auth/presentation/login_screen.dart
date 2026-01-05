import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:sns_clocked_in/core/state/app_state.dart';
import 'package:sns_clocked_in/core/ui/entrance.dart';
import 'package:sns_clocked_in/core/ui/pressable_scale.dart';
import 'package:sns_clocked_in/design_system/app_colors.dart';
import 'package:sns_clocked_in/design_system/app_radius.dart';
import 'package:sns_clocked_in/design_system/app_typography.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _rememberMe = false;
  String? _errorMessage;
  int _titleTapCount = 0;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _clearError() {
    if (_errorMessage != null) {
      setState(() {
        _errorMessage = null;
      });
    }
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) {
      _showSnackBar('Please fix the errors in the form above');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Call mock login - state updates immediately, router redirects synchronously
      // No jank - navigation happens instantly, delay is non-blocking
      context.read<AppState>().loginMock();
      // Don't await - loginMock() updates state immediately and router redirects
      // The delay inside loginMock() is non-blocking for UI
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Login failed. Please try again.';
        });
      }
    }

    // Reset loading state after a brief moment (UI feedback)
    // Navigation already happened via router redirect
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    });
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      resizeToAvoidBottomInset: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
        child: Stack(
          children: [
            // Full-bleed gradient background behind system bars
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.primary.withValues(alpha: 0.1),
                      AppColors.background,
                      AppColors.primary.withValues(alpha: 0.05),
                    ],
                  ),
                ),
              ),
            ),

            // Content: allow gradient to extend behind the top status bar
            SafeArea(
              top: false,
              left: false,
              right: false,
              child: _buildMobileLayout(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileLayout() {
    final media = MediaQuery.of(context);
    const baseHorizontal = 24.0;
    final leftPad = baseHorizontal + media.padding.left;
    final rightPad = baseHorizontal + media.padding.right;
    final availableWidthForForm = (media.size.width - leftPad - rightPad).clamp(
      0.0,
      double.infinity,
    );
    final formMaxWidth = availableWidthForForm > 400
        ? 400.0
        : availableWidthForForm;

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(
            leftPad,
            media.padding.top + 8.0,
            rightPad,
            media.viewInsets.bottom + 12.0,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: formMaxWidth),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 32),
                    // Show header immediately - no animation delay
                    _buildHeader(),
                    const SizedBox(height: 28),
                    // Show login form immediately - no animation for instant appearance
                    _buildLoginForm(),
                    const SizedBox(height: 16),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return Center(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          children: [
            Container(
              width: 120,
              height: 120,
              constraints: const BoxConstraints(
                maxWidth: 140,
                maxHeight: 140,
                minWidth: 100,
                minHeight: 100,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(16),
              child: Image.asset(
                'assets/images/app_log.png',
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(
                    Icons.access_time,
                    size: 60,
                    color: AppColors.primary,
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onLongPress: () {
                if (kDebugMode) {
                  context.go('/debug');
                }
              },
              onTap: () {
                if (kDebugMode) {
                  setState(() {
                    _titleTapCount++;
                  });
                  if (_titleTapCount >= 7) {
                    _titleTapCount = 0;
                    context.go('/debug');
                  }
                }
              },
              child: Text(
                'S&S CLOCKED IN',
                style: AppTypography.lightTextTheme.displayLarge?.copyWith(
                  color: AppColors.primary,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Sign in to your account',
              style: AppTypography.lightTextTheme.bodyLarge?.copyWith(
                color: AppColors.muted,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginForm() {
    // RepaintBoundary prevents unnecessary repaints of the form
    return RepaintBoundary(
      child: Container(
        decoration: const BoxDecoration(
          borderRadius: AppRadius.largeAll,
        ),
        child: ClipRRect(
          borderRadius: AppRadius.largeAll,
          // Reduce blur for better performance (5 instead of 10)
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
            child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.88),
              borderRadius: AppRadius.largeAll,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.3),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.8),
                  blurRadius: 20,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  // Email Field
                  TextFormField(
                    key: const Key('login_email'),
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    enabled: !_isLoading,
                    decoration: _buildInputDecoration(
                      label: 'Email',
                      hint: 'Enter your email address',
                      icon: Icons.email_outlined,
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Email address is required';
                      }
                      if (!RegExp(
                        r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                      ).hasMatch(value.trim())) {
                        return 'Please enter a valid email address';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 20),
                  // Password Field
                  TextFormField(
                    key: const Key('login_password'),
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    enabled: !_isLoading,
                    decoration: _buildInputDecoration(
                      label: 'Password',
                      hint: 'Enter your password',
                      icon: Icons.lock_outlined,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility
                              : Icons.visibility_off,
                          color: AppColors.muted,
                          size: 20,
                        ),
                        onPressed: _isLoading
                            ? null
                            : () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Password is required';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 20),
                  // Remember Me & Forgot Password
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Checkbox(
                            value: _rememberMe,
                            onChanged: _isLoading
                                ? null
                                : (value) {
                                    setState(() {
                                      _rememberMe = value ?? false;
                                    });
                                  },
                            activeColor: AppColors.primary,
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          Container(
                            constraints: const BoxConstraints(maxWidth: 120),
                            child: Text(
                              'Remember me',
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.lightTextTheme.bodyMedium?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.7),
                              ),
                            ),
                          ),
                        ],
                      ),
                      TextButton(
                        onPressed: _isLoading
                            ? null
                            : () {
                                // TODO(dev): Navigate to forgot password screen
                                _showSnackBar('Forgot password feature coming soon');
                              },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          minimumSize: const Size(88, 40),
                          tapTargetSize: MaterialTapTargetSize.padded,
                        ),
                        child: Text(
                          'Forgot password?',
                          style: AppTypography.lightTextTheme.bodyMedium?.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Error Message Display
                  if (_errorMessage != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.1),
                        borderRadius: AppRadius.smallAll,
                        border: Border.all(
                          color: AppColors.error.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: AppColors.error,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              _errorMessage!,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.lightTextTheme.bodyMedium?.copyWith(
                                color: AppColors.error,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            color: AppColors.error,
                            onPressed: _clearError,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ),

                  // Sign In Button
                  PressableScale(
                    child: SizedBox(
                      height: 56,
                      width: double.infinity,
                      child: ElevatedButton(
                        key: const Key('login_button'),
                        onPressed: _isLoading ? null : _handleLogin,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(88, 56),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.6),
                          shape: const RoundedRectangleBorder(
                            borderRadius: AppRadius.smallAll,
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : Semantics(
                                label: 'Login',
                                button: true,
                                child: Text(
                                  'Login',
                                  style: AppTypography.lightTextTheme.bodyLarge?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
    );
  }

  InputDecoration _buildInputDecoration({
    required String label,
    required String hint,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    final enabledBorderColor = Colors.grey.withValues(alpha: 0.3);
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: AppColors.muted, size: 20),
      suffixIcon: suffixIcon,
      border: OutlineInputBorder(
        borderRadius: AppRadius.smallAll,
        borderSide: BorderSide(color: enabledBorderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: AppRadius.smallAll,
        borderSide: BorderSide(color: enabledBorderColor),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: AppRadius.smallAll,
        borderSide: BorderSide(color: AppColors.primary, width: 1.5),
      ),
      errorBorder: const OutlineInputBorder(
        borderRadius: AppRadius.smallAll,
        borderSide: BorderSide(color: AppColors.error),
      ),
      focusedErrorBorder: const OutlineInputBorder(
        borderRadius: AppRadius.smallAll,
        borderSide: BorderSide(color: AppColors.error, width: 2),
      ),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.9),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      labelStyle: AppTypography.lightTextTheme.labelLarge?.copyWith(
        color: AppColors.muted,
      ),
      hintStyle: AppTypography.lightTextTheme.bodyMedium?.copyWith(
        color: AppColors.muted,
      ),
    );
  }
}
