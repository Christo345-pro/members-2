import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../models/admin_models.dart';
import '../platform/platform_features.dart';

class AdminOtpChallenge {
  final String challengeId;
  final bool pinConfigured;
  final int? expiresInSeconds;
  final int? retryAfterSeconds;
  final String? phoneMasked;

  const AdminOtpChallenge({
    required this.challengeId,
    required this.pinConfigured,
    this.expiresInSeconds,
    this.retryAfterSeconds,
    this.phoneMasked,
  });
}

class AdminService {
  static const String _baseUrl = String.fromEnvironment(
    'ADMIN_API_BASE_URL',
    defaultValue: 'https://api.weather-hooligan.co.za',
  );
  static const Duration _timeout = Duration(seconds: 30);

  static String? _token;

  static void setToken(String token) => _token = token.trim();
  static String? get token => _token;
  static bool get hasToken => (_token ?? '').trim().isNotEmpty;

  Map<String, String> _headers({
    bool jsonBody = false,
    bool requireAuth = true,
  }) {
    final t = (_token ?? '').trim();
    if (requireAuth && t.isEmpty) {
      throw Exception('No admin token set. Please login again.');
    }

    return <String, String>{
      'Accept': 'application/json',
      if (requireAuth) 'Authorization': 'Bearer $t',
      if (jsonBody) 'Content-Type': 'application/json',
    };
  }

  Future<void> loginWithPin({
    required String username,
    required String pin,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/admin/auth/login-pin');

    final res = await http
        .post(
          uri,
          headers: _headers(jsonBody: true, requireAuth: false),
          body: jsonEncode({
            'username': username.trim().toLowerCase(),
            'pin': pin.trim(),
            'app_type': adminAppType,
            'device_name': adminDeviceName,
          }),
        )
        .timeout(_timeout);

    final body = _safeJson(res.body);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(
        _extractMessage(body) ?? 'PIN login failed (${res.statusCode}).',
      );
    }

    final tok = _tokenFromBody(body);
    if (tok.isEmpty) {
      throw Exception('PIN login succeeded but token is missing.');
    }

    setToken(tok);
  }

  Future<AdminOtpChallenge> requestOtp({required String username}) async {
    final uri = Uri.parse('$_baseUrl/api/admin/auth/request-otp');

    final res = await http
        .post(
          uri,
          headers: _headers(jsonBody: true, requireAuth: false),
          body: jsonEncode({'username': username.trim().toLowerCase()}),
        )
        .timeout(_timeout);

    final body = _safeJson(res.body);

    if (res.statusCode == 429 && body is Map) {
      return AdminOtpChallenge(
        challengeId: '',
        pinConfigured: false,
        retryAfterSeconds: int.tryParse('${body['retry_after_seconds'] ?? ''}'),
      );
    }

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(
        _extractMessage(body) ?? 'OTP request failed (${res.statusCode}).',
      );
    }

    final map = body is Map
        ? body.cast<String, dynamic>()
        : <String, dynamic>{};
    final delivery = map['delivery'];
    final deliveryMap = delivery is Map
        ? delivery.cast<String, dynamic>()
        : <String, dynamic>{};

