import 'package:cscrm/services/app_lock_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Ilova qulfi — PIN qurilmada saqlanadi.
///
/// Bu sinovlar bitta narsani qat'iy qo'riqlaydi: PIN OCHIQ HOLDA
/// saqlanmasligi. Qolgani shundan keyin keladi.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  final lock = AppLockService.instance;

  test('boshida qulf o\'chiq', () async {
    expect(await lock.isEnabled(), isFalse);
  });

  test('PIN o\'rnatilgach qulf yoqiladi', () async {
    await lock.setPin('1234');
    expect(await lock.isEnabled(), isTrue);
  });

  test('to\'g\'ri PIN qabul qilinadi, xatosi rad etiladi', () async {
    await lock.setPin('4821');

    expect(await lock.verify('4821'), isTrue);
    expect(await lock.verify('4822'), isFalse);
    expect(await lock.verify('482'), isFalse);
    expect(await lock.verify('48210'), isFalse);
  });

  test('PIN hech qayerda OCHIQ saqlanmaydi', () async {
    // Eng muhim sinov. Qurilma ildiz huquqi bilan ochilsa,
    // sozlamalar fayli oddiy matn bo'lib o'qiladi — PIN o'sha yerda
    // ko'rinib turmasligi kerak.
    const pin = '73914';
    await lock.setPin(pin);

    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getKeys().map((k) => '${prefs.get(k)}').join('|');

    expect(stored.contains(pin), isFalse);
  });

  test('bir xil PIN har safar BOSHQA hash beradi', () async {
    // Tuz tasodifiy: ikki qurilmadagi bir xil PIN bir xil iz
    // qoldirmasligi kerak, aks holda bitta jadval bilan hammasini
    // ochib chiqish mumkin bo'lardi.
    await lock.setPin('1111');
    final prefs = await SharedPreferences.getInstance();
    final first = prefs.getString('app_lock_hash');

    await lock.setPin('1111');
    final second = prefs.getString('app_lock_hash');

    expect(first, isNotNull);
    expect(second, isNot(equals(first)));
  });

  test('o\'chirilgach hech narsa qolmaydi', () async {
    await lock.setPin('1234');
    await lock.setBiometrics(true);

    await lock.disable();

    expect(await lock.isEnabled(), isFalse);
    expect(await lock.biometricsEnabled(), isFalse);
    expect(
      await lock.verify('1234'),
      isFalse,
      reason: 'qulf o\'chirilgach eski PIN ham ishlamasligi kerak',
    );
  });

  test('barmoq izi sozlamasi saqlanadi', () async {
    await lock.setPin('1234');
    expect(await lock.biometricsEnabled(), isFalse);

    await lock.setBiometrics(true);
    expect(await lock.biometricsEnabled(), isTrue);
  });
}
