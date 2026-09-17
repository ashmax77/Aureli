import 'package:flutter_test/flutter_test.dart';
import 'package:aureli/models/notification_model.dart';

void main() {
  group('NotificationModel timestamp parsing', () {
    test('parses ISO UTC string with Z correctly and converts to local', () {
      final nowUtc = DateTime.now().toUtc();
      final json = {
        'id': 1,
        'title': 'Budget Exceeded',
        'body': 'You have exceeded Food budget',
        'read': false,
        'createdAt': nowUtc.toIso8601String(),
      };

      final model = NotificationModel.fromJson(json);
      expect(model.createdAt.isUtc, false);
      expect(model.createdAt.difference(DateTime.now()).inSeconds.abs() < 5, true);
    });

    test('parses ISO string without Z as UTC and converts to local', () {
      // Simulates Render server emitting LocalDateTime without Z
      final nowUtc = DateTime.now().toUtc();
      final isoWithoutZ = nowUtc.toIso8601String().replaceAll('Z', '');
      final json = {
        'id': 2,
        'title': 'Payment Due',
        'body': 'Rent due tomorrow',
        'read': true,
        'createdAt': isoWithoutZ,
      };

      final model = NotificationModel.fromJson(json);
      expect(model.createdAt.isUtc, false);
      // The parsed time should match local time within a couple seconds, NOT be 5.5 hours behind
      expect(model.createdAt.difference(DateTime.now()).inSeconds.abs() < 5, true);
    });

    test('parses ISO string with explicit timezone offset correctly', () {
      final json = {
        'id': 3,
        'title': 'Alert',
        'body': 'Test alert',
        'read': false,
        'createdAt': '2026-09-17T19:00:00+00:00',
      };

      final model = NotificationModel.fromJson(json);
      expect(model.createdAt.isUtc, false);
      expect(model.createdAt.toUtc().hour, 19);
    });

    test('parses epoch timestamp in milliseconds', () {
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final json = {
        'id': 4,
        'title': 'Epoch Alert',
        'body': 'Test epoch',
        'read': false,
        'createdAt': nowMs,
      };

      final model = NotificationModel.fromJson(json);
      expect(model.createdAt.isUtc, false);
      expect(model.createdAt.difference(DateTime.now()).inSeconds.abs() < 5, true);
    });
  });
}
