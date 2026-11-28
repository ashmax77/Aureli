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
      barrierColor: Colors.black.withValues(alpha: 0.75),
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
    final dialogBg = isDark ? Color(0xFF0F1722) : Colors.white;
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
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: cardBorder, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.6 : 0.2),
                blurRadius: 36,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
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
                          Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 12, vertical: 5),
                            decoration: BoxDecoration(
                              color: context.tokens.emerald.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: context.tokens.emerald.withValues(alpha: 0.35),
                              ),
                            ),
                            child: Text(
                              "Step ${_currentPage + 1} of $_totalPages",
                              style: TextStyle(
                                fontFamily: 'Manrope',
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: context.tokens.emerald,
                              ),
                            ),
                          ),

                          // Transparent "Skip Tutorial" Button
                          TextButton(
                            onPressed: _skipTutorial,
                            style: TextButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              foregroundColor: context.tokens.inkMuted,
                              padding: EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                                side: BorderSide(
                                  color: (isDark ? Colors.white : Colors.black)
                                      .withValues(alpha: 0.16),
                                  width: 1,
                                ),
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  "Skip Tutorial",
                                  style: TextStyle(
                                    fontFamily: 'Manrope',
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(width: 4),
                                Icon(Icons.close_rounded, size: 14),
                              ],
                            ),
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
                              label: Text(
                                "Back",
                                style: TextStyle(
                                  fontFamily: 'Manrope',
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
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
                                      : (isDark
                                          ? context.tokens.hairline
                                          : const Color(0xFFCBD5E1)),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                          ),

                          // Next / Get Started Button
                          ElevatedButton(
                            onPressed: _nextPage,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: context.tokens.brand,
                              foregroundColor: context.textPrimary,
                              padding: EdgeInsets.symmetric(
                                  horizontal: 18, vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: 0,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _currentPage == _totalPages - 1
                                      ? "Finish"
                                      : "Next",
                                  style: TextStyle(
                                    fontFamily: 'Manrope',
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
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
            "The Aureli Wealth Formula",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: titleColor,
            ),
          ),
          SizedBox(height: 6),
          Text(
            "Never guess how much money is safe to spend.",
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'Manrope', fontSize: 13, color: bodyColor),
          ),
          SizedBox(height: 16),
          _buildFormulaCard(isDark),
          SizedBox(height: 14),
          _buildWorkflowItem(
            isDark: isDark,
            number: "1",
            title: "Cumulative Savings Vault",
            description:
                "Whenever income is recorded, a portion is locked into your Savings Vault to steadily build your net worth.",
            icon: Icons.lock_outline_rounded,
            iconColor: context.tokens.emerald,
          ),
          SizedBox(height: 8),
          _buildWorkflowItem(
            isDark: isDark,
            number: "2",
            title: "Spendable Liquid Allowance",
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
            "Log Transactions & Save",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: titleColor,
            ),
          ),
          SizedBox(height: 6),
          Text(
            "Exact workflow to record income & expenses",
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'Manrope', fontSize: 13, color: bodyColor),
          ),
          SizedBox(height: 16),
          _buildWorkflowItem(
            isDark: isDark,
            number: "1",
            title: "Tap the (+) Quick Action Button",
            description:
                "Press the glowing (+) button at the center of the bottom bar from any tab to open the Quick Action sheet.",
            icon: Icons.touch_app_rounded,
            iconColor: context.tokens.cobalt,
          ),
          SizedBox(height: 8),
          _buildWorkflowItem(
            isDark: isDark,
            number: "2",
            title: "Income: Savings Choice Toggle",
            description:
                "Switch 'Reserve for Savings' ON to allocate a percentage (e.g. 20%), or toggle it OFF to keep 100% liquid for expenses.",
            icon: Icons.tune_rounded,
            iconColor: context.tokens.emerald,
          ),
          SizedBox(height: 8),
          _buildWorkflowItem(
            isDark: isDark,
            number: "3",
            title: "Expense: Category Deduction",
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
            "Budgets & Category Limits",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: titleColor,
            ),
          ),
          SizedBox(height: 6),
          Text(
            "Exact workflow to control spending ceilings",
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'Manrope', fontSize: 13, color: bodyColor),
          ),
          SizedBox(height: 16),
          _buildWorkflowItem(
            isDark: isDark,
            number: "1",
            title: "Navigate to Budgets Tab",
            description:
                "Tap the 3rd icon (Pie Chart) on the bottom navigation bar to review all category budgets.",
            icon: Icons.folder_open_rounded,
            iconColor: const Color(0xFFA78BFA),
          ),
          SizedBox(height: 8),
          _buildWorkflowItem(
            isDark: isDark,
            number: "2",
            title: "Tap Any Category to Set Limit",
            description:
                "Tap Groceries, Housing, etc., to establish monthly limits. Dynamic health bars show Normal (Green), Warning (Orange), or Exceeded (Red).",
            icon: Icons.linear_scale_rounded,
            iconColor: context.tokens.emerald,
          ),
          SizedBox(height: 8),
          _buildWorkflowItem(
            isDark: isDark,
            number: "3",
            title: "Create Custom Categories",
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
            "Scheduled Bills & 1-Tap Pay",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: titleColor,
            ),
          ),
          SizedBox(height: 6),
          Text(
            "Automate bills & eliminate late fee surprises",
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'Manrope', fontSize: 13, color: bodyColor),
          ),
          SizedBox(height: 16),
          _buildWorkflowItem(
            isDark: isDark,
            number: "1",
            title: "Schedule Recurring or One-Time Bills",
            description:
                "Add subscriptions, rent, or utilities under Weekly, Monthly, or Yearly cadences with automated push reminder alerts.",
            icon: Icons.calendar_month_rounded,
            iconColor: context.tokens.cobalt,
          ),
          SizedBox(height: 8),
          _buildWorkflowItem(
            isDark: isDark,
            number: "2",
            title: "1-Tap 'Pay Now' Execution",
            description:
                "When a bill is due, tap 'Pay Now' with 1 tap. Aureli records the payment in your expense ledger and rolls recurring bills forward!",
            icon: Icons.payment_rounded,
            iconColor: context.tokens.emerald,
          ),
          SizedBox(height: 8),
          _buildWorkflowItem(
            isDark: isDark,
            number: "3",
            title: "Manage Debts & Loans",
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
            "Analytics & Personalization",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: titleColor,
            ),
          ),
          SizedBox(height: 6),
          Text(
            "Tailor your Aureli experience to your style",
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'Manrope', fontSize: 13, color: bodyColor),
          ),
          SizedBox(height: 16),
          _buildWorkflowItem(
            isDark: isDark,
            number: "1",
            title: "Analytics & Trends",
            description:
                "Tap the 4th tab to visualize historical 6-month trends and category spending distribution graphs.",
            icon: Icons.insights_rounded,
            iconColor: context.tokens.amber,
          ),
          SizedBox(height: 8),
          _buildWorkflowItem(
            isDark: isDark,
            number: "2",
            title: "Dark & Light (White) Themes",
            description:
                "Tap your avatar (top right) → 'App Theme' to toggle between obsidian glassmorphic dark mode and clean white light mode.",
            icon: Icons.brightness_6_rounded,
            iconColor: const Color(0xFF8B5CF6),
          ),
          SizedBox(height: 8),
          _buildWorkflowItem(
            isDark: isDark,
            number: "3",
            title: "Replay This Guide Anytime",
            description:
                "Need a refresher? Open Profile → 'App Guided Tour' to reopen this tutorial anytime.",
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
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: gradientColors.first.withValues(alpha: 0.4),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Icon(icon, color: context.textPrimary, size: 32),
    );
  }

  Widget _buildFormulaCard(bool isDark) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: context.tokens.emerald.withValues(alpha: isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: context.tokens.emerald.withValues(alpha: 0.35),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.calculate_rounded, color: context.tokens.emerald, size: 18),
          SizedBox(width: 8),
          Flexible(
            child: Text(
              "Allowance = Income − Savings − Bills",
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: context.tokens.emerald,
              ),
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
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: itemBorder, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
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
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: titleColor,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  description,
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 12,
                    height: 1.35,
                    color: bodyColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
