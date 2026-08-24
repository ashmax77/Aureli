import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../providers/budget_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../models/category_model.dart';
import '../../widgets/glass_card.dart';

class AnalyticsView extends StatefulWidget {
  const AnalyticsView({super.key});

  @override
  State<AnalyticsView> createState() => _AnalyticsViewState();
}

class _AnalyticsViewState extends State<AnalyticsView> {
  int? _selectedCategoryId;
  final _limitController = TextEditingController();
  bool _isSaving = false;

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
    _limitController.dispose();
    super.dispose();
  }

  Future<void> _adjustBudget() async {
    final limit = double.tryParse(_limitController.text) ?? 0.0;
    if (limit <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a valid budget limit"), backgroundColor: Colors.red),
      );
      return;
    }
    if (_selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a category"), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isSaving = true);
    final budgetProvider = Provider.of<BudgetProvider>(context, listen: false);

    final result = await budgetProvider.setCategoryBudget(
      categoryId: _selectedCategoryId!,
      month: DateTime(budgetProvider.selectedYear, budgetProvider.selectedMonth, 1),
      limit: limit,
    );

    if (mounted) {
      setState(() => _isSaving = false);
      if (result != null) {
        _limitController.clear();
        _selectedCategoryId = null;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Budget limit updated successfully"), backgroundColor: Color(0xFF147D64)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final budgetProvider = Provider.of<BudgetProvider>(context);
    final transactionProvider = Provider.of<TransactionProvider>(context);
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
            const SizedBox(height: 32),

            // 2. Adjust Category Limit form
            const Text(
              "Adjust Budget Limits",
              style: TextStyle(fontFamily: 'Manrope', fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 12),
            GlassCard(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<int>(
                    value: _selectedCategoryId,
                    dropdownColor: const Color(0xFF141B26),
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: "Select Category",
                      labelStyle: TextStyle(color: Colors.white70),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                    ),
                    items: transactionProvider.categories
                        .where((c) => c.type == TransactionType.EXPENSE)
                        .map((c) => DropdownMenuItem<int>(value: c.id, child: Text(c.name)))
                        .toList(),
                    onChanged: (val) {
                      setState(() => _selectedCategoryId = val);
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _limitController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: "Monthly Limit Amount (LKR)",
                      labelStyle: TextStyle(color: Colors.white70),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _isSaving
                      ? const Center(child: CircularProgressIndicator(color: Color(0xFF147D64)))
                      : ElevatedButton(
                          onPressed: _adjustBudget,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0B3B5A),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text("Save Limit Setup", style: TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.bold)),
                        ),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
