import 'package:flutter/foundation.dart';

import '../../models/customer.dart';
import '../../models/pos_draft.dart';
import '../../models/product.dart';
import '../storage/pos_draft_store.dart';

class PosDraftService extends ChangeNotifier {
  PosDraftService(this._store);

  final PosDraftStore _store;

  static const tableCount = 12;
  static const subdivisions = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';

  String? linkedDraftId;
  RestoredCart? _pendingRestore;

  Future<List<SavedPosDraft>> getAllDrafts() => _store.load();

  Future<void> saveDraft({
    required int tableNumber,
    required String subdivision,
    required List<CartLine> lines,
    required String currency,
    Customer? customer,
  }) async {
    if (lines.isEmpty) return;
    final drafts = await _store.load();
    final slot = PosDraftSlot(
      tableNumber: tableNumber,
      subdivision: subdivision,
    );
    drafts.removeWhere(
      (d) =>
          d.slot.tableNumber == tableNumber &&
          d.slot.subdivision == subdivision,
    );
    drafts.add(
      SavedPosDraft(
        id: '$tableNumber-$subdivision-${DateTime.now().millisecondsSinceEpoch}',
        slot: slot,
        lines: cloneCartLines(lines),
        currency: currency,
        savedAt: DateTime.now(),
        customer: customer?.copy(),
      ),
    );
    await _store.save(drafts);
    notifyListeners();
  }

  Future<void> removeDraft(String id) async {
    final drafts = await _store.load();
    drafts.removeWhere((d) => d.id == id);
    await _store.save(drafts);
    if (linkedDraftId == id) linkedDraftId = null;
    notifyListeners();
  }

  void requestRestore(SavedPosDraft draft) {
    linkedDraftId = draft.id;
    _pendingRestore = RestoredCart(
      lines: cloneCartLines(draft.lines),
      currency: draft.currency,
      customer: draft.customer?.copy(),
    );
    notifyListeners();
  }

  RestoredCart? takePendingRestore() {
    final pending = _pendingRestore;
    _pendingRestore = null;
    return pending;
  }

  Future<void> removeLinkedDraftAfterCheckout() async {
    final id = linkedDraftId;
    if (id == null) return;
    linkedDraftId = null;
    final drafts = await _store.load();
    drafts.removeWhere((d) => d.id == id);
    await _store.save(drafts);
    notifyListeners();
  }

  void clearLinkedDraft() {
    linkedDraftId = null;
  }
}
