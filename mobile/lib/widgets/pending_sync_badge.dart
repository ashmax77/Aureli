import 'package:flutter/material.dart';
import 'package:aureli/theme/app_colors.dart';

import '../models/transaction_model.dart';

/// Small marker shown under a transaction that has not reached the server yet.
class PendingSyncBadge extends StatelessWidget {
  const PendingSyncBadge({super.key, required this.transaction});

  final TransactionModel transaction;

  @override
  Widget build(BuildContext context) {
    final failed = transaction.syncAttempts > 0;
    final color = failed ? context.tokens.amber : context.tokens.cobalt;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          failed ? Icons.sync_problem_rounded : Icons.cloud_upload_outlined,
          size: 12,
          color: color,
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            failed ? 'Sync failed - will retry - hold to discard' : 'Pending sync',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}
