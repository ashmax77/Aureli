import 'dart:async';

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
    final secondary = isDark ? Colors.white.withValues(alpha: 0.7) : const Color(0xFF475569);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F1621) : const Color(0xFFF4F6F9),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(
                color: Color(0xFF147D64), // Emerald
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
