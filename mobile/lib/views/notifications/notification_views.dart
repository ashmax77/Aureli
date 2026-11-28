import '../../theme/app_tokens.dart';
import '../../theme/app_text.dart';
import 'package:aureli/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/notification_provider.dart';
import '../../widgets/glass_card.dart';

/// A reusable bell icon button with unread badge.
/// Place this in any AppBar's actions list.
class NotificationBellIcon extends StatefulWidget {
  const NotificationBellIcon({super.key});

  @override
  State<NotificationBellIcon> createState() => _NotificationBellIconState();
}

class _NotificationBellIconState extends State<NotificationBellIcon> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<NotificationProvider>(context, listen: false)
          .fetchUnreadCount();
    });
  }

  @override
  Widget build(BuildContext context) {
    final notifProvider = Provider.of<NotificationProvider>(context);
    final unreadCount = notifProvider.unreadCount;

    return IconButton(
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(Icons.notifications_none_rounded, color: context.textSecondary),
          if (unreadCount > 0)
            Positioned(
              right: -4,
              top: -4,
              child: Container(
                padding: EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: context.tokens.coral,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  unreadCount > 9 ? "9+" : "$unreadCount",
                  style: AppText.caption.copyWith(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ),
        ],
      ),
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const NotificationHistoryScreen()),
        );
      },
      tooltip: "Notifications",
    );
  }
}

/// Full-screen notification history view.
class NotificationHistoryScreen extends StatefulWidget {
  const NotificationHistoryScreen({super.key});

  @override
  State<NotificationHistoryScreen> createState() =>
      _NotificationHistoryScreenState();
}

class _NotificationHistoryScreenState extends State<NotificationHistoryScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_loadNextPageWhenNeeded);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider =
          Provider.of<NotificationProvider>(context, listen: false);
      provider.fetchNotifications();
      provider.markAllAsRead();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _loadNextPageWhenNeeded() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      Provider.of<NotificationProvider>(context, listen: false)
          .fetchNotifications(refresh: false);
    }
  }

  String _formatRelativeTime(DateTime dateTime) {
    final local = dateTime.isUtc ? dateTime.toLocal() : dateTime;
    final now = DateTime.now();
    final diff = now.difference(local);

    if (diff.isNegative || diff.inMinutes < 1) return "Just now";
    if (diff.inMinutes < 60) return "${diff.inMinutes}m ago";
    if (diff.inHours < 24) return "${diff.inHours}h ago";
    if (diff.inDays < 7) return "${diff.inDays}d ago";
    return DateFormat('d MMM yyyy, h:mm a').format(local);
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<NotificationProvider>(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Notifications'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: context.iconSecondary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await provider.fetchNotifications();
          await provider.markAllAsRead();
        },
        color: context.tokens.emerald,
        child: provider.isLoading
            ? Center(
                child: CircularProgressIndicator(color: context.tokens.emerald))
            : provider.notifications.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(
                          height: MediaQuery.of(context).size.height * 0.3),
                      Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.notifications_off_rounded,
                                size: 48,
                                color: context.tokens.inkFaint),
                            const SizedBox(height: 12),
                            Text(
                              "You're all caught up",
                              style: AppText.title2.copyWith(color: context.tokens.inkSecondary),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'New alerts will show up here.',
                              style: AppText.bodySmall.copyWith(color: context.tokens.inkMuted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : ListView.builder(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: provider.notifications.length,
                    itemBuilder: (context, index) {
                      final notification = provider.notifications[index];

                      final accent = _accentFor(context, notification.title);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: GlassCard(
                          padding: const EdgeInsets.all(AppSpace.lg),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: context.tokens.soft(accent,
                                      brightness: Theme.of(context).brightness),
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.sm),
                                ),
                                child: Icon(
                                  _getNotificationIcon(notification.title),
                                  color: accent,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: AppSpace.md),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      notification.title,
                                      style: AppText.title2.copyWith(
                                          fontSize: 14,
                                          fontWeight: notification.isRead
                                              ? FontWeight.w600
                                              : FontWeight.w700,
                                          color: context.tokens.ink),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      notification.body,
                                      style: AppText.bodySmall.copyWith(
                                          color: context.tokens.inkSecondary),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      _formatRelativeTime(
                                          notification.createdAt),
                                      style: AppText.caption.copyWith(
                                          color: context.tokens.inkMuted),
                                    ),
                                  ],
                                ),
                              ),
                              if (!notification.isRead)
                                Padding(
                                  padding:
                                      const EdgeInsets.only(left: 8, top: 6),
                                  child: Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: context.tokens.emerald,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }

  Color _accentFor(BuildContext context, String title) {
    final lower = title.toLowerCase();
    final t = context.tokens;
    if (lower.contains('exceeded')) return t.coral;
    if (lower.contains('budget') ||
        lower.contains('limit') ||
        lower.contains('nearing')) {
      return t.amber;
    }
    return t.cobalt;
  }

  IconData _getNotificationIcon(String title) {
    final lower = title.toLowerCase();
    if (lower.contains('budget') ||
        lower.contains('limit') ||
        lower.contains('exceeded')) {
      return Icons.warning_amber_rounded;
    }
    if (lower.contains('nearing')) {
      return Icons.trending_up_rounded;
    }
    return Icons.notifications_active_rounded;
  }
}
