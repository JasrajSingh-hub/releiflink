import 'package:flutter/widgets.dart';

import '../storage/local_store.dart';
import 'conflict_service.dart';
import 'request_service.dart';
import 'sync_service.dart';

class AppBootstrap {
  AppBootstrap._();

  static Future<void> init() async {
    WidgetsFlutterBinding.ensureInitialized();
    await LocalStore.init();
    await ConflictService.instance.init();
    await RequestService.instance.init();
    await SyncService.instance.start();
  }
}
