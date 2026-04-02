import 'package:flutter/material.dart';

import '../models/request.dart';
import '../services/auth_service.dart';
import '../services/request_service.dart';
import '../widgets/relief_map.dart';

class RequestDetailScreen extends StatefulWidget {
  const RequestDetailScreen({super.key, required this.requestId});

  final String requestId;

  @override
  State<RequestDetailScreen> createState() => _RequestDetailScreenState();
}

class _RequestDetailScreenState extends State<RequestDetailScreen> {
  final _service = RequestService.instance;

  @override
  Widget build(BuildContext context) {
    final request = _service.getById(widget.requestId);
    if (request == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Request')),
        body: const Center(child: Text('Request not found')),
      );
    }

    final accent = priorityColor(request);
    final user = AuthService.instance.user;
    final isVolunteer = user?.role == 'volunteer';
    final canAccept = isVolunteer && request.status == RequestStatus.pending;
    final canComplete = isVolunteer && request.status == RequestStatus.inProgress;
    final shortId = _shortId(request.id);

    return Scaffold(
      appBar: AppBar(
        title: Text('Request $shortId'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _Pill(
                    text: requestPriorityLabel(request.priority).toUpperCase(),
                    background: const Color(0xFF111827),
                    foreground: Colors.white,
                    icon: Icons.warning_amber,
                  ),
                  const Spacer(),
                  Row(
                    children: const [
                      Text(
                        'LIVE SIGNAL',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 11,
                          letterSpacing: 1.6,
                          color: Color(0xFF71717A),
                        ),
                      ),
                      SizedBox(width: 6),
                      _LiveDot(),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                requestTypeLabel(request.type),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.4,
                    ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.location_on, size: 16, color: const Color(0xFF71717A)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      request.locationText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF71717A),
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _InfoCard(
                title: 'REQUEST SPECS',
                child: Row(
                  children: [
                    Expanded(
                      child: _Spec(label: 'Category', value: requestTypeLabel(request.type)),
                    ),
                    Expanded(
                      child: _Spec(label: 'Group Size', value: '${request.peopleCount} People'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _InfoCard(
                title: 'DETAILED DESCRIPTION',
                child: Text(
                  request.description,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        height: 1.4,
                        color: const Color(0xFF111827),
                      ),
                ),
              ),
              const SizedBox(height: 12),
              ReliefMap(
                requests: [request],
                height: 200,
                focusRequestId: request.id,
              ),
              const SizedBox(height: 12),
              Text(
                'Status: ${requestStatusLabel(request.status)}',
                style: TextStyle(
                  color: statusColor(request.status),
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _BottomActions(
        status: request.status,
        isVolunteer: isVolunteer,
        accent: accent,
        onContact: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Contact is not part of this MVP')),
          );
        },
        onPrimary: () async {
          if (!isVolunteer) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Only volunteer role can accept/complete requests'),
              ),
            );
            return;
          }
          if (canAccept) {
            await _service.acceptRequest(request.id);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Request accepted (In Progress)')),
            );
            Navigator.of(context).pop(true);
            return;
          }
          if (canComplete) {
            await _service.markCompleted(request.id);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Marked completed')),
            );
            Navigator.of(context).pop(true);
          }
        },
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final borderColor = Theme.of(context).dividerColor;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: const Color(0xFF71717A),
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2.2,
                ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _BottomActions extends StatelessWidget {
  const _BottomActions({
    required this.status,
    required this.isVolunteer,
    required this.accent,
    required this.onContact,
    required this.onPrimary,
  });

  final RequestStatus status;
  final bool isVolunteer;
  final Color accent;
  final VoidCallback onContact;
  final Future<void> Function() onPrimary;

  @override
  Widget build(BuildContext context) {
    final primaryLabel = switch (status) {
      RequestStatus.pending => 'ACCEPT REQUEST',
      RequestStatus.inProgress => 'MARK COMPLETED',
      RequestStatus.completed => 'COMPLETED',
    };
    final primaryEnabled = isVolunteer && status != RequestStatus.completed;

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
        ),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onContact,
                icon: const Icon(Icons.chat_bubble_outline),
                label: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Text('CONTACT'),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: primaryEnabled ? () async => onPrimary() : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryEnabled ? accent : const Color(0xFF16A34A),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Text(
                    primaryLabel,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2.0,
                        ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Spec extends StatelessWidget {
  const _Spec({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: const Color(0xFF71717A),
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.text,
    required this.background,
    required this.foreground,
    required this.icon,
  });

  final String text;
  final Color background;
  final Color foreground;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: foreground),
          const SizedBox(width: 8),
          Text(
            text,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: foreground,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.6,
                ),
          ),
        ],
      ),
    );
  }
}

class _LiveDot extends StatelessWidget {
  const _LiveDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: const BoxDecoration(
        color: Color(0xFFDC2626),
        shape: BoxShape.circle,
      ),
    );
  }
}

String _shortId(String id) {
  final parts = id.split('_');
  return parts.length >= 3 ? '#${parts[2]}' : '#${id.substring(0, id.length.clamp(0, 6))}';
}
