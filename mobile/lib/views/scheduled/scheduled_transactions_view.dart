import '../../theme/app_tokens.dart';
import '../../widgets/status_pill.dart';
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
    final t = context.tokens;
    if (days < 0) {
      return StatusPill(
          label: 'Overdue ${days.abs()}d',
          color: t.coral,
          icon: Icons.warning_amber_rounded);
    }
    if (days == 0) {
      return StatusPill(
          label: 'Due today',
          color: t.emerald,
          icon: Icons.error_outline_rounded);
    }
    if (days <= 3) {
      return StatusPill(
          label: 'Due in ${days}d',
          color: t.amber,
          icon: Icons.access_time_rounded);
    }
    return StatusPill(
        label: 'Due in ${days}d',
        color: t.cobalt,
        icon: Icons.calendar_today_rounded);
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
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: context.tokens.soft(color,
                            brightness: Theme.of(context).brightness),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      alignment: Alignment.center,
                      child: AppSvgIcons.getCategorySvg(
                        catModel?.iconKey,
                        item.categoryName,
                        color: color,
                        size: 18,
                      ),
                    );
                  },
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: AppText.title2.copyWith(color: context.tokens.ink),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 3),
                      Text(
                        item.recurringFrequency == ScheduledFrequency.ONCE
                            ? item.categoryName
                            : "${item.categoryName} \u2022 ${item.recurringFrequency.name.toLowerCase()}",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.caption
                            .copyWith(color: context.tokens.inkMuted),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Money(item.amount),
                    SizedBox(height: 4),
                    if (isPending) _buildStatusBadge(item),
                  ],
                ),
              ],
            ),
            SizedBox(height: 12),
            Divider(color: context.divider, height: 1),
            SizedBox(height: 10),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              runSpacing: 4,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
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
                  mainAxisSize: MainAxisSize.min,
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
                            backgroundColor: context.tokens.panel,
                            title: Text("Delete scheduled payment?",
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
                        icon: Icon(Icons.check_circle_rounded, size: 16),
                        label: const Text("Pay now"),
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
        title: const Text('Scheduled payments'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: context.tokens.emerald,
          indicatorWeight: 2,
          dividerColor: context.tokens.hairline,
          labelColor: context.tokens.ink,
          unselectedLabelColor: context.tokens.inkMuted,
          labelStyle: AppText.label.copyWith(fontSize: 13),
          unselectedLabelStyle: AppText.label.copyWith(fontSize: 13),
          tabs: [
            Tab(
                text:
                    "Upcoming (${provider.pendingScheduledTransactions.length})"),
            Tab(
                text:
                    "History (${provider.paidScheduledTransactions.length})"),
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
                                  "No upcoming payments",
                                  style: AppText.body.copyWith(fontSize: 15, color: context.tokens.inkMuted),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  "Schedule bills or recurring payments to stay on track.",
                                  style: AppText.label.copyWith(color: context.tokens.inkMuted),
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
        shape: const StadiumBorder(),
        onPressed: () => _showAddScheduledSheet(context),
        icon: const Icon(Icons.add_rounded, size: 20),
        label: const Text('Schedule payment'),
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
        color: context.tokens.panel,
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
                'Schedule a payment',
                style: AppText.title1.copyWith(color: context.textPrimary),
              ),
              SizedBox(height: 16),

              // Title
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: "Title (e.g. electricity bill)",
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
                decoration: InputDecoration(
                  labelText: "Amount (LKR)",
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
                dropdownColor: context.tokens.panel,
                decoration: InputDecoration(
                  labelText: "Category",
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
                                  "Due date",
                                  style: AppText.caption.copyWith(color: context.tokens.inkMuted),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  DateFormat('MMM d, yyyy').format(_dueDate),
                                  style: AppText.body.copyWith(color: context.tokens.ink, fontWeight: FontWeight.w700),
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
                      dropdownColor: context.tokens.panel,
                      decoration: InputDecoration(
                        labelText: "Frequency",
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
                      dropdownColor: context.tokens.panel,
                      decoration: InputDecoration(
                        labelText: "Payment method",
                      ),
                      items: const [
                        DropdownMenuItem(value: 'CASH', child: Text('Cash')),
                        DropdownMenuItem(
                            value: 'BANK_TRANSFER',
                            child: Text('Bank transfer')),
                      ],
                      onChanged: (val) => setState(() => _paymentMethod = val!),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      value: _reminderDaysBefore,
                      dropdownColor: context.tokens.panel,
                      decoration: InputDecoration(
                        labelText: "Remind me",
                      ),
                      items: const [
                        DropdownMenuItem(value: 0, child: Text('On the due date')),
                        DropdownMenuItem(value: 1, child: Text('1 day before')),
                        DropdownMenuItem(
                            value: 3, child: Text('3 days before')),
                        DropdownMenuItem(
                            value: 7, child: Text('7 days before')),
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
                child: _isSubmitting
                    ? SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                        : const Text('Set payment reminder'),
              ),
              SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
