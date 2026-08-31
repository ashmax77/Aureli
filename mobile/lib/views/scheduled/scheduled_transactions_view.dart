import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/scheduled_transaction_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/budget_provider.dart';
import '../../models/scheduled_transaction_model.dart';
import '../../widgets/glass_card.dart';

class ScheduledTransactionsScreen extends StatefulWidget {
  const ScheduledTransactionsScreen({super.key});

  @override
  State<ScheduledTransactionsScreen> createState() => _ScheduledTransactionsScreenState();
}

class _ScheduledTransactionsScreenState extends State<ScheduledTransactionsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ScheduledTransactionProvider>(context, listen: false)
          .fetchScheduledTransactions();
      Provider.of<TransactionProvider>(context, listen: false).fetchCategories();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showAddScheduledSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const AddScheduledTransactionSheet(),
    );
  }

  IconData _getCategoryIcon(String categoryName) {
    final name = categoryName.toLowerCase();
    if (name.contains('food') || name.contains('dining') || name.contains('eat')) return Icons.restaurant_rounded;
    if (name.contains('shop') || name.contains('grocer') || name.contains('market')) return Icons.shopping_bag_rounded;
    if (name.contains('bill') || name.contains('utilit') || name.contains('electric') || name.contains('water')) return Icons.receipt_long_rounded;
    if (name.contains('travel') || name.contains('transport') || name.contains('fuel')) return Icons.directions_car_rounded;
    if (name.contains('health') || name.contains('medical') || name.contains('doctor')) return Icons.medical_services_rounded;
    if (name.contains('entertain') || name.contains('movie') || name.contains('fun')) return Icons.movie_rounded;
    if (name.contains('rent') || name.contains('house') || name.contains('home')) return Icons.home_rounded;
    if (name.contains('salary') || name.contains('income') || name.contains('pay')) return Icons.account_balance_wallet_rounded;
    return Icons.category_rounded;
  }

  Widget _buildStatusBadge(ScheduledTransactionModel item) {
    final days = item.daysUntilDue;
    Color color;
    String text;
    IconData icon;

    if (days < 0) {
      color = const Color(0xFFCD5C52); // Coral Red
      text = "Overdue (${days.abs()}d)";
      icon = Icons.warning_amber_rounded;
    } else if (days == 0) {
      color = const Color(0xFF147D64); // Emerald Green
      text = "Due Today";
      icon = Icons.error_outline_rounded;
    } else if (days <= 3) {
      color = const Color(0xFFD68A19); // Amber
      text = "Due in $days d";
      icon = Icons.access_time_rounded;
    } else {
      color = const Color(0xFF6C8CFF); // Indigo
      text = "Due in $days d";
      icon = Icons.calendar_today_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.4), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduledCard(ScheduledTransactionModel item, ScheduledTransactionProvider provider) {
    final formattedDate = DateFormat('MMM d, yyyy').format(item.dueDate);
    final isPending = item.status == ScheduledStatus.PENDING;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: GlassCard(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF147D64).withOpacity(0.18),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _getCategoryIcon(item.categoryName),
                    color: const Color(0xFF2CB8A0),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: const TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Text(
                            item.categoryName,
                            style: TextStyle(
                              fontFamily: 'Manrope',
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.5),
                            ),
                          ),
                          if (item.recurringFrequency != ScheduledFrequency.ONCE) ...[
                            Text(
                              " • ${item.recurringFrequency.name.toLowerCase()}",
                              style: TextStyle(
                                fontFamily: 'Manrope',
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withOpacity(0.7),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      "LKR ${NumberFormat('#,##0').format(item.amount)}",
                      style: const TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (isPending) _buildStatusBadge(item),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(color: Colors.white10, height: 1),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.event_outlined, size: 14, color: Colors.white.withOpacity(0.5)),
                    const SizedBox(width: 4),
                    Text(
                      "Due $formattedDate",
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, size: 20, color: Colors.white38),
                      visualDensity: VisualDensity.compact,
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            backgroundColor: const Color(0xFF1B2432),
                            title: const Text("Delete Scheduled Payment?", style: TextStyle(color: Colors.white)),
                            content: Text("Are you sure you want to remove '${item.title}'?", style: const TextStyle(color: Colors.white70)),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text("Cancel", style: TextStyle(color: Colors.white54)),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text("Delete", style: TextStyle(color: Color(0xFFCD5C52))),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          await provider.deleteScheduledTransaction(item.id);
                        }
                      },
                    ),
                    if (isPending) ...[
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () async {
                          final txProvider = Provider.of<TransactionProvider>(context, listen: false);
                          final budgetProv = Provider.of<BudgetProvider>(context, listen: false);
                          final messenger = ScaffoldMessenger.of(context);

                          final success = await provider.payScheduledTransaction(item.id);
                          if (success) {
                            txProvider.fetchTransactions(refresh: true);
                            budgetProv.fetchSummary();
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text("Paid '${item.title}'! Recorded to transactions."),
                                backgroundColor: const Color(0xFF147D64),
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF147D64),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 0,
                        ),
                        icon: const Icon(Icons.check_circle_rounded, size: 16),
                        label: const Text(
                          "Pay Now",
                          style: TextStyle(
                            fontFamily: 'Manrope',
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ScheduledTransactionProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFF0F1621),
      appBar: AppBar(
        title: const Text(
          "Scheduled Payments",
          style: TextStyle(
            fontFamily: 'Manrope',
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF147D64),
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white38,
          labelStyle: const TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.bold),
          tabs: [
            Tab(text: "Upcoming (${provider.pendingScheduledTransactions.length})"),
            Tab(text: "Paid / History (${provider.paidScheduledTransactions.length})"),
          ],
        ),
      ),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF147D64)))
          : TabBarView(
              controller: _tabController,
              children: [
                // Upcoming Tab
                RefreshIndicator(
                  onRefresh: () => provider.fetchScheduledTransactions(),
                  color: const Color(0xFF147D64),
                  child: provider.pendingScheduledTransactions.isEmpty
                      ? SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          child: Container(
                            height: 400,
                            alignment: Alignment.center,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.event_available_rounded, size: 64, color: Colors.white.withOpacity(0.2)),
                                const SizedBox(height: 16),
                                Text(
                                  "No upcoming scheduled payments",
                                  style: TextStyle(
                                    fontFamily: 'Manrope',
                                    fontSize: 15,
                                    color: Colors.white.withOpacity(0.5),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  "Schedule bills or recurring payments to stay on track",
                                  style: TextStyle(
                                    fontFamily: 'Manrope',
                                    fontSize: 12,
                                    color: Colors.white.withOpacity(0.3),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(20.0),
                          itemCount: provider.pendingScheduledTransactions.length,
                          itemBuilder: (context, index) {
                            return _buildScheduledCard(
                              provider.pendingScheduledTransactions[index],
                              provider,
                            );
                          },
                        ),
                ),
                // Paid History Tab
                RefreshIndicator(
                  onRefresh: () => provider.fetchScheduledTransactions(),
                  color: const Color(0xFF147D64),
                  child: provider.paidScheduledTransactions.isEmpty
                      ? SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          child: Container(
                            height: 400,
                            alignment: Alignment.center,
                            child: Text(
                              "No completed scheduled payments yet",
                              style: TextStyle(
                                fontFamily: 'Manrope',
                                fontSize: 14,
                                color: Colors.white.withOpacity(0.4),
                              ),
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(20.0),
                          itemCount: provider.paidScheduledTransactions.length,
                          itemBuilder: (context, index) {
                            return _buildScheduledCard(
                              provider.paidScheduledTransactions[index],
                              provider,
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddScheduledSheet(context),
        backgroundColor: const Color(0xFF147D64),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded, size: 20),
        label: const Text(
          "Schedule Payment",
          style: TextStyle(
            fontFamily: 'Manrope',
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

class AddScheduledTransactionSheet extends StatefulWidget {
  const AddScheduledTransactionSheet({super.key});

  @override
  State<AddScheduledTransactionSheet> createState() => _AddScheduledTransactionSheetState();
}

class _AddScheduledTransactionSheetState extends State<AddScheduledTransactionSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  int? _selectedCategoryId;
  DateTime _dueDate = DateTime.now().add(const Duration(days: 3));
  String _paymentMethod = 'CASH';
  String _recurringFrequency = 'MONTHLY';
  int _reminderDaysBefore = 3;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _selectedCategoryId == null) return;

    setState(() => _isSubmitting = true);

    final provider = Provider.of<ScheduledTransactionProvider>(context, listen: false);
    final success = await provider.createScheduledTransaction(
      categoryId: _selectedCategoryId!,
      title: _titleController.text.trim(),
      amount: double.parse(_amountController.text.trim()),
      dueDate: _dueDate,
      paymentMethod: _paymentMethod,
      note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
      recurringFrequency: _recurringFrequency,
      reminderDaysBefore: _reminderDaysBefore,
    );

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (success) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Scheduled payment added! Smart reminder active."),
            backgroundColor: Color(0xFF147D64),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = Provider.of<TransactionProvider>(context).categories;

    // Ensure _selectedCategoryId is valid or safe
    if (_selectedCategoryId == null && categories.isNotEmpty) {
      _selectedCategoryId = categories.first.id;
    } else if (_selectedCategoryId != null && !categories.any((c) => c.id == _selectedCategoryId)) {
      _selectedCategoryId = categories.isNotEmpty ? categories.first.id : null;
    }

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF141C28),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                "Schedule a Payment",
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),

              // Title
              TextFormField(
                controller: _titleController,
                style: const TextStyle(color: Colors.white, fontFamily: 'Manrope'),
                decoration: InputDecoration(
                  labelText: "Payment Title (e.g. Electricity Bill)",
                  labelStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? "Enter payment title" : null,
              ),
              const SizedBox(height: 12),

              // Amount
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(color: Colors.white, fontFamily: 'Manrope'),
                decoration: InputDecoration(
                  labelText: "Amount (LKR)",
                  labelStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return "Enter amount";
                  if (double.tryParse(val.trim()) == null) return "Enter valid number";
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // Category dropdown
              DropdownButtonFormField<int>(
                value: _selectedCategoryId,
                dropdownColor: const Color(0xFF1B2432),
                style: const TextStyle(color: Colors.white, fontFamily: 'Manrope'),
                decoration: InputDecoration(
                  labelText: "Category",
                  labelStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
                items: categories.map((cat) {
                  return DropdownMenuItem<int>(
                    value: cat.id,
                    child: Text(cat.name),
                  );
                }).toList(),
                onChanged: (val) => setState(() => _selectedCategoryId = val),
              ),
              const SizedBox(height: 12),

              // Due Date Picker & Frequency Row
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _dueDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                        );
                        if (picked != null) {
                          setState(() => _dueDate = picked);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Due Date",
                                  style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.5)),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  DateFormat('MMM d, yyyy').format(_dueDate),
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            const Icon(Icons.calendar_month_rounded, color: Color(0xFF147D64)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Frequency dropdown
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _recurringFrequency,
                      dropdownColor: const Color(0xFF1B2432),
                      style: const TextStyle(color: Colors.white, fontFamily: 'Manrope'),
                      decoration: InputDecoration(
                        labelText: "Frequency",
                        labelStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.05),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'ONCE', child: Text('One-time')),
                        DropdownMenuItem(value: 'MONTHLY', child: Text('Monthly')),
                        DropdownMenuItem(value: 'WEEKLY', child: Text('Weekly')),
                        DropdownMenuItem(value: 'YEARLY', child: Text('Yearly')),
                      ],
                      onChanged: (val) => setState(() => _recurringFrequency = val!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Payment Method & Reminder Days Row
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _paymentMethod,
                      dropdownColor: const Color(0xFF1B2432),
                      style: const TextStyle(color: Colors.white, fontFamily: 'Manrope'),
                      decoration: InputDecoration(
                        labelText: "Payment Method",
                        labelStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.05),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'CASH', child: Text('Cash')),
                        DropdownMenuItem(value: 'CARD', child: Text('Card')),
                        DropdownMenuItem(value: 'BANK_TRANSFER', child: Text('Bank Transfer')),
                      ],
                      onChanged: (val) => setState(() => _paymentMethod = val!),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      value: _reminderDaysBefore,
                      dropdownColor: const Color(0xFF1B2432),
                      style: const TextStyle(color: Colors.white, fontFamily: 'Manrope'),
                      decoration: InputDecoration(
                        labelText: "Remind Me",
                        labelStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.05),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                      items: const [
                        DropdownMenuItem(value: 0, child: Text('On Due Date')),
                        DropdownMenuItem(value: 1, child: Text('1 Day Before')),
                        DropdownMenuItem(value: 3, child: Text('3 Days Before')),
                        DropdownMenuItem(value: 7, child: Text('7 Days Before')),
                      ],
                      onChanged: (val) => setState(() => _reminderDaysBefore = val!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Submit Button
              ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF147D64),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isSubmitting
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text(
                        "Set Payment Reminder",
                        style: TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
