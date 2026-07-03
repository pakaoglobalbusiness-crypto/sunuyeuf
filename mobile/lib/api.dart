import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Client HTTP de l'API Gologui.
/// En dev web/simulateur : localhost. Sur téléphone physique, remplacer
/// par l'IP locale de la machine qui héberge l'API.
const apiBase = String.fromEnvironment(
  'API_URL',
  defaultValue: 'http://localhost:3000/api/v1',
);

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => message;
}

class Api {
  static String? _token;
  static Map<String, dynamic>? currentUser;

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('sy_token');
    final userJson = prefs.getString('sy_user');
    if (userJson != null) currentUser = jsonDecode(userJson);
  }

  static bool get isLoggedIn => _token != null;

  static Future<void> setSession(String token, Map<String, dynamic> user) async {
    _token = token;
    currentUser = user;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('sy_token', token);
    await prefs.setString('sy_user', jsonEncode(user));
  }

  static Future<void> logout() async {
    _token = null;
    currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('sy_token');
    await prefs.remove('sy_user');
  }

  static Future<dynamic> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? query,
  }) async {
    var uri = Uri.parse('$apiBase$path');
    if (query != null && query.isNotEmpty) {
      uri = uri.replace(queryParameters: {...uri.queryParameters, ...query});
    }
    final headers = {
      'Content-Type': 'application/json',
      if (_token != null) 'Authorization': 'Bearer $_token',
    };
    late http.Response res;
    try {
      switch (method) {
        case 'GET':
          res = await http.get(uri, headers: headers);
        case 'POST':
          res = await http.post(uri, headers: headers, body: jsonEncode(body ?? {}));
        case 'PATCH':
          res = await http.patch(uri, headers: headers, body: jsonEncode(body ?? {}));
      }
    } catch (_) {
      throw ApiException('Connexion impossible. Vérifiez votre réseau.');
    }
    final data = res.body.isEmpty ? {} : jsonDecode(res.body);
    if (res.statusCode >= 400) {
      final msg = data is Map ? data['message'] : null;
      throw ApiException(
        msg is List ? msg.join('\n') : (msg?.toString() ?? 'Erreur ${res.statusCode}'),
      );
    }
    return data;
  }

  /// Upload multipart d'une photo/document ; renvoie l'URL publique.
  static Future<String> uploadBytes(List<int> bytes, String filename) async {
    final req = http.MultipartRequest('POST', Uri.parse('$apiBase/uploads'));
    if (_token != null) req.headers['Authorization'] = 'Bearer $_token';
    req.files.add(http.MultipartFile.fromBytes('file', bytes, filename: filename));
    final res = await http.Response.fromStream(await req.send());
    final data = jsonDecode(res.body);
    if (res.statusCode >= 400) {
      throw ApiException(data['message']?.toString() ?? 'Échec de l’upload');
    }
    return data['url'] as String;
  }

  static Future<dynamic> get(String path, {Map<String, String>? query}) =>
      _request('GET', path, query: query);
  static Future<dynamic> post(String path, {Map<String, dynamic>? body}) =>
      _request('POST', path, body: body);
  static Future<dynamic> patch(String path, {Map<String, dynamic>? body}) =>
      _request('PATCH', path, body: body);
}

final _fcfaFormat = NumberFormat.decimalPattern('fr');
String fcfa(num n) => '${_fcfaFormat.format(n)} FCFA';

String dateFr(dynamic iso) =>
    DateFormat('d MMM yyyy', 'fr').format(DateTime.parse(iso as String));

const bookingStatusLabels = {
  'requested': 'En attente du propriétaire',
  'accepted': 'Acceptée — à payer',
  'paid': 'Payée ✓',
  'ongoing': 'En cours',
  'completed': 'Terminée',
  'cancelled': 'Annulée',
  'rejected': 'Refusée',
  'disputed': 'Litige en cours',
  'expired': 'Expirée',
};

const paymentMethodLabels = {
  'wave': 'Wave',
  'orange_money': 'Orange Money',
  'free_money': 'Free Money',
  'carte': 'Carte bancaire',
};
