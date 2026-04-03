import 'package:flutter/material.dart';

import '../models/request.dart';
import '../utils/map_cluster.dart';

class ZoneSummarySheet extends StatelessWidget {
  const ZoneSummarySheet({
    super.key,
    required this.cluster,
    required this.isOffline,
    required this.onSelectRequest,
  });

  final RequestCluster cluster;
  final bool isOffline;
  final ValueChanged<ReliefRequest> onSelectRequest;

  @override
  Widget build(BuildContext context) {
    // Compute type counts
    final typeCounts = {for (final t in RequestType.values) t: 0};
    for (final r in cluster.requests) {
      typeCounts[r.type] = typeCounts[r.type]! + 1;
    }

    // Compute priority counts
    final priorityCounts = {for (final p in RequestPriority.values) p: 0};
    for (final r in cluster.requests) {
      priorityCounts[r.priority] = priorityCounts[r.priority]! + 1;
    }

    // Sort requests by priority
    final sorted = [...cluster.requests]
      ..sort((a, b) => priorityRank(a.priority).compareTo(priorityRank(b.priority)));

    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.3,
      maxChildSize: 0.92,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Drag handle
              Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 4),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD1D5DB),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              _ZoneSheetHeader(cluster: cluster),
              if (isOffline) const _OfflineBanner(),
              _TypeBreakdownRow(typeCounts: typeCounts),
              _PriorityBreakdownRow(priorityCounts: priorityCounts),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: sorted.length,
                  itemBuilder: (context, index) => _RequestListItem(
                    request: sorted[index],
                    onSelectRequest: onSelectRequest,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Zone Sheet Header
// ---------------------------------------------------------------------------

class _ZoneSheetHeader extends StatelessWidget {
  const _ZoneSheetHeader({required this.cluster});

  final RequestCluster cluster;

  @override
  Widget build(BuildContext context) {
    final hasAssigned = cluster.hasAssigned;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          Container(
            width: 5,
            height: 40,
            decoration: BoxDecoration(
              color: cluster.color,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ZONE SUMMARY',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
                if (hasAssigned)
                  Text(
                    '${cluster.inProgressCount} volunteer${cluster.inProgressCount > 1 ? 's' : ''} responding',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: const Color(0xFF16A34A),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
          ),
          // Pending badge
          _StatusBadge(
            count: cluster.pendingCount,
            label: 'PENDING',
            color: cluster.color,
          ),
          if (hasAssigned) ...[
            const SizedBox(width: 6),
            const _StatusBadge(
              count: null,
              label: 'ACTIVE',
              color: Color(0xFF16A34A),
              icon: Icons.directions_run,
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Status Badge
// ---------------------------------------------------------------------------

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.count,
    required this.label,
    required this.color,
    this.icon,
  });

  final int? count;
  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: color),
            const SizedBox(width: 3),
          ],
          if (count != null) ...[
            Text(
              '$count',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: color,
              fontSize: 10,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Offline Banner
// ---------------------------------------------------------------------------

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFF59E0B)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber, size: 16, color: Color(0xFFB45309)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Data may not be current (offline)',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: const Color(0xFF92400E),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Type Breakdown Row
// ---------------------------------------------------------------------------

class _TypeBreakdownRow extends StatelessWidget {
  const _TypeBreakdownRow({required this.typeCounts});

  final Map<RequestType, int> typeCounts;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: RequestType.values
              .where((t) => (typeCounts[t] ?? 0) > 0)
              .map((t) => Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: _CountChip(
                      icon: requestTypeIcon(t),
                      label: requestTypeLabel(t),
                      count: typeCounts[t] ?? 0,
                      color: const Color(0xFF374151),
                    ),
                  ))
              .toList(),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Priority Breakdown Row
// ---------------------------------------------------------------------------

class _PriorityBreakdownRow extends StatelessWidget {
  const _PriorityBreakdownRow({required this.priorityCounts});

  final Map<RequestPriority, int> priorityCounts;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: RequestPriority.values
              .where((p) => (priorityCounts[p] ?? 0) > 0)
              .map((p) {
            final color = _priorityColorFromEnum(p);
            return Padding(
              padding: const EdgeInsets.only(right: 12),
              child: _CountChip(
                icon: Icons.flag,
                label: requestPriorityLabel(p),
                count: priorityCounts[p] ?? 0,
                color: color,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Color _priorityColorFromEnum(RequestPriority p) {
    return switch (p) {
      RequestPriority.critical => const Color(0xFFC62828),
      RequestPriority.high => const Color(0xFFEF6C00),
      RequestPriority.medium => const Color(0xFFF9A825),
      RequestPriority.low => const Color(0xFF607D8B),
    };
  }
}

// ---------------------------------------------------------------------------
// Count Chip
// ---------------------------------------------------------------------------

class _CountChip extends StatelessWidget {
  const _CountChip({
    required this.icon,
    required this.label,
    required this.count,
    required this.color,
  });

  final IconData icon;
  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(height: 2),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: const Color(0xFF6B7280),
            fontSize: 10,
          ),
        ),
        const SizedBox(height: 2),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '$count',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Request List Item
// ---------------------------------------------------------------------------

class _RequestListItem extends StatelessWidget {
  const _RequestListItem({
    required this.request,
    required this.onSelectRequest,
  });

  final ReliefRequest request;
  final ValueChanged<ReliefRequest> onSelectRequest;

  @override
  Widget build(BuildContext context) {
    final color = _priorityColorFromEnum(request.priority);
    return InkWell(
      onTap: () => onSelectRequest(request),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: color.withOpacity(0.35)),
              ),
              child: Icon(requestTypeIcon(request.type), color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        requestPriorityLabel(request.priority).toUpperCase(),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: color,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        requestTypeLabel(request.type),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: const Color(0xFF6B7280),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      if (request.status == RequestStatus.assigned ||
                          request.status == RequestStatus.inProgress)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.directions_run,
                                size: 10,
                                color: Color(0xFF16A34A),
                              ),
                              const SizedBox(width: 3),
                              Text(
                                'ACTIVE',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                      color: const Color(0xFF16A34A),
                                      fontWeight: FontWeight.w900,
                                      fontSize: 9,
                                      letterSpacing: 0.8,
                                    ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    request.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.people, size: 12, color: Color(0xFF6B7280)),
                  const SizedBox(width: 3),
                  Text(
                    '${request.peopleCount}',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF374151),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _priorityColorFromEnum(RequestPriority p) {
    return switch (p) {
      RequestPriority.critical => const Color(0xFFC62828),
      RequestPriority.high => const Color(0xFFEF6C00),
      RequestPriority.medium => const Color(0xFFF9A825),
      RequestPriority.low => const Color(0xFF607D8B),
    };
  }
}
