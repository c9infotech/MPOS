import 'package:flutter/material.dart';

import '../../app.dart';
import '../../core/draft/pos_draft_service.dart';
import '../../core/theme/app_colors.dart';
import '../../models/pos_draft.dart';

class DraftListScreen extends StatefulWidget {
  const DraftListScreen({super.key, required this.onRestoreToPos});

  final VoidCallback onRestoreToPos;

  @override
  State<DraftListScreen> createState() => _DraftListScreenState();
}

class _DraftListScreenState extends State<DraftListScreen> {
  List<SavedPosDraft> _drafts = [];
  bool _loading = true;
  String? _busyId;
  bool _didLoad = false;
  PosDraftService? _draftService;

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
    _load();
  }

  @override
  void dispose() {
    _draftService?.removeListener(_onDraftsChanged);
    super.dispose();
  }

  void _onDraftsChanged() => _load();

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final drafts = await AppScope.of(context).posDrafts.getAllDrafts();
      if (!mounted) return;
      setState(() {
        _drafts = drafts..sort((a, b) => b.savedAt.compareTo(a.savedAt));
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _drafts = [];
        _loading = false;
      });
    }
  }

  Future<void> _cancelDraft(SavedPosDraft draft) async {
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

    setState(() => _busyId = draft.id);
    await AppScope.of(context).posDrafts.removeDraft(draft.id);
    if (mounted) setState(() => _busyId = null);
    await _load();
  }

  Future<void> _restoreDraft(SavedPosDraft draft) async {
    setState(() => _busyId = draft.id);
    AppScope.of(context).posDrafts.requestRestore(draft);
    widget.onRestoreToPos();
    if (mounted) setState(() => _busyId = null);
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
              const Text(
                'On POS, add items to cart → Save Draft → pick table & subdivision.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary),
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
                    '${draft.itemCount} items · '
                    '${draft.currency} ${draft.subtotal.toStringAsFixed(2)}',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 6),
                  ...draft.lines.take(3).map(
                        (l) => Text(
                          '· ${l.qty}x ${l.product.itemName.isNotEmpty ? l.product.itemName : l.product.itemCode}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                  if (draft.lines.length > 3)
                    Text(
                      '… +${draft.lines.length - 3} more',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
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
