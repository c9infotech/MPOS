import 'package:flutter/foundation.dart';

import '../api/pos_repository.dart';
import '../../models/customer.dart';
import '../../models/pos_draft.dart';
import '../../models/product.dart';

class PosDraftService extends ChangeNotifier {
  PosDraftService(this._repository);

  final PosRepository _repository;

  static const tableCount = 30;
  static const subdivisions = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';

  String? linkedDraftId;
  RestoredCart? _pendingRestore;

  /// Each InsertDraft stays as its own card on the Draft page.
  Future<List<SavedPosDraft>> getAllDrafts() async {
    final drafts = await _repository.fetchDrafts();
    for (final draft in drafts) {
      draft.lines.sort((a, b) {
        if (a.isDelivered == b.isDelivered) return 0;
        return a.isDelivered ? -1 : 1;
      });
    }
    drafts.sort((a, b) {
      final aDelivered = a.lines.any((l) => l.isDelivered);
      final bDelivered = b.lines.any((l) => l.isDelivered);
      if (aDelivered != bDelivered) return aDelivered ? -1 : 1;
      return b.savedAt.compareTo(a.savedAt);
    });
    return drafts;
  }

  Future<void> saveDraft({
    required int tableNumber,
    required String subdivision,
    required List<CartLine> lines,
    required String currency,
    Customer? customer,
  }) async {
    if (lines.isEmpty) return;
    // Each cart line = its own draft card on the Draft page.
    final cloned = cloneCartLines(lines);
    for (final line in cloned) {
      await _repository.insertDraft(
        tableNumber: tableNumber,
        subdivision: subdivision,
        lines: [line],
        currency: currency,
        customer: customer,
      );
    }
    notifyListeners();
  }

  Future<void> removeDraft(String id) async {
    await _repository.deleteDraft(id);
    if (linkedDraftId == id) linkedDraftId = null;
    notifyListeners();
  }

  void requestRestore(SavedPosDraft draft) {
    linkedDraftId = draft.id;
    final deliveredLines = draft.lines.where((line) => line.isDelivered).toList();
    _pendingRestore = RestoredCart(
      lines: cloneCartLines(deliveredLines),
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
    await _repository.deleteDraft(id);
    notifyListeners();
  }

  /// Mark this draft's pending lines delivered.
  /// If another draft for same table/subdivision already has the same item
  /// delivered, merge qty into that delivered line and remove this draft.
  Future<void> markLinesDelivered({
    required SavedPosDraft draft,
    required Set<int> lineIndexes,
  }) async {
    if (lineIndexes.isEmpty) return;

    final cloned = cloneCartLines(draft.lines);
    for (final index in lineIndexes) {
      if (index < 0 || index >= cloned.length) continue;
      cloned[index].isDelivered = true;
    }

    final allDrafts = await _repository.fetchDrafts();
    final others = allDrafts
        .where(
          (d) =>
              d.id != draft.id &&
              d.slot.tableNumber == draft.slot.tableNumber &&
              d.slot.subdivision == draft.slot.subdivision,
        )
        .toList();

    // Find existing delivered draft(s) for same table/subdivision to merge into.
    SavedPosDraft? targetDelivered;
    for (final other in others) {
      if (other.lines.any((l) => l.isDelivered)) {
        targetDelivered = other;
        break;
      }
    }

    if (targetDelivered != null) {
      final targetLines = cloneCartLines(targetDelivered.lines);
      // Move newly delivered lines into target; keep undelivered on current draft.
      final stillPending = <CartLine>[];
      for (final line in cloned) {
        if (line.isDelivered) {
          targetLines.add(line);
        } else {
          stillPending.add(line);
        }
      }
      final mergedTarget = _mergeDeliveredLines(targetLines);

      await _repository.deleteDraft(targetDelivered.id);
      await _repository.insertDraft(
        tableNumber: draft.slot.tableNumber,
        subdivision: draft.slot.subdivision,
        lines: mergedTarget,
        currency: draft.currency,
        customer: draft.customer ?? targetDelivered.customer,
      );

      await _repository.deleteDraft(draft.id);
      if (stillPending.isNotEmpty) {
        await _repository.insertDraft(
          tableNumber: draft.slot.tableNumber,
          subdivision: draft.slot.subdivision,
          lines: stillPending,
          currency: draft.currency,
          customer: draft.customer,
        );
      }
    } else {
      final merged = _mergeDeliveredLines(cloned);
      await _repository.deleteDraft(draft.id);
      await _repository.insertDraft(
        tableNumber: draft.slot.tableNumber,
        subdivision: draft.slot.subdivision,
        lines: merged,
        currency: draft.currency,
        customer: draft.customer,
      );
    }

    if (linkedDraftId == draft.id) linkedDraftId = null;
    notifyListeners();
  }

  void clearLinkedDraft() {
    linkedDraftId = null;
  }

  /// Only merges delivered lines with the same item (+ UoM). Pending stay separate.
  List<CartLine> _mergeDeliveredLines(List<CartLine> lines) {
    final delivered = <String, CartLine>{};
    final undelivered = <CartLine>[];
    for (final line in lines) {
      if (!line.isDelivered) {
        undelivered.add(line);
        continue;
      }
      final key = '${line.product.itemCode}|${line.cartUom}';
      final existing = delivered[key];
      if (existing == null) {
        delivered[key] = line;
      } else {
        existing.qty += line.qty;
      }
    }
    return [...delivered.values, ...undelivered];
  }
}
