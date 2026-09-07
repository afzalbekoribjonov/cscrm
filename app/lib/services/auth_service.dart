import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../branding/app_branding.dart';
import '../models/staff_access.dart';
import 'api_client.dart';
import 'message_center.dart';
import 'tenant_scope.dart';

class AuthFailure implements Exception {
  AuthFailure(this.message, {this.code});

  final String message;

  /// Mashina o'qiy oladigan kod — ekran maxsus holatni ajrata olishi uchun.
  final String? code;

  @override
  String toString() => message;
}

/// Bir telefon raqami bir nechta biznesga bog'langanda tanlash uchun.
class TenantChoice {
  const TenantChoice({required this.tenantId, required this.name});

  final String tenantId;
  final String name;
}

/// Kirish natijasi — sessiya shu ma'lumot asosida saqlanadi.
class SignInResult {
  const SignInResult({
    required this.tenantId,
    required this.tenantName,
    required this.userId,
    required this.displayName,
    required this.access,
    required this.isOwner,
    this.employeeId,
  });

  final String tenantId;
  final String tenantName;

  /// Firebase UID.
  final String userId;
  final String displayName;
  final StaffAccess access;
  final bool isOwner;

  /// Xodim uchun uning `/employees/{id}` kaliti. Egada `null`.
  final String? employeeId;
}

/// Autentifikatsiya.
///
/// MUHIM O'ZGARISH (eski versiyaga nisbatan): xodimning PIN-kodi endi
/// QURILMADA tekshirilmaydi. Ilgari ilova barcha xodimlarni `pinHash`
/// bilan yuklab olib, o'zi solishtirardi — natijada anonim kira olgan
/// har qanday odam hash'larni ko'chirib olib, 4 xonali PIN'ni bir necha
/// soniyada ochishi mumkin edi.
///
/// Endi telefon + PIN serverga yuboriladi, server bcrypt bilan tekshiradi
/// va Firebase custom token qaytaradi. Hash serverdan chiqmaydi.
class AuthService {
  AuthService({FirebaseAuth? auth, ApiClient? api})
      : _auth = auth ?? FirebaseAuth.instance,
        _api = api ?? ApiClient.instance;

  final FirebaseAuth _auth;
  final ApiClient _api;

