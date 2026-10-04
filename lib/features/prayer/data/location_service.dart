import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/services/storage_service.dart';
import '../domain/prayer_entities.dart';
import 'web_geo.dart';

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
    if (kIsWeb) return _webCurrent();
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
      position = kIsWeb ? null : await Geolocator.getLastKnownPosition();
    }
    if (position == null) throw const LocationException('تعذر تحديد موقعك الحالي.');

    String? city;
    if (kIsWeb) {
      city = await _webCity(position.latitude, position.longitude);
    } else {
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
    }

    final location = UserLocation(latitude: position.latitude, longitude: position.longitude, city: city);
    await _storage.settings.put(_cacheKey, location.toMap());
    return location;
  }

  /// City name in the browser (the geocoding plugin is phone-only): a free
  /// reverse-geocoding service that allows calls from web pages.
  Future<String?> _webCity(double lat, double lng) async {
    try {
      final res = await Dio(BaseOptions(connectTimeout: const Duration(seconds: 10))).get<Map<String, dynamic>>(
        'https://api.bigdatacloud.net/data/reverse-geocode-client',
        queryParameters: {'latitude': lat, 'longitude': lng, 'localityLanguage': 'ar'},
      );
      final d = res.data ?? const {};
      final parts = [d['city'], d['locality'], d['principalSubdivision'], d['countryName']]
          .whereType<String>()
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toSet()
          .take(2)
          .toList();
      return parts.isEmpty ? null : parts.join('، ');
    } catch (e) {
      debugPrint('Web reverse geocoding failed: $e');
      return null;
    }
  }

  /// Browser: the device location, or (if the browser can't or won't give it)
  /// the approximate city of the internet connection, so prayer times always
  /// show. The approximate one is replaced whenever a real fix comes later.
  Future<UserLocation> _webCurrent() async {
    late double lat, lng;
    String? city;
    var approximate = false;
    try {
      final p = await browserPosition();
      lat = p.lat;
      lng = p.lng;
    } catch (e) {
      debugPrint('Browser location failed: $e');
      final ip = await _ipLocation();
      if (ip == null) {
        if (e == 1) {
          throw const LocationException('تم رفض إذن الموقع. اسمح للمتصفح بالموقع من إعداداته ثم أعد المحاولة.');
        }
        throw const LocationException('تعذر تحديد موقعك الحالي.');
      }
      (lat, lng, city) = ip;
      approximate = true;
    }
    city ??= await _webCity(lat, lng);
    if (approximate && city != null) city = '$city (تقريبي)';
    final location = UserLocation(latitude: lat, longitude: lng, city: city);
    await _storage.settings.put(_cacheKey, location.toMap());
    return location;
  }

  /// City-level location from the connection's IP (no permission needed).
  Future<(double, double, String?)?> _ipLocation() async {
    try {
      final res = await Dio(BaseOptions(connectTimeout: const Duration(seconds: 8)))
          .get<Map<String, dynamic>>('https://get.geojs.io/v1/ip/geo.json');
      final d = res.data ?? const {};
      final lat = double.tryParse('${d['latitude']}');
      final lng = double.tryParse('${d['longitude']}');
      if (lat == null || lng == null) return null;
      return (lat, lng, null);
    } catch (e) {
      debugPrint('IP location failed: $e');
      return null;
    }
  }
}
