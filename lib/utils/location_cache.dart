import 'package:shared_preferences/shared_preferences.dart';

class LocationCache {
  static String? lastSelectedLocation;
  static bool userPicked = false;
  static bool _loaded = false;

  static const String _kLocationKey = 'last_selected_location';
  static const String _kUserPickedKey = 'last_location_user_picked';

  static Future<void> load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    lastSelectedLocation = prefs.getString(_kLocationKey);
    userPicked = prefs.getBool(_kUserPickedKey) ?? false;
    _loaded = true;
  }

  static Future<void> save({
    required String? location,
    required bool isUserPicked,
  }) async {
    lastSelectedLocation = location;
    userPicked = isUserPicked;
    final prefs = await SharedPreferences.getInstance();
    if (location == null || location.trim().isEmpty) {
      await prefs.remove(_kLocationKey);
    } else {
      await prefs.setString(_kLocationKey, location);
    }
    await prefs.setBool(_kUserPickedKey, isUserPicked);
  }
}
