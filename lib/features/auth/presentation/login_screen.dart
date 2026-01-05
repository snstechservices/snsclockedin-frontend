import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:sns_clocked_in/core/state/app_state.dart';
import 'package:sns_clocked_in/core/ui/motion.dart';
import 'package:sns_clocked_in/core/ui/pressable_scale.dart';
import 'package:sns_clocked_in/design_system/app_colors.dart';
import 'package:sns_clocked_in/design_system/app_radius.dart';
import 'package:sns_clocked_in/design_system/app_spacing.dart';
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

    // Prevent rapid repeated login attempts
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Await loginMock() to ensure the delay executes and simulate realistic login timing
      // This prevents rapid repeated login attempts and provides proper loading feedback
      await context.read<AppState>().loginMock();
      
      // Reset loading state after login completes
      // Note: Navigation may have already occurred via router redirect, but we still
      // need to clean up the loading state if we're still on this screen
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Login failed. Please try again.';
        });
      }
    }
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

  void _showHelpDialog() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Need help?',
          style: AppTypography.lightTextTheme.titleLarge?.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'If you need assistance with your account, please contact:',
              style: AppTypography.lightTextTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              '• Your company administrator',
              style: AppTypography.lightTextTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '• S&S Tech Services support team',
              style: AppTypography.lightTextTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '• Email: support@snsclockedin.com',
              style: AppTypography.lightTextTheme.bodyMedium?.copyWith(
                color: AppColors.primary,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Close',
              style: AppTypography.lightTextTheme.bodyMedium?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
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
    // Constrain form card width on large screens (max 460 for better use of space)
    final formMaxWidth = availableWidthForForm > 460
        ? 460.0
        : availableWidthForForm;

    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight;

        // Tighter + more controlled spacing (works better on tall screens)
        final topPad = (h * 0.035).clamp(16.0, 34.0);
        final betweenHeaderAndCard = (h * 0.035).clamp(14.0, 28.0);

        return CustomScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                leftPad,
                media.padding.top + topPad,
                rightPad,
                media.padding.bottom + 12.0,
              ),
              sliver: SliverFillRemaining(
                hasScrollBody: false,
                child: Column(
                  children: [
                    // Small top spacer that scales but never becomes huge
                    SizedBox(height: (h * 0.03).clamp(8.0, 22.0)),

                    Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: formMaxWidth),
                        child: _buildAnimatedHeader(),
                      ),
                    ),

                    SizedBox(height: betweenHeaderAndCard),

                    Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: formMaxWidth),
                        child: _buildAnimatedLoginForm(),
                      ),
                    ),

                    const Spacer(),

                    _buildFooter(),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAnimatedHeader() {
    final shouldReduceMotion = Motion.reducedMotion(context);
    final animationDuration = Motion.duration(context, const Duration(milliseconds: 300));
    final animationCurve = Motion.curve(context, Motion.standard);

    if (shouldReduceMotion) {
      return _buildHeader();
    }

    return TweenAnimationBuilder<double>(
      duration: animationDuration,
      curve: animationCurve,
      tween: Tween<double>(begin: 0, end: 1),
      builder: (context, value, child) {
        // Logo: scale from 0.98 to 1.0 + fade
        return Transform.scale(
          scale: 0.98 + (0.02 * value),
          child: Opacity(
            opacity: value,
            child: child,
          ),
        );
      },
      child: _buildHeader(),
    );
  }

  Widget _buildHeader() {
    return Center(
      child: Column(
        children: [
          Container(
            width: 100, // Reduced from 120
            height: 100, // Reduced from 120
            constraints: const BoxConstraints(
              maxWidth: 110,
              maxHeight: 110,
              minWidth: 80,
              minHeight: 80,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18), // Slightly reduced
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08), // Softer shadow
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            padding: const EdgeInsets.all(14), // Reduced from 16
            child: Image.asset(
              'assets/images/app_log.png',
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return const Icon(
                  Icons.access_time,
                  size: 50, // Reduced from 60
                  color: AppColors.primary,
                );
              },
            ),
          ),
          const SizedBox(height: 18),
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
              'Welcome back',
              textAlign: TextAlign.center,
              style: AppTypography.lightTextTheme.headlineMedium?.copyWith(
                color: AppColors.primary,
                fontSize: 24,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Sign in to continue',
            textAlign: TextAlign.center,
            style: AppTypography.lightTextTheme.bodyMedium?.copyWith(
              color: AppColors.muted.withValues(alpha: 0.7),
              fontSize: 15,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedLoginForm() {
    final shouldReduceMotion = Motion.reducedMotion(context);
    final animationDuration = Motion.duration(context, const Duration(milliseconds: 300));
    final animationCurve = Motion.curve(context, Motion.standard);

    if (shouldReduceMotion) {
      // No animation if reduced motion is enabled
      return _buildLoginForm();
    }

    return TweenAnimationBuilder<double>(
      duration: animationDuration,
      curve: animationCurve,
      tween: Tween<double>(begin: 0, end: 1),
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 10 * (1 - value)), // Slide up from 10px
          child: Opacity(
            opacity: value,
            child: child,
          ),
        );
      },
      child: _buildLoginForm(),
    );
  }

  Widget _buildLoginForm() {
    // RepaintBoundary prevents unnecessary repaints of the form
    return RepaintBoundary(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16), // Slightly reduced from largeAll
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.08), // Subtle border
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06), // Softer shadow
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(18), // Premium spacing
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

                  const SizedBox(height: 14), // Reduced from 16
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

                  const SizedBox(height: 14), // Reduced from 16
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

                  const SizedBox(height: 18), // Reduced from 20

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
                                label: 'Sign in',
                                button: true,
                                child: Text(
                                  'Sign in',
                                  style: AppTypography.lightTextTheme.bodyLarge?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                      ),
                    ),
                  ),

                  // Register link inside card
                  const SizedBox(height: 12),
                  _buildRegisterButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRegisterButton() {
    return OutlinedButton(
      onPressed: _isLoading
          ? null
          : () {
              _showSnackBar('Company registration coming soon');
            },
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        minimumSize: const Size(88, 44),
        side: BorderSide(
          color: AppColors.primary.withValues(alpha: 0.3),
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: AppRadius.smallAll,
        ),
      ),
      child: Text(
        'Register your company',
        style: AppTypography.lightTextTheme.bodyMedium?.copyWith(
          color: AppColors.primary,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Version 2.0.0',
            style: AppTypography.lightTextTheme.bodySmall?.copyWith(
              color: AppColors.muted.withValues(alpha: 0.7),
              fontSize: 12,
            ),
          ),
          TextButton(
            onPressed: _showHelpDialog,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              'Need help?',
              style: AppTypography.lightTextTheme.bodySmall?.copyWith(
                color: AppColors.primary.withValues(alpha: 0.8),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _buildInputDecoration({
    required String label,
    required String hint,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    final enabledBorderColor = Colors.grey.withValues(alpha: 0.5); // Increased contrast for finished look
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
        borderSide: BorderSide(color: AppColors.primary, width: 2), // Increased for better focus
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      labelStyle: AppTypography.lightTextTheme.labelLarge?.copyWith(
        color: AppColors.muted,
      ),
      hintStyle: AppTypography.lightTextTheme.bodyMedium?.copyWith(
        color: AppColors.muted,
      ),
    );
  }
}
