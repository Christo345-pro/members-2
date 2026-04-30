import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../auth/login_screen.dart';
import '../models/admin_models.dart';
import '../platform/platform_features.dart';
import '../screens/whatsapp_messages_panel.dart';
import '../services/admin_service.dart';
import '../services/report_file_exporter_stub.dart'
    if (dart.library.html) '../services/report_file_exporter_web.dart'
    if (dart.library.io) '../services/report_file_exporter_io.dart'
    as report_file_exporter;
import '../services/local_member_db_stub.dart'
    if (dart.library.io) '../services/local_member_db.dart';

class _MemberStatusChipConfig {
  final String label;
  final IconData icon;

  const _MemberStatusChipConfig({required this.label, required this.icon});
}

class _PaymentGapReportRow {
  final String groupLabel;
  final AdminUser user;
  final AdminInvoice? lastSuccessfulInvoice;
  final DateTime? lastPaymentAt;
  final int? daysSincePayment;

  const _PaymentGapReportRow({
    required this.groupLabel,
    required this.user,
    this.lastSuccessfulInvoice,
    this.lastPaymentAt,
    this.daysSincePayment,
  });
}

const List<String> _paymentSummaryGroupOrder = [
  'No successful payment',
  'Payments in the past month',
  'Payments older than a month',
];

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final _service = AdminService();
  final _waInboxKey = GlobalKey<WhatsAppMessagesPanelState>();
  final _invoiceHorizontalScrollCtrl = ScrollController();
  final _invoiceVerticalScrollCtrl = ScrollController();
  Timer? _waIncomingPollTimer;
  bool _waIncomingPolling = false;
  bool _waIncomingInitialized = false;
  bool _waIncomingDialogOpen = false;
  final Map<int, DateTime> _waLatestInboundAtByConversation = {};
  final List<AdminWaConversation> _waPendingIncomingPopups = [];

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
  static const Map<String, String> _checkoutAddonLabels = {
    'daily_temperature_forecast': 'Daily Temperature Forecast',
    'daily_rain_forecast': 'Daily Rain Forecast',
    'ten_day_forecast': '10 Day Forecast',
    'swell_forecast': 'Swell Forecast',
    'live_weather_alerts': 'Live Weather Alerts',
    'compass': 'Compass',
    'radar': 'Radar',
    'stormpath_whatsapp_notifications': 'Stormpath WhatsApp Notifications',
    'general_weather_whatsapp_notifications':
        'General Weather WhatsApp Notifications',
    'daily_location_whatsapp_weather':
        'Daily Weather For Your Location (WhatsApp)',
  };
  static const Set<String> _platformSelectableAddons = {
    'daily_temperature_forecast',
    'daily_rain_forecast',
    'ten_day_forecast',
    'swell_forecast',
    'radar',
  };

  int _tab = 0;

  bool _membersLoading = false;
  String? _membersError;
  List<AdminUser> _members = [];
  int? _selectedMemberId;
  AdminUser? _memberDetail;
  bool _reportLoading = false;
  String? _reportError;
  List<_PaymentGapReportRow> _paymentGapReportRows = [];
  DateTime? _paymentGapReportCutoff;
  DateTime? _paymentGapReportGeneratedAt;
  final Set<int> _selectedPaymentReportUserIds = <int>{};
  String _paymentSummarySortBy = 'client_code';

  final _memberSearchCtrl = TextEditingController();

  bool _toolsBusy = false;
  int? _toolsUserId;
  String? _toolsAction;
  final _toolCreateUsernameCtrl = TextEditingController();
  final _toolCreateEmailCtrl = TextEditingController();
  final _toolCreateNameCtrl = TextEditingController();
  final _toolCreateSurnameCtrl = TextEditingController();
  final _toolCreatePhoneCtrl = TextEditingController();
  final _toolCreateWhatsAppCtrl = TextEditingController();
  final _toolCreatePlanCtrl = TextEditingController(text: 'free');
  bool _toolCreateAndroid = false;
  bool _toolCreateWindows = false;
  bool _toolCreateWeb = false;
  bool _toolCreateBlocked = false;
  bool _toolCreateSendPaymentLink = true;
  bool _toolCreateCheckoutAndroid = true;
  bool _toolCreateCheckoutWeb = false;
  final Set<String> _toolCreateCheckoutAddons = <String>{};
  final Map<String, String> _toolCreateCheckoutAddonPlatforms =
      <String, String>{};
  String _toolCreateBillingPreference = 'subscription';
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
  bool _invoiceSelectedMemberOnly = false;
  final _invoiceSearchCtrl = TextEditingController();
  String _invoiceSortBy = 'date';
  String _invoiceSortDirection = 'descending';
  int? _sendingMemberPaymentLinkUserId;
  int? _updatingMemberLicensesUserId;

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
    _startWhatsAppIncomingPolling();
    if (supportsLocalDb) {
      _refreshLocalDbSummary();
    }
  }

  @override
  void dispose() {
    _stopWhatsAppIncomingPolling();
    _memberSearchCtrl.dispose();
    _toolCreateUsernameCtrl.dispose();
    _toolCreateEmailCtrl.dispose();
    _toolCreateNameCtrl.dispose();
    _toolCreateSurnameCtrl.dispose();
    _toolCreatePhoneCtrl.dispose();
    _toolCreateWhatsAppCtrl.dispose();
    _toolCreatePlanCtrl.dispose();
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
    _invoiceHorizontalScrollCtrl.dispose();
    _invoiceVerticalScrollCtrl.dispose();
    _statsSearchCtrl.dispose();
    _statsDateCtrl.dispose();
    _callsSearchCtrl.dispose();

    super.dispose();
  }

  void _startWhatsAppIncomingPolling() {
    _waIncomingPollTimer?.cancel();
    _pollWhatsAppIncoming(showPopups: false);
    _waIncomingPollTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      _pollWhatsAppIncoming();
    });
  }

  void _stopWhatsAppIncomingPolling() {
    _waIncomingPollTimer?.cancel();
    _waIncomingPollTimer = null;
  }

  Future<void> _pollWhatsAppIncoming({bool showPopups = true}) async {
    if (_waIncomingPolling) return;
    _waIncomingPolling = true;

    try {
      final rows = await _service.fetchWaConversations(limit: 300);
      final incoming = <AdminWaConversation>[];

      for (final row in rows) {
        final lastInbound = row.lastInboundAt;
        if (lastInbound == null) continue;

        final previous = _waLatestInboundAtByConversation[row.id];
        _waLatestInboundAtByConversation[row.id] = lastInbound;

        if (!showPopups || !_waIncomingInitialized) continue;

        final isNewInbound = previous == null || lastInbound.isAfter(previous);
        if (isNewInbound) {
          incoming.add(row);
        }
      }

      if (!_waIncomingInitialized) {
        _waIncomingInitialized = true;
        return;
      }

      if (incoming.isNotEmpty && mounted) {
        _queueWhatsAppIncomingPopups(incoming);
      }
    } catch (_) {
      // Keep this silent: inbox polling should not interrupt admin workflows.
    } finally {
      _waIncomingPolling = false;
    }
  }

  void _queueWhatsAppIncomingPopups(List<AdminWaConversation> incoming) {
    _waPendingIncomingPopups.addAll(incoming);
    _showNextWhatsAppIncomingPopupIfNeeded();
  }

  Future<void> _showNextWhatsAppIncomingPopupIfNeeded() async {
    if (!mounted || _waIncomingDialogOpen || _waPendingIncomingPopups.isEmpty) {
      return;
    }

    _waIncomingDialogOpen = true;

    final mergedByConversation = <int, AdminWaConversation>{};
    for (final row in _waPendingIncomingPopups) {
      final existing = mergedByConversation[row.id];
      if (existing == null) {
        mergedByConversation[row.id] = row;
        continue;
      }

      final existingInbound = existing.lastInboundAt;
      final currentInbound = row.lastInboundAt;
      if (existingInbound == null) {
        mergedByConversation[row.id] = row;
      } else if (currentInbound != null &&
          currentInbound.isAfter(existingInbound)) {
        mergedByConversation[row.id] = row;
      }
    }
    _waPendingIncomingPopups.clear();

    final items = mergedByConversation.values.toList()
      ..sort((a, b) {
        final aTs = a.lastInboundAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTs = b.lastInboundAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bTs.compareTo(aTs);
      });

    final topItems = items.take(4).toList();
    final remaining = items.length - topItems.length;

    final openInbox = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          items.length == 1
              ? 'Incoming WhatsApp Message'
              : 'Incoming WhatsApp Messages',
        ),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final row in topItems)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${row.title} (${row.waUser})',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        (row.lastMessagePreview ?? 'New message').trim(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Received: ${_fmtDate(row.lastInboundAt)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              if (remaining > 0)
                Text(
                  '+$remaining more message(s)',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Dismiss'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            icon: const Icon(Icons.forum),
            label: const Text('Open Inbox'),
          ),
        ],
      ),
    );

    _waIncomingDialogOpen = false;

    if (openInbox == true && mounted) {
      setState(() => _tab = 6);
      await _waInboxKey.currentState?.refreshAll();
    }

    if (mounted && _waPendingIncomingPopups.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showNextWhatsAppIncomingPopupIfNeeded();
      });
    }
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

  String _memberSortKey(AdminUser user) {
    final accountNumber = (user.accountNumber ?? '').trim().toUpperCase();
    if (accountNumber.isNotEmpty) return accountNumber;
    return user.username.trim().toUpperCase();
  }

  String _memberSearchHaystack(AdminUser user) {
    final fullName = '${user.name ?? ''} ${user.surname ?? ''}'.trim();
    final createdAt = user.createdAt == null ? '' : _fmtDate(user.createdAt);

    return [
      user.username,
      fullName,
      user.email,
      user.accountNumber ?? '',
      user.whatsapp ?? '',
      user.phone ?? '',
      user.cellphone ?? '',
      user.plan ?? '',
      user.deviceType ?? '',
      user.appTypeRaw ?? '',
      user.city ?? '',
      user.province ?? '',
      user.postalCode ?? '',
      createdAt,
    ].join(' ').toLowerCase();
  }

  String _memberDisplayName(AdminUser user) {
    final fullName = '${user.name ?? ''} ${user.surname ?? ''}'.trim();
    return fullName.isEmpty ? user.username : fullName;
  }

  DateTime _paymentGapCutoffDate(DateTime reference) {
    final year = reference.month == 1 ? reference.year - 1 : reference.year;
    final month = reference.month == 1 ? 12 : reference.month - 1;
    final lastDayOfTargetMonth = DateTime(year, month + 1, 0).day;
    final day = reference.day > lastDayOfTargetMonth
        ? lastDayOfTargetMonth
        : reference.day;
    return DateTime(
      year,
      month,
      day,
      reference.hour,
      reference.minute,
      reference.second,
      reference.millisecond,
      reference.microsecond,
    );
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
        await _loadStats();
        break;
      case 6:
        await _waInboxKey.currentState?.refreshAll();
        break;
      case 7:
        await _loadWhatsAppCalls();
        break;
    }
  }

  Future<void> _openWhatsAppInboxTab() async {
    if (!mounted) return;
    setState(() => _tab = 6);
    await _waInboxKey.currentState?.refreshAll();
  }

  Future<void> _loadMembers() async {
    if (_membersLoading) return;

    setState(() {
      _membersLoading = true;
      _membersError = null;
    });

    try {
      final list = await _service.fetchMembers(limit: 300);

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

      if (_selectedMemberId != null &&
          !_members.any((u) => u.id == _selectedMemberId)) {
        _selectedMemberId = null;
      }
      if (_toolsUserId != null && !_members.any((u) => u.id == _toolsUserId)) {
        _toolsUserId = null;
      }

      if (_selectedMemberId == null) {
        if (!mounted) return;
        setState(() => _memberDetail = null);
      } else {
        final detail = await _service.fetchMemberDetail(_selectedMemberId!);
        if (!mounted) return;
        setState(() {
          _memberDetail = detail;
        });
      }
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
      setState(() {
        _memberDetail = detail;
        if (_toolsAction == 'Edit user' && _toolsUserId == detail.id) {
          _populateToolsFormFromUser(detail);
        }
      });
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

  _MemberStatusChipConfig _memberAccountChip(AdminUser user) {
    if (user.isBlocked) {
      return const _MemberStatusChipConfig(label: 'INACTIVE', icon: Icons.lock);
    }

    return const _MemberStatusChipConfig(
      label: 'ACTIVE',
      icon: Icons.check_circle,
    );
  }

  void _resetCreateUserToolForm() {
    _toolCreateUsernameCtrl.clear();
    _toolCreateEmailCtrl.clear();
    _toolCreateNameCtrl.clear();
    _toolCreateSurnameCtrl.clear();
    _toolCreatePhoneCtrl.clear();
    _toolCreateWhatsAppCtrl.clear();
    _toolCreatePlanCtrl.text = 'free';
    _toolCreateAndroid = false;
    _toolCreateWindows = false;
    _toolCreateWeb = false;
    _toolCreateBlocked = false;
    _toolCreateSendPaymentLink = true;
    _toolCreateCheckoutAndroid = true;
    _toolCreateCheckoutWeb = false;
    _toolCreateCheckoutAddons.clear();
    _toolCreateCheckoutAddonPlatforms.clear();
    _toolCreateBillingPreference = 'subscription';
  }

  void _populateToolsFormFromUser(AdminUser user) {
    _toolCreateUsernameCtrl.text = user.username;
    _toolCreateEmailCtrl.text = user.email;
    _toolCreateNameCtrl.text = (user.name ?? '').trim();
    _toolCreateSurnameCtrl.text = (user.surname ?? '').trim();
    _toolCreatePhoneCtrl.text = (user.phone ?? '').trim();
    _toolCreateWhatsAppCtrl.text = (user.whatsapp ?? '').trim();
    _toolCreatePlanCtrl.text = (user.plan ?? 'free').trim().isEmpty
        ? 'free'
        : (user.plan ?? 'free').trim();
    _toolCreateAndroid = user.appAndroid == true;
    _toolCreateWindows = user.appWindows == true;
    _toolCreateWeb = user.appWeb == true;
    _toolCreateBlocked = user.isBlocked;
    _toolCreateBillingPreference =
        (user.billingPreference ?? '').trim() == 'invoice_monthly'
        ? 'invoice_monthly'
        : 'subscription';
    _toolCreateSendPaymentLink = false;
    _toolCreateCheckoutAndroid = false;
    _toolCreateCheckoutWeb = false;
    _toolCreateCheckoutAddons.clear();
    _toolCreateCheckoutAddonPlatforms.clear();
  }

  Future<void> _loadToolsEditUser(int userId) async {
    try {
      final detail = await _service.fetchMemberDetail(userId);
      if (!mounted) return;
      if (_toolsAction != 'Edit user' || _toolsUserId != userId) return;
      setState(() {
        _populateToolsFormFromUser(detail);
        _members = _members
            .map((member) => member.id == detail.id ? detail : member)
            .toList();
        if (_memberDetail?.id == detail.id) {
          _memberDetail = detail;
        }
      });
    } catch (e) {
      if (!mounted) return;
      _toast('Load member details failed: $e');
    }
  }

  Future<void> _onToolsActionChanged(String? value) async {
    if (value == null) return;

    final selectedMemberId = _selectedMemberId;
    setState(() {
      _toolsAction = value;
      _toolPasswordCtrl.clear();
      _toolPasswordConfirmCtrl.clear();
      if (value == 'Create user') {
        _toolsUserId = null;
        _resetCreateUserToolForm();
      } else if (selectedMemberId != null) {
        _toolsUserId = selectedMemberId;
      } else {
        _toolsUserId = null;
      }
    });

    if (value == 'Edit user' && _toolsUserId != null) {
      final currentDetail = _memberDetail;
      if (currentDetail != null && currentDetail.id == _toolsUserId) {
        setState(() => _populateToolsFormFromUser(currentDetail));
      } else {
        await _loadToolsEditUser(_toolsUserId!);
      }
    }
  }

  bool _isPlatformSelectableAddon(String addonType) {
    return _platformSelectableAddons.contains(addonType.trim().toLowerCase());
  }

  List<String> _composePaymentLinkLicenseTypes({
    required bool includeAndroid,
    required bool includeWeb,
    required Iterable<String> selectedAddons,
  }) {
    final types = <String>[];

    if (includeAndroid) {
      types.add('home_hooligan_android');
    }
    if (includeWeb) {
      types.add('home_hooligan_web');
    }
    for (final addon in selectedAddons) {
      final key = addon.trim().toLowerCase();
      if (_checkoutAddonLabels.containsKey(key)) {
        types.add(key);
      }
    }

    return types;
  }

  List<String> _paymentLinkLicenseTypesForCreateUser() {
    return _composePaymentLinkLicenseTypes(
      includeAndroid: _toolCreateCheckoutAndroid,
      includeWeb: _toolCreateCheckoutWeb,
      selectedAddons: _toolCreateCheckoutAddons,
    );
  }

  Map<String, String> _selectedAddonPlatforms({
    required bool includeAndroid,
    required bool includeWeb,
    required Iterable<String> selectedAddons,
    required Map<String, String> rawChoices,
  }) {
    final hasBothBase = includeAndroid && includeWeb;
    if (!hasBothBase) {
      return <String, String>{};
    }

    final out = <String, String>{};
    for (final addon in selectedAddons) {
      final key = addon.trim().toLowerCase();
      if (!_isPlatformSelectableAddon(key)) {
        continue;
      }
      final choice = (rawChoices[key] ?? 'both').trim().toLowerCase();
      if (choice == 'android' || choice == 'web' || choice == 'both') {
        out[key] = choice;
      } else {
        out[key] = 'both';
      }
    }
    return out;
  }

  Set<String> _defaultCheckoutAddonsForUser(AdminUser user) {
    final out = <String>{};
    for (final license in user.licenses) {
      final key = license.licenseType.trim().toLowerCase();
      if (_checkoutAddonLabels.containsKey(key)) {
        out.add(key);
      }
    }

    if (out.isEmpty && (user.plan ?? '').trim().toLowerCase() == 'travel') {
      out.add('ten_day_forecast');
      out.add('swell_forecast');
    }

    return out;
  }

  List<String> _memberBaseTypes(AdminUser user) {
    final out = <String>{};

    for (final license in user.licenses) {
      final key = license.licenseType.trim().toLowerCase();
      if (key == 'home_hooligan_android' || key == 'home_hooligan_web') {
        out.add(key);
      }
    }

    if (out.isEmpty) {
      if (user.appAndroid == true) out.add('home_hooligan_android');
      if (user.appWeb == true) out.add('home_hooligan_web');
    }

    if (out.isEmpty) {
      final raw = (user.appTypeRaw ?? '').trim().toLowerCase();
      if (raw.contains('home_hooligan_web') || raw.contains('member_web')) {
        out.add('home_hooligan_web');
      }
      if (raw.contains('home_hooligan_android') ||
          raw.contains('member_android')) {
        out.add('home_hooligan_android');
      }
    }

    if (out.isEmpty) {
      out.add('home_hooligan_android');
    }

    return out.toList();
  }

  Future<void> _manageMemberAddons(AdminUser user) async {
    if (_updatingMemberLicensesUserId != null) return;

    final baseTypes = _memberBaseTypes(user);
    final selected = <String>{..._defaultCheckoutAddonsForUser(user)};

    final result = await showDialog<List<String>>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Manage Add-ons'),
              content: SizedBox(
                width: 560,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Member: ${user.username}'),
                      const SizedBox(height: 6),
                      Text(
                        'Base preserved: ${baseTypes.join(' + ')}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 12),
                      for (final entry in _checkoutAddonLabels.entries)
                        CheckboxListTile(
                          value: selected.contains(entry.key),
                          onChanged: (value) {
                            setDialogState(() {
                              if (value == true) {
                                selected.add(entry.key);
                              } else {
                                selected.remove(entry.key);
                              }
                            });
                          },
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          title: Text(entry.value),
                        ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.pop(dialogContext, selected.toList());
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == null) return;

    setState(() => _updatingMemberLicensesUserId = user.id);
    try {
      final detail = await _service.updateMemberLicenses(
        userId: user.id,
        baseTypes: baseTypes,
        addons: result,
      );
      if (!mounted) return;
      setState(() {
        _members = _members
            .map((member) => member.id == detail.id ? detail : member)
            .toList();
        if (_memberDetail?.id == detail.id) {
          _memberDetail = detail;
        }
      });
      _toast('Member add-ons updated.');
    } catch (e) {
      _toast('Failed to update add-ons: $e');
    } finally {
      if (mounted) {
        setState(() => _updatingMemberLicensesUserId = null);
      }
    }
  }

  Future<void> _sendMemberPaymentLink(AdminUser user) async {
    if (_sendingMemberPaymentLinkUserId != null) return;

    final waDigits = _normalizeWhatsappDigits((user.whatsapp ?? '').trim());
    if (waDigits == null) {
      _toast('Invalid WhatsApp number on this member profile.');
      return;
    }

    final defaultWeb = user.appWeb == true;
    final defaultAndroid = user.appAndroid == true || !defaultWeb;
    final defaultAddons = _defaultCheckoutAddonsForUser(user);

    final options = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) {
        var includeAndroid = defaultAndroid;
        var includeWeb = defaultWeb;
        var billingPreference = 'subscription';
        final selectedAddons = <String>{...defaultAddons};
        final addonPlatforms = <String, String>{};
        for (final addon in selectedAddons) {
          if (_isPlatformSelectableAddon(addon)) {
            addonPlatforms[addon] = 'both';
          }
        }

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Send Payment Link'),
              content: SizedBox(
                width: 560,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Member: ${user.username}'),
                      const SizedBox(height: 10),
                      CheckboxListTile(
                        value: includeAndroid,
                        onChanged: (value) {
                          setDialogState(() => includeAndroid = value == true);
                        },
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        title: const Text('Android base'),
                      ),
                      CheckboxListTile(
                        value: includeWeb,
                        onChanged: (value) {
                          setDialogState(() => includeWeb = value == true);
                        },
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        title: const Text('Web base'),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: billingPreference,
                        decoration: const InputDecoration(
                          labelText: 'Billing preference',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'subscription',
                            child: Text('Subscription'),
                          ),
                          DropdownMenuItem(
                            value: 'invoice_monthly',
                            child: Text('Invoice Monthly'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          setDialogState(() => billingPreference = value);
                        },
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Add-on options',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      for (final entry in _checkoutAddonLabels.entries) ...[
                        CheckboxListTile(
                          value: selectedAddons.contains(entry.key),
                          onChanged: (value) {
                            setDialogState(() {
                              if (value == true) {
                                selectedAddons.add(entry.key);
                                if (_isPlatformSelectableAddon(entry.key)) {
                                  addonPlatforms[entry.key] =
                                      addonPlatforms[entry.key] ?? 'both';
                                }
                              } else {
                                selectedAddons.remove(entry.key);
                                addonPlatforms.remove(entry.key);
                              }
                            });
                          },
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          title: Text(entry.value),
                        ),
                        if (selectedAddons.contains(entry.key) &&
                            includeAndroid &&
                            includeWeb &&
                            _isPlatformSelectableAddon(entry.key))
                          Padding(
                            padding: const EdgeInsets.only(
                              left: 14,
                              right: 10,
                              bottom: 8,
                            ),
                            child: SizedBox(
                              width: 260,
                              child: DropdownButtonFormField<String>(
                                initialValue:
                                    addonPlatforms[entry.key] ?? 'both',
                                decoration: const InputDecoration(
                                  labelText: 'Addon platform',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'android',
                                    child: Text('Android'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'web',
                                    child: Text('Web'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'both',
                                    child: Text('Both'),
                                  ),
                                ],
                                onChanged: (value) {
                                  if (value == null) return;
                                  setDialogState(
                                    () => addonPlatforms[entry.key] = value,
                                  );
                                },
                              ),
                            ),
                          ),
                      ],
                      const SizedBox(height: 4),
                      const Text(
                        'Creates checkout + sends via WhatsApp webhook template (whatsapp_general).',
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    if (!includeAndroid && !includeWeb) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Select at least one base option: Android or Web.',
                          ),
                        ),
                      );
                      return;
                    }
                    Navigator.pop(dialogContext, {
                      'include_android': includeAndroid,
                      'include_web': includeWeb,
                      'billing_preference': billingPreference,
                      'addons': selectedAddons.toList(),
                      'addon_platforms': addonPlatforms,
                    });
                  },
                  child: const Text('Send Link'),
                ),
              ],
            );
          },
        );
      },
    );

    if (options == null) return;

    final includeAndroid = options['include_android'] == true;
    final includeWeb = options['include_web'] == true;
    final billingPreference = (options['billing_preference'] ?? 'subscription')
        .toString()
        .trim()
        .toLowerCase();
    final selectedAddons = ((options['addons'] as List?) ?? const [])
        .map((value) => value.toString().trim().toLowerCase())
        .where((value) => _checkoutAddonLabels.containsKey(value))
        .toSet();
    final rawAddonPlatforms = <String, String>{};
    final addonPlatformsRaw = options['addon_platforms'];
    if (addonPlatformsRaw is Map) {
      for (final entry in addonPlatformsRaw.entries) {
        final key = entry.key.toString().trim().toLowerCase();
        final value = entry.value.toString().trim().toLowerCase();
        if (key.isEmpty || value.isEmpty) continue;
        rawAddonPlatforms[key] = value;
      }
    }
    final licenseTypes = _composePaymentLinkLicenseTypes(
      includeAndroid: includeAndroid,
      includeWeb: includeWeb,
      selectedAddons: selectedAddons,
    );
    final addonPlatforms = _selectedAddonPlatforms(
      includeAndroid: includeAndroid,
      includeWeb: includeWeb,
      selectedAddons: selectedAddons,
      rawChoices: rawAddonPlatforms,
    );

    setState(() => _sendingMemberPaymentLinkUserId = user.id);
    try {
      final result = await _service.createMemberPaymentLink(
        userId: user.id,
        licenseTypes: licenseTypes,
        addonPlatforms: addonPlatforms,
        sendEmail: false,
        billingPreference: billingPreference == 'invoice_monthly'
            ? 'invoice_monthly'
            : 'subscription',
      );

      await _service.sendWaMessage(
        waUser: waDigits,
        body: _paymentLinkWhatsAppMessage(user: user, invoice: result.invoice),
      );

      _toast(
        'Payment link sent via WhatsApp webhook (${result.invoice.invoiceNumber}).',
      );

      await _loadInvoices();
      await _openWhatsAppInboxTab();

      final detail = await _service.fetchMemberDetail(user.id);
      if (!mounted) return;
      setState(() {
        _members = _members
            .map((member) => member.id == detail.id ? detail : member)
            .toList();
        if (_memberDetail?.id == detail.id) {
          _memberDetail = detail;
        }
      });
    } catch (e) {
      _toast('Send payment link failed: $e');
    } finally {
      if (mounted) setState(() => _sendingMemberPaymentLinkUserId = null);
    }
  }

  Future<void> _runToolsAction() async {
    if (_toolsBusy) return;

    setState(() => _toolsBusy = true);
    try {
      final action = _toolsAction;
      if (action == null) {
        _toast('Select an action first.');
        return;
      }

      if (action == 'Create user') {
        final username = _toolCreateUsernameCtrl.text.trim();
        final email = _toolCreateEmailCtrl.text.trim().toLowerCase();
        final name = _toolCreateNameCtrl.text.trim();

        if (username.isEmpty || email.isEmpty || name.isEmpty) {
          _toast('Username, email and name are required.');
          return;
        }
        if (_toolCreateSendPaymentLink &&
            !_toolCreateCheckoutAndroid &&
            !_toolCreateCheckoutWeb) {
          _toast('Select Android and/or Web base for payment link.');
          return;
        }

        final createResult = await _service.createMemberUser(
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
          plan: _toolCreatePlanCtrl.text.trim().isEmpty
              ? null
              : _toolCreatePlanCtrl.text.trim(),
          appAndroid: _toolCreateAndroid,
          appWindows: _toolCreateWindows,
          appWeb: _toolCreateWeb,
          isBlocked: _toolCreateBlocked,
        );
        final created = createResult.user;

        AdminPaymentLinkResult? paymentLinkResult;
        String? paymentLinkError;
        if (_toolCreateSendPaymentLink) {
          final waDigits = _normalizeWhatsappDigits(created.whatsapp);
          if (waDigits == null) {
            paymentLinkError =
                'Missing/invalid WhatsApp number. Could not send payment link webhook.';
          } else {
            try {
              paymentLinkResult = await _service.createMemberPaymentLink(
                userId: created.id,
                licenseTypes: _paymentLinkLicenseTypesForCreateUser(),
                addonPlatforms: _selectedAddonPlatforms(
                  includeAndroid: _toolCreateCheckoutAndroid,
                  includeWeb: _toolCreateCheckoutWeb,
                  selectedAddons: _toolCreateCheckoutAddons,
                  rawChoices: _toolCreateCheckoutAddonPlatforms,
                ),
                sendEmail: false,
                billingPreference: _toolCreateBillingPreference,
              );
              await _service.sendWaMessage(
                waUser: waDigits,
                body: _paymentLinkWhatsAppMessage(
                  user: created,
                  invoice: paymentLinkResult.invoice,
                  tempPassword: createResult.passwordIsTemporary
                      ? createResult.tempPassword
                      : null,
                  passwordSetupUrl: createResult.portalProfileSetupUrl,
                  loginUrl: createResult.portalLoginUrl,
                ),
              );
            } catch (e) {
              paymentLinkError = e.toString();
            }
          }
        }

        if ((paymentLinkError ?? '').trim().isNotEmpty &&
            paymentLinkResult != null) {
          _toast(
            'User created. Checkout ${paymentLinkResult.invoice.invoiceNumber} created, but WhatsApp send failed: $paymentLinkError',
          );
        } else if ((paymentLinkError ?? '').trim().isNotEmpty) {
          _toast(
            'User created. Payment link WhatsApp send failed: $paymentLinkError',
          );
        } else if (paymentLinkResult == null) {
          _toast('User created: ${created.username}');
        } else {
          _toast(
            'User created + payment link sent via WhatsApp (${paymentLinkResult.invoice.invoiceNumber}).',
          );
        }

        _resetCreateUserToolForm();
        await _loadMembers();
        if (paymentLinkResult != null) {
          await _loadInvoices();
          await _openWhatsAppInboxTab();
        }
        final createdDetail = await _service.fetchMemberDetail(created.id);
        if (!mounted) return;
        setState(() {
          _selectedMemberId = created.id;
          _toolsUserId = null;
          _memberDetail = createdDetail;
          _members = _members
              .map(
                (member) =>
                    member.id == createdDetail.id ? createdDetail : member,
              )
              .toList();
        });
        return;
      }

      final targetId = _toolsUserId ?? _selectedMemberId;
      if (targetId == null) {
        _toast('Select a member first.');
        return;
      }

      if (action == 'Edit user') {
        final username = _toolCreateUsernameCtrl.text.trim();
        final email = _toolCreateEmailCtrl.text.trim().toLowerCase();
        final name = _toolCreateNameCtrl.text.trim();

        if (username.isEmpty || email.isEmpty || name.isEmpty) {
          _toast('Username, email and name are required.');
          return;
        }

        final updated = await _service.updateMemberUser(
          userId: targetId,
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
          plan: _toolCreatePlanCtrl.text.trim().isEmpty
              ? null
              : _toolCreatePlanCtrl.text.trim(),
          appAndroid: _toolCreateAndroid,
          appWindows: _toolCreateWindows,
          appWeb: _toolCreateWeb,
          isBlocked: _toolCreateBlocked,
          billingPreference: _toolCreateBillingPreference,
        );

        _toast('Member details updated.');
        await _loadMembers();
        if (!mounted) return;
        setState(() {
          _selectedMemberId = updated.id;
          _toolsUserId = updated.id;
          _members = _members
              .map((member) => member.id == updated.id ? updated : member)
              .toList();
          if (_memberDetail?.id == updated.id) {
            _memberDetail = updated;
          }
          _populateToolsFormFromUser(updated);
        });
        return;
      }

      if (action == 'Set password') {
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

      if (action == 'Toggle block') {
        final blocked = await _service.toggleMemberBlock(targetId);
        _toast(blocked ? 'User inactive.' : 'User active.');
        await _loadMembers();
        if (!mounted) return;
        setState(() {
          _selectedMemberId = targetId;
          _toolsUserId = targetId;
        });
        return;
      }

      _toast('Unknown tools action: $action');
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

  DateTime? _invoiceSuccessDate(AdminInvoice invoice) =>
      invoice.completedAt ?? invoice.paidAt ?? invoice.createdAt;

  bool _invoiceIsSuccessful(AdminInvoice invoice) {
    final status = invoice.status.trim().toLowerCase();
    return status == 'completed' || status == 'paid';
  }

  Future<void> _loadPaymentGapReport() async {
    if (_reportLoading) return;

    setState(() {
      _reportLoading = true;
      _reportError = null;
    });

    try {
      final baseMembers = _members.isNotEmpty
          ? List<AdminUser>.from(_members)
          : await _service.fetchMembers(limit: 300);
      final invoices = await _service.fetchInvoices(status: 'all', limit: 500);

      final detailedMembers = <AdminUser>[];
      for (final member in baseMembers) {
        try {
          final detail = await _service.fetchMemberDetail(member.id);
          detailedMembers.add(detail);
        } catch (_) {
          detailedMembers.add(member);
        }
      }

      final latestSuccessfulInvoiceByUser = <int, AdminInvoice>{};
      for (final invoice in invoices) {
        if (!_invoiceIsSuccessful(invoice)) continue;
        final invoiceDate = _invoiceSuccessDate(invoice);
        if (invoiceDate == null) continue;

        final existing = latestSuccessfulInvoiceByUser[invoice.userId];
        final existingDate = existing == null
            ? null
            : _invoiceSuccessDate(existing);
        if (existing == null ||
            existingDate == null ||
            invoiceDate.isAfter(existingDate)) {
          latestSuccessfulInvoiceByUser[invoice.userId] = invoice;
        }
      }

      final generatedAt = DateTime.now();
      final cutoff = _paymentGapCutoffDate(generatedAt);
      final rows = <_PaymentGapReportRow>[];

      for (final user in detailedMembers) {
        final lastInvoice = latestSuccessfulInvoiceByUser[user.id];
        final lastPaymentAt = lastInvoice == null
            ? null
            : _invoiceSuccessDate(lastInvoice);

        if (lastPaymentAt == null) {
          rows.add(
            _PaymentGapReportRow(
              groupLabel: 'No successful payment',
              user: user,
            ),
          );
          continue;
        }

        final isOlderThanMonth = lastPaymentAt.isBefore(cutoff);
        rows.add(
          _PaymentGapReportRow(
            groupLabel: isOlderThanMonth
                ? 'Payments older than a month'
                : 'Payments in the past month',
            user: user,
            lastSuccessfulInvoice: lastInvoice,
            lastPaymentAt: lastPaymentAt,
            daysSincePayment: generatedAt.difference(lastPaymentAt).inDays,
          ),
        );
      }

      rows.sort((a, b) {
        final groupCompare = _paymentSummaryGroupOrder
            .indexOf(a.groupLabel)
            .compareTo(_paymentSummaryGroupOrder.indexOf(b.groupLabel));
        if (groupCompare != 0) return groupCompare;
        return _memberSortKey(a.user).compareTo(_memberSortKey(b.user));
      });

      if (!mounted) return;
      final previousSelectedIds = Set<int>.from(_selectedPaymentReportUserIds);
      setState(() {
        _paymentGapReportRows = rows;
        _paymentGapReportCutoff = cutoff;
        _paymentGapReportGeneratedAt = generatedAt;
        _selectedPaymentReportUserIds
          ..clear()
          ..addAll(
            rows.map((row) => row.user.id).where(previousSelectedIds.contains),
          );
        _members = baseMembers;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _reportError = e.toString());
    } finally {
      if (mounted) setState(() => _reportLoading = false);
    }
  }

  String _paymentGapStatusLabel(AdminUser user) =>
      user.isBlocked ? 'INACTIVE' : 'ACTIVE';

  String _paymentGapAmountLabel(_PaymentGapReportRow row) {
    final amount = row.lastSuccessfulInvoice?.totalAmount;
    if (amount == null) return '—';
    return 'R${amount.toStringAsFixed(2)}';
  }

  String _paymentGapMethodLabel(_PaymentGapReportRow row) {
    final invoice = row.lastSuccessfulInvoice;
    if (invoice == null) return '—';
    return _invoiceMethodLabel(invoice);
  }

  List<_PaymentGapReportRow> _paymentSummaryRows() {
    final rows = _paymentGapReportRows.toList();
    rows.sort((a, b) {
      int compare;
      switch (_paymentSummarySortBy) {
        case 'member':
          compare = _memberDisplayName(
            a.user,
          ).toLowerCase().compareTo(_memberDisplayName(b.user).toLowerCase());
          break;
        case 'email':
          compare = a.user.email.trim().toLowerCase().compareTo(
            b.user.email.trim().toLowerCase(),
          );
          break;
        case 'status':
          compare = _paymentGapStatusLabel(
            a.user,
          ).compareTo(_paymentGapStatusLabel(b.user));
          break;
        case 'last_payment':
          final aDate = a.lastPaymentAt;
          final bDate = b.lastPaymentAt;
          if (aDate == null && bDate == null) {
            compare = 0;
          } else if (aDate == null) {
            compare = -1;
          } else if (bDate == null) {
            compare = 1;
          } else {
            compare = aDate.compareTo(bDate);
          }
          break;
        case 'days_ago':
          compare = (a.daysSincePayment ?? -1).compareTo(
            b.daysSincePayment ?? -1,
          );
          break;
        case 'amount':
          compare = (a.lastSuccessfulInvoice?.totalAmount ?? -1).compareTo(
            b.lastSuccessfulInvoice?.totalAmount ?? -1,
          );
          break;
        case 'payment_method':
          compare = _paymentGapMethodLabel(
            a,
          ).toLowerCase().compareTo(_paymentGapMethodLabel(b).toLowerCase());
          break;
        case 'client_code':
        default:
          compare = _memberSortKey(a.user).compareTo(_memberSortKey(b.user));
          break;
      }

      if (compare != 0) return compare;
      return _memberSortKey(a.user).compareTo(_memberSortKey(b.user));
    });
    return rows;
  }

  int _paymentSummaryCount(String groupLabel) =>
      _paymentGapReportRows.where((row) => row.groupLabel == groupLabel).length;

  bool _isPaymentSummaryRowSelected(_PaymentGapReportRow row) =>
      _selectedPaymentReportUserIds.contains(row.user.id);

  void _togglePaymentSummaryRowSelection(
    _PaymentGapReportRow row,
    bool selected,
  ) {
    setState(() {
      if (selected) {
        _selectedPaymentReportUserIds.add(row.user.id);
      } else {
        _selectedPaymentReportUserIds.remove(row.user.id);
      }
    });
  }

  void _toggleAllPaymentSummaryRows(
    List<_PaymentGapReportRow> rows,
    bool selected,
  ) {
    setState(() {
      if (selected) {
        _selectedPaymentReportUserIds.addAll(rows.map((row) => row.user.id));
      } else {
        _selectedPaymentReportUserIds.removeAll(rows.map((row) => row.user.id));
      }
    });
  }

  Future<void> _exportSelectedPaymentSummaryRows() async {
    final selectedRows = _paymentSummaryRows()
        .where((row) => _selectedPaymentReportUserIds.contains(row.user.id))
        .toList();
    if (selectedRows.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one member first.')),
      );
      return;
    }

    final fileName =
        'payment_summary_report_selected_'
        '${DateTime.now().toLocal().toIso8601String().split('T').first}.xls';

    final rows = <List<String>>[
      const [
        'Client code',
        'Member',
        'Email',
        'Status',
        'Amount',
        'Payment method',
        'Last payment',
        'Days ago',
      ],
      ...selectedRows.map((row) {
        final user = row.user;
        return [
          user.accountNumber ?? '—',
          _memberDisplayName(user),
          user.email.trim().isEmpty ? '—' : user.email.trim(),
          _paymentGapStatusLabel(user),
          _paymentGapAmountLabel(row),
          _paymentGapMethodLabel(row),
          _fmtDate(row.lastPaymentAt),
          row.daysSincePayment?.toString() ?? '—',
        ];
      }),
    ];

    try {
      final savedPath = await report_file_exporter.exportTableAsExcel(
        fileName: fileName,
        worksheetName: 'Payment Summary Report',
        rows: rows,
      );
      if (!mounted) return;
      final message = savedPath == null
          ? 'Excel export started for ${selectedRows.length} selected member(s).'
          : 'Excel file saved to $savedPath';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Export failed: $error')));
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
        status: 'all',
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

  String _invoiceMethodToken(AdminInvoice invoice) {
    final providerKey = (invoice.providerKey ?? '').trim().toLowerCase();
    final paymentMethod = (invoice.paymentMethod ?? '').trim().toLowerCase();

    if (providerKey == 'payfast' || paymentMethod.contains('payfast')) {
      return 'payfast';
    }
    if (providerKey == 'ozow' || paymentMethod.contains('ozow')) return 'ozow';
    if (providerKey == 'eft' ||
        providerKey == 'direct_eft' ||
        paymentMethod.contains('eft')) {
      return 'eft';
    }

    if (providerKey.isNotEmpty) return providerKey;
    if (paymentMethod.isNotEmpty) return paymentMethod;
    return 'unknown';
  }

  String _invoiceMethodLabel(AdminInvoice invoice) {
    final label = (invoice.paymentMethod ?? '').trim();
    if (label.isNotEmpty) return label;

    switch (_invoiceMethodToken(invoice)) {
      case 'payfast':
        return 'PayFast';
      case 'ozow':
        return 'Ozow';
      case 'eft':
        return 'Direct EFT';
      case 'unknown':
        return 'Unknown';
      default:
        return (invoice.providerKey ?? 'Unknown').trim();
    }
  }

  String _invoiceDisplayName(AdminInvoice invoice) {
    final parts = <String>[
      (invoice.name ?? '').trim(),
      (invoice.surname ?? '').trim(),
    ].where((part) => part.isNotEmpty).toList();
    final fullName = parts.join(' ').trim();
    final fallback = invoice.username.trim();
    final accountCode = (invoice.accountNumber ?? '').trim();
    final label = fullName.isNotEmpty ? fullName : fallback;
    if (accountCode.isEmpty) return label;
    return '$label ($accountCode)';
  }

  DateTime? _invoiceSortDate(AdminInvoice invoice) =>
      invoice.paidAt ?? invoice.completedAt ?? invoice.createdAt;

  int _invoiceNumericValue(String text) {
    final digits = RegExp(r'\d+').allMatches(text).map((m) => m.group(0)!);
    if (digits.isEmpty) return 0;
    return int.tryParse(digits.join()) ?? 0;
  }

  int _compareInvoices(AdminInvoice a, AdminInvoice b) {
    int result;
    switch (_invoiceSortBy) {
      case 'member':
        result = _invoiceDisplayName(
          a,
        ).toLowerCase().compareTo(_invoiceDisplayName(b).toLowerCase());
        break;
      case 'invoice':
        result = _invoiceNumericValue(
          a.invoiceNumber,
        ).compareTo(_invoiceNumericValue(b.invoiceNumber));
        if (result == 0) {
          result = a.invoiceNumber.toLowerCase().compareTo(
            b.invoiceNumber.toLowerCase(),
          );
        }
        break;
      case 'status':
        result = a.status.toLowerCase().compareTo(b.status.toLowerCase());
        break;
      case 'date':
      default:
        final aDate = _invoiceSortDate(a);
        final bDate = _invoiceSortDate(b);
        if (aDate == null && bDate == null) {
          result = 0;
        } else if (aDate == null) {
          result = -1;
        } else if (bDate == null) {
          result = 1;
        } else {
          result = aDate.compareTo(bDate);
        }
        break;
    }

    return _invoiceSortDirection == 'ascending' ? result : -result;
  }

  String _invoiceAmountLabel(AdminInvoice invoice) =>
      'R${invoice.totalAmount.toStringAsFixed(2)}';

  Widget _invoiceHeaderCell(
    String text, {
    required double width,
    TextAlign textAlign = TextAlign.left,
  }) {
    return SizedBox(
      width: width,
      child: Text(
        text,
        textAlign: textAlign,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          height: 1.2,
        ),
      ),
    );
  }

  Widget _invoiceDataCell(
    String text, {
    required double width,
    TextAlign textAlign = TextAlign.left,
  }) {
    return SizedBox(
      width: width,
      child: Text(
        text,
        textAlign: textAlign,
        style: const TextStyle(fontSize: 13.5, height: 1.35),
        overflow: TextOverflow.ellipsis,
        maxLines: 2,
      ),
    );
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

  String _paymentLinkWhatsAppMessage({
    required AdminUser user,
    required AdminInvoice invoice,
    String? tempPassword,
    String? passwordSetupUrl,
    String? loginUrl,
  }) {
    final displayName = '${user.name ?? ''} ${user.surname ?? ''}'.trim();
    final firstName = displayName.isEmpty
        ? user.username
        : displayName.split(RegExp(r'\s+')).first;
    final amount = invoice.totalAmount.toStringAsFixed(2);
    final currency = invoice.currency.trim().isEmpty ? 'ZAR' : invoice.currency;
    final paymentUrl = (invoice.checkoutUrl ?? '').trim();

    final lines = <String>[
      'Hi $firstName, your Weather Hooligan payment link is ready.',
      'Invoice: ${invoice.invoiceNumber}',
      'Amount: $amount $currency',
    ];
    if (paymentUrl.isNotEmpty) {
      lines.add('Pay here: $paymentUrl');
    }
    final cleanTempPassword = (tempPassword ?? '').trim();
    if (cleanTempPassword.isNotEmpty) {
      lines.add('Temp password: $cleanTempPassword');
    }
    final cleanPasswordSetupUrl = (passwordSetupUrl ?? '').trim();
    if (cleanPasswordSetupUrl.isNotEmpty) {
      lines.add('Change your password online: $cleanPasswordSetupUrl');
    } else {
      final cleanLoginUrl = (loginUrl ?? '').trim();
      if (cleanLoginUrl.isNotEmpty) {
        lines.add('Login online: $cleanLoginUrl');
      }
    }
    lines.add('Reply here if you need help.');

    return lines.join('\n');
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

  Future<void> _openWhatsAppInboxComposer({
    required String rawPhone,
    String? name,
  }) async {
    final waUser = _normalizeWhatsappDigits(rawPhone);
    if (waUser == null) {
      _toast('Invalid WhatsApp number.');
      return;
    }

    if (!mounted) return;
    setState(() => _tab = 6);
    await _waInboxKey.currentState?.openComposerForWaUser(
      waUser: waUser,
      title: name,
      draftMessage: _defaultSupportWhatsAppMessage(name: name),
    );
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

              if (index == 2 &&
                  _appPortalAds.isEmpty &&
                  _largeAds.isEmpty &&
                  _smallAds.isEmpty) {
                await _loadAds();
              }
              if (index == 3 && _invites.isEmpty) {
                await _loadInvites();
              }
              if (index == 4 && _invoices.isEmpty) {
                await _loadInvoices();
              }
              if (index == 5) {
                await _loadStats();
              }
              if (index == 6) {
                await _waInboxKey.currentState?.refreshAll();
              }
              if (index == 7 && _calls.isEmpty) {
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
        return _notificationsTab();
      case 2:
        return _adsTab();
      case 3:
        return _emailsTab();
      case 4:
        return _invoicesTab();
      case 5:
        return _statsTab();
      case 6:
        return _whatsAppInboxTab();
      case 7:
        return _whatsAppCallsTab();
      default:
        return _membersTab();
    }
  }

  // ignore: unused_element
  Widget _reportsTab() {
    const selectionWidth = 56.0;
    const codeWidth = 130.0;
    const memberWidth = 240.0;
    const emailWidth = 240.0;
    const statusWidth = 130.0;
    const amountWidth = 120.0;
    const methodWidth = 150.0;
    const paymentWidth = 170.0;
    const daysWidth = 120.0;
    const tableHorizontalPadding = 18.0;
    const tableColumnGap = 20.0;
    final tableWidth =
        selectionWidth +
        codeWidth +
        memberWidth +
        emailWidth +
        statusWidth +
        amountWidth +
        methodWidth +
        paymentWidth +
        daysWidth +
        (tableHorizontalPadding * 2) +
        (tableColumnGap * 7);

    final generatedAt = _paymentGapReportGeneratedAt;
    final cutoff = _paymentGapReportCutoff;
    final noPaymentCount = _paymentSummaryCount('No successful payment');
    final pastMonthCount = _paymentSummaryCount('Payments in the past month');
    final olderCount = _paymentSummaryCount('Payments older than a month');
    final visibleRows = _paymentSummaryRows();
    final selectedVisibleCount = visibleRows
        .where((row) => _selectedPaymentReportUserIds.contains(row.user.id))
        .length;
    final allVisibleSelected =
        visibleRows.isNotEmpty && selectedVisibleCount == visibleRows.length;
    final partiallySelected =
        selectedVisibleCount > 0 && selectedVisibleCount < visibleRows.length;

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Card(
        child: Column(
          children: [
            ListTile(
              title: const Text('Payment Summary Report'),
              subtitle: Text(
                'Cutoff: ${_fmtDate(cutoff)} • ${_paymentGapReportRows.length} row(s) • '
                '$pastMonthCount in the past month • $olderCount older than a month • '
                '$noPaymentCount with no successful payment',
              ),
              trailing: Wrap(
                spacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text('Sort by'),
                  DropdownButton<String>(
                    value: _paymentSummarySortBy,
                    items: const [
                      DropdownMenuItem(
                        value: 'client_code',
                        child: Text('Client code'),
                      ),
                      DropdownMenuItem(value: 'member', child: Text('Member')),
                      DropdownMenuItem(value: 'email', child: Text('Email')),
                      DropdownMenuItem(value: 'status', child: Text('Status')),
                      DropdownMenuItem(value: 'amount', child: Text('Amount')),
                      DropdownMenuItem(
                        value: 'payment_method',
                        child: Text('Payment method'),
                      ),
                      DropdownMenuItem(
                        value: 'last_payment',
                        child: Text('Last payment'),
                      ),
                      DropdownMenuItem(
                        value: 'days_ago',
                        child: Text('Days ago'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _paymentSummarySortBy = value);
                    },
                  ),
                  OutlinedButton.icon(
                    onPressed: _selectedPaymentReportUserIds.isEmpty
                        ? null
                        : _exportSelectedPaymentSummaryRows,
                    icon: const Icon(Icons.download),
                    label: Text(
                      _selectedPaymentReportUserIds.isEmpty
                          ? 'Export selected'
                          : 'Export selected (${_selectedPaymentReportUserIds.length})',
                    ),
                  ),
                  if (generatedAt != null)
                    Text(
                      'Updated ${_fmtDate(generatedAt)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  IconButton(
                    onPressed: _reportLoading ? null : _loadPaymentGapReport,
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _reportLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _reportError != null
                  ? Center(child: Text('Error: $_reportError'))
                  : visibleRows.isEmpty
                  ? const Center(child: Text('No report rows found.'))
                  : LayoutBuilder(
                      builder: (context, constraints) => SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(
                          width: tableWidth > constraints.maxWidth
                              ? tableWidth
                              : constraints.maxWidth,
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: tableHorizontalPadding,
                                  vertical: 14,
                                ),
                                color: Theme.of(context).colorScheme.surface,
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: selectionWidth,
                                      child: Align(
                                        alignment: Alignment.centerLeft,
                                        child: Checkbox(
                                          value: allVisibleSelected
                                              ? true
                                              : (partiallySelected
                                                    ? null
                                                    : false),
                                          tristate: true,
                                          onChanged: visibleRows.isEmpty
                                              ? null
                                              : (value) =>
                                                    _toggleAllPaymentSummaryRows(
                                                      visibleRows,
                                                      value ?? false,
                                                    ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: tableColumnGap),
                                    _invoiceHeaderCell(
                                      'Client code',
                                      width: codeWidth,
                                    ),
                                    const SizedBox(width: tableColumnGap),
                                    _invoiceHeaderCell(
                                      'Member',
                                      width: memberWidth,
                                    ),
                                    const SizedBox(width: tableColumnGap),
                                    _invoiceHeaderCell(
                                      'Email',
                                      width: emailWidth,
                                    ),
                                    const SizedBox(width: tableColumnGap),
                                    _invoiceHeaderCell(
                                      'Status',
                                      width: statusWidth,
                                    ),
                                    const SizedBox(width: tableColumnGap),
                                    _invoiceHeaderCell(
                                      'Amount',
                                      width: amountWidth,
                                    ),
                                    const SizedBox(width: tableColumnGap),
                                    _invoiceHeaderCell(
                                      'Payment method',
                                      width: methodWidth,
                                    ),
                                    const SizedBox(width: tableColumnGap),
                                    _invoiceHeaderCell(
                                      'Last payment',
                                      width: paymentWidth,
                                    ),
                                    const SizedBox(width: tableColumnGap),
                                    _invoiceHeaderCell(
                                      'Days ago',
                                      width: daysWidth,
                                    ),
                                  ],
                                ),
                              ),
                              const Divider(height: 1, thickness: 1.2),
                              Expanded(
                                child: ListView.separated(
                                  itemCount: visibleRows.length,
                                  separatorBuilder: (_, index) =>
                                      const Divider(height: 1, thickness: 1.1),
                                  itemBuilder: (_, index) {
                                    final row = visibleRows[index];
                                    final user = row.user;

                                    return Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: tableHorizontalPadding,
                                        vertical: 14,
                                      ),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          SizedBox(
                                            width: selectionWidth,
                                            child: Align(
                                              alignment: Alignment.centerLeft,
                                              child: Checkbox(
                                                value:
                                                    _isPaymentSummaryRowSelected(
                                                      row,
                                                    ),
                                                onChanged: (value) =>
                                                    _togglePaymentSummaryRowSelection(
                                                      row,
                                                      value ?? false,
                                                    ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: tableColumnGap),
                                          _invoiceDataCell(
                                            user.accountNumber ?? '—',
                                            width: codeWidth,
                                          ),
                                          const SizedBox(width: tableColumnGap),
                                          _invoiceDataCell(
                                            _memberDisplayName(user),
                                            width: memberWidth,
                                          ),
                                          const SizedBox(width: tableColumnGap),
                                          _invoiceDataCell(
                                            user.email.trim().isEmpty
                                                ? '—'
                                                : user.email.trim(),
                                            width: emailWidth,
                                          ),
                                          const SizedBox(width: tableColumnGap),
                                          _invoiceDataCell(
                                            _paymentGapStatusLabel(user),
                                            width: statusWidth,
                                          ),
                                          const SizedBox(width: tableColumnGap),
                                          _invoiceDataCell(
                                            _paymentGapAmountLabel(row),
                                            width: amountWidth,
                                          ),
                                          const SizedBox(width: tableColumnGap),
                                          _invoiceDataCell(
                                            _paymentGapMethodLabel(row),
                                            width: methodWidth,
                                          ),
                                          const SizedBox(width: tableColumnGap),
                                          _invoiceDataCell(
                                            _fmtDate(row.lastPaymentAt),
                                            width: paymentWidth,
                                          ),
                                          const SizedBox(width: tableColumnGap),
                                          _invoiceDataCell(
                                            row.daysSincePayment?.toString() ??
                                                '—',
                                            width: daysWidth,
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
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _membersTab() {
    final query = _memberSearchCtrl.text.trim().toLowerCase();

    final visible =
        _members.where((u) {
          if (query.isEmpty) return true;
          return _memberSearchHaystack(u).contains(query);
        }).toList()..sort(
          (a, b) => _memberDisplayName(
            a,
          ).toLowerCase().compareTo(_memberDisplayName(b).toLowerCase()),
        );

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
                      labelText: 'Search member by any detail',
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
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                  child: DropdownButtonFormField<String>(
                    key: ValueKey('members-action-${_toolsAction ?? 'none'}'),
                    initialValue: _toolsAction,
                    decoration: const InputDecoration(
                      labelText: 'Action',
                      border: OutlineInputBorder(),
                    ),
                    hint: const Text('Select action'),
                    items: const [
                      DropdownMenuItem(
                        value: 'Create user',
                        child: Text('Create user'),
                      ),
                      DropdownMenuItem(
                        value: 'Edit user',
                        child: Text('Edit user'),
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
                    onChanged: _onToolsActionChanged,
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
                ? (_toolsAction == 'Create user'
                      ? _memberToolsStandalonePanel()
                      : const Center(
                          child: Text('Select a member to view details.'),
                        ))
                : _memberDetailPanel(_memberDetail!),
          ),
        ),
      ],
    );
  }

  Widget _whatsAppInboxTab() {
    return WhatsAppMessagesPanel(key: _waInboxKey);
  }

  Widget _memberToolsStandalonePanel() {
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Text(
          'Member Actions',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        _memberToolsSection(null),
      ],
    );
  }

  Widget _memberDetailPanel(AdminUser user) {
    final whatsappRaw = (user.whatsapp ?? '').trim();
    final canMessageOnWhatsApp = whatsappRaw.isNotEmpty;
    final sendingPaymentLink = _sendingMemberPaymentLinkUserId == user.id;
    final canSendPaymentLink = _normalizeWhatsappDigits(whatsappRaw) != null;
    final accountChip = _memberAccountChip(user);

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
              label: Text(accountChip.label),
              avatar: Icon(accountChip.icon, size: 18),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 6,
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
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: canMessageOnWhatsApp
                  ? () => _sendMemberWhatsAppViaCloud(user)
                  : null,
              icon: const Icon(Icons.chat),
              label: const Text('Send WhatsApp (Cloud)'),
            ),
            FilledButton.icon(
              onPressed: sendingPaymentLink || !canSendPaymentLink
                  ? null
                  : () => _sendMemberPaymentLink(user),
              icon: sendingPaymentLink
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.link),
              label: Text(
                sendingPaymentLink ? 'Sending link...' : 'Send Payment Link',
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        const Divider(),
        _memberToolsSection(user),
        const SizedBox(height: 14),
        const Divider(),
        Row(
          children: [
            Expanded(
              child: Text(
                'Licenses',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            OutlinedButton.icon(
              onPressed: _updatingMemberLicensesUserId == user.id
                  ? null
                  : () => _manageMemberAddons(user),
              icon: _updatingMemberLicensesUserId == user.id
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.tune),
              label: Text(
                _updatingMemberLicensesUserId == user.id
                    ? 'Saving...'
                    : 'Manage Add-ons',
              ),
            ),
          ],
        ),
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

  Widget _memberToolsSection(AdminUser? currentUser) {
    final selectedUser = _toolsAction == 'Create user'
        ? null
        : (currentUser ??
              _memberDetail ??
              _findMemberById(_toolsUserId ?? _selectedMemberId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Member Actions', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 6),
        if (_toolsAction == null) const Text('Select an action to continue.'),
        if (_toolsAction != null &&
            _toolsAction != 'Create user' &&
            selectedUser == null)
          const Text('Select a member from the list first.'),
        if (_toolsAction == 'Create user') ...[
          const SizedBox(height: 12),
          Text('Create User', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _toolsField(_toolCreateUsernameCtrl, 'Username', width: 260),
              _toolsField(_toolCreateEmailCtrl, 'Email', width: 320),
              _toolsField(_toolCreateNameCtrl, 'Name', width: 220),
              _toolsField(_toolCreateSurnameCtrl, 'Surname', width: 220),
              _toolsField(_toolCreatePhoneCtrl, 'Phone', width: 220),
              _toolsField(_toolCreateWhatsAppCtrl, 'WhatsApp', width: 220),
              _toolsField(_toolCreatePlanCtrl, 'Plan', width: 160),
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
                  controlAffinity: ListTileControlAffinity.leading,
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
                  controlAffinity: ListTileControlAffinity.leading,
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
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text('Allow Web'),
                ),
              ),
              SizedBox(
                width: 220,
                child: CheckboxListTile(
                  value: _toolCreateBlocked,
                  onChanged: (value) {
                    setState(() => _toolCreateBlocked = value == true);
                  },
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text('Create as inactive'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 220,
                child: DropdownButtonFormField<String>(
                  key: ValueKey(
                    'member-create-billing-$_toolCreateBillingPreference',
                  ),
                  initialValue: _toolCreateBillingPreference,
                  decoration: const InputDecoration(
                    labelText: 'Billing preference',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'subscription',
                      child: Text('Subscription'),
                    ),
                    DropdownMenuItem(
                      value: 'invoice_monthly',
                      child: Text('Invoice Monthly'),
                    ),
                  ],
                  onChanged: _toolCreateSendPaymentLink
                      ? (value) {
                          if (value == null) return;
                          setState(() => _toolCreateBillingPreference = value);
                        }
                      : null,
                ),
              ),
              SizedBox(
                width: 220,
                child: CheckboxListTile(
                  value: _toolCreateCheckoutAndroid,
                  onChanged: _toolCreateSendPaymentLink
                      ? (value) {
                          setState(
                            () => _toolCreateCheckoutAndroid = value == true,
                          );
                        }
                      : null,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text('Charge Android base'),
                ),
              ),
              SizedBox(
                width: 220,
                child: CheckboxListTile(
                  value: _toolCreateCheckoutWeb,
                  onChanged: _toolCreateSendPaymentLink
                      ? (value) {
                          setState(
                            () => _toolCreateCheckoutWeb = value == true,
                          );
                        }
                      : null,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text('Charge Web base'),
                ),
              ),
              SizedBox(
                width: 380,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: const Text(
                    'Add-on options',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              for (final entry in _checkoutAddonLabels.entries) ...[
                SizedBox(
                  width: 380,
                  child: CheckboxListTile(
                    value: _toolCreateCheckoutAddons.contains(entry.key),
                    onChanged: _toolCreateSendPaymentLink
                        ? (value) {
                            setState(() {
                              if (value == true) {
                                _toolCreateCheckoutAddons.add(entry.key);
                                if (_isPlatformSelectableAddon(entry.key)) {
                                  _toolCreateCheckoutAddonPlatforms[entry.key] =
                                      _toolCreateCheckoutAddonPlatforms[entry
                                          .key] ??
                                      'both';
                                }
                              } else {
                                _toolCreateCheckoutAddons.remove(entry.key);
                                _toolCreateCheckoutAddonPlatforms.remove(
                                  entry.key,
                                );
                              }
                            });
                          }
                        : null,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(entry.value),
                  ),
                ),
                if (_toolCreateSendPaymentLink &&
                    _toolCreateCheckoutAddons.contains(entry.key) &&
                    _toolCreateCheckoutAndroid &&
                    _toolCreateCheckoutWeb &&
                    _isPlatformSelectableAddon(entry.key))
                  SizedBox(
                    width: 520,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 10),
                      child: SizedBox(
                        width: 260,
                        child: DropdownButtonFormField<String>(
                          initialValue:
                              _toolCreateCheckoutAddonPlatforms[entry.key] ??
                              'both',
                          decoration: const InputDecoration(
                            labelText: 'Addon platform',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'android',
                              child: Text('Android'),
                            ),
                            DropdownMenuItem(value: 'web', child: Text('Web')),
                            DropdownMenuItem(
                              value: 'both',
                              child: Text('Both'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value == null) return;
                            setState(
                              () =>
                                  _toolCreateCheckoutAddonPlatforms[entry.key] =
                                      value,
                            );
                          },
                        ),
                      ),
                    ),
                  ),
              ],
              SizedBox(
                width: 300,
                child: CheckboxListTile(
                  value: _toolCreateSendPaymentLink,
                  onChanged: (value) {
                    setState(() => _toolCreateSendPaymentLink = value == true);
                  },
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text('Send payment link after create'),
                  subtitle: const Text(
                    'Creates checkout with selected ticks and sends payment link + temp password + online password-change link via whatsapp_general.',
                  ),
                ),
              ),
            ],
          ),
        ],
        if (_toolsAction == 'Edit user') ...[
          const SizedBox(height: 12),
          Text(
            selectedUser == null
                ? 'Edit User'
                : 'Edit User: ${selectedUser.username}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 10),
          if (selectedUser == null) ...[
            const Text('Select a user first.'),
          ] else ...[
            const Text(
              'This updates the member profile and app access flags. Changing active status revokes current sessions.',
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _toolsField(_toolCreateUsernameCtrl, 'Username', width: 260),
                _toolsField(_toolCreateEmailCtrl, 'Email', width: 320),
                _toolsField(_toolCreateNameCtrl, 'Name', width: 220),
                _toolsField(_toolCreateSurnameCtrl, 'Surname', width: 220),
                _toolsField(_toolCreatePhoneCtrl, 'Phone', width: 220),
                _toolsField(_toolCreateWhatsAppCtrl, 'WhatsApp', width: 220),
                _toolsField(_toolCreatePlanCtrl, 'Plan', width: 160),
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
                    controlAffinity: ListTileControlAffinity.leading,
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
                    controlAffinity: ListTileControlAffinity.leading,
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
                    controlAffinity: ListTileControlAffinity.leading,
                    title: const Text('Allow Web'),
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: CheckboxListTile(
                    value: _toolCreateBlocked,
                    onChanged: (value) {
                      setState(() => _toolCreateBlocked = value == true);
                    },
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: const Text('Set as inactive'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: 260,
              child: DropdownButtonFormField<String>(
                key: ValueKey(
                  'member-edit-billing-$_toolCreateBillingPreference-${selectedUser.id}',
                ),
                initialValue: _toolCreateBillingPreference,
                decoration: const InputDecoration(
                  labelText: 'Billing preference',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'subscription',
                    child: Text('Subscription'),
                  ),
                  DropdownMenuItem(
                    value: 'invoice_monthly',
                    child: Text('Invoice Monthly'),
                  ),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _toolCreateBillingPreference = value);
                },
              ),
            ),
          ],
        ],
        if (_toolsAction == 'Set password') ...[
          const SizedBox(height: 12),
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
          const SizedBox(height: 12),
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
                      ? 'User account is currently INACTIVE. Running action will attempt to activate.'
                      : 'User account is currently ACTIVE. Running action will set inactive.'),
          ),
          const SizedBox(height: 8),
          const Text('Current sessions are revoked when block status changes.'),
        ],
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _toolsBusy || _toolsAction == null
              ? null
              : _runToolsAction,
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
    );
  }

  Widget _info(String key, String value) {
    return Container(
      constraints: const BoxConstraints(minWidth: 145),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white12),
      ),
      child: Text(
        '$key: $value',
        style: const TextStyle(fontSize: 13, height: 1.2),
      ),
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
                                        onPressed: () => _openWhatsAppInboxComposer(
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
    const dateWidth = 170.0;
    const memberWidth = 290.0;
    const invoiceWidth = 170.0;
    const amountWidth = 140.0;
    const statusWidth = 150.0;
    const methodWidth = 150.0;
    const viewWidth = 110.0;
    const tableHorizontalPadding = 18.0;
    const tableColumnGap = 20.0;
    final tableWidth =
        dateWidth +
        memberWidth +
        invoiceWidth +
        amountWidth +
        statusWidth +
        methodWidth +
        viewWidth +
        (tableHorizontalPadding * 2) +
        (tableColumnGap * 6);

    final invoiceSearch = _invoiceSearchCtrl.text.trim().toLowerCase();

    final visibleInvoices = _invoices.where((invoice) {
      final hay = [
        invoice.invoiceNumber,
        invoice.username,
        invoice.name ?? '',
        invoice.surname ?? '',
        invoice.email,
        invoice.accountNumber ?? '',
        invoice.providerReference ?? '',
        invoice.token,
        _invoiceMethodLabel(invoice),
        invoice.status,
      ].join(' ').toLowerCase();

      if (invoiceSearch.isNotEmpty && !hay.contains(invoiceSearch)) {
        return false;
      }
      return true;
    }).toList()..sort(_compareInvoices);

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
                  const Text('Sort by'),
                  DropdownButton<String>(
                    value: _invoiceSortBy,
                    items: const [
                      DropdownMenuItem(value: 'date', child: Text('Date')),
                      DropdownMenuItem(value: 'member', child: Text('Member')),
                      DropdownMenuItem(
                        value: 'invoice',
                        child: Text('Invoice nr'),
                      ),
                      DropdownMenuItem(value: 'status', child: Text('Status')),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => _invoiceSortBy = v);
                    },
                  ),
                  DropdownButton<String>(
                    value: _invoiceSortDirection,
                    items: const [
                      DropdownMenuItem(
                        value: 'ascending',
                        child: Text('Ascending'),
                      ),
                      DropdownMenuItem(
                        value: 'descending',
                        child: Text('Descending'),
                      ),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => _invoiceSortDirection = v);
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
                    width: 300,
                    height: 40,
                    child: TextField(
                      controller: _invoiceSearchCtrl,
                      expands: true,
                      minLines: null,
                      maxLines: null,
                      decoration: const InputDecoration(
                        hintText: 'Search invoice/member/account/email/ref',
                        border: OutlineInputBorder(),
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        prefixIcon: Icon(Icons.search, size: 18),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {
                      _invoiceSearchCtrl.clear();
                      setState(() {
                        _invoiceSortBy = 'date';
                        _invoiceSortDirection = 'descending';
                      });
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
                  : LayoutBuilder(
                      builder: (context, constraints) => Scrollbar(
                        controller: _invoiceHorizontalScrollCtrl,
                        thumbVisibility: true,
                        notificationPredicate: (notification) =>
                            notification.metrics.axis == Axis.horizontal,
                        child: SingleChildScrollView(
                          controller: _invoiceHorizontalScrollCtrl,
                          scrollDirection: Axis.horizontal,
                          child: SizedBox(
                            width: tableWidth > constraints.maxWidth
                                ? tableWidth
                                : constraints.maxWidth,
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: tableHorizontalPadding,
                                    vertical: 14,
                                  ),
                                  color: Theme.of(context).colorScheme.surface,
                                  child: Row(
                                    children: [
                                      _invoiceHeaderCell(
                                        'Date',
                                        width: dateWidth,
                                      ),
                                      const SizedBox(width: tableColumnGap),
                                      _invoiceHeaderCell(
                                        'Member',
                                        width: memberWidth,
                                      ),
                                      const SizedBox(width: tableColumnGap),
                                      _invoiceHeaderCell(
                                        'Invoice nr',
                                        width: invoiceWidth,
                                      ),
                                      const SizedBox(width: tableColumnGap),
                                      _invoiceHeaderCell(
                                        'Amount',
                                        width: amountWidth,
                                      ),
                                      const SizedBox(width: tableColumnGap),
                                      _invoiceHeaderCell(
                                        'Status',
                                        width: statusWidth,
                                      ),
                                      const SizedBox(width: tableColumnGap),
                                      _invoiceHeaderCell(
                                        'Method',
                                        width: methodWidth,
                                      ),
                                      const SizedBox(width: tableColumnGap),
                                      _invoiceHeaderCell(
                                        'View',
                                        width: viewWidth,
                                      ),
                                    ],
                                  ),
                                ),
                                const Divider(height: 1, thickness: 1.2),
                                Expanded(
                                  child: Scrollbar(
                                    controller: _invoiceVerticalScrollCtrl,
                                    thumbVisibility: true,
                                    child: ListView.separated(
                                      controller: _invoiceVerticalScrollCtrl,
                                      itemCount: visibleInvoices.length,
                                      separatorBuilder: (_, index) =>
                                          const Divider(
                                            height: 1,
                                            thickness: 1.1,
                                          ),
                                      itemBuilder: (_, i) {
                                        final invoice = visibleInvoices[i];
                                        final invoiceDateText = _fmtDate(
                                          _invoiceSortDate(invoice),
                                        );
                                        final methodLabel = _invoiceMethodLabel(
                                          invoice,
                                        );
                                        final checkoutUrl =
                                            (invoice.checkoutUrl ?? '').trim();

                                        return Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: tableHorizontalPadding,
                                            vertical: 14,
                                          ),
                                          child: Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.center,
                                            children: [
                                              _invoiceDataCell(
                                                invoiceDateText,
                                                width: dateWidth,
                                              ),
                                              const SizedBox(
                                                width: tableColumnGap,
                                              ),
                                              _invoiceDataCell(
                                                _invoiceDisplayName(invoice),
                                                width: memberWidth,
                                              ),
                                              const SizedBox(
                                                width: tableColumnGap,
                                              ),
                                              _invoiceDataCell(
                                                invoice.invoiceNumber,
                                                width: invoiceWidth,
                                              ),
                                              const SizedBox(
                                                width: tableColumnGap,
                                              ),
                                              _invoiceDataCell(
                                                _invoiceAmountLabel(invoice),
                                                width: amountWidth,
                                              ),
                                              const SizedBox(
                                                width: tableColumnGap,
                                              ),
                                              _invoiceDataCell(
                                                invoice.status,
                                                width: statusWidth,
                                              ),
                                              const SizedBox(
                                                width: tableColumnGap,
                                              ),
                                              _invoiceDataCell(
                                                methodLabel,
                                                width: methodWidth,
                                              ),
                                              const SizedBox(
                                                width: tableColumnGap,
                                              ),
                                              SizedBox(
                                                width: viewWidth,
                                                child: checkoutUrl.isEmpty
                                                    ? const Text(
                                                        '-',
                                                        style: TextStyle(
                                                          fontSize: 13.5,
                                                          height: 1.35,
                                                        ),
                                                      )
                                                    : Align(
                                                        alignment: Alignment
                                                            .centerLeft,
                                                        child: TextButton(
                                                          onPressed: () =>
                                                              _openExternal(
                                                                checkoutUrl,
                                                              ),
                                                          style: TextButton.styleFrom(
                                                            padding:
                                                                EdgeInsets.zero,
                                                            minimumSize:
                                                                const Size(
                                                                  0,
                                                                  0,
                                                                ),
                                                            tapTargetSize:
                                                                MaterialTapTargetSize
                                                                    .shrinkWrap,
                                                            visualDensity:
                                                                VisualDensity
                                                                    .compact,
                                                          ),
                                                          child: const Text(
                                                            'Open',
                                                            style: TextStyle(
                                                              fontSize: 13.5,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
