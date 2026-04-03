import 'package:hive_flutter/hive_flutter.dart';

class LocalStore {
  static const requestsBoxName = 'requests_v1';
  static const outboxBoxName = 'outbox_v1';
  static const authBoxName = 'auth_v1';
  static const conflictsBoxName = 'conflicts_v1';

  static Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox<Map>(requestsBoxName);
    await Hive.openBox<Map>(outboxBoxName);
    await Hive.openBox<Map>(authBoxName);
    await Hive.openBox<Map>(conflictsBoxName);
  }

  static Box<Map> requestsBox() => Hive.box<Map>(requestsBoxName);

  static Box<Map> outboxBox() => Hive.box<Map>(outboxBoxName);

  static Box<Map> authBox() => Hive.box<Map>(authBoxName);

  static Box<Map> conflictsBox() => Hive.box<Map>(conflictsBoxName);
}
