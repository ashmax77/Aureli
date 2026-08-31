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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final budgetProv = Provider.of<BudgetProvider>(context, listen: false);
      final txProv = Provider.of<TransactionProvider>(context, listen: false);
      final schedProv = Provider.of<ScheduledTransactionProvider>(context, listen: false);
      Future.wait([
        budgetProv.fetchSummary(),
        txProv.fetchTransactions(refresh: true),
        txProv.fetchCategories(),
        schedProv.fetchScheduledTransactions(),
      ]);
    });
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

    budgetProvider.changeMonth(newYear, newMonth);
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

  IconData _getCategoryIcon(String name) {
    name = name.toLowerCase();
    if (name.contains('food') ||
        name.contains('eat') ||
        name.contains('grocer') ||
        name.contains('coffee') ||
        name.contains('cafe')) {
      return Icons.restaurant_rounded;
    }
    if (name.contains('rent') ||
        name.contains('home') ||
        name.contains('house')) {
      return Icons.home_work_rounded;
    }
    if (name.contains('utility') ||
        name.contains('bill') ||
        name.contains('water') ||
        name.contains('power') ||
        name.contains('ceb') ||
        name.contains('electr')) {
      return Icons.receipt_long_rounded;
    }
    if (name.contains('travel') ||
        name.contains('transport') ||
        name.contains('car') ||
        name.contains('fuel')) {
      return Icons.directions_car_filled_rounded;
    }
    if (name.contains('entertain') ||
        name.contains('movie') ||
        name.contains('fun') ||
        name.contains('game')) {
      return Icons.sports_esports_rounded;
    }
    if (name.contains('shop') ||
        name.contains('store') ||
        name.contains('market') ||
        name.contains('cloth') ||
        name.contains('keells')) {
      return Icons.shopping_cart_rounded;
    }
    if (name.contains('salary') ||
        name.contains('work') ||
        name.contains('pay') ||
        name.contains('income')) {
      return Icons.payments_rounded;
    }
    return Icons.category_rounded;
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
    final colors = [
      const Color(0xFFE89A58), // Warm Peach/Orange
      const Color(0xFF2CB8A0), // Emerald/Teal
      const Color(0xFF6C8CFF), // Indigo/Blue
    ];
    final color = colors[index % colors.length];

    return GlassCard(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _getCategoryIcon(cat.categoryName),
              color: color,
              size: 22,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            cat.categoryName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Manrope',
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "LKR ${NumberFormat('#,##0').format(cat.totalSpent)}",
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.white.withOpacity(0.75),
            ),
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
    final summary = budgetProvider.summary;

    final monthName = DateFormat('MMMM').format(
      DateTime(budgetProvider.selectedYear, budgetProvider.selectedMonth),
    );

    // Budget Calculations
    final double totalBudget =
        summary?.categoryBudgets.fold<double>(
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
    final double progress = hasBudget
        ? (totalSpent / totalBudget).clamp(0.0, 1.0)
        : 0.0;
    final int percentUsed = hasBudget
        ? ((totalSpent / totalBudget) * 100).round()
        : 0;

    Color statusColor = const Color(0xFF147D64);
    String statusLabel = "On track";
    IconData statusIcon = Icons.check_circle_rounded;

    if (!hasBudget) {
      statusColor = Colors.white38;
      statusLabel = "No limit set";
      statusIcon = Icons.info_outline_rounded;
    } else if (isOver) {
      statusColor = const Color(0xFFCD5C52);
      statusLabel = "Over budget";
      statusIcon = Icons.warning_amber_rounded;
    } else if (percentUsed >= 90) {
      statusColor = const Color(0xFFD68A19);
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
    Color trendColor = const Color(0xFF147D64);
    Color trendBg = const Color(0xFF147D64).withOpacity(0.15);

    if (prevSpent > 0 && summary != null) {
      final double diff = ((totalSpent - prevSpent) / prevSpent) * 100;
      if (diff > 0) {
        trendText =
            "📈 ${diff.abs().toStringAsFixed(1)}% more than $prevMonthName";
        trendColor = const Color(0xFFCD5C52);
        trendBg = const Color(0xFFCD5C52).withOpacity(0.15);
      } else if (diff < 0) {
        trendText =
            "📉 ${diff.abs().toStringAsFixed(1)}% less than $prevMonthName";
        trendColor = const Color(0xFF147D64);
        trendBg = const Color(0xFF147D64).withOpacity(0.15);
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

    return Scaffold(
      backgroundColor: const Color(0xFF0F1621),
      appBar: AppBar(
        title: const Text(
          "Aureli",
          style: TextStyle(
            fontFamily: 'Manrope',
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: const [UserProfileAvatarIcon()],
      ),
      body: budgetProvider.isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF147D64)),
            )
          : RefreshIndicator(
              onRefresh: () async {
                final budgetProv = Provider.of<BudgetProvider>(context, listen: false);
                final txProv = Provider.of<TransactionProvider>(context, listen: false);
                final schedProv = Provider.of<ScheduledTransactionProvider>(context, listen: false);
                await Future.wait([
                  budgetProv.fetchSummary(),
                  txProv.fetchTransactions(refresh: true),
                  schedProv.fetchScheduledTransactions(),
                ]);
              },
              color: const Color(0xFF147D64),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
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
                                ? Colors.white70
                                : Colors.white24,
                          ),
                          onPressed: _canGoToPreviousMonth()
                              ? () => _changeMonth(-1)
                              : null,
                        ),
                        Text(
                          "$monthName ${budgetProvider.selectedYear}",
                          style: const TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.chevron_right_rounded,
                            color: Colors.white70,
                          ),
                          onPressed: () => _changeMonth(1),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // 2. Financial Summary Card (Spent this month, Total Income & Net Cash Flow)
                    GlassCard(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        children: [
                          Text(
                            "Spent this month",
                            style: TextStyle(
                              fontFamily: 'Manrope',
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withOpacity(0.6),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            "LKR ${NumberFormat('#,##0').format(totalSpent)}",
                            style: const TextStyle(
                              fontFamily: 'Manrope',
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: -0.5,
                            ),
                          ),
                          if (trendText != null) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: trendBg,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                trendText,
                                style: TextStyle(
                                  fontFamily: 'Manrope',
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: trendColor,
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),
                          const Divider(color: Colors.white10, height: 1),
                          const SizedBox(height: 14),
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
                                        color: Colors.white.withOpacity(0.5),
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      "LKR ${NumberFormat('#,##0').format(totalIncome)}",
                                      style: const TextStyle(
                                        fontFamily: 'Manrope',
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF147D64),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                width: 1,
                                height: 28,
                                color: Colors.white10,
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
                                        color: Colors.white.withOpacity(0.5),
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      "${netCashFlow >= 0 ? '+' : ''}LKR ${NumberFormat('#,##0').format(netCashFlow)}",
                                      style: TextStyle(
                                        fontFamily: 'Manrope',
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: netCashFlow >= 0
                                            ? const Color(0xFF147D64)
                                            : const Color(0xFFCD5C52),
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
                    const SizedBox(height: 24),

                    // 3. Complete Budget Overview Card
                    InkWell(
                      onTap: widget.onViewBudgets,
                      borderRadius: BorderRadius.circular(16),
                      child: GlassCard(
                        padding: const EdgeInsets.all(20.0),
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
                                    color: Colors.white.withOpacity(0.6),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: statusColor.withOpacity(0.15),
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
                                      const SizedBox(width: 4),
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
                            const SizedBox(height: 8),
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
                                    ? const Color(0xFFCD5C52)
                                    : Colors.white,
                              ),
                            ),
                            const SizedBox(height: 16),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: progress,
                                minHeight: 7,
                                backgroundColor: Colors.white10,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  statusColor,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "0",
                                  style: TextStyle(
                                    fontFamily: 'Manrope',
                                    fontSize: 11,
                                    color: Colors.white.withOpacity(0.4),
                                  ),
                                ),
                                Text(
                                  hasBudget ? "$percentUsed% used" : "0% used",
                                  style: TextStyle(
                                    fontFamily: 'Manrope',
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white.withOpacity(0.6),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

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
                            padding: const EdgeInsets.symmetric(
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
                                    ).withOpacity(0.18),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.event_note_rounded,
                                    color: Color(0xFF6C8CFF),
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        "Scheduled Payments",
                                        style: TextStyle(
                                          fontFamily: 'Manrope',
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        upcomingCount > 0
                                            ? "$upcomingCount upcoming payment${upcomingCount > 1 ? 's' : ''} due"
                                            : "No upcoming payments scheduled",
                                        style: TextStyle(
                                          fontFamily: 'Manrope',
                                          fontSize: 12,
                                          color: upcomingCount > 0
                                              ? const Color(0xFF2CB8A0)
                                              : Colors.white38,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(
                                  Icons.chevron_right_rounded,
                                  color: Colors.white38,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 24),

                    // 4. Top Categories Section
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "Top Categories",
                              style: TextStyle(
                                fontFamily: 'Manrope',
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            TextButton(
                              onPressed: widget.onViewBudgets,
                              style: TextButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                              ),
                              child: const Text(
                                "See all",
                                style: TextStyle(
                                  fontFamily: 'Manrope',
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF147D64),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (displayTop.isEmpty)
                          GlassCard(
                            padding: const EdgeInsets.symmetric(
                              vertical: 24,
                              horizontal: 16,
                            ),
                            child: Center(
                              child: Text(
                                "No expenses recorded this month",
                                style: TextStyle(
                                  fontFamily: 'Manrope',
                                  color: Colors.white.withOpacity(0.4),
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          )
                        else
                          Row(
                            children: [
                              for (int i = 0; i < displayTop.length; i++) ...[
                                if (i > 0) const SizedBox(width: 10),
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
                    const SizedBox(height: 24),

                    // 5. Recent Expenses Section
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "Recent Expenses",
                              style: TextStyle(
                                fontFamily: 'Manrope',
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            TextButton(
                              onPressed: widget.onViewTransactions,
                              style: TextButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                              ),
                              child: const Text(
                                "See all",
                                style: TextStyle(
                                  fontFamily: 'Manrope',
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF147D64),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (recentExpenses.isEmpty)
                          GlassCard(
                            padding: const EdgeInsets.symmetric(
                              vertical: 24,
                              horizontal: 16,
                            ),
                            child: Center(
                              child: Text(
                                "No recent expenses logged",
                                style: TextStyle(
                                  fontFamily: 'Manrope',
                                  color: Colors.white.withOpacity(0.4),
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          )
                        else
                          GlassCard(
                            padding: const EdgeInsets.symmetric(
                              vertical: 4,
                              horizontal: 16,
                            ),
                            child: Column(
                              children: [
                                for (
                                  int i = 0;
                                  i < recentExpenses.length;
                                  i++
                                ) ...[
                                  if (i > 0)
                                    const Divider(
                                      color: Colors.white10,
                                      height: 1,
                                    ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12.0,
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 40,
                                          height: 40,
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(
                                              0.06,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: Icon(
                                            _getCategoryIcon(
                                              recentExpenses[i].category.name,
                                            ),
                                            color: Colors.white70,
                                            size: 20,
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                (recentExpenses[i].note !=
                                                            null &&
                                                        recentExpenses[i].note!
                                                            .trim()
                                                            .isNotEmpty)
                                                    ? recentExpenses[i].note!
                                                    : recentExpenses[i]
                                                          .category
                                                          .name,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontFamily: 'Manrope',
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white,
                                                ),
                                              ),
                                              const SizedBox(height: 3),
                                              Text(
                                                _formatExpenseDate(
                                                  recentExpenses[i]
                                                      .transactionDate,
                                                ),
                                                style: TextStyle(
                                                  fontFamily: 'Manrope',
                                                  fontSize: 11,
                                                  color: Colors.white
                                                      .withOpacity(0.45),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          "LKR ${NumberFormat('#,##0').format(recentExpenses[i].amount)}",
                                          style: const TextStyle(
                                            fontFamily: 'Manrope',
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
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

                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
    );
  }
}

class AddTransactionSheet extends StatefulWidget {
  const AddTransactionSheet({super.key});

  @override
  State<AddTransactionSheet> createState() => _AddTransactionSheetState();
}

class _AddTransactionSheetState extends State<AddTransactionSheet> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  TransactionType _type = TransactionType.EXPENSE;
  int? _selectedCategoryId;
  PaymentMethod _paymentMethod = PaymentMethod.CASH;
  DateTime _selectedDate = DateTime.now();
  bool _isSaving = false;

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

  Future<void> _submit() async {
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

    setState(() => _isSaving = true);
    final transactionProvider = Provider.of<TransactionProvider>(
      context,
      listen: false,
    );

    final success = await transactionProvider.createTransaction(
      type: _type,
      categoryId: _selectedCategoryId!,
      amount: amount,
      date: _selectedDate,
      paymentMethod: _paymentMethod,
      note: note,
    );

    if (mounted) {
      setState(() => _isSaving = false);
      if (success) {
        Navigator.pop(context, true);
      } else {
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
    final transactionProvider = Provider.of<TransactionProvider>(context);
    final categories = transactionProvider.categories
        .where((c) => c.type == _type)
        .toList();

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF141B26),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: 20.0,
        left: 20.0,
        right: 20.0,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20.0,
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
                decoration: const BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.all(Radius.circular(2)),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              "Add Transaction",
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),

            // Type Toggle (Income / Expense)
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: const Center(child: Text("EXPENSE")),
                    selected: _type == TransactionType.EXPENSE,
                    onSelected: (selected) {
                      setState(() {
                        _type = TransactionType.EXPENSE;
                        _selectedCategoryId = null;
                      });
                    },
                    selectedColor: const Color(0xFF0B3B5A),
                    backgroundColor: Colors.white.withOpacity(0.04),
                    labelStyle: TextStyle(
                      color: _type == TransactionType.EXPENSE
                          ? Colors.white
                          : Colors.white60,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ChoiceChip(
                    label: const Center(child: Text("INCOME")),
                    selected: _type == TransactionType.INCOME,
                    onSelected: (selected) {
                      setState(() {
                        _type = TransactionType.INCOME;
                        _selectedCategoryId = null;
                      });
                    },
                    selectedColor: const Color(0xFF147D64),
                    backgroundColor: Colors.white.withOpacity(0.04),
                    labelStyle: TextStyle(
                      color: _type == TransactionType.INCOME
                          ? Colors.white
                          : Colors.white60,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Note Field
            TextField(
              controller: _noteController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: "Note",
                labelStyle: TextStyle(color: Colors.white70),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white24),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF147D64)),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Amount Field
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: "Amount (LKR)",
                labelStyle: TextStyle(color: Colors.white70),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white24),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF147D64)),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Category Dropdown
            DropdownButtonFormField<int>(
              value: _selectedCategoryId,
              dropdownColor: const Color(0xFF141B26),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: "Category",
                labelStyle: TextStyle(color: Colors.white70),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white24),
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
            const SizedBox(height: 16),

            // Payment Method Dropdown
            DropdownButtonFormField<PaymentMethod>(
              value: _paymentMethod,
              dropdownColor: const Color(0xFF141B26),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: "Payment Method",
                labelStyle: TextStyle(color: Colors.white70),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white24),
                ),
              ),
              items: PaymentMethod.values.map((method) {
                return DropdownMenuItem<PaymentMethod>(
                  value: method,
                  child: Text(method.toString().split('.').last),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() => _paymentMethod = val);
                }
              },
            ),
            const SizedBox(height: 16),

            // Date picker Trigger
            ListTile(
              title: const Text(
                "Transaction Date",
                style: TextStyle(color: Colors.white70),
              ),
              subtitle: Text(
                DateFormat('yyyy-MM-dd').format(_selectedDate),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              trailing: const Icon(
                Icons.calendar_today_rounded,
                color: Colors.white70,
              ),
              onTap: _selectDate,
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 32),

            // Save button
            _isSaving
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF147D64)),
                  )
                : ElevatedButton(
                    onPressed: _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF147D64),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      "Save Transaction",
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
