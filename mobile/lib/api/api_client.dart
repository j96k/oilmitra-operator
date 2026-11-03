import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models.dart';

class ApiException implements Exception {
  ApiException(this.message, [this.statusCode]);
  final String message;
  final int? statusCode;
  @override
  String toString() => message;
}

/// One place that talks to the FastAPI server.
class Api {
  Api._();
  static final Api instance = Api._();

  static const _kBaseUrl = 'base_url';
  static const _kToken = 'token';
  static const _kUser = 'user';

  late SharedPreferences _prefs;
  String baseUrl = '';
  String? token;
  AppUser? user;

  /// Called whenever the server says our login expired.
  VoidCallback? onUnauthorized;

  /// Server address baked in at build time:
  /// flutter build apk --dart-define=API_URL=https://...
  static const _builtInUrl = String.fromEnvironment('API_URL');

  static String get defaultBaseUrl {
    if (_builtInUrl.isNotEmpty) return _builtInUrl;
    if (kIsWeb) {
      // Served by the API server itself at /app/ or /admin/ — same origin, so
      // both the supplier and operator apps talk to the API they came from.
      final path = Uri.base.path;
      if (path.startsWith('/app') || path.startsWith('/admin')) return Uri.base.origin;
      return 'http://${Uri.base.host}:8000';
    }
    if (defaultTargetPlatform == TargetPlatform.android) return 'http://10.0.2.2:8000'; // emulator -> PC
    return 'http://localhost:8000';
  }

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    baseUrl = _prefs.getString(_kBaseUrl) ?? defaultBaseUrl;
    token = _prefs.getString(_kToken);
    final u = _prefs.getString(_kUser);
    if (u != null) user = AppUser.fromJson(jsonDecode(u));
  }

  bool get isLoggedIn => token != null;

  Future<void> setBaseUrl(String url) async {
    var u = url.trim();
    if (u.isEmpty) u = defaultBaseUrl;
    if (!u.startsWith('http')) u = 'http://$u';
    while (u.endsWith('/')) {
      u = u.substring(0, u.length - 1);
    }
    baseUrl = u;
    await _prefs.setString(_kBaseUrl, u);
  }

  String imageUrl(String? path) => path == null ? '' : (path.startsWith('http') ? path : '$baseUrl$path');

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  Uri _uri(String path, [Map<String, String>? query]) => Uri.parse('$baseUrl$path').replace(queryParameters: query);

  Future<dynamic> _send(Future<http.Response> Function() call) async {
    http.Response res;
    try {
      // Long timeout: a free online server can take up to a minute to wake up.
      res = await call().timeout(const Duration(seconds: 75));
    } catch (_) {
      throw ApiException('Cannot reach the server at $baseUrl.\nCheck the server is running and the address in Settings.');
    }
    final body = res.body.isEmpty ? null : jsonDecode(utf8.decode(res.bodyBytes));
    if (res.statusCode >= 200 && res.statusCode < 300) return body;
    if (res.statusCode == 401 && token != null) {
      await logout();
      onUnauthorized?.call();
    }
    throw ApiException(_errorText(body), res.statusCode);
  }

  String _errorText(dynamic body) {
    final d = body is Map ? body['detail'] : null;
    if (d is String) return d;
    if (d is List && d.isNotEmpty) {
      final msg = (d.first['msg'] ?? 'Invalid input').toString().replaceFirst('Value error, ', '');
      final field = (d.first['loc'] as List?)?.last;
      return field is String && !msg.toLowerCase().contains(field) ? '$field: $msg' : msg;
    }
    return 'Something went wrong';
  }

  Future<dynamic> get(String path, [Map<String, String>? q]) => _send(() => http.get(_uri(path, q), headers: _headers));
  Future<dynamic> post(String path, [Object? body]) =>
      _send(() => http.post(_uri(path), headers: _headers, body: body == null ? null : jsonEncode(body)));
  Future<dynamic> put(String path, Object body) =>
      _send(() => http.put(_uri(path), headers: _headers, body: jsonEncode(body)));
  Future<dynamic> delete(String path) => _send(() => http.delete(_uri(path), headers: _headers));

  Future<dynamic> multipart(
    String method,
    String path,
    Map<String, String> fields, {
    Uint8List? imageBytes,
    String imageName = 'photo.jpg',
    String imageField = 'image',
  }) {
    return _send(() async {
      final req = http.MultipartRequest(method, _uri(path))..fields.addAll(fields);
      if (token != null) req.headers['Authorization'] = 'Bearer $token';
      if (imageBytes != null) {
        req.files.add(http.MultipartFile.fromBytes(imageField, imageBytes, filename: imageName));
      }
      return http.Response.fromStream(await req.send());
    });
  }

  // ---------------- Auth ----------------
  Future<void> _saveSession(Map<String, dynamic> j) async {
    token = j['access_token'];
    user = AppUser.fromJson(j['user']);
    await _prefs.setString(_kToken, token!);
    await _prefs.setString(_kUser, jsonEncode(j['user']));
  }

  Future<void> login(String username, String password) async =>
      _saveSession(await post('/auth/login', {'username': username, 'password': password}));

  Future<void> register({
    required String username,
    required String password,
    required String name,
    required String role,
    required String orgType,
    String? phone,
    String? city,
  }) async =>
      _saveSession(await post('/auth/register', {
        'username': username,
        'password': password,
        'name': name,
        'role': role,
        'org_type': orgType,
        'phone': phone,
        'city': city,
      }));

  Future<void> logout() async {
    token = null;
    user = null;
    await _prefs.remove(_kToken);
    await _prefs.remove(_kUser);
  }

  Future<void> refreshMe() async {
    final j = await get('/auth/me');
    user = AppUser.fromJson(j);
    await _prefs.setString(_kUser, jsonEncode(j));
  }

  Future<void> updateProfile({String? name, String? orgType, String? phone, String? city}) async {
    final j = await put('/auth/me', {
      'name': ?name,
      'org_type': ?orgType,
      'phone': ?phone,
      'city': ?city,
    });
    user = AppUser.fromJson(j);
    await _prefs.setString(_kUser, jsonEncode(j));
  }

  Future<void> uploadAvatar(Uint8List bytes, String filename) async {
    final j = await multipart('POST', '/auth/me/avatar', {}, imageBytes: bytes, imageName: filename);
    user = AppUser.fromJson(j);
    await _prefs.setString(_kUser, jsonEncode(j));
  }

  Future<bool> ping() async {
    try {
      await get('/');
      return true;
    } catch (_) {
      return false;
    }
  }

  // ---------------- Listings ----------------
  Future<List<OilListing>> listings({
    String? q,
    bool mine = false,
    bool assigned = false,
    String? status,
    String? scope,
    double? lat,
    double? lng,
  }) async {
    final list = await get('/listings', {
      if (q != null && q.isNotEmpty) 'q': q,
      if (mine) 'mine': 'true',
      if (assigned) 'assigned': 'true',
      'status': ?status,
      'scope': ?scope,
      if (lat != null) 'lat': '$lat',
      if (lng != null) 'lng': '$lng',
    }) as List;
    return list.map((e) => OilListing.fromJson(e)).toList();
  }

  Future<OilListing> listing(int id, {double? lat, double? lng}) async => OilListing.fromJson(await get(
        '/listings/$id',
        {if (lat != null) 'lat': '$lat', if (lng != null) 'lng': '$lng'},
      ));

  Future<OilListing> saveListing({
    int? id,
    required Map<String, String> fields,
    Uint8List? photoBytes,
    String? photoName,
  }) async {
    final j = await multipart(
      id == null ? 'POST' : 'PUT',
      id == null ? '/listings' : '/listings/$id',
      fields,
      imageBytes: photoBytes,
      imageName: photoName ?? 'oil.jpg',
      imageField: 'photo',
    );
    return OilListing.fromJson(j);
  }

  Future<void> deleteListing(int id) => delete('/listings/$id');

  Future<Pickup> claim(int id, {DateTime? scheduledAt, String? note}) async => Pickup.fromJson(await post(
        '/listings/$id/claim',
        {
          if (scheduledAt != null) 'scheduled_at': apiDate(scheduledAt),
          if (note != null && note.isNotEmpty) 'note': note,
        },
      ));

  Future<OilListing> release(int id) async => OilListing.fromJson(await post('/listings/$id/release'));

  Future<Pickup> collect(int id, {required double liters, required double rate, String? notes}) async =>
      Pickup.fromJson(await post('/listings/$id/collect', {
        'actual_liters': liters,
        'rate_per_liter': rate,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      }));

  Future<OilListing> cancelListing(int id) async => OilListing.fromJson(await post('/listings/$id/cancel'));

  // ---------------- Pickups / dashboard ----------------
  Future<List<Pickup>> pickups({String? status}) async {
    final list = await get('/pickups', {'status': ?status}) as List;
    return list.map((e) => Pickup.fromJson(e)).toList();
  }

  Future<Pickup> reviewPickup(int id, int rating, String? review) async =>
      Pickup.fromJson(await post('/pickups/$id/review', {'rating': rating, 'review': ?review}));

  Future<Dashboard> dashboard({double? lat, double? lng}) async => Dashboard.fromJson(await get(
        '/dashboard',
        {if (lat != null) 'lat': '$lat', if (lng != null) 'lng': '$lng'},
      ));

  Future<Impact> impact() async => Impact.fromJson(await get('/impact'));
  Future<List<LeaderRow>> leaderboard() async =>
      ((await get('/leaderboard')) as List).map((e) => LeaderRow.fromJson(e)).toList();
  Future<List<OilRate>> rates() async => ((await get('/rates')) as List).map((e) => OilRate.fromJson(e)).toList();
  Future<void> setRate(String oilType, double price) => put('/rates/$oilType', {'price_per_liter': price});

  // ---------------- Address / map ----------------
  Future<List<GeoPlace>> geoSearch(String q) async =>
      ((await get('/geo/search', {'q': q})) as List).map((e) => GeoPlace.fromJson(e)).toList();

  Future<Map<String, dynamic>> geoReverse(double lat, double lng) async =>
      await get('/geo/reverse', {'lat': '$lat', 'lng': '$lng'}) as Map<String, dynamic>;

  /// Approximate map centre for the user's city (cached). Lets the radar show
  /// useful distances without asking for phone GPS permission.
  String? _areaCity;
  LatLng? _areaCenter;

  Future<LatLng?> areaCenter(String? city) async {
    final name = (city ?? '').trim();
    if (name.isEmpty) return null;
    if (_areaCity == name && _areaCenter != null) return _areaCenter;
    try {
      final places = await geoSearch(name);
      if (places.isEmpty) return null;
      _areaCity = name;
      _areaCenter = LatLng(places.first.lat, places.first.lng);
      return _areaCenter;
    } catch (_) {
      return null;
    }
  }
}

/// The server stores local time without a timezone.
String apiDate(DateTime d) => d.toIso8601String().split('.').first;
