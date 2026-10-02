import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../providers/budget_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/svg_icons.dart';

class AnalyticsView extends StatefulWidget {
  const AnalyticsView({super.key});

  @override
  State<AnalyticsView> createState() => _AnalyticsViewState();
}

class _AnalyticsViewState extends State<AnalyticsView> {
  int touchedIndex = -1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<BudgetProvider>(context, listen: false).fetchSummary();
      Provider.of<TransactionProvider>(context, listen: false)
          .fetchCategories();
    });
  }

  final List<Color> _chartColors = const [
    Color(0xFF147D64), // Emerald / Teal
    Color(0xFF2F6690), // Navy
    Color(0xFFD68A19), // Amber
    Color(0xFF7466C8), // Violet
    Color(0xFFCD5C52), // Coral
    Color(0xFF4C9FD1), // Sky
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
    if (prevYear == registrationDate.year && prevMonth < registrationDate.month)
      return false;
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
        icon: AppSvgIcons.lightbulb(size: 16, color: const Color(0xFFE89A58)),
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
            AppSvgIcons.alertTriangle(size: 16, color: const Color(0xFFE89A58)),
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
        icon: AppSvgIcons.alertTriangle(size: 16, color: const Color(0xFFD68A19)),
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
              AppSvgIcons.trendingUp(size: 16, color: const Color(0xFFCD5C52)),
          text:
              "Your monthly spend is LKR ${NumberFormat('#,##0').format(diff)} higher than last month. Try tracking daily micro-expenses.",
        ));
      } else if (diff < 0) {
        tips.add(_AdvisoryTipItem(
          icon:
              AppSvgIcons.celebration(size: 16, color: const Color(0xFF2CB8A0)),
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
        icon: AppSvgIcons.lightbulb(size: 16, color: const Color(0xFFE89A58)),
        text:
            "Insight: '${topCategory.categoryName}' makes up $percentage% of your total expenses. Trimming expenses here yields the biggest savings.",
      ));
    }

    // Fallback if we only have 1 or 2 tips (to ensure UI looks full)
    if (tips.length < 2) {
      tips.add(_AdvisoryTipItem(
        icon: AppSvgIcons.lightbulb(size: 16, color: const Color(0xFFE89A58)),
        text:
            "Rule of thumb: Aim for the 50/30/20 rule (50% Needs, 30% Wants, 20% Savings) to maintain a healthy budget level.",
      ));
    }

    return tips;
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
      final titleColor = isTouched ? Colors.white : Colors.white.withOpacity(0.9);

      sections.add(
        PieChartSectionData(
          color: color,
          value: b.totalSpent > 0 ? b.totalSpent : 0.1,
          title: percentage >= 5 ? "${percentage.toStringAsFixed(0)}%" : "",
          radius: radius,
          titleStyle: TextStyle(
              fontSize: fontSize, fontWeight: FontWeight.bold, color: titleColor),
        ),
      );
    }

    // Filter categories that have budget limits set
    final budgetedCategories =
        summary?.categoryBudgets.where((b) => b.amountLimit != null).toList() ??
            [];

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text("Analytics",
            style: TextStyle(
                fontFamily: 'Manrope',
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF0F172A))),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: budgetProvider.isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF147D64)))
          : RefreshIndicator(
              onRefresh: () => budgetProvider.fetchSummary(),
              color: const Color(0xFF147D64),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. Date Selector & Total Spend Header
                    GlassCard(
                      padding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 16),
                      child: Column(
                        children: [
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
                                monthName,
                                style: const TextStyle(
                                  fontFamily: 'Manrope',
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.chevron_right_rounded,
                                    color: Colors.white70),
                                onPressed: () => _changeMonth(1),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Total Spend: LKR ${NumberFormat('#,##0').format(totalExpenses)}",
                            style: TextStyle(
                              fontFamily: 'Manrope',
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.6),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

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
                              catModel?.color ?? const Color(0xFF4C9FD1);

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: GlassCard(
                              padding: const EdgeInsets.all(16.0),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 20,
                                    backgroundColor: color.withOpacity(0.2),
                                    child: AppSvgIcons.getCategorySvg(
                                      catModel?.iconKey,
                                      topCategory.categoryName,
                                      color: color,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          "Top Category",
                                          style: TextStyle(
                                              fontFamily: 'Manrope',
                                              fontSize: 13,
                                              color: Colors.white60),
                                        ),
                                        const SizedBox(height: 2),
                                        RichText(
                                          text: TextSpan(
                                            style: const TextStyle(
                                                fontFamily: 'Manrope',
                                                color: Colors.white,
                                                fontSize: 14),
                                            children: [
                                              TextSpan(
                                                text:
                                                    "${topCategory.categoryName} ",
                                                style: const TextStyle(
                                                    fontWeight:
                                                        FontWeight.bold),
                                              ),
                                              const TextSpan(
                                                  text:
                                                      "was your largest category this month: "),
                                              TextSpan(
                                                text:
                                                    "LKR ${NumberFormat('#,##0').format(topCategory.totalSpent)}",
                                                style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: Color(0xFFD68A19)),
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
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: (totalExpenses >= prevExpenses
                                    ? const Color(0xFFCD5C52)
                                    : const Color(0xFF147D64))
                                .withOpacity(0.2),
                            child: Icon(
                              totalExpenses >= prevExpenses
                                  ? Icons.trending_up_rounded
                                  : Icons.trending_down_rounded,
                              color: totalExpenses >= prevExpenses
                                  ? const Color(0xFFCD5C52)
                                  : const Color(0xFF147D64),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Monthly Comparison",
                                  style: TextStyle(
                                      fontFamily: 'Manrope',
                                      fontSize: 13,
                                      color: Colors.white60),
                                ),
                                const SizedBox(height: 2),
                                Builder(
                                  builder: (context) {
                                    if (prevExpenses <= 0) {
                                      return Text(
                                        "You spent LKR ${NumberFormat('#,##0').format(totalExpenses)} this month.",
                                        style: const TextStyle(
                                            fontFamily: 'Manrope',
                                            fontSize: 14,
                                            color: Colors.white),
                                      );
                                    }
                                    final diff = totalExpenses - prevExpenses;
                                    return RichText(
                                      text: TextSpan(
                                        style: const TextStyle(
                                            fontFamily: 'Manrope',
                                            color: Colors.white,
                                            fontSize: 14),
                                        children: [
                                          const TextSpan(text: "You spent "),
                                          TextSpan(
                                            text:
                                                "LKR ${NumberFormat('#,##0').format(diff.abs())} ",
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: diff >= 0
                                                  ? const Color(0xFFCD5C52)
                                                  : const Color(0xFF147D64),
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
                    const SizedBox(height: 20),

                    // 4. Category Breakdown Section
                    GlassCard(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            "Category Breakdown",
                            style: TextStyle(
                              fontFamily: 'Manrope',
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 24),
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
                                        touchCallback: (FlTouchEvent event, pieTouchResponse) {
                                          setState(() {
                                            if (!event.isInterestedForInteractions ||
                                                pieTouchResponse == null ||
                                                pieTouchResponse.touchedSection == null) {
                                              touchedIndex = -1;
                                              return;
                                            }
                                            touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
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
                                      style: const TextStyle(
                                        fontFamily: 'Manrope',
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const Text(
                                      "Total",
                                      style: TextStyle(
                                        fontFamily: 'Manrope',
                                        fontSize: 12,
                                        color: Colors.white54,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),

                            // List of breakdown categories
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: expenseBudgets.length,
                              separatorBuilder: (context, index) =>
                                  const Divider(
                                      color: Colors.white10, height: 1),
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
                                      const EdgeInsets.symmetric(vertical: 8.0),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 28,
                                        height: 28,
                                        decoration: BoxDecoration(
                                          color: color.withOpacity(0.2),
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
                                      const SizedBox(width: 10),
                                      Text(
                                        b.categoryName,
                                        style: const TextStyle(
                                          fontFamily: 'Manrope',
                                          color: Colors.white,
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
                                            style: const TextStyle(
                                              fontFamily: 'Manrope',
                                              color: Colors.white,
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            "${percentage.toStringAsFixed(0)}%",
                                            style: const TextStyle(
                                              fontFamily: 'Manrope',
                                              color: Colors.white54,
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
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 40.0),
                              child: Text(
                                "No expense data to analyze for this month.",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    color: Colors.white54,
                                    fontFamily: 'Manrope'),
                              ),
                            )
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // 5. Budget vs Actual Section
                    GlassCard(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            "Budget vs Actual",
                            style: TextStyle(
                              fontFamily: 'Manrope',
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 16),
                          budgetedCategories.isEmpty
                              ? const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 20.0),
                                  child: Text(
                                    "No budgets set for this month. Set budget limits in the Budgets tab.",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        color: Colors.white54,
                                        fontFamily: 'Manrope',
                                        fontSize: 13),
                                  ),
                                )
                              : ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
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
                                      margin: const EdgeInsets.only(bottom: 16),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                b.categoryName,
                                                style: const TextStyle(
                                                  fontFamily: 'Manrope',
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 14,
                                                ),
                                              ),
                                              RichText(
                                                text: TextSpan(
                                                  style: const TextStyle(
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
                                                      style: const TextStyle(
                                                          color:
                                                              Colors.white54),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(4),
                                            child: LinearProgressIndicator(
                                              value: progress,
                                              minHeight: 8,
                                              backgroundColor: Colors.white10,
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                isOver
                                                    ? const Color(0xFFCD5C52)
                                                    : const Color(0xFF147D64),
                                              ),
                                            ),
                                          ),
                                          if (isOver) ...[
                                            const SizedBox(height: 6),
                                            Text(
                                              "Over budget by ${_formatK(spent - limit)}",
                                              style: const TextStyle(
                                                fontFamily: 'Manrope',
                                                color: Color(0xFFCD5C52),
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
                    const SizedBox(height: 20),

                    // 6. Advisory Tips Section
                    GlassCard(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            "Budget Advisory Tips",
                            style: TextStyle(
                              fontFamily: 'Manrope',
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ..._generateAdvisoryTips(
                                  totalExpenses, prevExpenses, expenseBudgets)
                              .map(
                            (tip) => Padding(
                              padding: const EdgeInsets.only(bottom: 12.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2.0),
                                    child: tip.icon,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      tip.text,
                                      style: const TextStyle(
                                        fontFamily: 'Manrope',
                                        fontSize: 13,
                                        color: Colors.white70,
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
                    const SizedBox(height: 100), // Safe scroll space
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
