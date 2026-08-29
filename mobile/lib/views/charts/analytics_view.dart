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

  IconData _getCategoryIcon(String name) {
    name = name.toLowerCase();
    if (name.contains('food') || name.contains('eat') || name.contains('grocer')) {
      return Icons.restaurant_rounded;
    }
    if (name.contains('rent') || name.contains('home') || name.contains('house')) {
      return Icons.home_work_rounded;
    }
    if (name.contains('utility') || name.contains('bill') || name.contains('water') || name.contains('power')) {
      return Icons.lightbulb_outline_rounded;
    }
    if (name.contains('travel') || name.contains('transport') || name.contains('car') || name.contains('fuel')) {
      return Icons.directions_car_filled_rounded;
    }
    if (name.contains('entertain') || name.contains('movie') || name.contains('fun') || name.contains('game')) {
      return Icons.sports_esports_rounded;
    }
    if (name.contains('salary') || name.contains('work') || name.contains('pay') || name.contains('income')) {
      return Icons.payments_rounded;
    }
    return Icons.category_rounded;
  }

  void _showCategoryFormDialog(BuildContext context, {CategoryModel? category}) {
    final nameController = TextEditingController(text: category?.name ?? "");
    TransactionType type = category?.type ?? TransactionType.EXPENSE;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF141B26),
              title: Text(
                category == null ? "Create Category" : "Edit Category",
                style: const TextStyle(color: Colors.white, fontFamily: 'Manrope', fontWeight: FontWeight.bold),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: nameController,
                    autofocus: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: "Category Name",
                      labelStyle: TextStyle(color: Colors.white60),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF147D64))),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text("Type", style: TextStyle(color: Colors.white60, fontSize: 12)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(child: Text("EXPENSE")),
                          selected: type == TransactionType.EXPENSE,
                          onSelected: category != null ? null : (selected) {
                            setDialogState(() => type = TransactionType.EXPENSE);
                          },
                          selectedColor: const Color(0xFF0B3B5A),
                          backgroundColor: Colors.white.withOpacity(0.04),
                          labelStyle: TextStyle(color: type == TransactionType.EXPENSE ? Colors.white : Colors.white60),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(child: Text("INCOME")),
                          selected: type == TransactionType.INCOME,
                          onSelected: category != null ? null : (selected) {
                            setDialogState(() => type = TransactionType.INCOME);
                          },
                          selectedColor: const Color(0xFF147D64),
                          backgroundColor: Colors.white.withOpacity(0.04),
                          labelStyle: TextStyle(color: type == TransactionType.INCOME ? Colors.white : Colors.white60),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel", style: TextStyle(color: Colors.white60)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final name = nameController.text.trim();
                    if (name.isEmpty) return;

                    final provider = Provider.of<TransactionProvider>(context, listen: false);
                    bool success;
                    if (category == null) {
                      success = await provider.createCategory(name, type);
                    } else {
                      success = await provider.updateCategory(category.id, name, type);
                    }

                    if (context.mounted) {
                      Navigator.pop(context);
                      if (success) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(category == null ? "Category '$name' created!" : "Category updated to '$name'!"),
                            backgroundColor: const Color(0xFF147D64),
                          ),
                        );
                        Provider.of<BudgetProvider>(context, listen: false).fetchSummary();
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(provider.errorMessage ?? "Failed to save category"),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF147D64)),
                  child: Text(category == null ? "Create" : "Save", style: const TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmDeleteCategory(BuildContext context, CategoryModel category) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF141B26),
          title: const Text("Delete Category", style: TextStyle(color: Colors.white, fontFamily: 'Manrope', fontWeight: FontWeight.bold)),
          content: Text(
            "Are you sure you want to delete '${category.name}'? This will archive the category.",
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel", style: TextStyle(color: Colors.white60)),
            ),
            ElevatedButton(
              onPressed: () async {
                final provider = Provider.of<TransactionProvider>(context, listen: false);
                final success = await provider.deleteCategory(category.id);

                if (context.mounted) {
                  Navigator.pop(context);
                  if (success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Category '${category.name}' deleted!"), backgroundColor: const Color(0xFF147D64)),
                    );
                    Provider.of<BudgetProvider>(context, listen: false).fetchSummary();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(provider.errorMessage ?? "Failed to delete category"), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFCD5C52)),
              child: const Text("Delete", style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
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
            // 3. Manage Categories section
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Manage Categories",
                  style: TextStyle(fontFamily: 'Manrope', fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                TextButton.icon(
                  onPressed: () => _showCategoryFormDialog(context),
                  icon: const Icon(Icons.add_rounded, size: 16, color: Color(0xFF147D64)),
                  label: const Text("New Category", style: TextStyle(color: Color(0xFF147D64), fontSize: 13, fontWeight: FontWeight.bold, fontFamily: 'Manrope')),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            GlassCard(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: transactionProvider.categories.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20.0),
                      child: Center(
                        child: Text(
                          "No categories found",
                          style: TextStyle(color: Colors.white.withOpacity(0.5)),
                        ),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: transactionProvider.categories.length,
                      separatorBuilder: (context, index) => const Divider(color: Colors.white10, height: 1),
                      itemBuilder: (context, index) {
                        final cat = transactionProvider.categories[index];
                        final isExpense = cat.type == TransactionType.EXPENSE;
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 2.0),
                          leading: CircleAvatar(
                            radius: 16,
                            backgroundColor: (isExpense ? const Color(0xFF0B3B5A) : const Color(0xFF147D64)).withOpacity(0.2),
                            child: Icon(
                              _getCategoryIcon(cat.name),
                              color: isExpense ? const Color(0xFF4C9FD1) : const Color(0xFF147D64),
                              size: 16,
                            ),
                          ),
                          title: Text(
                            cat.name,
                            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600, fontFamily: 'Manrope'),
                          ),
                          subtitle: Text(
                            isExpense ? "EXPENSE" : "INCOME",
                            style: TextStyle(color: isExpense ? const Color(0xFF4C9FD1) : const Color(0xFF147D64), fontSize: 10, fontWeight: FontWeight.bold, fontFamily: 'Manrope'),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_rounded, color: Colors.white60, size: 18),
                                onPressed: () => _showCategoryFormDialog(context, category: cat),
                                tooltip: "Edit Category",
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFCD5C52), size: 18),
                                onPressed: () => _confirmDeleteCategory(context, cat),
                                tooltip: "Delete Category",
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 100), // Safe scroll space
          ],
        ),
      ),
    );
  }
}
