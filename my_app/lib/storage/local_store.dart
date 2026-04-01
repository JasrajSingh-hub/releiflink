import 'package:hive_flutter/hive_flutter.dart';

class LocalStore {
  static const requestsBoxName = 'requests_v1';
  static const outboxBoxName = 'outbox_v1';

  static Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox<Map>(requestsBoxName);
    await Hive.openBox<Map>(outboxBoxName);
  }

  static Box<Map> requestsBox() => Hive.box<Map>(requestsBoxName);

  static Box<Map> outboxBox() => Hive.box<Map>(outboxBoxName);
}

