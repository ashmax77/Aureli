import '../../theme/app_text.dart';
import 'package:aureli/theme/app_colors.dart';
import '../../widgets/money_text.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/scheduled_transaction_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/budget_provider.dart';
import '../../models/scheduled_transaction_model.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/svg_icons.dart';

class ScheduledTransactionsScreen extends StatefulWidget {
  const ScheduledTransactionsScreen({super.key});

  @override
  State<ScheduledTransactionsScreen> createState() =>
      _ScheduledTransactionsScreenState();
}

class _ScheduledTransactionsScreenState
    extends State<ScheduledTransactionsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ScheduledTransactionProvider>(context, listen: false)
          .fetchScheduledTransactions();
      Provider.of<TransactionProvider>(context, listen: false)
          .fetchCategories();
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

  Widget _buildStatusBadge(ScheduledTransactionModel item) {
    final days = item.daysUntilDue;
    Color color;
    String text;
    IconData icon;

    if (days < 0) {
      color = context.tokens.coral; // Coral Red
      text = "Overdue (${days.abs()}d)";
      icon = Icons.warning_amber_rounded;
    } else if (days == 0) {
      color = context.tokens.emerald; // Emerald Green
      text = "Due Today";
      icon = Icons.error_outline_rounded;
    } else if (days <= 3) {
      color = context.tokens.amber; // Amber
      text = "Due in $days d";
      icon = Icons.access_time_rounded;
    } else {
      color = context.tokens.cobalt; // Indigo
      text = "Due in $days d";
      icon = Icons.calendar_today_rounded;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          SizedBox(width: 4),
          Text(
            text,
            style: AppText.caption.copyWith(fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduledCard(
      ScheduledTransactionModel item, ScheduledTransactionProvider provider) {
    final formattedDate = DateFormat('MMM d, yyyy').format(item.dueDate);
    final isPending = item.status == ScheduledStatus.PENDING;

    return Padding(
      padding: EdgeInsets.only(bottom: 12.0),
      child: GlassCard(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Builder(
                  builder: (context) {
                    final categories =
                        Provider.of<TransactionProvider>(context, listen: false)
                            .categories;
                    final matches = categories.where((c) =>
                        c.id == item.categoryId ||
                        c.name.toLowerCase() ==
                            item.categoryName.toLowerCase());
                    final catModel = matches.isNotEmpty ? matches.first : null;
                    final color = catModel?.color ?? context.tokens.emerald;

                    return Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: AppSvgIcons.getCategorySvg(
                        catModel?.iconKey,
                        item.categoryName,
                        color: color,
                        size: 22,
                      ),
                    );
                  },
                ),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: AppText.body.copyWith(fontSize: 15, fontWeight: FontWeight.bold, color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white
                              : context.tokens.ink),
                      ),
                      SizedBox(height: 3),
                      Row(
                        children: [
                          Text(
                            item.categoryName,
                            style: AppText.label.copyWith(color: Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? context.tokens.inkMuted
                                  : context.tokens.inkMuted),
                          ),
                          if (item.recurringFrequency !=
                              ScheduledFrequency.ONCE) ...[
                            Text(
                              " • ${item.recurringFrequency.name.toLowerCase()}",
                              style: AppText.label.copyWith(color: Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? context.tokens.inkSecondary
                                    : context.tokens.inkSecondary),
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
                      "LKR ${formatAmount(item.amount)}",
                      style: AppText.body.copyWith(fontSize: 15, fontWeight: FontWeight.bold, color: context.textPrimary),
                    ),
                    SizedBox(height: 4),
                    if (isPending) _buildStatusBadge(item),
                  ],
                ),
              ],
            ),
            SizedBox(height: 12),
            Divider(color: context.divider, height: 1),
            SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.event_outlined,
                        size: 14, color: context.tokens.inkMuted),
                    SizedBox(width: 4),
                    Text(
                      "Due $formattedDate",
                      style: AppText.label.copyWith(color: context.tokens.inkMuted),
                    ),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.delete_outline_rounded,
                          size: 20, color: context.textLight),
                      visualDensity: VisualDensity.compact,
                      onPressed: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            backgroundColor: const Color(0xFF1B2432),
                            title: Text("Delete Scheduled Payment?",
                                style: TextStyle(color: context.textPrimary)),
                            content: Text(
                                "Are you sure you want to remove '${item.title}'?",
                                style: TextStyle(color: context.textSecondary)),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: Text("Cancel",
                                    style: TextStyle(color: context.textMuted)),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: Text("Delete",
                                    style: TextStyle(color: context.tokens.coral)),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          final deleted =
                              await provider.deleteScheduledTransaction(item.id);
                          if (!deleted) {
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(provider.errorMessage ??
                                    "Failed to delete scheduled payment"),
                                backgroundColor: context.tokens.coral,
                              ),
                            );
                          }
                        }
                      },
                    ),
                    if (isPending) ...[
                      SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () async {
                          final txProvider = Provider.of<TransactionProvider>(
                              context,
                              listen: false);
                          final budgetProv = Provider.of<BudgetProvider>(
                              context,
                              listen: false);
                          final messenger = ScaffoldMessenger.of(context);

                          final success =
                              await provider.payScheduledTransaction(item.id);
                          if (success) {
                            txProvider.fetchTransactions(refresh: true);
                            budgetProv.fetchSummary();
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(
                                    "Paid '${item.title}'! Recorded to transactions."),
                                backgroundColor: context.tokens.brand,
                              ),
                            );
                          } else {
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(provider.errorMessage ??
                                    "Failed to mark as paid"),
                                backgroundColor: context.tokens.coral,
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: context.tokens.brand,
                          foregroundColor: context.textPrimary,
                          padding:
                              EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          elevation: 0,
                        ),
                        icon: Icon(Icons.check_circle_rounded, size: 16),
                        label: Text(
                          "Pay Now",
                          style: AppText.label.copyWith(fontWeight: FontWeight.bold),
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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          "Scheduled Payments",
          style: TextStyle(
            fontFamily: 'Manrope',
            fontWeight: FontWeight.bold,
            color: context.textPrimary,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: context.tokens.emerald,
          indicatorWeight: 3,
          labelColor: context.textPrimary,
          unselectedLabelColor: context.textLight,
          labelStyle:
              TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.bold),
          tabs: [
            Tab(
                text:
                    "Upcoming (${provider.pendingScheduledTransactions.length})"),
            Tab(
                text:
                    "Paid / History (${provider.paidScheduledTransactions.length})"),
          ],
        ),
      ),
      body: provider.isLoading
          ? Center(
              child: CircularProgressIndicator(color: context.tokens.emerald))
          : TabBarView(
              controller: _tabController,
              children: [
                // Upcoming Tab
                RefreshIndicator(
                  onRefresh: () => provider.fetchScheduledTransactions(),
                  color: context.tokens.emerald,
                  child: provider.pendingScheduledTransactions.isEmpty
                      ? SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          child: Container(
                            height: 400,
                            alignment: Alignment.center,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.event_available_rounded,
                                    size: 64,
                                    color: context.tokens.hairline),
                                SizedBox(height: 16),
                                Text(
                                  "No upcoming scheduled payments",
                                  style: AppText.body.copyWith(fontSize: 15, color: context.tokens.inkMuted),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  "Schedule bills or recurring payments to stay on track",
                                  style: AppText.label.copyWith(color: context.tokens.hairline),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: EdgeInsets.all(20.0),
                          itemCount:
                              provider.pendingScheduledTransactions.length,
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
                  color: context.tokens.emerald,
                  child: provider.paidScheduledTransactions.isEmpty
                      ? SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          child: Container(
                            height: 400,
                            alignment: Alignment.center,
                            child: Text(
                              "No completed scheduled payments yet",
                              style: AppText.body.copyWith(color: context.tokens.inkMuted),
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: EdgeInsets.all(20.0),
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
        backgroundColor: context.tokens.brand,
        foregroundColor: context.textPrimary,
        icon: Icon(Icons.add_rounded, size: 20),
        label: Text(
          "Schedule Payment",
          style: AppText.title2.copyWith(fontSize: 14),
        ),
      ),
    );
  }
}

class AddScheduledTransactionSheet extends StatefulWidget {
  const AddScheduledTransactionSheet({super.key});

  @override
  State<AddScheduledTransactionSheet> createState() =>
      _AddScheduledTransactionSheetState();
}

class _AddScheduledTransactionSheetState
    extends State<AddScheduledTransactionSheet> {
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
  DateTime? _lastSubmitTime;

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    // Debounce: prevent rapid duplicate scheduled payment creation
    final now = DateTime.now();
    if (_lastSubmitTime != null &&
        now.difference(_lastSubmitTime!) < const Duration(seconds: 2)) {
      return;
    }
    _lastSubmitTime = now;

    if (!_formKey.currentState!.validate() || _selectedCategoryId == null) {
      return;
    }

    setState(() => _isSubmitting = true);

    final provider =
        Provider.of<ScheduledTransactionProvider>(context, listen: false);
    final success = await provider.createScheduledTransaction(
      categoryId: _selectedCategoryId!,
      title: _titleController.text.trim(),
      amount: double.parse(_amountController.text.trim()),
      dueDate: _dueDate,
      paymentMethod: _paymentMethod,
      note: _noteController.text.trim().isEmpty
          ? null
          : _noteController.text.trim(),
      recurringFrequency: _recurringFrequency,
      reminderDaysBefore: _reminderDaysBefore,
    );

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (success) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Scheduled payment added! Smart reminder active."),
            backgroundColor: context.tokens.brand,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(provider.errorMessage ?? "Failed to schedule payment"),
            backgroundColor: context.tokens.coral,
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
    } else if (_selectedCategoryId != null &&
        !categories.any((c) => c.id == _selectedCategoryId)) {
      _selectedCategoryId = categories.isNotEmpty ? categories.first.id : null;
    }

    final mediaQuery = MediaQuery.of(context);
    final bottomInset = mediaQuery.viewInsets.bottom;
    final systemBottomPadding = mediaQuery.viewPadding.bottom > 0
        ? mediaQuery.viewPadding.bottom
        : mediaQuery.padding.bottom;
    final effectiveBottomPadding = bottomInset +
        (systemBottomPadding > 0 ? systemBottomPadding : 16.0) +
        20.0;

    return Container(
      decoration: BoxDecoration(
        color: context.cardLightBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: effectiveBottomPadding,
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
                    color: context.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              SizedBox(height: 16),
              Text(
                "Schedule a Payment",
                style: AppText.title1.copyWith(color: context.textPrimary),
              ),
              SizedBox(height: 16),

              // Title
              TextFormField(
                controller: _titleController,
                style: TextStyle(
                    color: context.textPrimary, fontFamily: 'Manrope'),
                decoration: InputDecoration(
                  labelText: "Payment Title (e.g. Electricity Bill)",
                  labelStyle:
                      TextStyle(color: context.tokens.inkMuted),
                  filled: true,
                  fillColor: context.tokens.inputFill,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none),
                ),
                validator: (val) => val == null || val.trim().isEmpty
                    ? "Enter payment title"
                    : null,
              ),
              SizedBox(height: 12),

              // Amount
              TextFormField(
                controller: _amountController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                style: TextStyle(
                    color: context.textPrimary, fontFamily: 'Manrope'),
                decoration: InputDecoration(
                  labelText: "Amount (LKR)",
                  labelStyle:
                      TextStyle(color: context.tokens.inkMuted),
                  filled: true,
                  fillColor: context.tokens.inputFill,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return "Enter amount";
                  if (double.tryParse(val.trim()) == null) {
                    return "Enter valid number";
                  }
                  return null;
                },
              ),
              SizedBox(height: 12),

              // Category dropdown
              DropdownButtonFormField<int>(
                value: _selectedCategoryId,
                dropdownColor: const Color(0xFF1B2432),
                style: TextStyle(
                    color: context.textPrimary, fontFamily: 'Manrope'),
                decoration: InputDecoration(
                  labelText: "Category",
                  labelStyle:
                      TextStyle(color: context.tokens.inkMuted),
                  filled: true,
                  fillColor: context.tokens.inputFill,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none),
                ),
                items: categories.map((cat) {
                  return DropdownMenuItem<int>(
                    value: cat.id,
                    child: Text(cat.name),
                  );
                }).toList(),
                onChanged: (val) => setState(() => _selectedCategoryId = val),
              ),
              SizedBox(height: 12),

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
                          lastDate:
                              DateTime.now().add(const Duration(days: 365 * 5)),
                        );
                        if (picked != null) {
                          setState(() => _dueDate = picked);
                        }
                      },
                      child: Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                        decoration: BoxDecoration(
                          color: context.tokens.inputFill,
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
                                  style: AppText.caption.copyWith(color: context.tokens.inkMuted),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  DateFormat('MMM d, yyyy').format(_dueDate),
                                  style: TextStyle(
                                      color: context.textPrimary,
                                      fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            Icon(Icons.calendar_month_rounded,
                                color: context.tokens.emerald),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  // Frequency dropdown
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _recurringFrequency,
                      dropdownColor: const Color(0xFF1B2432),
                      style: TextStyle(
                          color: context.textPrimary, fontFamily: 'Manrope'),
                      decoration: InputDecoration(
                        labelText: "Frequency",
                        labelStyle: TextStyle(
                            color: context.tokens.inkMuted),
                        filled: true,
                        fillColor: context.tokens.inputFill,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none),
                      ),
                      items: const [
                        DropdownMenuItem(
                            value: 'ONCE', child: Text('One-time')),
                        DropdownMenuItem(
                            value: 'MONTHLY', child: Text('Monthly')),
                        DropdownMenuItem(
                            value: 'WEEKLY', child: Text('Weekly')),
                        DropdownMenuItem(
                            value: 'YEARLY', child: Text('Yearly')),
                      ],
                      onChanged: (val) =>
                          setState(() => _recurringFrequency = val!),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),

              // Payment Method & Reminder Days Row
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _paymentMethod,
                      dropdownColor: const Color(0xFF1B2432),
                      style: TextStyle(
                          color: context.textPrimary, fontFamily: 'Manrope'),
                      decoration: InputDecoration(
                        labelText: "Payment Method",
                        labelStyle: TextStyle(
                            color: context.tokens.inkMuted),
                        filled: true,
                        fillColor: context.tokens.inputFill,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'CASH', child: Text('Cash')),
                        DropdownMenuItem(
                            value: 'BANK_TRANSFER',
                            child: Text('Bank Transfer')),
                      ],
                      onChanged: (val) => setState(() => _paymentMethod = val!),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      value: _reminderDaysBefore,
                      dropdownColor: const Color(0xFF1B2432),
                      style: TextStyle(
                          color: context.textPrimary, fontFamily: 'Manrope'),
                      decoration: InputDecoration(
                        labelText: "Remind Me",
                        labelStyle: TextStyle(
                            color: context.tokens.inkMuted),
                        filled: true,
                        fillColor: context.tokens.inputFill,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none),
                      ),
                      items: const [
                        DropdownMenuItem(value: 0, child: Text('On Due Date')),
                        DropdownMenuItem(value: 1, child: Text('1 Day Before')),
                        DropdownMenuItem(
                            value: 3, child: Text('3 Days Before')),
                        DropdownMenuItem(
                            value: 7, child: Text('7 Days Before')),
                      ],
                      onChanged: (val) =>
                          setState(() => _reminderDaysBefore = val!),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),

              // Submit Button
              ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.tokens.brand,
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _isSubmitting
                    ? SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            color: context.textPrimary, strokeWidth: 2))
                    : Text(
                        "Set Payment Reminder",
                        style: AppText.title2.copyWith(color: context.textPrimary),
                      ),
              ),
              SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
