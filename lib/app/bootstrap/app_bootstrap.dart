import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sns_clocked_in/core/network/api_client.dart';
import 'package:sns_clocked_in/core/state/app_state.dart';

/// Bootstrap widget that initializes app state and API client
class AppBootstrap extends StatefulWidget {
  const AppBootstrap({required this.child, super.key});

  final Widget child;

  @override
  State<AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<AppBootstrap> {
  @override
  void initState() {
    super.initState();
    _initialize();
  }

  void _initialize() {
    // Bootstrap app state
    context.read<AppState>().bootstrap();

    // Set token provider for API client
    ApiClient().setTokenProvider(
      () => context.read<AppState>().accessToken,
    );

    // Pre-cache images for login screen to prevent lag during transition
    _precacheImages();
  }

  /// Pre-cache images used in login screen for smooth transition
  void _precacheImages() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      
      // Pre-cache login screen logo (non-blocking)
      // Uses global imageCache automatically
      precacheImage(
        const AssetImage('assets/images/app_log.png'),
        context,
      ).catchError((_) {
        // Ignore errors - image will load when needed
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
