import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'secure_storage_service.dart';

class CachedSnapshot {
  final DateTime savedAt;
  final int schemaVersion;
  final dynamic data;

  const CachedSnapshot({
    required this.savedAt,
    required this.schemaVersion,
    required this.data,
  });

  bool isFresh(Duration maxAge, {DateTime? now}) {
    final currentTime = now ?? DateTime.now();
    return currentTime.difference(savedAt) < maxAge;
  }
}

class SnapshotCacheService {
  static const int currentSchemaVersion = 1;

  static String key(String userId, String resource) =>
      'aureli:$userId:$resource';

  static Future<CachedSnapshot?> read({
    required String userId,
    required String resource,
  }) async {
    final raw = await SecureStorageService.read(key(userId, resource));
    if (raw == null || raw.isEmpty) return null;

    try {
      final envelope = jsonDecode(raw) as Map<String, dynamic>;
      final savedAt = DateTime.tryParse(envelope['savedAt'] as String? ?? '');
      final data = envelope['data'];
      if (savedAt == null || data == null) return null;

      return CachedSnapshot(
        savedAt: savedAt,
        schemaVersion: (envelope['schemaVersion'] as num?)?.toInt() ?? 0,
        data: data,
      );
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Snapshot cache decode error for $resource: $error');
      }
      return null;
    }
  }

  static Future<void> write({
    required String userId,
    required String resource,
    required dynamic data,
    DateTime? savedAt,
  }) async {
    await SecureStorageService.write(
      key(userId, resource),
      jsonEncode({
        'savedAt': (savedAt ?? DateTime.now()).toUtc().toIso8601String(),
        'schemaVersion': currentSchemaVersion,
        'data': data,
      }),
    );
  }

  static Future<void> invalidate({
    required String userId,
    required String resource,
  }) async {
    await SecureStorageService.delete(key(userId, resource));
  }
}
