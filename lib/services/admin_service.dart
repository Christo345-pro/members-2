// lib/services/admin_service.dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../models/admin_models.dart';
import '../platform/platform_features.dart';

class AdminService {
  static const String _baseUrl = 'https://weather-hooligan.co.za';
  static const Duration _timeout = Duration(seconds: 25);

  static String? _token;

  static void setToken(String token) => _token = token.trim();
  static String? get token => _token;

  // ---------------------------
  // Headers
  // ---------------------------
  Map<String, String> _headers({bool jsonBody = false}) {
    final t = (_token ?? '').trim();
    if (t.isEmpty) {
      throw Exception('No admin token set. Please login again.');
    }
    return <String, String>{
      'Accept': 'application/json',
      'Authorization': 'Bearer $t',
      if (jsonBody) 'Content-Type': 'application/json',
    };
  }

  // ---------------------------
  // Auth
  // ---------------------------
  Future<String> login({
    required String email,
    required String password,
  }) async {
    final appType = adminAppType;
    final deviceName = adminDeviceName;
    final uri = Uri.parse('$_baseUrl/api/admin/login');

    final res = await http
        .post(
          uri,
          headers: const {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'email': email.trim(),
            'password': password,
            'app_type': appType,
            'device_name': deviceName,
            'force_login': true,
          }),
        )
        .timeout(_timeout);

    final body = _safeJson(res.body);

    if (res.statusCode >= 200 && res.statusCode < 300) {
      final tok = (body is Map ? body['token'] : null)?.toString().trim();
      if (tok == null || tok.isEmpty) {
        throw Exception('Login succeeded but token missing.');
      }
      setToken(tok);
      return tok;
    }

