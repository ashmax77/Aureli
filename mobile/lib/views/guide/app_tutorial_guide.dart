import '../../theme/app_tokens.dart';
import '../../widgets/status_pill.dart';
import '../../theme/app_text.dart';
import 'package:aureli/theme/app_colors.dart';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/auth_provider.dart';

/// Interactive Educated Guide showcasing the exact workflow to perform tasks in Aureli.
/// Automatically shown to newly registered users on first launch, with a transparent "Skip Tutorial" button.
class AppTutorialGuide extends StatefulWidget {
  final bool isManualTrigger;

  const AppTutorialGuide({
    super.key,
    this.isManualTrigger = false,
  });

  /// Static helper to display the tutorial dialog anywhere in the app.
  static Future<void> show(BuildContext context, {bool isManualTrigger = false}) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Theme.of(context).extension<AureliTokens>()?.scrim ?? Colors.black54,
      builder: (ctx) => AppTutorialGuide(isManualTrigger: isManualTrigger),
    );
  }

  @override
  State<AppTutorialGuide> createState() => _AppTutorialGuideState();
}

class _AppTutorialGuideState extends State<AppTutorialGuide> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  static const int _totalPages = 5;

  Future<void> _markTutorialCompleted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final authProv = Provider.of<AuthProvider>(context, listen: false);
      final uid = authProv.firebaseUser?.uid ?? 'guest';
      await prefs.setBool('has_seen_tutorial_$uid', true);
    } catch (e) {
      if (kDebugMode) debugPrint("Error saving tutorial completion: $e");
    }
  }

  void _skipTutorial() {
    _markTutorialCompleted();
    Navigator.of(context, rootNavigator: true).pop();
  }

  void _nextPage() {
    if (_currentPage < _totalPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeInOut,
      );
    } else {
      _skipTutorial(); // Finished all steps
    }
  }

  void _prevPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dialogBg = context.tokens.panel;
    final cardBorder = context.tokens.hairline;
    final titleColor = context.textPrimary;
    final bodyColor = context.tokens.inkSecondary;

    return PopScope(
      canPop: false, // Force explicit action or skip
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _skipTutorial();
      },
      child: Center(
        child: Container(
          margin: EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          constraints: const BoxConstraints(maxWidth: 440, maxHeight: 680),
          decoration: BoxDecoration(
            color: dialogBg,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: cardBorder),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Material(
                color: Colors.transparent,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(22, 18, 22, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Top Bar: Step Indicator & Transparent "Skip Tutorial" Button
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Step badge
                          StatusPill(
                            label: "Step ${_currentPage + 1} of $_totalPages",
                            color: context.tokens.emerald,
                          ),

                          // Transparent "Skip Tutorial" Button
                          TextButton.icon(
                            onPressed: _skipTutorial,
                            style: TextButton.styleFrom(
                              foregroundColor: context.tokens.inkMuted,
                            ),
                            icon: const Icon(Icons.close_rounded, size: 14),
                            label: const Text('Skip'),
                            iconAlignment: IconAlignment.end,
                          ),
                        ],
                      ),

                      SizedBox(height: 12),

                      // Step Content (PageView)
                      Expanded(
                        child: PageView(
                          controller: _pageController,
                          onPageChanged: (index) {
                            setState(() => _currentPage = index);
                          },
                          children: [
                            _buildStep1(isDark, titleColor, bodyColor),
                            _buildStep2(isDark, titleColor, bodyColor),
                            _buildStep3(isDark, titleColor, bodyColor),
                            _buildStep4(isDark, titleColor, bodyColor),
                            _buildStep5(isDark, titleColor, bodyColor),
                          ],
                        ),
                      ),

                      SizedBox(height: 16),

                      // Bottom Navigation Bar (Previous, Dots, Next)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Previous Button
                          if (_currentPage > 0)
                            TextButton.icon(
                              onPressed: _prevPage,
                              icon: Icon(Icons.arrow_back_rounded, size: 16),
                              label: const Text('Back'),
                              style: TextButton.styleFrom(
                                foregroundColor: context.tokens.inkMuted,
                                backgroundColor: Colors.transparent,
                              ),
                            )
                          else
                            SizedBox(width: 70),

                          // Page Indicator Dots
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: List.generate(
                              _totalPages,
                              (idx) => AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                margin: EdgeInsets.symmetric(horizontal: 3),
                                width: _currentPage == idx ? 22 : 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  color: _currentPage == idx
                                      ? context.tokens.emerald
                                      : context.tokens.hairline,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                          ),

                          // Next / Get Started Button
                          ElevatedButton(
                            onPressed: _nextPage,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _currentPage == _totalPages - 1
                                      ? "Finish"
                                      : "Next",
                                  style: AppText.title2.copyWith(fontSize: 14),
                                ),
                                SizedBox(width: 4),
                                Icon(
                                  _currentPage == _totalPages - 1
                                      ? Icons.check_rounded
                                      : Icons.arrow_forward_rounded,
                                  size: 16,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // STEP 1: Wealth Formula (Savings Vault & Spendable Allowance)
  // ===========================================================================
  Widget _buildStep1(bool isDark, Color titleColor, Color bodyColor) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildHeroIcon(
            icon: Icons.account_balance_wallet_rounded,
            gradientColors: [context.tokens.emerald, context.tokens.emerald],
          ),
          SizedBox(height: 14),
          Text(
            "The Aureli wealth formula",
            textAlign: TextAlign.center,
            style: AppText.title1.copyWith(color: titleColor),
          ),
          SizedBox(height: 6),
          Text(
            "Never guess how much money is safe to spend.",
            textAlign: TextAlign.center,
            style: AppText.bodySmall.copyWith(color: bodyColor),
          ),
          SizedBox(height: 16),
          _buildFormulaCard(isDark),
          SizedBox(height: 14),
          _buildWorkflowItem(
            isDark: isDark,
            number: "1",
            title: "Cumulative savings vault",
            description:
                "Whenever income is recorded, a portion is locked into your Savings Vault to steadily build your net worth.",
            icon: Icons.lock_outline_rounded,
            iconColor: context.tokens.emerald,
          ),
          SizedBox(height: 8),
          _buildWorkflowItem(
            isDark: isDark,
            number: "2",
            title: "Spendable liquid allowance",
            description:
                "The large allowance on your dashboard shows your true spendable cash after subtracting savings and upcoming bills.",
            icon: Icons.check_circle_outline_rounded,
            iconColor: context.tokens.cobalt,
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // STEP 2: Quick Actions & Income Allocation
  // ===========================================================================
  Widget _buildStep2(bool isDark, Color titleColor, Color bodyColor) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildHeroIcon(
            icon: Icons.add_circle_rounded,
            gradientColors: [context.tokens.cobalt, context.tokens.cobalt],
          ),
          SizedBox(height: 14),
          Text(
            "Log transactions & save",
            textAlign: TextAlign.center,
            style: AppText.title1.copyWith(color: titleColor),
          ),
          SizedBox(height: 6),
          Text(
            "Exact workflow to record income & expenses",
            textAlign: TextAlign.center,
            style: AppText.bodySmall.copyWith(color: bodyColor),
          ),
          SizedBox(height: 16),
          _buildWorkflowItem(
            isDark: isDark,
            number: "1",
            title: "Tap the (+) quick action button",
            description:
                "Press the glowing (+) button at the center of the bottom bar from any tab to open the Quick Action sheet.",
            icon: Icons.touch_app_rounded,
            iconColor: context.tokens.cobalt,
          ),
          SizedBox(height: 8),
          _buildWorkflowItem(
            isDark: isDark,
            number: "2",
            title: "Income: savings choice toggle",
            description:
                "Switch 'Reserve for Savings' ON to allocate a percentage (e.g. 20%), or toggle it OFF to keep 100% liquid for expenses.",
            icon: Icons.tune_rounded,
            iconColor: context.tokens.emerald,
          ),
          SizedBox(height: 8),
          _buildWorkflowItem(
            isDark: isDark,
            number: "3",
            title: "Expense: category deduction",
            description:
                "Pick a category (Dining, Groceries, etc.) to deduct the spend from both your monthly category limit and your allowance.",
            icon: Icons.receipt_long_rounded,
            iconColor: context.tokens.amber,
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // STEP 3: Budgets & Spending Limits
  // ===========================================================================
  Widget _buildStep3(bool isDark, Color titleColor, Color bodyColor) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildHeroIcon(
            icon: Icons.pie_chart_rounded,
            gradientColors: const [Color(0xFF7C3AED), Color(0xFFA78BFA)],
          ),
          SizedBox(height: 14),
          Text(
            "Budgets & category limits",
            textAlign: TextAlign.center,
            style: AppText.title1.copyWith(color: titleColor),
          ),
          SizedBox(height: 6),
          Text(
            "Exact workflow to control spending ceilings",
            textAlign: TextAlign.center,
            style: AppText.bodySmall.copyWith(color: bodyColor),
          ),
          SizedBox(height: 16),
          _buildWorkflowItem(
            isDark: isDark,
            number: "1",
            title: "Navigate to budgets tab",
            description:
                "Tap the 3rd icon (Pie Chart) on the bottom navigation bar to review all category budgets.",
            icon: Icons.folder_open_rounded,
            iconColor: const Color(0xFFA78BFA),
          ),
          SizedBox(height: 8),
          _buildWorkflowItem(
            isDark: isDark,
            number: "2",
            title: "Tap any category to set limit",
            description:
                "Tap Groceries, Housing, etc., to establish monthly limits. Dynamic health bars show Normal (Green), Warning (Orange), or Exceeded (Red).",
            icon: Icons.linear_scale_rounded,
            iconColor: context.tokens.emerald,
          ),
          SizedBox(height: 8),
          _buildWorkflowItem(
            isDark: isDark,
            number: "3",
            title: "Create custom categories",
            description:
                "Tap '+ Add Category' to define custom expense or income buckets tailored with personalized icons and color palettes.",
            icon: Icons.category_rounded,
            iconColor: context.tokens.cobalt,
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // STEP 4: Scheduled Bills & 1-Tap Payments
  // ===========================================================================
  Widget _buildStep4(bool isDark, Color titleColor, Color bodyColor) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildHeroIcon(
            icon: Icons.event_repeat_rounded,
            gradientColors: [Color(0xFF2563EB), context.tokens.cobalt],
          ),
          SizedBox(height: 14),
          Text(
            "Scheduled bills & 1-Tap pay",
            textAlign: TextAlign.center,
            style: AppText.title1.copyWith(color: titleColor),
          ),
          SizedBox(height: 6),
          Text(
            "Automate bills & eliminate late fee surprises",
            textAlign: TextAlign.center,
            style: AppText.bodySmall.copyWith(color: bodyColor),
          ),
          SizedBox(height: 16),
          _buildWorkflowItem(
            isDark: isDark,
            number: "1",
            title: "Schedule recurring or one-time bills",
            description:
                "Add subscriptions, rent, or utilities under Weekly, Monthly, or Yearly cadences with automated push reminder alerts.",
            icon: Icons.calendar_month_rounded,
            iconColor: context.tokens.cobalt,
          ),
          SizedBox(height: 8),
          _buildWorkflowItem(
            isDark: isDark,
            number: "2",
            title: "1-Tap 'pay now' execution",
            description:
                "When a bill is due, tap 'Pay Now' with 1 tap. Aureli records the payment in your expense ledger and rolls recurring bills forward!",
            icon: Icons.payment_rounded,
            iconColor: context.tokens.emerald,
          ),
          SizedBox(height: 8),
          _buildWorkflowItem(
            isDark: isDark,
            number: "3",
            title: "Manage debts & loans",
            description:
                "Track money owed or money lent via the Debts & Loans tracker with partial and full repayment logging.",
            icon: Icons.handshake_rounded,
            iconColor: context.tokens.amber,
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // STEP 5: Analytics & Dual Themes
  // ===========================================================================
  Widget _buildStep5(bool isDark, Color titleColor, Color bodyColor) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildHeroIcon(
            icon: Icons.auto_awesome_rounded,
            gradientColors: [Color(0xFFD97706), context.tokens.amber],
          ),
          SizedBox(height: 14),
          Text(
            "Analytics & personalization",
            textAlign: TextAlign.center,
            style: AppText.title1.copyWith(color: titleColor),
          ),
          SizedBox(height: 6),
          Text(
            "Tailor your Aureli experience to your style",
            textAlign: TextAlign.center,
            style: AppText.bodySmall.copyWith(color: bodyColor),
          ),
          SizedBox(height: 16),
          _buildWorkflowItem(
            isDark: isDark,
            number: "1",
            title: "Analytics & trends",
            description:
                "Tap the 4th tab to visualize historical 6-month trends and category spending distribution graphs.",
            icon: Icons.insights_rounded,
            iconColor: context.tokens.amber,
          ),
          SizedBox(height: 8),
          _buildWorkflowItem(
            isDark: isDark,
            number: "2",
            title: "Dark & light (white) themes",
            description:
                "Tap your avatar (top right) → 'App theme' to toggle between obsidian glassmorphic dark mode and clean white light mode.",
            icon: Icons.brightness_6_rounded,
            iconColor: const Color(0xFF8B5CF6),
          ),
          SizedBox(height: 8),
          _buildWorkflowItem(
            isDark: isDark,
            number: "3",
            title: "Replay this guide anytime",
            description:
                "Need a refresher? Open Profile → 'App guided tour' to reopen this tutorial anytime.",
            icon: Icons.menu_book_rounded,
            iconColor: context.tokens.emerald,
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // Helper Widgets
  // ===========================================================================
  Widget _buildHeroIcon({
    required IconData icon,
    required List<Color> gradientColors,
  }) {
    final accent = gradientColors.last;
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: context.tokens.soft(accent, brightness: Theme.of(context).brightness),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Icon(icon, color: accent, size: 30),
    );
  }

  Widget _buildFormulaCard(bool isDark) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: context.tokens.soft(context.tokens.emerald, brightness: Theme.of(context).brightness),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.calculate_rounded, color: context.tokens.emerald, size: 18),
          SizedBox(width: 8),
          Flexible(
            child: Text(
              "Allowance = Income − Savings − Bills",
              style: AppText.title2.copyWith(fontSize: 13, color: context.tokens.emerald),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkflowItem({
    required bool isDark,
    required String number,
    required String title,
    required String description,
    required IconData icon,
    required Color iconColor,
  }) {
    final itemBg = context.tokens.inputFill;
    final itemBorder = context.tokens.hairline;
    final titleColor = context.textPrimary;
    final bodyColor = context.tokens.inkSecondary;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: itemBg,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: itemBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: context.tokens.soft(iconColor, brightness: Theme.of(context).brightness),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppText.title2.copyWith(fontSize: 14, color: titleColor),
                ),
                SizedBox(height: 3),
                Text(
                  description,
                  style: AppText.label.copyWith(height: 1.35, color: bodyColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
