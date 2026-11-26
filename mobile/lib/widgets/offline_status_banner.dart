import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/transaction_provider.dart';

/// Human-friendly age of cached data, e.g. "just now", "5 min ago", "3 h ago", "2 days ago".
String describeDataAge(DateTime updatedAt, {DateTime? now}) {
  final age = (now ?? DateTime.now()).difference(updatedAt);
  if (age.inMinutes < 1) return 'just now';
  if (age.inMinutes < 60) return '${age.inMinutes} min ago';
  if (age.inHours < 24) return '${age.inHours} h ago';
  final days = age.inDays;
  return days == 1 ? '1 day ago' : '$days days ago';
}

/// Strip shown above the app content while the device can't reach the server and/or
/// transactions saved on this device are still waiting to sync. Renders nothing otherwise.
class OfflineStatusBanner extends StatelessWidget {
  const OfflineStatusBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TransactionProvider>();
    final pending = provider.pendingCount;
    if (!provider.isOffline && pending == 0) return const SizedBox.shrink();

    final pendingText =
        pending == 1 ? '1 transaction waiting to sync' : '$pending transactions waiting to sync';
    final updatedAt = provider.lastUpdatedAt;
    final savedData = updatedAt == null
        ? "You're offline - showing saved data"
        : "You're offline - showing saved data from ${describeDataAge(updatedAt)}";
    final message = provider.isOffline
        ? (pending > 0 ? "$savedData. $pendingText" : savedData)
        : pendingText;
    final color = provider.isOffline ? const Color(0xFF8A5A12) : const Color(0xFF30456B);

    return Material(
      color: color,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              Icon(
                provider.isOffline ? Icons.cloud_off_rounded : Icons.cloud_upload_outlined,
                size: 16,
                color: Colors.white,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
              if (pending > 0)
                TextButton(
                  onPressed: provider.syncNow,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 28),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: const Text('Sync now'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
