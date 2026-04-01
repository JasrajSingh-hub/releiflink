import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.requestCount,
    required this.pendingSyncCount,
    required this.onRequestHelp,
    required this.onVolunteer,
  });

  final int requestCount;
  final int pendingSyncCount;
  final VoidCallback onRequestHelp;
  final VoidCallback onVolunteer;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 110),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'OPERATIONAL STATUS: ACTIVE',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: const Color(0xFF71717A),
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2.2,
                ),
          ),
          const SizedBox(height: 10),
          Text(
            'Decisive\nAction.',
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1.4,
                  height: 0.98,
                ),
          ),
          const SizedBox(height: 10),
          Text(
            'Get help or give help.',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: const Color(0xFF52525B),
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 18),
          _PrimaryCard(
            onTap: onRequestHelp,
            title: 'REQUEST HELP',
            subtitle: 'IMMEDIATE RESPONSE NEEDED',
            leading: 'SOS',
            background: const Color(0xFFD32F2F),
            foreground: Colors.white,
          ),
          const SizedBox(height: 14),
          _SecondaryCard(
            onTap: onVolunteer,
            eyebrow: 'COMMUNITY SUPPORT',
            title: 'Volunteer',
            subtitle: 'Join the response effort',
            icon: Icons.volunteer_activism,
          ),
          const SizedBox(height: 14),
          Row(
            children: const [
              Expanded(
                child: _MiniInfoCard(
                  icon: Icons.location_on,
                  label: 'YOUR ZONE',
                  value: 'Sector 7-G',
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _MiniInfoCard(
                  icon: Icons.shield,
                  label: 'VERIFIED',
                  value: 'Safe Route',
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _SystemNote(requestCount: requestCount, pendingSyncCount: pendingSyncCount),
        ],
      ),
    );
  }
}

class _PrimaryCard extends StatelessWidget {
  const _PrimaryCard({
    required this.onTap,
    required this.title,
    required this.subtitle,
    required this.leading,
    required this.background,
    required this.foreground,
  });

  final VoidCallback onTap;
  final String title;
  final String subtitle;
  final String leading;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        height: 220,
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: background.withOpacity(0.22),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              top: 8,
              right: 10,
              child: Icon(Icons.emergency, size: 60, color: Colors.white.withOpacity(0.18)),
            ),
            Align(
              alignment: Alignment.bottomLeft,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    leading,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: foreground,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.1,
                        ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: foreground,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.6,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: foreground.withOpacity(0.82),
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.8,
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
}

class _SecondaryCard extends StatelessWidget {
  const _SecondaryCard({
    required this.onTap,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final VoidCallback onTap;
  final String eyebrow;
  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        height: 120,
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFFFAFAFA),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: const Color(0xFF71717A)),
                const SizedBox(width: 8),
                Text(
                  eyebrow,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: const Color(0xFF71717A),
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2.2,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF52525B),
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniInfoCard extends StatelessWidget {
  const _MiniInfoCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFFA1A1AA)),
          const SizedBox(height: 10),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: const Color(0xFFA1A1AA),
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.8,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _SystemNote extends StatelessWidget {
  const _SystemNote({required this.requestCount, required this.pendingSyncCount});

  final int requestCount;
  final int pendingSyncCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F4F5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.offline_bolt, color: Color(0xFF52525B)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Offline-first MVP. Local requests: $requestCount. Pending sync: $pendingSyncCount',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF52525B),
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
