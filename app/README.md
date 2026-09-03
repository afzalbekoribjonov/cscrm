# CSCRM — mobil ilova (Flutter)

Xizmat biznesi (gilam yuvish, kimyoviy tozalash, kir yuvish) uchun buyurtma,
xodim va moliya boshqaruv tizimining Android/Web mijozi.

## Boshlash

```bash
flutter pub get
cp env/example.json env/dev.json    # qiymatlarni Firebase Console'dan to'ldiring
flutter run --dart-define-from-file=env/dev.json
```

Sozlamalar haqida to'liq ma'lumot: [`env/README.md`](env/README.md).

## Relizga yig'ish

```bash
flutter build apk       --release --dart-define-from-file=env/prod.json
flutter build appbundle --release --dart-define-from-file=env/prod.json
```

Imzo kalitlari `android/key.properties` faylida (git'ga tushmaydi). Fayl
bo'lmasa debug kalit bilan imzolanadi.

## Loyiha tuzilishi

Bu papka umumiy monorepo'ning bir qismi — ildizdagi
[`README.md`](../README.md) ga qarang.