  /// Login uchun ruxsat etilgan belgilar — server tomonidagi
  /// `sanitizeLogin` bilan bir xil bo'lishi shart.
  static String sanitizeLogin(String input) {
    return input.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9_-]'), '');
  }

  // ---------------------------------------------------------------------
  // Biznes ro'yxatdan o'tkazish
  // ---------------------------------------------------------------------

  /// Yangi biznes va uning egasini yaratadi.
  ///
  /// Hisob Firebase Auth'da EMAS, serverda yaratiladi — chunki tenant
  /// tuguni, litsenziya va token da'volari birgalikda qo'yilishi kerak.
  Future<SignInResult> registerBusiness({
    required String businessName,
    required String login,
    required String password,
    String? phone,
  }) async {
    try {
      final response = await _api.post(
        '/api/v1/auth/register',
        withAuth: false,
        body: {
          'businessName': businessName.trim(),
          'login': sanitizeLogin(login),
          'password': password,
          if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
        },
      );

      final token = response['customToken'] as String;
      await _auth.signOut();
      await _auth.signInWithCustomToken(token);

      final tenantId = response['tenantId'] as String;
      TenantScope.activate(TenantScope(tenantId: tenantId));

      return SignInResult(
        tenantId: tenantId,
        tenantName: businessName.trim(),
        userId: response['uid'] as String,
        displayName: sanitizeLogin(login),
        access: const StaffAccess.admin(),
        isOwner: true,
      );
    } on ApiException catch (e) {
      throw AuthFailure(e.message, code: e.code);
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_mapAuthError(e), code: e.code);
    }
  }

  // ---------------------------------------------------------------------
  // Biznes egasi kirishi
  // ---------------------------------------------------------------------

  /// Ega login + parol bilan kiradi.
  ///
  /// Parolni faqat Firebase Auth tekshira oladi (server Admin SDK bilan
  /// parolni tasdiqlay olmaydi), shuning uchun bu qadam qurilmada
  /// bajariladi. Undan keyin tokendagi `tenantId` da'vosi o'qiladi.
  Future<SignInResult> ownerSignIn({
    required String login,
    required String password,
  }) async {
    final cleanLogin = sanitizeLogin(login);
    final email = '$cleanLogin${AppBranding.authEmailDomain}';

    try {
      await _auth.signOut();
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = credential.user;
      if (user == null) {
        throw AuthFailure('Kirish amalga oshmadi. Qayta urinib ko\'ring.');
      }

      var claims = await _readClaims(user);

      // Da'volar yo'q bo'lsa (masalan hisob eski yoki qo'lda yaratilgan) —
      // serverdan tiklashni so'raymiz va tokenni MAJBURIY yangilaymiz.
      if (claims == null) {
        await _api.post('/api/v1/auth/claims/sync');
        claims = await _readClaims(user, forceRefresh: true);
      }

      if (claims == null) {
        throw AuthFailure(
          'Hisobingiz hech qanday biznesga bog\'lanmagan. '
          'Yordam xizmatiga murojaat qiling.',
          code: 'no_tenant',
        );
      }

      final tenantId = claims.tenantId;
      TenantScope.activate(TenantScope(tenantId: tenantId));

      final profileSnap =
          await TenantScope.current.ref('profile/name').get();

      return SignInResult(
        tenantId: tenantId,
        tenantName: profileSnap.value as String? ?? '',
        userId: user.uid,
        displayName: cleanLogin,
        access: const StaffAccess.admin(),
        isOwner: true,
      );
    } on ApiException catch (e) {
      throw AuthFailure(e.message, code: e.code);
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_mapAuthError(e), code: e.code);
    }
  }

  // ---------------------------------------------------------------------
  // Xodim kirishi
  // ---------------------------------------------------------------------

  /// Xodim telefon + PIN bilan kiradi.
  ///
  /// [tenantId] faqat bitta holatda kerak: bir telefon raqami bir nechta
  /// biznesga bog'langan bo'lsa. Bunday holatda server
  /// `tenant_choice_required` kodi bilan ro'yxat qaytaradi.
  Future<SignInResult> employeeSignIn({
    required String phone,
    required String pin,
    String? tenantId,
  }) async {
    try {
      final response = await _api.post(
        '/api/v1/auth/employee/login',
        withAuth: false,
        body: {
          'phone': phone.trim(),
          'pin': pin,
          if (tenantId != null) 'tenantId': tenantId,
        },
      );

      final token = response['customToken'] as String;
      await _auth.signOut();
      await _auth.signInWithCustomToken(token);

      final claims = response['claims'] as Map<String, dynamic>;
      final employee = response['employee'] as Map<String, dynamic>;
      final resolvedTenantId = claims['tenantId'] as String;

      TenantScope.activate(TenantScope(tenantId: resolvedTenantId));

      final firstName = employee['firstName'] as String? ?? '';
      final lastName = employee['lastName'] as String? ?? '';

      return SignInResult(
        tenantId: resolvedTenantId,
        tenantName: response['tenantName'] as String? ?? '',
        userId: _auth.currentUser?.uid ?? '',
        displayName: '$firstName $lastName'.trim(),
        employeeId: employee['id'] as String?,
        isOwner: false,
        access: StaffAccess.fromKeys(
          (employee['sections'] as List?)?.cast<String>() ?? const [],
          permissionKeys:
              (employee['permissions'] as List?)?.cast<String>() ?? const [],
        ),
      );
    } on ApiException catch (e) {
      if (e.code == 'tenant_choice_required') {
        throw TenantChoiceRequired(_parseChoices(e.details));
      }
      throw AuthFailure(e.message, code: e.code);
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_mapAuthError(e), code: e.code);
    }
  }

  List<TenantChoice> _parseChoices(Map<String, dynamic>? details) {
    final raw = details?['tenants'];
    if (raw is! List) return const [];
    return [
      for (final item in raw)
        if (item is Map)
          TenantChoice(
            tenantId: item['tenantId'] as String? ?? '',
            name: item['name'] as String? ?? '',
          ),
    ];
  }

  // ---------------------------------------------------------------------
  // Umumiy
  // ---------------------------------------------------------------------

  /// Boshqaruvchining login va/yoki parolini o'zgartiradi.
  ///
  /// Ikkalasi ikki xil joyda bajariladi va bu ataylab shunday:
  ///  * PAROL — Firebase Auth orqali, qurilmada. Joriy parol bilan qayta
  ///    tasdiqlanadi, shuning uchun server ishtirok etmaydi.
  ///  * LOGIN — server orqali. Login `admin_logins` indeksining kaliti,
  ///    u mijozga berk; Auth email'i ham shu logindan yasaladi va uni
  ///    faqat Admin SDK ishonchli yangilay oladi.
  Future<void> updateCredentials({
    required String currentPassword,
    String? newLogin,
    String? newPassword,
  }) async {
    final user = _auth.currentUser;
    final currentEmail = user?.email;
    if (user == null || currentEmail == null) {
      throw AuthFailure('Sessiya topilmadi. Chiqib, qaytadan kiring.');
    }
    if (newLogin == null && newPassword == null) return;

    try {
      // Har qanday o'zgarishdan oldin shaxsni tasdiqlaymiz.
      await user.reauthenticateWithCredential(
        EmailAuthProvider.credential(
          email: currentEmail,
          password: currentPassword,
        ),
      );

      if (newPassword != null) {
        await user.updatePassword(newPassword);
      }

      if (newLogin != null) {
        await _api.post(
          '/api/v1/auth/credentials/login',
          body: {'newLogin': sanitizeLogin(newLogin)},
        );
      }
    } on ApiException catch (e) {
      throw AuthFailure(e.message, code: e.code);
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_mapCredentialsError(e), code: e.code);
    }
  }

  String _mapCredentialsError(FirebaseAuthException e) {
    switch (e.code) {
      case 'wrong-password':
      case 'invalid-credential':
        return 'Joriy parol noto\'g\'ri.';
      case 'weak-password':
        return 'Yangi parol juda oddiy. Kamida 6 ta belgi kiriting.';
      case 'requires-recent-login':
        return 'Xavfsizlik uchun tizimdan chiqib, qaytadan kiring.';
      case 'too-many-requests':
        return 'Juda ko\'p urinish. Bir necha daqiqadan so\'ng urining.';
      case 'network-request-failed':
        return 'Internet aloqasini tekshiring.';
      default:
        return 'Xatolik: ${e.message ?? e.code}';
    }
  }

  Future<void> signOut() async {
    TenantScope.clear();
    // Keyingi foydalanuvchi oldingisining xabarlarini ko'rmasin.
    MessageCenter.instance.clear();
    await _auth.signOut();
  }

  /// Joriy sessiya uchun da'volarni tokendan o'qiydi — ilova qayta
  /// ochilganda tenant'ni tiklash uchun.
  Future<AppClaims?> currentClaims({bool forceRefresh = false}) async {
    final user = _auth.currentUser;
    if (user == null) return null;
    return _readClaims(user, forceRefresh: forceRefresh);
  }

  Future<AppClaims?> _readClaims(User user, {bool forceRefresh = false}) async {
    try {
      final result = await user.getIdTokenResult(forceRefresh);
      final tenantId = result.claims?['tenantId'];
      final role = result.claims?['role'];
      if (tenantId is! String || tenantId.isEmpty) return null;
      if (role is! String) return null;
      return AppClaims(
        tenantId: tenantId,
        role: role,
        employeeId: result.claims?['employeeId'] as String?,
      );
    } catch (e) {
      debugPrint('Token da\'volarini o\'qib bo\'lmadi: $e');
      return null;
    }
  }

  String _mapAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Login yoki parol noto\'g\'ri.';
      case 'invalid-email':
        return 'Login formatida xatolik bor.';
      case 'user-disabled':
        return 'Bu hisob bloklangan. Yordam xizmatiga murojaat qiling.';
      case 'too-many-requests':
        return 'Juda ko\'p urinish. Bir necha daqiqadan so\'ng urining.';
      case 'network-request-failed':
        return 'Internet aloqasini tekshiring.';
      case 'invalid-custom-token':
      case 'custom-token-mismatch':
        return 'Kirish tokeni yaroqsiz. Qayta urinib ko\'ring.';
      default:
        return 'Xatolik yuz berdi: ${e.message ?? e.code}';
    }
  }
}

/// Bir telefon bir nechta biznesga tegishli — ilova qaysi biri ekanini
/// so'rashi kerak.
class TenantChoiceRequired implements Exception {
  TenantChoiceRequired(this.choices);

  final List<TenantChoice> choices;

  @override
  String toString() =>
      'Bu raqam bir nechta biznesga bog\'langan. Qaysi biri ekanini tanlang.';
}

/// Firebase token ichidagi ilova da'volari.
class AppClaims {
  const AppClaims({
    required this.tenantId,
    required this.role,
    this.employeeId,
  });

  final String tenantId;

  /// `owner` yoki `staff`.
  final String role;
  final String? employeeId;

  bool get isOwner => role == 'owner';
}
