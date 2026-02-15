import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../dashboard/dashboard.dart';
import '../services/admin_service.dart';

class AdminLoginScreen extends StatefulWidget {
  final AdminService service;

  const AdminLoginScreen({super.key, required this.service});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  static const _kRememberKey = 'admin_remember_me';
  static const _kEmailKey = 'admin_email';

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  late final AdminService _service;

  bool _isLoading = false;
  bool _rememberMe = true;
  bool _showPassword = false;

  @override
  void initState() {
    super.initState();
    _service = widget.service;
    _restoreRemembered();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _restoreRemembered() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final remember = prefs.getBool(_kRememberKey) ?? true;
      final email = prefs.getString(_kEmailKey) ?? '';

      if (!mounted) return;
      setState(() {
        _rememberMe = remember;
        if (remember && email.isNotEmpty) {
          _emailController.text = email;
        }
      });
    } catch (_) {
      // ignore (no drama if prefs fails)
    }
  }

  Future<void> _persistRemembered() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kRememberKey, _rememberMe);

      if (_rememberMe) {
        await prefs.setString(_kEmailKey, _emailController.text.trim());
      } else {
        await prefs.remove(_kEmailKey);
      }
    } catch (_) {
      // ignore
    }
  }

  Future<void> _handleLogin() async {
    if (_isLoading) return;

    final email = _emailController.text.trim();
    final pw = _passwordController.text;

    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your admin email.')),
      );
      return;
    }
    if (pw.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your password.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _service.login(email: email, password: pw);
      await _persistRemembered();

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AdminDashboard()),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Login failed: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final disabled = _isLoading;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/login.png',
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(color: Colors.black),
          ),
          Container(color: Colors.black.withOpacity(0.55)),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.60),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.12)),
                  boxShadow: const [
                    BoxShadow(color: Colors.black54, blurRadius: 18),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'assets/images/icon.png',
                      height: 74,
                      width: 74,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.security,
                        size: 66,
                        color: Colors.amber,
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      "Weather Hooligan Admin",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 26),

                    TextField(
                      controller: _emailController,
                      enabled: !disabled,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: "Admin Email",
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _handleLogin(),
                    ),
                    const SizedBox(height: 16),

                    TextField(
                      controller: _passwordController,
                      enabled: !disabled,
                      obscureText: !_showPassword,
                      decoration: InputDecoration(
                        labelText: "Password",
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          tooltip: _showPassword
                              ? 'Hide password'
                              : 'Show password',
                          onPressed: disabled
                              ? null
                              : () => setState(
                                  () => _showPassword = !_showPassword,
                                ),
                          icon: Icon(
                            _showPassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                        ),
                      ),
                      onSubmitted: (_) => _handleLogin(),
                    ),

                    const SizedBox(height: 10),

                    Row(
                      children: [
                        Checkbox(
                          value: _rememberMe,
                          onChanged: disabled
                              ? null
                              : (v) => setState(() => _rememberMe = v ?? true),
                        ),
                        const Expanded(
                          child: Text(
                            'Remember me',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ),
                        TextButton(
                          onPressed: disabled
                              ? null
                              : () {
                                  _passwordController.clear();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Ask admin to reset your password in Tools → Reset password.',
                                      ),
                                    ),
                                  );
                                },
                          child: const Text('Forgot password?'),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    disabled
                        ? const Padding(
                            padding: EdgeInsets.symmetric(vertical: 6),
                            child: CircularProgressIndicator(),
                          )
                        : ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 50),
                            ),
                            onPressed: _handleLogin,
                            child: const Text("Login to Dashboard"),
                          ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
