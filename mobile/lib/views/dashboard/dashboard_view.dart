import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../providers/budget_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../models/category_model.dart';
import '../../models/transaction_model.dart';
import '../../widgets/glass_card.dart';

class DashboardView extends StatefulWidget {
  final VoidCallback onViewTransactions;
  final VoidCallback onViewAnalytics;

  const DashboardView({
    super.key,
    required this.onViewTransactions,
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
      Provider.of<BudgetProvider>(context, listen: false).fetchSummary();
      Provider.of<TransactionProvider>(context, listen: false).fetchCategories();
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

  Color _getStatusColor(String status) {
    switch (status) {
      case 'EXCEEDED_100':
        return const Color(0xFFB42318); // Red
      case 'NEARING_90':
        return const Color(0xFFB45309); // Amber
      case 'NORMAL':
      default:
        return const Color(0xFF147D64); // Emerald
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'EXCEEDED_100':
        return 'LIMIT EXCEEDED';
      case 'NEARING_90':
        return 'NEARING LIMIT';
      case 'NORMAL':
      default:
        return 'ON TRACK';
    }
  }

  void _showAddTransactionSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddTransactionSheet(),
    ).then((success) {
      if (success == true) {
        Provider.of<BudgetProvider>(context, listen: false).fetchSummary();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final budgetProvider = Provider.of<BudgetProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final summary = budgetProvider.summary;

    final monthName = DateFormat('MMMM').format(DateTime(budgetProvider.selectedYear, budgetProvider.selectedMonth));

    return Scaffold(
      backgroundColor: const Color(0xFF0F1621),
      appBar: AppBar(
        title: const Text(
          "Aureli",
          style: TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.white70),
            onPressed: () => authProvider.logout(),
            tooltip: "Logout",
          )
        ],
      ),
      body: budgetProvider.isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF147D64)))
          : RefreshIndicator(
              onRefresh: () => budgetProvider.fetchSummary(),
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
                          icon: const Icon(Icons.chevron_left_rounded, color: Colors.white70),
                          onPressed: () => _changeMonth(-1),
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
                          icon: const Icon(Icons.chevron_right_rounded, color: Colors.white70),
                          onPressed: () => _changeMonth(1),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // 2. Premium Net Cash Flow Glass Card
                    if (summary != null)
                      GlassCard(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          children: [
                            Text(
                              "NET CASH FLOW",
                              style: TextStyle(
                                fontFamily: 'Manrope',
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withOpacity(0.5),
                                letterSpacing: 1.0,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              "${summary.netCashFlow.toStringAsFixed(2)} LKR",
                              style: TextStyle(
                                fontFamily: 'Manrope',
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: summary.netCashFlow >= 0 ? const Color(0xFF147D64) : const Color(0xFFB42318),
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Divider(color: Colors.white10),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                Column(
                                  children: [
                                    Text(
                                      "INCOME",
                                      style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.5)),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      "+${summary.totalIncome.toStringAsFixed(0)}",
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF147D64),
                                      ),
                                    ),
                                  ],
                                ),
                                Container(width: 1, height: 24, color: Colors.white10),
                                Column(
                                  children: [
                                    Text(
                                      "EXPENSES",
                                      style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.5)),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      "-${summary.totalExpenses.toStringAsFixed(0)}",
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFFCD5C52),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            )
                          ],
                        ),
                      ),
                    const SizedBox(height: 24),

                    // 3. Category Budgets Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Category Budgets",
                          style: TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        TextButton(
                          onPressed: widget.onViewAnalytics,
                          child: const Text("View Analytics", style: TextStyle(color: Color(0xFF147D64))),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // 4. Progress Bars List
                    if (summary == null || summary.categoryBudgets.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40.0),
                        child: Text(
                          "No budgets set for this month.\nSet limits in the Analytics/Budget tab.",
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white.withOpacity(0.5)),
                        ),
                      )
                    else
                      ...summary.categoryBudgets.map((b) {
                        final progress = b.amountLimit != null && b.amountLimit! > 0
                            ? (b.totalSpent / b.amountLimit!).clamp(0.0, 1.0)
                            : 0.0;
                        final color = _getStatusColor(b.status);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 16.0),
                          padding: const EdgeInsets.all(16.0),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.04),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white.withOpacity(0.06)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor: const Color(0xFF0B3B5A).withOpacity(0.3),
                                    child: Icon(_getCategoryIcon(b.categoryName), color: Colors.white, size: 18),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          b.categoryName,
                                          style: const TextStyle(
                                            fontFamily: 'Manrope',
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          "${b.totalSpent.toStringAsFixed(0)} spent ${b.amountLimit != null ? 'of ${b.amountLimit!.toStringAsFixed(0)}' : 'no limit'}",
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.white.withOpacity(0.5),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: color.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      _getStatusText(b.status),
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: color,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (b.amountLimit != null) ...[
                                const SizedBox(height: 12),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: progress,
                                    minHeight: 6,
                                    backgroundColor: Colors.white10,
                                    valueColor: AlwaysStoppedAnimation<Color>(color),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      }),

                    const SizedBox(height: 100), // safe space for FAB
                  ],
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddTransactionSheet(context),
        backgroundColor: const Color(0xFF147D64), // Emerald
        foregroundColor: Colors.white,
        child: const Icon(Icons.add_rounded, size: 32),
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
    final amount = double.tryParse(_amountController.text) ?? 0.0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a valid amount"), backgroundColor: Colors.red),
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
    final transactionProvider = Provider.of<TransactionProvider>(context, listen: false);

    final success = await transactionProvider.createTransaction(
      type: _type,
      categoryId: _selectedCategoryId!,
      amount: amount,
      date: _selectedDate,
      paymentMethod: _paymentMethod,
      note: _noteController.text.trim().isNotEmpty ? _noteController.text.trim() : null,
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
    final categories = transactionProvider.categories.where((c) => c.type == _type).toList();

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
                decoration: const BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.all(Radius.circular(2))),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              "Add Transaction",
              style: TextStyle(fontFamily: 'Manrope', fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
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
                    labelStyle: TextStyle(color: _type == TransactionType.EXPENSE ? Colors.white : Colors.white60),
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
                    labelStyle: TextStyle(color: _type == TransactionType.INCOME ? Colors.white : Colors.white60),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Amount Field
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: "Amount (LKR)",
                labelStyle: TextStyle(color: Colors.white70),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF147D64))),
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
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
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
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
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
              title: const Text("Transaction Date", style: TextStyle(color: Colors.white70)),
              subtitle: Text(DateFormat('yyyy-MM-dd').format(_selectedDate), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              trailing: const Icon(Icons.calendar_today_rounded, color: Colors.white70),
              onTap: _selectDate,
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 12),

            // Note Field
            TextField(
              controller: _noteController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: "Note (Optional)",
                labelStyle: TextStyle(color: Colors.white70),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF147D64))),
              ),
            ),
            const SizedBox(height: 32),

            // Save button
            _isSaving
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF147D64)))
                : ElevatedButton(
                    onPressed: _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF147D64),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text("Save Transaction", style: TextStyle(fontFamily: 'Manrope', fontSize: 15, fontWeight: FontWeight.bold)),
                  ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
