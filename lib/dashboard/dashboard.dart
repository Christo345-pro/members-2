import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../auth/login_screen.dart';
import '../models/admin_models.dart';
import '../platform/platform_features.dart';
import '../screens/whatsapp_messages_panel.dart';
import '../services/admin_service.dart';

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

  bool _pushSending = false;
  final _pushMessageCtrl = TextEditingController();

  bool _adsLoading = false;
  String? _adsError;
  List<AdminAd> _ads = [];

  bool _invitesLoading = false;
  bool _inviteSending = false;
  String? _invitesError;
  List<AdminInvite> _invites = [];
  String _inviteStatus = 'all';

  final _inviteNameCtrl = TextEditingController();
  final _inviteSurnameCtrl = TextEditingController();
  final _inviteEmailCtrl = TextEditingController();
  final _inviteWhatsappCtrl = TextEditingController();

  bool _invoicesLoading = false;
  String? _invoicesError;
  List<AdminInvoice> _invoices = [];
  String _invoiceStatus = 'all';
  bool _invoiceSelectedMemberOnly = false;

  bool _callsLoading = false;
  String? _callsError;
  List<AdminWhatsAppCall> _calls = [];
  String _callsAdminStatus = 'all';
  String _callsDirection = 'all';
  String _callsEventStatus = 'all';
  int? _updatingCallId;
  final _callsSearchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  @override
  void dispose() {
    _memberSearchCtrl.dispose();
    _pushMessageCtrl.dispose();

    _inviteNameCtrl.dispose();
    _inviteSurnameCtrl.dispose();
    _inviteEmailCtrl.dispose();
    _inviteWhatsappCtrl.dispose();
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
        break;
      case 2:
        await _loadAds();
        break;
      case 3:
        await _loadInvites();
        break;
      case 4:
        await _loadInvoices();
        break;
      case 5:
        await _waInboxKey.currentState?.refreshAll();
        break;
      case 6:
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

      if (_members.isEmpty) {
        if (!mounted) return;
        setState(() {
          _selectedMemberId = null;
          _memberDetail = null;
        });
        return;
      }

      _selectedMemberId ??= _members.first.id;
      if (!_members.any((u) => u.id == _selectedMemberId)) {
        _selectedMemberId = _members.first.id;
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

  Future<void> _selectMember(AdminUser user) async {
    if (_selectedMemberId == user.id && _memberDetail != null) return;

    setState(() {
      _selectedMemberId = user.id;
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

  Future<void> _loadAds() async {
    if (_adsLoading) return;

    setState(() {
      _adsLoading = true;
      _adsError = null;
    });

    try {
      final list = await _service.fetchAds();
      if (!mounted) return;
      setState(() => _ads = list);
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

  Future<void> _deleteAd(AdminAd ad) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete ad?'),
        content: Text('Delete "${ad.title}" permanently?'),
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
      await _service.deleteAd(ad.id);
      await _loadAds();
      _toast('Ad deleted.');
    } catch (e) {
      _toast('Delete failed: $e');
      if (mounted) setState(() => _adsLoading = false);
    }
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
          String fileName(PlatformFile? f) =>
              f == null ? '(not selected)' : f.name;

          return AlertDialog(
            title: const Text('Upload Advertisement'),
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
        thumbBytes: thumbImage!.bytes!,
        thumbName: thumbImage!.name,
      );
      await _loadAds();
      _toast('Ad uploaded.');
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

    final displayName = (name ?? '').trim();
    String msg;
    if (displayName.isEmpty) {
      msg = _whatsAppMessageDefault.trim();
      if (msg.isEmpty) {
        msg = 'Hello from Weather Hooligan support.';
      }
    } else {
      final template = _whatsAppMessageTemplate.trim();
      msg = template.isEmpty
          ? 'Hello $displayName, this is Weather Hooligan support.'
          : template.replaceAll('{name}', displayName);
    }
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

              if (index == 2 && _ads.isEmpty) {
                await _loadAds();
              }
              if (index == 3 && _invites.isEmpty) {
                await _loadInvites();
              }
              if (index == 4 && _invoices.isEmpty) {
                await _loadInvoices();
              }
              if (index == 5) {
                await _waInboxKey.currentState?.refreshAll();
              }
              if (index == 6 && _calls.isEmpty) {
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
        return _notificationsTab();
      case 2:
        return _adsTab();
      case 3:
        return _emailsTab();
      case 4:
        return _invoicesTab();
      case 5:
        return _whatsAppInboxTab();
      case 6:
        return _whatsAppCallsTab();
      default:
        return _membersTab();
    }
  }

  Widget _membersTab() {
    final query = _memberSearchCtrl.text.trim().toLowerCase();

    final visible = query.isEmpty
        ? _members
        : _members.where((u) {
            final hay = [
              u.username,
              u.name ?? '',
              u.surname ?? '',
              u.email,
              u.accountNumber ?? '',
              u.whatsapp ?? '',
              u.phone ?? '',
            ].join(' ').toLowerCase();
            return hay.contains(query);
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
                  title: const Text('Members'),
                  subtitle: Text('${visible.length} shown'),
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
            _info('Created', _fmtDate(user.createdAt)),
          ],
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: canMessageOnWhatsApp
                ? () => _openWhatsAppChat(
                    rawPhone: whatsappRaw,
                    name: '${user.name ?? ''} ${user.surname ?? ''}'.trim(),
                  )
                : null,
            icon: const Icon(Icons.chat),
            label: const Text('WhatsApp Message'),
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
              subtitle: Text('Ref: ${p.reference ?? '—'} • ${p.status ?? '—'}'),
              trailing: Text(_fmtDate(p.paymentDate ?? p.createdAt)),
            ),
          ),
      ],
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
                  child: Text('Upload is disabled on this platform.'),
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
                    ? const Center(child: Text('No ads available.'))
                    : ListView.separated(
                        itemCount: _ads.length,
                        separatorBuilder: (_, index) =>
                            const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final ad = _ads[i];
                          final image = (ad.thumbUrl ?? ad.imageUrl ?? '')
                              .trim();
                          return ListTile(
                            leading: _thumb(image),
                            title: Text(ad.title),
                            subtitle: Text(
                              '${ad.active ? 'ACTIVE' : 'INACTIVE'} • ${_fmtDate(ad.createdAt)}',
                            ),
                            trailing: IconButton(
                              onPressed: _adsLoading
                                  ? null
                                  : () => _deleteAd(ad),
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
        ),
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
          const SizedBox(height: 12),
          Expanded(
            child: Card(
              child: Column(
                children: [
                  ListTile(
                    title: const Text('Invite Email History'),
                    subtitle: Text('${_invites.length} invite(s)'),
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
                        : _invites.isEmpty
                        ? const Center(child: Text('No invites found.'))
                        : ListView.builder(
                            itemCount: _invites.length,
                            itemBuilder: (_, i) {
                              final invite = _invites[i];
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
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Card(
        child: Column(
          children: [
            ListTile(
              title: const Text('Invoices / Payments'),
              subtitle: Text('${_invoices.length} row(s)'),
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
            const Divider(height: 1),
            Expanded(
              child: _invoicesLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _invoicesError != null
                  ? Center(child: Text('Error: $_invoicesError'))
                  : _invoices.isEmpty
                  ? const Center(child: Text('No invoices found.'))
                  : ListView.separated(
                      itemCount: _invoices.length,
                      separatorBuilder: (_, index) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final invoice = _invoices[i];
                        return ListTile(
                          leading: const Icon(Icons.receipt_long),
                          title: Text(
                            '${invoice.invoiceNumber} • ${invoice.totalAmount.toStringAsFixed(2)} ${invoice.currency}',
                          ),
                          subtitle: Text(
                            '${invoice.username} (${invoice.accountNumber ?? 'no account'})\nStatus: ${invoice.status} • Ref: ${invoice.providerReference ?? invoice.token}',
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
