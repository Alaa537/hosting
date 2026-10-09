import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';

class Store {
  static const _kToken = 'token';
  static const _kBase  = 'base_url';

  static Future<({String base, String? token})> load() async {
    final p = await SharedPreferences.getInstance();
    return (
      base: p.getString(_kBase) ?? kApiBaseDefault,
      token: p.getString(_kToken),
    );
  }

  static Future<void> saveToken(String? t) async {
    final p = await SharedPreferences.getInstance();
    if (t == null) await p.remove(_kToken);
    else await p.setString(_kToken, t);
  }

  static Future<void> saveBase(String b) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kBase, b);
  }
}
