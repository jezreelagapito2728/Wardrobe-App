import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show MissingPluginException;
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

enum LocationSource { gps, ip, manual }

/// Structured address for a position.
/// (Recipient name can't come from a map lookup, the page fills it from the
/// signed-in account.)
class AddressInfo {
  final String buildingUnit; // house / building / unit no.
  final String street;
  final String barangay; // Philippines only
  final String neighborhood; // district / neighbourhood
  final String city; // city / municipality
  final String province; // state / province
  final String postalCode;
  final String country;

  const AddressInfo({
    this.buildingUnit = '',
    this.street = '',
    this.barangay = '',
    this.neighborhood = '',
    this.city = '',
    this.province = '',
    this.postalCode = '',
    this.country = '',
  });

  bool get isEmpty =>
      buildingUnit.isEmpty &&
      street.isEmpty &&
      barangay.isEmpty &&
      neighborhood.isEmpty &&
      city.isEmpty &&
      province.isEmpty &&
      postalCode.isEmpty &&
      country.isEmpty;

  static String _pick(String a, String b) => a.isNotEmpty ? a : b;

  /// Keeps our values, fills the blanks from [o].
  AddressInfo merge(AddressInfo o) => AddressInfo(
        buildingUnit: _pick(buildingUnit, o.buildingUnit),
        street: _pick(street, o.street),
        barangay: _pick(barangay, o.barangay),
        neighborhood: _pick(neighborhood, o.neighborhood),
        city: _pick(city, o.city),
        province: _pick(province, o.province),
        postalCode: _pick(postalCode, o.postalCode),
        country: _pick(country, o.country),
      );

  /// Like [merge] but only for area fields (not building / street).
  AddressInfo fillAreaFrom(AddressInfo o) => AddressInfo(
        buildingUnit: buildingUnit,
        street: street,
        barangay: _pick(barangay, o.barangay),
        neighborhood: _pick(neighborhood, o.neighborhood),
        city: _pick(city, o.city),
        province: _pick(province, o.province),
        postalCode: _pick(postalCode, o.postalCode),
        country: _pick(country, o.country),
      );

  /// Drops the district if it is just a repeat of the barangay.
  AddressInfo deduped() {
    if (barangay.isNotEmpty && neighborhood == barangay) {
      return AddressInfo(
        buildingUnit: buildingUnit,
        street: street,
        barangay: barangay,
        neighborhood: '',
        city: city,
        province: province,
        postalCode: postalCode,
        country: country,
      );
    }
    return this;
  }

  String get formatted => [
        buildingUnit,
        street,
        barangay,
        neighborhood,
        city,
        province,
        postalCode,
        country,
      ].where((e) => e.isNotEmpty).join(', ');

  Map<String, dynamic> toJson() => {
        'buildingUnit': buildingUnit,
        'street': street,
        'barangay': barangay,
        'neighborhood': neighborhood,
        'city': city,
        'province': province,
        'postalCode': postalCode,
        'country': country,
      };

  factory AddressInfo.fromJson(Map<String, dynamic> j) {
    String s(String k) => (j[k] ?? '').toString();
    return AddressInfo(
      buildingUnit: s('buildingUnit'),
      street: s('street'),
      barangay: s('barangay'),
      neighborhood: s('neighborhood'),
      city: s('city'),
      province: s('province'),
      postalCode: s('postalCode'),
      country: s('country'),
    );
  }
}

/// One result of a manual place search.
class PlaceResult {
  final String displayName;
  final double latitude;
  final double longitude;
  final AddressInfo address;

  const PlaceResult({
    required this.displayName,
    required this.latitude,
    required this.longitude,
    required this.address,
  });

  String get title {
    if (address.barangay.isNotEmpty) return address.barangay;
    if (address.street.isNotEmpty) return address.street;
    if (address.neighborhood.isNotEmpty) return address.neighborhood;
    if (address.city.isNotEmpty) return address.city;
    return displayName.split(',').first;
  }
}

/// Everything the UI needs in one object.
class WeatherData {
  final String placeName;
  final String placeDetail;
  final AddressInfo address;
  final double latitude;
  final double longitude;
  final LocationSource source;
  final String? locationNote; // why we fell back to IP location (if we did)

  final double temperatureC;
  final double feelsLikeC;
  final String description;
  final IconData icon;
  final int humidity;
  final double windKmh;
  final int weatherCode;
  final bool isDay;
  final DateTime updatedAt;

