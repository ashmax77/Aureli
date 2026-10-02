import 'package:aureli/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/budget_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../models/category_model.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/svg_icons.dart';
import '../../providers/auth_provider.dart';

class BudgetsView extends StatefulWidget {
  const BudgetsView({super.key});

  static void showCategoryFormDialog(BuildContext context,
      {CategoryModel? category}) {
    _BudgetsViewState.showCategoryFormDialog(context, category: category);
  }

  @override
  State<BudgetsView> createState() => _BudgetsViewState();
}

class _BudgetsViewState extends State<BudgetsView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<BudgetProvider>(context, listen: false).fetchSummary();
      Provider.of<TransactionProvider>(context, listen: false)
          .fetchCategories();
    });
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'LIMIT_EXCEEDED':
        return const Color(0xFFCD5C52); // Coral / Red
      case 'NEARING_90':
        return const Color(0xFFD68A19); // Amber / Warning
      case 'NORMAL':
      default:
        return const Color(0xFF147D64); // Emerald / Success
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'LIMIT_EXCEEDED':
        return 'LIMIT EXCEEDED';
      case 'NEARING_90':
        return 'NEARING LIMIT';
      case 'NORMAL':
      default:
        return 'ON TRACK';
    }
  }

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

    budgetProvider.changeMonth(newYear, newMonth);
  }

  IconData _getCategoryIcon(String name) {
    name = name.toLowerCase();
    if (name.contains('food') ||
        name.contains('eat') ||
        name.contains('grocer')) {
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
        name.contains('power')) {
      return Icons.lightbulb_outline_rounded;
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
    if (name.contains('salary') ||
        name.contains('work') ||
        name.contains('pay') ||
        name.contains('income')) {
      return Icons.payments_rounded;
    }
    if (name.contains('edu') ||
        name.contains('school') ||
        name.contains('study') ||
        name.contains('book') ||
        name.contains('class')) {
      return Icons.school_rounded;
    }
    if (name.contains('medic') ||
        name.contains('health') ||
        name.contains('pharma') ||
        name.contains('doctor') ||
        name.contains('hospital') ||
        name.contains('pill')) {
      return Icons.medical_services_rounded;
    }
    return Icons.category_rounded;
  }

  static void showCategoryFormDialog(BuildContext context,
      {CategoryModel? category}) {
    final nameController = TextEditingController(text: category?.name ?? "");
    TransactionType type = category?.type ?? TransactionType.EXPENSE;
    final limitController = TextEditingController();
    Color selectedColor = category?.color ?? CategoryModel.defaultPalette[0];
    String selectedIconKey =
        AppSvgIcons.resolveIconKey(category?.iconKey, category?.name ?? "");
    bool isSaving = false;

    // Prefill limit if category has one in the current month summary
    final budgetProvider = Provider.of<BudgetProvider>(context, listen: false);
    double existingCategoryLimit = 0.0;
    if (category != null) {
      final matches = budgetProvider.summary?.categoryBudgets
              .where((b) => b.categoryId == category.id) ??
          [];
      final summaryItem = matches.isNotEmpty ? matches.first : null;
      if (summaryItem != null && summaryItem.amountLimit != null) {
        existingCategoryLimit = summaryItem.amountLimit!;
        limitController.text = existingCategoryLimit.toStringAsFixed(0);
      }
    }

    final summary = budgetProvider.summary;
    final bool hasIncome = summary != null && summary.totalIncome > 0;
    final double availableMargin = hasIncome
        ? (summary.unallocatedAllowance + existingCategoryLimit)
        : 0.0;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final dialogBg = context.cardLightBg;
            final textPrimary = context.textPrimary;

            return AlertDialog(
              backgroundColor: dialogBg,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: Text(
                category == null ? "Create Category" : "Edit Category",
                style: TextStyle(
                    color: textPrimary,
                    fontFamily: 'Manrope',
                    fontWeight: FontWeight.bold),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: nameController,
                      autofocus: category == null,
                      style: TextStyle(color: textPrimary),
                      decoration: InputDecoration(
                        labelText: "Category Name",
                        labelStyle: TextStyle(
                            color: isDark
                                ? Colors.white60
                                : const Color(0xFF64748B)),
                        enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: context.divider)),
                        focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Color(0xFF147D64))),
                      ),
                      onChanged: (val) {
                        if (category == null) {
                          setDialogState(() {
                            selectedIconKey =
                                AppSvgIcons.resolveIconKey(null, val);
                          });
                        }
                      },
                    ),
                    SizedBox(height: 16),
                    Text("Type",
                        style: TextStyle(
                            color: isDark
                                ? Colors.white60
                                : const Color(0xFF64748B),
                            fontSize: 12)),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: Center(child: Text("EXPENSE")),
                            selected: type == TransactionType.EXPENSE,
                            onSelected: category != null
                                ? null
                                : (selected) {
                                    setDialogState(
                                        () => type = TransactionType.EXPENSE);
                                  },
                            selectedColor: const Color(0xFF0B3B5A),
                            backgroundColor: isDark
                                ? Colors.white.withValues(alpha: 0.04)
                                : const Color(0xFFF1F5F9),
                            labelStyle: TextStyle(
                                color: type == TransactionType.EXPENSE
                                    ? Colors.white
                                    : (isDark
                                        ? Colors.white60
                                        : const Color(0xFF64748B))),
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: ChoiceChip(
                            label: Center(child: Text("INCOME")),
                            selected: type == TransactionType.INCOME,
                            onSelected: category != null
                                ? null
                                : (selected) {
                                    setDialogState(
                                        () => type = TransactionType.INCOME);
                                  },
                            selectedColor: const Color(0xFF147D64),
                            backgroundColor: isDark
                                ? Colors.white.withValues(alpha: 0.04)
                                : const Color(0xFFF1F5F9),
                            labelStyle: TextStyle(
                                color: type == TransactionType.INCOME
                                    ? Colors.white
                                    : (isDark
                                        ? Colors.white60
                                        : const Color(0xFF64748B))),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    Text("Category Color",
                        style: TextStyle(
                            color: isDark
                                ? Colors.white60
                                : const Color(0xFF64748B),
                            fontSize: 12)),
                    SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: CategoryModel.defaultPalette.map((color) {
                        final isSelected = selectedColor.value == color.value;
                        return GestureDetector(
                          onTap: () =>
                              setDialogState(() => selectedColor = color),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected
                                    ? Colors.white
                                    : Colors.transparent,
                                width: 2.5,
                              ),
                            ),
                            child: isSelected
                                ? Icon(Icons.check_rounded,
                                    color: context.textPrimary, size: 16)
                                : null,
                          ),
                        );
                      }).toList(),
                    ),
                    SizedBox(height: 16),
                    Text("Category Icon",
                        style: TextStyle(
                            color: isDark
                                ? Colors.white60
                                : const Color(0xFF64748B),
                            fontSize: 12)),
                    SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children:
                          AppSvgIcons.availableCategoryIconKeys.map((iconKey) {
                        final isSelected = selectedIconKey == iconKey;
                        return GestureDetector(
                          onTap: () =>
                              setDialogState(() => selectedIconKey = iconKey),
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? selectedColor.withValues(alpha: 0.3)
                                  : (isDark
                                      ? Colors.white.withValues(alpha: 0.04)
                                      : const Color(0xFFF1F5F9)),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected
                                    ? selectedColor
                                    : (isDark
                                        ? Colors.white10
                                        : const Color(0xFFE2E8F0)),
                                width: 1.5,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: AppSvgIcons.getCategorySvg(iconKey, "",
                                size: 18,
                                color: isSelected
                                    ? selectedColor
                                    : (context.textSecondary)),
                          ),
                        );
                      }).toList(),
                    ),
                    if (type == TransactionType.EXPENSE) ...[
                      SizedBox(height: 16),
                      TextField(
                        controller: limitController,
                        keyboardType: TextInputType.number,
                        style: TextStyle(color: context.textPrimary),
                        decoration: InputDecoration(
                          labelText: "Monthly Budget Limit (LKR)",
                          labelStyle: TextStyle(
                              color:
                                  isDark ? Colors.white60 : Color(0xFF64748B)),
                          enabledBorder: UnderlineInputBorder(
                              borderSide: BorderSide(color: context.divider)),
                          focusedBorder: const UnderlineInputBorder(
                              borderSide: BorderSide(color: Color(0xFF147D64))),
                        ),
                      ),
                      if (hasIncome) ...[
                        SizedBox(height: 8),
                        Container(
                          padding:
                              EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFF2CB8A0).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: const Color(0xFF2CB8A0)
                                    .withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.account_balance_wallet_outlined,
                                  size: 16, color: Color(0xFF2CB8A0)),
                              SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  "Available Unallocated Margin: LKR ${NumberFormat('#,##0').format(availableMargin)}",
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF2CB8A0),
                                    fontFamily: 'Manrope',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text("Cancel",
                      style: TextStyle(
                          color: isDark
                              ? Colors.white60
                              : const Color(0xFF64748B))),
                ),
                isSaving
                    ? Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16.0),
                        child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                color: Color(0xFF147D64), strokeWidth: 2)),
                      )
                    : ElevatedButton(
                        onPressed: () async {
                          final name = nameController.text.trim();
                          if (name.isEmpty) return;

                          final limit =
                              double.tryParse(limitController.text) ?? 0.0;
                          if (type == TransactionType.EXPENSE &&
                              limit > 0 &&
                              hasIncome &&
                              limit > availableMargin) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  "Limit of LKR ${NumberFormat('#,##0').format(limit)} exceeds available unallocated allowance of LKR ${NumberFormat('#,##0').format(availableMargin)}",
                                ),
                                backgroundColor: const Color(0xFFCD5C52),
                              ),
                            );
                            return;
                          }

                          setDialogState(() => isSaving = true);
                          final transProvider =
                              Provider.of<TransactionProvider>(context,
                                  listen: false);
                          final budgetProv = Provider.of<BudgetProvider>(
                              context,
                              listen: false);

                          final colorHex =
                              '#${selectedColor.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
                          bool success;
                          int? categoryId = category?.id;
                          if (category == null) {
                            success = await transProvider.createCategory(
                              name,
                              type,
                              colorKey: colorHex,
                              iconKey: selectedIconKey,
                            );
                            if (success &&
                                transProvider.categories.isNotEmpty) {
                              final matches = transProvider.categories.where(
                                  (c) =>
                                      c.name.toLowerCase() ==
                                      name.toLowerCase());
                              categoryId = matches.isNotEmpty
                                  ? matches.last.id
                                  : transProvider.categories.last.id;
                            }
                          } else {
                            success = await transProvider.updateCategory(
                              category.id,
                              name,
                              type,
                              colorKey: colorHex,
                              iconKey: selectedIconKey,
                            );
                          }

                          bool budgetSuccess = true;
                          if (success &&
                              type == TransactionType.EXPENSE &&
                              categoryId != null) {
                            if (limit > 0) {
                              final res = await budgetProv.setCategoryBudget(
                                categoryId: categoryId,
                                month: DateTime(budgetProv.selectedYear,
                                    budgetProv.selectedMonth, 1),
                                limit: limit,
                              );
                              if (res == null &&
                                  budgetProv.errorMessage != null) {
                                budgetSuccess = false;
                              }
                            }
                          }

                          if (context.mounted) {
                            setDialogState(() => isSaving = false);
                            Navigator.pop(context);
                            if (!budgetSuccess &&
                                budgetProv.errorMessage != null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(budgetProv.errorMessage!),
                                  backgroundColor: const Color(0xFFCD5C52),
                                ),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(category == null
                                      ? "Category '$name' created!"
                                      : "Category updated!"),
                                  backgroundColor: const Color(0xFF147D64),
                                ),
                              );
                            }
                            budgetProv.fetchSummary();
                          }
                        },
                        style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF147D64)),
                        child: Text(category == null ? "Create" : "Save",
                            style: TextStyle(color: context.textPrimary)),
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
          backgroundColor: context.cardLightBg,
          title: Text("Delete Category",
              style: TextStyle(
                  color: context.textPrimary,
                  fontFamily: 'Manrope',
                  fontWeight: FontWeight.bold)),
          content: Text(
            "Are you sure you want to delete '${category.name}'? This will archive the category.",
            style: TextStyle(color: context.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Cancel"),
            ),
            TextButton(
              onPressed: () async {
                final nav = Navigator.of(context);
                final messenger = ScaffoldMessenger.of(context);
                nav.pop();
                try {
                  final provider =
                      Provider.of<TransactionProvider>(context, listen: false);
                  final success = await provider.deleteCategory(category.id);
                  if (success) {
                    await Provider.of<BudgetProvider>(context, listen: false)
                        .fetchSummary();
                    messenger.showSnackBar(
                      SnackBar(
                          content:
                              Text("Category '${category.name}' archived")),
                    );
                  } else {
                    messenger.showSnackBar(
                      SnackBar(
                          content: Text(provider.errorMessage ??
                              "Failed to delete category"),
                          backgroundColor: Colors.red),
                    );
                  }
                } catch (e) {
                  messenger.showSnackBar(
                    SnackBar(
                        content: Text("Error: $e"),
                        backgroundColor: Colors.red),
                  );
                }
              },
              child: Text("Delete", style: TextStyle(color: Colors.red)),
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

    final activeCategories =
        transactionProvider.categories.where((c) => !c.isArchived).toList();
    final archivedCategories =
        transactionProvider.categories.where((c) => c.isArchived).toList();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text("Budgets",
            style: TextStyle(
                fontFamily: 'Manrope',
                fontWeight: FontWeight.bold,
                color: context.textPrimary)),
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
          padding: EdgeInsets.symmetric(horizontal: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Month Selector
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
                    onPressed:
                        _canGoToPreviousMonth() ? () => _changeMonth(-1) : null,
                  ),
                  Text(
                    DateFormat('MMMM yyyy').format(DateTime(
                        budgetProvider.selectedYear,
                        budgetProvider.selectedMonth)),
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: context.textPrimary,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.chevron_right_rounded,
                        color: (context.textSecondary)),
                    onPressed: () => _changeMonth(1),
                  ),
                ],
              ),
              SizedBox(height: 16),

              // Spendable Allowance & Locked Savings Breakdown Card
              GlassCard(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.account_balance_wallet_rounded,
                                color: Color(0xFF2CB8A0), size: 18),
                            SizedBox(width: 8),
                            Text(
                              "Spendable Allowance",
                              style: TextStyle(
                                fontFamily: 'Manrope',
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.9)
                                    : const Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          "LKR ${NumberFormat('#,##0').format(summary?.spendableAllowance ?? 0.0)}",
                          style: TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2CB8A0),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 10),
                    Divider(
                        color: (isDark ? Colors.white10 : Color(0xFFE2E8F0)),
                        height: 1),
                    SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.savings_rounded,
                                color: Color(0xFFE89A58), size: 14),
                            SizedBox(width: 6),
                            Text(
                              "Locked Savings (${(summary?.savingsRatePercentage ?? 20.0).toInt()}%)",
                              style: TextStyle(
                                  fontSize: 11,
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.55)
                                      : const Color(0xFF64748B),
                                  fontFamily: 'Manrope'),
                            ),
                          ],
                        ),
                        Text(
                          "LKR ${NumberFormat('#,##0').format(summary?.monthlyReservedSavings ?? 0.0)}",
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFE89A58),
                              fontFamily: 'Manrope'),
                        ),
                      ],
                    ),
                    SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.pie_chart_outline_rounded,
                                color: Color(0xFF6C8CFF), size: 14),
                            SizedBox(width: 6),
                            Text(
                              "Unallocated to Limits",
                              style: TextStyle(
                                  fontSize: 11,
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.55)
                                      : const Color(0xFF64748B),
                                  fontFamily: 'Manrope'),
                            ),
                          ],
                        ),
                        Text(
                          "LKR ${NumberFormat('#,##0').format(summary?.unallocatedAllowance ?? 0.0)}",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: (summary?.unallocatedAllowance ?? 0.0) > 0
                                ? const Color(0xFF6C8CFF)
                                : (isDark
                                    ? Colors.white38
                                    : const Color(0xFF94A3B8)),
                            fontFamily: 'Manrope',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16),

              // 2. Active Section
              Text(
                "Active",
                style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: (context.textSecondary)),
              ),
              SizedBox(height: 12),
              activeCategories.isEmpty
                  ? GlassCard(
                      padding: EdgeInsets.all(20),
                      child: Center(
                        child: Text(
                          "No active categories yet.",
                          style: TextStyle(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.4)
                                  : const Color(0xFF94A3B8)),
                        ),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: activeCategories.length,
                      itemBuilder: (context, index) {
                        final cat = activeCategories[index];

                        // Find spending summary for this category
                        final matches = summary?.categoryBudgets
                                .where((b) => b.categoryId == cat.id) ??
                            [];
                        final summaryItem =
                            matches.isNotEmpty ? matches.first : null;

                        final double spent = summaryItem?.totalSpent ?? 0.0;
                        final double? limit = summaryItem?.amountLimit;
                        final int count = summaryItem?.transactionCount ?? 0;
                        final String status = summaryItem?.status ?? 'NORMAL';
                        final color = _getStatusColor(status);
                        final isOver = limit != null && spent > limit;
                        final progress = limit != null && limit > 0
                            ? (spent / limit).clamp(0.0, 1.0)
                            : 0.0;

                        return Container(
                          margin: EdgeInsets.only(bottom: 14),
                          child: GlassCard(
                            padding: EdgeInsets.all(16),
                            child: InkWell(
                              onTap: () => showCategoryFormDialog(context,
                                  category: cat),
                              borderRadius: BorderRadius.circular(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 20,
                                        backgroundColor:
                                            cat.color.withValues(alpha: 0.2),
                                        child: AppSvgIcons.getCategorySvg(
                                          cat.iconKey,
                                          cat.name,
                                          color: cat.color,
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
                                              cat.name,
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: context.textPrimary,
                                                fontSize: 16,
                                                fontFamily: 'Manrope',
                                              ),
                                            ),
                                            SizedBox(height: 3),
                                            Text(
                                              limit != null
                                                  ? "LKR ${NumberFormat('#,##0').format(spent)} spent of ${NumberFormat('#,##0').format(limit)} · $count Trans."
                                                  : "LKR ${NumberFormat('#,##0').format(spent)} spent · $count Trans.",
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: context.textPrimary
                                                    .withValues(alpha: 0.55),
                                                fontFamily: 'Manrope',
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (limit != null) ...[
                                        Container(
                                          padding: EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color:
                                                color.withValues(alpha: 0.15),
                                            borderRadius:
                                                BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            _getStatusText(status),
                                            style: TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                              color: color,
                                              fontFamily: 'Manrope',
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ),
                                        SizedBox(width: 4),
                                      ],
                                      IconButton(
                                        icon: Icon(Icons.delete_outline_rounded,
                                            color: Color(0xFFCD5C52), size: 20),
                                        onPressed: () => _confirmDeleteCategory(
                                            context, cat),
                                        tooltip: "Delete Category",
                                        visualDensity: VisualDensity.compact,
                                      ),
                                    ],
                                  ),
                                  if (limit != null) ...[
                                    SizedBox(height: 12),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: LinearProgressIndicator(
                                        value: progress,
                                        minHeight: 6,
                                        backgroundColor: (isDark
                                            ? Colors.white10
                                            : const Color(0xFFE2E8F0)),
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                                color),
                                      ),
                                    ),
                                    SizedBox(height: 6),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          isOver
                                              ? "Over budget by LKR ${NumberFormat('#,##0').format(spent - limit)}"
                                              : "LKR ${NumberFormat('#,##0').format(limit - spent)} remaining",
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: isOver
                                                ? const Color(0xFFCD5C52)
                                                : Colors.white38,
                                            fontFamily: 'Manrope',
                                          ),
                                        ),
                                        Text(
                                          limit > 0
                                              ? "${((spent / limit) * 100).toInt()}%"
                                              : "0%",
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: color,
                                            fontFamily: 'Manrope',
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
              SizedBox(height: 24),

              // 3. Archived Section
              if (archivedCategories.isNotEmpty) ...[
                Row(
                  children: [
                    Text(
                      "Archived",
                      style: TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: (context.textSecondary)),
                    ),
                    SizedBox(width: 6),
                    AppSvgIcons.trash(size: 15, color: (context.textSecondary)),
                  ],
                ),
                SizedBox(height: 12),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: archivedCategories.length,
                  itemBuilder: (context, index) {
                    final cat = archivedCategories[index];
                    return Container(
                      margin: EdgeInsets.only(bottom: 12),
                      child: GlassCard(
                        padding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: isDark
                                  ? Colors.white.withValues(alpha: 0.04)
                                  : const Color(0xFFF1F5F9),
                              child: Icon(
                                _getCategoryIcon(cat.name),
                                color: context.textLight,
                                size: 16,
                              ),
                            ),
                            SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                cat.name,
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: context.textLight,
                                    fontSize: 14,
                                    fontFamily: 'Manrope'),
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.restore_from_trash_rounded,
                                  color: Color(0xFF147D64), size: 20),
                              onPressed: () async {
                                final transProvider =
                                    Provider.of<TransactionProvider>(context,
                                        listen: false);
                                final success = await transProvider
                                    .updateCategory(cat.id, cat.name, cat.type);
                                if (success && context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content: Text(
                                            "Category '${cat.name}' restored!"),
                                        backgroundColor:
                                            const Color(0xFF147D64)),
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
              SizedBox(height: 100),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showCategoryFormDialog(context),
        backgroundColor: const Color(0xFF147D64),
        foregroundColor: context.textPrimary,
        elevation: 6,
        shape: const CircleBorder(),
        child: Icon(Icons.add_rounded, size: 28),
      ),
    );
  }
}
