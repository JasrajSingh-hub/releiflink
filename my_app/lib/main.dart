import 'package:flutter/material.dart';

import 'screens/create_request_screen.dart';
import 'screens/shell_screen.dart';
import 'services/app_bootstrap.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  await AppBootstrap.init();
  runApp(const ReliefConnectApp());
}

class ReliefConnectApp extends StatelessWidget {
  const ReliefConnectApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ReliefLink',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const ShellScreen(),
      routes: {
        CreateRequestScreen.routeName: (_) => const CreateRequestScreen(),
      },
    );
  }
}
