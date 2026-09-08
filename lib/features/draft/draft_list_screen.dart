import 'dart:async';

import 'package:flutter/material.dart';

import '../../app.dart';
import '../../core/draft/pos_draft_service.dart';
import '../../core/theme/app_colors.dart';
import '../../models/pos_draft.dart';
import '../../models/product.dart';

class DraftListScreen extends StatefulWidget {
  const DraftListScreen({
    super.key,
    required this.onRestoreToPos,
    this.isActive = true,
  });

  final VoidCallback onRestoreToPos;
  final bool isActive;

  @override
  State<DraftListScreen> createState() => _DraftListScreenState();
}

class _DraftListScreenState extends State<DraftListScreen> {
  List<SavedPosDraft> _drafts = [];
  bool _loading = true;
  String? _error;
  String? _busyId;
  bool _didLoad = false;
  PosDraftService? _draftService;
  Timer? _autoRefreshTimer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final service = AppScope.of(context).posDrafts;
    if (_draftService != service) {
      _draftService?.removeListener(_onDraftsChanged);
      _draftService = service;
      _draftService!.addListener(_onDraftsChanged);
    }
    if (_didLoad) return;
    _didLoad = true;
    if (widget.isActive) {
      _load();
      _startAutoRefresh();
    } else {
      setState(() => _loading = false);
    }
  }

  @override
  void didUpdateWidget(covariant DraftListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive == widget.isActive) return;
    if (widget.isActive) {
      _load();
      _startAutoRefresh();
    } else {
      _autoRefreshTimer?.cancel();
      _autoRefreshTimer = null;
    }
  }

  void _startAutoRefresh() {
    _autoRefreshTimer?.cancel();
    if (!widget.isActive) return;
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (!mounted || !widget.isActive || _busyId != null) return;
      _load(silent: true);
    });
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _draftService?.removeListener(_onDraftsChanged);
    super.dispose();
  }

  void _onDraftsChanged() {
    if (!widget.isActive) return;
    _load(silent: true);
  }

  Future<void> _load({bool silent = false}) async {
    if (!widget.isActive && silent) return;
    if (!silent) {
      setState(() => _loading = true);
    }
    try {
      final drafts = await AppScope.of(context).posDrafts.getAllDrafts();
      if (!mounted) return;
      setState(() {
        _drafts = drafts..sort((a, b) => b.savedAt.compareTo(a.savedAt));
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _drafts = [];
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _showDraftMessage(String message, {Color background = AppColors.error}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: background),
    );
  }

  bool _hasValidDraftId(SavedPosDraft draft) {
    if (draft.id.trim().isNotEmpty) return true;
    _showDraftMessage('Draft ID is missing. Refresh and try again.');
    return false;
  }

  Future<void> _cancelDraft(SavedPosDraft draft) async {
    if (!_hasValidDraftId(draft)) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text('Cancel draft?'),
        content: Text('Remove ${draft.slot.label} from drafts?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Cancel draft'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (!mounted) return;

    setState(() => _busyId = draft.id);
    try {
      await AppScope.of(context).posDrafts.removeDraft(draft.id);
      await _load();
    } on Exception catch (e) {
      _showDraftMessage(e.toString());
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _restoreDraft(SavedPosDraft draft) async {
    if (!_hasValidDraftId(draft)) return;

    final deliveredCount = draft.lines.where((line) => line.isDelivered).length;
    if (deliveredCount == 0) {
      _showDraftMessage(
        'No delivered items in this draft yet.',
        background: AppColors.warning,
      );
      return;
    }
    setState(() => _busyId = draft.id);
    AppScope.of(context).posDrafts.requestRestore(draft);
    widget.onRestoreToPos();
    if (mounted) setState(() => _busyId = null);
  }

  Future<void> _markDelivered(SavedPosDraft draft) async {
    if (!_hasValidDraftId(draft)) return;

    final pendingIndexes = <int>{};
    for (var i = 0; i < draft.lines.length; i++) {
      if (!draft.lines[i].isDelivered) {
        pendingIndexes.add(i);
      }
    }
    if (pendingIndexes.isEmpty) return;

    setState(() => _busyId = draft.id);
    try {
      await AppScope.of(context).posDrafts.markLinesDelivered(
        draft: draft,
        lineIndexes: pendingIndexes,
      );
      if (!mounted) return;
      _showDraftMessage(
        'Marked as delivered',
        background: AppColors.success,
      );
      await _load();
    } on Exception catch (e) {
      _showDraftMessage(e.toString());
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  List<MapEntry<int, CartLine>> _sortedLineEntries(SavedPosDraft draft) {
    final entries = List.generate(
      draft.lines.length,
      (index) => MapEntry(index, draft.lines[index]),
    );
    entries.sort((a, b) {
      if (a.value.isDelivered == b.value.isDelivered) {
        return a.key.compareTo(b.key);
      }
      return a.value.isDelivered ? -1 : 1;
    });
    return entries;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.emerald),
      );
    }

    if (_drafts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.drafts_outlined,
                  size: 48,
                  color: AppColors.textSecondary.withValues(alpha: 0.6)),
              const SizedBox(height: 12),
              const Text(
                'No saved drafts',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
              const SizedBox(height: 6),
              Text(
                _error == null
                    ? 'On POS, add items to cart → Save Draft → pick table & subdivision.'
                    : _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.emerald,
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: _drafts.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final draft = _drafts[index];
          final busy = _busyId == draft.id;
          return Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    draft.slot.label,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${draft.itemCount} qty · '
                    '${draft.currency} ${draft.subtotal.toStringAsFixed(2)}',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 6),
                  ..._sortedLineEntries(draft).map((entry) {
                    final line = entry.value;
                    final isDelivered = line.isDelivered;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isDelivered
                            ? const Color(0xFFDDF4EA)
                            : AppColors.surfaceMuted,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isDelivered
                              ? AppColors.success
                              : AppColors.warning.withValues(alpha: 0.55),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          if (isDelivered)
                            const Icon(
                              Icons.check_circle,
                              size: 18,
                              color: AppColors.success,
                            )
                          else
                            const Icon(
                              Icons.pending_outlined,
                              size: 18,
                              color: AppColors.warning,
                            ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '${line.qty}x ${line.product.itemName.isNotEmpty ? line.product.itemName : line.product.itemCode}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isDelivered
                                    ? AppColors.emerald
                                    : AppColors.textPrimary,
                              ),
                            ),
                          ),
                          Text(
                            isDelivered ? 'Delivered' : 'Pending',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: isDelivered
                                  ? AppColors.success
                                  : AppColors.warning,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (draft.lines.any((line) => !line.isDelivered)) ...[
                        Expanded(
                          child: OutlinedButton(
                            onPressed: busy ? null : () => _markDelivered(draft),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.success,
                              side: const BorderSide(color: AppColors.success),
                            ),
                            child: const Text('Delivered'),
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                      Expanded(
                        child: OutlinedButton(
                          onPressed: busy ? null : () => _cancelDraft(draft),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.error,
                            side: const BorderSide(color: AppColors.error),
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: busy ? null : () => _restoreDraft(draft),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.emerald,
                          ),
                          child: busy
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Restore'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
