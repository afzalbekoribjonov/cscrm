import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';

/// Serverdan kelgan, foydalanuvchiga ko'rsatish mumkin bo'lgan xatolik.
class ApiException implements Exception {
  ApiException(this.message, {this.code, this.status, this.details});

  final String message;

  /// Mashina o'qiy oladigan kod — masalan `tenant_choice_required`.
  final String? code;
  final int? status;
  final Map<String, dynamic>? details;

  @override
  String toString() => message;
}

/// CSCRM API bilan aloqa.
///
/// Har bir so'rovga joriy foydalanuvchining Firebase ID token'i qo'shiladi
/// (mavjud bo'lsa) — server aynan shu token orqali kim so'rayotganini va
/// qaysi biznesga tegishli ekanini biladi.
class ApiClient {
  ApiClient({http.Client? httpClient, FirebaseAuth? auth})
      : _http = httpClient ?? http.Client(),
        _authOverride = auth;

  final http.Client _http;

  /// Testda almashtirish uchun. Odatda `null`.
  final FirebaseAuth? _authOverride;

  /// `FirebaseAuth.instance` ga murojaat DANGASA qilinadi.
  ///
  /// Konstruktorda chaqirilsa, Firebase hali ishga tushmagan muhitda
  /// (masalan vidjet testlarida) obyekt yaratishning o'ziyoq yiqilardi —
  /// hatto avtorizatsiya kerak bo'lmagan so'rovlar uchun ham.
  FirebaseAuth get _auth => _authOverride ?? FirebaseAuth.instance;

  static final ApiClient instance = ApiClient();

  Uri _uri(String path) => Uri.parse('${AppConfig.apiBaseUrl}$path');

  Future<Map<String, String>> _headers({bool withAuth = true}) async {
    final headers = <String, String>{'content-type': 'application/json'};
    if (!withAuth) return headers;

    final user = _auth.currentUser;
    if (user != null) {
      try {
        final token = await user.getIdToken();
        if (token != null) headers['authorization'] = 'Bearer $token';
      } catch (e) {
        // Token olinmasa so'rovni baribir yuboramiz — server 401 qaytaradi
        // va chaqiruvchi buni to'g'ri ishlaydi.
        debugPrint('ID token olinmadi: $e');
      }
    }
    return headers;
  }

  Future<Map<String, dynamic>> get(String path, {bool withAuth = true}) {
    return _send(() async => _http.get(
          _uri(path),
          headers: await _headers(withAuth: withAuth),
        ));
  }

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, Object?> body = const {},
    bool withAuth = true,
  }) {
    return _send(() async => _http.post(
          _uri(path),
          headers: await _headers(withAuth: withAuth),
          body: jsonEncode(body),
        ));
  }

  Future<Map<String, dynamic>> delete(String path) {
    return _send(() async => _http.delete(
          _uri(path),
          headers: await _headers(),
        ));
  }

  Future<Map<String, dynamic>> _send(
    Future<http.Response> Function() request,
  ) async {
    if (!AppConfig.hasApi) {
      throw ApiException(
        'Server manzili sozlanmagan. `API_BASE_URL` qiymatini bering.',
        code: 'no_api_url',
      );
    }

    http.Response response;
    try {
      response = await request().timeout(AppConfig.requestTimeout);
    } on TimeoutException {
      throw ApiException(
        'Server javob bermadi. Internet aloqasini tekshirib, qayta urining.',
        code: 'timeout',
      );
    } catch (e) {
      debugPrint('API so\'rovi uzildi: $e');
      throw ApiException(
        'Serverga ulanib bo\'lmadi. Internet aloqasini tekshiring.',
        code: 'network',
      );
    }

    Map<String, dynamic> json;
    try {
      final decoded = jsonDecode(response.body);
      json = decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    } catch (_) {
      // Server HTML yoki bo'sh javob qaytardi (masalan proxy xatosi).
      throw ApiException(
        'Serverdan tushunarsiz javob keldi (${response.statusCode}).',
        status: response.statusCode,
      );
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return json;
    }

    final error = json['error'];
    if (error is Map) {
      throw ApiException(
        error['message'] as String? ?? 'Xatolik yuz berdi.',
        code: error['code'] as String?,
        status: response.statusCode,
        details: error['details'] is Map
            ? Map<String, dynamic>.from(error['details'] as Map)
            : null,
      );
    }
    throw ApiException(
      'Xatolik yuz berdi (${response.statusCode}).',
      status: response.statusCode,
    );
  }
}
