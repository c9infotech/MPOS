import 'package:shared_preferences/shared_preferences.dart';

import '../../models/pos_draft.dart';

class PosDraftStore {
  PosDraftStore(this._prefs);

  final SharedPreferences _prefs;
  static const _key = 'pos_drafts_v1';

  Future<List<SavedPosDraft>> load() async {
    final raw = _prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      return decodePosDraftList(raw);
    } catch (_) {
      await _prefs.remove(_key);
      return [];
    }
  }

  Future<void> save(List<SavedPosDraft> drafts) async {
    await _prefs.setString(_key, encodePosDraftList(drafts));
  }
}
