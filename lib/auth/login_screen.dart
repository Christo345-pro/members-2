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
  static const _kUsernameKey = 'admin_username';

  final _usernameController = TextEditingController();
  final _pinController = TextEditingController();
  final _otpController = TextEditingController();
  final _newPinController = TextEditingController();
  final _confirmPinController = TextEditingController();

  late final AdminService _service;

  bool _rememberMe = true;
  bool _showPin = false;
  bool _showNewPin = false;
  bool _showConfirmPin = false;

  bool _loggingIn = false;
  bool _requestingOtp = false;
  bool _verifyingOtp = false;

  String? _challengeId;
  String? _otpDelivery;
  String? _status;

  bool get _busy => _loggingIn || _requestingOtp || _verifyingOtp;

  @override
  void initState() {
    super.initState();
    _service = widget.service;
    _restoreRemembered();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _pinController.dispose();
    _otpController.dispose();
    _newPinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  Future<void> _restoreRemembered() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final remember = prefs.getBool(_kRememberKey) ?? true;
      final username = prefs.getString(_kUsernameKey) ?? '';

      if (!mounted) return;
      setState(() {
        _rememberMe = remember;
        if (remember && username.isNotEmpty) {
          _usernameController.text = username;
        }
      });
    } catch (_) {}
  }

  Future<void> _persistRemembered() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kRememberKey, _rememberMe);

      if (_rememberMe) {
        await prefs.setString(_kUsernameKey, _username());
      } else {
        await prefs.remove(_kUsernameKey);
      }
    } catch (_) {}
  }

  String _username() => _usernameController.text.trim().toLowerCase();

  String? _validateUsername() {
    final value = _username();
    if (value.isEmpty) return 'Please enter your admin username.';
    if (!RegExp(r'^[a-z0-9_-]{3,60}$').hasMatch(value)) {
      return 'Username must use only letters, numbers, _ or -';
    }
    return null;
  }

  String? _validatePin(String value, {String label = 'PIN'}) {
    final v = value.trim();
    if (v.isEmpty) return 'Please enter $label.';
    if (!RegExp(r'^[0-9]{4,8}$').hasMatch(v)) {
      return '$label must be 4 to 8 digits.';
    }
    return null;
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _loginWithPin() async {
    if (_busy) return;

    final usernameError = _validateUsername();
    final pinError = _validatePin(_pinController.text);

    if (usernameError != null) {
      _toast(usernameError);
      return;
    }
    if (pinError != null) {
      _toast(pinError);
      return;
    }

    setState(() => _loggingIn = true);

    try {
      await _service.loginWithPin(
        username: _username(),
        pin: _pinController.text.trim(),
      );

      await _persistRemembered();

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AdminDashboard()),
      );
    } catch (e) {
      _toast('Login failed: $e');
    } finally {
      if (mounted) setState(() => _loggingIn = false);
    }
  }

  Future<void> _requestOtp() async {
    if (_busy) return;

    final usernameError = _validateUsername();
    if (usernameError != null) {
      _toast(usernameError);
      return;
    }

    setState(() {
      _requestingOtp = true;
      _status = null;
    });

    try {
      final challenge = await _service.requestOtp(username: _username());
      if (!mounted) return;

      if ((challenge.retryAfterSeconds ?? 0) > 0 &&
          challenge.challengeId.isEmpty) {
        _toast(
          'OTP was sent recently. Retry in ${challenge.retryAfterSeconds}s.',
        );
        return;
      }

      setState(() {
        _challengeId = challenge.challengeId;
        _otpDelivery = challenge.phoneMasked;
        _status = challenge.pinConfigured
            ? 'OTP sent. Enter OTP + new PIN to reset your PIN.'
            : 'OTP sent. Enter OTP + new PIN to complete first-time setup.';
      });

      _toast(
        _otpDelivery == null
            ? 'OTP sent via WhatsApp.'
            : 'OTP sent to $_otpDelivery',
      );
    } catch (e) {
      _toast('OTP request failed: $e');
    } finally {
      if (mounted) setState(() => _requestingOtp = false);
    }
  }

  Future<void> _verifyOtpAndSetPin() async {
    if (_busy) return;

    final usernameError = _validateUsername();
    if (usernameError != null) {
      _toast(usernameError);
      return;
    }

    if ((_challengeId ?? '').trim().isEmpty) {
      _toast('Request OTP first.');
      return;
    }

    final otp = _otpController.text.trim();
    if (!RegExp(r'^[0-9]{6}$').hasMatch(otp)) {
      _toast('OTP must be 6 digits.');
      return;
    }

    final newPin = _newPinController.text.trim();
    final confirmPin = _confirmPinController.text.trim();

    final pinError = _validatePin(newPin, label: 'new PIN');
    if (pinError != null) {
      _toast(pinError);
      return;
    }

    if (newPin != confirmPin) {
      _toast('PIN confirmation does not match.');
      return;
    }

    setState(() => _verifyingOtp = true);

    try {
      await _service.verifyOtpAndSetPin(
        username: _username(),
        challengeId: _challengeId!,
        otpCode: otp,
        pin: newPin,
        pinConfirmation: confirmPin,
      );

      await _persistRemembered();

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AdminDashboard()),
      );
    } catch (e) {
      _toast('OTP verify failed: $e');
    } finally {
      if (mounted) setState(() => _verifyingOtp = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final disabled = _busy;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/login.png',
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(color: Colors.black),
          ),
          Container(color: Colors.black.withOpacity(0.58)),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 540),
              child: Container(
                padding: const EdgeInsets.all(26),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.64),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.14)),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Image.asset(
                        'assets/images/icon.png',
                        height: 72,
                        width: 72,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.admin_panel_settings,
                          size: 64,
                          color: Colors.amber,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Weather Hooligan Members Admin',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _usernameController,
                        enabled: !disabled,
                        decoration: const InputDecoration(
                          labelText: 'Admin Username',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        onSubmitted: (_) => _loginWithPin(),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _pinController,
                        enabled: !disabled,
                        obscureText: !_showPin,
                        decoration: InputDecoration(
                          labelText: 'PIN',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.pin_outlined),
                          suffixIcon: IconButton(
                            onPressed: disabled
                                ? null
                                : () => setState(() => _showPin = !_showPin),
                            icon: Icon(
                              _showPin
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                          ),
                        ),
                        onSubmitted: (_) => _loginWithPin(),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Checkbox(
                            value: _rememberMe,
                            onChanged: disabled
                                ? null
                                : (v) =>
                                      setState(() => _rememberMe = v ?? true),
                          ),
                          const Expanded(
                            child: Text(
                              'Remember username',
                              style: TextStyle(color: Colors.white70),
                            ),
                          ),
                          TextButton(
                            onPressed: disabled ? null : _requestOtp,
                            child: const Text('Forgot PIN?'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      FilledButton.icon(
                        onPressed: disabled ? null : _loginWithPin,
                        icon: _loggingIn
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.login),
                        label: Text(
                          _loggingIn ? 'Logging in...' : 'Login with PIN',
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Divider(),
                      const SizedBox(height: 10),
                      const Text(
                        'First-time setup or reset PIN',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: disabled ? null : _requestOtp,
                        icon: _requestingOtp
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.chat_outlined),
                        label: const Text('Request OTP via WhatsApp'),
                      ),
                      if ((_status ?? '').trim().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          _status!,
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ],
                      const SizedBox(height: 10),
                      TextField(
                        controller: _otpController,
                        enabled: !disabled,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'OTP Code (6 digits)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.sms_outlined),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _newPinController,
                        enabled: !disabled,
                        obscureText: !_showNewPin,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'New PIN (4-8 digits)',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.password_outlined),
                          suffixIcon: IconButton(
                            onPressed: disabled
                                ? null
                                : () => setState(
                                    () => _showNewPin = !_showNewPin,
                                  ),
                            icon: Icon(
                              _showNewPin
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _confirmPinController,
                        enabled: !disabled,
                        obscureText: !_showConfirmPin,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Confirm PIN',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.password),
                          suffixIcon: IconButton(
                            onPressed: disabled
                                ? null
                                : () => setState(
                                    () => _showConfirmPin = !_showConfirmPin,
                                  ),
                            icon: Icon(
                              _showConfirmPin
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      FilledButton.icon(
                        onPressed: disabled ? null : _verifyOtpAndSetPin,
                        icon: _verifyingOtp
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.verified_outlined),
                        label: Text(
                          _verifyingOtp
                              ? 'Verifying...'
                              : 'Verify OTP + Set PIN',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
