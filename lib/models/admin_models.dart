// admin_models.dart
//
// Models used by the Admin Dashboard UI.
// Defensive parsing: accepts snake_case + camelCase keys,
// and safely parses dates/numbers.

DateTime? _parseDate(dynamic v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  final s = v.toString().trim();
  if (s.isEmpty) return null;
  return DateTime.tryParse(s);
}

bool _parseBool(dynamic v) {
  if (v == null) return false;
  if (v is bool) return v;
  if (v is num) return v != 0;
  final s = v.toString().toLowerCase().trim();
  return s == '1' || s == 'true' || s == 'yes' || s == 'y';
}

double? _parseDouble(dynamic v) {
  if (v == null) return null;
  if (v is double) return v;
  if (v is int) return v.toDouble();
  return double.tryParse(v.toString());
}

int _parseInt(dynamic v, {int fallback = 0}) {
  if (v == null) return fallback;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString()) ?? fallback;
}

String? _readString(dynamic v) {
  final s = v?.toString().trim();
  return (s == null || s.isEmpty) ? null : s;
}

bool? _getAppWebValue(Map<String, dynamic> json) {
  final keys = [
    'app_web',
    'appWeb',
    'app_webapp',
    'appWebapp',
    'web_app',
    'webapp',
    'member_web',
    'memberWeb',
  ];
  for (final key in keys) {
    if (json.containsKey(key)) {
      return _parseBool(json[key]);
    }
  }
  return null;
}

// -----------------------------------------------------------------------------
// Admin User
// -----------------------------------------------------------------------------
class AdminUser {
  final int id;
  final String username;
  final String email;
  final String? accountNumber;

  final String? name;
  final String? surname;
  final String? phone;
  final String? cellphone;
  final String? whatsapp;
  final String? addressLine1;
  final String? addressLine2;
  final String? town;
  final String? local;
  final String? metroDistrict;
  final String? city;
  final String? province;
  final String? postalCode;
  final bool? appAndroid;
  final bool? appWindows;
  final bool? appWeb;

  /// e.g. "free", "premium", "trial", or your own labels.
  final String? plan;

  /// Whether user is an admin (if your API provides it).
  final bool? isAdmin;

  /// Whether user is blocked/suspended.
  final bool isBlocked;

  /// Account created date/time (used by Dashboard UI).
  final DateTime? createdAt;

  /// Recent login logs (used by Dashboard UI).
  final List<LoginLog> loginLogs;

  /// Payments list (used by Dashboard UI).
  final List<UserPayment> payments;
  final List<AdminLicense> licenses;

  const AdminUser({
    required this.id,
    required this.username,
    required this.email,
    this.accountNumber,
    this.name,
    this.surname,
    this.phone,
    this.cellphone,
    this.whatsapp,
    this.addressLine1,
    this.addressLine2,
    this.town,
    this.local,
    this.metroDistrict,
    this.city,
    this.province,
    this.postalCode,
    this.appAndroid,
    this.appWindows,
    this.appWeb,
    this.plan,
    this.isAdmin,
    required this.isBlocked,
    this.createdAt,
    this.loginLogs = const [],
    this.payments = const [],
    this.licenses = const [],
  });

  /// Backwards compatibility: older code might still use `logs`.
  List<LoginLog> get logs => loginLogs;

