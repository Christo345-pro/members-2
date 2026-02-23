import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../auth/login_screen.dart';
import '../models/admin_models.dart';
import '../platform/platform_features.dart';
import '../screens/whatsapp_messages_panel.dart';
import '../services/admin_service.dart';
import '../services/local_member_db_stub.dart'
    if (dart.library.io) '../services/local_member_db.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final _service = AdminService();
  final _waInboxKey = GlobalKey<WhatsAppMessagesPanelState>();

  static const String _whatsAppDefaultCountryCode = String.fromEnvironment(
    'MEMBERS_WHATSAPP_DEFAULT_COUNTRY_CODE',
    defaultValue: '27',
  );
  static const String _whatsAppMessageTemplate = String.fromEnvironment(
    'MEMBERS_WHATSAPP_MESSAGE_TEMPLATE',
    defaultValue: 'Hello {name}, this is Weather Hooligan support.',
  );
  static const String _whatsAppMessageDefault = String.fromEnvironment(
    'MEMBERS_WHATSAPP_MESSAGE_DEFAULT',
    defaultValue: 'Hello from Weather Hooligan support.',
  );
  static const String _whatsAppSchemeBase = String.fromEnvironment(
    'MEMBERS_WHATSAPP_SCHEME_BASE',
    defaultValue: 'whatsapp://send',
  );
  static const String _whatsAppWebBase = String.fromEnvironment(
    'MEMBERS_WHATSAPP_WEB_BASE',
    defaultValue: 'https://wa.me',
  );

  int _tab = 0;

  bool _membersLoading = false;
  String? _membersError;
  List<AdminUser> _members = [];
  int? _selectedMemberId;
  AdminUser? _memberDetail;

  final _memberSearchCtrl = TextEditingController();
  final _memberNameCtrl = TextEditingController();
  final _memberAccountCtrl = TextEditingController();
  final _memberEmailCtrl = TextEditingController();
  final _memberDateCtrl = TextEditingController();
  String _memberPlanFilter = 'all';

  bool _toolsBusy = false;
  int? _toolsUserId;
  String _toolsAction = 'Create user';
  final _toolCreateUsernameCtrl = TextEditingController();
  final _toolCreateEmailCtrl = TextEditingController();
  final _toolCreateNameCtrl = TextEditingController();
  final _toolCreateSurnameCtrl = TextEditingController();
  final _toolCreatePhoneCtrl = TextEditingController();
  final _toolCreateWhatsAppCtrl = TextEditingController();
  final _toolCreatePlanCtrl = TextEditingController(text: 'free');
  final _toolCreatePasswordCtrl = TextEditingController();
  bool _toolCreateAndroid = false;
  bool _toolCreateWindows = false;
  bool _toolCreateWeb = false;
  final _toolPasswordCtrl = TextEditingController();
  final _toolPasswordConfirmCtrl = TextEditingController();

  bool _pushSending = false;
  final _pushMessageCtrl = TextEditingController();

  bool _adsLoading = false;
  String? _adsError;
  List<AdminAd> _appPortalAds = [];
  List<AdminAd> _largeAds = [];
  List<AdminAd> _smallAds = [];

  bool _invitesLoading = false;
  bool _inviteSending = false;
  String? _invitesError;
  List<AdminInvite> _invites = [];
  String _inviteStatus = 'all';
  final _inviteSearchCtrl = TextEditingController();
  final _inviteDateCtrl = TextEditingController();

  final _inviteNameCtrl = TextEditingController();
  final _inviteSurnameCtrl = TextEditingController();
  final _inviteEmailCtrl = TextEditingController();
  final _inviteWhatsappCtrl = TextEditingController();

  bool _invoicesLoading = false;
  String? _invoicesError;
  List<AdminInvoice> _invoices = [];
  String _invoiceStatus = 'all';
  bool _invoiceSelectedMemberOnly = false;
  final _invoiceSearchCtrl = TextEditingController();
  final _invoiceDateCtrl = TextEditingController();
  String _invoiceMethodFilter = 'all';

  bool _callsLoading = false;
  String? _callsError;
  List<AdminWhatsAppCall> _calls = [];
  String _callsAdminStatus = 'all';
  String _callsDirection = 'all';
  String _callsEventStatus = 'all';
  int? _updatingCallId;
  final _callsSearchCtrl = TextEditingController();

  bool _statsLoading = false;
  String? _statsError;
  AdminTrafficStats? _trafficStats;
  AdminLogSnapshot? _logSnapshot;
  int _logLineLimit = 400;
  final _statsSearchCtrl = TextEditingController();
  final _statsDateCtrl = TextEditingController();
  String _statsLevelFilter = 'all';

  final _adsSearchCtrl = TextEditingController();

  bool _localDbSyncing = false;
  String? _localDbError;
  String? _localDbPath;
  int _localDbCount = 0;

  @override
  void initState() {
    super.initState();
    _loadMembers();
    if (supportsLocalDb) {
      _refreshLocalDbSummary();
    }
  }

  @override
  void dispose() {
    _memberSearchCtrl.dispose();
    _memberNameCtrl.dispose();
    _memberAccountCtrl.dispose();
    _memberEmailCtrl.dispose();
    _memberDateCtrl.dispose();
    _toolCreateUsernameCtrl.dispose();
    _toolCreateEmailCtrl.dispose();
    _toolCreateNameCtrl.dispose();
    _toolCreateSurnameCtrl.dispose();
    _toolCreatePhoneCtrl.dispose();
    _toolCreateWhatsAppCtrl.dispose();
    _toolCreatePlanCtrl.dispose();
    _toolCreatePasswordCtrl.dispose();
    _toolPasswordCtrl.dispose();
    _toolPasswordConfirmCtrl.dispose();
    _pushMessageCtrl.dispose();
    _adsSearchCtrl.dispose();

    _inviteSearchCtrl.dispose();
    _inviteDateCtrl.dispose();
    _inviteNameCtrl.dispose();
    _inviteSurnameCtrl.dispose();
    _inviteEmailCtrl.dispose();
    _inviteWhatsappCtrl.dispose();
    _invoiceSearchCtrl.dispose();
    _invoiceDateCtrl.dispose();
    _statsSearchCtrl.dispose();
    _statsDateCtrl.dispose();
    _callsSearchCtrl.dispose();

    super.dispose();
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _fmtDate(DateTime? dt) {
    if (dt == null) return '—';
    return dt.toLocal().toString().split('.').first;
  }

  bool _containsText(String? value, String needle) {
    final hay = (value ?? '').toLowerCase();
    final token = needle.trim().toLowerCase();
    if (token.isEmpty) return true;
    return hay.contains(token);
  }

  bool _dateMatches(DateTime? dt, String token) {
    final value = token.trim().toLowerCase();
    if (value.isEmpty) return true;
    if (dt == null) return false;

    final iso = dt.toIso8601String().toLowerCase();
    final local = _fmtDate(dt).toLowerCase();
    final compact = iso.split('t').first;
    return iso.contains(value) ||
        local.contains(value) ||
        compact.contains(value);
  }

  bool _logMatchesLevel(String line, String level) {
    final value = line.toLowerCase();
    switch (level) {
      case 'error':
        return value.contains('.error') ||
            value.contains(' error ') ||
            value.contains('exception') ||
            value.contains('fatal');
      case 'warning':
        return value.contains('.warning') || value.contains(' warning ');
      case 'info':
        return value.contains('.info') || value.contains(' info ');
      case 'debug':
        return value.contains('.debug') || value.contains(' debug ');
      default:
        return true;
    }
  }

  Future<void> _logout() async {
    try {
      await _service.logout();
    } catch (_) {}

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => AdminLoginScreen(service: AdminService()),
      ),
      (_) => false,
    );
  }

  Future<void> _refreshCurrentTab() async {
    switch (_tab) {
      case 0:
        await _loadMembers();
        break;
      case 1:
        await _loadMembers();
        break;
      case 2:
        break;
      case 3:
        await _loadAds();
        break;
      case 4:
        await _loadInvites();
        break;
      case 5:
        await _loadInvoices();
        break;
      case 6:
        await _loadStats();
        break;
      case 7:
        await _waInboxKey.currentState?.refreshAll();
        break;
      case 8:
        await _loadWhatsAppCalls();
        break;
    }
  }

  Future<void> _loadMembers() async {
    if (_membersLoading) return;

    setState(() {
      _membersLoading = true;
      _membersError = null;
    });

    try {
      final list = await _service.fetchMembers(
        query: _memberSearchCtrl.text.trim(),
        limit: 300,
      );

      _members = list;
      await _syncMembersToLocalDb(list);

      if (_members.isEmpty) {
        if (!mounted) return;
        setState(() {
          _selectedMemberId = null;
          _toolsUserId = null;
          _memberDetail = null;
        });
        return;
      }

      _selectedMemberId ??= _members.first.id;
      if (!_members.any((u) => u.id == _selectedMemberId)) {
        _selectedMemberId = _members.first.id;
      }
      _toolsUserId ??= _selectedMemberId;
      if (!_members.any((u) => u.id == _toolsUserId)) {
        _toolsUserId = _selectedMemberId;
      }

      final detail = await _service.fetchMemberDetail(_selectedMemberId!);
      if (!mounted) return;

      setState(() {
        _memberDetail = detail;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _membersError = e.toString());
    } finally {
      if (mounted) setState(() => _membersLoading = false);
    }
  }

  Future<void> _syncMembersToLocalDb(List<AdminUser> users) async {
    if (!supportsLocalDb) return;

    if (mounted) {
      setState(() {
        _localDbSyncing = true;
        _localDbError = null;
      });
    }

    try {
      await LocalMemberDb.instance.syncFromAdminUsers(users);
      await _refreshLocalDbSummary();
    } catch (e) {
      if (!mounted) return;
      setState(() => _localDbError = e.toString());
    } finally {
      if (mounted) setState(() => _localDbSyncing = false);
    }
  }

  Future<void> _refreshLocalDbSummary() async {
    if (!supportsLocalDb) return;

    final members = await LocalMemberDb.instance.getMembers();
    final path = await LocalMemberDb.instance.databasePath();

    if (!mounted) return;
    setState(() {
      _localDbCount = members.length;
      _localDbPath = path;
    });
  }

  Future<void> _exportLocalDbJson() async {
    if (!supportsLocalDb || _localDbSyncing) return;

    setState(() {
      _localDbSyncing = true;
      _localDbError = null;
    });

    try {
      final path = await LocalMemberDb.instance.exportJsonSnapshot();
      if (!mounted) return;
      _toast('Customer export created: $path');
    } catch (e) {
      if (!mounted) return;
      setState(() => _localDbError = e.toString());
      _toast('Export failed: $e');
    } finally {
      if (mounted) setState(() => _localDbSyncing = false);
    }
  }

  Future<void> _selectMember(AdminUser user) async {
    if (_selectedMemberId == user.id && _memberDetail != null) return;

    setState(() {
      _selectedMemberId = user.id;
      _toolsUserId = user.id;
      _membersLoading = true;
      _membersError = null;
    });

    try {
      final detail = await _service.fetchMemberDetail(user.id);
      if (!mounted) return;
      setState(() => _memberDetail = detail);
    } catch (e) {
      _toast('Load member failed: $e');
    } finally {
      if (mounted) setState(() => _membersLoading = false);
    }
  }

  AdminUser? _findMemberById(int? id) {
    if (id == null) return null;
    for (final member in _members) {
      if (member.id == id) return member;
    }
    return null;
  }

  void _resetCreateUserToolForm() {
    _toolCreateUsernameCtrl.clear();
    _toolCreateEmailCtrl.clear();
    _toolCreateNameCtrl.clear();
    _toolCreateSurnameCtrl.clear();
    _toolCreatePhoneCtrl.clear();
    _toolCreateWhatsAppCtrl.clear();
    _toolCreatePlanCtrl.text = 'free';
    _toolCreatePasswordCtrl.clear();
    _toolCreateAndroid = false;
    _toolCreateWindows = false;
    _toolCreateWeb = false;
  }

  Future<void> _runToolsAction() async {
    if (_toolsBusy) return;

    setState(() => _toolsBusy = true);
    try {
      if (_toolsAction == 'Create user') {
        final username = _toolCreateUsernameCtrl.text.trim();
        final email = _toolCreateEmailCtrl.text.trim().toLowerCase();
        final name = _toolCreateNameCtrl.text.trim();
        final password = _toolCreatePasswordCtrl.text;

        if (username.isEmpty || email.isEmpty || name.isEmpty) {
          _toast('Username, email and name are required.');
          return;
        }
        if (password.trim().length < 8) {
          _toast('Password must be at least 8 characters.');
          return;
        }

        final created = await _service.createMemberUser(
          username: username,
          email: email,
          name: name,
          surname: _toolCreateSurnameCtrl.text.trim().isEmpty
              ? null
              : _toolCreateSurnameCtrl.text.trim(),
          phone: _toolCreatePhoneCtrl.text.trim().isEmpty
              ? null
              : _toolCreatePhoneCtrl.text.trim(),
          whatsapp: _toolCreateWhatsAppCtrl.text.trim().isEmpty
              ? null
              : _toolCreateWhatsAppCtrl.text.trim(),
          password: password,
          plan: _toolCreatePlanCtrl.text.trim().isEmpty
              ? null
              : _toolCreatePlanCtrl.text.trim(),
          appAndroid: _toolCreateAndroid,
          appWindows: _toolCreateWindows,
          appWeb: _toolCreateWeb,
        );

        _toast('User created: ${created.username}');
        _resetCreateUserToolForm();
        await _loadMembers();
        if (!mounted) return;
        setState(() {
          _selectedMemberId = created.id;
          _toolsUserId = created.id;
        });
        return;
      }

      final targetId = _toolsUserId ?? _selectedMemberId;
      if (targetId == null) {
        _toast('Select a user first.');
        return;
      }

      if (_toolsAction == 'Set password') {
        final password = _toolPasswordCtrl.text;
        final confirm = _toolPasswordConfirmCtrl.text;
        if (password.trim().length < 8) {
          _toast('Password must be at least 8 characters.');
          return;
        }
        if (password != confirm) {
          _toast('Password confirmation does not match.');
          return;
        }

        await _service.setMemberPassword(
          userId: targetId,
          newPassword: password,
        );
        _toolPasswordCtrl.clear();
        _toolPasswordConfirmCtrl.clear();
        _toast('Password updated. User sessions revoked.');
        return;
      }

      if (_toolsAction == 'Toggle block') {
        final blocked = await _service.toggleMemberBlock(targetId);
        _toast(blocked ? 'User blocked.' : 'User unblocked.');
        await _loadMembers();
        if (!mounted) return;
        setState(() {
          _selectedMemberId = targetId;
          _toolsUserId = targetId;
        });
        return;
      }

      _toast('Unknown tools action: $_toolsAction');
    } catch (e) {
      _toast('Tools action failed: $e');
    } finally {
      if (mounted) setState(() => _toolsBusy = false);
    }
  }

  Widget _toolsField(
    TextEditingController controller,
    String label, {
    double width = 260,
    bool obscure = false,
  }) {
    return SizedBox(
      width: width,
      child: TextField(
        controller: controller,
        obscureText: obscure,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Future<void> _sendGeneralPush() async {
    final msg = _pushMessageCtrl.text.trim();
    if (msg.isEmpty) {
      _toast('Type a message first.');
      return;
    }
    if (_pushSending) return;

    setState(() => _pushSending = true);
    try {
      await _service.sendGeneralPush(title: 'Weather Hooligan', body: msg);
      _pushMessageCtrl.clear();
      _toast('General notification sent to topic wh_general.');
    } catch (e) {
      _toast('Send failed: $e');
    } finally {
      if (mounted) setState(() => _pushSending = false);
    }
  }

  Future<void> _loadAds({bool force = false}) async {
    if (_adsLoading && !force) return;

    setState(() {
      _adsLoading = true;
      _adsError = null;
    });

    try {
      final appPortalFuture = _service.fetchAds();
      final largeFuture = _service.fetchLargeAds();
      final smallFuture = _service.fetchSmallAds();
      final appPortal = await appPortalFuture;
      final large = await largeFuture;
      final small = await smallFuture;
      if (!mounted) return;
      setState(() {
        _appPortalAds = appPortal;
        _largeAds = large;
        _smallAds = small;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _adsError = e.toString());
    } finally {
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

  Future<void> _deletePlacementAd({
    required AdminAd ad,
    required String placementLabel,
    required Future<void> Function(int id) deleteAction,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete ad?'),
        content: Text('Delete $placementLabel ad "${ad.title}" permanently?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    setState(() => _adsLoading = true);
    try {
      await deleteAction(ad.id);
      await _loadAds(force: true);
      _toast('$placementLabel ad deleted.');
    } catch (e) {
      _toast('Delete failed: $e');
      if (mounted) setState(() => _adsLoading = false);
    }
  }

  Future<void> _deleteLargeAd(AdminAd ad) async {
    await _deletePlacementAd(
      ad: ad,
      placementLabel: 'large',
      deleteAction: _service.deleteLargeAd,
    );
  }

  Future<void> _deleteSmallAd(AdminAd ad) async {
    await _deletePlacementAd(
      ad: ad,
      placementLabel: 'small',
      deleteAction: _service.deleteSmallAd,
    );
  }

  Future<void> _openUploadLargeAdDialog() async {
    await _openUploadPlacementAdDialog(isLarge: true);
  }

  Future<void> _openUploadSmallAdDialog() async {
    await _openUploadPlacementAdDialog(isLarge: false);
  }

  Future<void> _openUploadPlacementAdDialog({required bool isLarge}) async {
    final titleCtrl = TextEditingController();
    final msgCtrl = TextEditingController();
    final linkCtrl = TextEditingController();
    final weightCtrl = TextEditingController();

    bool active = true;
    PlatformFile? imageFile;
    final placementLabel = isLarge ? 'Large' : 'Small';

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setLocal) {
          String fileName(PlatformFile? f) =>
              f == null ? '(not selected)' : f.name;

          return AlertDialog(
            title: Text('Upload $placementLabel Advertisement'),
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
                    const SizedBox(height: 10),
                    TextField(
                      controller: msgCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Message (optional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: linkCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Link URL (optional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
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
                        const SizedBox(width: 10),
                        Expanded(
                          child: SwitchListTile(
                            value: active,
                            onChanged: (v) => setLocal(() => active = v),
                            title: const Text('Active'),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 20),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Upload specs',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        isLarge
                            ? 'Large ad for main/login/about rotobox: 1920x1080 preferred (minimum 1600x900).'
                            : 'Small ad for features/pricing/contact/signup/register rotobox: 1366x768 preferred (minimum 960x540).',
                      ),
                    ),
                    const Divider(height: 20),

                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '$placementLabel image: ${fileName(imageFile)}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          onPressed: () async {
                            final f = await _pickImageFile();
                            if (f == null) return;
                            setLocal(() => imageFile = f);
                          },
                          child: Text('Pick $placementLabel'),
                        ),
                      ],
                    ),
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
                  if (imageFile == null || imageFile?.bytes == null) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(
                        content: Text('Pick the $placementLabel image.'),
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
      if (isLarge) {
        await _service.uploadLargeAd(
          title: titleCtrl.text.trim(),
          message: msgCtrl.text.trim().isEmpty ? null : msgCtrl.text.trim(),
          linkUrl: linkCtrl.text.trim().isEmpty ? null : linkCtrl.text.trim(),
          active: active,
          weight: int.tryParse(weightCtrl.text.trim()),
          imageBytes: imageFile!.bytes!,
          imageName: imageFile!.name,
        );
      } else {
        await _service.uploadSmallAd(
          title: titleCtrl.text.trim(),
          message: msgCtrl.text.trim().isEmpty ? null : msgCtrl.text.trim(),
          linkUrl: linkCtrl.text.trim().isEmpty ? null : linkCtrl.text.trim(),
          active: active,
          weight: int.tryParse(weightCtrl.text.trim()),
          imageBytes: imageFile!.bytes!,
          imageName: imageFile!.name,
        );
      }
      await _loadAds(force: true);
      _toast('$placementLabel ad uploaded.');
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

  Future<void> _deleteAppPortalAd(AdminAd ad) async {
    await _deletePlacementAd(
      ad: ad,
      placementLabel: 'app/portal',
      deleteAction: _service.deleteAd,
    );
  }

  Future<void> _openUploadAppPortalAdDialog() async {
    final titleCtrl = TextEditingController();
    final msgCtrl = TextEditingController();
    final linkCtrl = TextEditingController();
    final weightCtrl = TextEditingController();

    bool active = true;
    PlatformFile? fullImage;
    PlatformFile? thumbImage;
    PlatformFile? smallImage;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setLocal) {
          String fileName(PlatformFile? f) =>
              f == null ? '(not selected)' : f.name;

          return AlertDialog(
            title: const Text('Upload App + Portal Ad (Full + Thumb)'),
            content: SizedBox(
              width: 600,
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
                    const SizedBox(height: 10),
                    TextField(
                      controller: msgCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Message (optional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: linkCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Link URL (optional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
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
                        const SizedBox(width: 10),
                        Expanded(
                          child: SwitchListTile(
                            value: active,
                            onChanged: (v) => setLocal(() => active = v),
                            title: const Text('Active'),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 20),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Full + Thumb are used by the user app and portal.',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Full: required • Thumb: required • Small: optional fallback.',
                      ),
                    ),
                    const Divider(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Full image: ${fileName(fullImage)}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          onPressed: () async {
                            final f = await _pickImageFile();
                            if (f == null) return;
                            setLocal(() => fullImage = f);
                          },
                          child: const Text('Pick Full'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Thumb image: ${fileName(thumbImage)}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          onPressed: () async {
                            final f = await _pickImageFile();
                            if (f == null) return;
                            setLocal(() => thumbImage = f);
                          },
                          child: const Text('Pick Thumb'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Small image (optional): ${fileName(smallImage)}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          onPressed: () async {
                            final f = await _pickImageFile();
                            if (f == null) return;
                            setLocal(() => smallImage = f);
                          },
                          child: const Text('Pick Small'),
                        ),
                      ],
                    ),
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
                      const SnackBar(content: Text('Pick the full image.')),
                    );
                    return;
                  }
                  if (thumbImage == null || thumbImage?.bytes == null) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('Pick the thumb image.')),
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
      await _service.uploadAd(
        title: titleCtrl.text.trim(),
        message: msgCtrl.text.trim().isEmpty ? null : msgCtrl.text.trim(),
        linkUrl: linkCtrl.text.trim().isEmpty ? null : linkCtrl.text.trim(),
        active: active,
        weight: int.tryParse(weightCtrl.text.trim()),
        imageBytes: fullImage!.bytes!,
        imageName: fullImage!.name,
        smallBytes: smallImage?.bytes,
        smallName: smallImage?.name,
        thumbBytes: thumbImage!.bytes!,
        thumbName: thumbImage!.name,
      );
      await _loadAds(force: true);
      _toast('App + portal ad uploaded.');
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

  Future<void> _loadStats({bool force = false}) async {
    if (_statsLoading && !force) return;

    setState(() {
      _statsLoading = true;
      _statsError = null;
    });

    try {
      final trafficFuture = _service.fetchTrafficStats();
      final logsFuture = _service.fetchLaravelLogs(lines: _logLineLimit);
      final traffic = await trafficFuture;
      final logs = await logsFuture;

      if (!mounted) return;
      setState(() {
        _trafficStats = traffic;
        _logSnapshot = logs;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _statsError = e.toString());
    } finally {
      if (mounted) setState(() => _statsLoading = false);
    }
  }

  Future<void> _clearStatsLogs() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Clear Laravel logs?'),
        content: const Text(
          'This will remove historical log lines from all current log files.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear Logs'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    setState(() {
      _statsLoading = true;
      _statsError = null;
    });
    try {
      await _service.clearLaravelLogs();
      if (!mounted) return;
      _toast('Laravel logs cleared.');
    } catch (e) {
      if (!mounted) return;
      _toast('Clear logs failed: $e');
      setState(() => _statsLoading = false);
      return;
    }

    if (!mounted) return;
    await _loadStats(force: true);
  }

  Future<void> _loadInvites() async {
    if (_invitesLoading) return;

    setState(() {
      _invitesLoading = true;
      _invitesError = null;
    });

    try {
      final list = await _service.fetchInvites(
        status: _inviteStatus,
        limit: 250,
      );
      if (!mounted) return;
      setState(() => _invites = list);
    } catch (e) {
      if (!mounted) return;
      setState(() => _invitesError = e.toString());
    } finally {
      if (mounted) setState(() => _invitesLoading = false);
    }
  }

  Future<void> _createInvite() async {
    if (_inviteSending) return;

    final name = _inviteNameCtrl.text.trim();
    final surname = _inviteSurnameCtrl.text.trim();
    final email = _inviteEmailCtrl.text.trim();
    final whatsapp = _inviteWhatsappCtrl.text.trim();

    if (name.isEmpty || surname.isEmpty || email.isEmpty || whatsapp.isEmpty) {
      _toast('Name, surname, email and WhatsApp are required.');
      return;
    }

    setState(() => _inviteSending = true);
    try {
      await _service.createInvite(
        name: name,
        surname: surname,
        email: email,
        whatsappPhone: whatsapp,
      );

      _inviteNameCtrl.clear();
      _inviteSurnameCtrl.clear();
      _inviteEmailCtrl.clear();
      _inviteWhatsappCtrl.clear();

      await _loadInvites();
      _toast('Invite email sent.');
    } catch (e) {
      _toast('Invite failed: $e');
    } finally {
      if (mounted) setState(() => _inviteSending = false);
    }
  }

  Future<void> _resendInvite(AdminInvite invite) async {
    try {
      await _service.resendInvite(invite.id);
      await _loadInvites();
      _toast('Invite resent.');
    } catch (e) {
      _toast('Resend failed: $e');
    }
  }

  Future<void> _loadInvoices() async {
    if (_invoicesLoading) return;

    setState(() {
      _invoicesLoading = true;
      _invoicesError = null;
    });

    try {
      final list = await _service.fetchInvoices(
        userId: _invoiceSelectedMemberOnly ? _selectedMemberId : null,
        status: _invoiceStatus,
        limit: 300,
      );

      if (!mounted) return;
      setState(() => _invoices = list);
    } catch (e) {
      if (!mounted) return;
      setState(() => _invoicesError = e.toString());
    } finally {
      if (mounted) setState(() => _invoicesLoading = false);
    }
  }

  Future<void> _loadWhatsAppCalls() async {
    if (_callsLoading) return;

    setState(() {
      _callsLoading = true;
      _callsError = null;
    });

    try {
      final rows = await _service.fetchWhatsAppCalls(
        adminStatus: _callsAdminStatus,
        callStatus: _callsEventStatus,
        direction: _callsDirection,
        query: _callsSearchCtrl.text.trim(),
        limit: 300,
      );

      if (!mounted) return;
      setState(() => _calls = rows);
    } catch (e) {
      if (!mounted) return;
      setState(() => _callsError = e.toString());
    } finally {
      if (mounted) setState(() => _callsLoading = false);
    }
  }

  Future<void> _setWhatsAppCallStatus(
    AdminWhatsAppCall call,
    String nextStatus,
  ) async {
    if (_updatingCallId != null) return;

    setState(() => _updatingCallId = call.id);
    try {
      final updated = await _service.setWhatsAppCallStatus(
        callId: call.id,
        adminStatus: nextStatus,
      );

      if (!mounted) return;
      setState(() {
        _calls = _calls
            .map((row) => row.id == updated.id ? updated : row)
            .toList();
      });
      _toast('Call status updated.');
    } catch (e) {
      _toast('Update failed: $e');
    } finally {
      if (mounted) setState(() => _updatingCallId = null);
    }
  }

  Future<void> _openExternal(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      _toast('Invalid URL.');
      return;
    }

    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) {
      _toast('Could not open URL.');
    }
  }

  String? _normalizeWhatsappDigits(String? raw) {
    final input = (raw ?? '').trim();
    if (input.isEmpty) return null;

    var digits = input.replaceAll(RegExp(r'\D+'), '');
    if (digits.isEmpty) return null;

    if (digits.startsWith('00') && digits.length > 2) {
      digits = digits.substring(2);
    }

    // Project default is South African numbering; convert local 0XXXXXXXXX.
    if (digits.startsWith('0') && digits.length == 10) {
      final countryCode = _whatsAppDefaultCountryCode.replaceAll(
        RegExp(r'\D+'),
        '',
      );
      if (countryCode.isNotEmpty) {
        digits = '$countryCode${digits.substring(1)}';
      }
    }

    if (digits.length < 8 || digits.length > 15) {
      return null;
    }

    return digits;
  }

  String _defaultSupportWhatsAppMessage({String? name}) {
    final displayName = (name ?? '').trim();
    if (displayName.isEmpty) {
      final msg = _whatsAppMessageDefault.trim();
      return msg.isEmpty ? 'Hello from Weather Hooligan support.' : msg;
    }

    final template = _whatsAppMessageTemplate.trim();
    if (template.isEmpty) {
      return 'Hello $displayName, this is Weather Hooligan support.';
    }

    return template.replaceAll('{name}', displayName);
  }

  Future<void> _sendMemberWhatsAppViaCloud(AdminUser user) async {
    final rawPhone = (user.whatsapp ?? '').trim();
    final waDigits = _normalizeWhatsappDigits(rawPhone);
    if (waDigits == null) {
      _toast('Invalid WhatsApp number.');
      return;
    }

    final displayName = '${user.name ?? ''} ${user.surname ?? ''}'.trim();
    final messageCtrl = TextEditingController(
      text: _defaultSupportWhatsAppMessage(name: displayName),
    );

    final sent = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        var sending = false;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Send WhatsApp via Cloud'),
              content: SizedBox(
                width: 540,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('To: ${user.username} (+$waDigits)'),
                    const SizedBox(height: 8),
                    const Text(
                      'This sends through the Weather Hooligan cloud webhook channel.',
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: messageCtrl,
                      enabled: !sending,
                      minLines: 4,
                      maxLines: 8,
                      maxLength: 4000,
                      decoration: const InputDecoration(
                        labelText: 'Message',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: sending
                      ? null
                      : () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton.icon(
                  onPressed: sending
                      ? null
                      : () async {
                          final navigator = Navigator.of(dialogContext);
                          final body = messageCtrl.text.trim();
                          if (body.isEmpty) {
                            _toast('Type a message first.');
                            return;
                          }

                          setDialogState(() => sending = true);
                          try {
                            await _service.sendWaMessage(
                              waUser: waDigits,
                              body: body,
                            );
                            if (!mounted) return;
                            navigator.pop(true);
                          } catch (e) {
                            if (!mounted) return;
                            _toast('Send failed: $e');
                            setDialogState(() => sending = false);
                          }
                        },
                  icon: sending
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send),
                  label: Text(sending ? 'Sending...' : 'Send'),
                ),
              ],
            );
          },
        );
      },
    );

    messageCtrl.dispose();

    if (sent == true) {
      _toast('WhatsApp sent via cloud webhook.');
      await _waInboxKey.currentState?.refreshAll();
    }
  }

  Future<bool> _tryLaunchUri(Uri uri, {required LaunchMode mode}) async {
    try {
      return await launchUrl(uri, mode: mode);
    } catch (_) {
      return false;
    }
  }

  Future<void> _openWhatsAppChat({
    required String rawPhone,
    String? name,
  }) async {
    final digits = _normalizeWhatsappDigits(rawPhone);
    if (digits == null) {
      _toast('Invalid WhatsApp number.');
      return;
    }

    final msg = _defaultSupportWhatsAppMessage(name: name);
    final encodedMsg = Uri.encodeQueryComponent(msg);

    final schemeBase = _whatsAppSchemeBase.trim().isEmpty
        ? 'whatsapp://send'
        : _whatsAppSchemeBase.trim();
    final webBase = _whatsAppWebBase.trim().isEmpty
        ? 'https://wa.me'
        : _whatsAppWebBase.trim().replaceAll(RegExp(r'/$'), '');

    final deepLink = Uri.parse('$schemeBase?phone=$digits&text=$encodedMsg');
    final webLink = Uri.parse('$webBase/$digits?text=$encodedMsg');

    bool opened;
    if (isAndroid) {
      opened = await _tryLaunchUri(
        deepLink,
        mode: LaunchMode.externalApplication,
      );
      if (!opened) {
        opened = await _tryLaunchUri(
          webLink,
          mode: LaunchMode.externalApplication,
        );
      }
    } else if (isWeb) {
      opened = await _tryLaunchUri(webLink, mode: LaunchMode.platformDefault);
    } else {
      opened = await _tryLaunchUri(
        webLink,
        mode: LaunchMode.externalApplication,
      );
      if (!opened) {
        opened = await _tryLaunchUri(webLink, mode: LaunchMode.platformDefault);
      }
    }

    if (!opened) {
      _toast('Could not open WhatsApp.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final loading = _membersLoading && _members.isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Members Admin'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _refreshCurrentTab,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Logout',
            onPressed: _logout,
            icon: const Icon(Icons.logout),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _tab,
            onDestinationSelected: (index) async {
              setState(() => _tab = index);

              if (index == 2 && _members.isEmpty) {
                await _loadMembers();
              }
              if (index == 3 &&
                  _appPortalAds.isEmpty &&
                  _largeAds.isEmpty &&
                  _smallAds.isEmpty) {
                await _loadAds();
              }
              if (index == 4 && _invites.isEmpty) {
                await _loadInvites();
              }
              if (index == 5 && _invoices.isEmpty) {
                await _loadInvoices();
              }
              if (index == 6) {
                await _loadStats();
              }
              if (index == 7) {
                await _waInboxKey.currentState?.refreshAll();
              }
              if (index == 8 && _calls.isEmpty) {
                await _loadWhatsAppCalls();
              }
            },
            labelType: NavigationRailLabelType.all,
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.people),
                label: Text('Members'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.build_circle_outlined),
                label: Text('Tools'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.notifications_active),
                label: Text('General FCM'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.campaign),
                label: Text('Ads'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.mail),
                label: Text('Emails'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.receipt_long),
                label: Text('Invoices'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.query_stats),
                label: Text('Stats'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.forum),
                label: Text('WA Inbox'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.call),
                label: Text('WA Calls'),
              ),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : _membersError != null && _members.isEmpty
                ? Center(child: Text('Error: $_membersError'))
                : _buildTabBody(),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBody() {
    switch (_tab) {
      case 0:
        return _membersTab();
      case 1:
        return _toolsTab();
      case 2:
        return _notificationsTab();
      case 3:
        return _adsTab();
      case 4:
        return _emailsTab();
      case 5:
        return _invoicesTab();
      case 6:
        return _statsTab();
      case 7:
        return _whatsAppInboxTab();
      case 8:
        return _whatsAppCallsTab();
      default:
        return _membersTab();
    }
  }

  Widget _membersTab() {
    final query = _memberSearchCtrl.text.trim().toLowerCase();
    final nameFilter = _memberNameCtrl.text.trim().toLowerCase();
    final accountFilter = _memberAccountCtrl.text.trim().toLowerCase();
    final emailFilter = _memberEmailCtrl.text.trim().toLowerCase();
    final dateFilter = _memberDateCtrl.text.trim().toLowerCase();

    final visible = _members.where((u) {
      final fullName = '${u.name ?? ''} ${u.surname ?? ''}'.trim();
      final accountType = (u.plan ?? '').trim().toLowerCase();
      final genericHay = [
        u.username,
        fullName,
        u.email,
        u.accountNumber ?? '',
        u.whatsapp ?? '',
        u.phone ?? '',
        accountType,
      ].join(' ').toLowerCase();

      if (query.isNotEmpty && !genericHay.contains(query)) return false;
      if (nameFilter.isNotEmpty &&
          !_containsText('${u.username} $fullName', nameFilter)) {
        return false;
      }
      if (accountFilter.isNotEmpty &&
          !_containsText(u.accountNumber, accountFilter)) {
        return false;
      }
      if (emailFilter.isNotEmpty && !_containsText(u.email, emailFilter)) {
        return false;
      }
      if (dateFilter.isNotEmpty && !_dateMatches(u.createdAt, dateFilter)) {
        return false;
      }
      if (_memberPlanFilter != 'all' && _memberPlanFilter == 'other') {
        if (['free', 'premium', 'trial'].contains(accountType)) {
          return false;
        }
      } else if (_memberPlanFilter != 'all' &&
          accountType != _memberPlanFilter.trim().toLowerCase()) {
        return false;
      }

      return true;
    }).toList();

    return Row(
      children: [
        SizedBox(
          width: 470,
          child: Card(
            margin: const EdgeInsets.all(12),
            child: Column(
              children: [
                ListTile(
                  title: const Text('Members'),
                  subtitle: Text(
                    '${visible.length} shown'
                    '${_members.length == visible.length ? '' : ' / ${_members.length} total'}',
                  ),
                  trailing: IconButton(
                    onPressed: _loadMembers,
                    icon: const Icon(Icons.refresh),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                  child: TextField(
                    controller: _memberSearchCtrl,
                    decoration: InputDecoration(
                      labelText: 'Search member',
                      border: const OutlineInputBorder(),
                      suffixIcon: query.isEmpty
                          ? const Icon(Icons.search)
                          : IconButton(
                              onPressed: () {
                                _memberSearchCtrl.clear();
                                setState(() {});
                              },
                              icon: const Icon(Icons.clear),
                            ),
                    ),
                    onSubmitted: (_) => _loadMembers(),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      SizedBox(
                        width: 210,
                        child: TextField(
                          controller: _memberNameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Name / Username',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      SizedBox(
                        width: 210,
                        child: TextField(
                          controller: _memberAccountCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Account Number',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      SizedBox(
                        width: 210,
                        child: TextField(
                          controller: _memberEmailCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Email Address',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      SizedBox(
                        width: 140,
                        child: TextField(
                          controller: _memberDateCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Date (YYYY-MM-DD)',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      SizedBox(
                        width: 130,
                        child: DropdownButtonFormField<String>(
                          initialValue: _memberPlanFilter,
                          decoration: const InputDecoration(
                            labelText: 'Account Type',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'all', child: Text('All')),
                            DropdownMenuItem(
                              value: 'free',
                              child: Text('Free'),
                            ),
                            DropdownMenuItem(
                              value: 'premium',
                              child: Text('Premium'),
                            ),
                            DropdownMenuItem(
                              value: 'trial',
                              child: Text('Trial'),
                            ),
                            DropdownMenuItem(
                              value: 'other',
                              child: Text('Other'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() => _memberPlanFilter = value);
                          },
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () {
                          _memberSearchCtrl.clear();
                          _memberNameCtrl.clear();
                          _memberAccountCtrl.clear();
                          _memberEmailCtrl.clear();
                          _memberDateCtrl.clear();
                          setState(() => _memberPlanFilter = 'all');
                        },
                        icon: const Icon(Icons.clear_all),
                        label: const Text('Clear Filters'),
                      ),
                    ],
                  ),
                ),
                if (supportsLocalDb)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white24),
                        color: Colors.black12,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Local Customer DB',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                              ),
                              TextButton(
                                onPressed: _localDbSyncing
                                    ? null
                                    : () => _syncMembersToLocalDb(_members),
                                child: const Text('Sync'),
                              ),
                              TextButton(
                                onPressed: _localDbSyncing
                                    ? null
                                    : _exportLocalDbJson,
                                child: const Text('Export JSON'),
                              ),
                            ],
                          ),
                          Text('Customers in local DB: $_localDbCount'),
                          Text('DB path: ${_localDbPath ?? 'Loading...'}'),
                          if (_localDbSyncing)
                            const Padding(
                              padding: EdgeInsets.only(top: 4),
                              child: LinearProgressIndicator(minHeight: 2),
                            ),
                          if ((_localDbError ?? '').trim().isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                'Error: $_localDbError',
                                style: const TextStyle(
                                  color: Colors.redAccent,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.builder(
                    itemCount: visible.length,
                    itemBuilder: (_, i) {
                      final user = visible[i];
                      final selected = user.id == _selectedMemberId;
                      return ListTile(
                        selected: selected,
                        title: Text(
                          '${user.name ?? ''} ${user.surname ?? ''}'
                                  .trim()
                                  .isEmpty
                              ? user.username
                              : '${user.name ?? ''} ${user.surname ?? ''}'
                                    .trim(),
                        ),
                        subtitle: Text(
                          (user.accountNumber ?? '').trim().isEmpty
                              ? user.email
                              : '${user.email}\n${user.accountNumber}',
                        ),
                        isThreeLine: true,
                        onTap: () => _selectMember(user),
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
            child: _memberDetail == null
                ? const Center(child: Text('Select a member to view details.'))
                : _memberDetailPanel(_memberDetail!),
          ),
        ),
      ],
    );
  }

  Widget _whatsAppInboxTab() {
    return WhatsAppMessagesPanel(key: _waInboxKey);
  }

  Widget _memberDetailPanel(AdminUser user) {
    final whatsappRaw = (user.whatsapp ?? '').trim();
    final canMessageOnWhatsApp = whatsappRaw.isNotEmpty;

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${user.name ?? ''} ${user.surname ?? ''}'.trim().isEmpty
                    ? user.username
                    : '${user.name ?? ''} ${user.surname ?? ''}'.trim(),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            Chip(
              label: Text(user.isBlocked ? 'BLOCKED' : 'ACTIVE'),
              avatar: Icon(
                user.isBlocked ? Icons.lock : Icons.check_circle,
                size: 18,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: [
            _info('Username', user.username),
            _info('Email', user.email),
            _info('Account', user.accountNumber ?? '—'),
            _info('Plan', user.plan ?? '—'),
            _info('Phone', user.phone ?? '—'),
            _info('WhatsApp', user.whatsapp ?? '—'),
            _info('Device Type', user.deviceType ?? 'Unknown'),
            _info('App Type Raw', user.appTypeRaw ?? '—'),
            _info('Created', _fmtDate(user.createdAt)),
          ],
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: canMessageOnWhatsApp
                ? () => _sendMemberWhatsAppViaCloud(user)
                : null,
            icon: const Icon(Icons.chat),
            label: const Text('Send WhatsApp (Cloud)'),
          ),
        ),
        const SizedBox(height: 14),
        const Divider(),
        Text('Licenses', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 6),
        if (user.licenses.isEmpty)
          const Text('No licenses found.')
        else
          ...user.licenses.map(
            (license) => ListTile(
              dense: true,
              leading: Icon(
                license.isLocked ? Icons.lock : Icons.vpn_key,
                color: license.isLocked ? Colors.redAccent : null,
              ),
              title: Text(license.licenseType),
              subtitle: Text(
                'status=${license.status} • paid=${license.isPaid ? 'yes' : 'no'} • hint=${license.licenseKeyHint ?? '—'}',
              ),
              trailing: Text(_fmtDate(license.lastUsedAt)),
            ),
          ),
        const SizedBox(height: 14),
        const Divider(),
        Text('Recent Payments', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 6),
        if (user.payments.isEmpty)
          const Text('No payments found.')
        else
          ...user.payments.map(
            (p) => ListTile(
              dense: true,
              leading: const Icon(Icons.receipt),
              title: Text(
                '${p.amount?.toStringAsFixed(2) ?? '0.00'} ${p.currency ?? 'ZAR'}',
              ),
              subtitle: Text(
                'Method: ${p.paymentMethod ?? p.providerKey ?? 'Unknown'} • Status: ${p.status ?? '—'}\n'
                'Ref: ${p.providerReference ?? p.reference ?? p.checkoutToken ?? '—'}'
                '${(p.billingCycle ?? '').trim().isEmpty ? '' : ' • Cycle: ${p.billingCycle}'}',
              ),
              isThreeLine: true,
              trailing: Text(_fmtDate(p.paymentDate ?? p.createdAt)),
            ),
          ),
      ],
    );
  }

  Widget _toolsTab() {
    final selectedUser = _findMemberById(_toolsUserId ?? _selectedMemberId);

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ListView(
            children: [
              Text('Tools', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              const Text(
                'Create users, set member passwords, and block/unblock members.',
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _toolsUserId ?? _selectedMemberId,
                      decoration: const InputDecoration(
                        labelText: 'Selected user',
                        border: OutlineInputBorder(),
                      ),
                      items: _members
                          .map(
                            (u) => DropdownMenuItem(
                              value: u.id,
                              child: Text('${u.username} • ${u.email}'),
                            ),
                          )
                          .toList(),
                      onChanged: _toolsAction == 'Create user'
                          ? null
                          : (value) {
                              setState(() => _toolsUserId = value);
                            },
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 220,
                    child: DropdownButtonFormField<String>(
                      initialValue: _toolsAction,
                      decoration: const InputDecoration(
                        labelText: 'Action',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'Create user',
                          child: Text('Create user'),
                        ),
                        DropdownMenuItem(
                          value: 'Set password',
                          child: Text('Set password'),
                        ),
                        DropdownMenuItem(
                          value: 'Toggle block',
                          child: Text('Toggle block'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() {
                          _toolsAction = value;
                          if (_toolsAction != 'Create user') {
                            _toolsUserId ??= _selectedMemberId;
                          }
                        });
                      },
                    ),
                  ),
                ],
              ),
              if (_toolsAction != 'Create user' && selectedUser == null)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Text('Select a user first.'),
                ),
              const SizedBox(height: 14),
              const Divider(),
              const SizedBox(height: 6),
              if (_toolsAction == 'Create user') ...[
                Text(
                  'Create User',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _toolsField(
                      _toolCreateUsernameCtrl,
                      'Username',
                      width: 260,
                    ),
                    _toolsField(_toolCreateEmailCtrl, 'Email', width: 320),
                    _toolsField(_toolCreateNameCtrl, 'Name', width: 220),
                    _toolsField(_toolCreateSurnameCtrl, 'Surname', width: 220),
                    _toolsField(_toolCreatePhoneCtrl, 'Phone', width: 220),
                    _toolsField(
                      _toolCreateWhatsAppCtrl,
                      'WhatsApp',
                      width: 220,
                    ),
                    _toolsField(_toolCreatePlanCtrl, 'Plan', width: 160),
                    _toolsField(
                      _toolCreatePasswordCtrl,
                      'Password',
                      width: 260,
                      obscure: true,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    SizedBox(
                      width: 220,
                      child: CheckboxListTile(
                        value: _toolCreateAndroid,
                        onChanged: (value) {
                          setState(() => _toolCreateAndroid = value == true);
                        },
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Allow Android'),
                      ),
                    ),
                    SizedBox(
                      width: 220,
                      child: CheckboxListTile(
                        value: _toolCreateWindows,
                        onChanged: (value) {
                          setState(() => _toolCreateWindows = value == true);
                        },
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Allow Windows'),
                      ),
                    ),
                    SizedBox(
                      width: 220,
                      child: CheckboxListTile(
                        value: _toolCreateWeb,
                        onChanged: (value) {
                          setState(() => _toolCreateWeb = value == true);
                        },
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Allow Web'),
                      ),
                    ),
                  ],
                ),
              ],
              if (_toolsAction == 'Set password') ...[
                Text(
                  selectedUser == null
                      ? 'Set Password'
                      : 'Set Password: ${selectedUser.username}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 10),
                const Text(
                  'This updates the member password and revokes existing sessions.',
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _toolsField(
                      _toolPasswordCtrl,
                      'New password',
                      width: 260,
                      obscure: true,
                    ),
                    _toolsField(
                      _toolPasswordConfirmCtrl,
                      'Confirm password',
                      width: 260,
                      obscure: true,
                    ),
                  ],
                ),
              ],
              if (_toolsAction == 'Toggle block') ...[
                Text(
                  selectedUser == null
                      ? 'Toggle Block'
                      : 'Toggle Block: ${selectedUser.username}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 10),
                Text(
                  selectedUser == null
                      ? 'Select a user first.'
                      : (selectedUser.isBlocked
                            ? 'User is currently BLOCKED. Running action will unblock.'
                            : 'User is currently ACTIVE. Running action will block.'),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Current sessions are revoked when block status changes.',
                ),
              ],
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _toolsBusy ? null : _runToolsAction,
                icon: _toolsBusy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.play_arrow),
                label: Text(_toolsBusy ? 'Working...' : 'Run Action'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _info(String key, String value) {
    return Container(
      constraints: const BoxConstraints(minWidth: 180),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white12),
      ),
      child: Text('$key: $value'),
    );
  }

  Widget _notificationsTab() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'General User Notification',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 6),
              const Text('Sends FCM to topic: wh_general'),
              const SizedBox(height: 12),
              TextField(
                controller: _pushMessageCtrl,
                minLines: 3,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Message',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _pushSending ? null : _sendGeneralPush,
                icon: _pushSending
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send),
                label: Text(_pushSending ? 'Sending...' : 'Send to wh_general'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _adsTab() {
    final adsQuery = _adsSearchCtrl.text.trim().toLowerCase();

    List<AdminAd> filterAds(List<AdminAd> rows) {
      if (adsQuery.isEmpty) return rows;
      return rows.where((ad) {
        final hay = [
          ad.title,
          ad.message ?? '',
          ad.linkUrl ?? '',
          ad.placement ?? '',
          _fmtDate(ad.createdAt),
        ].join(' ').toLowerCase();
        return hay.contains(adsQuery);
      }).toList();
    }

    final appPortalVisible = filterAds(_appPortalAds);
    final largeVisible = filterAds(_largeAds);
    final smallVisible = filterAds(_smallAds);

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
                ],
              ),
              if (!supportsAdsUpload) ...[
                const SizedBox(height: 8),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Upload is disabled on this platform.'),
                ),
              ],
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.black12),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ad controllers',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'App + Portal ads: full + thumb flow (legacy /api/ads).',
                    ),
                    Text(
                      'Large ads: main/login/about rotobox (independent from thumb/small images).',
                    ),
                    Text(
                      'Small ads: features/pricing/contact/signup/register rotobox.',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _adsSearchCtrl,
                decoration: InputDecoration(
                  labelText: 'Search ads (title/message/link/date)',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _adsSearchCtrl.text.trim().isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            _adsSearchCtrl.clear();
                            setState(() {});
                          },
                          icon: const Icon(Icons.clear),
                        ),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              const Divider(),
              Expanded(
                child: _adsLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _adsError != null
                    ? Center(child: Text('Error: $_adsError'))
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          final threeColumns = constraints.maxWidth >= 1550;
                          final twoColumns = constraints.maxWidth >= 1100;

                          final appPortalPanel = _adPlacementPanel(
                            title: 'App + Portal Ads',
                            subtitle:
                                'User app + portal.weather-hooligan.co.za',
                            ads: appPortalVisible,
                            onUpload: supportsAdsUpload && !_adsLoading
                                ? _openUploadAppPortalAdDialog
                                : null,
                            onDelete: _deleteAppPortalAd,
                            imageForTile: (ad) =>
                                (ad.thumbUrl ?? ad.imageUrl ?? '').trim(),
                          );

                          final largePanel = _adPlacementPanel(
                            title: 'Large Ads',
                            subtitle: 'Used on main/login/about',
                            ads: largeVisible,
                            onUpload: supportsAdsUpload && !_adsLoading
                                ? _openUploadLargeAdDialog
                                : null,
                            onDelete: _deleteLargeAd,
                            imageForTile: (ad) => (ad.imageUrl ?? '').trim(),
                          );

                          final smallPanel = _adPlacementPanel(
                            title: 'Small Ads',
                            subtitle:
                                'Used on features/pricing/contact/signup/register',
                            ads: smallVisible,
                            onUpload: supportsAdsUpload && !_adsLoading
                                ? _openUploadSmallAdDialog
                                : null,
                            onDelete: _deleteSmallAd,
                            imageForTile: (ad) =>
                                (ad.smallUrl ?? ad.imageUrl ?? '').trim(),
                          );

                          if (threeColumns) {
                            return Row(
                              children: [
                                Expanded(child: appPortalPanel),
                                const SizedBox(width: 12),
                                Expanded(child: largePanel),
                                const SizedBox(width: 12),
                                Expanded(child: smallPanel),
                              ],
                            );
                          }

                          if (twoColumns) {
                            return Column(
                              children: [
                                SizedBox(height: 340, child: appPortalPanel),
                                const SizedBox(height: 12),
                                Expanded(
                                  child: Row(
                                    children: [
                                      Expanded(child: largePanel),
                                      const SizedBox(width: 12),
                                      Expanded(child: smallPanel),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          }

                          return ListView(
                            children: [
                              SizedBox(height: 380, child: appPortalPanel),
                              const SizedBox(height: 12),
                              SizedBox(height: 380, child: largePanel),
                              const SizedBox(height: 12),
                              SizedBox(height: 380, child: smallPanel),
                            ],
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

  Widget _adPlacementPanel({
    required String title,
    required String subtitle,
    required List<AdminAd> ads,
    required VoidCallback? onUpload,
    required void Function(AdminAd ad) onDelete,
    required String Function(AdminAd ad) imageForTile,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: [
          ListTile(
            title: Text(title),
            subtitle: Text('$subtitle • ${ads.length} ad(s)'),
            trailing: FilledButton.icon(
              onPressed: onUpload,
              icon: const Icon(Icons.upload),
              label: const Text('Upload'),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ads.isEmpty
                ? const Center(child: Text('No ads in this section.'))
                : ListView.separated(
                    itemCount: ads.length,
                    separatorBuilder: (_, index) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final ad = ads[i];
                      final image = imageForTile(ad);
                      return ListTile(
                        leading: _thumb(image),
                        title: Text(ad.title),
                        subtitle: Text(
                          '${ad.active ? 'ACTIVE' : 'INACTIVE'} • ${_fmtDate(ad.createdAt)}',
                        ),
                        trailing: IconButton(
                          onPressed: _adsLoading ? null : () => onDelete(ad),
                          icon: const Icon(
                            Icons.delete,
                            color: Colors.redAccent,
                          ),
                        ),
                        onTap: image.isEmpty
                            ? null
                            : () => _openAdPreview(ad, image),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _statsTab() {
    final traffic = _trafficStats;
    final logs = _logSnapshot;
    final keyword = _statsSearchCtrl.text.trim().toLowerCase();
    final dateToken = _statsDateCtrl.text.trim().toLowerCase();

    final filteredLogLines = (logs?.lines ?? const <String>[]).where((line) {
      final value = line.toLowerCase();
      if (keyword.isNotEmpty && !value.contains(keyword)) {
        return false;
      }
      if (dateToken.isNotEmpty && !value.contains(dateToken)) {
        return false;
      }
      if (!_logMatchesLevel(value, _statsLevelFilter)) {
        return false;
      }
      return true;
    }).toList();

    final errorLines = filteredLogLines.where((line) {
      final value = line.toLowerCase();
      return value.contains('error') ||
          value.contains('exception') ||
          value.contains('fatal');
    }).toList();

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
                      'Traffic Stats + Laravel Logs',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  DropdownButton<int>(
                    value: _logLineLimit,
                    items: const [
                      DropdownMenuItem(value: 200, child: Text('200 lines')),
                      DropdownMenuItem(value: 400, child: Text('400 lines')),
                      DropdownMenuItem(value: 800, child: Text('800 lines')),
                      DropdownMenuItem(value: 1200, child: Text('1200 lines')),
                    ],
                    onChanged: (value) async {
                      if (value == null) return;
                      setState(() => _logLineLimit = value);
                      await _loadStats();
                    },
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: _statsLoading ? null : _loadStats,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _statsLoading ? null : _clearStatsLogs,
                    icon: const Icon(Icons.delete_sweep),
                    label: const Text('Clear Logs'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_statsError != null && !_statsLoading)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Last refresh error: $_statsError',
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 300,
                    child: TextField(
                      controller: _statsSearchCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Search logs (keyword)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  SizedBox(
                    width: 170,
                    child: TextField(
                      controller: _statsDateCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Date token',
                        hintText: '2026-02-23',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  SizedBox(
                    width: 160,
                    child: DropdownButtonFormField<String>(
                      initialValue: _statsLevelFilter,
                      decoration: const InputDecoration(
                        labelText: 'Log level',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('All')),
                        DropdownMenuItem(value: 'error', child: Text('Error')),
                        DropdownMenuItem(
                          value: 'warning',
                          child: Text('Warning'),
                        ),
                        DropdownMenuItem(value: 'info', child: Text('Info')),
                        DropdownMenuItem(value: 'debug', child: Text('Debug')),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _statsLevelFilter = value);
                      },
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {
                      _statsSearchCtrl.clear();
                      _statsDateCtrl.clear();
                      setState(() => _statsLevelFilter = 'all');
                    },
                    icon: const Icon(Icons.clear_all),
                    label: const Text('Clear'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: _statsLoading && traffic == null && logs == null
                    ? const Center(child: CircularProgressIndicator())
                    : ListView(
                        children: [
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              _statMetricCard(
                                title: 'Visitors / minute',
                                value: '${traffic?.visitorsPerMinute ?? 0}',
                              ),
                              _statMetricCard(
                                title: 'Visitors / hour',
                                value: '${traffic?.visitorsPerHour ?? 0}',
                              ),
                              _statMetricCard(
                                title: 'Visitors / 24h',
                                value: '${traffic?.visitorsPer24Hours ?? 0}',
                              ),
                              _statMetricCard(
                                title: 'Visitors / month',
                                value: '${traffic?.visitorsPerMonth ?? 0}',
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Traffic snapshot: ${_fmtDate(traffic?.generatedAt)}',
                          ),
                          const SizedBox(height: 14),
                          const Divider(),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Laravel Log Stream'),
                            subtitle: Text(
                              'Files: ${(logs?.sourceFiles ?? const []).join(', ')}',
                            ),
                            trailing: Text(
                              'Lines: ${filteredLogLines.length}'
                              '${logs == null ? '' : ' / ${logs.lineCount}'}',
                            ),
                          ),
                          Container(
                            constraints: const BoxConstraints(minHeight: 240),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.white12),
                              color: Colors.black26,
                            ),
                            child: filteredLogLines.isEmpty
                                ? const Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(12),
                                      child: Text(
                                        'No log lines match current filters.',
                                      ),
                                    ),
                                  )
                                : ListView.builder(
                                    shrinkWrap: true,
                                    itemCount: filteredLogLines.length,
                                    itemBuilder: (_, i) => Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      child: SelectableText(
                                        filteredLogLines[i],
                                        style: const TextStyle(fontSize: 12.5),
                                      ),
                                    ),
                                  ),
                          ),
                          const SizedBox(height: 14),
                          const Divider(),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Quick Error Watch'),
                            subtitle: Text(
                              '${errorLines.length} potential error line(s) detected.',
                            ),
                          ),
                          Container(
                            constraints: const BoxConstraints(minHeight: 120),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.redAccent),
                              color: Colors.black26,
                            ),
                            child: errorLines.isEmpty
                                ? const Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(12),
                                      child: Text(
                                        'No obvious error/exception lines in current snapshot.',
                                      ),
                                    ),
                                  )
                                : ListView.builder(
                                    shrinkWrap: true,
                                    itemCount: errorLines.length,
                                    itemBuilder: (_, i) => Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      child: SelectableText(
                                        errorLines[i],
                                        style: const TextStyle(
                                          fontSize: 12.5,
                                          color: Colors.redAccent,
                                        ),
                                      ),
                                    ),
                                  ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statMetricCard({required String title, required String value}) {
    return Container(
      width: 230,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white12),
        color: Colors.black12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _thumb(String imageUrl) {
    const width = 110.0;
    const height = 62.0;

    if (imageUrl.isEmpty) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white10),
          color: Colors.black26,
        ),
        child: const Icon(Icons.image_not_supported),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        imageUrl,
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (_, error, stackTrace) => Container(
          width: width,
          height: height,
          color: Colors.black26,
          child: const Icon(Icons.broken_image),
        ),
      ),
    );
  }

  Future<void> _openAdPreview(AdminAd ad, String imageUrl) async {
    await showDialog<void>(
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
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, error, stackTrace) =>
                      const Center(child: Icon(Icons.broken_image)),
                ),
              ),
              const SizedBox(height: 8),
              if ((ad.message ?? '').trim().isNotEmpty)
                Text(ad.message!.trim()),
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

  Widget _emailsTab() {
    final inviteSearch = _inviteSearchCtrl.text.trim().toLowerCase();
    final inviteDate = _inviteDateCtrl.text.trim().toLowerCase();

    final visibleInvites = _invites.where((invite) {
      final hay = [
        invite.name,
        invite.surname,
        invite.email,
        invite.whatsappPhone ?? '',
        invite.status,
      ].join(' ').toLowerCase();

      if (inviteSearch.isNotEmpty && !hay.contains(inviteSearch)) {
        return false;
      }
      if (inviteDate.isNotEmpty &&
          !_dateMatches(invite.createdAt ?? invite.expiresAt, inviteDate)) {
        return false;
      }
      return true;
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Send Invite Email',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      SizedBox(
                        width: 220,
                        child: TextField(
                          controller: _inviteNameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Name',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 220,
                        child: TextField(
                          controller: _inviteSurnameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Surname',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 320,
                        child: TextField(
                          controller: _inviteEmailCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 220,
                        child: TextField(
                          controller: _inviteWhatsappCtrl,
                          decoration: const InputDecoration(
                            labelText: 'WhatsApp (+27...)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      FilledButton.icon(
                        onPressed: _inviteSending ? null : _createInvite,
                        icon: _inviteSending
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.send),
                        label: Text(
                          _inviteSending ? 'Sending...' : 'Send Invite',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  SizedBox(
                    width: 320,
                    child: TextField(
                      controller: _inviteSearchCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Search invite (name/email/phone/status)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  SizedBox(
                    width: 180,
                    child: TextField(
                      controller: _inviteDateCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Date token',
                        hintText: '2026-02-23',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {
                      _inviteSearchCtrl.clear();
                      _inviteDateCtrl.clear();
                      setState(() {});
                    },
                    icon: const Icon(Icons.clear_all),
                    label: const Text('Clear'),
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
                    title: const Text('Invite Email History'),
                    subtitle: Text(
                      '${visibleInvites.length} invite(s)'
                      '${visibleInvites.length == _invites.length ? '' : ' / ${_invites.length} total'}',
                    ),
                    trailing: Wrap(
                      spacing: 8,
                      children: [
                        DropdownButton<String>(
                          value: _inviteStatus,
                          items: const [
                            DropdownMenuItem(value: 'all', child: Text('All')),
                            DropdownMenuItem(
                              value: 'active',
                              child: Text('Active'),
                            ),
                            DropdownMenuItem(
                              value: 'used',
                              child: Text('Used'),
                            ),
                            DropdownMenuItem(
                              value: 'expired',
                              child: Text('Expired'),
                            ),
                          ],
                          onChanged: (v) async {
                            if (v == null) return;
                            setState(() => _inviteStatus = v);
                            await _loadInvites();
                          },
                        ),
                        IconButton(
                          onPressed: _invitesLoading ? null : _loadInvites,
                          icon: const Icon(Icons.refresh),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: _invitesLoading
                        ? const Center(child: CircularProgressIndicator())
                        : _invitesError != null
                        ? Center(child: Text('Error: $_invitesError'))
                        : visibleInvites.isEmpty
                        ? const Center(child: Text('No invites found.'))
                        : ListView.builder(
                            itemCount: visibleInvites.length,
                            itemBuilder: (_, i) {
                              final invite = visibleInvites[i];
                              final inviteWhatsApp =
                                  (invite.whatsappPhone ?? '').trim();

                              return ListTile(
                                leading: Icon(
                                  invite.status == 'used'
                                      ? Icons.check_circle
                                      : invite.status == 'expired'
                                      ? Icons.timer_off
                                      : Icons.mark_email_read,
                                ),
                                title: Text('${invite.name} ${invite.surname}'),
                                subtitle: Text(
                                  '${invite.email}\nStatus: ${invite.status} • Expires: ${_fmtDate(invite.expiresAt)}',
                                ),
                                isThreeLine: true,
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (inviteWhatsApp.isNotEmpty)
                                      IconButton(
                                        tooltip: 'WhatsApp message',
                                        onPressed: () => _openWhatsAppChat(
                                          rawPhone: inviteWhatsApp,
                                          name:
                                              '${invite.name} ${invite.surname}',
                                        ),
                                        icon: const Icon(Icons.chat_outlined),
                                      ),
                                    if (invite.status != 'used')
                                      TextButton(
                                        onPressed: () => _resendInvite(invite),
                                        child: const Text('Resend'),
                                      ),
                                  ],
                                ),
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

  Color _adminCallStatusColor(String status) {
    switch (status.trim().toLowerCase()) {
      case 'resolved':
        return Colors.green;
      case 'in_progress':
        return Colors.orange;
      default:
        return Colors.blueGrey;
    }
  }

  String _callTitle(AdminWhatsAppCall call) {
    final name = (call.contactName ?? '').trim();
    if (name.isNotEmpty) return name;
    final userName = (call.username ?? '').trim();
    if (userName.isNotEmpty) return userName;
    final from = (call.fromNumber ?? '').trim();
    if (from.isNotEmpty) return from;
    return 'Unknown caller';
  }

  Widget _whatsAppCallsTab() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Card(
        child: Column(
          children: [
            ListTile(
              title: const Text('WhatsApp Calls'),
              subtitle: Text('${_calls.length} call event(s)'),
              trailing: Wrap(
                spacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  DropdownButton<String>(
                    value: _callsAdminStatus,
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('All Admin')),
                      DropdownMenuItem(value: 'open', child: Text('Open')),
                      DropdownMenuItem(
                        value: 'in_progress',
                        child: Text('In Progress'),
                      ),
                      DropdownMenuItem(
                        value: 'resolved',
                        child: Text('Resolved'),
                      ),
                    ],
                    onChanged: (value) async {
                      if (value == null) return;
                      setState(() => _callsAdminStatus = value);
                      await _loadWhatsAppCalls();
                    },
                  ),
                  DropdownButton<String>(
                    value: _callsDirection,
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('All Dir')),
                      DropdownMenuItem(
                        value: 'inbound',
                        child: Text('Inbound'),
                      ),
                      DropdownMenuItem(
                        value: 'outbound',
                        child: Text('Outbound'),
                      ),
                    ],
                    onChanged: (value) async {
                      if (value == null) return;
                      setState(() => _callsDirection = value);
                      await _loadWhatsAppCalls();
                    },
                  ),
                  DropdownButton<String>(
                    value: _callsEventStatus,
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('All Event')),
                      DropdownMenuItem(
                        value: 'ringing',
                        child: Text('Ringing'),
                      ),
                      DropdownMenuItem(
                        value: 'accepted',
                        child: Text('Accepted'),
                      ),
                      DropdownMenuItem(value: 'missed', child: Text('Missed')),
                      DropdownMenuItem(value: 'ended', child: Text('Ended')),
                      DropdownMenuItem(
                        value: 'rejected',
                        child: Text('Rejected'),
                      ),
                    ],
                    onChanged: (value) async {
                      if (value == null) return;
                      setState(() => _callsEventStatus = value);
                      await _loadWhatsAppCalls();
                    },
                  ),
                  IconButton(
                    tooltip: 'Refresh calls',
                    onPressed: _callsLoading ? null : _loadWhatsAppCalls,
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: TextField(
                controller: _callsSearchCtrl,
                decoration: InputDecoration(
                  labelText: 'Search call id / phone / note',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    onPressed: () async {
                      _callsSearchCtrl.clear();
                      await _loadWhatsAppCalls();
                    },
                    icon: const Icon(Icons.clear),
                  ),
                ),
                onSubmitted: (_) => _loadWhatsAppCalls(),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _callsLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _callsError != null
                  ? Center(child: Text('Error: $_callsError'))
                  : _calls.isEmpty
                  ? const Center(child: Text('No WhatsApp call events found.'))
                  : ListView.separated(
                      itemCount: _calls.length,
                      separatorBuilder: (_, index) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final call = _calls[i];
                        final fromNumber = (call.fromNumber ?? '').trim();
                        final toNumber = (call.toNumber ?? '').trim();
                        final forChat = fromNumber.isNotEmpty
                            ? fromNumber
                            : (call.userWhatsappPhone ?? '');
                        final isUpdating = _updatingCallId == call.id;

                        return ListTile(
                          leading: Icon(
                            (call.direction ?? '').toLowerCase() == 'outbound'
                                ? Icons.call_made
                                : Icons.call_received,
                          ),
                          title: Text(_callTitle(call)),
                          subtitle: Text(
                            'From: ${fromNumber.isEmpty ? '—' : fromNumber} • To: ${toNumber.isEmpty ? '—' : toNumber}\n'
                            'Event: ${(call.callStatus ?? call.eventType ?? 'unknown')} • When: ${_fmtDate(call.occurredAt ?? call.receivedAt)}',
                          ),
                          isThreeLine: true,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Chip(
                                label: Text(call.adminStatus),
                                backgroundColor: _adminCallStatusColor(
                                  call.adminStatus,
                                ).withValues(alpha: 0.18),
                              ),
                              IconButton(
                                tooltip: 'WhatsApp chat',
                                onPressed: forChat.trim().isEmpty
                                    ? null
                                    : () => _openWhatsAppChat(
                                        rawPhone: forChat,
                                        name: _callTitle(call),
                                      ),
                                icon: const Icon(Icons.chat_outlined),
                              ),
                              PopupMenuButton<String>(
                                enabled: !isUpdating,
                                onSelected: (next) =>
                                    _setWhatsAppCallStatus(call, next),
                                itemBuilder: (_) => const [
                                  PopupMenuItem(
                                    value: 'open',
                                    child: Text('Set Open'),
                                  ),
                                  PopupMenuItem(
                                    value: 'in_progress',
                                    child: Text('Set In Progress'),
                                  ),
                                  PopupMenuItem(
                                    value: 'resolved',
                                    child: Text('Set Resolved'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _invoicesTab() {
    final invoiceSearch = _invoiceSearchCtrl.text.trim().toLowerCase();
    final invoiceDate = _invoiceDateCtrl.text.trim().toLowerCase();

    final visibleInvoices = _invoices.where((invoice) {
      var method = (invoice.paymentMethod ?? invoice.providerKey ?? '')
          .trim()
          .toLowerCase();
      if (method.isEmpty) method = 'unknown';
      final hay = [
        invoice.invoiceNumber,
        invoice.username,
        invoice.email,
        invoice.accountNumber ?? '',
        invoice.providerReference ?? '',
        invoice.token,
        method,
        invoice.status,
      ].join(' ').toLowerCase();

      if (invoiceSearch.isNotEmpty && !hay.contains(invoiceSearch)) {
        return false;
      }
      if (invoiceDate.isNotEmpty &&
          !_dateMatches(
            invoice.paidAt ?? invoice.completedAt ?? invoice.createdAt,
            invoiceDate,
          )) {
        return false;
      }
      if (_invoiceMethodFilter != 'all' &&
          method != _invoiceMethodFilter.trim().toLowerCase()) {
        return false;
      }
      return true;
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Card(
        child: Column(
          children: [
            ListTile(
              title: const Text('Invoices / Payments'),
              subtitle: Text(
                '${visibleInvoices.length} row(s)'
                '${visibleInvoices.length == _invoices.length ? '' : ' / ${_invoices.length} total'}',
              ),
              trailing: Wrap(
                spacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  DropdownButton<String>(
                    value: _invoiceStatus,
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('All')),
                      DropdownMenuItem(value: 'paid', child: Text('Paid')),
                      DropdownMenuItem(
                        value: 'pending',
                        child: Text('Pending'),
                      ),
                      DropdownMenuItem(value: 'failed', child: Text('Failed')),
                      DropdownMenuItem(
                        value: 'completed',
                        child: Text('Completed'),
                      ),
                    ],
                    onChanged: (v) async {
                      if (v == null) return;
                      setState(() => _invoiceStatus = v);
                      await _loadInvoices();
                    },
                  ),
                  DropdownButton<String>(
                    value: _invoiceMethodFilter,
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('All Method')),
                      DropdownMenuItem(
                        value: 'payfast',
                        child: Text('PayFast'),
                      ),
                      DropdownMenuItem(value: 'ozow', child: Text('Ozow')),
                      DropdownMenuItem(value: 'eft', child: Text('EFT')),
                      DropdownMenuItem(
                        value: 'unknown',
                        child: Text('Unknown'),
                      ),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => _invoiceMethodFilter = v);
                    },
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Checkbox(
                        value: _invoiceSelectedMemberOnly,
                        onChanged: (v) async {
                          setState(
                            () => _invoiceSelectedMemberOnly = v == true,
                          );
                          await _loadInvoices();
                        },
                      ),
                      const Text('Selected member only'),
                    ],
                  ),
                  IconButton(
                    onPressed: _invoicesLoading ? null : _loadInvoices,
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  SizedBox(
                    width: 340,
                    child: TextField(
                      controller: _invoiceSearchCtrl,
                      decoration: const InputDecoration(
                        labelText:
                            'Search invoice/user/account/email/ref/method',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  SizedBox(
                    width: 180,
                    child: TextField(
                      controller: _invoiceDateCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Date token',
                        hintText: '2026-02-23',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {
                      _invoiceSearchCtrl.clear();
                      _invoiceDateCtrl.clear();
                      setState(() => _invoiceMethodFilter = 'all');
                    },
                    icon: const Icon(Icons.clear_all),
                    label: const Text('Clear'),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _invoicesLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _invoicesError != null
                  ? Center(child: Text('Error: $_invoicesError'))
                  : visibleInvoices.isEmpty
                  ? const Center(child: Text('No invoices found.'))
                  : ListView.separated(
                      itemCount: visibleInvoices.length,
                      separatorBuilder: (_, index) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final invoice = visibleInvoices[i];
                        return ListTile(
                          leading: const Icon(Icons.receipt_long),
                          title: Text(
                            '${invoice.invoiceNumber} • ${invoice.totalAmount.toStringAsFixed(2)} ${invoice.currency}',
                          ),
                          subtitle: Text(
                            '${invoice.username} (${invoice.accountNumber ?? 'no account'})\n'
                            'Status: ${invoice.status} • Method: ${invoice.paymentMethod ?? invoice.providerKey ?? 'Unknown'}\n'
                            'Ref: ${invoice.providerReference ?? invoice.token}'
                            '${(invoice.billingCycle ?? '').trim().isEmpty ? '' : ' • Cycle: ${invoice.billingCycle}'}',
                          ),
                          isThreeLine: true,
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _fmtDate(
                                  invoice.paidAt ??
                                      invoice.completedAt ??
                                      invoice.createdAt,
                                ),
                              ),
                              if ((invoice.checkoutUrl ?? '').trim().isNotEmpty)
                                TextButton(
                                  onPressed: () =>
                                      _openExternal(invoice.checkoutUrl!),
                                  child: const Text('Open'),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
