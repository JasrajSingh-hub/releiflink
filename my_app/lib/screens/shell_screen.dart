import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../services/request_service.dart';
import '../services/sync_service.dart';
import '../services/conflict_service.dart';
import '../storage/local_store.dart';
import '../widgets/relief_bottom_nav.dart';
import 'create_request_screen.dart';
import 'home_screen.dart';
import 'map_screen.dart';
import 'request_list_screen.dart';
import 'sync_conflicts_screen.dart';

class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key});

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  int _index = 0;
  final _service = RequestService.instance;
  final _conflicts = ConflictService.instance;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Box<Map>>(
      valueListenable: LocalStore.outboxBox().listenable(),
      builder: (context, outbox, _) {
        return AnimatedBuilder(
          animation: Listenable.merge([_service, _conflicts]),
          builder: (context, _) {
            final conflictCount = _conflicts.unresolvedCount();
            return Scaffold(
              appBar: AppBar(
                title: const Text('ReliefLink'),
                leading: const Icon(Icons.emergency),
                actions: [
                  IconButton(
                    tooltip: 'Sync',
                    onPressed: () async {
                      await SyncService.instance.syncNow(force: true);
                      if (!context.mounted) return;
                      final status =
                          SyncService.instance.status ?? 'Sync finished';
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(status)),
                      );
                    },
                    icon: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        const Icon(Icons.sync),
                        if (outbox.length > 0)
                          Positioned(
                            right: -6,
                            top: -6,
                            child: _Badge(text: '${outbox.length}'),
                          ),
                      ],
                    ),
                  ),
                  if (conflictCount > 0)
                    IconButton(
                      tooltip: 'Conflicts',
                      onPressed: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const SyncConflictsScreen()),
                        );
                      },
                      icon: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          const Icon(Icons.report_problem),
                          Positioned(
                            right: -6,
                            top: -6,
                            child: _Badge(text: '$conflictCount'),
                          ),
                        ],
                      ),
                    ),
                  IconButton(
                    tooltip: 'Profile',
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Profile is disabled for now'),
                        ),
                      );
                    },
                    icon: const Icon(Icons.account_circle),
                  ),
                ],
              ),
              body: IndexedStack(
                index: _index,
                children: [
                  HomeScreen(
                    requestCount: _service.getAll().length,
                    pendingSyncCount: outbox.length,
                    conflictCount: conflictCount,
                    onRequestHelp: () => setState(() => _index = 2),
                    onVolunteer: () => setState(() => _index = 1),
                  ),
                  RequestListScreen(
                    onNewReport: () => setState(() => _index = 2),
                  ),
                  CreateRequestScreen(
                    embedded: true,
                    onSubmitted: () => setState(() => _index = 1),
                  ),
                  MapScreen(
                    onNewReport: () => setState(() => _index = 2),
                  ),
                ],
              ),
              bottomNavigationBar: ReliefBottomNav(
                index: _index,
                onSelect: (i) => setState(() => _index = i),
              ),
            );
          },
        );
      },
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFDC2626),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 10,
            ),
      ),
    );
  }
}
