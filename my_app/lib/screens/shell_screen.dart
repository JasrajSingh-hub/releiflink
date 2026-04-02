import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../services/request_service.dart';
import '../services/sync_service.dart';
import '../storage/local_store.dart';
import '../widgets/relief_bottom_nav.dart';
import 'create_request_screen.dart';
import 'home_screen.dart';
import 'profile_screen.dart';
import 'map_screen.dart';
import 'request_list_screen.dart';

class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key});

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  int _index = 0;
  final _service = RequestService.instance;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Box<Map>>(
      valueListenable: LocalStore.outboxBox().listenable(),
      builder: (context, outbox, _) {
        return AnimatedBuilder(
          animation: _service,
          builder: (context, _) {
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
                    icon: const Icon(Icons.sync),
                  ),
                  IconButton(
                    tooltip: 'Profile',
                    onPressed: () {
                      Navigator.of(context).pushNamed(ProfileScreen.routeName);
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
