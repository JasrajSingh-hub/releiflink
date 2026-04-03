import 'package:flutter/material.dart';

import '../models/outbox_item.dart';
import '../models/request.dart';
import '../models/sync_conflict.dart';
import '../services/conflict_service.dart';
import '../services/outbox_service.dart';
import '../services/request_service.dart';
import '../storage/local_store.dart';

class SyncConflictsScreen extends StatelessWidget {
  const SyncConflictsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = ConflictService.instance;
    return AnimatedBuilder(
      animation: service,
      builder: (context, _) {
        final conflicts = service.listAll();
        return Scaffold(
          appBar: AppBar(title: const Text('Sync Conflicts')),
          body: conflicts.isEmpty
              ? const Center(child: Text('No conflicts'))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  itemCount: conflicts.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final c = conflicts[index];
                    return _ConflictCard(conflict: c);
                  },
                ),
        );
      },
    );
  }
}

class _ConflictCard extends StatelessWidget {
  const _ConflictCard({required this.conflict});

  final SyncConflict conflict;

  @override
  Widget build(BuildContext context) {
    final local = conflict.local;
    final remote = conflict.remote;

    String? localSummary() {
      if (local == null) return null;
      final status = local['status'];
      final desc = local['description'];
      return 'Local: status=${status ?? "?"}, desc=${_short(desc)}';
    }

    String? remoteSummary() {
      if (remote == null) return null;
      final status = remote['status'];
      final desc = remote['description'];
      return 'Server: status=${status ?? "?"}, desc=${_short(desc)}';
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: const Color(0xFFFAFAFA),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.report_problem, color: Color(0xFFD97706)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Request ${_shortId(conflict.requestId)}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ),
              Text(
                _formatTime(conflict.createdAt),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: const Color(0xFF71717A),
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
          if (conflict.message != null) ...[
            const SizedBox(height: 8),
            Text(
              conflict.message!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF52525B),
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
          const SizedBox(height: 10),
          if (localSummary() != null) Text(localSummary()!),
          if (remoteSummary() != null) ...[
            const SizedBox(height: 6),
            Text(remoteSummary()!),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    await ConflictService.instance.dismiss(conflict.id);
                  },
                  child: const Text('Dismiss'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: local == null
                      ? null
                      : () async {
                          await _reapplyLocal(conflict);
                          await ConflictService.instance.dismiss(conflict.id);
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Requeued local changes')),
                          );
                        },
                  child: const Text('Reapply Local'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

Future<void> _reapplyLocal(SyncConflict conflict) async {
  final local = conflict.local;
  if (local == null) return;

  // Apply local snapshot into the cache immediately (UX: user sees their choice).
  final req = ReliefRequest.fromJson(local).copyWith(updatedAt: DateTime.now());
  await LocalStore.requestsBox().put(req.id, req.toJson());

  // Requeue write in the correct channel.
  if (conflict.action == OutboxAction.updateStatus) {
    final desired =
        req.status == RequestStatus.assigned ? RequestStatus.inProgress : req.status;
    await OutboxService.instance.enqueue(
      action: OutboxAction.updateStatus,
      requestId: req.id,
      payload: {'status': requestStatusToWire(desired)},
      baseUpdatedAt: req.updatedAt,
    );
    return;
  }

  await OutboxService.instance.enqueue(
    action: conflict.action,
    requestId: req.id,
    payload: req.toJson(),
    baseUpdatedAt: req.updatedAt,
  );

  // Ensure listeners refresh quickly.
  RequestService.instance.notifyListeners();
}

String _short(Object? v) {
  final s = v == null ? '' : v.toString();
  if (s.length <= 42) return s;
  return '${s.substring(0, 39)}...';
}

String _shortId(String id) {
  if (id.length <= 8) return id;
  return '#${id.substring(id.length - 6)}';
}

String _formatTime(DateTime dt) {
  final h = dt.hour.toString().padLeft(2, '0');
  final m = dt.minute.toString().padLeft(2, '0');
  return '$h:$m';
}
