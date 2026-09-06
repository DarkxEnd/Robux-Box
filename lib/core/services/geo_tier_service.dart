import 'dart:ui';

import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

import '../utils/logger.dart';

/// Works out a country code to *suggest* to the server.
///
/// The server never trusts this. `resolveTier` takes the hint only when the
/// account has no country of record yet, and pins it permanently on first
/// resolve — otherwise a user could VPN into a T1 country and multiply every
/// payout. Location permission is optional throughout: a refusal costs nothing
/// but a slightly less accurate first guess.
class GeoService {
  const GeoService();

  /// Best-effort ISO-3166 alpha-2 code, or null.
  ///
  /// Tries the cheap source first (the device's own locale) and only asks for
  /// location if that yields nothing, so most users are never prompted.
  Future<String?> detectCountryCode() async {
    final fromLocale = _fromPlatformLocale();
    if (fromLocale != null) return fromLocale;
    return _fromLocation();
  }

  String? _fromPlatformLocale() {
    // e.g. "en_US", "ar_EG.UTF-8"
    final raw = _platformLocaleName();
    final match = RegExp(r'[_-]([A-Za-z]{2})\b').firstMatch(raw);
    final code = match?.group(1)?.toUpperCase();
    return (code != null && code.length == 2) ? code : null;
  }

  /// Location is a fallback, and a silent one: any failure — permission
  /// denied, services off, no fix — returns null rather than surfacing an
  /// error, because the tier still resolves without it.
  Future<String?> _fromLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 10),
        ),
      );
      final places = await placemarkFromCoordinates(pos.latitude, pos.longitude);
      final code = places.firstOrNull?.isoCountryCode?.toUpperCase();
      return (code != null && code.length == 2) ? code : null;
    } catch (e) {
      log.w('country from location unavailable', e);
      return null;
    }
  }

  String _platformLocaleName() {
    try {
      return PlatformDispatcher.instance.locale.toString();
    } catch (_) {
      return '';
    }
  }
}
