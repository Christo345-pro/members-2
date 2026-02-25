import 'package:flutter/material.dart';
import 'auth/login_screen.dart';
import 'core/theme/app_theme.dart';
import 'services/admin_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const HooliganAdminApp());
}

class HooliganAdminApp extends StatelessWidget {
  const HooliganAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    final service = AdminService();

    return MaterialApp(
      title: 'Hooligan Members Admin',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: AdminLoginScreen(service: service),
    );
  }
}
