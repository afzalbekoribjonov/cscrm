# Flutter / Firebase uchun zarur saqlash qoidalari.
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# Firebase model sinflari reflection orqali o'qiladi.
-keepattributes Signature
-keepattributes *Annotation*
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# Play Core (Flutter deferred components) - ishlatilmasa ham ogohlantirmasin.
-dontwarn com.google.android.play.core.**
