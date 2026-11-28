import 'package:aureli/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../providers/budget_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/category_model.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/svg_icons.dart';

class AnalyticsView extends StatefulWidget {
  const AnalyticsView({super.key});

  @override
  State<AnalyticsView> createState() => _AnalyticsViewState();
}

class _AnalyticsViewState extends State<AnalyticsView> {
  int touchedIndex = -1;
  bool _isWeeklyView = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<BudgetProvider>(context, listen: false).fetchSummary();
      Provider.of<TransactionProvider>(context, listen: false)
          .fetchCategories();
    });
  }

  final List<Color> _chartColors = [
    Color(0xFFFF5757),
    Color(0xFF4A90E2),
    Color(0xFF2ECC71),
    Color(0xFFF39C12),
    Color(0xFFBA68C8),
    Color(0xFFFF8A65),
    Color(0xFF00BCD4),
    Color(0xFFE91E63),
    Color(0xFF2CB8A0),
    Color(0xFF6C8CFF),
    Color(0xFF9B51E0),
    Color(0xFFE89A58),
    Color(0xFF64748B),
    Color(0xFFF43F5E),
    Color(0xFF0EA5E9),
    Color(0xFFEC4899),
    Color(0xFF0284C7),
    Color(0xFF84CC16),
    Color(0xFF475569),
    Color(0xFFA16207),
    Color(0xFFD946EF),
    Color(0xFF1D4ED8),
    Color(0xFF991B1B),
    Color(0xFFF97316),
    Color(0xFF14B8A6),
    Color(0xFFEAB308),
    Color(0xFF4338CA),
    Color(0xFF34D399),
  ];

  bool _canGoToPreviousMonth() {
    final budgetProvider = Provider.of<BudgetProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final registrationDate = authProvider.userModel?.createdAt;
    if (registrationDate == null) return true;

    int prevMonth = budgetProvider.selectedMonth - 1;
    int prevYear = budgetProvider.selectedYear;
    if (prevMonth < 1) {
      prevMonth = 12;
      prevYear--;
    }

    if (prevYear < registrationDate.year) return false;
    if (prevYear == registrationDate.year &&
        prevMonth < registrationDate.month) {
      return false;
    }
    return true;
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
    );
    Provider.of<TransactionProvider>(context, listen: false).changeMonth(
      newYear,
      newMonth,
      registrationDate: authProvider.userModel?.createdAt,
    );
  }

  String _formatK(double val) {
    if (val >= 1000) {
      return "${(val / 1000).toStringAsFixed(val % 1000 == 0 ? 0 : 1)}k";
    }
    return val.toStringAsFixed(0);
  }

  List<_AdvisoryTipItem> _generateAdvisoryTips(
      double currentSpent, double prevSpent, List<dynamic> categoryBudgets) {
    final List<_AdvisoryTipItem> tips = [];

    if (currentSpent == 0) {
      tips.add(_AdvisoryTipItem(
        icon: AppSvgIcons.lightbulb(size: 16, color: context.tokens.amber),
        text:
            "You haven't tracked any expenses this month. Start logging your daily spends to unlock personalized insights.",
      ));
      return tips;
    }

    // Check if any budget is exceeded
    final exceededCount = categoryBudgets
        .where((b) => b.amountLimit != null && b.totalSpent > b.amountLimit!)
        .length;
    if (exceededCount > 0) {
      tips.add(_AdvisoryTipItem(
        icon:
            AppSvgIcons.alertTriangle(size: 16, color: context.tokens.amber),
        text:
            "You have exceeded your budget limits in $exceededCount category(s). Consider postponing non-essential purchases.",
      ));
    }

    // Check if nearing budget limit (>80%)
    final nearExceededCount = categoryBudgets
        .where((b) =>
            b.amountLimit != null &&
            b.totalSpent > (b.amountLimit! * 0.8) &&
            b.totalSpent <= b.amountLimit!)
        .length;
    if (nearExceededCount > 0) {
      tips.add(_AdvisoryTipItem(
        icon:
            AppSvgIcons.alertTriangle(size: 16, color: context.tokens.amber),
        text:
            "You are nearing the budget limit in $nearExceededCount category(s). Keep a close eye on your spending there.",
      ));
    }

    // Check monthly trend
    if (prevSpent > 0) {
      final diff = currentSpent - prevSpent;
      if (diff > 0) {
        tips.add(_AdvisoryTipItem(
          icon:
              AppSvgIcons.trendingUp(size: 16, color: context.tokens.coral),
          text:
              "Your monthly spend is LKR ${NumberFormat('#,##0').format(diff)} higher than last month. Try tracking daily micro-expenses.",
        ));
      } else if (diff < 0) {
        tips.add(_AdvisoryTipItem(
          icon:
              AppSvgIcons.celebration(size: 16, color: context.tokens.emerald),
          text:
              "Great job! You spent LKR ${NumberFormat('#,##0').format(diff.abs())} less than last month. Consider moving the surplus to savings.",
        ));
      }
    }

    // Top Category Insight
    dynamic topCategory;
    double maxSpent = -1;
    for (var b in categoryBudgets) {
      if (b.totalSpent > maxSpent) {
        maxSpent = b.totalSpent;
        topCategory = b;
      }
    }

    if (topCategory != null && topCategory.totalSpent > 0) {
      final percentage =
          (topCategory.totalSpent / currentSpent * 100).toStringAsFixed(0);
      tips.add(_AdvisoryTipItem(
        icon: AppSvgIcons.lightbulb(size: 16, color: context.tokens.amber),
        text:
            "Insight: '${topCategory.categoryName}' makes up $percentage% of your total expenses. Trimming expenses here yields the biggest savings.",
      ));
    }

    // Fallback if we only have 1 or 2 tips (to ensure UI looks full)
    if (tips.length < 2) {
      tips.add(_AdvisoryTipItem(
        icon: AppSvgIcons.lightbulb(size: 16, color: context.tokens.amber),
        text:
            "Rule of thumb: Aim for the 50/30/20 rule (50% Needs, 30% Wants, 20% Savings) to maintain a healthy budget level.",
      ));
    }

    return tips;
  }

  Widget _buildWeeklyChart(
      BuildContext context, BudgetProvider budgetProvider) {
    final transactionProvider =
        Provider.of<TransactionProvider>(context, listen: false);
    List<double> weeklyTotals = List.filled(5, 0.0);
    double maxWeeklySpend = 0;

    final txs = transactionProvider.transactions;
    for (var tx in txs) {
      if (tx.type == TransactionType.EXPENSE &&
          tx.transactionDate.year == budgetProvider.selectedYear &&
          tx.transactionDate.month == budgetProvider.selectedMonth) {
        int weekIndex = (tx.transactionDate.day - 1) ~/ 7;
        if (weekIndex > 4) weekIndex = 4; // Days 29, 30, 31 fall into Week 5
        weeklyTotals[weekIndex] += tx.amount;
      }
    }
    for (var w in weeklyTotals) {
      if (w > maxWeeklySpend) maxWeeklySpend = w;
    }

    return GlassCard(
      padding: EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            "Weekly Expenses Trend",
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: context.textPrimary,
            ),
          ),
          SizedBox(height: 24),
          SizedBox(
            height: 220,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxWeeklySpend > 0 ? maxWeeklySpend * 1.2 : 100,
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => context.tokens.ink,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      return BarTooltipItem(
                        'Week ${group.x + 1}\nLKR ${NumberFormat('#,##0').format(rod.toY)}',
                        TextStyle(
                            color: context.textPrimary,
                            fontWeight: FontWeight.bold),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (double value, TitleMeta meta) {
                        return Padding(
                          padding: EdgeInsets.only(top: 8.0),
                          child: Text('W${value.toInt() + 1}',
                              style: TextStyle(
                                  color: context.textSecondary,
                                  fontSize: 12,
                                  fontFamily: 'Manrope')),
                        );
                      },
                    ),
                  ),
                  leftTitles:
                      AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles:
                      AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles:
                      AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(5, (index) {
                  return BarChartGroupData(
                    x: index,
                    barRods: [
                      BarChartRodData(
                        toY: weeklyTotals[index],
                        color: context.tokens.emerald,
                        width: 20,
                        borderRadius:
                            BorderRadius.vertical(top: Radius.circular(6)),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
          SizedBox(height: 16),
          Text("Distribution based on latest synced transactions.",
              textAlign: TextAlign.center,
              style: TextStyle(color: context.textLight, fontSize: 11)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final budgetProvider = Provider.of<BudgetProvider>(context);
    final summary = budgetProvider.summary;

    final monthName = DateFormat('MMMM yyyy').format(
        DateTime(budgetProvider.selectedYear, budgetProvider.selectedMonth));
    final double totalExpenses = summary?.totalExpenses ?? 0.0;
    final double prevExpenses = summary?.previousMonthExpenses ?? 0.0;

    final expenseBudgets = summary?.categoryBudgets
            .where((b) =>
                b.totalSpent > 0 ||
                (b.amountLimit != null && b.amountLimit! > 0))
            .toList() ??
        [];

    // Sort descending by total spent (which equals sorting by percentage contribution)
    expenseBudgets.sort((a, b) => b.totalSpent.compareTo(a.totalSpent));

    // Calculate top category
    dynamic topCategory;
    double maxSpent = -1;
    for (var b in expenseBudgets) {
      if (b.totalSpent > maxSpent) {
        maxSpent = b.totalSpent;
        topCategory = b;
      }
    }

    final categories =
        Provider.of<TransactionProvider>(context, listen: false).categories;

    // Prepare pie chart sections
    List<PieChartSectionData> sections = [];
    for (int i = 0; i < expenseBudgets.length; i++) {
      final b = expenseBudgets[i];
      final matches = categories.where((c) =>
          c.id == b.categoryId ||
          c.name.toLowerCase() == b.categoryName.toLowerCase());
      final categoryModel = matches.isNotEmpty ? matches.first : null;
      final color =
          categoryModel?.color ?? _chartColors[i % _chartColors.length];
      final percentage =
          totalExpenses > 0 ? (b.totalSpent / totalExpenses) * 100 : 0.0;

      final isTouched = i == touchedIndex;
      final fontSize = isTouched ? 16.0 : 11.0;
      final radius = isTouched ? 40.0 : 32.0;
      final titleColor =
          isTouched ? Colors.white : context.tokens.ink;

      sections.add(
        PieChartSectionData(
          color: color,
          value: b.totalSpent > 0 ? b.totalSpent : 0.1,
          title: percentage >= 5 ? "${percentage.toStringAsFixed(0)}%" : "",
          radius: radius,
          titleStyle: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
              color: titleColor),
        ),
      );
    }

    // Filter categories that have budget limits set
    final budgetedCategories =
        summary?.categoryBudgets.where((b) => b.amountLimit != null).toList() ??
            [];

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text("Analytics",
            style: TextStyle(
                fontFamily: 'Manrope',
                fontWeight: FontWeight.bold,
                color: context.textPrimary)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: budgetProvider.isLoading
          ? Center(child: CircularProgressIndicator(color: context.tokens.emerald))
          : RefreshIndicator(
              onRefresh: () => budgetProvider.fetchSummary(),
              color: context.tokens.emerald,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.symmetric(horizontal: 20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. Date Selector & Total Spend Header
                    GlassCard(
                      padding:
                          EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              IconButton(
                                icon: Icon(
                                  Icons.chevron_left_rounded,
                                  color: _canGoToPreviousMonth()
                                      ? context.tokens.inkSecondary
                                      : context.tokens.hairline,
                                ),
                                onPressed: _canGoToPreviousMonth()
                                    ? () => _changeMonth(-1)
                                    : null,
                              ),
                              Text(
                                monthName,
                                style: TextStyle(
                                  fontFamily: 'Manrope',
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: context.textPrimary,
                                ),
                              ),
                              IconButton(
                                icon: Icon(Icons.chevron_right_rounded,
                                    color: context.textSecondary),
                                onPressed: () => _changeMonth(1),
                              ),
                            ],
                          ),
                          SizedBox(height: 4),
                          Text(
                            "Total Spend: LKR ${NumberFormat('#,##0').format(totalExpenses)}",
                            style: TextStyle(
                              fontFamily: 'Manrope',
                              fontSize: 14,
                              color: context.tokens.inkMuted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 16),

                    // View Mode Toggle (Weekly / Monthly)
                    Padding(
                      padding: EdgeInsets.only(bottom: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          GestureDetector(
                            onTap: () => setState(() => _isWeeklyView = false),
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 8),
                              decoration: BoxDecoration(
                                color: !_isWeeklyView
                                    ? context.tokens.emerald
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(20),
                                border:
                                    Border.all(color: context.tokens.emerald),
                              ),
                              child: Text("Monthly",
                                  style: TextStyle(
                                      color: !_isWeeklyView
                                          ? Colors.white
                                          : context.tokens.inkMuted,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'Manrope')),
                            ),
                          ),
                          SizedBox(width: 10),
                          GestureDetector(
                            onTap: () => setState(() => _isWeeklyView = true),
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 8),
                              decoration: BoxDecoration(
                                color: _isWeeklyView
                                    ? context.tokens.emerald
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(20),
                                border:
                                    Border.all(color: context.tokens.emerald),
                              ),
                              child: Text("Weekly",
                                  style: TextStyle(
                                      color: _isWeeklyView
                                          ? Colors.white
                                          : context.tokens.inkMuted,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'Manrope')),
                            ),
                          ),
                        ],
                      ),
                    ),

                    if (!_isWeeklyView) ...[
                      // 2. Top Category Card

                      if (topCategory != null)
                        Builder(
                          builder: (context) {
                            final matches = categories.where((c) =>
                                c.id == topCategory.categoryId ||
                                c.name.toLowerCase() ==
                                    topCategory.categoryName.toLowerCase());
                            final catModel =
                                matches.isNotEmpty ? matches.first : null;
                            final color =
                                catModel?.color ?? context.tokens.cobalt;

                            return Container(
                              margin: EdgeInsets.only(bottom: 12),
                              child: GlassCard(
                                padding: EdgeInsets.all(16.0),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 20,
                                      backgroundColor:
                                          color.withValues(alpha: 0.2),
                                      child: AppSvgIcons.getCategorySvg(
                                        catModel?.iconKey,
                                        topCategory.categoryName,
                                        color: color,
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
                                            "Top Category",
                                            style: TextStyle(
                                                fontFamily: 'Manrope',
                                                fontSize: 13,
                                                color: context.tokens.inkMuted),
                                          ),
                                          SizedBox(height: 2),
                                          RichText(
                                            text: TextSpan(
                                              style: TextStyle(
                                                  fontFamily: 'Manrope',
                                                  color: context.textPrimary,
                                                  fontSize: 14),
                                              children: [
                                                TextSpan(
                                                  text:
                                                      "${topCategory.categoryName} ",
                                                  style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold),
                                                ),
                                                const TextSpan(
                                                    text:
                                                        "was your largest category this month: "),
                                                TextSpan(
                                                  text:
                                                      "LKR ${NumberFormat('#,##0').format(topCategory.totalSpent)}",
                                                  style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: context.tokens.amber),
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
                            );
                          },
                        ),

                      // 3. Monthly Comparison Card
                      GlassCard(
                        padding: EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: (totalExpenses >= prevExpenses
                                      ? context.tokens.coral
                                      : context.tokens.emerald)
                                  .withValues(alpha: 0.2),
                              child: Icon(
                                totalExpenses >= prevExpenses
                                    ? Icons.trending_up_rounded
                                    : Icons.trending_down_rounded,
                                color: totalExpenses >= prevExpenses
                                    ? context.tokens.coral
                                    : context.tokens.emerald,
                                size: 20,
                              ),
                            ),
                            SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Monthly Comparison",
                                    style: TextStyle(
                                        fontFamily: 'Manrope',
                                        fontSize: 13,
                                        color: context.tokens.inkMuted),
                                  ),
                                  SizedBox(height: 2),
                                  Builder(
                                    builder: (context) {
                                      if (prevExpenses <= 0) {
                                        return Text(
                                          "You spent LKR ${NumberFormat('#,##0').format(totalExpenses)} this month.",
                                          style: TextStyle(
                                              fontFamily: 'Manrope',
                                              fontSize: 14,
                                              color: context.textPrimary),
                                        );
                                      }
                                      final diff = totalExpenses - prevExpenses;
                                      return RichText(
                                        text: TextSpan(
                                          style: TextStyle(
                                              fontFamily: 'Manrope',
                                              color: context.textPrimary,
                                              fontSize: 14),
                                          children: [
                                            const TextSpan(text: "You spent "),
                                            TextSpan(
                                              text:
                                                  "LKR ${NumberFormat('#,##0').format(diff.abs())} ",
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: diff >= 0
                                                    ? context.tokens.coral
                                                    : context.tokens.emerald,
                                              ),
                                            ),
                                            TextSpan(
                                                text: diff >= 0
                                                    ? "more than last month."
                                                    : "less than last month."),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 20),

                      // 4. Category Breakdown Section
                      GlassCard(
                        padding: EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              "Category Breakdown",
                              style: TextStyle(
                                fontFamily: 'Manrope',
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: context.textPrimary,
                              ),
                            ),
                            SizedBox(height: 24),
                            if (totalExpenses > 0) ...[
                              // Donut Chart inside Stack
                              Stack(
                                alignment: Alignment.center,
                                children: [
                                  SizedBox(
                                    height: 180,
                                    child: PieChart(
                                      PieChartData(
                                        pieTouchData: PieTouchData(
                                          touchCallback: (FlTouchEvent event,
                                              pieTouchResponse) {
                                            setState(() {
                                              if (!event
                                                      .isInterestedForInteractions ||
                                                  pieTouchResponse == null ||
                                                  pieTouchResponse
                                                          .touchedSection ==
                                                      null) {
                                                touchedIndex = -1;
                                                return;
                                              }
                                              touchedIndex = pieTouchResponse
                                                  .touchedSection!
                                                  .touchedSectionIndex;
                                            });
                                          },
                                        ),
                                        sections: sections,
                                        centerSpaceRadius: 55,
                                        sectionsSpace: 2,
                                      ),
                                    ),
                                  ),
                                  Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        _formatK(totalExpenses),
                                        style: TextStyle(
                                          fontFamily: 'Manrope',
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold,
                                          color: context.textPrimary,
                                        ),
                                      ),
                                      Text(
                                        "Total",
                                        style: TextStyle(
                                          fontFamily: 'Manrope',
                                          fontSize: 12,
                                          color: context.textMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              SizedBox(height: 24),

                              // List of breakdown categories
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: expenseBudgets.length,
                                separatorBuilder: (context, index) =>
                                    Divider(color: context.divider, height: 1),
                                itemBuilder: (context, index) {
                                  final b = expenseBudgets[index];
                                  final matches = categories.where((c) =>
                                      c.id == b.categoryId ||
                                      c.name.toLowerCase() ==
                                          b.categoryName.toLowerCase());
                                  final catModel =
                                      matches.isNotEmpty ? matches.first : null;
                                  final color = catModel?.color ??
                                      _chartColors[index % _chartColors.length];
                                  final percentage =
                                      (b.totalSpent / totalExpenses) * 100;

                                  return Padding(
                                    padding:
                                        EdgeInsets.symmetric(vertical: 8.0),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 28,
                                          height: 28,
                                          decoration: BoxDecoration(
                                            color: color.withValues(alpha: 0.2),
                                            shape: BoxShape.circle,
                                          ),
                                          alignment: Alignment.center,
                                          child: AppSvgIcons.getCategorySvg(
                                            catModel?.iconKey,
                                            b.categoryName,
                                            color: color,
                                            size: 14,
                                          ),
                                        ),
                                        SizedBox(width: 10),
                                        Text(
                                          b.categoryName,
                                          style: TextStyle(
                                            fontFamily: 'Manrope',
                                            color: context.textPrimary,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const Spacer(),
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              "LKR ${NumberFormat('#,##0').format(b.totalSpent)}",
                                              style: TextStyle(
                                                fontFamily: 'Manrope',
                                                color: context.textPrimary,
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            SizedBox(height: 2),
                                            Text(
                                              "${percentage.toStringAsFixed(0)}%",
                                              style: TextStyle(
                                                fontFamily: 'Manrope',
                                                color: context.textMuted,
                                                fontSize: 11,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ] else ...[
                              Padding(
                                padding: EdgeInsets.symmetric(vertical: 40.0),
                                child: Text(
                                  "No expense data to analyze for this month.",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      color: context.textMuted,
                                      fontFamily: 'Manrope'),
                                ),
                              )
                            ],
                          ],
                        ),
                      ),
                      SizedBox(height: 20),

                      // 5. Budget vs Actual Section
                      GlassCard(
                        padding: EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              "Budget vs Actual",
                              style: TextStyle(
                                fontFamily: 'Manrope',
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: context.textPrimary,
                              ),
                            ),
                            SizedBox(height: 16),
                            budgetedCategories.isEmpty
                                ? Padding(
                                    padding:
                                        EdgeInsets.symmetric(vertical: 20.0),
                                    child: Text(
                                      "No budgets set for this month. Set budget limits in the Budgets tab.",
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                          color: context.textMuted,
                                          fontFamily: 'Manrope',
                                          fontSize: 13),
                                    ),
                                  )
                                : ListView.builder(
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    itemCount: budgetedCategories.length,
                                    itemBuilder: (context, index) {
                                      final b = budgetedCategories[index];
                                      final double spent = b.totalSpent;
                                      final double limit = b.amountLimit ?? 0.0;
                                      final isOver = spent > limit;

                                      // Progress fraction capped at 1.0
                                      final progress = limit > 0
                                          ? (spent / limit).clamp(0.0, 1.0)
                                          : 0.0;

                                      return Container(
                                        margin: EdgeInsets.only(bottom: 16),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Text(
                                                  b.categoryName,
                                                  style: TextStyle(
                                                    fontFamily: 'Manrope',
                                                    color: context.textPrimary,
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                                RichText(
                                                  text: TextSpan(
                                                    style: TextStyle(
                                                        fontFamily: 'Manrope',
                                                        fontSize: 13),
                                                    children: [
                                                      TextSpan(
                                                        text:
                                                            "LKR ${_formatK(spent)} ",
                                                        style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: isOver
                                                              ? const Color(
                                                                  0xFFCD5C52)
                                                              : Colors.white,
                                                        ),
                                                      ),
                                                      TextSpan(
                                                        text:
                                                            "/ ${_formatK(limit)}",
                                                        style: TextStyle(
                                                            color: context
                                                                .textMuted),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                            SizedBox(height: 8),
                                            ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                              child: LinearProgressIndicator(
                                                value: progress,
                                                minHeight: 8,
                                                backgroundColor:
                                                    context.divider,
                                                valueColor:
                                                    AlwaysStoppedAnimation<
                                                        Color>(
                                                  isOver
                                                      ? context.tokens.coral
                                                      : context.tokens.emerald,
                                                ),
                                              ),
                                            ),
                                            if (isOver) ...[
                                              SizedBox(height: 6),
                                              Text(
                                                "Over budget by ${_formatK(spent - limit)}",
                                                style: TextStyle(
                                                  fontFamily: 'Manrope',
                                                  color: context.tokens.coral,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                          ],
                        ),
                      ),
                      SizedBox(height: 20),

                      // 6. Advisory Tips Section
                      GlassCard(
                        padding: EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              "Budget Advisory Tips",
                              style: TextStyle(
                                fontFamily: 'Manrope',
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: context.textPrimary,
                              ),
                            ),
                            SizedBox(height: 16),
                            ..._generateAdvisoryTips(
                                    totalExpenses, prevExpenses, expenseBudgets)
                                .map(
                              (tip) => Padding(
                                padding: EdgeInsets.only(bottom: 12.0),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding: EdgeInsets.only(top: 2.0),
                                      child: tip.icon,
                                    ),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        tip.text,
                                        style: TextStyle(
                                          fontFamily: 'Manrope',
                                          fontSize: 13,
                                          color: context.textSecondary,
                                          height: 1.4,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      // WEEKLY VIEW
                      _buildWeeklyChart(context, budgetProvider),
                    ],
                    SizedBox(height: 100), // Safe scroll space
                  ],
                ),
              ),
            ),
    );
  }
}

class _AdvisoryTipItem {
  final Widget icon;
  final String text;
  _AdvisoryTipItem({required this.icon, required this.text});
}
