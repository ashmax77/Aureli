import '../../theme/app_text.dart';
import 'package:aureli/theme/app_colors.dart';
import '../../widgets/money_text.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../providers/lifetime_provider.dart';
import '../../widgets/glass_card.dart';

class LifetimeJourneyView extends StatefulWidget {
  const LifetimeJourneyView({super.key});

  @override
  State<LifetimeJourneyView> createState() => _LifetimeJourneyViewState();
}

class _LifetimeJourneyViewState extends State<LifetimeJourneyView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<LifetimeProvider>(context, listen: false).fetchLifetimeData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Consumer<LifetimeProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.stats == null) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.errorMessage != null && provider.stats == null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    provider.errorMessage!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.red),
                  ),
                  SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () =>
                        provider.fetchLifetimeData(year: provider.selectedYear),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final stats = provider.stats;
          if (stats == null) {
            return const Center(child: Text("No data available"));
          }

          return SafeArea(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24.0, vertical: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Lifetime Journey",
                          style: TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: context.textPrimary,
                          ),
                        ).animate().fade(duration: 400.ms).slideX(begin: -0.1),
                        SizedBox(height: 8),
                        Text(
                          "Your financial milestones since joining Aureli",
                          style: TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 14,
                            color: context.textSecondary,
                          ),
                        ).animate().fade(duration: 400.ms, delay: 100.ms).slideX(begin: -0.1),
                        SizedBox(height: 24),
                        
                        // Hero Section: Lifetime Ledger
                        GlassCard(
                          padding: EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildHeroStat(
                                "Total lifetime saved", 
                                stats.totalSaved, 
                                context.tokens.emerald
                              ),
                              SizedBox(height: 24),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildHeroStat(
                                      "Total earned", 
                                      stats.totalEarned, 
                                      context.tokens.cobalt
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: _buildHeroStat(
                                      "Total spent", 
                                      stats.totalSpent, 
                                      context.tokens.amber
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ).animate().fade(duration: 600.ms, delay: 200.ms).scale(begin: const Offset(0.95, 0.95)),
                        
                        SizedBox(height: 32),
                        
                        // Achievements Section
                        Text(
                          "Hall of Fame",
                          style: TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: context.textPrimary,
                          ),
                        ),
                        SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: 24.0),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childAspectRatio: 0.85,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final achievement = provider.achievements[index];
                        return _buildAchievementCard(achievement, isDark)
                            .animate(delay: (300 + (100 * index)).ms)
                            .fade(duration: 400.ms)
                            .slideY(begin: 0.2);
                      },
                      childCount: provider.achievements.length,
                    ),
                  ),
                ),
                const SliverToBoxAdapter(
                  child: SizedBox(height: 40),
                )
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeroStat(String label, double amount, Color accentColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppText.label.copyWith(color: context.tokens.inkSecondary),
        ),
        SizedBox(height: 4),
        TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: amount),
          duration: const Duration(seconds: 2),
          curve: Curves.easeOutQuart,
          builder: (context, value, child) {
            return FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Money(
                value,
                style: AppText.title1.copyWith(fontSize: 22),
                color: accentColor,
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildAchievementCard(dynamic achievement, bool isDark) {
    final bool isUnlocked = achievement.isUnlocked;
    return Container(
      decoration: BoxDecoration(
        color: isDark 
            ? (isUnlocked ? context.tokens.inputFill : context.tokens.inputFill)
            : (isUnlocked ? Colors.white : Colors.grey.shade100),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isUnlocked 
              ? (isDark ? Colors.white24 : Colors.grey.shade300) 
              : Colors.transparent,
        ),
      ),
      padding: EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isUnlocked ? const Color(0xFFFACC15).withValues(alpha: 0.2) : Colors.grey.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isUnlocked ? Icons.emoji_events_rounded : Icons.lock_rounded,
              color: isUnlocked ? const Color(0xFFFACC15) : context.tokens.inkMuted,
              size: 32,
            ),
          ),
          SizedBox(height: 12),
          Text(
            achievement.title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isUnlocked ? (isDark ? Colors.white : Colors.black) : context.tokens.inkMuted,
            ),
          ),
          SizedBox(height: 4),
          Text(
            achievement.description,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 11,
              color: isUnlocked ? (isDark ? context.tokens.inkSecondary : context.tokens.inkSecondary) : context.tokens.inkMuted,
            ),
          ),
        ],
      ),
    );
  }
}