  factory AdminUser.fromJson(Map<String, dynamic> json) {
    final logsRaw =
        (json['login_logs'] ?? json['loginLogs'] ?? json['logs'] ?? const [])
            as List;
    final paysRaw =
        (json['payments'] ?? json['user_payments'] ?? const []) as List;
    final licensesRaw = (json['licenses'] ?? const []) as List;

    return AdminUser(
      id: _parseInt(json['id']),
      username: (json['username'] ?? 'N/A').toString(),
      email: (json['email'] ?? '').toString(),
      accountNumber: _readString(
        json['account_number'] ?? json['accountNumber'],
      ),
      name: _readString(json['name']),
      surname: _readString(json['surname']),
      phone: _readString(json['phone'] ?? json['cell'] ?? json['mobile']),
      cellphone: _readString(json['cellphone'] ?? json['cell_phone']),
      whatsapp: _readString(json['whatsapp'] ?? json['wa']),
      addressLine1: _readString(json['address_line_1'] ?? json['addressLine1']),
      addressLine2: _readString(json['address_line_2'] ?? json['addressLine2']),
      town: _readString(json['town']),
      local: _readString(json['local']),
      metroDistrict: _readString(
        json['metro_district'] ?? json['metroDistrict'],
      ),
      city: _readString(json['city']),
      province: _readString(json['province']),
      postalCode: _readString(json['postal_code'] ?? json['postalCode']),
      appAndroid: json.containsKey('app_android')
          ? _parseBool(json['app_android'])
          : (json.containsKey('appAndroid')
                ? _parseBool(json['appAndroid'])
                : null),
      appWindows: json.containsKey('app_windows')
          ? _parseBool(json['app_windows'])
          : (json.containsKey('appWindows')
                ? _parseBool(json['appWindows'])
                : null),
      appWeb: _getAppWebValue(json),
      plan: _readString(
        json['plan'] ?? json['subscription_plan'] ?? json['tier'],
      ),
      isAdmin: json.containsKey('is_admin')
          ? _parseBool(json['is_admin'])
          : (json.containsKey('isAdmin') ? _parseBool(json['isAdmin']) : null),
      isBlocked: _parseBool(
        json['is_blocked'] ?? json['isBlocked'] ?? json['blocked'],
      ),
      createdAt: _parseDate(json['created_at'] ?? json['createdAt']),
      loginLogs: logsRaw
          .whereType<Map>()
          .map((e) => LoginLog.fromJson(e.cast<String, dynamic>()))
          .toList(),
      payments: paysRaw
          .whereType<Map>()
          .map((e) => UserPayment.fromJson(e.cast<String, dynamic>()))
          .toList(),
      licenses: licensesRaw
          .whereType<Map>()
          .map((e) => AdminLicense.fromJson(e.cast<String, dynamic>()))
          .toList(),
    );
  }
}

// -----------------------------------------------------------------------------
// Admin Ad
// -----------------------------------------------------------------------------
class AdminAd {
  final int id;
  final String title;
  final String? message;

  final String? imageUrl; // full image
  final String? thumbUrl; // 16:9 thumb

  final String? linkUrl;
  final bool active;
  final int? weight;

  final DateTime? startsAt;
  final DateTime? endsAt;
  final DateTime? createdAt;

  const AdminAd({
    required this.id,
    required this.title,
    this.message,
    this.imageUrl,
    this.thumbUrl,
    this.linkUrl,
    required this.active,
    this.weight,
    this.startsAt,
    this.endsAt,
    this.createdAt,
  });

  factory AdminAd.fromJson(Map<String, dynamic> j) {
    return AdminAd(
      id: _parseInt(j['id']),
      title: (j['title'] ?? '').toString(),
      message: _readString(j['message']),
      // Laravel appends: image_url + thumb_url
      imageUrl: _readString(j['image_url'] ?? j['imageUrl']),
      thumbUrl: _readString(
        j['thumb_url'] ??
            j['thumbUrl'] ??
            j['thumbnail_url'] ??
            j['thumbnailUrl'],
      ),
      linkUrl: _readString(j['link_url'] ?? j['linkUrl']),
      active: _parseBool(j['active']),
      weight: j['weight'] == null ? null : _parseInt(j['weight'], fallback: 0),
      startsAt: _parseDate(j['starts_at'] ?? j['startsAt']),
      endsAt: _parseDate(j['ends_at'] ?? j['endsAt']),
      createdAt: _parseDate(j['created_at'] ?? j['createdAt']),
    );
  }
}

