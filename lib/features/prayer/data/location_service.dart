import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/services/storage_service.dart';
import '../domain/prayer_entities.dart';

class LocationException implements Exception {
  final String message;

  const LocationException(this.message);

  @override
  String toString() => message;
}

/// GPS location with permission handling and an offline cache.
class LocationService {
  static const _cacheKey = 'last_location';

  final StorageService _storage;

  LocationService(this._storage);

  UserLocation? get cached {
    final raw = _storage.settings.get(_cacheKey);
    return raw == null ? null : UserLocation.fromMap(StorageService.asMap(raw));
  }

  Future<UserLocation> current() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationException('خدمة الموقع متوقفة. فعّل GPS لحساب المواقيت بدقة.');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw const LocationException('تم رفض إذن الموقع.');
    }
    if (permission == LocationPermission.deniedForever) {
      throw const LocationException('إذن الموقع مرفوض نهائيًا، فعّله من إعدادات الجهاز.');
    }

    Position? position;
    try {
      position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium, timeLimit: Duration(seconds: 20)),
      );
    } catch (e) {
      debugPrint('GPS fix failed, trying last known: $e');
      position = await Geolocator.getLastKnownPosition();
    }
    if (position == null) throw const LocationException('تعذر تحديد موقعك الحالي.');

    String? city;
    try {
      await setLocaleIdentifier('ar');
      final marks = await placemarkFromCoordinates(position.latitude, position.longitude);
      if (marks.isNotEmpty) {
        final m = marks.first;
        city = [m.locality, m.administrativeArea, m.country]
            .whereType<String>()
            .where((s) => s.trim().isNotEmpty)
            .take(2)
            .join('، ');
      }
    } catch (e) {
      debugPrint('Reverse geocoding failed: $e');
    }

    final location = UserLocation(latitude: position.latitude, longitude: position.longitude, city: city);
    await _storage.settings.put(_cacheKey, location.toMap());
    return location;
  }
}
