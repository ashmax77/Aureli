import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/budget_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../models/category_model.dart';
import '../../widgets/glass_card.dart';

class BudgetsView extends StatefulWidget {
  const BudgetsView({super.key});

  @override
  State<BudgetsView> createState() => _BudgetsViewState();
}

class _BudgetsViewState extends State<BudgetsView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<BudgetProvider>(context, listen: false).fetchSummary();
      Provider.of<TransactionProvider>(context, listen: false).fetchCategories();
    });
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
    final limitController = TextEditingController();
    bool isSaving = false;

    // Prefill limit if category has one in the current month summary
    final budgetProvider = Provider.of<BudgetProvider>(context, listen: false);
    if (category != null) {
      final summaryItem = budgetProvider.summary?.categoryBudgets
          .firstWhere((b) => b.categoryId == category.id, orElse: () => null as dynamic);
      if (summaryItem != null && summaryItem.amountLimit != null) {
        limitController.text = summaryItem.amountLimit!.toStringAsFixed(0);
      }
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF141B26),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                  if (type == TransactionType.EXPENSE) ...[
                    const SizedBox(height: 20),
                    TextField(
                      controller: limitController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: "Monthly Budget Limit (LKR)",
                        labelStyle: TextStyle(color: Colors.white60),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF147D64))),
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel", style: TextStyle(color: Colors.white60)),
                ),
                isSaving
                    ? const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16.0),
                        child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Color(0xFF147D64), strokeWidth: 2)),
                      )
                    : ElevatedButton(
                        onPressed: () async {
                          final name = nameController.text.trim();
                          if (name.isEmpty) return;

                          setDialogState(() => isSaving = true);
                          final transProvider = Provider.of<TransactionProvider>(context, listen: false);
                          final budgetProv = Provider.of<BudgetProvider>(context, listen: false);

                          bool success;
                          int? categoryId = category?.id;
                          if (category == null) {
                            success = await transProvider.createCategory(name, type);
                            if (success && transProvider.categories.isNotEmpty) {
                              categoryId = transProvider.categories.last.id;
                            }
                          } else {
                            success = await transProvider.updateCategory(category.id, name, type);
                          }

                          if (success && type == TransactionType.EXPENSE && categoryId != null) {
                            final limit = double.tryParse(limitController.text) ?? 0.0;
                            if (limit > 0) {
                              await budgetProv.setCategoryBudget(
                                categoryId: categoryId,
                                month: DateTime(budgetProv.selectedYear, budgetProv.selectedMonth, 1),
                                limit: limit,
                              );
                            }
                          }

                          if (context.mounted) {
                            setDialogState(() => isSaving = false);
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(category == null ? "Category '$name' created!" : "Category updated!"),
                                backgroundColor: const Color(0xFF147D64),
                              ),
                            );
                            budgetProv.fetchSummary();
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
    final transactionProvider = Provider.of<TransactionProvider>(context);
    final budgetProvider = Provider.of<BudgetProvider>(context);
    final summary = budgetProvider.summary;

    final activeCategories = transactionProvider.categories.where((c) => !c.isArchived).toList();
    final archivedCategories = transactionProvider.categories.where((c) => c.isArchived).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0F1621),
      appBar: AppBar(
        title: const Text("Aureli", style: TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await budgetProvider.fetchSummary();
          await transactionProvider.fetchCategories();
        },
        color: const Color(0xFF147D64),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Header Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Categories",
                        style: TextStyle(fontFamily: 'Manrope', fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Manage your spending buckets.",
                        style: TextStyle(fontFamily: 'Manrope', fontSize: 14, color: Colors.white.withOpacity(0.6)),
                      ),
                    ],
                  ),
                  ElevatedButton(
                    onPressed: () => _showCategoryFormDialog(context),
                    style: ElevatedButton.styleFrom(
                      shape: const CircleBorder(),
                      padding: const EdgeInsets.all(16),
                      backgroundColor: const Color(0xFF0B3B5A),
                      foregroundColor: Colors.white,
                    ),
                    child: const Icon(Icons.add_rounded, size: 24),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // 2. Active Section
              const Text(
                "Active",
                style: TextStyle(fontFamily: 'Manrope', fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white70),
              ),
              const SizedBox(height: 12),
              activeCategories.isEmpty
                  ? GlassCard(
                      padding: const EdgeInsets.all(20),
                      child: Center(
                        child: Text(
                          "No active categories yet.",
                          style: TextStyle(color: Colors.white.withOpacity(0.4)),
                        ),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: activeCategories.length,
                      itemBuilder: (context, index) {
                        final cat = activeCategories[index];
                        final isExpense = cat.type == TransactionType.EXPENSE;

                        // Find spending summary for this category
                        final summaryItem = summary?.categoryBudgets
                            .firstWhere((b) => b.categoryId == cat.id, orElse: () => null as dynamic);
                        
                        final double spent = summaryItem?.totalSpent ?? 0.0;
                        final double? limit = summaryItem?.amountLimit;
                        final int count = summaryItem?.transactionCount ?? 0;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: GlassCard(
                            padding: const EdgeInsets.all(16),
                            child: InkWell(
                              onTap: () => _showCategoryFormDialog(context, category: cat),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 20,
                                    backgroundColor: (isExpense ? const Color(0xFF0B3B5A) : const Color(0xFF147D64)).withOpacity(0.2),
                                    child: Icon(
                                      _getCategoryIcon(cat.name),
                                      color: isExpense ? const Color(0xFF4C9FD1) : const Color(0xFF147D64),
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          cat.name,
                                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16, fontFamily: 'Manrope'),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          "$count Transactions",
                                          style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.5), fontFamily: 'Manrope'),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        "LKR ${NumberFormat('#,##0').format(spent)}",
                                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16, fontFamily: 'Manrope'),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        limit != null ? "Limit: LKR ${NumberFormat('#,##0').format(limit)}" : "This month",
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: limit != null && spent > limit ? const Color(0xFFCD5C52) : Colors.white54,
                                          fontFamily: 'Manrope',
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(width: 4),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFCD5C52), size: 20),
                                    onPressed: () => _confirmDeleteCategory(context, cat),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
              const SizedBox(height: 24),

              // 3. Archived Section
              if (archivedCategories.isNotEmpty) ...[
                const Text(
                  "Archived 🗑️",
                  style: TextStyle(fontFamily: 'Manrope', fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white70),
                ),
                const SizedBox(height: 12),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: archivedCategories.length,
                  itemBuilder: (context, index) {
                    final cat = archivedCategories[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: GlassCard(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: Colors.white.withOpacity(0.04),
                              child: Icon(
                                _getCategoryIcon(cat.name),
                                color: Colors.white38,
                                size: 16,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                cat.name,
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white38, fontSize: 14, fontFamily: 'Manrope'),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.restore_from_trash_rounded, color: Color(0xFF147D64), size: 20),
                              onPressed: () async {
                                final transProvider = Provider.of<TransactionProvider>(context, listen: false);
                                final success = await transProvider.updateCategory(cat.id, cat.name, cat.type);
                                if (success && context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text("Category '${cat.name}' restored!"), backgroundColor: const Color(0xFF147D64)),
                                  );
                                  budgetProvider.fetchSummary();
                                }
                              },
                              tooltip: "Restore Category",
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }
}
