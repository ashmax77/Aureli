import 'package:aureli/theme/app_colors.dart';
import 'package:aureli/models/transaction_model.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../providers/budget_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../models/category_model.dart';
import '../../models/budget_summary_model.dart';
import '../../widgets/glass_card.dart';
import '../profile/profile_view.dart';
import '../../providers/scheduled_transaction_provider.dart';
import '../scheduled/scheduled_transactions_view.dart';
import '../../providers/debt_provider.dart';
import '../debts/debt_management_view.dart';
import '../../services/secure_storage_service.dart';
import '../../widgets/svg_icons.dart';
import '../../widgets/pending_sync_badge.dart';
import 'package:flutter_animate/flutter_animate.dart';

class DashboardView extends StatefulWidget {
  final VoidCallback onViewTransactions;
  final VoidCallback onViewBudgets;
  final VoidCallback onViewAnalytics;

  const DashboardView({
    super.key,
    required this.onViewTransactions,
    required this.onViewBudgets,
    required this.onViewAnalytics,
  });

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  String _savingsGoalName = "";
  double _savingsGoalAmount = 0.0;

  @override
  void initState() {
    super.initState();
    _loadSavingsGoal();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final budgetProv = Provider.of<BudgetProvider>(context, listen: false);
      final txProv = Provider.of<TransactionProvider>(context, listen: false);
      final schedProv =
          Provider.of<ScheduledTransactionProvider>(context, listen: false);
      final debtProv = Provider.of<DebtProvider>(context, listen: false);

      // Priority 1: Primary visible dashboard metrics (instant visual load)
      Future.wait([
        budgetProv.fetchDashboardSummary(),
        txProv.fetchTransactions(refresh: true),
      ]).then((_) {
        // Priority 2: Stagger non-critical background data to prevent bandwidth contention on slow networks
        if (mounted) {
          txProv.fetchCategories();
          schedProv.fetchScheduledTransactions();
          debtProv.fetchSummary();
        }
      });
    });
  }

  Future<void> _loadSavingsGoal() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final uid = authProvider.userModel?.firebaseUid ?? "default";
    final name = await SecureStorageService.read('savings_goal_name_$uid');
    final amountStr = await SecureStorageService.read('savings_goal_amount_$uid');
    
    if (mounted) {
      setState(() {
        _savingsGoalName = name ?? "";
        _savingsGoalAmount = double.tryParse(amountStr ?? "") ?? 0.0;
      });
    }
  }

  void _changeMonth(int delta) {
    final budgetProvider = Provider.of<BudgetProvider>(context, listen: false);
    int newMonth = budgetProvider.selectedMonth + delta;
    int newYear = budgetProvider.selectedYear;

    if (newMonth > 12) {
      newMonth = 1;
      newYear++;
    } else if (newMonth < 1) {
      newMonth = 12;
      newYear--;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    budgetProvider.changeMonth(
      newYear, 
      newMonth,
      registrationDate: authProvider.userModel?.createdAt,
      dashboardOnly: true,
    );
  }

  bool _canGoToPreviousMonth() {
    final budgetProvider = Provider.of<BudgetProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final registrationDate = authProvider.userModel?.createdAt;
    if (registrationDate == null) return true;

    // Calculate previous month's year and month
    int prevMonth = budgetProvider.selectedMonth - 1;
    int prevYear = budgetProvider.selectedYear;
    if (prevMonth < 1) {
      prevMonth = 12;
      prevYear--;
    }

    // Compare year and month
    if (prevYear < registrationDate.year) {
      return false;
    }
    if (prevYear == registrationDate.year &&
        prevMonth < registrationDate.month) {
      return false;
    }

    return true;
  }

  String _formatExpenseDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final itemDay = DateTime(date.year, date.month, date.day);

    if (itemDay == today) {
      return "Today, ${DateFormat('hh:mm a').format(date)}";
    } else if (itemDay == today.subtract(const Duration(days: 1))) {
      return "Yesterday, ${DateFormat('hh:mm a').format(date)}";
    } else if (now.year == date.year) {
      return DateFormat('MMM d, hh:mm a').format(date);
    } else {
      return DateFormat('MMM d, yyyy').format(date);
    }
  }

  Widget _buildTopCategoryCard(CategoryBudgetSummary cat, int index) {
    final categories =
        Provider.of<TransactionProvider>(context, listen: false).categories;
    final matches = categories.where((c) =>
        c.id == cat.categoryId ||
        c.name.toLowerCase() == cat.categoryName.toLowerCase());
    final categoryModel = matches.isNotEmpty ? matches.first : null;
    final color = categoryModel?.color ??
        CategoryModel
            .defaultPalette[index % CategoryModel.defaultPalette.length];

    return GlassCard(
      padding: EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: AppSvgIcons.getCategorySvg(
              categoryModel?.iconKey,
              cat.categoryName,
              color: color,
              size: 22,
            ),
          ),
          SizedBox(height: 10),
          Text(
            cat.categoryName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white
                  : context.tokens.ink,
            ),
          ),
          SizedBox(height: 4),
          Text(
            "LKR ${NumberFormat('#,##0').format(cat.totalSpent)}",
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white.withValues(alpha: 0.75)
                  : context.tokens.inkSecondary,
            ),
          ),
        ],
      ),
    );
  }
  void _showSavingsGoalDialog(BuildContext context) {
    final nameController = TextEditingController(text: _savingsGoalName);
    final amountController = TextEditingController(text: _savingsGoalAmount > 0 ? _savingsGoalAmount.toStringAsFixed(0) : "");

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final mediaQuery = MediaQuery.of(context);
        final systemBottomPadding = mediaQuery.viewInsets.bottom > 0 ? mediaQuery.viewInsets.bottom : mediaQuery.padding.bottom;
        final effectiveBottomPadding = (systemBottomPadding > 0 ? systemBottomPadding : 16.0) + 24.0;
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return Padding(
          padding: EdgeInsets.only(bottom: mediaQuery.viewInsets.bottom),
          child: Container(
            decoration: BoxDecoration(
              color: context.cardLightBg,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: EdgeInsets.only(left: 24, right: 24, top: 24, bottom: effectiveBottomPadding),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                SizedBox(height: 16),
                Row(
                  children: [
                    Icon(Icons.flag_rounded, color: context.tokens.emerald, size: 24),
                    SizedBox(width: 10),
                    Text(
                      "Set Savings Goal",
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: context.textPrimary,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Text(
                  "Give your savings a purpose. What are you saving up for?",
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 13,
                    color: context.tokens.inkSecondary,
                  ),
                ),
                SizedBox(height: 20),
                TextFormField(
                  controller: nameController,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black, fontFamily: 'Manrope'),
                  decoration: InputDecoration(
                    labelText: "Goal Name (e.g. New MacBook)",
                    labelStyle: TextStyle(color: isDark ? Colors.white54 : Colors.black54),
                    enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.grey.shade300), borderRadius: BorderRadius.circular(12)),
                    focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: context.tokens.emerald), borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                SizedBox(height: 16),
                TextFormField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black, fontFamily: 'Manrope'),
                  decoration: InputDecoration(
                    labelText: "Target Amount (LKR)",
                    labelStyle: TextStyle(color: isDark ? Colors.white54 : Colors.black54),
                    enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.grey.shade300), borderRadius: BorderRadius.circular(12)),
                    focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: context.tokens.emerald), borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () async {
                    final authProvider = Provider.of<AuthProvider>(context, listen: false);
                    final uid = authProvider.userModel?.firebaseUid ?? "default";
                    final newName = nameController.text.trim();
                    final newAmount = double.tryParse(amountController.text.trim()) ?? 0.0;
                    
                    await SecureStorageService.write('savings_goal_name_$uid', newName);
                    await SecureStorageService.write('savings_goal_amount_$uid', newAmount.toString());
                    
                    setState(() {
                      _savingsGoalName = newName;
                      _savingsGoalAmount = newAmount;
                    });
                    
                    if (context.mounted) Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.tokens.brand,
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text("Save Goal", style: TextStyle(fontFamily: 'Manrope', fontSize: 16, fontWeight: FontWeight.bold, color: context.textPrimary)),
                ),
              ],
            ),
          ),
        );
      }
    );
  }

  void _showSavingsRateDialog(BuildContext context, double currentRate) {
    double tempRate = currentRate.clamp(5.0, 20.0);
    showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (context) => StatefulBuilder(
              builder: (context, setSheetState) {
                final mediaQuery = MediaQuery.of(context);
                final systemBottomPadding = mediaQuery.viewPadding.bottom > 0
                    ? mediaQuery.viewPadding.bottom
                    : mediaQuery.padding.bottom;
                final effectiveBottomPadding =
                    (systemBottomPadding > 0 ? systemBottomPadding : 16.0) +
                        24.0;

                final isDark = Theme.of(context).brightness == Brightness.dark;
                return Container(
                  decoration: BoxDecoration(
                    color: context.cardLightBg,
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  padding: EdgeInsets.only(
                    left: 24,
                    right: 24,
                    top: 24,
                    bottom: effectiveBottomPadding,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color:
                                isDark ? Colors.white24 : Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      SizedBox(height: 16),
                      Row(
                        children: [
                          Icon(Icons.savings_rounded,
                              color: context.tokens.amber, size: 24),
                          SizedBox(width: 10),
                          Text(
                            "Monthly Savings Rate Target",
                            style: TextStyle(
                              fontFamily: 'Manrope',
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: context.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text(
                        "Select what percentage of your monthly income/salary to automatically reserve in your cumulative Savings Vault. Mandatory range is 5% to 20%.",
                        style: TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 13,
                          color: context.tokens.inkSecondary,
                        ),
                      ),
                      SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("Savings Rate",
                              style: TextStyle(
                                  color: context.iconSecondary,
                                  fontWeight: FontWeight.w600)),
                          Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: context.tokens.amber.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              "${tempRate.toInt()}%",
                              style: TextStyle(
                                fontFamily: 'Manrope',
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: context.tokens.amber,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Slider(
                        value: tempRate,
                        min: 5.0,
                        max: 20.0,
                        divisions: 15,
                        activeColor: context.tokens.amber,
                        inactiveColor:
                            context.tokens.hairline,
                        onChanged: (val) => setSheetState(() => tempRate = val),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("Min: 5%",
                              style: TextStyle(
                                  color: context.tokens.inkMuted,
                                  fontSize: 11)),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AppSvgIcons.sparkles(
                                  size: 13, color: context.tokens.emerald),
                              SizedBox(width: 4),
                              Text("Recommended: 20%",
                                  style: TextStyle(
                                      color: context.tokens.emerald,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                          Text("Max: 20%",
                              style: TextStyle(
                                  color: context.tokens.inkMuted,
                                  fontSize: 11)),
                        ],
                      ),
                      SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () async {
                          final authProv =
                              Provider.of<AuthProvider>(context, listen: false);
                          final budgetProv = Provider.of<BudgetProvider>(
                              context,
                              listen: false);
                          // Grab the messenger first: the sheet's own context is gone once popped.
                          final messenger = ScaffoldMessenger.of(context);
                          Navigator.pop(context);
                          final success =
                              await authProv.updateSavingsRate(tempRate);
                          if (success) {
                            budgetProv.fetchSummary();
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(
                                    "Savings rate updated to ${tempRate.toInt()}%!"),
                                backgroundColor: context.tokens.brand,
                              ),
                            );
                          } else {
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(authProv.actionErrorMessage ??
                                    "Could not update your savings rate"),
                                backgroundColor: context.tokens.coral,
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: context.tokens.brand,
                          padding: EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text("Save Rate Target",
                            style: TextStyle(
                                color: context.textPrimary,
                                fontWeight: FontWeight.bold)),
                      ),
                      SizedBox(height: 16),
                    ],
                  ),
                );
              },
            ));
  }

  Widget _buildSavingsVaultCard({
    required BuildContext context,
    required double cumulativeSavings,
    required double monthlyReservedSavings,
    required double savingsRate,
    required double spendableAllowance,
    required double totalIncome,
    required double scheduledBills,
    required double unallocatedAllowance,
  }) {
    final textPrimary = context.textPrimary;
    final textSecondary =
        context.tokens.inkSecondary;
    final textMuted =
        context.tokens.inkMuted;

    return GlassCard(
      padding: EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: context.tokens.amber.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.savings_rounded,
                        color: context.tokens.amber, size: 20),
                  ),
                  SizedBox(width: 10),
                  Text(
                    "SAVINGS VAULT",
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: context.tokens.amber,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: () => _showSavingsRateDialog(context, savingsRate),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: context.tokens.inputFill,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color:
                            context.tokens.hairline),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "${savingsRate.toInt()}% Target",
                        style: TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: textSecondary,
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(Icons.edit_rounded, color: textMuted, size: 12),
                    ],
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Text(
            "Cumulative Total Saved",
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: textMuted,
            ),
          ),
          SizedBox(height: 4),
          Text(
            "LKR ${NumberFormat('#,##0').format(cumulativeSavings)}",
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          
          if (_savingsGoalName.isNotEmpty && _savingsGoalAmount > 0) ...[
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.flag_rounded, color: context.tokens.emerald, size: 14),
                    SizedBox(width: 4),
                    Text(
                      "Goal: $_savingsGoalName",
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: textSecondary,
                      ),
                    ),
                  ],
                ),
                InkWell(
                  onTap: () => _showSavingsGoalDialog(context),
                  child: Text(
                    "LKR ${NumberFormat('#,##0').format(_savingsGoalAmount)}",
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: context.tokens.emerald,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (_savingsGoalAmount > 0) ? (cumulativeSavings / _savingsGoalAmount).clamp(0.0, 1.0) : 0,
                minHeight: 6,
                backgroundColor: context.tokens.hairline,
                valueColor: AlwaysStoppedAnimation<Color>(context.tokens.emerald),
              ),
            ),
          ] else ...[
            SizedBox(height: 12),
            InkWell(
              onTap: () => _showSavingsGoalDialog(context),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: BoxDecoration(
                  color: context.tokens.inputFill,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: context.tokens.hairline, style: BorderStyle.solid),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.flag_rounded, size: 14, color: context.tokens.emerald),
                    SizedBox(width: 6),
                    Text("Set a Savings Goal", style: TextStyle(fontFamily: 'Manrope', fontSize: 12, fontWeight: FontWeight.bold, color: textSecondary)),
                  ],
                ),
              ),
            ),
          ],
          
          SizedBox(height: 16),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: context.tokens.emerald.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border:
                  Border.all(color: context.tokens.emerald.withValues(alpha: 0.25)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.lock_outline_rounded,
                        color: context.tokens.emerald, size: 16),
                    SizedBox(width: 6),
                    Text(
                      "Reserved this month",
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 12,
                        color: textSecondary,
                      ),
                    ),
                  ],
                ),
                Text(
                  "+ LKR ${NumberFormat('#,##0').format(monthlyReservedSavings)}",
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: context.tokens.emerald,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 14),
          Divider(color: context.divider, height: 1),
          SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "SPENDABLE ALLOWANCE",
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: textMuted,
                      letterSpacing: 0.8,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    "LKR ${NumberFormat('#,##0').format(spendableAllowance)}",
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: textPrimary,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    "UNALLOCATED TO BUDGETS",
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: textMuted,
                      letterSpacing: 0.8,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    "LKR ${NumberFormat('#,##0').format(unallocatedAllowance)}",
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: unallocatedAllowance > 0
                          ? context.tokens.cobalt
                          : textMuted,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNetDebtSummaryCard(BuildContext context) {
    final debtProv = Provider.of<DebtProvider>(context);
    final debtSummary = debtProv.summary;
    final double netPos = debtSummary?.netDebtPosition ?? 0.0;
    final bool isPositive = netPos >= 0;
    final Color positionColor =
        isPositive ? context.tokens.emerald : context.tokens.coral;

    final textSecondary =
        context.tokens.inkSecondary;
    final textMuted =
        context.tokens.inkMuted;

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const DebtManagementView()),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: GlassCard(
        padding: EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: context.tokens.cobalt.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.account_balance_rounded,
                          color: context.tokens.cobalt, size: 18),
                    ),
                    SizedBox(width: 10),
                    Text(
                      "LOAN & DEBT POSITION",
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: context.tokens.cobalt,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Text(
                      "Ledger",
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: textSecondary,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(Icons.arrow_forward_ios_rounded,
                        color: textMuted, size: 12),
                  ],
                ),
              ],
            ),
            SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Net Debt Balance",
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 11,
                        color: textSecondary,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      "${isPositive ? '+' : '-'} LKR ${NumberFormat('#,##0').format(netPos.abs())}",
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: positionColor,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: positionColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: positionColor.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    isPositive ? "Net Creditor" : "Net Debtor",
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: positionColor,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    "Lent: LKR ${NumberFormat('#,##0').format(debtSummary?.totalLent ?? 0)}",
                    style: TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 11,
                        color: context.tokens.emerald,
                        fontWeight: FontWeight.w600),
                  ),
                ),
                Expanded(
                  child: Text(
                    "Borrowed: LKR ${NumberFormat('#,##0').format(debtSummary?.totalBorrowed ?? 0)}",
                    style: TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 11,
                        color: context.tokens.coral,
                        fontWeight: FontWeight.w600),
                    textAlign: TextAlign.end,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentMethodSpendableCard({
    required BuildContext context,
    required double cashSpendable,
    required double cashSpent,
    required double bankTransferSpendable,
    required double bankTransferSpent,
  }) {
    final double cashRemaining =
        (cashSpendable - cashSpent).clamp(0.0, double.infinity);
    final double cashProgress = cashSpendable > 0
        ? (cashSpent / cashSpendable).clamp(0.0, 1.0)
        : (cashSpent > 0 ? 1.0 : 0.0);

    final double bankRemaining =
        (bankTransferSpendable - bankTransferSpent).clamp(0.0, double.infinity);
    final double bankProgress = bankTransferSpendable > 0
        ? (bankTransferSpent / bankTransferSpendable).clamp(0.0, 1.0)
        : (bankTransferSpent > 0 ? 1.0 : 0.0);

    final textSecondary =
        context.tokens.inkSecondary;
    final textMuted =
        context.tokens.inkMuted;

    return GlassCard(
      padding: EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: context.tokens.emerald.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.payments_rounded,
                        color: context.tokens.emerald, size: 18),
                  ),
                  SizedBox(width: 10),
                  Text(
                    "SPENDABLE ALLOWANCE BY METHOD",
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: context.tokens.emerald,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 16),

          // 1. CASH SECTION
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.account_balance_wallet_rounded,
                          color: context.tokens.emerald, size: 16),
                      SizedBox(width: 6),
                      Text(
                        "Cash Spendable",
                        style: TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: context.textPrimary),
                      ),
                    ],
                  ),
                  Text(
                    "LKR ${NumberFormat('#,##0').format(cashSpendable)}",
                    style: TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: context.tokens.emerald),
                  ),
                ],
              ),
              SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: cashProgress,
                  minHeight: 7,
                  backgroundColor:
                      context.tokens.hairline,
                  valueColor: AlwaysStoppedAnimation<Color>(cashProgress >= 1.0
                      ? context.tokens.coral
                      : context.tokens.emerald),
                ),
              ),
              SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Consumed: LKR ${NumberFormat('#,##0').format(cashSpent)}",
                    style: TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 11,
                        color: textSecondary,
                        fontWeight: FontWeight.w500),
                  ),
                  Text(
                    "Remains: LKR ${NumberFormat('#,##0').format(cashRemaining)}",
                    style: TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 11,
                        color: cashRemaining > 0
                            ? context.tokens.emerald
                            : textMuted,
                        fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),

          SizedBox(height: 16),
          Divider(color: context.divider, height: 1),
          SizedBox(height: 16),

          // 2. BANK TRANSFER SECTION
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.account_balance_rounded,
                          color: context.tokens.emerald, size: 16),
                      SizedBox(width: 6),
                      Text(
                        "Bank Transfer Spendable",
                        style: TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: context.textPrimary),
                      ),
                    ],
                  ),
                  Text(
                    "LKR ${NumberFormat('#,##0').format(bankTransferSpendable)}",
                    style: TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: context.tokens.emerald),
                  ),
                ],
              ),
              SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: bankProgress,
                  minHeight: 7,
                  backgroundColor:
                      context.tokens.hairline,
                  valueColor: AlwaysStoppedAnimation<Color>(bankProgress >= 1.0
                      ? context.tokens.coral
                      : context.tokens.emerald),
                ),
              ),
              SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Consumed: LKR ${NumberFormat('#,##0').format(bankTransferSpent)}",
                    style: TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 11,
                        color: textSecondary,
                        fontWeight: FontWeight.w500),
                  ),
                  Text(
                    "Remains: LKR ${NumberFormat('#,##0').format(bankRemaining)}",
                    style: TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 11,
                        color: bankRemaining > 0
                            ? context.tokens.emerald
                            : textMuted,
                        fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final budgetProvider = Provider.of<BudgetProvider>(context);
    Provider.of<AuthProvider>(context);
    final transactionProvider = Provider.of<TransactionProvider>(context);
    final summary = budgetProvider.dashboardSummary ?? budgetProvider.summary;

    final monthName = DateFormat('MMMM').format(
      DateTime(budgetProvider.selectedYear, budgetProvider.selectedMonth),
    );

    // Budget Calculations
    final double totalBudget = summary?.categoryBudgets.fold<double>(
          0.0,
          (sum, b) => sum + (b.amountLimit ?? 0.0),
        ) ??
        0.0;
    final double totalSpent = summary?.totalExpenses ?? 0.0;
    final double totalIncome = summary?.totalIncome ?? 0.0;
    final double netCashFlow =
        summary?.netCashFlow ?? (totalIncome - totalSpent);
    final double remaining = totalBudget - totalSpent;
    final bool hasBudget = totalBudget > 0;
    final bool isOver = hasBudget && totalSpent > totalBudget;
    final double progress =
        hasBudget ? (totalSpent / totalBudget).clamp(0.0, 1.0) : 0.0;
    final int percentUsed =
        hasBudget ? ((totalSpent / totalBudget) * 100).round() : 0;

    // Payment Method breakdowns (Cash & Bank Transfer)
    final double cashSpent =
        (summary?.cashExpenses != null && summary!.cashExpenses > 0)
            ? summary.cashExpenses
            : (summary?.cardExpenses != null && summary!.cardExpenses > 0)
                ? summary.cardExpenses
                : transactionProvider.transactions
                    .where((t) =>
                        t.type == TransactionType.EXPENSE &&
                        t.paymentMethod == PaymentMethod.CASH &&
                        t.transactionDate.year == budgetProvider.selectedYear &&
                        t.transactionDate.month == budgetProvider.selectedMonth)
                    .fold<double>(0.0, (sum, t) => sum + t.amount);

    final double bankTransferSpent = (summary?.bankTransferExpenses != null &&
            summary!.bankTransferExpenses > 0)
        ? summary.bankTransferExpenses
        : transactionProvider.transactions
            .where((t) =>
                t.type == TransactionType.EXPENSE &&
                t.paymentMethod == PaymentMethod.BANK_TRANSFER &&
                t.transactionDate.year == budgetProvider.selectedYear &&
                t.transactionDate.month == budgetProvider.selectedMonth)
            .fold<double>(0.0, (sum, t) => sum + t.amount);

    final double totalAmountToSpend =
        hasBudget ? totalBudget : (summary?.spendableAllowance ?? 0.0);

    Color statusColor = context.tokens.emerald;
    String statusLabel = "On track";
    IconData statusIcon = Icons.check_circle_rounded;

    if (!hasBudget) {
      statusColor = Colors.white38;
      statusLabel = "No limit set";
      statusIcon = Icons.info_outline_rounded;
    } else if (isOver) {
      statusColor = context.tokens.coral;
      statusLabel = "Over budget";
      statusIcon = Icons.warning_amber_rounded;
    } else if (percentUsed >= 90) {
      statusColor = context.tokens.amber;
      statusLabel = "Nearing limit";
      statusIcon = Icons.trending_up_rounded;
    }

    // Previous month comparison
    final prevMonthDate = DateTime(
      budgetProvider.selectedYear,
      budgetProvider.selectedMonth - 1,
    );
    final prevMonthName = DateFormat('MMMM').format(prevMonthDate);
    final double prevSpent = summary?.previousMonthExpenses ?? 0.0;
    String? trendText;
    Widget? trendIconWidget;
    Color trendColor = context.tokens.emerald;
    Color trendBg = context.tokens.emerald.withValues(alpha: 0.15);

    if (prevSpent > 0 && summary != null) {
      final double diff = ((totalSpent - prevSpent) / prevSpent) * 100;
      if (diff > 0) {
        trendText =
            "${diff.abs().toStringAsFixed(1)}% more than $prevMonthName";
        trendColor = context.tokens.coral;
        trendBg = context.tokens.coral.withValues(alpha: 0.15);
        trendIconWidget = AppSvgIcons.trendingUp(size: 13, color: trendColor);
      } else if (diff < 0) {
        trendText =
            "${diff.abs().toStringAsFixed(1)}% less than $prevMonthName";
        trendColor = context.tokens.emerald;
        trendBg = context.tokens.emerald.withValues(alpha: 0.15);
        trendIconWidget = AppSvgIcons.trendingDown(size: 13, color: trendColor);
      } else {
        trendText = "Same as $prevMonthName";
        trendColor = Colors.white70;
        trendBg = Colors.white10;
      }
    }

    // Top categories
    final topCategories = summary != null
        ? (List<CategoryBudgetSummary>.from(
            summary.categoryBudgets,
          ).where((c) => c.totalSpent > 0).toList()
          ..sort((a, b) => b.totalSpent.compareTo(a.totalSpent)))
        : <CategoryBudgetSummary>[];
    final displayTop = topCategories.take(3).toList();

    // Recent expenses
    final recentExpenses = transactionProvider.transactions
        .where((t) => t.type == TransactionType.EXPENSE)
        .take(3)
        .toList();

    final textPrimary = context.textPrimary;
    final textSecondary =
        context.tokens.inkSecondary;
    final textMuted =
        context.tokens.inkMuted;
    final dividerColor = context.tokens.hairline;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          "Aureli",
          style: TextStyle(
            fontFamily: 'Manrope',
            fontWeight: FontWeight.bold,
            color: textPrimary,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: const [UserProfileAvatarIcon()],
      ),
      body: budgetProvider.isLoading
          ? Center(
              child: CircularProgressIndicator(color: context.tokens.emerald),
            )
          : RefreshIndicator(
              onRefresh: () async {
                final budgetProv =
                    Provider.of<BudgetProvider>(context, listen: false);
                final txProv =
                    Provider.of<TransactionProvider>(context, listen: false);
                final schedProv = Provider.of<ScheduledTransactionProvider>(
                    context,
                    listen: false);
                await Future.wait([
                  budgetProv.fetchDashboardSummary(force: true),
                  txProv.fetchTransactions(refresh: true),
                  schedProv.fetchScheduledTransactions(),
                ]);
              },
              color: context.tokens.emerald,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.symmetric(horizontal: 20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. Date Selector
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.chevron_left_rounded,
                            color: _canGoToPreviousMonth()
                                ? (context.iconSecondary)
                                : (context.divider),
                          ),
                          onPressed: _canGoToPreviousMonth()
                              ? () => _changeMonth(-1)
                              : null,
                        ),
                        Text(
                          "$monthName ${budgetProvider.selectedYear}",
                          style: TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: textPrimary,
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.chevron_right_rounded,
                            color: context.iconSecondary,
                          ),
                          onPressed: () => _changeMonth(1),
                        ),
                      ],
                    ).animate().fade(duration: 400.ms).slideY(begin: -0.1),
                    SizedBox(height: 12),

                    // 2. Financial Summary Card (Spent this month, Total to Spend & Payment Methods Breakdown)
                    GlassCard(
                      padding: EdgeInsets.all(20.0),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "TOTAL EXPENDITURE",
                                style: TextStyle(
                                  fontFamily: 'Manrope',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: textSecondary,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              if (totalAmountToSpend > 0)
                                Container(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: context.tokens.cobalt
                                        .withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    "Total to spend: LKR ${NumberFormat('#,##0').format(totalAmountToSpend)}",
                                    style: TextStyle(
                                      fontFamily: 'Manrope',
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: context.tokens.cobalt,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          SizedBox(height: 8),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                "LKR ${NumberFormat('#,##0').format(totalSpent)}",
                                style: TextStyle(
                                  fontFamily: 'Manrope',
                                  fontSize: 30,
                                  fontWeight: FontWeight.bold,
                                  color: context.textPrimary,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              SizedBox(width: 8),
                              Text(
                                "already spent",
                                style: TextStyle(
                                  fontFamily: 'Manrope',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: textMuted,
                                ),
                              ),
                            ],
                          ),
                          if (trendText != null) ...[
                            SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: trendBg,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (trendIconWidget != null) ...[
                                      trendIconWidget,
                                      SizedBox(width: 4),
                                    ],
                                    Text(
                                      trendText,
                                      style: TextStyle(
                                        fontFamily: 'Manrope',
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: trendColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                          SizedBox(height: 16),

                          // Payment Method Breakdown: Cash vs Bank Transfer
                          Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.04),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: context.divider),
                            ),
                            child: Row(
                              children: [
                                // Cash Payments
                                Expanded(
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: context.tokens.emerald
                                              .withValues(alpha: 0.18),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Icon(
                                          Icons.account_balance_wallet_rounded,
                                          color: context.tokens.emerald,
                                          size: 16,
                                        ),
                                      ),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              "Cash",
                                              style: TextStyle(
                                                fontFamily: 'Manrope',
                                                fontSize: 11,
                                                color: context.textPrimary
                                                    .withValues(alpha: 0.6),
                                              ),
                                            ),
                                            Text(
                                              "LKR ${NumberFormat('#,##0').format(cashSpent)}",
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontFamily: 'Manrope',
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                                color: context.textPrimary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  width: 1,
                                  height: 30,
                                  color: context.divider,
                                ),
                                SizedBox(width: 10),
                                // Bank Transfers
                                Expanded(
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: context.tokens.emerald
                                              .withValues(alpha: 0.18),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Icon(
                                          Icons.account_balance_rounded,
                                          color: context.tokens.emerald,
                                          size: 16,
                                        ),
                                      ),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              "Bank Transfer",
                                              style: TextStyle(
                                                fontFamily: 'Manrope',
                                                fontSize: 11,
                                                color: context.textPrimary
                                                    .withValues(alpha: 0.6),
                                              ),
                                            ),
                                            Text(
                                              "LKR ${NumberFormat('#,##0').format(bankTransferSpent)}",
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontFamily: 'Manrope',
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                                color: context.textPrimary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 16),
                          Divider(color: context.divider, height: 1),
                          SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  children: [
                                    Text(
                                      "TOTAL INCOME",
                                      style: TextStyle(
                                        fontFamily: 'Manrope',
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white.withValues(alpha: 0.5),
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      "LKR ${NumberFormat('#,##0').format(totalIncome)}",
                                      style: TextStyle(
                                        fontFamily: 'Manrope',
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: context.tokens.emerald,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                width: 1,
                                height: 28,
                                color: context.divider,
                              ),
                              Expanded(
                                child: Column(
                                  children: [
                                    Text(
                                      "NET CASH FLOW",
                                      style: TextStyle(
                                        fontFamily: 'Manrope',
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white.withValues(alpha: 0.5),
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      "${netCashFlow >= 0 ? '+' : ''}LKR ${NumberFormat('#,##0').format(netCashFlow)}",
                                      style: TextStyle(
                                        fontFamily: 'Manrope',
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: netCashFlow >= 0
                                            ? context.tokens.emerald
                                            : context.tokens.coral,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 16),

                    // 2.5 Savings Vault & Spendable Allowance Card
                    _buildSavingsVaultCard(
                      context: context,
                      cumulativeSavings: summary?.cumulativeSavings ?? 0.0,
                      monthlyReservedSavings:
                          summary?.monthlyReservedSavings ?? 0.0,
                      savingsRate: summary?.savingsRatePercentage ?? 20.0,
                      spendableAllowance: summary?.spendableAllowance ?? 0.0,
                      totalIncome: totalIncome,
                      scheduledBills: summary?.scheduledPaymentsTotal ?? 0.0,
                      unallocatedAllowance:
                          summary?.unallocatedAllowance ?? 0.0,
                    ).animate().fade(duration: 500.ms, delay: 300.ms).slideY(begin: 0.1),
                    SizedBox(height: 16),

                    // 2.6 Net Debt Position Card
                    _buildNetDebtSummaryCard(context).animate().fade(duration: 500.ms, delay: 400.ms).slideY(begin: 0.1),
                    SizedBox(height: 16),

                    // 2.7 Payment Method Spendable Allowance Card (Cash vs Bank Transfer)
                    _buildPaymentMethodSpendableCard(
                      context: context,
                      cashSpendable: summary?.cashSpendable ?? 0.0,
                      cashSpent: cashSpent,
                      bankTransferSpendable:
                          summary?.bankTransferSpendable ?? 0.0,
                      bankTransferSpent: bankTransferSpent,
                    ).animate().fade(duration: 500.ms, delay: 500.ms).slideY(begin: 0.1),
                    SizedBox(height: 24),

                    // 3. Complete Budget Overview Card
                    InkWell(
                      onTap: widget.onViewBudgets,
                      borderRadius: BorderRadius.circular(16),
                      child: GlassCard(
                        padding: EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  hasBudget
                                      ? "LKR ${NumberFormat('#,##0').format(totalBudget)} budget"
                                      : "Overall Monthly Budget",
                                  style: TextStyle(
                                    fontFamily: 'Manrope',
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white.withValues(alpha: 0.6),
                                  ),
                                ),
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: statusColor.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        statusIcon,
                                        color: statusColor,
                                        size: 13,
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        statusLabel,
                                        style: TextStyle(
                                          fontFamily: 'Manrope',
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: statusColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 8),
                            Text(
                              !hasBudget
                                  ? "Tap to set budgets"
                                  : isOver
                                      ? "LKR ${NumberFormat('#,##0').format(totalSpent - totalBudget)} over budget"
                                      : "LKR ${NumberFormat('#,##0').format(remaining)} remaining",
                              style: TextStyle(
                                fontFamily: 'Manrope',
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: isOver
                                    ? context.tokens.coral
                                    : Colors.white,
                              ),
                            ),
                            SizedBox(height: 16),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: progress,
                                minHeight: 7,
                                backgroundColor: context.tokens.hairline,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  statusColor,
                                ),
                              ),
                            ),
                            SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "0",
                                  style: TextStyle(
                                    fontFamily: 'Manrope',
                                    fontSize: 11,
                                    color: Colors.white.withValues(alpha: 0.4),
                                  ),
                                ),
                                Text(
                                  hasBudget ? "$percentUsed% used" : "0% used",
                                  style: TextStyle(
                                    fontFamily: 'Manrope',
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white.withValues(alpha: 0.6),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ).animate().fade(duration: 500.ms, delay: 600.ms).slideY(begin: 0.1),
                    SizedBox(height: 16),

                    // 3.5 Scheduled Payments Card
                    Consumer<ScheduledTransactionProvider>(
                      builder: (context, scheduledProvider, _) {
                        final upcomingCount = scheduledProvider.upcomingCount;
                        return InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const ScheduledTransactionsScreen(),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: GlassCard(
                            padding: EdgeInsets.symmetric(
                              horizontal: 16.0,
                              vertical: 14.0,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFF6C8CFF,
                                    ).withValues(alpha: 0.18),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    Icons.event_note_rounded,
                                    color: context.tokens.cobalt,
                                    size: 22,
                                  ),
                                ),
                                SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Scheduled Payments",
                                        style: TextStyle(
                                          fontFamily: 'Manrope',
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: context.textPrimary,
                                        ),
                                      ),
                                      SizedBox(height: 2),
                                      Text(
                                        upcomingCount > 0
                                            ? "$upcomingCount upcoming payment${upcomingCount > 1 ? 's' : ''} due"
                                            : "No upcoming payments scheduled",
                                        style: TextStyle(
                                          fontFamily: 'Manrope',
                                          fontSize: 12,
                                          color: upcomingCount > 0
                                              ? context.tokens.emerald
                                              : textMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.chevron_right_rounded,
                                  color: textMuted,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    SizedBox(height: 24),

                    // 4. Top Categories Section
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Top Categories",
                              style: TextStyle(
                                fontFamily: 'Manrope',
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: context.textPrimary,
                              ),
                            ),
                            TextButton(
                              onPressed: widget.onViewBudgets,
                              style: TextButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                              ),
                              child: Text(
                                "See all",
                                style: TextStyle(
                                  fontFamily: 'Manrope',
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: context.tokens.emerald,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 12),
                        if (displayTop.isEmpty)
                          GlassCard(
                            padding: EdgeInsets.symmetric(
                              vertical: 24,
                              horizontal: 16,
                            ),
                            child: Center(
                              child: Text(
                                "No expenses recorded this month",
                                style: TextStyle(
                                  fontFamily: 'Manrope',
                                  color: textMuted,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          )
                        else
                          Row(
                            children: [
                              for (int i = 0; i < displayTop.length; i++) ...[
                                if (i > 0) SizedBox(width: 10),
                                Expanded(
                                  child: _buildTopCategoryCard(
                                    displayTop[i],
                                    i,
                                  ),
                                ),
                              ],
                            ],
                          ),
                      ],
                    ),
                    SizedBox(height: 24),

                    // 5. Recent Expenses Section
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Recent Expenses",
                              style: TextStyle(
                                fontFamily: 'Manrope',
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: textPrimary,
                              ),
                            ),
                            TextButton(
                              onPressed: widget.onViewTransactions,
                              style: TextButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                              ),
                              child: Text(
                                "See all",
                                style: TextStyle(
                                  fontFamily: 'Manrope',
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: context.tokens.emerald,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        if (recentExpenses.isEmpty)
                          GlassCard(
                            padding: EdgeInsets.symmetric(
                              vertical: 24,
                              horizontal: 16,
                            ),
                            child: Center(
                              child: Text(
                                "No recent expenses logged",
                                style: TextStyle(
                                  fontFamily: 'Manrope',
                                  color: textMuted,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          )
                        else
                          GlassCard(
                            padding: EdgeInsets.symmetric(
                              vertical: 4,
                              horizontal: 16,
                            ),
                            child: Column(
                              children: [
                                for (int i = 0;
                                    i < recentExpenses.length;
                                    i++) ...[
                                  if (i > 0)
                                    Divider(
                                      color: dividerColor,
                                      height: 1,
                                    ),
                                  Padding(
                                    padding: EdgeInsets.symmetric(
                                      vertical: 12.0,
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 40,
                                          height: 40,
                                          decoration: BoxDecoration(
                                            color: recentExpenses[i]
                                                .category
                                                .color
                                                .withValues(alpha: 0.18),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          alignment: Alignment.center,
                                          child: AppSvgIcons.getCategorySvg(
                                            recentExpenses[i].category.iconKey,
                                            recentExpenses[i].category.name,
                                            color: recentExpenses[i]
                                                .category
                                                .color,
                                            size: 20,
                                          ),
                                        ),
                                        SizedBox(width: 14),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                (recentExpenses[i].note !=
                                                            null &&
                                                        recentExpenses[i]
                                                            .note!
                                                            .trim()
                                                            .isNotEmpty)
                                                    ? recentExpenses[i].note!
                                                    : recentExpenses[i]
                                                        .category
                                                        .name,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontFamily: 'Manrope',
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                  color: textPrimary,
                                                ),
                                              ),
                                              SizedBox(height: 3),
                                              Text(
                                                _formatExpenseDate(
                                                  recentExpenses[i]
                                                      .transactionDate,
                                                ),
                                                style: TextStyle(
                                                  fontFamily: 'Manrope',
                                                  fontSize: 11,
                                                  color: textMuted,
                                                ),
                                              ),
                                              if (recentExpenses[i].isPending) ...[
                                                SizedBox(height: 3),
                                                PendingSyncBadge(
                                                  transaction: recentExpenses[i],
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          "LKR ${NumberFormat('#,##0').format(recentExpenses[i].amount)}",
                                          style: TextStyle(
                                            fontFamily: 'Manrope',
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: textPrimary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                      ],
                    ),

                    SizedBox(height: 30),
                  ],
                ),
              ),
            ),
    );
  }
}

/// Bottom sheet for adding a transaction, or - when [editing] is set - for editing an
/// existing (already synced) one. Edits are only applied after the user reviews and
/// confirms the changes.
class AddTransactionSheet extends StatefulWidget {
  const AddTransactionSheet({super.key, this.editing});

  final TransactionModel? editing;

  @override
  State<AddTransactionSheet> createState() => _AddTransactionSheetState();
}

class _AddTransactionSheetState extends State<AddTransactionSheet> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final tx = widget.editing;
    if (tx != null) {
      _type = tx.type;
      _selectedCategoryId = tx.category.id;
      _paymentMethod = tx.paymentMethod;
      _selectedDate = tx.transactionDate;
      _noteController.text = tx.note ?? '';
      _amountController.text = tx.amount == tx.amount.roundToDouble()
          ? tx.amount.toStringAsFixed(0)
          : tx.amount.toString();
      _isSavingsEnabled = tx.isSavingsEnabled ?? true;
      final rate = tx.savingsRate;
      if (rate != null && rate > 0) _savingsRate = rate.clamp(5.0, 30.0);
      // Keep the transaction's own savings settings; don't overwrite with the profile default.
      _isSavingsRateInitialized = true;
    }
  }

  /// Human-readable list of what differs from the transaction being edited.
  List<String> _describeChanges(
    TransactionModel old, {
    required String note,
    required double amount,
  }) {
    String method(PaymentMethod m) => m == PaymentMethod.CASH ? 'Cash' : 'Bank Transfer';
    String money(double v) => 'LKR ${NumberFormat('#,##0.##').format(v)}';
    final categories = Provider.of<TransactionProvider>(context, listen: false).categories;
    String categoryName(int? id) => categories
        .firstWhere(
          (c) => c.id == id,
          orElse: () => CategoryModel(id: id ?? 0, name: id == old.category.id ? old.category.name : 'Selected category', type: _type),
        )
        .name;

    final changes = <String>[];
    if (_type != old.type) {
      changes.add('Type: ${old.type.name} → ${_type.name}');
    }
    if (amount != old.amount) {
      changes.add('Amount: ${money(old.amount)} → ${money(amount)}');
    }
    if (_selectedCategoryId != old.category.id) {
      changes.add('Category: ${old.category.name} → ${categoryName(_selectedCategoryId)}');
    }
    if (note != (old.note ?? '')) {
      changes.add('Note: "${old.note ?? ''}" → "$note"');
    }
    if (_paymentMethod != old.paymentMethod) {
      changes.add('Payment: ${method(old.paymentMethod)} → ${method(_paymentMethod)}');
    }
    final oldDay = DateFormat('yyyy-MM-dd').format(old.transactionDate);
    final newDay = DateFormat('yyyy-MM-dd').format(_selectedDate);
    if (oldDay != newDay) {
      changes.add('Date: $oldDay → $newDay');
    }
    if (_type == TransactionType.INCOME) {
      final oldSavings = old.isSavingsEnabled ?? true;
      if (_isSavingsEnabled != oldSavings) {
        changes.add('Savings: ${oldSavings ? 'reserved' : 'not reserved'} → ${_isSavingsEnabled ? 'reserved' : 'not reserved'}');
      } else if (_isSavingsEnabled &&
          (old.savingsRate ?? 0) > 0 &&
          (_savingsRate - old.savingsRate!).abs() > 0.001) {
        changes.add('Savings rate: ${old.savingsRate!.toStringAsFixed(1)}% → ${_savingsRate.toStringAsFixed(1)}%');
      }
    }
    return changes;
  }

  Future<void> _submitEdit(String note, double amount) async {
    final old = widget.editing!;
    final changes = _describeChanges(old, note: note, amount: amount);
    if (changes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No changes to save")),
      );
      _lastSubmitTime = null;
      return;
    }

    // Verification step: the user must explicitly approve exactly what will change.
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Save these changes?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final line in changes)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(line),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save changes'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      _lastSubmitTime = null;
      return;
    }

    setState(() => _isSaving = true);
    final provider = Provider.of<TransactionProvider>(context, listen: false);
    final success = await provider.updateTransaction(
      old.id,
      type: _type,
      categoryId: _selectedCategoryId!,
      amount: amount,
      date: _selectedDate,
      paymentMethod: _paymentMethod,
      note: note,
      isSavingsEnabled: _type == TransactionType.INCOME ? _isSavingsEnabled : null,
      savingsRate: (_type == TransactionType.INCOME && _isSavingsEnabled)
          ? _savingsRate
          : null,
    );
    if (!mounted) return;
    if (success) {
      // Budget / debt summaries refresh via provider.onFinancialDataChanged.
      setState(() => _isSaving = false);
      Navigator.pop(context, true);
    } else {
      setState(() => _isSaving = false);
      _lastSubmitTime = null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.actionErrorMessage ?? "Update failed"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  TransactionType _type = TransactionType.EXPENSE;
  int? _selectedCategoryId;
  PaymentMethod _paymentMethod = PaymentMethod.CASH;
  DateTime _selectedDate = DateTime.now();
  bool _isSaving = false;
  bool _isSavingsEnabled = true;
  double _savingsRate = 20.0;
  bool _isSavingsRateInitialized = false;
  DateTime? _lastSubmitTime;

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  bool _isSubmitted = false;

  Future<void> _submit() async {
    if (_isSaving || _isSubmitted) return;

    // Debounce: prevent rapid duplicate transaction creation
    final now = DateTime.now();
    if (_lastSubmitTime != null &&
        now.difference(_lastSubmitTime!) < const Duration(seconds: 2)) {
      return;
    }
    _lastSubmitTime = now;

    final note = _noteController.text.trim();
    if (note.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please enter a note / description"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final amount = double.tryParse(_amountController.text) ?? 0.0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please enter a valid amount"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (_selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please select a category"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (widget.editing != null) {
      await _submitEdit(note, amount);
      return;
    }

    setState(() {
      _isSaving = true;
      _isSubmitted = true;
    });
    final transactionProvider = Provider.of<TransactionProvider>(
      context,
      listen: false,
    );

    final result = await transactionProvider.createTransaction(
      type: _type,
      categoryId: _selectedCategoryId!,
      amount: amount,
      date: _selectedDate,
      paymentMethod: _paymentMethod,
      note: note,
      isSavingsEnabled:
          _type == TransactionType.INCOME ? _isSavingsEnabled : null,
      savingsRate: (_type == TransactionType.INCOME && _isSavingsEnabled)
          ? _savingsRate
          : null,
    );

    if (mounted) {
      if (result == TransactionCreateResult.success) {
        // Budget, debt and dashboard summaries refresh via onFinancialDataChanged.
        setState(() => _isSaving = false);
        Navigator.pop(context, true);
      } else if (result == TransactionCreateResult.networkError) {
        // DO NOT unlock the button here. Keep it locked while the dialog is visible.
        final bool? shouldSaveOffline = await showDialog<bool>(
          context: context,
          barrierDismissible: false, // Force the user to make a choice
          builder: (ctx) => AlertDialog(
            title: Text('Network Error'),
            content: Text(
                'Failed to connect to the server. Do you want to save this transaction offline? It will be synced automatically when the connection is restored.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text('Save Offline'),
              ),
            ],
          ),
        );

        if (shouldSaveOffline == true) {
          await transactionProvider.saveTransactionOffline(
            type: _type,
            categoryId: _selectedCategoryId!,
            amount: amount,
            date: _selectedDate,
            paymentMethod: _paymentMethod,
            note: note,
            isSavingsEnabled:
                _type == TransactionType.INCOME ? _isSavingsEnabled : null,
            savingsRate: (_type == TransactionType.INCOME && _isSavingsEnabled)
                ? _savingsRate
                : null,
          );
          if (mounted) {
            Provider.of<BudgetProvider>(context, listen: false).fetchSummary();
            Provider.of<DebtProvider>(context, listen: false).fetchSummary();
            Navigator.pop(context, true);
          }
        } else {
          // User cancelled offline save. Unlock the button so they can retry.
          if (mounted) {
            setState(() {
              _isSaving = false;
              _isSubmitted = false;
            });
          }
        }
      } else {
        setState(() {
          _isSaving = false;
          _isSubmitted = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(transactionProvider.errorMessage ?? "Create failed"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!_isSavingsRateInitialized) {
      _savingsRate = authProvider.userModel?.savingsRatePercentage ?? 20.0;
      _isSavingsRateInitialized = true;
    }

    final transactionProvider = Provider.of<TransactionProvider>(context);
    final categories =
        transactionProvider.categories.where((c) => c.type == _type).toList();
    // The edited transaction's own category may be archived and so missing from the
    // list; keep it selectable or the dropdown would have no matching item.
    final editing = widget.editing;
    if (editing != null &&
        editing.type == _type &&
        !categories.any((c) => c.id == editing.category.id)) {
      categories.add(editing.category);
    }

    final mediaQuery = MediaQuery.of(context);
    final bottomInset = mediaQuery.viewInsets.bottom;
    final systemBottomPadding = mediaQuery.viewPadding.bottom > 0
        ? mediaQuery.viewPadding.bottom
        : mediaQuery.padding.bottom;
    final effectiveBottomPadding = bottomInset +
        (systemBottomPadding > 0 ? systemBottomPadding : 16.0) +
        20.0;

    final sheetBg = context.cardLightBg;
    final textPrimary = context.textPrimary;
    final textSecondary = context.textSecondary;

    return PopScope(
      canPop: !_isSaving,
      child: Container(
        decoration: BoxDecoration(
          color: sheetBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: 20.0,
        left: 20.0,
        right: 20.0,
        bottom: effectiveBottomPadding,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: context.divider,
                  borderRadius: BorderRadius.all(Radius.circular(2)),
                ),
              ),
            ),
            SizedBox(height: 20),
            Text(
              widget.editing != null ? "Edit Transaction" : "Add Transaction",
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textPrimary,
              ),
            ),
            SizedBox(height: 16),

            // Type Toggle (Income / Expense)
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: Center(child: Text("EXPENSE")),
                    selected: _type == TransactionType.EXPENSE,
                    onSelected: (selected) {
                      setState(() {
                        _type = TransactionType.EXPENSE;
                        _selectedCategoryId = null;
                      });
                    },
                    selectedColor: const Color(0xFF0B3B5A),
                    backgroundColor: context.tokens.inputFill,
                    labelStyle: TextStyle(
                      color: _type == TransactionType.EXPENSE
                          ? Colors.white
                          : (context.tokens.inkMuted),
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: ChoiceChip(
                    label: Center(child: Text("INCOME")),
                    selected: _type == TransactionType.INCOME,
                    onSelected: (selected) {
                      setState(() {
                        _type = TransactionType.INCOME;
                        _selectedCategoryId = null;
                      });
                    },
                    selectedColor: context.tokens.emerald,
                    backgroundColor: context.tokens.inputFill,
                    labelStyle: TextStyle(
                      color: _type == TransactionType.INCOME
                          ? Colors.white
                          : (context.tokens.inkMuted),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),

            // Note Field
            TextField(
              controller: _noteController,
              style: TextStyle(color: textPrimary),
              decoration: InputDecoration(
                labelText: "Note",
                labelStyle: TextStyle(color: textSecondary),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(
                      color: context.divider),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: context.tokens.emerald),
                ),
              ),
            ),
            SizedBox(height: 16),

            // Amount Field
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: TextStyle(color: textPrimary),
              decoration: InputDecoration(
                labelText: "Amount (LKR)",
                labelStyle: TextStyle(color: textSecondary),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(
                      color: context.divider),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: context.tokens.emerald),
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
            SizedBox(height: 16),

            if (_type == TransactionType.INCOME) ...[
              Container(
                decoration: BoxDecoration(
                  color: context.tokens.inputFill,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: context.tokens.hairline),
                ),
                padding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: SwitchListTile(
                  activeColor: context.tokens.emerald,
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    "Reserve for Savings",
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      color: textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: Text(
                    _isSavingsEnabled
                        ? "Deduct savings before calculating spendable allowance"
                        : "100% of income is allowed to spend for expenses",
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      color: textSecondary,
                      fontSize: 11,
                    ),
                  ),
                  value: _isSavingsEnabled,
                  onChanged: (val) => setState(() => _isSavingsEnabled = val),
                ),
              ),
              if (_isSavingsEnabled) ...[
                SizedBox(height: 12),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: context.tokens.emerald.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: context.tokens.emerald.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Savings Rate",
                            style: TextStyle(
                              fontFamily: 'Manrope',
                              color: textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            "${_savingsRate.toStringAsFixed(1)}%",
                            style: TextStyle(
                              fontFamily: 'Manrope',
                              color: context.tokens.emerald,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      Slider(
                        value: _savingsRate,
                        min: 5.0,
                        max: 30.0,
                        divisions: 25,
                        activeColor: context.tokens.emerald,
                        inactiveColor:
                            context.divider,
                        label: "${_savingsRate.toStringAsFixed(1)}%",
                        onChanged: (val) => setState(() => _savingsRate = val),
                      ),
                      if ((double.tryParse(_amountController.text) ?? 0) >
                          0) ...[
                        Builder(
                          builder: (context) {
                            final amt =
                                double.tryParse(_amountController.text) ?? 0.0;
                            final sav = amt * (_savingsRate / 100.0);
                            final spend = amt - sav;
                            return Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "Savings: LKR ${NumberFormat('#,##0').format(sav)}",
                                  style: TextStyle(
                                      color: context.tokens.emerald,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  "Spendable: LKR ${NumberFormat('#,##0').format(spend)}",
                                  style: TextStyle(
                                      color: textSecondary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              SizedBox(height: 16),
            ],

            // Category Dropdown
            DropdownButtonFormField<int>(
              value: _selectedCategoryId,
              dropdownColor: sheetBg,
              style: TextStyle(color: textPrimary),
              decoration: InputDecoration(
                labelText: "Category",
                labelStyle: TextStyle(color: textSecondary),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(
                      color: context.divider),
                ),
              ),
              items: categories.map((cat) {
                return DropdownMenuItem<int>(
                  value: cat.id,
                  child: Text(cat.name),
                );
              }).toList(),
              onChanged: (val) {
                setState(() => _selectedCategoryId = val);
              },
            ),
            SizedBox(height: 16),

            // Payment Method Dropdown
            DropdownButtonFormField<PaymentMethod>(
              value: _paymentMethod,
              dropdownColor: sheetBg,
              style: TextStyle(color: textPrimary),
              decoration: InputDecoration(
                labelText: "Payment Method",
                labelStyle: TextStyle(color: textSecondary),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(
                      color: context.divider),
                ),
              ),
              items: PaymentMethod.values.map((method) {
                final label =
                    method == PaymentMethod.CASH ? 'Cash' : 'Bank Transfer';
                return DropdownMenuItem<PaymentMethod>(
                  value: method,
                  child: Text(label),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() => _paymentMethod = val);
                }
              },
            ),
            SizedBox(height: 16),

            // Date picker Trigger
            ListTile(
              title: Text(
                "Transaction Date",
                style: TextStyle(color: textSecondary),
              ),
              subtitle: Text(
                DateFormat('yyyy-MM-dd').format(_selectedDate),
                style: TextStyle(
                  color: textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              trailing: Icon(
                Icons.calendar_today_rounded,
                color: textSecondary,
              ),
              onTap: _selectDate,
              contentPadding: EdgeInsets.zero,
            ),
            SizedBox(height: 32),

            // Save button
            _isSaving
                ? Center(
                    child: CircularProgressIndicator(color: context.tokens.emerald),
                  )
                : ElevatedButton(
                    onPressed: _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: context.tokens.brand,
                      foregroundColor: context.textPrimary,
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      widget.editing != null ? "Review & Save" : "Save Transaction",
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
            SizedBox(height: 20),
          ],
        ),
        ),
      ),
    );
  }
}