    throw Exception(
      _extractMessage(body) ?? 'Login failed (${res.statusCode}).',
    );
  }

  // ---------------------------
  // Users
  // ---------------------------
  Future<List<AdminUser>> fetchUsers() async {
    final uri = Uri.parse('$_baseUrl/api/admin/users');

    final res = await http.get(uri, headers: _headers()).timeout(_timeout);
    final body = _safeJson(res.body);

    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (body is List) {
        return body.map((e) => AdminUser.fromJson(e)).toList();
      }
      throw Exception('Unexpected response format for users list.');
    }

    throw Exception(
      _extractMessage(body) ?? 'Failed to load users (${res.statusCode}).',
    );
  }

  Future<AdminUser> fetchUserDetail(int id) async {
    final uri = Uri.parse('$_baseUrl/api/admin/users/$id');

    final res = await http.get(uri, headers: _headers()).timeout(_timeout);
    final body = _safeJson(res.body);

    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (body is Map<String, dynamic>) return AdminUser.fromJson(body);
      if (body is Map) return AdminUser.fromJson(body.cast<String, dynamic>());
      throw Exception('Unexpected response format for user detail.');
    }

    throw Exception(
      _extractMessage(body) ??
          'Failed to load user detail (${res.statusCode}).',
    );
  }

  Future<bool> toggleBlock(int id) async {
    final uri = Uri.parse('$_baseUrl/api/admin/users/$id/block');

    final res = await http.post(uri, headers: _headers()).timeout(_timeout);
    final body = _safeJson(res.body);

    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (body is Map) {
        return (body['is_blocked'] == true) ||
            (body['is_blocked']?.toString() == '1');
      }
      return false;
    }

    throw Exception(
      _extractMessage(body) ?? 'Failed to toggle block (${res.statusCode}).',
    );
  }

  // ---------------------------
  // Payments
  // ---------------------------
  Future<void> addPayment({
    required int userId,
    required double amount,
    required String reference,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/admin/users/$userId/payments');

    final res = await http
        .post(
          uri,
          headers: _headers(jsonBody: true),
          body: jsonEncode({'amount': amount, 'reference': reference.trim()}),
        )
        .timeout(_timeout);

    final body = _safeJson(res.body);

    if (res.statusCode >= 200 && res.statusCode < 300) return;

    throw Exception(
      _extractMessage(body) ?? 'Failed to add payment (${res.statusCode}).',
    );
  }

  // ---------------------------
  // Admin Tools
  // ---------------------------
  Future<AdminUser> createUser(Map<String, dynamic> payload) async {
    final uri = Uri.parse('$_baseUrl/api/admin/users');

    final res = await http
        .post(uri, headers: _headers(jsonBody: true), body: jsonEncode(payload))
        .timeout(_timeout);

    final body = _safeJson(res.body);

    if (res.statusCode == 201 ||
        (res.statusCode >= 200 && res.statusCode < 300)) {
      final u = (body is Map ? body['user'] : null);
      if (u is Map<String, dynamic>) return AdminUser.fromJson(u);
      throw Exception('User created, but response user payload missing.');
    }

    throw Exception(
      _extractMessage(body) ?? 'Failed to create user (${res.statusCode}).',
    );
  }

  Future<AdminUser> updateUser(int id, Map<String, dynamic> payload) async {
    final uri = Uri.parse('$_baseUrl/api/admin/users/$id');

    final res = await http
        .patch(
          uri,
          headers: _headers(jsonBody: true),
          body: jsonEncode(payload),
        )
        .timeout(_timeout);

    final body = _safeJson(res.body);

    if (res.statusCode >= 200 && res.statusCode < 300) {
      final u = (body is Map ? body['user'] : null);
      if (u is Map<String, dynamic>) return AdminUser.fromJson(u);

      if (body is Map && body.containsKey('id')) {
        return AdminUser.fromJson(body.cast<String, dynamic>());
      }

      throw Exception('User updated, but response payload unexpected.');
    }

    throw Exception(
      _extractMessage(body) ?? 'Failed to update user (${res.statusCode}).',
    );
  }

  Future<void> setPassword(int id, String newPassword) async {
    final uri = Uri.parse('$_baseUrl/api/admin/users/$id/password');

    final res = await http
        .post(
          uri,
          headers: _headers(jsonBody: true),
          body: jsonEncode({'password': newPassword}),
        )
        .timeout(_timeout);

    final body = _safeJson(res.body);

    if (res.statusCode >= 200 && res.statusCode < 300) return;

    throw Exception(
      _extractMessage(body) ?? 'Failed to set password (${res.statusCode}).',
    );
  }

  Future<void> revokeTokens(int id) async {
    final uri = Uri.parse('$_baseUrl/api/admin/users/$id/revoke-tokens');

    final res = await http.post(uri, headers: _headers()).timeout(_timeout);
    final body = _safeJson(res.body);

    if (res.statusCode >= 200 && res.statusCode < 300) return;

    throw Exception(
      _extractMessage(body) ?? 'Failed to revoke tokens (${res.statusCode}).',
    );
  }

  Future<void> deleteUser(int id) async {
    final uri = Uri.parse('$_baseUrl/api/admin/users/$id');

    final res = await http.delete(uri, headers: _headers()).timeout(_timeout);
    final body = _safeJson(res.body);

    if (res.statusCode >= 200 && res.statusCode < 300) return;

    throw Exception(
      _extractMessage(body) ?? 'Failed to delete user (${res.statusCode}).',
    );
  }

  // ---------------------------
  // Ads
  // ---------------------------
  Future<List<AdminAd>> fetchAds() async {
    final uri = Uri.parse('$_baseUrl/api/admin/ads');

    final res = await http.get(uri, headers: _headers()).timeout(_timeout);
    final body = _safeJson(res.body);

    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (body is List) {
        return body
            .map((e) => AdminAd.fromJson((e as Map).cast<String, dynamic>()))
            .toList();
      }
      throw Exception('Unexpected response format for ads list.');
    }

    throw Exception(
      _extractMessage(body) ?? 'Failed to load ads (${res.statusCode}).',
    );
  }

  /// ✅ Aligned with your Dashboard UI:
  /// - imageBytes/imageName = FULL (required)
  /// - thumbBytes/thumbName = THUMB (required)
  /// - weight optional
  Future<AdminAd> uploadAd({
    required String title,
    String? message,
    String? linkUrl,
    bool active = true,
    int? weight,
    String? startsAtIso,
    String? endsAtIso,
    required Uint8List imageBytes, // FULL
    required String imageName,
    required Uint8List thumbBytes, // THUMB
    required String thumbName,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/admin/ads');

    final t = (_token ?? '').trim();
    if (t.isEmpty) throw Exception('No admin token set. Please login again.');

    if (imageBytes.isEmpty) {
      throw Exception('Full image file is empty.');
    }
    if (thumbBytes.isEmpty) {
      throw Exception('Thumb image file is empty.');
    }

    final req = http.MultipartRequest('POST', uri);
    req.headers['Accept'] = 'application/json';
    req.headers['Authorization'] = 'Bearer $t';

    req.fields['title'] = title.trim();
    if ((message ?? '').trim().isNotEmpty) {
      req.fields['message'] = message!.trim();
    }
    if ((linkUrl ?? '').trim().isNotEmpty) {
      req.fields['link_url'] = linkUrl!.trim();
    }
    req.fields['active'] = active ? '1' : '0';

    if (weight != null) req.fields['weight'] = '$weight';
    if ((startsAtIso ?? '').trim().isNotEmpty) {
      req.fields['starts_at'] = startsAtIso!.trim();
    }
    if ((endsAtIso ?? '').trim().isNotEmpty) {
      req.fields['ends_at'] = endsAtIso!.trim();
    }

    // Field names must match Laravel: 'image' and 'thumb'
    req.files.add(
      http.MultipartFile.fromBytes('image', imageBytes, filename: imageName),
    );
    req.files.add(
      http.MultipartFile.fromBytes('thumb', thumbBytes, filename: thumbName),
    );

    final streamed = await req.send();
    final res = await http.Response.fromStream(streamed);
    final body = _safeJson(res.body);

    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (body is Map && body['ad'] is Map) {
        return AdminAd.fromJson((body['ad'] as Map).cast<String, dynamic>());
      }
      if (body is Map && body.containsKey('id')) {
        return AdminAd.fromJson(body.cast<String, dynamic>());
      }
      throw Exception('Upload succeeded, but response payload unexpected.');
    }

    throw Exception(
      _extractMessage(body) ?? 'Failed to upload ad (${res.statusCode}).',
    );
  }

  Future<void> deleteAd(int id) async {
    final uri = Uri.parse('$_baseUrl/api/admin/ads/$id');

    final res = await http.delete(uri, headers: _headers()).timeout(_timeout);
    final body = _safeJson(res.body);

    if (res.statusCode >= 200 && res.statusCode < 300) return;

    throw Exception(
      _extractMessage(body) ?? 'Failed to delete ad (${res.statusCode}).',
    );
  }

  // ---------------------------
  // System (Control Center)
  // ---------------------------
  Future<SystemHealth> fetchSystemHealth() async {
    final uri = Uri.parse('$_baseUrl/api/admin/system/health');

    final res = await http.get(uri, headers: _headers()).timeout(_timeout);
    final body = _safeJson(res.body);

    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (body is Map<String, dynamic>) return SystemHealth.fromJson(body);
      if (body is Map) {
        return SystemHealth.fromJson(body.cast<String, dynamic>());
      }
      throw Exception('Unexpected response format for system health.');
    }

    throw Exception(
      _extractMessage(body) ??
          'Failed to load system health (${res.statusCode}).',
    );
  }

  Future<SystemUsage> fetchSystemUsage() async {
    final uri = Uri.parse('$_baseUrl/api/admin/system/usage');

    final res = await http.get(uri, headers: _headers()).timeout(_timeout);
    final body = _safeJson(res.body);

    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (body is Map<String, dynamic>) return SystemUsage.fromJson(body);
      if (body is Map) {
        return SystemUsage.fromJson(body.cast<String, dynamic>());
      }
      throw Exception('Unexpected response format for system usage.');
    }

    throw Exception(
      _extractMessage(body) ??
          'Failed to load system usage (${res.statusCode}).',
    );
  }

  Future<SystemVisits> fetchSystemVisits() async {
    final uri = Uri.parse('$_baseUrl/api/admin/system/visits');

    final res = await http.get(uri, headers: _headers()).timeout(_timeout);
    final body = _safeJson(res.body);

    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (body is Map<String, dynamic>) return SystemVisits.fromJson(body);
      if (body is Map) {
        return SystemVisits.fromJson(body.cast<String, dynamic>());
      }
      throw Exception('Unexpected response format for system visits.');
    }

    throw Exception(
      _extractMessage(body) ??
          'Failed to load visit stats (${res.statusCode}).',
    );
  }

  // ---------------------------
  // Audit Logs (Admin)
  // ---------------------------
  Future<List<AdminAuditLog>> fetchAuditLogs({
    String? action,
    int? userId,
    DateTime? from,
    DateTime? to,
    int limit = 200,
  }) async {
    final params = <String, String>{};
    if ((action ?? '').trim().isNotEmpty) params['action'] = action!.trim();
    if (userId != null) params['user_id'] = '$userId';
    if (from != null) params['from'] = from.toIso8601String();
    if (to != null) params['to'] = to.toIso8601String();
    if (limit > 0) params['limit'] = '$limit';

    final uri = Uri.parse(
      '$_baseUrl/api/admin/audit-logs',
    ).replace(queryParameters: params.isEmpty ? null : params);

    final res = await http.get(uri, headers: _headers()).timeout(_timeout);
    final body = _safeJson(res.body);

    if (res.statusCode >= 200 && res.statusCode < 300) {
      final listRaw = (body is Map ? body['logs'] : null);
      if (listRaw is List) {
        return listRaw
            .whereType<Map>()
            .map((e) => AdminAuditLog.fromJson(e.cast<String, dynamic>()))
            .toList();
      }
      return [];
    }

    throw Exception(
      _extractMessage(body) ?? 'Failed to load audit logs (${res.statusCode}).',
    );
  }

  Future<int?> clearAuditLogs() async {
    final uri = Uri.parse('$_baseUrl/api/admin/audit-logs');

    final res = await http.delete(uri, headers: _headers()).timeout(_timeout);
    final body = _safeJson(res.body);

    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (body is Map && body['deleted'] != null) {
        return int.tryParse(body['deleted'].toString());
      }
      return null;
    }

    throw Exception(
      _extractMessage(body) ??
          'Failed to clear audit logs (${res.statusCode}).',
    );
  }

  // ---------------------------
  // Error Logs (Admin)
  // ---------------------------
  Future<AdminErrorLogResponse> fetchErrorLogs({
    String? level,
    String? url,
    String? exceptionClass,
    String? appType,
    String? method,
    String? ip,
    String? requestId,
    int? userId,
    int? sinceId,
    DateTime? from,
    DateTime? to,
    int limit = 200,
  }) async {
    final params = <String, String>{};
    if ((level ?? '').trim().isNotEmpty) params['level'] = level!.trim();
    if ((url ?? '').trim().isNotEmpty) params['url'] = url!.trim();
    if ((exceptionClass ?? '').trim().isNotEmpty) {
      params['exception_class'] = exceptionClass!.trim();
    }
    if ((appType ?? '').trim().isNotEmpty) params['app_type'] = appType!.trim();
    if ((method ?? '').trim().isNotEmpty) params['method'] = method!.trim();
    if ((ip ?? '').trim().isNotEmpty) params['ip'] = ip!.trim();
    if ((requestId ?? '').trim().isNotEmpty) {
      params['request_id'] = requestId!.trim();
    }
    if (userId != null) params['user_id'] = '$userId';
    if (sinceId != null) params['since_id'] = '$sinceId';
    if (from != null) params['from'] = from.toIso8601String();
    if (to != null) params['to'] = to.toIso8601String();
    if (limit > 0) params['limit'] = '$limit';

    final uri = Uri.parse(
      '$_baseUrl/api/admin/error-logs',
    ).replace(queryParameters: params.isEmpty ? null : params);

    final res = await http.get(uri, headers: _headers()).timeout(_timeout);
    final body = _safeJson(res.body);

    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (body is Map<String, dynamic>) {
        return AdminErrorLogResponse.fromJson(body);
      }
      if (body is Map) {
        return AdminErrorLogResponse.fromJson(body.cast<String, dynamic>());
      }
      return const AdminErrorLogResponse(logs: []);
    }

    throw Exception(
      _extractMessage(body) ?? 'Failed to load error logs (${res.statusCode}).',
    );
  }

  Future<int?> clearErrorLogs() async {
    final uri = Uri.parse('$_baseUrl/api/admin/error-logs');

    final res = await http.delete(uri, headers: _headers()).timeout(_timeout);
    final body = _safeJson(res.body);

    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (body is Map && body['deleted'] != null) {
        return int.tryParse(body['deleted'].toString());
      }
      return null;
    }

    throw Exception(
      _extractMessage(body) ??
          'Failed to clear error logs (${res.statusCode}).',
    );
  }

  // ---------------------------
  // Sessions / Licenses (Admin)
  // ---------------------------
  Future<List<AdminSession>> fetchUserSessions(int userId) async {
    final uri = Uri.parse('$_baseUrl/api/admin/users/$userId/sessions');

    final res = await http.get(uri, headers: _headers()).timeout(_timeout);
    final body = _safeJson(res.body);

    if (res.statusCode >= 200 && res.statusCode < 300) {
      final listRaw = (body is Map ? body['sessions'] : null);
      if (listRaw is List) {
        return listRaw
            .whereType<Map>()
            .map((e) => AdminSession.fromJson(e.cast<String, dynamic>()))
            .toList();
      }
      return [];
    }

    throw Exception(
      _extractMessage(body) ?? 'Failed to load sessions (${res.statusCode}).',
    );
  }

  Future<void> logoutUserByType(int userId, String appType) async {
    final uri = Uri.parse('$_baseUrl/api/admin/users/$userId/logout-by-type');

    final res = await http
        .post(
          uri,
          headers: _headers(jsonBody: true),
          body: jsonEncode({'app_type': appType}),
        )
        .timeout(_timeout);

    final body = _safeJson(res.body);
    if (res.statusCode >= 200 && res.statusCode < 300) return;

    throw Exception(
      _extractMessage(body) ??
          'Failed to revoke app sessions (${res.statusCode}).',
    );
  }

  Future<void> logoutUserByToken(int userId, int tokenId) async {
    final uri = Uri.parse('$_baseUrl/api/admin/users/$userId/logout-by-token');

    final res = await http
        .post(
          uri,
          headers: _headers(jsonBody: true),
          body: jsonEncode({'token_id': tokenId}),
        )
        .timeout(_timeout);

    final body = _safeJson(res.body);
    if (res.statusCode >= 200 && res.statusCode < 300) return;

    throw Exception(
      _extractMessage(body) ?? 'Failed to revoke session (${res.statusCode}).',
    );
  }

  Future<void> logoutUserAll(int userId) async {
    final uri = Uri.parse('$_baseUrl/api/admin/users/$userId/logout-all');

    final res = await http.post(uri, headers: _headers()).timeout(_timeout);
    final body = _safeJson(res.body);
    if (res.statusCode >= 200 && res.statusCode < 300) return;

    throw Exception(
      _extractMessage(body) ??
          'Failed to revoke all sessions (${res.statusCode}).',
    );
  }

  // ---------------------------
  // Alerts / Notices (Admin)
  // ---------------------------
  Future<List<AdminNotice>> fetchNotices({
    bool unreadOnly = false,
    int limit = 100,
  }) async {
    final uri = Uri.parse(
      '$_baseUrl/api/admin/notices?limit=$limit&unread=${unreadOnly ? '1' : '0'}',
    );

    final res = await http.get(uri, headers: _headers()).timeout(_timeout);
    final body = _safeJson(res.body);

    if (res.statusCode >= 200 && res.statusCode < 300) {
      final listRaw = (body is Map ? body['notices'] : null);
      if (listRaw is List) {
        return listRaw
            .whereType<Map>()
            .map((e) => AdminNotice.fromJson(e.cast<String, dynamic>()))
            .toList();
      }
      if (body is List) {
        return body
            .whereType<Map>()
            .map((e) => AdminNotice.fromJson(e.cast<String, dynamic>()))
            .toList();
      }
      return [];
    }

    throw Exception(
      _extractMessage(body) ?? 'Failed to load notices (${res.statusCode}).',
    );
  }

  Future<void> markNoticeRead(int id) async {
    final uri = Uri.parse('$_baseUrl/api/admin/notices/$id/read');

    final res = await http.post(uri, headers: _headers()).timeout(_timeout);
    final body = _safeJson(res.body);

    if (res.statusCode >= 200 && res.statusCode < 300) return;

    throw Exception(
      _extractMessage(body) ??
          'Failed to mark notice read (${res.statusCode}).',
    );
  }

  // ---------------------------
  // Push Notifications
  // ---------------------------
  Future<void> sendGeneralPush({
    required String title,
    required String body,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/admin/push/send');
    final payload = <String, dynamic>{
      'target_type': 'topic',
      'target': 'wh_general',
      'title': title.trim(),
      'body': body,
      'payload': {'type': 'general'},
    };

    final res = await http
        .post(uri, headers: _headers(jsonBody: true), body: jsonEncode(payload))
        .timeout(_timeout);

    final resBody = _safeJson(res.body);
    if (res.statusCode >= 200 && res.statusCode < 300) return;

    throw Exception(
      _extractMessage(resBody) ?? 'Failed to send push (${res.statusCode}).',
    );
  }

  // ---------------------------
  // Approvals (Profile changes)
  // ---------------------------
  Future<List<ProfileChangeRequest>> fetchProfileChangeRequests({
    String status = 'pending',
    int limit = 100,
  }) async {
    final uri = Uri.parse(
      '$_baseUrl/api/admin/profile-change-requests?status=$status&limit=$limit',
    );

    final res = await http.get(uri, headers: _headers()).timeout(_timeout);
    final body = _safeJson(res.body);

    if (res.statusCode >= 200 && res.statusCode < 300) {
      final listRaw = (body is Map ? body['requests'] : null);
      if (listRaw is List) {
        return listRaw
            .whereType<Map>()
            .map(
              (e) => ProfileChangeRequest.fromJson(e.cast<String, dynamic>()),
            )
            .toList();
      }
      return [];
    }

    throw Exception(
      _extractMessage(body) ??
          'Failed to load change requests (${res.statusCode}).',
    );
  }

  Future<void> approveProfileChangeRequest(int id, {String? note}) async {
    final uri = Uri.parse(
      '$_baseUrl/api/admin/profile-change-requests/$id/approve',
    );

    final res = await http
        .post(
          uri,
          headers: _headers(jsonBody: true),
          body: jsonEncode({'note': (note ?? '').trim()}),
        )
        .timeout(_timeout);
    final body = _safeJson(res.body);

    if (res.statusCode >= 200 && res.statusCode < 300) return;

    throw Exception(
      _extractMessage(body) ?? 'Failed to approve request (${res.statusCode}).',
    );
  }

  Future<void> rejectProfileChangeRequest(int id, {String? note}) async {
    final uri = Uri.parse(
      '$_baseUrl/api/admin/profile-change-requests/$id/reject',
    );

    final res = await http
        .post(
          uri,
          headers: _headers(jsonBody: true),
          body: jsonEncode({'note': (note ?? '').trim()}),
        )
        .timeout(_timeout);
    final body = _safeJson(res.body);

    if (res.statusCode >= 200 && res.statusCode < 300) return;

    throw Exception(
      _extractMessage(body) ?? 'Failed to reject request (${res.statusCode}).',
    );
  }

  // ---------------------------
  // Security verification link (Admin tool)
  // ---------------------------
  Future<void> sendSecurityVerificationLink(int userId) async {
    final uri = Uri.parse(
      '$_baseUrl/api/admin/users/$userId/security-verification-link',
    );

    final res = await http.post(uri, headers: _headers()).timeout(_timeout);
    final body = _safeJson(res.body);

    if (res.statusCode >= 200 && res.statusCode < 300) return;

    throw Exception(
      _extractMessage(body) ??
          'Failed to send security verification link (${res.statusCode}).',
    );
  }

  Future<void> sendTemporaryPassword(int userId) async {
    final uri = Uri.parse(
      '$_baseUrl/api/admin/users/$userId/temporary-password',
    );

    final res = await http.post(uri, headers: _headers()).timeout(_timeout);
    final body = _safeJson(res.body);

    if (res.statusCode >= 200 && res.statusCode < 300) return;

    throw Exception(
      _extractMessage(body) ??
          'Failed to send temporary password (${res.statusCode}).',
    );
  }

  // ---------------------------
  // Email logs (Welcome / Signup)
  // ---------------------------
  Future<int?> fetchLatestEmailLogId({
    required String type,
    required String email,
  }) async {
    final params = <String, String>{
      'type': type.trim(),
      'email': email.trim(),
      'limit': '1',
    };

    final uri = Uri.parse(
      '$_baseUrl/api/admin/email-logs',
    ).replace(queryParameters: params);

    final res = await http.get(uri, headers: _headers()).timeout(_timeout);
    final body = _safeJson(res.body);

    if (res.statusCode >= 200 && res.statusCode < 300) {
      final listRaw = (body is Map ? body['email_logs'] : null);
      if (listRaw is List && listRaw.isNotEmpty) {
        final first = listRaw.first;
        if (first is Map && first['id'] != null) {
          return int.tryParse(first['id'].toString());
        }
      }
      return null;
    }

    throw Exception(
      _extractMessage(body) ?? 'Failed to load email logs (${res.statusCode}).',
    );
  }

  Future<void> resendEmailLog(int emailLogId, {String? email}) async {
    final uri = Uri.parse('$_baseUrl/api/admin/email-logs/$emailLogId/resend');

    final payload = <String, dynamic>{};
    if ((email ?? '').trim().isNotEmpty) payload['email'] = email!.trim();

    final res = await http
        .post(uri, headers: _headers(jsonBody: true), body: jsonEncode(payload))
        .timeout(_timeout);
    final body = _safeJson(res.body);

    if (res.statusCode >= 200 && res.statusCode < 300) return;

    throw Exception(
      _extractMessage(body) ?? 'Failed to resend email (${res.statusCode}).',
    );
  }

  Future<void> generateWelcomeEmail(int userId) async {
    final uri = Uri.parse('$_baseUrl/api/admin/users/$userId/welcome-email');

    final res = await http.post(uri, headers: _headers()).timeout(_timeout);
    final body = _safeJson(res.body);

    if (res.statusCode >= 200 && res.statusCode < 300) return;

    throw Exception(
      _extractMessage(body) ??
          'Failed to generate welcome email (${res.statusCode}).',
    );
  }

  Future<List<EmailLog>> fetchEmailLogs({
    String? email,
    String? type,
    int limit = 50,
  }) async {
    final params = <String, String>{};
    if ((email ?? '').trim().isNotEmpty) params['email'] = email!.trim();
    if ((type ?? '').trim().isNotEmpty) params['type'] = type!.trim();
    if (limit > 0) params['limit'] = '$limit';

    final uri = Uri.parse(
      '$_baseUrl/api/admin/email-logs',
    ).replace(queryParameters: params.isEmpty ? null : params);

    final res = await http.get(uri, headers: _headers()).timeout(_timeout);
    final body = _safeJson(res.body);

    if (res.statusCode >= 200 && res.statusCode < 300) {
      final listRaw = (body is Map ? body['email_logs'] : null);
      if (listRaw is List) {
        return listRaw
            .whereType<Map>()
            .map((e) => EmailLog.fromJson(e.cast<String, dynamic>()))
            .toList();
      }
      return [];
    }

    throw Exception(
      _extractMessage(body) ?? 'Failed to load email logs (${res.statusCode}).',
    );
  }

  // ---------------------------
  // Helpers
  // ---------------------------
  dynamic _safeJson(String raw) {
    if (raw.trim().isEmpty) return {};
    try {
      return jsonDecode(raw);
    } catch (_) {
      return {'message': raw};
    }
  }

  String? _extractMessage(dynamic body) {
    if (body is Map) {
      if (body['message'] != null) return body['message'].toString();
      if (body['error'] != null) return body['error'].toString();
      if (body['errors'] is Map) {
        final errs = body['errors'] as Map;
        if (errs.isNotEmpty) {
          final firstKey = errs.keys.first;
          final v = errs[firstKey];
          if (v is List && v.isNotEmpty) return v.first.toString();
          return v.toString();
        }
      }
    }
    return null;
  }
}
