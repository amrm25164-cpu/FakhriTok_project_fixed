import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class LocalStore {
  static const _likedKey = 'liked_video_ids';
  static const _savedKey = 'saved_video_ids';
  static const _followKey = 'followed_users';
  static const _commentsKey = 'comments_by_video';
  static const _usernameKey = 'fakhritok_username';

  static Future<Set<String>> getSet(String key) async {
    final p = await SharedPreferences.getInstance();
    return (p.getStringList(key) ?? <String>[]).toSet();
  }

  static Future<void> setSet(String key, Set<String> values) async {
    final p = await SharedPreferences.getInstance();
    await p.setStringList(key, values.toList());
  }

  static Future<Set<String>> liked() => getSet(_likedKey);
  static Future<void> saveLiked(Set<String> ids) => setSet(_likedKey, ids);
  static Future<Set<String>> saved() => getSet(_savedKey);
  static Future<void> saveSaved(Set<String> ids) => setSet(_savedKey, ids);
  static Future<Set<String>> followed() => getSet(_followKey);
  static Future<void> saveFollowed(Set<String> ids) => setSet(_followKey, ids);

  static Future<String> username() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_usernameKey) ?? 'fakhri_user';
  }

  static Future<void> setUsername(String value) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_usernameKey, value);
  }

  static Future<List<String>> comments(String videoId) async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_commentsKey);
    if (raw == null) return [];
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return List<String>.from(decoded[videoId] ?? []);
    } catch (_) {
      return [];
    }
  }

  static Future<void> addComment(String videoId, String comment) async {
    final p = await SharedPreferences.getInstance();
    Map<String, dynamic> decoded = {};
    try {
      decoded = jsonDecode(p.getString(_commentsKey) ?? '{}') as Map<String, dynamic>;
    } catch (_) {}
    final list = List<String>.from(decoded[videoId] ?? []);
    list.insert(0, comment);
    decoded[videoId] = list;
    await p.setString(_commentsKey, jsonEncode(decoded));
  }
}
