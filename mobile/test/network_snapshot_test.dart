import 'package:flutter_test/flutter_test.dart';
import 'package:aureli/services/api_metrics.dart';
import 'package:aureli/services/snapshot_cache_service.dart';

void main() {
  test('snapshot freshness expires after its max age', () {
    final savedAt = DateTime.utc(2026, 10, 28, 8);
    final snapshot = CachedSnapshot(
      savedAt: savedAt,
      schemaVersion: SnapshotCacheService.currentSchemaVersion,
      data: const {'value': 1},
    );

    expect(
      snapshot.isFresh(const Duration(minutes: 5),
          now: savedAt.add(const Duration(minutes: 4))),
      isTrue,
    );
    expect(
      snapshot.isFresh(const Duration(minutes: 5),
          now: savedAt.add(const Duration(minutes: 5))),
      isFalse,
    );
  });

  test('API metrics records request, retry, bytes, and coalescing counters', () {
    final metrics = ApiMetrics();
    metrics.recordRequestAttempt();
    metrics.recordRetry();
    metrics.recordResponseBytes(128);
    metrics.recordInFlightGetHit();

    expect(metrics.snapshot(), {
      'requestAttempts': 1,
      'retryCount': 1,
      'responseBytes': 128,
      'inFlightGetHits': 1,
    });
  });
}
