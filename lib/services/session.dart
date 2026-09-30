import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum LoginRole { user, admin }

/// Which role the person chose on the sign-in screen. Remembered on this
/// device so a page refresh keeps them in the same mode.
class Session {
  static const _key = 'login_role';
  static final ValueNotifier<LoginRole> role = ValueNotifier(LoginRole.user);

  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      role.value = LoginRole.values.asNameMap()[prefs.getString(_key)] ?? LoginRole.user;
    } catch (_) {
      // Storage can be unavailable (e.g. private browsing); default to user.
    }
  }

  static Future<void> setRole(LoginRole value) async {
    role.value = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, value.name);
    } catch (_) {}
  }
}