    return AdminOtpChallenge(
      challengeId: (map['challenge_id'] ?? '').toString(),
      pinConfigured: map['pin_configured'] == true,
      expiresInSeconds: int.tryParse('${map['expires_in_seconds'] ?? ''}'),
      retryAfterSeconds: int.tryParse('${map['retry_after_seconds'] ?? ''}'),
      phoneMasked: (deliveryMap['phone_masked'] ?? '').toString().trim().isEmpty
          ? null
          : (deliveryMap['phone_masked'] ?? '').toString().trim(),
    );
  }

  Future<void> verifyOtpAndSetPin({
    required String username,
    required String challengeId,
    required String otpCode,
    required String pin,
    required String pinConfirmation,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/admin/auth/verify-otp');

    final res = await http
        .post(
          uri,
          headers: _headers(jsonBody: true, requireAuth: false),
          body: jsonEncode({
            'username': username.trim().toLowerCase(),
            'challenge_id': challengeId.trim(),
            'otp_code': otpCode.trim(),
            'pin': pin.trim(),
            'pin_confirmation': pinConfirmation.trim(),
            'app_type': adminAppType,
            'device_name': adminDeviceName,
          }),
        )
        .timeout(_timeout);

    final body = _safeJson(res.body);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(
        _extractMessage(body) ?? 'OTP verification failed (${res.statusCode}).',
      );
    }

    final tok = _tokenFromBody(body);
    if (tok.isEmpty) {
      throw Exception('OTP verification succeeded but token is missing.');
    }

    setToken(tok);
  }

  Future<void> logout() async {
    if (!hasToken) return;

    final uri = Uri.parse('$_baseUrl/api/admin/auth/logout');
    final res = await http.post(uri, headers: _headers()).timeout(_timeout);

    final body = _safeJson(res.body);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(
        _extractMessage(body) ?? 'Logout failed (${res.statusCode}).',
      );
    }

    _token = null;
  }

  Future<List<AdminUser>> fetchMembers({String? query, int limit = 200}) async {
    final params = <String, String>{'limit': '$limit'};
    if ((query ?? '').trim().isNotEmpty) params['q'] = query!.trim();

    final uri = Uri.parse(
      '$_baseUrl/api/admin/users',
    ).replace(queryParameters: params);

    final res = await http.get(uri, headers: _headers()).timeout(_timeout);
    final body = _safeJson(res.body);

    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (body is List) {
        return body
            .whereType<Map>()
            .map((e) => AdminUser.fromJson(e.cast<String, dynamic>()))
            .toList();
      }
      throw Exception('Unexpected response format for members list.');
    }

    throw Exception(
      _extractMessage(body) ?? 'Failed to load members (${res.statusCode}).',
    );
  }

  Future<AdminUser> fetchMemberDetail(int id) async {
    final uri = Uri.parse('$_baseUrl/api/admin/users/$id');

    final res = await http.get(uri, headers: _headers()).timeout(_timeout);
    final body = _safeJson(res.body);

    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (body is Map<String, dynamic>) return AdminUser.fromJson(body);
      if (body is Map) return AdminUser.fromJson(body.cast<String, dynamic>());
      throw Exception('Unexpected response format for member detail.');
    }

    throw Exception(
      _extractMessage(body) ??
          'Failed to load member detail (${res.statusCode}).',
    );
  }

  Future<void> sendGeneralPush({
    required String title,
    required String body,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/admin/push/send');

    final payload = <String, dynamic>{
      'target_type': 'topic',
      'target': 'wh_general',
      'title': title.trim(),
      'body': body.trim(),
      'payload': {'type': 'general', 'source': 'members_admin'},
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

  Future<List<AdminAd>> fetchAds() async {
    final uri = Uri.parse('$_baseUrl/api/admin/ads');

    final res = await http.get(uri, headers: _headers()).timeout(_timeout);
    final body = _safeJson(res.body);

    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (body is List) {
        return body
            .whereType<Map>()
            .map((e) => AdminAd.fromJson(e.cast<String, dynamic>()))
            .toList();
      }
      throw Exception('Unexpected response format for ads list.');
    }

    throw Exception(
      _extractMessage(body) ?? 'Failed to load ads (${res.statusCode}).',
    );
  }

  Future<AdminAd> uploadAd({
    required String title,
    String? message,
    String? linkUrl,
    bool active = true,
    int? weight,
    String? startsAtIso,
    String? endsAtIso,
    required Uint8List imageBytes,
    required String imageName,
    Uint8List? smallBytes,
    String? smallName,
    required Uint8List thumbBytes,
    required String thumbName,
  }) async {
    final t = (_token ?? '').trim();
    if (t.isEmpty) throw Exception('No admin token set. Please login again.');

    if (imageBytes.isEmpty) throw Exception('Large image file is empty.');
    if (smallBytes != null && smallBytes.isEmpty) {
      throw Exception('Small web image file is empty.');
    }
    if (thumbBytes.isEmpty) throw Exception('Thumb image file is empty.');

    final uri = Uri.parse('$_baseUrl/api/admin/ads');
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

    req.files.add(
      http.MultipartFile.fromBytes('large', imageBytes, filename: imageName),
    );
    if (smallBytes != null &&
        smallName != null &&
        smallName.trim().isNotEmpty) {
      req.files.add(
        http.MultipartFile.fromBytes(
          'small',
          smallBytes,
          filename: smallName.trim(),
        ),
      );
    }
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

  Future<List<AdminInvite>> fetchInvites({
    String status = 'all',
    int limit = 200,
  }) async {
    final params = <String, String>{'status': status, 'limit': '$limit'};

    final uri = Uri.parse(
      '$_baseUrl/api/admin/invites',
    ).replace(queryParameters: params);

    final res = await http.get(uri, headers: _headers()).timeout(_timeout);
    final body = _safeJson(res.body);

    if (res.statusCode >= 200 && res.statusCode < 300) {
      final listRaw = (body is Map ? body['invites'] : null);
      if (listRaw is List) {
        return listRaw
            .whereType<Map>()
            .map((e) => AdminInvite.fromJson(e.cast<String, dynamic>()))
            .toList();
      }
      return [];
    }

    throw Exception(
      _extractMessage(body) ?? 'Failed to load invites (${res.statusCode}).',
    );
  }

  Future<AdminInvite> createInvite({
    required String name,
    required String surname,
    required String email,
    required String whatsappPhone,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/admin/invites');

    final res = await http
        .post(
          uri,
          headers: _headers(jsonBody: true),
          body: jsonEncode({
            'name': name.trim(),
            'surname': surname.trim(),
            'email': email.trim().toLowerCase(),
            'whatsapp_phone': whatsappPhone.trim(),
          }),
        )
        .timeout(_timeout);

    final body = _safeJson(res.body);

    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (body is Map && body['invite'] is Map) {
        return AdminInvite.fromJson(
          (body['invite'] as Map).cast<String, dynamic>(),
        );
      }
      throw Exception('Invite created but response payload is missing.');
    }

    throw Exception(
      _extractMessage(body) ?? 'Failed to create invite (${res.statusCode}).',
    );
  }

  Future<AdminInvite> resendInvite(int inviteId) async {
    final uri = Uri.parse('$_baseUrl/api/admin/invites/$inviteId/resend');

    final res = await http.post(uri, headers: _headers()).timeout(_timeout);
    final body = _safeJson(res.body);

    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (body is Map && body['invite'] is Map) {
        return AdminInvite.fromJson(
          (body['invite'] as Map).cast<String, dynamic>(),
        );
      }
      throw Exception('Resend succeeded but invite payload is missing.');
    }

    throw Exception(
      _extractMessage(body) ?? 'Failed to resend invite (${res.statusCode}).',
    );
  }

  Future<List<AdminInvoice>> fetchInvoices({
    int? userId,
    String status = 'all',
    int limit = 200,
  }) async {
    final params = <String, String>{'status': status, 'limit': '$limit'};
    if (userId != null && userId > 0) params['user_id'] = '$userId';

    final uri = Uri.parse(
      '$_baseUrl/api/admin/invoices',
    ).replace(queryParameters: params);

    final res = await http.get(uri, headers: _headers()).timeout(_timeout);
    final body = _safeJson(res.body);

    if (res.statusCode >= 200 && res.statusCode < 300) {
      final listRaw = (body is Map ? body['invoices'] : null);
      if (listRaw is List) {
        return listRaw
            .whereType<Map>()
            .map((e) => AdminInvoice.fromJson(e.cast<String, dynamic>()))
            .toList();
      }
      return [];
    }

    throw Exception(
      _extractMessage(body) ?? 'Failed to load invoices (${res.statusCode}).',
    );
  }

  Future<List<AdminWhatsAppCall>> fetchWhatsAppCalls({
    String adminStatus = 'all',
    String callStatus = 'all',
    String direction = 'all',
    String? query,
    int limit = 200,
  }) async {
    final params = <String, String>{
      'admin_status': adminStatus,
      'call_status': callStatus,
      'direction': direction,
      'limit': '$limit',
    };
    if ((query ?? '').trim().isNotEmpty) params['q'] = query!.trim();

    final uri = Uri.parse(
      '$_baseUrl/api/admin/whatsapp/calls',
    ).replace(queryParameters: params);

    final res = await http.get(uri, headers: _headers()).timeout(_timeout);
    final body = _safeJson(res.body);

    if (res.statusCode >= 200 && res.statusCode < 300) {
      final listRaw = (body is Map ? body['calls'] : null);
      if (listRaw is List) {
        return listRaw
            .whereType<Map>()
            .map((e) => AdminWhatsAppCall.fromJson(e.cast<String, dynamic>()))
            .toList();
      }
      return [];
    }

    throw Exception(
      _extractMessage(body) ??
          'Failed to load WhatsApp calls (${res.statusCode}).',
    );
  }

  Future<List<AdminWaConversation>> fetchWaConversations({
    String? query,
    String status = 'all',
    int limit = 200,
  }) async {
    final params = <String, String>{'status': status, 'limit': '$limit'};
    if ((query ?? '').trim().isNotEmpty) params['q'] = query!.trim();

    final uri = Uri.parse(
      '$_baseUrl/api/wa/conversations',
    ).replace(queryParameters: params);

    final res = await http.get(uri, headers: _headers()).timeout(_timeout);
    final body = _safeJson(res.body);

    if (res.statusCode >= 200 && res.statusCode < 300) {
      final listRaw = body is Map ? body['conversations'] : null;
      if (listRaw is List) {
        return listRaw
            .whereType<Map>()
            .map((e) => AdminWaConversation.fromJson(e.cast<String, dynamic>()))
            .toList();
      }
      return [];
    }

    throw Exception(
      _extractMessage(body) ??
          'Failed to load WhatsApp conversations (${res.statusCode}).',
    );
  }

  Future<List<AdminWaMessage>> fetchWaConversationMessages(
    int conversationId, {
    int limit = 500,
  }) async {
    final uri = Uri.parse(
      '$_baseUrl/api/wa/conversations/$conversationId/messages',
    ).replace(queryParameters: {'limit': '$limit'});

    final res = await http.get(uri, headers: _headers()).timeout(_timeout);
    final body = _safeJson(res.body);

    if (res.statusCode >= 200 && res.statusCode < 300) {
      final listRaw = body is Map ? body['messages'] : null;
      if (listRaw is List) {
        return listRaw
            .whereType<Map>()
            .map((e) => AdminWaMessage.fromJson(e.cast<String, dynamic>()))
            .toList();
      }
      return [];
    }

    throw Exception(
      _extractMessage(body) ??
          'Failed to load WhatsApp messages (${res.statusCode}).',
    );
  }

  Future<void> sendWaMessage({
    int? conversationId,
    String? waUser,
    required String body,
  }) async {
    final cleanBody = body.trim();
    if (cleanBody.isEmpty) {
      throw Exception('Message body is required.');
    }
    if ((conversationId ?? 0) <= 0 && (waUser ?? '').trim().isEmpty) {
      throw Exception('Provide conversationId or waUser.');
    }

    final payload = <String, dynamic>{
      'body': cleanBody,
      if ((conversationId ?? 0) > 0) 'conversation_id': conversationId,
      if ((waUser ?? '').trim().isNotEmpty) 'wa_user': waUser!.trim(),
    };

    final uri = Uri.parse('$_baseUrl/api/wa/messages/send');
    final res = await http
        .post(uri, headers: _headers(jsonBody: true), body: jsonEncode(payload))
        .timeout(_timeout);
    final resBody = _safeJson(res.body);

    if (res.statusCode >= 200 && res.statusCode < 300) return;

    throw Exception(
      _extractMessage(resBody) ??
          'Failed to send WhatsApp message (${res.statusCode}).',
    );
  }

  Future<AdminWhatsAppCall> setWhatsAppCallStatus({
    required int callId,
    required String adminStatus,
    String? adminNote,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/admin/whatsapp/calls/$callId/status');

    final payload = <String, dynamic>{
      'admin_status': adminStatus.trim().toLowerCase(),
      if (adminNote != null) 'admin_note': adminNote.trim(),
    };

    final res = await http
        .post(uri, headers: _headers(jsonBody: true), body: jsonEncode(payload))
        .timeout(_timeout);
    final body = _safeJson(res.body);

    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (body is Map && body['call'] is Map) {
        return AdminWhatsAppCall.fromJson(
          (body['call'] as Map).cast<String, dynamic>(),
        );
      }
      throw Exception('Call status updated but payload is missing.');
    }

    throw Exception(
      _extractMessage(body) ??
          'Failed to update call status (${res.statusCode}).',
    );
  }

  dynamic _safeJson(String raw) {
    if (raw.trim().isEmpty) return <String, dynamic>{};
    try {
      return jsonDecode(raw);
    } catch (_) {
      return {'message': raw};
    }
  }

  String _tokenFromBody(dynamic body) {
    if (body is Map) {
      return (body['token'] ?? '').toString().trim();
    }
    return '';
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
