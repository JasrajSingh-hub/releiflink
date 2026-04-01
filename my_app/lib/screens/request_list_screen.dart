import 'package:flutter/material.dart';

import '../models/request.dart';
import '../services/request_service.dart';
import 'request_detail_screen.dart';

class RequestListScreen extends StatefulWidget {
  const RequestListScreen({super.key, required this.onNewReport});

  final VoidCallback onNewReport;

  @override
  State<RequestListScreen> createState() => _RequestListScreenState();
}

class _RequestListScreenState extends State<RequestListScreen> {
  final _service = RequestService.instance;
  RequestType? _typeFilter;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _service,
      builder: (context, _) {
        final active =
            _service.getAll().where((r) => r.status != RequestStatus.completed).toList();
        final filtered = _typeFilter == null
            ? active
            : active.where((r) => r.type == _typeFilter).toList();
        final requests = _sorted(filtered);

        return Stack(
          children: [
            RefreshIndicator(
              onRefresh: () async {},
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
                children: [
                  TextField(
                    readOnly: true,
                    decoration: const InputDecoration(
                      hintText: 'Search by location or need...',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Search is not part of this MVP'),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  _FilterRow(
                    typeFilter: _typeFilter,
                    counts: _counts(active),
                    onSelectAll: () => setState(() => _typeFilter = null),
                    onSelectType: (t) => setState(() => _typeFilter = t),
                  ),
                  const SizedBox(height: 14),
                  if (requests.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 60),
                      child: Center(child: Text('No requests yet')),
                    )
                  else
                    ..._buildSections(context, requests),
                ],
              ),
            ),
            Positioned(
              right: 20,
              bottom: 90,
              child: _NewReportFab(onTap: widget.onNewReport),
            ),
          ],
        );
      },
    );
  }

  List<ReliefRequest> _sorted(List<ReliefRequest> input) {
    final copy = [...input];
    copy.sort((a, b) {
      final prioCompare = priorityRank(a.priority).compareTo(priorityRank(b.priority));
      if (prioCompare != 0) return prioCompare;

      return b.createdAt.compareTo(a.createdAt);
    });
    return copy;
  }

  Map<RequestType, int> _counts(List<ReliefRequest> active) {
    final map = <RequestType, int>{};
    for (final t in RequestType.values) {
      map[t] = 0;
    }
    for (final r in active) {
      map[r.type] = (map[r.type] ?? 0) + 1;
    }
    return map;
  }

  List<Widget> _buildSections(BuildContext context, List<ReliefRequest> requests) {
    final byPriority = <RequestPriority, List<ReliefRequest>>{};
    for (final r in requests) {
      byPriority.putIfAbsent(r.priority, () => []).add(r);
    }

    final order = [
      RequestPriority.critical,
      RequestPriority.high,
      RequestPriority.medium,
      RequestPriority.low,
    ];

    final widgets = <Widget>[];
    for (final p in order) {
      final list = byPriority[p];
      if (list == null || list.isEmpty) continue;
      widgets.add(_SectionHeader(label: '${requestPriorityLabel(p)} Priority'));
      widgets.add(const SizedBox(height: 10));
      widgets.addAll(
        list.map(
          (r) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _RequestCard(
              request: r,
              onTap: () async {
                final result = await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => RequestDetailScreen(requestId: r.id)),
                );
                if (!mounted) return;
                if (result == true) setState(() {});
              },
            ),
          ),
        ),
      );
      widgets.add(const SizedBox(height: 8));
    }
    return widgets;
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.request,
    required this.onTap,
  });

  final ReliefRequest request;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = priorityColor(request);
    final borderColor = Theme.of(context).dividerColor;
    final statusText = request.status == RequestStatus.pending ? 'ACTIVE' : 'OPEN';

    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(0, 0, 0, 0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: [
              Container(
                width: 6,
                height: 140,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: accent.withOpacity(0.10),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(requestTypeIcon(request.type), color: accent),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _titleFor(request),
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: -0.2,
                                      ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  request.locationText,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: const Color(0xFF71717A),
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          _StatusPill(text: statusText),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        request.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: const Color(0xFF52525B),
                              height: 1.35,
                            ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: const [
                          Text(
                            'DETAILS',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.6,
                              fontSize: 12,
                            ),
                          ),
                          SizedBox(width: 6),
                          Icon(Icons.chevron_right, size: 18),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _titleFor(ReliefRequest r) {
    return switch (r.type) {
      RequestType.medical => 'Critical Medical Support',
      RequestType.food => 'Supplies & Food Delivery',
      RequestType.rescue => 'Rescue Assistance Needed',
      RequestType.shelter => 'Shelter Required',
    };
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F4F5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: const Color(0xFF71717A),
              fontWeight: FontWeight.w900,
              letterSpacing: 0.6,
            ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: const Color(0xFF71717A),
                fontWeight: FontWeight.w900,
                letterSpacing: 3.0,
              ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(height: 1, color: const Color(0xFFF4F4F5)),
        ),
      ],
    );
  }
}

class _NewReportFab extends StatelessWidget {
  const _NewReportFab({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF111827),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        elevation: 6,
      ),
      icon: const Icon(Icons.add, size: 20),
      label: Text(
        'NEW REPORT',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              letterSpacing: 2.0,
            ),
      ),
    );
  }
}

class _FilterRow extends StatelessWidget {
  const _FilterRow({
    required this.typeFilter,
    required this.counts,
    required this.onSelectAll,
    required this.onSelectType,
  });

  final RequestType? typeFilter;
  final Map<RequestType, int> counts;
  final VoidCallback onSelectAll;
  final ValueChanged<RequestType> onSelectType;

  @override
  Widget build(BuildContext context) {
    final active = typeFilter == null;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _FilterChip(
            label: 'ALL ACTIVE',
            isActive: active,
            onTap: onSelectAll,
          ),
          const SizedBox(width: 8),
          for (final t in RequestType.values) ...[
            _FilterChip(
              label: '${requestTypeLabel(t).toUpperCase()} (${counts[t] ?? 0})',
              isActive: typeFilter == t,
              onTap: () => onSelectType(t),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = isActive ? const Color(0xFF111827) : const Color(0xFFF4F4F5);
    final fg = isActive ? Colors.white : const Color(0xFF52525B);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: fg,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
        ),
      ),
    );
  }
}
