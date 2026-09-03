// CSCRM Firebase konfiguratsiyasi.
//
// MUHIM: bu faylda HECH QANDAY kalit qattiq yozilmagan. Barcha qiymatlar
// build vaqtida `--dart-define-from-file` orqali beriladi:
//
//   flutter run  --dart-define-from-file=env/dev.json
//   flutter build apk --release --dart-define-from-file=env/prod.json
//
// Namuna fayl: `env/example.json`. Haqiqiy `env/*.json` fayllari git'ga
// tushmaydi (.gitignore). Shu sabab kalitlar repoda saqlanmaydi va loyiha
// boshqa Firebase hisobiga bir fayl almashtirish bilan ko'chiriladi.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Konfiguratsiya to'liq berilmaganida tashlanadi - ilova buni ushlab
/// foydalanuvchiga tushunarli ekran ko'rsatadi (jim ishlamay qolish emas).
class FirebaseConfigMissing implements Exception {
  const FirebaseConfigMissing(this.missingKeys);

  final List<String> missingKeys;

  @override
  String toString() =>
      'Firebase sozlamalari to\'liq emas. Yetishmayotgan qiymatlar: '
      '${missingKeys.join(', ')}. `--dart-define-from-file=env/prod.json` '
      'bilan ishga tushiring (namuna: env/example.json).';
}

class DefaultFirebaseOptions {
  // --- Umumiy (barcha platformalar uchun bir xil) ---
  static const _projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const _databaseUrl = String.fromEnvironment('FIREBASE_DATABASE_URL');
  static const _storageBucket =
      String.fromEnvironment('FIREBASE_STORAGE_BUCKET');
  static const _messagingSenderId =
      String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');

  // --- Android ---
  static const _androidApiKey =
      String.fromEnvironment('FIREBASE_ANDROID_API_KEY');
  static const _androidAppId = String.fromEnvironment('FIREBASE_ANDROID_APP_ID');

  // --- Web ---
  static const _webApiKey = String.fromEnvironment('FIREBASE_WEB_API_KEY');
  static const _webAppId = String.fromEnvironment('FIREBASE_WEB_APP_ID');
  static const _webAuthDomain =
      String.fromEnvironment('FIREBASE_WEB_AUTH_DOMAIN');

  /// Sozlamalar berilganmi - splash ekrani shu orqali tekshiradi.
  static bool get isConfigured => missingKeys().isEmpty;

  /// Joriy platforma uchun yetishmayotgan kalitlar ro'yxati.
  static List<String> missingKeys() {
    final missing = <String>[
      if (_projectId.isEmpty) 'FIREBASE_PROJECT_ID',
      if (_databaseUrl.isEmpty) 'FIREBASE_DATABASE_URL',
      if (_messagingSenderId.isEmpty) 'FIREBASE_MESSAGING_SENDER_ID',
    ];
    if (kIsWeb) {
      if (_webApiKey.isEmpty) missing.add('FIREBASE_WEB_API_KEY');
      if (_webAppId.isEmpty) missing.add('FIREBASE_WEB_APP_ID');
    } else {
      if (_androidApiKey.isEmpty) missing.add('FIREBASE_ANDROID_API_KEY');
      if (_androidAppId.isEmpty) missing.add('FIREBASE_ANDROID_APP_ID');
    }
    return missing;
  }

  static FirebaseOptions get currentPlatform {
    final missing = missingKeys();
    if (missing.isNotEmpty) throw FirebaseConfigMissing(missing);

    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError(
          'CSCRM hozircha faqat Android va Web uchun sozlangan. '
          '${defaultTargetPlatform.name} uchun `flutterfire configure` '
          'orqali qo\'shimcha sozlama kerak.',
        );
    }
  }

  static FirebaseOptions get android => FirebaseOptions(
        apiKey: _androidApiKey,
        appId: _androidAppId,
        messagingSenderId: _messagingSenderId,
        projectId: _projectId,
        databaseURL: _databaseUrl,
        storageBucket: _storageBucket,
      );

  static FirebaseOptions get web => FirebaseOptions(
        apiKey: _webApiKey,
        appId: _webAppId,
        messagingSenderId: _messagingSenderId,
        projectId: _projectId,
        databaseURL: _databaseUrl,
        storageBucket: _storageBucket,
        authDomain: _webAuthDomain.isEmpty
            ? '$_projectId.firebaseapp.com'
            : _webAuthDomain,
      );
}
