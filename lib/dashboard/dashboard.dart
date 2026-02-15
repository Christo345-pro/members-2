// C:\HOOLIGAN_AP\Weather_Hooligan_members\members\lib\dashboard\dashboard.dart

import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/admin_models.dart';
import '../services/admin_service.dart';
import '../services/admin_push_service.dart';
import '../services/local_member_db_stub.dart'
    if (dart.library.io) '../services/local_member_db.dart';
import '../platform/platform_features.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final _service = AdminService();
  final _memberDb = LocalMemberDb.instance;

  int _tab =
      0; // 0=Members, 1=Payments, 2=Tools, 3=Approvals, 4=Notifications, 5=Ads, 6=Logs, 7=Server

  bool _loading = true;
  String? _error;

  // ---------------- Users ----------------
  List<AdminUser> _users = [];
  int? _selectedUserId;
  AdminUser? _detail;

  // Payments form
  final _payAmountCtrl = TextEditingController();
  final _payRefCtrl = TextEditingController();

  // Tools
  int? _toolsUserId; // separate selection for tools
  String _toolAction = 'Reset password';

  // Create user form
  final _cUsername = TextEditingController();
  final _cEmail = TextEditingController();
  final _cName = TextEditingController();
  final _cSurname = TextEditingController();
  final _cPhone = TextEditingController();
  final _cCellphone = TextEditingController();
  final _cWhatsapp = TextEditingController();
  final _cPassword = TextEditingController();
  final _cPlan = TextEditingController(text: 'free');
  bool _cIsAdmin = false;
  bool _cAppAndroid = false;
  bool _cAppWindows = false;
  bool _cAppWeb = false;

  // Edit user form
  final _eUsername = TextEditingController();
  final _eEmail = TextEditingController();
  final _eName = TextEditingController();
  final _eSurname = TextEditingController();
  final _ePhone = TextEditingController();
  final _eCellphone = TextEditingController();
  final _eWhatsapp = TextEditingController();
  final _ePlan = TextEditingController();
  bool _eIsAdmin = false;
  bool _eIsBlocked = false;
  bool _eAppAndroid = false;
  bool _eAppWindows = false;
  bool _eAppWeb = false;

  // Reset password form
  final _newPwCtrl = TextEditingController();
  final _newPw2Ctrl = TextEditingController();

  bool _busyAction = false;

  // ---------------- Approvals ----------------
  bool _approvalsLoading = false;
  String? _approvalsError;
  List<ProfileChangeRequest> _approvals = [];
  bool _approvalsLoadedOnce = false;

  // ---------------- Alerts / Notices ----------------
  bool _noticesLoading = false;
  String? _noticesError;
  List<AdminNotice> _notices = [];
  bool _noticesLoadedOnce = false;
  bool _pushSending = false;

  // ---------------- Ads ----------------
  bool _adsLoading = false;
  String? _adsError;
  List<AdminAd> _ads = [];
  bool _adsLoadedOnce = false;

  // ---------------- Logs / Sessions ----------------
  bool _sessionsLoading = false;
  String? _sessionsError;
  List<AdminSession> _sessions = [];
  bool _emailLogsLoading = false;
  String? _emailLogsError;
  List<EmailLog> _emailLogs = [];

  // ---------------- Server / Control Center ----------------
  bool _serverLoading = false;
  String? _serverError;
  bool _serverLoadedOnce = false;
  SystemHealth? _health;
  SystemUsage? _usage;
  SystemVisits? _visits;

  bool _auditLoading = false;
  String? _auditError;
  List<AdminAuditLog> _auditLogs = [];

  bool _errorLogsLoading = false;
  String? _errorLogsError;
  List<AdminErrorLog> _errorLogs = [];
  int? _errorLiveSinceId;
  bool _errorLive = false;
  Timer? _errorLiveTimer;

  final _auditActionCtrl = TextEditingController();
  final _auditUserCtrl = TextEditingController();
  final _auditFromCtrl = TextEditingController();
  final _auditToCtrl = TextEditingController();
  final _auditLimitCtrl = TextEditingController(text: '200');

  final _errorLevelCtrl = TextEditingController();
  final _errorUrlCtrl = TextEditingController();
  final _errorExceptionCtrl = TextEditingController();
  final _errorAppCtrl = TextEditingController();
  final _errorMethodCtrl = TextEditingController();
  final _errorIpCtrl = TextEditingController();
  final _errorRequestCtrl = TextEditingController();
  final _errorUserCtrl = TextEditingController();
  final _errorFromCtrl = TextEditingController();
  final _errorToCtrl = TextEditingController();
  final _errorLimitCtrl = TextEditingController(text: '200');
  final _memberSearchCtrl = TextEditingController();
  final _pushMessageCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUsers();
    if (supportsAdminPush) {
      AdminPushService.instance.init(
        onNewMember: (_) {
          _loadUsers(keepSelection: true);
        },
      );
    }
  }

  @override
  void dispose() {
    _payAmountCtrl.dispose();
    _payRefCtrl.dispose();

    _cUsername.dispose();
    _cEmail.dispose();
    _cName.dispose();
    _cSurname.dispose();
    _cPhone.dispose();
    _cCellphone.dispose();
    _cWhatsapp.dispose();
    _cPassword.dispose();
    _cPlan.dispose();

    _eUsername.dispose();
    _eEmail.dispose();
    _eName.dispose();
    _eSurname.dispose();
    _ePhone.dispose();
    _eCellphone.dispose();
    _eWhatsapp.dispose();
    _ePlan.dispose();

    _newPwCtrl.dispose();
    _newPw2Ctrl.dispose();

    _auditActionCtrl.dispose();
    _auditUserCtrl.dispose();
    _auditFromCtrl.dispose();
    _auditToCtrl.dispose();
    _auditLimitCtrl.dispose();

    _errorLevelCtrl.dispose();
    _errorUrlCtrl.dispose();
    _errorExceptionCtrl.dispose();
    _errorAppCtrl.dispose();
    _errorMethodCtrl.dispose();
    _errorIpCtrl.dispose();
    _errorRequestCtrl.dispose();
    _errorUserCtrl.dispose();
    _errorFromCtrl.dispose();
    _errorToCtrl.dispose();
    _errorLimitCtrl.dispose();
    _memberSearchCtrl.dispose();
    _pushMessageCtrl.dispose();

    _errorLiveTimer?.cancel();
    if (supportsLocalDb) {
      _memberDb.close();
    }
    super.dispose();
  }

  // ---------------- Common helpers ----------------
  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _fmtDate(DateTime? dt) {
    if (dt == null) return '—';
    final s = dt.toLocal().toString();
    return s.split('.').first;
  }

  String? _normalizeWhatsAppNumber(String? input) {
    if (input == null) return null;
    var s = input.trim();
    if (s.isEmpty) return null;

    // Keep leading + for now, then strip it, then keep digits only.
    s = s.replaceAll(RegExp(r'[^0-9+]'), '');
    if (s.startsWith('+')) s = s.substring(1);
    if (s.startsWith('00')) s = s.substring(2);
    s = s.replaceAll(RegExp(r'[^0-9]'), '');
    if (s.isEmpty) return null;

    // App UI suggests "10 digits" (SA style: 0#########). Convert to 27#########.
    if (s.length == 10 && s.startsWith('0')) {
      return '27${s.substring(1)}';
    }
    if (s.length == 9 && !s.startsWith('0')) {
      return '27$s';
    }

    // Already in international format (no +), keep as-is (WhatsApp accepts 10-15 digits).
    if (s.length >= 10 && s.length <= 15) return s;

    return null;
  }

  Future<void> _openWhatsApp(String? number, {String? message}) async {
    final phone = _normalizeWhatsAppNumber(number);
    if (phone == null) {
      _toast('Invalid WhatsApp number.');
      return;
    }

    final msg = (message ?? '').trim();

    try {
      // On Windows, try WhatsApp Desktop first (if installed), then fall back to web.
      if (isWindows) {
        final desktopUri = Uri.parse('whatsapp://send').replace(
          queryParameters: {'phone': phone, if (msg.isNotEmpty) 'text': msg},
        );

        if (await canLaunchUrl(desktopUri)) {
          final ok = await launchUrl(
            desktopUri,
            mode: LaunchMode.externalApplication,
          );
          if (ok) return;
        }
      }

      var webUri = Uri.parse('https://wa.me/$phone');
      if (msg.isNotEmpty) {
        webUri = webUri.replace(queryParameters: {'text': msg});
      }

      final ok = await launchUrl(webUri, mode: LaunchMode.externalApplication);
      if (!ok) _toast('Could not open WhatsApp.');
    } catch (e) {
      _toast('Could not open WhatsApp: $e');
    }
  }

  Future<void> _openEmail(
    String? email, {
    String? subject,
    String? body,
  }) async {
    final e = (email ?? '').trim();
    if (e.isEmpty || !e.contains('@')) {
      _toast('Invalid email address.');
      return;
    }

    final subj = (subject ?? '').trim();
    final b = (body ?? '').trim();

    final uri = Uri(
      scheme: 'mailto',
      path: e,
      queryParameters: {
        if (subj.isNotEmpty) 'subject': subj,
        if (b.isNotEmpty) 'body': b,
      },
    );

    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) _toast('Could not open email client.');
    } catch (err) {
      _toast('Could not open email client: $err');
    }
  }

  AdminUser? _findUser(int? id) {
    if (id == null) return null;
    try {
      return _users.firstWhere((u) => u.id == id);
    } catch (_) {
      return null;
    }
  }

  // ---------------- Users: load/list/detail ----------------
  Future<void> _loadUsers({bool keepSelection = true}) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final list = await _service.fetchUsers();
      _users = list;
      if (supportsLocalDb) {
        try {
          await _memberDb.syncFromAdminUsers(_users);
        } catch (e) {
          debugPrint('Local DB sync failed: $e');
        }
      }

      if (_users.isEmpty) {
        _selectedUserId = null;
        _detail = null;
        _toolsUserId = null;
        setState(() {});
        return;
      }

      if (!keepSelection || _selectedUserId == null) {
        _selectedUserId = _users.first.id;
      } else {
        if (!_users.any((u) => u.id == _selectedUserId)) {
          _selectedUserId = _users.first.id;
        }
      }

      _toolsUserId ??= _selectedUserId;

      await _loadDetail(_selectedUserId!);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadDetail(int id) async {
    try {
      final d = await _service.fetchUserDetail(id);
      setState(() => _detail = d);

      if (_toolsUserId == id) {
        _prefillEditFromDetail(d);
      }
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  void _prefillEditFromDetail(AdminUser u) {
    _eUsername.text = u.username;
    _eEmail.text = u.email;
    _eName.text = u.name ?? '';
    _eSurname.text = u.surname ?? '';
    _ePhone.text = u.phone ?? '';
    _eCellphone.text = u.cellphone ?? '';
    _eWhatsapp.text = u.whatsapp ?? '';
    _ePlan.text = u.plan ?? '';
    _eIsAdmin = u.isAdmin ?? false;
    _eIsBlocked = u.isBlocked;
    _eAppAndroid = u.appAndroid ?? false;
    _eAppWindows = u.appWindows ?? false;
    _eAppWeb = u.appWeb ?? false;
  }

  // ---------------- Approvals ----------------
  Future<void> _loadApprovals() async {
    if (_approvalsLoading) return;

    setState(() {
      _approvalsLoading = true;
      _approvalsError = null;
    });

    try {
      final list = await _service.fetchProfileChangeRequests(status: 'pending');
      setState(() {
        _approvals = list;
        _approvalsLoadedOnce = true;
      });
    } catch (e) {
      setState(() => _approvalsError = e.toString());
    } finally {
      if (mounted) setState(() => _approvalsLoading = false);
    }
  }

  // ---------------- Alerts / Notices ----------------
  Future<void> _loadNotices() async {
    if (_noticesLoading) return;

    setState(() {
      _noticesLoading = true;
      _noticesError = null;
    });

    try {
      final list = await _service.fetchNotices(limit: 200);
      setState(() {
        _notices = list;
        _noticesLoadedOnce = true;
      });
    } catch (e) {
      setState(() => _noticesError = e.toString());
    } finally {
      if (mounted) setState(() => _noticesLoading = false);
    }
  }

  Future<void> _sendGeneralPush() async {
    final msg = _pushMessageCtrl.text.trim();
    if (msg.isEmpty) {
      _toast('Please type a message first.');
      return;
    }
    if (_pushSending) return;

    setState(() => _pushSending = true);
    try {
      await _service.sendGeneralPush(title: 'Weather Hooligan', body: msg);
      _pushMessageCtrl.clear();
      _toast('Notification sent ✅');
    } catch (e) {
      _toast('Send failed: $e');
    } finally {
      if (mounted) setState(() => _pushSending = false);
    }
  }

  // ---------------- Sessions ----------------
  Future<void> _loadSessionsForUser(int? userId) async {
    if (userId == null || _sessionsLoading) return;

    setState(() {
      _sessionsLoading = true;
      _sessionsError = null;
    });

    try {
      final list = await _service.fetchUserSessions(userId);
      setState(() => _sessions = list);
    } catch (e) {
      setState(() => _sessionsError = e.toString());
    } finally {
      if (mounted) setState(() => _sessionsLoading = false);
    }
  }

  Future<void> _loadEmailLogsForUser(int? userId) async {
    if (userId == null || _emailLogsLoading) return;

    final email = (_detail?.email ?? '').trim();
    if (email.isEmpty) {
      setState(() => _emailLogs = []);
      return;
    }

    setState(() {
      _emailLogsLoading = true;
      _emailLogsError = null;
    });

    try {
      final list = await _service.fetchEmailLogs(email: email, limit: 50);
      setState(() => _emailLogs = list);
    } catch (e) {
      setState(() => _emailLogsError = e.toString());
    } finally {
      if (mounted) setState(() => _emailLogsLoading = false);
    }
  }

  // ---------------- Server / Control Center ----------------
  DateTime? _parseDateInput(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return null;
    return DateTime.tryParse(s);
  }

  Future<void> _pickDateTime(TextEditingController ctrl) async {
    final now = DateTime.now();
    final existing = _parseDateInput(ctrl.text) ?? now;

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: existing,
      firstDate: DateTime(2020, 1, 1),
      lastDate: now.add(const Duration(days: 365 * 5)),
    );
    if (pickedDate == null) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(existing),
    );

    final time = pickedTime ?? TimeOfDay.fromDateTime(existing);
    final combined = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      time.hour,
      time.minute,
    );
    ctrl.text = combined.toIso8601String();
  }

  void _applyAuditRange(Duration delta, {bool todayOnly = false}) {
    final now = DateTime.now();
    final start = todayOnly
        ? DateTime(now.year, now.month, now.day)
        : now.subtract(delta);
    _auditFromCtrl.text = start.toIso8601String();
    _auditToCtrl.text = now.toIso8601String();
  }

  void _applyErrorRange(Duration delta, {bool todayOnly = false}) {
    final now = DateTime.now();
    final start = todayOnly
        ? DateTime(now.year, now.month, now.day)
        : now.subtract(delta);
    _errorFromCtrl.text = start.toIso8601String();
    _errorToCtrl.text = now.toIso8601String();
  }

  Future<void> _loadServerOverview() async {
    if (_serverLoading) return;

    setState(() {
      _serverLoading = true;
      _serverError = null;
    });

    try {
      final health = await _service.fetchSystemHealth();
      final usage = await _service.fetchSystemUsage();
      final visits = await _service.fetchSystemVisits();

      setState(() {
        _health = health;
        _usage = usage;
        _visits = visits;
        _serverLoadedOnce = true;
      });
    } catch (e) {
      setState(() => _serverError = e.toString());
    } finally {
      if (mounted) setState(() => _serverLoading = false);
    }
  }

  Future<void> _loadAuditLogs() async {
    if (_auditLoading) return;

    setState(() {
      _auditLoading = true;
      _auditError = null;
    });

    try {
      final action = _auditActionCtrl.text.trim();
      final userId = int.tryParse(_auditUserCtrl.text.trim());
      final from = _parseDateInput(_auditFromCtrl.text);
      final to = _parseDateInput(_auditToCtrl.text);
      final limit = int.tryParse(_auditLimitCtrl.text.trim()) ?? 200;

      final logs = await _service.fetchAuditLogs(
        action: action.isEmpty ? null : action,
        userId: userId,
        from: from,
        to: to,
        limit: limit,
      );

      setState(() => _auditLogs = logs);
    } catch (e) {
      setState(() => _auditError = e.toString());
    } finally {
      if (mounted) setState(() => _auditLoading = false);
    }
  }

  Future<void> _clearAuditLogs() async {
    final ok = await _confirmDialog(
      title: 'Clear audit logs?',
      body: 'This cannot be undone.',
      danger: true,
    );
    if (!ok) return;

    try {
      await _service.clearAuditLogs();
      await _loadAuditLogs();
    } catch (e) {
      _toast('Clear failed: $e');
    }
  }

  Future<void> _loadErrorLogs({bool liveTail = false}) async {
    if (_errorLogsLoading) return;

    setState(() {
      _errorLogsLoading = true;
      _errorLogsError = null;
    });

    try {
      final level = _errorLevelCtrl.text.trim();
      final url = _errorUrlCtrl.text.trim();
      final exceptionClass = _errorExceptionCtrl.text.trim();
      final appType = _errorAppCtrl.text.trim();
      final method = _errorMethodCtrl.text.trim();
      final ip = _errorIpCtrl.text.trim();
      final requestId = _errorRequestCtrl.text.trim();
      final userId = int.tryParse(_errorUserCtrl.text.trim());
      final from = _parseDateInput(_errorFromCtrl.text);
      final to = _parseDateInput(_errorToCtrl.text);
      final limit = int.tryParse(_errorLimitCtrl.text.trim()) ?? 200;

      final resp = await _service.fetchErrorLogs(
        level: level.isEmpty ? null : level,
        url: url.isEmpty ? null : url,
        exceptionClass: exceptionClass.isEmpty ? null : exceptionClass,
        appType: appType.isEmpty ? null : appType,
        method: method.isEmpty ? null : method,
        ip: ip.isEmpty ? null : ip,
        requestId: requestId.isEmpty ? null : requestId,
        userId: userId,
        sinceId: liveTail ? _errorLiveSinceId : null,
        from: from,
        to: to,
        limit: limit,
      );

      if (liveTail) {
        if (resp.logs.isNotEmpty) {
          setState(() {
            _errorLogs = [...resp.logs, ..._errorLogs];
            _errorLiveSinceId = resp.latestId ?? _errorLiveSinceId;
          });
        }
      } else {
        setState(() {
          _errorLogs = resp.logs;
          _errorLiveSinceId = resp.latestId;
        });
      }
    } catch (e) {
      setState(() => _errorLogsError = e.toString());
    } finally {
      if (mounted) setState(() => _errorLogsLoading = false);
    }
  }

  Future<void> _clearErrorLogs() async {
    final ok = await _confirmDialog(
      title: 'Clear error logs?',
      body: 'This cannot be undone.',
      danger: true,
    );
    if (!ok) return;

    try {
      await _service.clearErrorLogs();
      await _loadErrorLogs();
    } catch (e) {
      _toast('Clear failed: $e');
    }
  }

  void _setErrorLive(bool on) {
    if (on == _errorLive) return;

    setState(() => _errorLive = on);

    if (on) {
      if (_errorLiveSinceId == null && _errorLogs.isNotEmpty) {
        var maxId = 0;
        for (final log in _errorLogs) {
          if (log.id > maxId) maxId = log.id;
        }
        if (maxId > 0) _errorLiveSinceId = maxId;
      }

      _errorLiveTimer?.cancel();
      _errorLiveTimer = Timer.periodic(
        const Duration(seconds: 5),
        (_) => _loadErrorLogs(liveTail: true),
      );
    } else {
      _errorLiveTimer?.cancel();
      _errorLiveTimer = null;
    }
  }

  Future<void> _loadServerAll() async {
    await _loadServerOverview();
    await _loadAuditLogs();
    await _loadErrorLogs();
  }

  // ---------------- Users actions ----------------
  Future<void> _doToggleBlock(int userId) async {
    setState(() => _busyAction = true);
    try {
      final blocked = await _service.toggleBlock(userId);
      _toast(blocked ? 'User is now blocked 🔒' : 'User unblocked ✅');
      await _loadUsers(keepSelection: true);
    } catch (e) {
      _toast('Block failed: $e');
    } finally {
      if (mounted) setState(() => _busyAction = false);
    }
  }

  Future<void> _doAddPayment() async {
    final id = _selectedUserId;
    if (id == null) return;

    final amt = double.tryParse(_payAmountCtrl.text.trim());
    final ref = _payRefCtrl.text.trim();

    if (amt == null || amt <= 0) {
      _toast('Enter a valid amount.');
      return;
    }
    if (ref.isEmpty) {
      _toast('Enter a reference.');
      return;
    }

    setState(() => _busyAction = true);
    try {
      await _service.addPayment(userId: id, amount: amt, reference: ref);
      _toast('Payment added ✅');
      _payAmountCtrl.clear();
      _payRefCtrl.clear();
      await _loadDetail(id);
    } catch (e) {
      _toast('Payment failed: $e');
    } finally {
      if (mounted) setState(() => _busyAction = false);
    }
  }

  Future<void> _doToolsAction() async {
    setState(() => _busyAction = true);

    try {
      if (_toolAction == 'Create user') {
        final payload = <String, dynamic>{
          'username': _cUsername.text.trim(),
          'email': _cEmail.text.trim(),
          'name': _cName.text.trim(),
          'surname': _cSurname.text.trim().isEmpty
              ? null
              : _cSurname.text.trim(),
          'phone': _cPhone.text.trim().isEmpty ? null : _cPhone.text.trim(),
          'cellphone': _cCellphone.text.trim().isEmpty
              ? null
              : _cCellphone.text.trim(),
          'whatsapp': _cWhatsapp.text.trim().isEmpty
              ? null
              : _cWhatsapp.text.trim(),
          'password': _cPassword.text,
          'plan': _cPlan.text.trim().isEmpty ? 'free' : _cPlan.text.trim(),
          'app_android': _cAppAndroid,
          'app_windows': _cAppWindows,
          'app_web': _cAppWeb,
          'is_admin': _cIsAdmin,
        };

        final created = await _service.createUser(payload);
        _toast('User created ✅');
        try {
          await _service.generateWelcomeEmail(created.id);
          _toast('Welcome email queued ✅');
        } catch (e) {
          _toast('Welcome email not queued: $e');
        }
        await _loadUsers(keepSelection: false);
        return;
      }

      final id = _toolsUserId;
      if (id == null) {
        _toast('Select a user first.');
        return;
      }

      if (_toolAction == 'Edit details') {
        final payload = <String, dynamic>{
          'username': _eUsername.text.trim(),
          'email': _eEmail.text.trim(),
          'name': _eName.text.trim(),
          'surname': _eSurname.text.trim().isEmpty
              ? null
              : _eSurname.text.trim(),
          'phone': _ePhone.text.trim().isEmpty ? null : _ePhone.text.trim(),
          'cellphone': _eCellphone.text.trim().isEmpty
              ? null
              : _eCellphone.text.trim(),
          'whatsapp': _eWhatsapp.text.trim().isEmpty
              ? null
              : _eWhatsapp.text.trim(),
          'plan': _ePlan.text.trim().isEmpty ? 'free' : _ePlan.text.trim(),
          'app_android': _eAppAndroid,
          'app_windows': _eAppWindows,
          'app_web': _eAppWeb,
          'is_admin': _eIsAdmin,
          'is_blocked': _eIsBlocked,
        };

        await _service.updateUser(id, payload);
        _toast('User updated ✅');
        await _loadUsers(keepSelection: true);
        return;
      }

      if (_toolAction == 'Reset password') {
        await _service.sendTemporaryPassword(id);
        _toast('Temporary password emailed ✅');
        return;
      }

      if (_toolAction == 'Revoke tokens') {
        await _service.revokeTokens(id);
        _toast('All tokens revoked ✅ (user forced to login again)');
        return;
      }

      if (_toolAction == 'Delete user') {
        final u = _findUser(id);
        final ok = await _confirmDialog(
          title: 'Delete user?',
          body:
              'This will permanently delete ${u?.username ?? 'this user'}.\n\nAre you sure?',
          danger: true,
        );
        if (!ok) return;

        await _service.deleteUser(id);
        _toast('User deleted ✅');
        _toolsUserId = null;
        await _loadUsers(keepSelection: false);
        return;
      }

      if (_toolAction == 'Toggle block') {
        await _doToggleBlock(id);
        return;
      }

      if (_toolAction == 'Send security verify link') {
        await _service.sendSecurityVerificationLink(id);
        _toast('Security verification link sent ✅');
        return;
      }

      if (_toolAction == 'Resend welcome email') {
        final u = _findUser(id);
        final email = (u?.email ?? '').trim();
        if (email.isEmpty) {
          _toast('User email missing.');
          return;
        }
        final logId = await _service.fetchLatestEmailLogId(
          type: 'welcome',
          email: email,
        );
        if (logId == null) {
          await _service.generateWelcomeEmail(id);
          _toast('Welcome email generated & queued ✅');
          return;
        }
        await _service.resendEmailLog(logId, email: email);
        _toast('Welcome email queued ✅');
        return;
      }

      if (_toolAction == 'Resend invite email') {
        final u = _findUser(id);
        final email = (u?.email ?? '').trim();
        if (email.isEmpty) {
          _toast('User email missing.');
          return;
        }
        final logId = await _service.fetchLatestEmailLogId(
          type: 'signup',
          email: email,
        );
        if (logId == null) {
          _toast('No invite email log found for ${u?.username ?? 'user'}.');
          return;
        }
        await _service.resendEmailLog(logId, email: email);
        _toast('Invite email queued ✅');
        return;
      }
    } catch (e) {
      _toast('Action failed: $e');
    } finally {
      if (mounted) setState(() => _busyAction = false);
    }
  }

  Future<bool> _confirmDialog({
    required String title,
    required String body,
    bool danger = false,
  }) async {
    final res = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: danger
                ? FilledButton.styleFrom(backgroundColor: Colors.redAccent)
                : null,
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    return res ?? false;
  }

  // ---------------- Ads: load/list/delete/upload ----------------
  Future<void> _loadAds() async {
    setState(() {
      _adsLoading = true;
      _adsError = null;
    });

    try {
      final list = await _service.fetchAds();
      setState(() {
        _ads = list;
        _adsLoadedOnce = true;
      });
    } catch (e) {
      setState(() => _adsError = e.toString());
    } finally {
      if (mounted) setState(() => _adsLoading = false);
    }
  }

  Future<void> _deleteAd(AdminAd ad) async {
    final ok = await _confirmDialog(
      title: 'Delete ad?',
      body: 'This will permanently delete:\n\n"${ad.title}"\n\nAre you sure?',
      danger: true,
    );
    if (!ok) return;

    setState(() => _adsLoading = true);
    try {
      await _service.deleteAd(ad.id);
      _toast('Ad deleted ✅');
      await _loadAds();
    } catch (e) {
      _toast('Delete failed: $e');
      if (mounted) setState(() => _adsLoading = false);
    }
  }

  Future<PlatformFile?> _pickImageFile() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
      withData: true,
    );
    return res?.files.single;
  }

  Future<void> _openUploadAdDialog() async {
    final titleCtrl = TextEditingController();
    final msgCtrl = TextEditingController();
    final linkCtrl = TextEditingController();
    final weightCtrl = TextEditingController();

    bool active = true;
    PlatformFile? fullImage;
    PlatformFile? thumbImage;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setLocal) {
          void refresh() => setLocal(() {});

          String fileName(PlatformFile? f) =>
              f == null ? '(not selected)' : f.name;

          return AlertDialog(
            title: const Text('Upload Ad'),
            content: SizedBox(
              width: 560,
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    TextField(
                      controller: titleCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Title',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: msgCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Message (optional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: linkCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Link URL (optional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: weightCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Weight (optional)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SwitchListTile(
                            value: active,
                            onChanged: (v) {
                              active = v;
                              refresh();
                            },
                            title: const Text('Active'),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 26),

                    // Full
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Full image: ${fileName(fullImage)}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 10),
                        OutlinedButton.icon(
                          onPressed: () async {
                            final f = await _pickImageFile();
                            if (f == null) return;
                            fullImage = f;
                            refresh();
                          },
                          icon: const Icon(Icons.image),
                          label: const Text('Pick full'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Thumb
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Thumb 16:9: ${fileName(thumbImage)}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 10),
                        OutlinedButton.icon(
                          onPressed: () async {
                            final f = await _pickImageFile();
                            if (f == null) return;
                            thumbImage = f;
                            refresh();
                          },
                          icon: const Icon(Icons.photo_size_select_large),
                          label: const Text('Pick thumb'),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),
                    const Text('Tip: Thumb should be 16:9 vir mooi cards 😉'),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  if (titleCtrl.text.trim().isEmpty) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('Title is required.')),
                    );
                    return;
                  }
                  if (fullImage == null || fullImage?.bytes == null) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(
                        content: Text('Please pick a FULL image.'),
                      ),
                    );
                    return;
                  }

                  if (thumbImage == null || thumbImage?.bytes == null) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(
                        content: Text('Please pick a THUMB image (16:9).'),
                      ),
                    );
                    return;
                  }

                  Navigator.pop(ctx, true);
                },
                child: const Text('Upload'),
              ),
            ],
          );
        },
      ),
    );

    if (ok != true) {
      titleCtrl.dispose();
      msgCtrl.dispose();
      linkCtrl.dispose();
      weightCtrl.dispose();
      return;
    }

    setState(() => _adsLoading = true);
    try {
      final weight = int.tryParse(weightCtrl.text.trim());

      await _service.uploadAd(
        title: titleCtrl.text.trim(),
        message: msgCtrl.text.trim().isEmpty ? null : msgCtrl.text.trim(),
        linkUrl: linkCtrl.text.trim().isEmpty ? null : linkCtrl.text.trim(),
        active: active,
        weight: weight, // int? (leave null if empty)
        imageBytes: fullImage!.bytes!,
        imageName: fullImage!.name,
        thumbBytes: thumbImage!.bytes!,
        thumbName: thumbImage!.name,
      );

      _toast('Ad uploaded ✅');
      await _loadAds();
    } catch (e) {
      _toast('Upload failed: $e');
      if (mounted) setState(() => _adsLoading = false);
    } finally {
      titleCtrl.dispose();
      msgCtrl.dispose();
      linkCtrl.dispose();
      weightCtrl.dispose();
    }
  }

  // ---------------- UI: build ----------------
  @override
  Widget build(BuildContext context) {
    final selectedUser = _findUser(_selectedUserId);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hooligan Admin Dashboard'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed:
                (_loading ||
                    _busyAction ||
                    _adsLoading ||
                    _approvalsLoading ||
                    _noticesLoading ||
                    _serverLoading ||
                    _auditLoading ||
                    _errorLogsLoading)
                ? null
                : () async {
                    if (_tab == 5) {
                      await _loadAds();
                    } else if (_tab == 6) {
                      await _loadSessionsForUser(_selectedUserId);
                      await _loadEmailLogsForUser(_selectedUserId);
                    } else if (_tab == 7) {
                      await _loadServerAll();
                    } else if (_tab == 3) {
                      await _loadApprovals();
                    } else if (_tab == 4) {
                      await _loadNotices();
                    } else {
                      await _loadUsers(keepSelection: true);
                    }
                  },
            icon: const Icon(Icons.refresh),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _tab,
            onDestinationSelected: (i) async {
              setState(() => _tab = i);

              if (i != 7 && _errorLive) {
                _setErrorLive(false);
              }

              // Lazy load ads on first open
              if (i == 5 && !_adsLoadedOnce && !_adsLoading) {
                await _loadAds();
              }

              // Lazy load approvals
              if (i == 3 && !_approvalsLoadedOnce && !_approvalsLoading) {
                await _loadApprovals();
              }

              // Lazy load alerts
              if (i == 4 && !_noticesLoadedOnce && !_noticesLoading) {
                await _loadNotices();
              }

              // Load sessions for logs tab
              if (i == 6) {
                await _loadSessionsForUser(_selectedUserId);
                await _loadEmailLogsForUser(_selectedUserId);
              }

              // Load server tab
              if (i == 7 && !_serverLoadedOnce && !_serverLoading) {
                await _loadServerAll();
              }
            },
            labelType: NavigationRailLabelType.all,
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.people),
                label: Text('Members'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.payments),
                label: Text('Payments'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.build),
                label: Text('Tools'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.verified),
                label: Text('Approval'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.notifications_active),
                label: Text('Notifications'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.campaign),
                label: Text('Ads'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.list_alt),
                label: Text('Logs'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.storage),
                label: Text('Server'),
              ),
            ],
          ),
          const VerticalDivider(width: 1),

          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text('Error: $_error'),
                    ),
                  )
                : _buildTabBody(selectedUser),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBody(AdminUser? selectedUser) {
    switch (_tab) {
      case 0:
        return _membersTab(selectedUser);
      case 1:
        return _paymentsTab();
      case 2:
        return _toolsTab();
      case 3:
        return _approvalsTab();
      case 4:
        return _alertsTab();
      case 5:
        return _adsTab();
      case 6:
        return _logsTab(selectedUser);
      case 7:
        return _serverTab();
      default:
        return _membersTab(selectedUser);
    }
  }

  // ---------------- Approvals tab ----------------
  Widget _approvalsTab() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Card(
        child: Column(
          children: [
            ListTile(
              title: const Text('Pending Approvals'),
              subtitle: Text('${_approvals.length} request(s)'),
              trailing: IconButton(
                tooltip: 'Refresh approvals',
                onPressed: _approvalsLoading ? null : _loadApprovals,
                icon: const Icon(Icons.refresh),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _approvalsLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _approvalsError != null
                  ? Center(child: Text('Error: $_approvalsError'))
                  : _approvals.isEmpty
                  ? const Center(child: Text('No pending approvals.'))
                  : ListView.builder(
                      itemCount: _approvals.length,
                      itemBuilder: (context, i) {
                        final r = _approvals[i];
                        final u = r.user;
                        final who = u == null
                            ? 'User ${r.userId}'
                            : '${u.name ?? ''} ${u.surname ?? ''}'
                                  .trim()
                                  .isEmpty
                            ? u.username
                            : '${u.name ?? ''} ${u.surname ?? ''}'.trim();

                        final fields = r.fieldsChanged;
                        final fieldsText = fields.isEmpty
                            ? '—'
                            : (fields.length <= 5
                                  ? fields.join(', ')
                                  : '${fields.take(5).join(', ')} +${fields.length - 5}');

                        return ListTile(
                          leading: const Icon(Icons.assignment),
                          title: Text(who),
                          subtitle: Text(
                            'ID: ${r.id} • ${_fmtDate(r.createdAt)}\nFields: $fieldsText',
                          ),
                          isThreeLine: true,
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _openApprovalDialog(r),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openApprovalDialog(ProfileChangeRequest r) async {
    final noteCtrl = TextEditingController();

    String displayValue(String k, dynamic v) {
      if (k.startsWith('security_answer_')) return '(updated)';
      if (v == null) return '—';
      final s = v.toString();
      if (s.length > 120) return '${s.substring(0, 120)}…';
      return s;
    }

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Approve request #${r.id}?'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('User ID: ${r.userId}'),
                const SizedBox(height: 10),
                const Text(
                  'Requested changes:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                ...r.payload.keys.map((k) {
                  final v = r.payload[k];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text('$k: ${displayValue(k, v)}'),
                  );
                }),
                const SizedBox(height: 14),
                TextField(
                  controller: noteCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Admin note (optional)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: _busyAction
                ? null
                : () async {
                    Navigator.pop(context);
                    setState(() => _busyAction = true);
                    try {
                      await _service.rejectProfileChangeRequest(
                        r.id,
                        note: noteCtrl.text.trim(),
                      );
                      _toast('Rejected ✅');
                      await _loadApprovals();
                      await _loadUsers(keepSelection: true);
                    } catch (e) {
                      _toast('Reject failed: $e');
                    } finally {
                      if (mounted) setState(() => _busyAction = false);
                    }
                  },
            child: const Text('Reject'),
          ),
          ElevatedButton(
            onPressed: _busyAction
                ? null
                : () async {
                    Navigator.pop(context);
                    setState(() => _busyAction = true);
                    try {
                      await _service.approveProfileChangeRequest(
                        r.id,
                        note: noteCtrl.text.trim(),
                      );
                      _toast('Approved ✅');
                      await _loadApprovals();
                      await _loadUsers(keepSelection: true);
                    } catch (e) {
                      _toast('Approve failed: $e');
                    } finally {
                      if (mounted) setState(() => _busyAction = false);
                    }
                  },
            child: const Text('Approve'),
          ),
        ],
      ),
    );

    noteCtrl.dispose();
  }

  // ---------------- Alerts tab ----------------
  Widget _alertsTab() {
    IconData iconFor(String severity) {
      switch (severity.toLowerCase()) {
        case 'critical':
          return Icons.error;
        case 'warning':
          return Icons.warning;
        default:
          return Icons.info;
      }
    }

    Color colorFor(String severity) {
      switch (severity.toLowerCase()) {
        case 'critical':
          return Colors.redAccent;
        case 'warning':
          return Colors.amberAccent;
        default:
          return Colors.lightBlueAccent;
      }
    }

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Send Notification'),
                    subtitle: Text('Topic: wh_general • Type: general'),
                  ),
                  TextField(
                    controller: _pushMessageCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Message',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'This will go to all users on the general topic.',
                        ),
                      ),
                      const SizedBox(width: 12),
                      FilledButton.icon(
                        onPressed: _pushSending ? null : _sendGeneralPush,
                        icon: const Icon(Icons.send),
                        label: Text(_pushSending ? 'Sending...' : 'Send'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Card(
              child: Column(
                children: [
                  ListTile(
                    title: const Text('Alerts'),
                    subtitle: Text('${_notices.length} notice(s)'),
                    trailing: IconButton(
                      tooltip: 'Refresh alerts',
                      onPressed: _noticesLoading ? null : _loadNotices,
                      icon: const Icon(Icons.refresh),
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: _noticesLoading
                        ? const Center(child: CircularProgressIndicator())
                        : _noticesError != null
                        ? Center(child: Text('Error: $_noticesError'))
                        : _notices.isEmpty
                        ? const Center(child: Text('No alerts.'))
                        : ListView.builder(
                            itemCount: _notices.length,
                            itemBuilder: (context, i) {
                              final n = _notices[i];
                              final sev = n.severity;
                              final c = colorFor(sev);

                              return ListTile(
                                leading: Icon(iconFor(sev), color: c),
                                title: Text(
                                  n.title,
                                  style: TextStyle(
                                    fontWeight: n.isRead
                                        ? FontWeight.normal
                                        : FontWeight.bold,
                                  ),
                                ),
                                subtitle: Text(
                                  '${_fmtDate(n.createdAt)} • ${n.type}\n${n.body ?? ''}',
                                ),
                                isThreeLine: true,
                                trailing: n.isRead
                                    ? const Icon(
                                        Icons.done,
                                        color: Colors.greenAccent,
                                      )
                                    : TextButton(
                                        onPressed: _busyAction
                                            ? null
                                            : () async {
                                                setState(
                                                  () => _busyAction = true,
                                                );
                                                try {
                                                  await _service.markNoticeRead(
                                                    n.id,
                                                  );
                                                  _toast('Marked read ✅');
                                                  await _loadNotices();
                                                } catch (e) {
                                                  _toast('Failed: $e');
                                                } finally {
                                                  if (mounted) {
                                                    setState(
                                                      () => _busyAction = false,
                                                    );
                                                  }
                                                }
                                              },
                                        child: const Text('Mark read'),
                                      ),
                                onTap: () => _openNoticeDialog(n),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openNoticeDialog(AdminNotice n) async {
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(n.title),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Severity: ${n.severity}'),
                Text('Type: ${n.type}'),
                Text('Time: ${_fmtDate(n.createdAt)}'),
                if ((n.relatedUserId ?? 0) > 0)
                  Text('User ID: ${n.relatedUserId}'),
                const SizedBox(height: 10),
                if ((n.body ?? '').trim().isNotEmpty) Text(n.body!.trim()),
                if (n.payload != null && n.payload!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Payload:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  ...n.payload!.entries.map(
                    (e) => Text('${e.key}: ${e.value}'),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // ---------------- Members tab ----------------
  Widget _membersTab(AdminUser? selectedUser) {
    final q = _memberSearchCtrl.text.trim().toLowerCase();
    final filteredUsers = q.isEmpty
        ? _users
        : _users.where((u) {
            final hay = [
              u.username,
              u.email,
              u.accountNumber ?? '',
              u.name ?? '',
              u.surname ?? '',
              u.phone ?? '',
              u.cellphone ?? '',
              u.whatsapp ?? '',
            ].join(' ').toLowerCase();
            return hay.contains(q);
          }).toList();

    return Row(
      children: [
        SizedBox(
          width: 360,
          child: Card(
            margin: const EdgeInsets.all(12),
            child: Column(
              children: [
                ListTile(
                  title: const Text('Users'),
                  subtitle: Text(
                    q.isEmpty
                        ? '${_users.length} total'
                        : '${filteredUsers.length} of ${_users.length}',
                  ),
                  trailing: IconButton(
                    tooltip: 'Refresh list',
                    onPressed: _busyAction
                        ? null
                        : () => _loadUsers(keepSelection: true),
                    icon: const Icon(Icons.refresh),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: TextField(
                    controller: _memberSearchCtrl,
                    decoration: InputDecoration(
                      labelText: 'Search members',
                      border: const OutlineInputBorder(),
                      suffixIcon: q.isEmpty
                          ? const Icon(Icons.search)
                          : IconButton(
                              tooltip: 'Clear',
                              onPressed: () {
                                _memberSearchCtrl.clear();
                                setState(() {});
                              },
                              icon: const Icon(Icons.clear),
                            ),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.builder(
                    itemCount: filteredUsers.length,
                    itemBuilder: (context, i) {
                      final u = filteredUsers[i];
                      final selected = u.id == _selectedUserId;

                      return ListTile(
                        selected: selected,
                        title: Text(
                          '${u.name ?? ''} ${u.surname ?? ''}'.trim(),
                        ),
                        subtitle: Text(
                          (u.cellphone ?? '').trim().isEmpty
                              ? u.email
                              : '${u.email}\nCell: ${u.cellphone}',
                        ),
                        trailing: u.isBlocked
                            ? const Icon(Icons.lock, color: Colors.redAccent)
                            : const Icon(
                                Icons.lock_open,
                                color: Colors.greenAccent,
                              ),
                        onTap: () async {
                          setState(() => _selectedUserId = u.id);
                          await _loadDetail(u.id);
                          if (_tab == 6) {
                            await _loadSessionsForUser(u.id);
                            await _loadEmailLogsForUser(u.id);
                          }
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),

        Expanded(
          child: Card(
            margin: const EdgeInsets.fromLTRB(0, 12, 12, 12),
            child: _detail == null
                ? const Center(child: Text('Select a user to view details.'))
                : _detailPanel(_detail!),
          ),
        ),
      ],
    );
  }

  Widget _detailPanel(AdminUser u) {
    final isBlocked = u.isBlocked;

    return Padding(
      padding: const EdgeInsets.all(14),
      child: ListView(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${u.name ?? ''} ${u.surname ?? ''}'.trim(),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              if (isBlocked)
                const Chip(
                  label: Text('BLOCKED'),
                  avatar: Icon(Icons.lock, size: 18),
                )
              else
                const Chip(
                  label: Text('ACTIVE'),
                  avatar: Icon(Icons.check_circle, size: 18),
                ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _busyAction ? null : () => _doToggleBlock(u.id),
                icon: Icon(isBlocked ? Icons.lock_open : Icons.lock),
                label: Text(isBlocked ? 'Unblock' : 'Block'),
              ),
            ],
          ),
          const SizedBox(height: 10),

          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              if ((u.accountNumber ?? '').trim().isNotEmpty)
                _kv('Account #', u.accountNumber!),
              _kv('Username', u.username),
              _kv(
                'Email',
                u.email,
                onTap: () => _openEmail(u.email),
                trailing: IconButton(
                  tooltip: 'Compose email',
                  onPressed: () => _openEmail(u.email),
                  icon: const Icon(Icons.email),
                  visualDensity: VisualDensity.compact,
                ),
              ),
              if ((u.phone ?? '').trim().isNotEmpty) _kv('Phone', u.phone!),
              if ((u.cellphone ?? '').trim().isNotEmpty)
                _kv('Cellphone', u.cellphone!),
              if ((u.whatsapp ?? '').trim().isNotEmpty)
                _kv(
                  'WhatsApp',
                  u.whatsapp!,
                  onTap: () => _openWhatsApp(u.whatsapp),
                  trailing: IconButton(
                    tooltip: 'Open WhatsApp',
                    onPressed: () => _openWhatsApp(u.whatsapp),
                    icon: const Icon(Icons.chat),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              _kv('Plan', u.plan ?? '—'),
              _kv('Admin', (u.isAdmin ?? false) ? 'Yes' : 'No'),
              _kv(
                'App Options',
                [
                      if (u.appAndroid == true) 'Android',
                      if (u.appWindows == true) 'Windows',
                    ].isEmpty
                    ? '—'
                    : [
                        if (u.appAndroid == true) 'Android',
                        if (u.appWindows == true) 'Windows',
                      ].join(' / '),
              ),
              _kv('Created', _fmtDate(u.createdAt)),
            ],
          ),

          const SizedBox(height: 18),
          const Divider(),

          Text('Address', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              if ((u.addressLine1 ?? '').trim().isNotEmpty)
                _kv('Address Line 1', u.addressLine1!),
              if ((u.addressLine2 ?? '').trim().isNotEmpty)
                _kv('Address Line 2', u.addressLine2!),
              if ((u.town ?? '').trim().isNotEmpty) _kv('Town', u.town!),
              if ((u.local ?? '').trim().isNotEmpty) _kv('Local', u.local!),
              if ((u.city ?? '').trim().isNotEmpty) _kv('City', u.city!),
              if ((u.metroDistrict ?? '').trim().isNotEmpty)
                _kv('Metro / District', u.metroDistrict!),
              if ((u.province ?? '').trim().isNotEmpty)
                _kv('Province', u.province!),
              if ((u.postalCode ?? '').trim().isNotEmpty)
                _kv('Postal Code', u.postalCode!),
            ],
          ),

          const SizedBox(height: 18),
          const Divider(),

          Text('Payments', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (u.payments.isEmpty)
            const Text('No payments.')
          else
            ...u.payments
                .take(20)
                .map(
                  (p) => ListTile(
                    dense: true,
                    leading: const Icon(Icons.receipt_long),
                    title: Text(
                      '${p.amount?.toStringAsFixed(2) ?? '0.00'} ${p.currency ?? 'ZAR'}',
                    ),
                    subtitle: Text(
                      'Ref: ${p.reference ?? ''} • ${p.status ?? ''}',
                    ),
                    trailing: Text(
                      _fmtDate(p.paymentDate) == '—'
                          ? _fmtDate(p.createdAt)
                          : _fmtDate(p.paymentDate),
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  // ---------------- Payments tab ----------------
  Widget _paymentsTab() {
    final u = _detail;

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Add Manual Payment',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 10),
                    Text('Selected user: ${u?.username ?? '—'}'),
                    const SizedBox(height: 14),

                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _payAmountCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Amount',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _payRefCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Reference',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: (_busyAction || _selectedUserId == null)
                          ? null
                          : _doAddPayment,
                      icon: const Icon(Icons.add),
                      label: const Text('Add payment'),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Tip: After adding, refresh happens automatically 😉',
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Payment History',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: (u == null || u.payments.isEmpty)
                          ? const Center(child: Text('No payments to show.'))
                          : ListView(
                              children: u.payments.map((p) {
                                return ListTile(
                                  leading: const Icon(Icons.receipt),
                                  title: Text(
                                    '${p.amount?.toStringAsFixed(2) ?? '0.00'} ${p.currency ?? 'ZAR'}',
                                  ),
                                  subtitle: Text(
                                    'Ref: ${p.reference ?? ''} • ${p.status ?? ''}',
                                  ),
                                  trailing: Text(
                                    _fmtDate(p.paymentDate) == '—'
                                        ? _fmtDate(p.createdAt)
                                        : _fmtDate(p.paymentDate),
                                  ),
                                );
                              }).toList(),
                            ),
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

  // ---------------- Tools tab ----------------
  Widget _toolsTab() {
    final toolsUser = _findUser(_toolsUserId);

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ListView(
            children: [
              Text(
                'Admin Tools',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              const Text('Use this when the website is being a diva 💅'),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _toolAction == 'Create user'
                          ? null
                          : _toolsUserId,
                      decoration: const InputDecoration(
                        labelText: 'Select user',
                        border: OutlineInputBorder(),
                      ),
                      items: _users
                          .map(
                            (u) => DropdownMenuItem(
                              value: u.id,
                              child: Text('${u.username} • ${u.email}'),
                            ),
                          )
                          .toList(),
                      onChanged: _toolAction == 'Create user'
                          ? null
                          : (v) async {
                              setState(() => _toolsUserId = v);
                              if (v != null) {
                                final d = await _service.fetchUserDetail(v);
                                setState(() {
                                  _detail = d;
                                  _prefillEditFromDetail(d);
                                });
                              }
                            },
                    ),
                  ),
                  const SizedBox(width: 12),

                  SizedBox(
                    width: 260,
                    child: DropdownButtonFormField<String>(
                      initialValue: _toolAction,
                      decoration: const InputDecoration(
                        labelText: 'Action',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'Send security verify link',
                          child: Text('Send security verify link'),
                        ),
                        DropdownMenuItem(
                          value: 'Resend welcome email',
                          child: Text('Resend welcome email'),
                        ),
                        DropdownMenuItem(
                          value: 'Resend invite email',
                          child: Text('Resend invite email'),
                        ),
                        DropdownMenuItem(
                          value: 'Reset password',
                          child: Text('Reset password'),
                        ),
                        DropdownMenuItem(
                          value: 'Revoke tokens',
                          child: Text('Revoke tokens'),
                        ),
                        DropdownMenuItem(
                          value: 'Edit details',
                          child: Text('Edit details'),
                        ),
                        DropdownMenuItem(
                          value: 'Toggle block',
                          child: Text('Toggle block'),
                        ),
                        DropdownMenuItem(
                          value: 'Delete user',
                          child: Text('Delete user'),
                        ),
                        DropdownMenuItem(
                          value: 'Create user',
                          child: Text('Create user'),
                        ),
                      ],
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() {
                          _toolAction = v;
                          if (_toolAction != 'Create user') {
                            _toolsUserId ??= _selectedUserId;
                          }
                        });
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),
              const Divider(),

              if (_toolAction == 'Create user') _toolsCreateUser(),
              if (_toolAction == 'Edit details') _toolsEditUser(toolsUser),
              if (_toolAction == 'Reset password')
                _toolsResetPassword(toolsUser),
              if (_toolAction == 'Send security verify link')
                _toolsSecurityLink(toolsUser),
              if (_toolAction == 'Resend welcome email')
                _toolsResendWelcome(toolsUser),
              if (_toolAction == 'Resend invite email')
                _toolsResendInvite(toolsUser),
              if (_toolAction == 'Revoke tokens') _toolsRevoke(toolsUser),
              if (_toolAction == 'Delete user') _toolsDelete(toolsUser),
              if (_toolAction == 'Toggle block') _toolsBlock(toolsUser),

              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _busyAction ? null : _doToolsAction,
                icon: _busyAction
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.play_arrow),
                label: Text(_busyAction ? 'Working...' : 'Run action'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------- Ads tab ----------------
  Widget _adsTab() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Advertisements',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _adsLoading ? null : _loadAds,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh'),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    onPressed: (!supportsAdsUpload || _adsLoading)
                        ? null
                        : _openUploadAdDialog,
                    icon: const Icon(Icons.upload),
                    label: const Text('Upload'),
                  ),
                ],
              ),
              if (!supportsAdsUpload) ...[
                const SizedBox(height: 8),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Upload only available on Windows.'),
                ),
              ],
              const SizedBox(height: 12),
              const Divider(),

              Expanded(
                child: _adsLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _adsError != null
                    ? Center(child: Text('Error: $_adsError'))
                    : _ads.isEmpty
                    ? const Center(child: Text('No ads yet. Upload one 😄'))
                    : ListView.separated(
                        itemCount: _ads.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final ad = _ads[i];
                          final img = (ad.thumbUrl ?? ad.imageUrl ?? '').trim();

                          return ListTile(
                            leading: _thumbBox(img),
                            title: Text(ad.title),
                            subtitle: Text(
                              [
                                ad.active ? 'ACTIVE' : 'INACTIVE',
                                if ((ad.weight ?? 0) > 0) 'weight=${ad.weight}',
                                if ((ad.linkUrl ?? '').trim().isNotEmpty)
                                  'link set',
                                if (ad.createdAt != null)
                                  'created ${_fmtDate(ad.createdAt)}',
                              ].join(' • '),
                            ),
                            trailing: IconButton(
                              tooltip: 'Delete',
                              onPressed: _adsLoading
                                  ? null
                                  : () => _deleteAd(ad),
                              icon: const Icon(
                                Icons.delete,
                                color: Colors.redAccent,
                              ),
                            ),
                            onTap: img.isEmpty
                                ? null
                                : () => _openAdPreviewDialog(ad),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _thumbBox(String url) {
    const w = 120.0;
    const h = 68.0; // ~16:9

    if (url.isEmpty) {
      return Container(
        width: w,
        height: h,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.black12,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.black12),
        ),
        child: const Icon(Icons.image_not_supported),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: w,
        height: h,
        color: Colors.black12,
        child: Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
              const Center(child: Icon(Icons.broken_image)),
          loadingBuilder: (ctx, child, prog) {
            if (prog == null) return child;
            return const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            );
          },
        ),
      ),
    );
  }

  Future<void> _openAdPreviewDialog(AdminAd ad) async {
    final img = (ad.imageUrl ?? ad.thumbUrl ?? '').trim();
    if (img.isEmpty) return;

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(ad.title),
        content: SizedBox(
          width: 900,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    img,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        const Center(child: Icon(Icons.broken_image)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if ((ad.message ?? '').trim().isNotEmpty)
                Text(ad.message!.trim()),
              const SizedBox(height: 8),
              Text('Created: ${_fmtDate(ad.createdAt)}'),
              Text('Active: ${ad.active ? "Yes" : "No"}'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // ---------------- Tools sub-widgets ----------------
  Widget _toolsCreateUser() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Create User', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 10),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _field(_cUsername, 'Username', width: 260),
            _field(_cEmail, 'Email', width: 340),
            _field(_cName, 'Name', width: 260),
            _field(_cSurname, 'Surname', width: 260),
            _field(_cPhone, 'Phone', width: 200),
            _field(_cCellphone, 'Cellphone (10 digits)', width: 220),
            _field(_cWhatsapp, 'WhatsApp (10 digits)', width: 220),
            _field(_cPlan, 'Plan', width: 160),
            _field(_cPassword, 'Temp Password', width: 260, obscure: true),
          ],
        ),
        const SizedBox(height: 10),
        SwitchListTile(
          value: _cIsAdmin,
          onChanged: (v) => setState(() => _cIsAdmin = v),
          title: const Text('Is Admin'),
        ),
        SwitchListTile(
          value: _cAppAndroid,
          onChanged: (v) => setState(() => _cAppAndroid = v),
          title: const Text('Allow Android App'),
        ),
        SwitchListTile(
          value: _cAppWindows,
          onChanged: (v) => setState(() => _cAppWindows = v),
          title: const Text('Allow Windows App'),
        ),
        SwitchListTile(
          value: _cAppWeb,
          onChanged: (v) => setState(() => _cAppWeb = v),
          title: const Text('Allow Web App'),
        ),
      ],
    );
  }

  Widget _toolsEditUser(AdminUser? toolsUser) {
    if (toolsUser == null) return const Text('Select a user first.');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Edit Details: ${toolsUser.username}',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _field(_eUsername, 'Username', width: 260),
            _field(_eEmail, 'Email', width: 340),
            _field(_eName, 'Name', width: 260),
            _field(_eSurname, 'Surname', width: 260),
            _field(_ePhone, 'Phone', width: 200),
            _field(_eCellphone, 'Cellphone (10 digits)', width: 220),
            _field(_eWhatsapp, 'WhatsApp (10 digits)', width: 220),
            _field(_ePlan, 'Plan', width: 160),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: SwitchListTile(
                value: _eIsAdmin,
                onChanged: (v) => setState(() => _eIsAdmin = v),
                title: const Text('Is Admin'),
              ),
            ),
            Expanded(
              child: SwitchListTile(
                value: _eIsBlocked,
                onChanged: (v) => setState(() => _eIsBlocked = v),
                title: const Text('Blocked'),
              ),
            ),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: SwitchListTile(
                value: _eAppAndroid,
                onChanged: (v) => setState(() => _eAppAndroid = v),
                title: const Text('Allow Android App'),
              ),
            ),
            Expanded(
              child: SwitchListTile(
                value: _eAppWindows,
                onChanged: (v) => setState(() => _eAppWindows = v),
                title: const Text('Allow Windows App'),
              ),
            ),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: SwitchListTile(
                value: _eAppWeb,
                onChanged: (v) => setState(() => _eAppWeb = v),
                title: const Text('Allow Web App'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _toolsResetPassword(AdminUser? toolsUser) {
    if (toolsUser == null) return const Text('Select a user first.');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Reset Password: ${toolsUser.username}',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 10),
        const Text(
          'This will generate a strong temporary password and email it to the user. '
          'The user will be forced to create a new password and confirm it via email before continuing. '
          'This also revokes tokens (forces logout).',
        ),
      ],
    );
  }

  // ---------------- Logs tab ----------------
  Widget _logsTab(AdminUser? selectedUser) {
    final u = _detail;

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(Icons.list_alt),
                  const SizedBox(width: 8),
                  const Text(
                    'License Sessions & Logs',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  if (_users.isNotEmpty)
                    DropdownButton<int>(
                      value: _selectedUserId,
                      items: _users
                          .map(
                            (u) => DropdownMenuItem(
                              value: u.id,
                              child: Text(
                                (u.accountNumber ?? '').trim().isNotEmpty
                                    ? '${u.accountNumber} • ${u.username}'
                                    : u.username,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (id) async {
                        if (id == null) return;
                        setState(() => _selectedUserId = id);
                        await _loadDetail(id);
                        await _loadSessionsForUser(id);
                      },
                    ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Refresh sessions',
                    onPressed: _sessionsLoading
                        ? null
                        : () => _loadSessionsForUser(_selectedUserId),
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
              const Divider(height: 20),

              // Sessions
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Active Sessions',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const SizedBox(height: 8),
              if (_sessionsLoading)
                const Center(child: CircularProgressIndicator())
              else if (_sessionsError != null)
                Text('Error: $_sessionsError')
              else if (_sessions.isEmpty)
                const Text('No active sessions.')
              else
                SizedBox(
                  height: 220,
                  child: ListView.builder(
                    itemCount: _sessions.length,
                    itemBuilder: (context, i) {
                      final s = _sessions[i];
                      return ListTile(
                        leading: const Icon(Icons.devices),
                        title: Text(s.label ?? s.appType ?? 'Unknown'),
                        subtitle: Text('Last used: ${_fmtDate(s.lastUsedAt)}'),
                        trailing: IconButton(
                          tooltip: 'Logout this session',
                          icon: const Icon(Icons.logout),
                          onPressed: () async {
                            await _service.logoutUserByToken(
                              _selectedUserId ?? 0,
                              s.id,
                            );
                            await _loadSessionsForUser(_selectedUserId);
                          },
                        ),
                      );
                    },
                  ),
                ),

              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: _selectedUserId == null
                        ? null
                        : () async {
                            await _service.logoutUserByType(
                              _selectedUserId!,
                              'member_android',
                            );
                            await _loadSessionsForUser(_selectedUserId);
                          },
                    child: const Text('Logout Member Android'),
                  ),
                  OutlinedButton(
                    onPressed: _selectedUserId == null
                        ? null
                        : () async {
                            await _service.logoutUserByType(
                              _selectedUserId!,
                              'member_windows',
                            );
                            await _loadSessionsForUser(_selectedUserId);
                          },
                    child: const Text('Logout Member Windows'),
                  ),
                  OutlinedButton(
                    onPressed: _selectedUserId == null
                        ? null
                        : () async {
                            await _service.logoutUserByType(
                              _selectedUserId!,
                              'member_web',
                            );
                            await _loadSessionsForUser(_selectedUserId);
                          },
                    child: const Text('Logout Member Web'),
                  ),
                  OutlinedButton(
                    onPressed: _selectedUserId == null
                        ? null
                        : () async {
                            await _service.logoutUserByType(
                              _selectedUserId!,
                              'admin_windows',
                            );
                            await _loadSessionsForUser(_selectedUserId);
                          },
                    child: const Text('Logout Admin Windows'),
                  ),
                  OutlinedButton(
                    onPressed: _selectedUserId == null
                        ? null
                        : () async {
                            await _service.logoutUserByType(
                              _selectedUserId!,
                              'admin_web',
                            );
                            await _loadSessionsForUser(_selectedUserId);
                          },
                    child: const Text('Logout Admin Web'),
                  ),
                  OutlinedButton(
                    onPressed: _selectedUserId == null
                        ? null
                        : () async {
                            await _service.logoutUserByType(
                              _selectedUserId!,
                              'admin_member',
                            );
                            await _loadSessionsForUser(_selectedUserId);
                          },
                    child: const Text('Logout Admin Member'),
                  ),
                  OutlinedButton(
                    onPressed: _selectedUserId == null
                        ? null
                        : () async {
                            await _service.logoutUserByType(
                              _selectedUserId!,
                              'admin_android',
                            );
                            await _loadSessionsForUser(_selectedUserId);
                          },
                    child: const Text('Logout Admin Android'),
                  ),
                  OutlinedButton(
                    onPressed: _selectedUserId == null
                        ? null
                        : () async {
                            await _service.logoutUserByType(
                              _selectedUserId!,
                              'admin_adminport',
                            );
                            await _loadSessionsForUser(_selectedUserId);
                          },
                    child: const Text('Logout Admin Adminport'),
                  ),
                  FilledButton(
                    onPressed: _selectedUserId == null
                        ? null
                        : () async {
                            await _service.logoutUserAll(_selectedUserId!);
                            await _loadSessionsForUser(_selectedUserId);
                          },
                    child: const Text('Logout All'),
                  ),
                ],
              ),

              const Divider(height: 32),

              // Recent logins moved here
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Recent Logins',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const SizedBox(height: 8),
              if (u == null)
                const Text('Select a user to view logs.')
              else if (u.loginLogs.isEmpty)
                const Text('No login logs.')
              else
                SizedBox(
                  height: 220,
                  child: ListView(
                    children: u.loginLogs
                        .take(20)
                        .map(
                          (l) => ListTile(
                            dense: true,
                            leading: const Icon(Icons.login),
                            title: Text(_fmtDate(l.loginAt)),
                            subtitle: Text(l.ipAddress ?? ''),
                          ),
                        )
                        .toList(),
                  ),
                ),

              const Divider(height: 32),

              Align(
                alignment: Alignment.centerLeft,
                child: Row(
                  children: [
                    Text(
                      'Email Logs (Welcome / Invite)',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Refresh email logs',
                      onPressed: _emailLogsLoading
                          ? null
                          : () => _loadEmailLogsForUser(_selectedUserId),
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              if (_emailLogsLoading)
                const Center(child: CircularProgressIndicator())
              else if (_emailLogsError != null)
                Text('Error: $_emailLogsError')
              else if (_emailLogs.isEmpty)
                const Text('No welcome/invite email logs for this user.')
              else
                SizedBox(
                  height: 240,
                  child: ListView(
                    children: _emailLogs.map((log) {
                      final typeLabel = log.type == 'signup'
                          ? 'Invite'
                          : (log.type.isEmpty ? 'Email' : log.type);
                      final status = log.status.isEmpty
                          ? 'unknown'
                          : log.status;
                      final when = _fmtDate(
                        log.sentAt ?? log.createdAt ?? DateTime.now(),
                      );
                      return ListTile(
                        dense: true,
                        leading: const Icon(Icons.email),
                        title: Text('$typeLabel • $status'),
                        subtitle: Text('${log.recipientEmail}\n${log.subject}'),
                        trailing: Text(when),
                        isThreeLine: true,
                      );
                    }).toList(),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _toolsSecurityLink(AdminUser? toolsUser) {
    if (toolsUser == null) return const Text('Select a user first.');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Security Verification Link: ${toolsUser.username}',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 10),
        const Text(
          'This emails a secure verification link to the user. The link is valid for 1 hour. '
          'After the user answers their security questions correctly, you will see an alert: '
          '"Security passed".',
        ),
        const SizedBox(height: 8),
        Text('Email: ${toolsUser.email}'),
      ],
    );
  }

  Widget _toolsResendWelcome(AdminUser? toolsUser) {
    if (toolsUser == null) return const Text('Select a user first.');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Resend Welcome Email: ${toolsUser.username}',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        const Text(
          'Queues the most recent welcome email from the email log for this user.',
        ),
        const SizedBox(height: 8),
        Text('Email: ${toolsUser.email}'),
      ],
    );
  }

  Widget _toolsResendInvite(AdminUser? toolsUser) {
    if (toolsUser == null) return const Text('Select a user first.');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Resend Invite Email: ${toolsUser.username}',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        const Text(
          'Queues the most recent signup/invite email from the email log for this user.',
        ),
        const SizedBox(height: 8),
        Text('Email: ${toolsUser.email}'),
      ],
    );
  }

  Widget _toolsRevoke(AdminUser? toolsUser) {
    if (toolsUser == null) return const Text('Select a user first.');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Revoke Tokens: ${toolsUser.username}',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        const Text('Forces the user to login again on all devices.'),
      ],
    );
  }

  Widget _toolsDelete(AdminUser? toolsUser) {
    if (toolsUser == null) return const Text('Select a user first.');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Delete User: ${toolsUser.username}',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        const Text(
          'Permanent. No undo. (Like deleting your favourite braai tongs 😭)',
        ),
      ],
    );
  }

  Widget _toolsBlock(AdminUser? toolsUser) {
    if (toolsUser == null) return const Text('Select a user first.');
    final blocked = toolsUser.isBlocked;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Toggle Block: ${toolsUser.username}',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(
          blocked ? 'User is currently BLOCKED.' : 'User is currently ACTIVE.',
        ),
        const SizedBox(height: 6),
        const Text('Blocking also revokes tokens immediately.'),
      ],
    );
  }

  // ---------------- Server tab ----------------
  Widget _serverTab() {
    final health = _health;
    final usage = _usage;
    final visits = _visits;

    final alerts = <String>[];
    if (health != null) {
      if (!health.db.ok) {
        alerts.add(
          'DB DOWN${health.db.error != null ? ' - ${health.db.error}' : ''}',
        );
      }
      if (!health.cache.ok) {
        alerts.add(
          'CACHE DOWN${health.cache.error != null ? ' - ${health.cache.error}' : ''}',
        );
      }
      if (!health.storage.ok) {
        alerts.add('STORAGE NOT WRITABLE');
      }
      final free = health.disk?.freeMb;
      if (free != null && free < 512) {
        alerts.add('LOW DISK - $free MB free');
      }
    }

    return Padding(
      padding: const EdgeInsets.all(12),
      child: ListView(
        children: [
          Row(
            children: [
              const Icon(Icons.storage),
              const SizedBox(width: 8),
              const Text(
                'Server / Control Center',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              if (_serverLoading)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _serverLoading ? null : _loadServerAll,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh All'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_serverError != null)
            Text(
              'Error: $_serverError',
              style: const TextStyle(color: Colors.redAccent),
            ),
          const SizedBox(height: 8),

          _serverCard(
            title: 'System Health',
            child: health == null
                ? const Text('No data yet.')
                : Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      _kv('Status', health.status),
                      _kv('Server time', health.serverTime ?? '—'),
                      _kv('Env', health.env ?? '—'),
                      _kv('PHP', health.php ?? '—'),
                      _kv('Laravel', health.laravel ?? '—'),
                      _kv(
                        'Disk free',
                        health.disk?.freeMb == null
                            ? 'n/a'
                            : '${health.disk!.freeMb} MB',
                      ),
                      _kv(
                        'Disk total',
                        health.disk?.totalMb == null
                            ? 'n/a'
                            : '${health.disk!.totalMb} MB',
                      ),
                      _kv('DB', health.db.ok ? 'OK' : 'FAIL'),
                      _kv('Cache', health.cache.ok ? 'OK' : 'FAIL'),
                      _kv('Storage', health.storage.ok ? 'OK' : 'FAIL'),
                      _kv('Queue', health.queue ?? '—'),
                    ],
                  ),
          ),

          _serverCard(
            title: 'Usage Snapshot',
            child: usage == null
                ? const Text('No data yet.')
                : Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      _kv(
                        'Users',
                        '${usage.users.total} total, ${usage.users.admins} admins, ${usage.users.blocked} blocked',
                      ),
                      _kv(
                        'Subscribers',
                        '${usage.users.subscribed} active, ${usage.users.expired} expired',
                      ),
                      _kv(
                        'Must change password',
                        '${usage.users.mustChangePassword}',
                      ),
                      _kv(
                        'Android cap',
                        '${usage.appOptions.android.count}/${usage.appOptions.android.cap}',
                      ),
                      _kv(
                        'Windows cap',
                        '${usage.appOptions.windows.count}/${usage.appOptions.windows.cap}',
                      ),
                    ],
                  ),
          ),

          _serverCard(
            title: 'Active Tokens',
            child: usage == null
                ? const Text('No data yet.')
                : (usage.tokensByType.isEmpty)
                ? const Text('No active tokens.')
                : Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: usage.tokensByType
                        .map((t) => _kv(t.appType ?? 'unknown', '${t.count}'))
                        .toList(),
                  ),
          ),

          _serverCard(
            title: 'Recent Activity (24h)',
            child: usage == null
                ? const Text('No data yet.')
                : Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      _kv('Login logs', '${usage.activity.loginLogs24h}'),
                      _kv('Audit logs', '${usage.activity.auditLogs24h}'),
                      _kv('Error logs', '${usage.activity.errorLogs24h}'),
                    ],
                  ),
          ),

          _serverCard(
            title: 'Visit Stats',
            child: visits == null
                ? const Text('No data yet.')
                : Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      _kv('This hour', '${visits.thisHour}'),
                      _kv('Last 24h', '${visits.last24h}'),
                      _kv('Today', '${visits.today}'),
                      _kv('This week', '${visits.thisWeek}'),
                      _kv('This month', '${visits.thisMonth}'),
                      _kv('All time', '${visits.allTime}'),
                      _kv(
                        'Last 14 days',
                        visits.daily.isEmpty
                            ? 'No daily data yet.'
                            : visits.daily
                                  .map((d) => '${d.date}: ${d.count}')
                                  .join(', '),
                      ),
                    ],
                  ),
          ),

          _serverCard(
            title: 'System Alerts',
            child: alerts.isEmpty
                ? const Text('All systems nominal.')
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: alerts
                        .map(
                          (a) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text(
                              a,
                              style: const TextStyle(
                                color: Colors.redAccent,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
          ),

          _serverCard(
            title: 'Audit Logs',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _field(_auditActionCtrl, 'Action', width: 200),
                    _field(_auditUserCtrl, 'User ID', width: 120),
                    _dateField(_auditFromCtrl, 'From', width: 220),
                    _dateField(_auditToCtrl, 'To', width: 220),
                    _field(_auditLimitCtrl, 'Limit', width: 100),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    TextButton(
                      onPressed: _auditLoading
                          ? null
                          : () {
                              _applyAuditRange(const Duration(hours: 24));
                              _loadAuditLogs();
                            },
                      child: const Text('Last 24h'),
                    ),
                    TextButton(
                      onPressed: _auditLoading
                          ? null
                          : () {
                              _applyAuditRange(const Duration(days: 7));
                              _loadAuditLogs();
                            },
                      child: const Text('Last 7d'),
                    ),
                    TextButton(
                      onPressed: _auditLoading
                          ? null
                          : () {
                              _applyAuditRange(
                                const Duration(days: 1),
                                todayOnly: true,
                              );
                              _loadAuditLogs();
                            },
                      child: const Text('Today'),
                    ),
                    TextButton(
                      onPressed: _auditLoading
                          ? null
                          : () {
                              _auditActionCtrl.clear();
                              _auditUserCtrl.clear();
                              _auditFromCtrl.clear();
                              _auditToCtrl.clear();
                            },
                      child: const Text('Clear filters'),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: _auditLoading ? null : _loadAuditLogs,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Refresh'),
                    ),
                    const SizedBox(width: 10),
                    TextButton.icon(
                      onPressed: _auditLoading ? null : _clearAuditLogs,
                      icon: const Icon(
                        Icons.delete_forever,
                        color: Colors.redAccent,
                      ),
                      label: const Text('Clear'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (_auditLoading)
                  const Center(child: CircularProgressIndicator())
                else if (_auditError != null)
                  Text('Error: $_auditError')
                else if (_auditLogs.isEmpty)
                  const Text('No audit logs found.')
                else
                  _auditTable(),
              ],
            ),
          ),

          _serverCard(
            title: 'Error Logs',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _field(_errorLevelCtrl, 'Level', width: 120),
                    _field(_errorUrlCtrl, 'URL contains', width: 220),
                    _field(_errorExceptionCtrl, 'Exception class', width: 260),
                    _field(_errorAppCtrl, 'App type', width: 160),
                    _field(_errorMethodCtrl, 'Method', width: 100),
                    _field(_errorIpCtrl, 'IP', width: 180),
                    _field(_errorRequestCtrl, 'Request ID', width: 220),
                    _field(_errorUserCtrl, 'User ID', width: 120),
                    _dateField(_errorFromCtrl, 'From', width: 220),
                    _dateField(_errorToCtrl, 'To', width: 220),
                    _field(_errorLimitCtrl, 'Limit', width: 100),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    TextButton(
                      onPressed: _errorLogsLoading
                          ? null
                          : () {
                              _errorLevelCtrl.text = 'error';
                              _loadErrorLogs();
                            },
                      child: const Text('Errors'),
                    ),
                    TextButton(
                      onPressed: _errorLogsLoading
                          ? null
                          : () {
                              _errorLevelCtrl.text = 'warning';
                              _loadErrorLogs();
                            },
                      child: const Text('Warnings'),
                    ),
                    TextButton(
                      onPressed: _errorLogsLoading
                          ? null
                          : () {
                              _applyErrorRange(const Duration(hours: 24));
                              _loadErrorLogs();
                            },
                      child: const Text('Last 24h'),
                    ),
                    TextButton(
                      onPressed: _errorLogsLoading
                          ? null
                          : () {
                              _applyErrorRange(const Duration(days: 7));
                              _loadErrorLogs();
                            },
                      child: const Text('Last 7d'),
                    ),
                    TextButton(
                      onPressed: _errorLogsLoading
                          ? null
                          : () {
                              _applyErrorRange(
                                const Duration(days: 1),
                                todayOnly: true,
                              );
                              _loadErrorLogs();
                            },
                      child: const Text('Today'),
                    ),
                    TextButton(
                      onPressed: _errorLogsLoading
                          ? null
                          : () {
                              _errorLevelCtrl.clear();
                              _errorUrlCtrl.clear();
                              _errorExceptionCtrl.clear();
                              _errorAppCtrl.clear();
                              _errorMethodCtrl.clear();
                              _errorIpCtrl.clear();
                              _errorRequestCtrl.clear();
                              _errorUserCtrl.clear();
                              _errorFromCtrl.clear();
                              _errorToCtrl.clear();
                            },
                      child: const Text('Clear filters'),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: _errorLogsLoading ? null : _loadErrorLogs,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Refresh'),
                    ),
                    const SizedBox(width: 10),
                    TextButton.icon(
                      onPressed: _errorLogsLoading ? null : _clearErrorLogs,
                      icon: const Icon(
                        Icons.delete_forever,
                        color: Colors.redAccent,
                      ),
                      label: const Text('Clear'),
                    ),
                    const SizedBox(width: 20),
                    Switch(value: _errorLive, onChanged: _setErrorLive),
                    const Text('Live tail'),
                  ],
                ),
                const SizedBox(height: 10),
                if (_errorLogsLoading)
                  const Center(child: CircularProgressIndicator())
                else if (_errorLogsError != null)
                  Text('Error: $_errorLogsError')
                else if (_errorLogs.isEmpty)
                  const Text('No error logs found.')
                else
                  _errorTable(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _serverCard({required String title, required Widget child}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }

  Widget _auditTable() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Time')),
          DataColumn(label: Text('User')),
          DataColumn(label: Text('Action')),
          DataColumn(label: Text('IP')),
          DataColumn(label: Text('Meta')),
        ],
        rows: _auditLogs.map((log) {
          return DataRow(
            cells: [
              DataCell(Text(_fmtDate(log.createdAt))),
              DataCell(Text(log.userId?.toString() ?? '')),
              DataCell(Text(log.action ?? '')),
              DataCell(Text(log.ip ?? '')),
              DataCell(
                Text(
                  log.meta == null ? '' : log.meta.toString(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _errorTable() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Time')),
          DataColumn(label: Text('Level')),
          DataColumn(label: Text('Message')),
          DataColumn(label: Text('Request')),
          DataColumn(label: Text('User')),
        ],
        rows: _errorLogs.map((log) {
          return DataRow(
            cells: [
              DataCell(Text(_fmtDate(log.createdAt))),
              DataCell(Text(log.level ?? '')),
              DataCell(
                SizedBox(
                  width: 420,
                  child: Text(
                    log.message ?? '',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              DataCell(Text(log.requestId ?? '')),
              DataCell(Text(log.userId?.toString() ?? '')),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _kv(String k, String v, {VoidCallback? onTap, Widget? trailing}) {
    final value = onTap == null
        ? Text(v)
        : MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: onTap,
              child: Text(
                v,
                style: const TextStyle(decoration: TextDecoration.underline),
              ),
            ),
          );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$k: ', style: const TextStyle(fontWeight: FontWeight.bold)),
          value,
          if (trailing != null) ...[const SizedBox(width: 6), trailing],
        ],
      ),
    );
  }

  Widget _field(
    TextEditingController c,
    String label, {
    double width = 260,
    bool obscure = false,
  }) {
    return SizedBox(
      width: width,
      child: TextField(
        controller: c,
        obscureText: obscure,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget _dateField(
    TextEditingController c,
    String label, {
    double width = 220,
  }) {
    return SizedBox(
      width: width,
      child: TextField(
        controller: c,
        readOnly: true,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: IconButton(
            icon: const Icon(Icons.event),
            onPressed: () => _pickDateTime(c),
          ),
        ),
        onTap: () => _pickDateTime(c),
      ),
    );
  }
}
