import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:sns_clocked_in/app/app.dart';
import 'package:sns_clocked_in/app/bootstrap/app_bootstrap.dart';
import 'package:sns_clocked_in/core/state/app_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  await dotenv.load();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppState()),
      ],
      child: const AppBootstrap(child: App()),
    ),
  );
}
