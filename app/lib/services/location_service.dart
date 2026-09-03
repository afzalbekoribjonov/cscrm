import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

class LocationFailure implements Exception {
  LocationFailure(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Dastavchik "Olib kelish" manzilini GPS orqali saqlashi va keyinchalik
/// "Yo'lga chiqish" tugmasi bilan xaritada ochishi uchun.
class LocationService {
  Future<Position> getCurrentLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw LocationFailure(
        'Joylashuv xizmati (GPS) o\'chirilgan. Uni yoqib qayta urining.',
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw LocationFailure('Joylashuvga ruxsat berilmadi.');
    }
    if (permission == LocationPermission.deniedForever) {
      throw LocationFailure(
        'Joylashuvga ruxsat butunlay rad etilgan. Sozlamalardan yoqing.',
      );
    }

    return Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  Future<void> openDirections(double latitude, double longitude) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$latitude,$longitude',
    );
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched) {
      throw LocationFailure('Xaritani ochib bo\'lmadi.');
    }
  }
}
