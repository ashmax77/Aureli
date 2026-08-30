import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../providers/budget_provider.dart';
import '../../providers/transaction_provider.dart';

class AnalyticsView extends StatefulWidget {
  const AnalyticsView({super.key});

  @override
  State<AnalyticsView> createState() => _AnalyticsViewState();
}

class _AnalyticsViewState extends State<AnalyticsView> {


  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<BudgetProvider>(context, listen: false).fetchSummary();
      Provider.of<TransactionProvider>(context, listen: false).fetchCategories();
    });
  }

  final List<Color> _chartColors = const [
    Color(0xFF2F6690), // Navy
    Color(0xFF16806A), // Teal
    Color(0xFFCD5C52), // Coral
    Color(0xFF7466C8), // Violet
    Color(0xFFD68A19), // Amber
    Color(0xFF4C9FD1), // Sky
  ];

  @override
  void dispose() {
    super.dispose();
  }



  @override
  Widget build(BuildContext context) {
    final budgetProvider = Provider.of<BudgetProvider>(context);
    final summary = budgetProvider.summary;

    final expenseBudgets = summary?.categoryBudgets
            .where((b) => b.totalSpent > 0 || (b.amountLimit != null && b.amountLimit! > 0))
            .toList() ??
        [];

    double totalExpenseSpent = expenseBudgets.fold(0.0, (sum, item) => sum + item.totalSpent);

    // Prepare pie chart sections
    List<PieChartSectionData> sections = [];
    for (int i = 0; i < expenseBudgets.length; i++) {
      final b = expenseBudgets[i];
      final color = _chartColors[i % _chartColors.length];
      final percentage = totalExpenseSpent > 0 ? (b.totalSpent / totalExpenseSpent) * 100 : 0.0;

      sections.add(
        PieChartSectionData(
          color: color,
          value: b.totalSpent > 0 ? b.totalSpent : 0.1,
          title: percentage >= 5 ? "${percentage.toStringAsFixed(0)}%" : "",
          radius: 40,
          titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F1621),
      appBar: AppBar(
        title: const Text("Analytics & Budgets", style: TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Pie Chart section
            if (totalExpenseSpent > 0) ...[
              const Text(
                "Expense Proportions",
                style: TextStyle(fontFamily: 'Manrope', fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 180,
                child: PieChart(
                  PieChartData(
                    sections: sections,
                    centerSpaceRadius: 40,
                    sectionsSpace: 2,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Chart Legend
              Wrap(
                spacing: 12,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: List.generate(expenseBudgets.length, (index) {
                  final b = expenseBudgets[index];
                  final color = _chartColors[index % _chartColors.length];
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                      const SizedBox(width: 4),
                      Text(
                        "${b.categoryName} (${b.totalSpent.toStringAsFixed(0)})",
                        style: const TextStyle(fontSize: 12, color: Colors.white70),
                      ),
                    ],
                  );
                }),
              ),
            ] else ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40.0),
                child: Text(
                  "No expense data to analyze for this month.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white.withOpacity(0.5)),
                ),
              )
            ],
            const SizedBox(height: 100), // Safe scroll space
          ],
        ),
      ),
    );
  }
}