// -----------------------------------------------------------------------------
// Invite Email
// -----------------------------------------------------------------------------
class AdminInvite {
  final int id;
  final String name;
  final String surname;
  final String email;
  final String? whatsappPhone;
  final String status;
  final String? registerLink;
  final DateTime? expiresAt;
  final DateTime? openedAt;
  final DateTime? usedAt;
  final DateTime? createdAt;

  const AdminInvite({
    required this.id,
    required this.name,
    required this.surname,
    required this.email,
    this.whatsappPhone,
    required this.status,
    this.registerLink,
    this.expiresAt,
    this.openedAt,
    this.usedAt,
    this.createdAt,
  });

  factory AdminInvite.fromJson(Map<String, dynamic> j) => AdminInvite(
    id: _parseInt(j['id']),
    name: (j['name'] ?? '').toString(),
    surname: (j['surname'] ?? '').toString(),
    email: (j['email'] ?? '').toString(),
    whatsappPhone: _readString(
      j['whatsapp_phone'] ?? j['whatsappPhone'] ?? j['cellphone'],
    ),
    status: (j['status'] ?? 'active').toString(),
    registerLink: _readString(j['register_link'] ?? j['registerLink']),
    expiresAt: _parseDate(j['expires_at'] ?? j['expiresAt']),
    openedAt: _parseDate(j['opened_at'] ?? j['openedAt']),
    usedAt: _parseDate(j['used_at'] ?? j['usedAt']),
    createdAt: _parseDate(j['created_at'] ?? j['createdAt']),
  );
}

// -----------------------------------------------------------------------------
// Invoice
// -----------------------------------------------------------------------------
class AdminInvoice {
  final int id;
  final String invoiceNumber;
  final String token;
  final String status;
  final String currency;
  final double totalAmount;
  final String? providerKey;
  final String? providerReference;
  final String? checkoutUrl;
  final int userId;
  final String username;
  final String email;
  final String? accountNumber;
  final DateTime? paidAt;
  final DateTime? completedAt;
  final DateTime? createdAt;

  const AdminInvoice({
    required this.id,
    required this.invoiceNumber,
    required this.token,
    required this.status,
    required this.currency,
    required this.totalAmount,
    this.providerKey,
    this.providerReference,
    this.checkoutUrl,
    required this.userId,
    required this.username,
    required this.email,
    this.accountNumber,
    this.paidAt,
    this.completedAt,
    this.createdAt,
  });

  factory AdminInvoice.fromJson(Map<String, dynamic> j) {
    final user = j['user'];
    final userMap = user is Map ? user.cast<String, dynamic>() : const {};
    return AdminInvoice(
      id: _parseInt(j['id']),
      invoiceNumber:
          (j['invoice_number'] ?? j['invoiceNumber'] ?? '').toString(),
      token: (j['token'] ?? '').toString(),
      status: (j['status'] ?? '').toString(),
      currency: (j['currency'] ?? 'ZAR').toString(),
      totalAmount: _parseDouble(j['total_amount'] ?? j['amount']) ?? 0.0,
      providerKey: _readString(j['provider_key'] ?? j['providerKey']),
      providerReference: _readString(
        j['provider_reference'] ?? j['providerReference'],
      ),
      checkoutUrl: _readString(j['checkout_url'] ?? j['checkoutUrl']),
      userId: _parseInt(
        userMap['id'] ?? j['user_id'] ?? j['userId'],
        fallback: 0,
      ),
      username: (userMap['username'] ?? j['username'] ?? '').toString(),
      email: (userMap['email'] ?? j['email'] ?? '').toString(),
      accountNumber: _readString(
        userMap['account_number'] ?? userMap['accountNumber'] ??
            j['account_number'] ??
            j['accountNumber'],
      ),
      paidAt: _parseDate(j['paid_at'] ?? j['paidAt']),
      completedAt: _parseDate(j['completed_at'] ?? j['completedAt']),
      createdAt: _parseDate(j['created_at'] ?? j['createdAt']),
    );
  }
}

