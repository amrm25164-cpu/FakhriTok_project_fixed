import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class BackendApi {
  static const _baseKey = 'fakhritok_api_base_url';
  static const _tokenKey = 'fakhritok_api_token';
  static const _userKey = 'fakhritok_api_user';

  static Future<String> baseUrl() async {
    final p = await SharedPreferences.getInstance();
    return (p.getString(_baseKey) ?? 'http://10.0.2.2:8000').replaceAll(RegExp(r'/+$'), '');
  }

  static Future<void> setBaseUrl(String value) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_baseKey, value.trim().replaceAll(RegExp(r'/+$'), ''));
  }

  static Future<String?> token() async => (await SharedPreferences.getInstance()).getString(_tokenKey);
  static Future<Map<String, dynamic>?> currentUser() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_userKey);
    if (raw == null) return null;
    try { return Map<String, dynamic>.from(jsonDecode(raw)); } catch (_) { return null; }
  }

  static Future<void> _storeAuth(Map<String, dynamic> data) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_tokenKey, data['token'] as String);
    await p.setString(_userKey, jsonEncode(data['user']));
  }

  static Future<void> logout() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_tokenKey);
    await p.remove(_userKey);
  }

  static Future<Map<String, dynamic>> _jsonRequest(String method, String path, {Map<String, dynamic>? body, bool auth = false}) async {
    final root = await baseUrl();
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (auth) {
      final t = await token();
      if (t == null) throw const ApiException('سجّل الدخول أولًا.');
      headers['Authorization'] = 'Bearer $t';
    }
    final uri = Uri.parse('$root$path');
    late http.Response response;
    try {
      if (method == 'GET') {
        response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 20));
      } else if (method == 'POST') {
        response = await http.post(uri, headers: headers, body: jsonEncode(body ?? {})).timeout(const Duration(seconds: 30));
      } else if (method == 'PATCH') {
        response = await http.patch(uri, headers: headers, body: jsonEncode(body ?? {})).timeout(const Duration(seconds: 20));
      } else {
        throw const ApiException('طريقة الطلب غير مدعومة.');
      }
    } on SocketException {
      throw const ApiException('تعذر الاتصال بالخادم. تأكد من عنوان الخادم والإنترنت.');
    } on http.ClientException {
      throw const ApiException('تعذر الوصول إلى الخادم.');
    }
    dynamic decoded;
    try { decoded = jsonDecode(response.body); } catch (_) { decoded = {}; }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final code = decoded is Map ? decoded['error']?.toString() : null;
      throw ApiException(_translateError(code, response.statusCode));
    }
    return Map<String, dynamic>.from(decoded as Map);
  }

  static String _translateError(String? code, int status) {
    switch (code) {
      case 'username_or_email_already_exists': return 'اسم المستخدم أو البريد الإلكتروني مستخدم بالفعل.';
      case 'incorrect_credentials': return 'بيانات تسجيل الدخول غير صحيحة.';
      case 'authentication_required': return 'تحتاج إلى تسجيل الدخول.';
      case 'invalid_or_expired_token': return 'انتهت الجلسة، سجّل الدخول مجددًا.';
      case 'unsupported_video_type': return 'صيغة الفيديو غير مدعومة. استخدم MP4 أو MOV أو WEBM.';
      case 'video_file_required': return 'اختر فيديو أولًا.';
      default: return 'تعذر تنفيذ الطلب (HTTP $status${code == null ? '' : ': $code'}).';
    }
  }

  static Future<Map<String, dynamic>> health() => _jsonRequest('GET', '/api/health');

  static Future<Map<String, dynamic>> register({required String username, required String email, required String password}) async {
    final data = await _jsonRequest('POST', '/api/auth/register', body: {'username': username, 'email': email, 'password': password});
    await _storeAuth(data); return data;
  }
  static Future<Map<String, dynamic>> login({required String identity, required String password}) async {
    final data = await _jsonRequest('POST', '/api/auth/login', body: {'identity': identity, 'password': password});
    await _storeAuth(data); return data;
  }
  static Future<List<Map<String, dynamic>>> feed({int limit = 10}) async {
    final data = await _jsonRequest('GET', '/api/feed?limit=$limit');
    return List<Map<String, dynamic>>.from(data['items'] ?? []);
  }
  static Future<Map<String, dynamic>> uploadVideo({required String filePath, required String caption, String visibility = 'public'}) async {
    final root = await baseUrl();
    final t = await token();
    if (t == null) throw const ApiException('سجّل الدخول قبل رفع الفيديو.');
    final request = http.MultipartRequest('POST', Uri.parse('$root/api/videos'));
    request.headers['Authorization'] = 'Bearer $t';
    request.fields['caption'] = caption;
    request.fields['visibility'] = visibility;
    request.files.add(await http.MultipartFile.fromPath('video', filePath));
    final streamed = await request.send().timeout(const Duration(minutes: 5));
    final response = await http.Response.fromStream(streamed);
    dynamic decoded;
    try { decoded = jsonDecode(response.body); } catch (_) { decoded = {}; }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(_translateError(decoded is Map ? decoded['error']?.toString() : null, response.statusCode));
    }
    return Map<String, dynamic>.from(decoded['video'] as Map);
  }
  static Future<List<Map<String, dynamic>>> comments(String videoId) async {
    final data = await _jsonRequest('GET', '/api/videos/$videoId/comments');
    return List<Map<String, dynamic>>.from(data['items'] ?? []);
  }
  static Future<Map<String, dynamic>> toggleLike(String videoId) => _jsonRequest('POST', '/api/videos/$videoId/like', auth: true);
  static Future<Map<String, dynamic>> toggleSave(String videoId) => _jsonRequest('POST', '/api/videos/$videoId/save', auth: true);
  static Future<Map<String, dynamic>> addComment(String videoId, String body) => _jsonRequest('POST', '/api/videos/$videoId/comments', body: {'body': body}, auth: true);
  static Future<Map<String, dynamic>> follow(String userId) => _jsonRequest('POST', '/api/users/$userId/follow', auth: true);
  static Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    final data = await _jsonRequest('GET', '/api/users/search?q=${Uri.encodeQueryComponent(query)}');
    return List<Map<String, dynamic>>.from(data['items'] ?? []);
  }
}

class ApiException implements Exception {
  final String message;
  const ApiException(this.message);
  @override
  String toString() => message;
}
