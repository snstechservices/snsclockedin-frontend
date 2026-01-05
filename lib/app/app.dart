import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sns_clocked_in/app/router/app_router.dart';
import 'package:sns_clocked_in/app/theme/theme_config.dart';
import 'package:sns_clocked_in/core/state/app_state.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final router = AppRouter.createRouter(appState);

    return MaterialApp.router(
      title: 'SNS Clocked In',
      debugShowCheckedModeBanner: false,
      theme: ThemeConfig.lightTheme,
      darkTheme: ThemeConfig.darkTheme,
      themeMode: ThemeMode.light,
      routerConfig: router,
    );
  }
}
