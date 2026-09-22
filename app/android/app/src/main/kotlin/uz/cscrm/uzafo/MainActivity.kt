package uz.cscrm.uzafo

import io.flutter.embedding.android.FlutterFragmentActivity

/**
 * `FlutterActivity` EMAS, `FlutterFragmentActivity`.
 *
 * Barmoq izi so'rovini Android `BiometricPrompt` orqali ko'rsatadi, u esa
 * FragmentActivity talab qiladi. Oddiy `FlutterActivity` bilan
 * `local_auth` paketi `no_fragment_activity` xatosini tashlaydi va
 * barmoq izi HECH QACHON ishlamaydi - hech qanday oyna ham chiqmaydi.
 */
class MainActivity : FlutterFragmentActivity()