  const WeatherData({
    required this.placeName,
    required this.placeDetail,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.source,
    required this.locationNote,
    required this.temperatureC,
    required this.feelsLikeC,
    required this.description,
    required this.icon,
    required this.humidity,
    required this.windKmh,
    required this.weatherCode,
    required this.isDay,
    required this.updatedAt,
  });
}

class _GeoLocation {
  final double latitude;
  final double longitude;
  final AddressInfo address;
  final String name;
  final String detail;
  final LocationSource source;
  final String? note;

  const _GeoLocation({
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.name,
    required this.detail,
    required this.source,
    this.note,
  });
}

/// Location strategy (first match wins):
///   1. Manual location the user typed in and saved (works on every device).
///   2. Real device location (geolocator / GPS).
///   3. IP location (city-level only) if GPS is not available.
///
/// Addresses use OpenStreetMap Nominatim + BigDataCloud (free, no API key).
/// Weather comes from Open-Meteo (free, no API key).
class WeatherService {
  static const _timeout = Duration(seconds: 15);
  static const _manualKey = 'weather_manual_location';

  static Future<WeatherData> fetchCurrentWeather() async {
    final loc = await _resolveLocation();
    return _fetchWeather(loc);
  }

  // ---------------------------------------------------------------------------
  // Manual location (search + save)
  // ---------------------------------------------------------------------------
  static Future<List<PlaceResult>> searchPlaces(String query) async {
    final q = query.trim();
    if (q.isEmpty) return [];

    final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
      'q': q,
      'format': 'jsonv2',
      'addressdetails': '1',
      'limit': '8',
      'accept-language': 'en',
    });
    final res = await http.get(uri, headers: _nominatimHeaders).timeout(_timeout);
    if (res.statusCode != 200) {
      throw Exception('Search failed (${res.statusCode}). Try again.');
    }

    final list = jsonDecode(res.body) as List<dynamic>;
    final out = <PlaceResult>[];
    for (final item in list) {
      final m = (item as Map).cast<String, dynamic>();
      final lat = double.tryParse((m['lat'] ?? '').toString());
      final lon = double.tryParse((m['lon'] ?? '').toString());
      if (lat == null || lon == null) continue;
      out.add(PlaceResult(
        displayName: (m['display_name'] ?? '').toString(),
        latitude: lat,
        longitude: lon,
        address: _fromNominatimJson(m).deduped(),
      ));
    }
    return out;
  }

  /// Saves the chosen place. Weather will use it until [clearManualLocation].
  static Future<void> setManualLocation(PlaceResult r) async {
    var address = r.address;
    try {
      // Fill in barangay / city / province / postal code around that point.
      final area = await _reverseGeocode(r.latitude, r.longitude);
      address = address.fillAreaFrom(area).deduped();
    } catch (_) {}

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _manualKey,
      jsonEncode({
        'lat': r.latitude,
        'lon': r.longitude,
        'address': address.toJson(),
      }),
    );
  }

  static Future<void> clearManualLocation() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_manualKey);
  }

  static Future<_GeoLocation?> _loadManual() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_manualKey);
      if (raw == null) return null;
      final j = jsonDecode(raw) as Map<String, dynamic>;
      final address =
          AddressInfo.fromJson((j['address'] as Map).cast<String, dynamic>());
      final lat = (j['lat'] as num).toDouble();
      final lon = (j['lon'] as num).toDouble();
      final nd = _nameAndDetail(address);
      return _GeoLocation(
        latitude: lat,
        longitude: lon,
        address: address,
        name: nd.$1,
        detail: nd.$2,
        source: LocationSource.manual,
      );
    } catch (_) {
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Location resolution
  // ---------------------------------------------------------------------------
  static Future<_GeoLocation> _resolveLocation() async {
    final manual = await _loadManual();
    if (manual != null) return manual;

    String? note;
    try {
      final pos = await _gpsPosition();

      var address = const AddressInfo();
      try {
        address = await _reverseGeocode(pos.latitude, pos.longitude);
      } catch (_) {}

      final nd = _nameAndDetail(address);
      return _GeoLocation(
        latitude: pos.latitude,
        longitude: pos.longitude,
        address: address,
        name: address.isEmpty ? 'Your location' : nd.$1,
        detail: address.isEmpty
            ? '${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)}'
            : nd.$2,
        source: LocationSource.gps,
      );
    } catch (e) {
      note = _explain(e);
    }

    return _ipLocation(note);
  }

  static Future<Position> _gpsPosition() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      throw Exception('Location services are turned off on this device.');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw Exception('Location permission was denied.');
    }
    if (permission == LocationPermission.deniedForever) {
      throw Exception(
          'Location permission is permanently denied. Enable it in system settings.');
    }

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        timeLimit: Duration(seconds: 20),
      ),
    );
  }

  static String _explain(Object e) {
    if (e is MissingPluginException) {
      return 'GPS is not available in this build of the app.';
    }
    if (e is TimeoutException) {
      return 'GPS took too long to respond.';
    }
    return e.toString().replaceFirst('Exception: ', '');
  }

  static (String, String) _nameAndDetail(AddressInfo a) {
    final name = a.barangay.isNotEmpty
        ? a.barangay
        : a.neighborhood.isNotEmpty
            ? a.neighborhood
            : (a.city.isNotEmpty ? a.city : 'Your location');

    final parts = <String>[
      if (a.city.isNotEmpty && a.city != name) a.city,
      if (a.province.isNotEmpty && a.province != name && a.province != a.city)
        a.province,
      if (a.country.isNotEmpty) a.country,
    ];
    return (name, parts.join(', '));
  }

  // ---------------------------------------------------------------------------
  // Reverse geocoding (coordinates -> address, incl. barangay)
  // ---------------------------------------------------------------------------
  static Map<String, String> get _nominatimHeaders => {
        // Nominatim requires an identifying User-Agent (browsers set their own).
        if (!kIsWeb) 'User-Agent': 'ClosetMate/1.0 (Flutter wardrobe app)',
      };

  static Future<AddressInfo> _reverseGeocode(double lat, double lon) async {
    final fDetail = _nominatimReverse(lat, lon, 18);
    final fBdc = _bigDataCloud(lat, lon);
    final detailJson = await fDetail;
    final bdc = await fBdc;

    var addr = detailJson != null
        ? _fromNominatimJson(detailJson)
        : const AddressInfo();
    addr = addr.merge(bdc);

    final isPh = addr.country.toLowerCase() == 'philippines';

    // Barangay still unknown: ask Nominatim for the neighbourhood-level
    // feature at this point (zoom 14), whose name is usually the barangay.
    if (addr.barangay.isEmpty && isPh) {
      await Future.delayed(const Duration(milliseconds: 1100)); // be polite
      final area = await _nominatimReverse(lat, lon, 14);
      if (area != null) addr = addr.merge(_fromNominatimJson(area));
    }

    // Last resort: best guess from the address parts.
    if (addr.barangay.isEmpty && isPh && detailJson != null) {
      addr = addr.merge(AddressInfo(barangay: _looseBarangay(detailJson)));
    }

    return addr.deduped();
  }

  static Future<Map<String, dynamic>?> _nominatimReverse(
      double lat, double lon, int zoom) async {
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
        'format': 'jsonv2',
        'lat': lat.toString(),
        'lon': lon.toString(),
        'zoom': zoom.toString(),
        'addressdetails': '1',
        'accept-language': 'en',
      });
      final res =
          await http.get(uri, headers: _nominatimHeaders).timeout(_timeout);
      if (res.statusCode != 200) return null;
      final j = jsonDecode(res.body) as Map<String, dynamic>;
      if (j.containsKey('error')) return null;
      return j;
    } catch (_) {
      return null;
    }
  }

  static const _areaKeys = [
    'suburb',
    'quarter',
    'neighbourhood',
    'village',
    'hamlet',
    'city_district',
    'borough',
  ];

  static String _s(Map<String, dynamic> a, String k) =>
      (a[k] ?? '').toString().trim();

  static String _firstExcept(
      Map<String, dynamic> a, List<String> keys, String exclude) {
    for (final k in keys) {
      final v = _s(a, k);
      if (v.isNotEmpty && v != exclude) return v;
    }
    return '';
  }

  /// Converts one Nominatim result (search or reverse) into an [AddressInfo].
  static AddressInfo _fromNominatimJson(Map<String, dynamic> j) {
    final a = (j['address'] as Map?)?.cast<String, dynamic>() ?? {};
    final isPh = _s(a, 'country_code').toLowerCase() == 'ph';

    // ---- barangay (strict rules only)
    var barangay = '';
    if (isPh) {
      // 1) any area field that literally says "Barangay ..." / "Brgy ..."
      final re = RegExp(r'^(barangay|brgy\.?)\s', caseSensitive: false);
      for (final k in _areaKeys) {
        final v = _s(a, k);
        if (v.isNotEmpty && re.hasMatch(v)) {
          barangay = v;
          break;
        }
      }
      // 2) the result itself IS a neighbourhood-level place
      if (barangay.isEmpty) {
        final type = (j['addresstype'] ?? j['type'] ?? '').toString();
        final name = (j['name'] ?? '').toString().trim();
        const areaTypes = {'suburb', 'village', 'quarter', 'neighbourhood', 'hamlet'};
        if (name.isNotEmpty && areaTypes.contains(type)) barangay = name;
      }
    }

    final house = _firstExcept(a, ['house_number'], '');
    final building = _firstExcept(a, [
      'building',
      'amenity',
      'shop',
      'office',
      'tourism',
      'leisure',
      'man_made',
    ], '');

    return AddressInfo(
      buildingUnit: [house, building].where((e) => e.isNotEmpty).join(' '),
      street: _firstExcept(
          a, ['road', 'pedestrian', 'footway', 'path', 'residential'], ''),
      barangay: barangay,
      neighborhood: _firstExcept(a, [
        'city_district',
        'borough',
        'district',
        'quarter',
        'neighbourhood',
        'suburb',
      ], barangay),
      city: _firstExcept(
          a, ['city', 'town', 'municipality', 'village', 'county'], barangay),
      province: _firstExcept(a, ['state', 'province', 'region', 'state_district'], ''),
      postalCode: _s(a, 'postcode'),
      country: _s(a, 'country'),
    );
  }

  static String _looseBarangay(Map<String, dynamic> j) {
    final a = (j['address'] as Map?)?.cast<String, dynamic>() ?? {};
    for (final k in ['suburb', 'village', 'quarter', 'neighbourhood', 'hamlet']) {
      final v = _s(a, k);
      if (v.isNotEmpty) return v;
    }
    return '';
  }

  /// BigDataCloud: city / province / postcode fallbacks and, for the
  /// Philippines, the admin-level-10 boundary which is the barangay.
  static Future<AddressInfo> _bigDataCloud(double lat, double lon) async {
    try {
      final uri = Uri.https(
          'api.bigdatacloud.net', '/data/reverse-geocode-client', {
        'latitude': lat.toString(),
        'longitude': lon.toString(),
        'localityLanguage': 'en',
      });
      final res = await http.get(uri).timeout(_timeout);
      if (res.statusCode != 200) return const AddressInfo();

      final j = jsonDecode(res.body) as Map<String, dynamic>;
      String s(String key) => (j[key] ?? '').toString().trim();

      var barangay = '';
      if (s('countryCode').toUpperCase() == 'PH') {
        final li = j['localityInfo'];
        if (li is Map && li['administrative'] is List) {
          for (final e in li['administrative'] as List) {
            if (e is Map && e['adminLevel'] == 10) {
              barangay = (e['name'] ?? '').toString().trim();
              break;
            }
          }
        }
      }

      return AddressInfo(
        barangay: barangay,
        neighborhood: s('locality'),
        city: s('city'),
        province: s('principalSubdivision'),
        postalCode: s('postcode'),
        country: s('countryName'),
      );
    } catch (_) {
      return const AddressInfo();
    }
  }

  // ---------------------------------------------------------------------------
  // IP fallback
  // ---------------------------------------------------------------------------
  static Future<_GeoLocation> _ipLocation(String? note) async {
    try {
      final res =
          await http.get(Uri.parse('https://ipwho.is/')).timeout(_timeout);
      if (res.statusCode == 200) {
        final j = jsonDecode(res.body) as Map<String, dynamic>;
        if (j['success'] == true) {
          return _fromIp(
            lat: (j['latitude'] as num).toDouble(),
            lon: (j['longitude'] as num).toDouble(),
            city: (j['city'] ?? '').toString(),
            region: (j['region'] ?? '').toString(),
            postal: (j['postal'] ?? '').toString(),
            country: (j['country'] ?? '').toString(),
            note: note,
          );
        }
      }
    } catch (_) {}

    final res = await http
        .get(Uri.parse('https://ipapi.co/json/'))
        .timeout(_timeout);
    if (res.statusCode != 200) {
      throw Exception('Could not determine your location (${res.statusCode}).');
    }
    final j = jsonDecode(res.body) as Map<String, dynamic>;
    if (j['latitude'] == null || j['longitude'] == null) {
      throw Exception('Could not determine your location.');
    }
    return _fromIp(
      lat: (j['latitude'] as num).toDouble(),
      lon: (j['longitude'] as num).toDouble(),
      city: (j['city'] ?? '').toString(),
      region: (j['region'] ?? '').toString(),
      postal: (j['postal'] ?? '').toString(),
      country: (j['country_name'] ?? '').toString(),
      note: note,
    );
  }

  static _GeoLocation _fromIp({
    required double lat,
    required double lon,
    required String city,
    required String region,
    required String postal,
    required String country,
    required String? note,
  }) {
    final address = AddressInfo(
      city: city,
      province: region,
      postalCode: postal,
      country: country,
    );
    final nd = _nameAndDetail(address);
    return _GeoLocation(
      latitude: lat,
      longitude: lon,
      address: address,
      name: nd.$1,
      detail: nd.$2,
      source: LocationSource.ip,
      note: note,
    );
  }

  // ---------------------------------------------------------------------------
  // Weather
  // ---------------------------------------------------------------------------
  static Future<WeatherData> _fetchWeather(_GeoLocation loc) async {
    final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': loc.latitude.toString(),
      'longitude': loc.longitude.toString(),
      'current':
          'temperature_2m,apparent_temperature,relative_humidity_2m,weather_code,is_day,wind_speed_10m',
      'timezone': 'auto',
    });

    final res = await http.get(uri).timeout(_timeout);
    if (res.statusCode != 200) {
      throw Exception('Failed to load weather (${res.statusCode}).');
    }

    final j = jsonDecode(res.body) as Map<String, dynamic>;
    final cur = j['current'] as Map<String, dynamic>;
    final code = (cur['weather_code'] as num).toInt();
    final isDay = (cur['is_day'] as num).toInt() == 1;

    return WeatherData(
      placeName: loc.name,
      placeDetail: loc.detail,
      address: loc.address,
      latitude: loc.latitude,
      longitude: loc.longitude,
      source: loc.source,
      locationNote: loc.note,
      temperatureC: (cur['temperature_2m'] as num).toDouble(),
      feelsLikeC: (cur['apparent_temperature'] as num).toDouble(),
      description: _describe(code),
      icon: _iconFor(code, isDay),
      humidity: (cur['relative_humidity_2m'] as num).toInt(),
      windKmh: (cur['wind_speed_10m'] as num).toDouble(),
      weatherCode: code,
      isDay: isDay,
      updatedAt: DateTime.now(),
    );
  }

  static String _describe(int code) {
    switch (code) {
      case 0:
        return 'Clear sky';
      case 1:
        return 'Mainly clear';
      case 2:
        return 'Partly cloudy';
      case 3:
        return 'Overcast';
      case 45:
      case 48:
        return 'Foggy';
      case 51:
      case 53:
      case 55:
        return 'Drizzle';
      case 56:
      case 57:
        return 'Freezing drizzle';
      case 61:
        return 'Light rain';
      case 63:
        return 'Rain';
      case 65:
        return 'Heavy rain';
      case 66:
      case 67:
        return 'Freezing rain';
      case 71:
      case 73:
      case 75:
      case 77:
        return 'Snow';
      case 80:
      case 81:
      case 82:
        return 'Rain showers';
      case 85:
      case 86:
        return 'Snow showers';
      case 95:
        return 'Thunderstorm';
      case 96:
      case 99:
        return 'Thunderstorm with hail';
      default:
        return 'Unknown';
    }
  }

  static IconData _iconFor(int code, bool isDay) {
    if (code == 0 || code == 1) {
      return isDay ? Icons.wb_sunny : Icons.nightlight_round;
    }
    if (code == 2) return Icons.wb_cloudy;
    if (code == 3) return Icons.cloud;
    if (code == 45 || code == 48) return Icons.blur_on;
    if (code >= 51 && code <= 67) return Icons.water_drop;
    if (code >= 71 && code <= 77) return Icons.ac_unit;
    if (code >= 80 && code <= 82) return Icons.water_drop;
    if (code == 85 || code == 86) return Icons.ac_unit;
    if (code >= 95) return Icons.thunderstorm;
    return Icons.wb_sunny;
  }
}