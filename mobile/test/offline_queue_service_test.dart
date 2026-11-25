import 'package:aureli/services/offline_queue_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final store = <String, String>{};

  setUp(() {
    store.clear();
    TestWidgetsFlutterBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async {
        final args = (call.arguments as Map?) ?? {};
        switch (call.method) {
          case 'write':
            store[args['key'] as String] = args['value'] as String;
            return null;
          case 'read':
            return store[args['key'] as String];
          case 'delete':
            store.remove(args['key'] as String);
            return null;
          case 'deleteAll':
            store.clear();
            return null;
        }
        return null;
      },
    );
  });

  test('queued transactions always get distinct ids', () async {
    for (var i = 0; i < 20; i++) {
      await OfflineQueueService.enqueueTransaction({'amount': i + 1.0});
    }
    final queue = await OfflineQueueService.getPendingTransactions();
    expect(queue.length, 20);
    expect(queue.map((e) => e['id']).toSet().length, 20);
  });

  test('concurrent enqueues are all stored with distinct ids', () async {
    await Future.wait([
      for (var i = 0; i < 10; i++)
        OfflineQueueService.enqueueTransaction({'amount': i + 1.0}),
    ]);
    final queue = await OfflineQueueService.getPendingTransactions();
    expect(queue.length, 10);
    expect(queue.map((e) => e['id']).toSet().length, 10);
  });

  test('removing one entry leaves the others untouched', () async {
    for (var i = 0; i < 3; i++) {
      await OfflineQueueService.enqueueTransaction({'amount': i + 1.0});
    }
    final queue = await OfflineQueueService.getPendingTransactions();
    await OfflineQueueService.removeTransaction(queue.first['id'] as int);
    final after = await OfflineQueueService.getPendingTransactions();
    expect(after.length, 2);
    expect(after.any((e) => e['id'] == queue.first['id']), isFalse);
  });

  test('failure backoff grows and is capped at one hour', () async {
    await OfflineQueueService.enqueueTransaction({'amount': 1.0});
    final id = (await OfflineQueueService.getPendingTransactions()).first['id'] as int;
    var previous = 0;
    for (var i = 0; i < 14; i++) {
      await OfflineQueueService.recordFailure(id);
      final item = (await OfflineQueueService.getPendingTransactions()).first;
      final delay = DateTime.parse(item['nextAttemptAt'] as String)
          .difference(DateTime.now().toUtc())
          .inSeconds;
      expect(delay, greaterThanOrEqualTo(previous - 1));
      expect(delay, lessThanOrEqualTo(3600));
      previous = delay;
      expect(item['attempts'], i + 1);
    }
  });
}
