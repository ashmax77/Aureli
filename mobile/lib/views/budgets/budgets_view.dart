import 'package:aureli/theme/app_colors.dart';
import '../../widgets/money_text.dart';
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
      case 'EXCEEDED_100':
      case 'LIMIT_EXCEEDED':
        return context.tokens.coral; // Coral / Red
      case 'NEARING_90':
        return context.tokens.amber; // Amber / Warning
      case 'NORMAL':
      default:
        return context.tokens.emerald; // Emerald / Success
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'EXCEEDED_100':
      case 'LIMIT_EXCEEDED':
        return 'Limit exceeded';
      case 'NEARING_90':
        return 'Nearing limit';
      case 'NORMAL':
      default:
        return 'On track';
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
                            color: context.tokens.inkMuted),
                        enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: context.divider)),
                        focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: context.tokens.emerald)),
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
                            color: context.tokens.inkMuted,
                            fontSize: 12)),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: Center(child: Text("Expense")),
                            selected: type == TransactionType.EXPENSE,
                            onSelected: category != null
                                ? null
                                : (selected) {
                                    setDialogState(
                                        () => type = TransactionType.EXPENSE);
                                  },
                            selectedColor: const Color(0xFF0B3B5A),
                            backgroundColor: context.tokens.inputFill,
                            labelStyle: TextStyle(
                                color: type == TransactionType.EXPENSE
                                    ? Colors.white
                                    : (context.tokens.inkMuted)),
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: ChoiceChip(
                            label: Center(child: Text("Income")),
                            selected: type == TransactionType.INCOME,
                            onSelected: category != null
                                ? null
                                : (selected) {
                                    setDialogState(
                                        () => type = TransactionType.INCOME);
                                  },
                            selectedColor: context.tokens.emerald,
                            backgroundColor: context.tokens.inputFill,
                            labelStyle: TextStyle(
                                color: type == TransactionType.INCOME
                                    ? Colors.white
                                    : (context.tokens.inkMuted)),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    Text("Category Color",
                        style: TextStyle(
                            color: context.tokens.inkMuted,
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
                            color: context.tokens.inkMuted,
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
                                  : (context.tokens.inputFill),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected
                                    ? selectedColor
                                    : (context.tokens.hairline),
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
                                  context.tokens.inkMuted),
                          enabledBorder: UnderlineInputBorder(
                              borderSide: BorderSide(color: context.divider)),
                          focusedBorder: UnderlineInputBorder(
                              borderSide: BorderSide(color: context.tokens.emerald)),
                        ),
                      ),
                      if (hasIncome) ...[
                        SizedBox(height: 8),
                        Container(
                          padding:
                              EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color:
                                context.tokens.emerald.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: context.tokens.emerald
                                    .withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.account_balance_wallet_outlined,
                                  size: 16, color: context.tokens.emerald),
                              SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  "Available Unallocated Margin: LKR ${formatAmount(availableMargin)}",
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: context.tokens.emerald,
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
                          color: context.tokens.inkMuted)),
                ),
                isSaving
                    ? Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16.0),
                        child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                color: context.tokens.emerald, strokeWidth: 2)),
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
                                  "Limit of LKR ${formatAmount(limit)} exceeds available unallocated allowance of LKR ${formatAmount(availableMargin)}",
                                ),
                                backgroundColor: context.tokens.coral,
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

                          if (!success) {
                            // Keep the dialog open so the user's input isn't lost, and say why.
                            if (context.mounted) {
                              setDialogState(() => isSaving = false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(transProvider.actionErrorMessage ??
                                      "Could not save the category"),
                                  backgroundColor: context.tokens.coral,
                                ),
                              );
                            }
                            return;
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
                                  backgroundColor: context.tokens.coral,
                                ),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(category == null
                                      ? "Category '$name' created!"
                                      : "Category updated!"),
                                  backgroundColor: context.tokens.brand,
                                ),
                              );
                            }
                            budgetProv.fetchSummary();
                          }
                        },
                        style: ElevatedButton.styleFrom(
                            backgroundColor: context.tokens.brand),
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
                  final budgets =
                      Provider.of<BudgetProvider>(context, listen: false);
                  final success = await provider.deleteCategory(category.id);
                  if (success) {
                    await budgets.fetchSummary();
                    messenger.showSnackBar(
                      SnackBar(
                          content:
                              Text("Category '${category.name}' archived")),
                    );
                  } else {
                    messenger.showSnackBar(
                      SnackBar(
                          content: Text(provider.actionErrorMessage ??
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
        color: context.tokens.emerald,
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
                                color: context.tokens.emerald, size: 18),
                            SizedBox(width: 8),
                            Text(
                              "Spendable Allowance",
                              style: TextStyle(
                                fontFamily: 'Manrope',
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: context.tokens.ink,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          "LKR ${formatAmount(summary?.spendableAllowance ?? 0.0)}",
                          style: TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: context.tokens.emerald,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 10),
                    Divider(
                        color: (context.tokens.hairline),
                        height: 1),
                    SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.savings_rounded,
                                color: context.tokens.amber, size: 14),
                            SizedBox(width: 6),
                            Text(
                              "Locked Savings (${(summary?.savingsRatePercentage ?? 20.0).toInt()}%)",
                              style: TextStyle(
                                  fontSize: 11,
                                  color: context.tokens.inkMuted,
                                  fontFamily: 'Manrope'),
                            ),
                          ],
                        ),
                        Text(
                          "LKR ${formatAmount(summary?.monthlyReservedSavings ?? 0.0)}",
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: context.tokens.amber,
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
                                color: context.tokens.cobalt, size: 14),
                            SizedBox(width: 6),
                            Text(
                              "Unallocated to Limits",
                              style: TextStyle(
                                  fontSize: 11,
                                  color: context.tokens.inkMuted,
                                  fontFamily: 'Manrope'),
                            ),
                          ],
                        ),
                        Text(
                          "LKR ${formatAmount(summary?.unallocatedAllowance ?? 0.0)}",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: (summary?.unallocatedAllowance ?? 0.0) > 0
                                ? context.tokens.cobalt
                                : (context.tokens.inkMuted),
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
                              color: context.tokens.inkMuted),
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
                                                  ? "LKR ${formatAmount(spent)} spent of ${formatAmount(limit)} · $count Trans."
                                                  : "LKR ${formatAmount(spent)} spent · $count Trans.",
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
                                            ),
                                          ),
                                        ),
                                        SizedBox(width: 4),
                                      ],
                                      IconButton(
                                        icon: Icon(Icons.delete_outline_rounded,
                                            color: context.tokens.coral, size: 20),
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
                                        backgroundColor: (context.tokens.hairline),
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
                                              ? "Over budget by LKR ${formatAmount(spent - limit)}"
                                              : "LKR ${formatAmount(limit - spent)} remaining",
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: isOver
                                                ? context.tokens.coral
                                                : context.tokens.inkMuted,
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
                              backgroundColor: context.tokens.inputFill,
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
                                  color: context.tokens.emerald, size: 20),
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
                                            context.tokens.emerald),
                                  );
                                  budgetProvider.fetchSummary();
                                } else if (!success && context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content: Text(
                                            transProvider.actionErrorMessage ??
                                                "Could not restore the category"),
                                        backgroundColor:
                                            context.tokens.coral),
                                  );
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
        backgroundColor: context.tokens.brand,
        foregroundColor: context.textPrimary,
        elevation: 6,
        shape: const CircleBorder(),
        child: Icon(Icons.add_rounded, size: 28),
      ),
    );
  }
}
