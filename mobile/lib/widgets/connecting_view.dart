import 'dart:async';
import 'package:aureli/theme/app_colors.dart';

import 'package:flutter/material.dart';

/// Full-screen wait shown while the app waits for the server's first answer (profile sync
/// at launch). After [slowHintAfter] it says why the wait can be long: the free-tier server
/// sleeps when idle and can take about a minute to wake, so the user isn't left guessing.
class ConnectingView extends StatefulWidget {
  const ConnectingView({super.key, this.slowHintAfter = const Duration(seconds: 5)});

  final Duration slowHintAfter;

  @override
  State<ConnectingView> createState() => _ConnectingViewState();
}

class _ConnectingViewState extends State<ConnectingView> {
  Timer? _slowHintTimer;
  bool _showSlowHint = false;

  @override
  void initState() {
    super.initState();
    _slowHintTimer = Timer(widget.slowHintAfter, () {
      if (mounted) setState(() => _showSlowHint = true);
    });
  }

  @override
  void dispose() {
    _slowHintTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondary = context.tokens.inkSecondary;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F1621) : context.tokens.inputFill,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                color: context.tokens.emerald, // Emerald
              ),
              const SizedBox(height: 20),
              Text(
                "Connecting to Aureli...",
                style: TextStyle(
                  color: secondary,
                  fontFamily: 'Manrope',
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (_showSlowHint) ...[
                const SizedBox(height: 12),
                Text(
                  "Waking up the server. The first load after a quiet period can take up to a minute.",
                  textAlign: TextAlign.center,
                  key: const Key('slow-hint'),
                  style: TextStyle(
                    color: secondary,
                    fontFamily: 'Manrope',
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
