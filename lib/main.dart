import 'package:flutter/material.dart';
import 'auth/login_screen.dart';
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
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.amber,
        useMaterial3: true,
      ),
      home: AdminLoginScreen(service: service),
    );
  }
}
