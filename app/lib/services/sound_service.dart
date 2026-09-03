import 'package:audioplayers/audioplayers.dart';

/// Yangi/o'zgargan buyurtma haqida ilova ochiq bo'lganda ovozli signal
/// beradi (Firebase real-time listener orqali chaqiriladi).
class SoundService {
  SoundService._();
  static final SoundService instance = SoundService._();

  final AudioPlayer _player = AudioPlayer();

  Future<void> playNotification() async {
    try {
      await _player.stop();
      await _player.play(AssetSource('sounds/notification.mp3'));
    } catch (_) {
      // Ovoz chalinmasa ham ilova ishlayvergani muhim - xatolikni yutamiz.
    }
  }
}