// -----------------------------------------------------------------------------
// Email Logs (Welcome / Signup)
// -----------------------------------------------------------------------------
class EmailLog {
  final int id;
  final int? userId;
  final String recipientEmail;
  final String type;
  final String subject;
  final String status;
  final DateTime? sentAt;
  final DateTime? createdAt;

  const EmailLog({
    required this.id,
    required this.recipientEmail,
    required this.type,
    required this.subject,
    required this.status,
    this.userId,
    this.sentAt,
    this.createdAt,
  });

  factory EmailLog.fromJson(Map<String, dynamic> json) {
    return EmailLog(
      id: _parseInt(json['id']),
      userId: json['user_id'] == null ? null : _parseInt(json['user_id']),
      recipientEmail: (json['recipient_email'] ?? json['recipientEmail'] ?? '')
          .toString(),
      type: (json['type'] ?? '').toString(),
      subject: (json['subject'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      sentAt: _parseDate(json['sent_at'] ?? json['sentAt']),
      createdAt: _parseDate(json['created_at'] ?? json['createdAt']),
    );
  }
}

// -----------------------------------------------------------------------------
// Login Log
// -----------------------------------------------------------------------------
class LoginLog {
  final String? ipAddress;
  final DateTime? loginAt;

  const LoginLog({this.ipAddress, this.loginAt});

  /// Backwards compatibility with older code that used `ip` and `date`.
  String get ip => ipAddress ?? 'N/A';
  String get date => loginAt?.toIso8601String() ?? '';

  factory LoginLog.fromJson(Map<String, dynamic> json) => LoginLog(
    ipAddress: _readString(
      json['ip_address'] ?? json['ipAddress'] ?? json['ip'],
    ),
    loginAt: _parseDate(json['login_at'] ?? json['loginAt'] ?? json['date']),
  );
}

// -----------------------------------------------------------------------------
// License Session
// -----------------------------------------------------------------------------
class AdminSession {
  final int id;
  final String? appType;
  final String? deviceName;
  final String? label;
  final DateTime? lastUsedAt;
  final DateTime? createdAt;

  const AdminSession({
    required this.id,
    this.appType,
    this.deviceName,
    this.label,
    this.lastUsedAt,
    this.createdAt,
  });

  factory AdminSession.fromJson(Map<String, dynamic> json) => AdminSession(
    id: _parseInt(json['id']),
    appType: _readString(json['app_type'] ?? json['appType']),
    deviceName: _readString(json['device_name'] ?? json['deviceName']),
    label: _readString(json['label']),
    lastUsedAt: _parseDate(json['last_used_at'] ?? json['lastUsedAt']),
    createdAt: _parseDate(json['created_at'] ?? json['createdAt']),
  );
}

// -----------------------------------------------------------------------------
// User Payment
// -----------------------------------------------------------------------------
class UserPayment {
  final double? amount;
  final String? currency;
  final String? reference;
  final String? status;
  final DateTime? paymentDate;
  final DateTime? createdAt;

  const UserPayment({
    this.amount,
    this.currency,
    this.reference,
    this.status,
    this.paymentDate,
    this.createdAt,
  });

  /// Backwards compatibility with older code that used `date` and `ref`.
  String get date => paymentDate?.toIso8601String() ?? '';
  String get ref => reference ?? '';

  factory UserPayment.fromJson(Map<String, dynamic> json) => UserPayment(
    amount: _parseDouble(json['amount']),
    currency:
        _readString(json['currency'] ?? json['cur'] ?? json['ccy']) ?? 'ZAR',
    reference: _readString(
      json['reference'] ?? json['ref'] ?? json['payment_reference'],
    ),
    status: _readString(json['status'] ?? json['state']),
    paymentDate: _parseDate(
      json['payment_date'] ?? json['paymentDate'] ?? json['date'],
    ),
    createdAt: _parseDate(json['created_at'] ?? json['createdAt']),
  );
}

// -----------------------------------------------------------------------------
// Admin License
// -----------------------------------------------------------------------------
class AdminLicense {
  final int id;
  final String licenseType;
  final String status;
  final bool isPaid;
  final bool isFree;
  final bool isLocked;
  final String? licenseKeyHint;
  final String? deviceLabel;
  final DateTime? lastUsedAt;

  const AdminLicense({
    required this.id,
    required this.licenseType,
    required this.status,
    required this.isPaid,
    required this.isFree,
    required this.isLocked,
    this.licenseKeyHint,
    this.deviceLabel,
    this.lastUsedAt,
  });

  factory AdminLicense.fromJson(Map<String, dynamic> j) => AdminLicense(
    id: _parseInt(j['id']),
    licenseType: (j['license_type'] ?? j['licenseType'] ?? '').toString(),
    status: (j['status'] ?? '').toString(),
    isPaid: _parseBool(j['is_paid'] ?? j['isPaid']),
    isFree: _parseBool(j['is_free'] ?? j['isFree']),
    isLocked: _parseBool(j['is_locked'] ?? j['isLocked']),
    licenseKeyHint: _readString(j['license_key_hint'] ?? j['licenseKeyHint']),
    deviceLabel: _readString(j['device_label'] ?? j['deviceLabel']),
    lastUsedAt: _parseDate(j['last_used_at'] ?? j['lastUsedAt']),
  );
}

// -----------------------------------------------------------------------------
// Admin Notice (Alerts)
// -----------------------------------------------------------------------------
class AdminNotice {
  final int id;
  final String type;
  final String severity; // info|warning|critical
  final String title;
  final String? body;
  final Map<String, dynamic>? payload;
  final int? relatedUserId;
  final DateTime? readAt;
  final DateTime? createdAt;

  const AdminNotice({
    required this.id,
    required this.type,
    required this.severity,
    required this.title,
    this.body,
    this.payload,
    this.relatedUserId,
    this.readAt,
    this.createdAt,
  });

  bool get isRead => readAt != null;

  factory AdminNotice.fromJson(Map<String, dynamic> j) {
    final payloadRaw = j['payload'];
    return AdminNotice(
      id: _parseInt(j['id']),
      type: (j['type'] ?? '').toString(),
      severity: (j['severity'] ?? 'info').toString(),
      title: (j['title'] ?? '').toString(),
      body: _readString(j['body']),
      payload: payloadRaw is Map
          ? payloadRaw.cast<String, dynamic>()
          : (payloadRaw is String ? {'raw': payloadRaw} : null),
      relatedUserId: j['related_user_id'] == null
          ? null
          : _parseInt(j['related_user_id'], fallback: 0),
      readAt: _parseDate(j['read_at'] ?? j['readAt']),
      createdAt: _parseDate(j['created_at'] ?? j['createdAt']),
    );
  }
}

// -----------------------------------------------------------------------------
// Profile Change Request (Approvals)
// -----------------------------------------------------------------------------
class ProfileChangeRequest {
  final int id;
  final int userId;
  final String status;
  final Map<String, dynamic> payload;
  final DateTime? createdAt;
  final AdminUser? user;

  const ProfileChangeRequest({
    required this.id,
    required this.userId,
    required this.status,
    required this.payload,
    this.createdAt,
    this.user,
  });

  List<String> get fieldsChanged =>
      payload.keys.map((e) => e.toString()).toList();

  factory ProfileChangeRequest.fromJson(Map<String, dynamic> j) {
    final p = (j['payload'] is Map)
        ? (j['payload'] as Map).cast<String, dynamic>()
        : <String, dynamic>{};

    AdminUser? u;
    final uRaw = j['user'];
    if (uRaw is Map) {
      try {
        u = AdminUser.fromJson(uRaw.cast<String, dynamic>());
      } catch (_) {
        u = null;
      }
    }

    return ProfileChangeRequest(
      id: _parseInt(j['id']),
      userId: _parseInt(j['user_id'] ?? j['userId']),
      status: (j['status'] ?? '').toString(),
      payload: p,
      createdAt: _parseDate(j['created_at'] ?? j['createdAt']),
      user: u,
    );
  }
}

// -----------------------------------------------------------------------------
// System: Health / Usage / Visits
// -----------------------------------------------------------------------------
class HealthCheck {
  final bool ok;
  final String? error;

  const HealthCheck({required this.ok, this.error});

  factory HealthCheck.fromJson(dynamic j) {
    if (j is Map) {
      return HealthCheck(
        ok: _parseBool(j['ok']),
        error: _readString(j['error']),
      );
    }
    return const HealthCheck(ok: false);
  }
}

class DiskStats {
  final int? freeMb;
  final int? totalMb;

  const DiskStats({this.freeMb, this.totalMb});

  factory DiskStats.fromJson(dynamic j) {
    if (j is Map) {
      return DiskStats(
        freeMb: j['free_mb'] == null ? null : _parseInt(j['free_mb']),
        totalMb: j['total_mb'] == null ? null : _parseInt(j['total_mb']),
      );
    }
    return const DiskStats();
  }
}

class StoragePathCheck {
  final String? path;
  final bool writable;

  const StoragePathCheck({this.path, required this.writable});

  factory StoragePathCheck.fromJson(dynamic j) {
    if (j is Map) {
      return StoragePathCheck(
        path: _readString(j['path']),
        writable: _parseBool(j['writable']),
      );
    }
    return const StoragePathCheck(writable: false);
  }
}

class StorageCheck {
  final bool ok;
  final List<StoragePathCheck> paths;

  const StorageCheck({required this.ok, this.paths = const []});

  factory StorageCheck.fromJson(dynamic j) {
    if (j is Map) {
      final list = (j['paths'] is List)
          ? (j['paths'] as List)
                .whereType<Map>()
                .map((e) => StoragePathCheck.fromJson(e))
                .toList()
          : <StoragePathCheck>[];
      return StorageCheck(ok: _parseBool(j['ok']), paths: list);
    }
    return const StorageCheck(ok: false);
  }
}

class SystemHealth {
  final String status;
  final String? serverTime;
  final String? env;
  final String? php;
  final String? laravel;
  final DiskStats? disk;
  final HealthCheck db;
  final HealthCheck cache;
  final StorageCheck storage;
  final String? queue;

  const SystemHealth({
    required this.status,
    this.serverTime,
    this.env,
    this.php,
    this.laravel,
    this.disk,
    required this.db,
    required this.cache,
    required this.storage,
    this.queue,
  });

  factory SystemHealth.fromJson(Map<String, dynamic> j) {
    return SystemHealth(
      status: (j['status'] ?? '').toString(),
      serverTime: _readString(j['server_time'] ?? j['serverTime']),
      env: _readString(j['env']),
      php: _readString(j['php']),
      laravel: _readString(j['laravel']),
      disk: j.containsKey('disk') ? DiskStats.fromJson(j['disk']) : null,
      db: HealthCheck.fromJson(j['db']),
      cache: HealthCheck.fromJson(j['cache']),
      storage: StorageCheck.fromJson(j['storage']),
      queue: _readString(j['queue']),
    );
  }
}

class UserUsage {
  final int total;
  final int admins;
  final int blocked;
  final int subscribed;
  final int expired;
  final int mustChangePassword;

  const UserUsage({
    required this.total,
    required this.admins,
    required this.blocked,
    required this.subscribed,
    required this.expired,
    required this.mustChangePassword,
  });

  factory UserUsage.fromJson(dynamic j) {
    if (j is Map) {
      return UserUsage(
        total: _parseInt(j['total']),
        admins: _parseInt(j['admins']),
        blocked: _parseInt(j['blocked']),
        subscribed: _parseInt(j['subscribed']),
        expired: _parseInt(j['expired']),
        mustChangePassword: _parseInt(
          j['must_change_password'] ?? j['mustChangePassword'],
        ),
      );
    }
    return const UserUsage(
      total: 0,
      admins: 0,
      blocked: 0,
      subscribed: 0,
      expired: 0,
      mustChangePassword: 0,
    );
  }
}

class AppOptionCap {
  final int cap;
  final int count;
  final bool full;

  const AppOptionCap({
    required this.cap,
    required this.count,
    required this.full,
  });

  factory AppOptionCap.fromJson(dynamic j) {
    if (j is Map) {
      return AppOptionCap(
        cap: _parseInt(j['cap']),
        count: _parseInt(j['count']),
        full: _parseBool(j['full']),
      );
    }
    return const AppOptionCap(cap: 0, count: 0, full: false);
  }
}

class AppOptionCaps {
  final AppOptionCap android;
  final AppOptionCap windows;

  const AppOptionCaps({required this.android, required this.windows});

  factory AppOptionCaps.fromJson(dynamic j) {
    if (j is Map) {
      return AppOptionCaps(
        android: AppOptionCap.fromJson(j['android']),
        windows: AppOptionCap.fromJson(j['windows']),
      );
    }
    return AppOptionCaps(
      android: const AppOptionCap(cap: 0, count: 0, full: false),
      windows: const AppOptionCap(cap: 0, count: 0, full: false),
    );
  }
}

class TokenCount {
  final String? appType;
  final int count;

  const TokenCount({this.appType, required this.count});

  factory TokenCount.fromJson(dynamic j) {
    if (j is Map) {
      return TokenCount(
        appType: _readString(j['app_type'] ?? j['appType']),
        count: _parseInt(j['count']),
      );
    }
    return const TokenCount(count: 0);
  }
}

class ActivityStats {
  final int loginLogs24h;
  final int auditLogs24h;
  final int errorLogs24h;

  const ActivityStats({
    required this.loginLogs24h,
    required this.auditLogs24h,
    required this.errorLogs24h,
  });

  factory ActivityStats.fromJson(dynamic j) {
    if (j is Map) {
      return ActivityStats(
        loginLogs24h: _parseInt(j['login_logs_24h'] ?? j['loginLogs24h']),
        auditLogs24h: _parseInt(j['audit_logs_24h'] ?? j['auditLogs24h']),
        errorLogs24h: _parseInt(j['error_logs_24h'] ?? j['errorLogs24h']),
      );
    }
    return const ActivityStats(
      loginLogs24h: 0,
      auditLogs24h: 0,
      errorLogs24h: 0,
    );
  }
}

class SystemUsage {
  final UserUsage users;
  final AppOptionCaps appOptions;
  final List<TokenCount> tokensByType;
  final ActivityStats activity;

  const SystemUsage({
    required this.users,
    required this.appOptions,
    required this.tokensByType,
    required this.activity,
  });

  factory SystemUsage.fromJson(Map<String, dynamic> j) {
    final tokensRaw = (j['tokens'] is Map)
        ? (j['tokens']['by_app_type'] ?? [])
        : [];
    final tokens = (tokensRaw is List)
        ? tokensRaw.whereType<Map>().map((e) => TokenCount.fromJson(e)).toList()
        : <TokenCount>[];

    return SystemUsage(
      users: UserUsage.fromJson(j['users']),
      appOptions: AppOptionCaps.fromJson(j['app_options'] ?? j['appOptions']),
      tokensByType: tokens,
      activity: ActivityStats.fromJson(j['activity']),
    );
  }
}

class VisitDaily {
  final String date;
  final int count;

  const VisitDaily({required this.date, required this.count});

  factory VisitDaily.fromJson(dynamic j) {
    if (j is Map) {
      return VisitDaily(
        date: (j['date'] ?? '').toString(),
        count: _parseInt(j['count']),
      );
    }
    return const VisitDaily(date: '', count: 0);
  }
}

class SystemVisits {
  final int thisHour;
  final int last24h;
  final int today;
  final int thisWeek;
  final int thisMonth;
  final int allTime;
  final List<VisitDaily> daily;

  const SystemVisits({
    required this.thisHour,
    required this.last24h,
    required this.today,
    required this.thisWeek,
    required this.thisMonth,
    required this.allTime,
    required this.daily,
  });

  factory SystemVisits.fromJson(Map<String, dynamic> j) {
    final dailyRaw = (j['daily'] ?? []) as List;
    return SystemVisits(
      thisHour: _parseInt(j['this_hour']),
      last24h: _parseInt(j['last_24h']),
      today: _parseInt(j['today']),
      thisWeek: _parseInt(j['this_week']),
      thisMonth: _parseInt(j['this_month']),
      allTime: _parseInt(j['all_time']),
      daily: dailyRaw
          .whereType<Map>()
          .map((e) => VisitDaily.fromJson(e))
          .toList(),
    );
  }
}

// -----------------------------------------------------------------------------
// Admin Audit + Error Logs
// -----------------------------------------------------------------------------
class AdminAuditLog {
  final int id;
  final int? userId;
  final String? action;
  final String? ip;
  final Map<String, dynamic>? meta;
  final DateTime? createdAt;

  const AdminAuditLog({
    required this.id,
    this.userId,
    this.action,
    this.ip,
    this.meta,
    this.createdAt,
  });

  factory AdminAuditLog.fromJson(Map<String, dynamic> j) {
    return AdminAuditLog(
      id: _parseInt(j['id']),
      userId: j['user_id'] == null ? null : _parseInt(j['user_id']),
      action: _readString(j['action']),
      ip: _readString(j['ip']),
      meta: (j['meta'] is Map)
          ? (j['meta'] as Map).cast<String, dynamic>()
          : null,
      createdAt: _parseDate(j['created_at'] ?? j['createdAt']),
    );
  }
}

class AdminErrorLog {
  final int id;
  final String? level;
  final String? message;
  final String? requestId;
  final String? appType;
  final String? method;
  final String? url;
  final String? ip;
  final String? exceptionClass;
  final int? userId;
  final DateTime? createdAt;

  const AdminErrorLog({
    required this.id,
    this.level,
    this.message,
    this.requestId,
    this.appType,
    this.method,
    this.url,
    this.ip,
    this.exceptionClass,
    this.userId,
    this.createdAt,
  });

  factory AdminErrorLog.fromJson(Map<String, dynamic> j) {
    return AdminErrorLog(
      id: _parseInt(j['id']),
      level: _readString(j['level']),
      message: _readString(j['message']),
      requestId: _readString(j['request_id'] ?? j['requestId']),
      appType: _readString(j['app_type'] ?? j['appType']),
      method: _readString(j['method']),
      url: _readString(j['url']),
      ip: _readString(j['ip']),
      exceptionClass: _readString(j['exception_class'] ?? j['exceptionClass']),
      userId: j['user_id'] == null ? null : _parseInt(j['user_id']),
      createdAt: _parseDate(j['created_at'] ?? j['createdAt']),
    );
  }
}

class AdminErrorLogResponse {
  final List<AdminErrorLog> logs;
  final int? latestId;

  const AdminErrorLogResponse({required this.logs, this.latestId});

  factory AdminErrorLogResponse.fromJson(Map<String, dynamic> j) {
    final list = (j['logs'] is List)
        ? (j['logs'] as List)
              .whereType<Map>()
              .map((e) => AdminErrorLog.fromJson(e.cast<String, dynamic>()))
              .toList()
        : <AdminErrorLog>[];
    final latest = j['latest_id'] == null ? null : _parseInt(j['latest_id']);
    return AdminErrorLogResponse(logs: list, latestId: latest);
  }
}
