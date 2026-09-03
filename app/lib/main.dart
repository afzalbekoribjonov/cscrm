import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

import 'branding/app_branding.dart';
import 'firebase_options.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home/home_shell.dart';
import 'screens/splash/firebase_unavailable_screen.dart';
import 'screens/splash/splash_screen.dart';
import 'services/auth_service.dart';
import 'services/session_service.dart';
import 'services/tenant_scope.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';
import 'widgets/license_gate.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ThemeController.instance.load();

  Object? firebaseError;
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } on FirebaseException catch (e, st) {
    // Hot restart Dart holatini tozalaydi ("Firebase.apps" yana bo'sh
    // ko'rinadi), lekin native tarafdagi "[DEFAULT]" ilova tirik qoladi -
    // shu sabab qayta initializeApp chaqirilib "duplicate-app" chiqishi
    // mumkin. Bu haqiqiy xato emas, e'tiborsiz qoldiramiz.
    if (e.code != 'duplicate-app') {
      firebaseError = e;
      debugPrint('Firebase.initializeApp failed: $e\n$st');
    }
  } catch (e, st) {
    firebaseError = e;
    debugPrint('Firebase.initializeApp failed: $e\n$st');
  }

  if (firebaseError == null) {
    try {
      // Mahalliy kesh: ilova qayta ochilganda oxirgi ma'lumot darhol
      // ko'rinadi va tarmoq sekin bo'lsa ham ro'yxatlar bo'sh chiqmaydi.
      //
      // DIQQAT: bu yerda ilgari `ref('orders').keepSynced(true)` ham bor
      // edi - u BUTUN buyurtmalar tarixini qurilmada saqlab turardi va
      // yillar davomida o'sib borardi. Endi kesh faqat umumiy holda
      // yoqiladi; nimani sinxron saqlash kerakligini ekranlar o'zlari,
      // faol buyurtmalar so'rovi doirasida hal qiladi.
      FirebaseDatabase.instance.setPersistenceEnabled(true);
    } catch (e) {
      debugPrint('Firebase keshini yoqib bo\'lmadi (e\'tiborsiz): $e');
    }
  }

  runApp(CscrmApp(firebaseError: firebaseError));
}

class CscrmApp extends StatelessWidget {
  const CscrmApp({super.key, required this.firebaseError});

  final Object? firebaseError;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.instance,
      builder: (context, mode, _) {
        return MaterialApp(
          title: AppBranding.name,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: mode,
          home: _RootGate(firebaseError: firebaseError),
        );
      },
    );
  }
}

/// Ilova ochilganda sessiyani tiklaydi va tegishli ekranga yo'naltiradi.
///
/// Eski versiyada bu yerda `signInAnonymously()` chaqirilardi - ya'ni
/// hech kim kirmagan holatda ham Firebase sessiyasi ochilardi va
/// qoidalardagi `auth != null` sharti bajarilib qolardi. Ko'p ijarachili
/// tizimda bu qabul qilib bo'lmaydi, shuning uchun anonim kirish
/// BUTUNLAY olib tashlandi: sessiya faqat haqiqiy kirishdan keyin
/// paydo bo'ladi.
class _RootGate extends StatefulWidget {
  const _RootGate({required this.firebaseError});

  final Object? firebaseError;

  @override
  State<_RootGate> createState() => _RootGateState();
}

class _RootGateState extends State<_RootGate> {
  Widget? _resolved;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _error = widget.firebaseError;
    if (_error == null) _resolve();
  }

  Future<void> _resolve() async {
    try {
      final sessionService = SessionService();
      final session = await sessionService.loadSession();

      // Qurilmada sessiya yo'q yoki Firebase sessiyasi tugagan - login.
      if (!session.isSignedIn || FirebaseAuth.instance.currentUser == null) {
        if (session.isSignedIn) await sessionService.clearSession();
        return _show(const LoginScreen());
      }

      // Tokendagi da'volar sessiyaga mos kelishini tekshiramiz. Mos
      // kelmasa (masalan boshqaruvchi hisobni boshqa biznesga ko'chirgan
      // yoki token eskirgan) - qayta kirishni so'raymiz.
      final claims = await AuthService().currentClaims();
      if (claims == null || claims.tenantId != session.tenantId) {
        await sessionService.clearSession();
        await FirebaseAuth.instance.signOut();
        return _show(const LoginScreen());
      }

      TenantScope.activate(TenantScope(tenantId: claims.tenantId));

      _show(LicenseGate(
        tenantId: claims.tenantId,
        isOwner: session.isOwner,
        child: HomeShell(session: session),
      ));
    } catch (e, st) {
      debugPrint('Startup resolve failed: $e\n$st');
      if (mounted) setState(() => _error = e);
    }
  }

  void _show(Widget screen) {
    if (mounted) setState(() => _resolved = screen);
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return FirebaseUnavailableScreen(
        error: _error!,
        onRetry: () {
          setState(() => _error = null);
          _resolve();
        },
      );
    }
    return _resolved ?? const SplashScreen();
  }
}
