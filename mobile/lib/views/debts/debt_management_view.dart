import '../../widgets/segment_toggle.dart';
import '../../theme/app_tokens.dart';
import '../../widgets/status_pill.dart';
import '../../widgets/meter_bar.dart';
import '../../widgets/dashboard_cards.dart';
import '../../theme/app_text.dart';
import 'package:aureli/theme/app_colors.dart';
import '../../widgets/money_text.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/debt_model.dart';
import '../../models/transaction_model.dart';
import '../../providers/debt_provider.dart';
import '../../widgets/glass_card.dart';

class DebtManagementView extends StatefulWidget {
  const DebtManagementView({super.key});

  @override
  State<DebtManagementView> createState() => _DebtManagementViewState();
}

class _DebtManagementViewState extends State<DebtManagementView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<DebtProvider>(context, listen: false);
      provider.fetchSummary();
      provider.fetchDebts();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showAddDebtSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const AddDebtSheet(),
    );
  }

  void _showRepaymentSheet(BuildContext context, DebtRecordModel debt) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => RecordRepaymentSheet(debt: debt),
    );
  }

  void _showDebtDetailsSheet(BuildContext context, DebtRecordModel debt) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DebtDetailsSheet(debt: debt),
    );
  }

  void _confirmDeleteDebt(BuildContext context, DebtRecordModel debt) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: context.cardLightBg,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text("Delete Record?",
              style: TextStyle(
                  color: context.textPrimary,
                  fontFamily: 'Manrope',
                  fontWeight: FontWeight.bold)),
          content: Text(
            "Are you sure you want to delete the loan/debt record with '${debt.counterpartyName}'? All associated repayment history will also be removed.",
            style: AppText.bodySmall.copyWith(color: context.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text("Cancel"),
            ),
            TextButton(
              onPressed: () async {
                final nav = Navigator.of(ctx);
                final messenger = ScaffoldMessenger.of(context);
                final tokens = context.tokens;
                nav.pop();
                final debtProv =
                    Provider.of<DebtProvider>(context, listen: false);
                final success = await debtProv.deleteDebt(debt.id);
                if (success) {
                  messenger.showSnackBar(
                    SnackBar(
                        content: Text("Record deleted"),
                        backgroundColor: tokens.brand),
                  );
                } else {
                  messenger.showSnackBar(
                    SnackBar(
                        content: Text(
                            debtProv.errorMessage ?? "Failed to delete record"),
                        backgroundColor: tokens.coral),
                  );
                }
              },
              child: Text("Delete", style: TextStyle(color: context.tokens.coral)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final debtProv = Provider.of<DebtProvider>(context);
    final summary = debtProv.summary;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: context.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Loans & debts',
              style: AppText.title1.copyWith(fontSize: 18, color: context.textPrimary),
            ),
            Text(
              'Kept separate from your monthly cash flow',
              style: AppText.caption.copyWith(color: context.tokens.inkMuted),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: context.iconSecondary),
            onPressed: () {
              debtProv.fetchSummary();
              debtProv.fetchDebts();
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: AmbientBackdrop()),
          RefreshIndicator(
            onRefresh: () async {
              await debtProv.fetchSummary();
              await debtProv.fetchDebts();
            },
            color: context.tokens.emerald,
            child: Column(
              children: [
                SizedBox(height: 8),
                // 1. Net Debt Position Card
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0),
                  child: _buildNetDebtLedgerCard(summary),
                ),
                SizedBox(height: 12),

                // 2. Filter tabs
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16.0),
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: context.tokens.inputFill,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: context.tokens.hairline),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicatorSize: TabBarIndicatorSize.tab,
                    indicator: BoxDecoration(
                      color: context.tokens.brand,
                      borderRadius: BorderRadius.circular(AppRadius.md - 3),
                    ),
                    labelColor: Colors.white,
                    unselectedLabelColor: context.tokens.inkSecondary,
                    labelStyle: AppText.label.copyWith(fontSize: 13),
                    unselectedLabelStyle: AppText.label.copyWith(fontSize: 13),
                    dividerColor: Colors.transparent,
                    splashBorderRadius: BorderRadius.circular(AppRadius.md),
                    tabs: [
                      Tab(height: 36, text: "All (${debtProv.debts.length})"),
                      Tab(height: 36, text: "Lent (${debtProv.lentDebts.length})"),
                      Tab(height: 36, text: "Borrowed (${debtProv.borrowedDebts.length})"),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // 3. Tab Views
                Expanded(
                  child: debtProv.isLoading && debtProv.debts.isEmpty
                      ? Center(
                          child: CircularProgressIndicator(
                              color: context.tokens.emerald))
                      : TabBarView(
                          controller: _tabController,
                          children: [
                            _buildDebtList(context, debtProv.debts),
                            _buildDebtList(context, debtProv.lentDebts),
                            _buildDebtList(context, debtProv.borrowedDebts),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        shape: const StadiumBorder(),
        onPressed: () => _showAddDebtSheet(context),
        icon: const Icon(Icons.add_rounded, size: 22),
        label: const Text('Record loan or debt'),
      ),
    );
  }

  Widget _buildNetDebtLedgerCard(DebtSummaryModel? summary) {
    final t = context.tokens;
    final double netPos = summary?.netDebtPosition ?? 0.0;
    final bool isPositive = netPos >= 0;
    final Color positionColor = isPositive ? t.emerald : t.coral;
    final int overdue = summary?.overdueCount ?? 0;

    return GlassCard(
      padding: const EdgeInsets.all(AppSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CardHeader(
            icon: isPositive
                ? Icons.account_balance_rounded
                : Icons.money_off_csred_rounded,
            color: positionColor,
            title: 'Net position',
            trailing: StatusPill(
              label: isPositive ? 'Net creditor' : 'Net debtor',
              color: positionColor,
            ),
          ),
          const SizedBox(height: AppSpace.md),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Money(
              netPos,
              style: AppText.hero.copyWith(fontSize: 30),
              tone: MoneyTone.bySign,
              showPlus: true,
            ),
          ),
          const SizedBox(height: AppSpace.xs),
          Text(
            'What you are owed, minus what you owe',
            style: AppText.caption.copyWith(color: t.inkMuted),
          ),
          const SizedBox(height: AppSpace.lg),
          Divider(color: t.hairline, height: 1),
          const SizedBox(height: AppSpace.md),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _ledgerStat(
                    label: 'Lent out',
                    amount: summary?.totalLent ?? 0.0,
                    color: t.emerald,
                    footnote:
                        '${summary?.activeLentCount ?? 0} active loan(s)',
                  ),
                ),
                VerticalDivider(color: t.hairline, width: AppSpace.xxl),
                Expanded(
                  child: _ledgerStat(
                    label: 'Borrowed',
                    amount: summary?.totalBorrowed ?? 0.0,
                    color: t.coral,
                    footnote:
                        '${summary?.activeBorrowedCount ?? 0} active debt(s)',
                  ),
                ),
              ],
            ),
          ),
          if (overdue > 0) ...[
            const SizedBox(height: AppSpace.md),
            InlineNotice(
              message: '$overdue payment(s) overdue',
              color: t.amber,
              icon: Icons.warning_amber_rounded,
            ),
          ],
        ],
      ),
    );
  }

  Widget _ledgerStat({
    required String label,
    required double amount,
    required Color color,
    required String footnote,
  }) {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppText.label.copyWith(color: t.inkSecondary)),
        const SizedBox(height: AppSpace.xs),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Money(amount, color: color),
        ),
        const SizedBox(height: 2),
        Text(footnote, style: AppText.caption.copyWith(color: t.inkMuted)),
      ],
    );
  }

  Widget _buildDebtList(BuildContext context, List<DebtRecordModel> list) {
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.receipt_long_rounded,
                size: 52, color: context.tokens.hairline),
            SizedBox(height: 12),
            Text(
              "No debt records found",
              style: AppText.body.copyWith(fontSize: 15, color: context.tokens.inkMuted),
            ),
            SizedBox(height: 6),
            Text(
              "Tap 'Record loan or debt' to log money you borrowed or lent",
              style: AppText.label.copyWith(color: context.tokens.inkMuted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 100),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final debt = list[index];
        return _buildDebtCard(context, debt);
      },
    );
  }

  Widget _buildDebtCard(BuildContext context, DebtRecordModel debt) {
    final t = context.tokens;
    final bool isLent = debt.type == DebtType.LENT;
    final bool isSettled = debt.status == DebtStatus.SETTLED;
    final bool isOverdue = debt.status == DebtStatus.OVERDUE;

    // Lent money is an asset (green); borrowed money is a liability (coral).
    final Color sideColor = isLent ? t.emerald : t.coral;
    final Color barColor = isLent ? t.emerald : t.cobalt;

    Color badgeColor;
    String badgeText;
    if (isSettled) {
      badgeColor = t.emerald;
      badgeText = 'Settled';
    } else if (isOverdue) {
      badgeColor = t.coral;
      badgeText = 'Overdue';
    } else {
      badgeColor = isLent ? t.emerald : t.cobalt;
      badgeText = isLent ? 'Receivable' : 'Liability';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.md),
      child: InkWell(
        onTap: () => _showDebtDetailsSheet(context, debt),
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: GlassCard(
          padding: const EdgeInsets.all(AppSpace.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Who, and what state the record is in.
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: t.soft(sideColor,
                          brightness: Theme.of(context).brightness),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Icon(
                      isLent
                          ? Icons.arrow_outward_rounded
                          : Icons.arrow_downward_rounded,
                      color: sideColor,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: AppSpace.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          debt.counterpartyName,
                          style: AppText.title2.copyWith(color: t.ink),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          (debt.counterpartyContact != null &&
                                  debt.counterpartyContact!.isNotEmpty)
                              ? debt.counterpartyContact!
                              : (isLent ? 'Lent to' : 'Borrowed from'),
                          style: AppText.caption.copyWith(color: t.inkMuted),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpace.sm),
                  StatusPill(label: badgeText, color: badgeColor),
                  IconButton(
                    icon: Icon(Icons.delete_outline_rounded,
                        color: t.inkFaint, size: 18),
                    onPressed: () => _confirmDeleteDebt(context, debt),
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Delete record',
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.lg),

              // Remaining on the left, total on the right.
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Remaining',
                            style: AppText.caption.copyWith(color: t.inkMuted)),
                        const SizedBox(height: 2),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Money(
                            debt.remainingAmount,
                            style: AppText.title1,
                            color: isSettled ? t.inkMuted : sideColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpace.md),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('Total due',
                          style: AppText.caption.copyWith(color: t.inkMuted)),
                      const SizedBox(height: 2),
                      Money(
                        debt.totalAmountDue,
                        style: AppText.figure.copyWith(fontSize: 14),
                        color: t.inkSecondary,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.md),
              MeterBar(
                ratio: debt.progressPercentage,
                color: isSettled ? t.emerald : barColor,
              ),
              const SizedBox(height: AppSpace.sm),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                spacing: AppSpace.md,
                runSpacing: 2,
                children: [
                  Text(
                    'Repaid ${formatAmount(debt.amountRepaid)} (${(debt.progressPercentage * 100).toInt()}%)',
                    style: AppText.caption.copyWith(color: t.inkMuted),
                  ),
                  if (debt.dueDate != null)
                    Text(
                      'Due ${DateFormat('MMM d, yyyy').format(debt.dueDate!)}',
                      style: AppText.caption.copyWith(
                        fontWeight:
                            isOverdue ? FontWeight.w700 : FontWeight.w500,
                        color: isOverdue ? t.coral : t.inkMuted,
                      ),
                    ),
                ],
              ),

              if (!isSettled) ...[
                const SizedBox(height: AppSpace.lg),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showRepaymentSheet(context, debt),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: barColor,
                          minimumSize: const Size(0, 44),
                          side: BorderSide(color: t.hairline),
                        ),
                        icon: Icon(
                          isLent
                              ? Icons.call_received_rounded
                              : Icons.payment_rounded,
                          size: 16,
                        ),
                        label: Text(isLent ? 'Collect repayment' : 'Pay instalment'),
                      ),
                    ),
                    const SizedBox(width: AppSpace.sm),
                    IconButton(
                      icon: Icon(Icons.history_rounded,
                          color: t.inkMuted, size: 20),
                      onPressed: () => _showDebtDetailsSheet(context, debt),
                      tooltip: 'View history',
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

}

// ==============================================================================
// ADD DEBT SHEET
// ==============================================================================
class AddDebtSheet extends StatefulWidget {
  const AddDebtSheet({super.key});

  @override
  State<AddDebtSheet> createState() => _AddDebtSheetState();
}

class _AddDebtSheetState extends State<AddDebtSheet> {
  DebtType _type = DebtType.BORROWED;
  final _nameController = TextEditingController();
  final _contactController = TextEditingController();
  final _amountController = TextEditingController();
  final _interestController = TextEditingController();
  final _noteController = TextEditingController();

  DateTime _startDate = DateTime.now();
  DateTime? _dueDate;
  int _reminderDays = 3;
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _contactController.dispose();
    _amountController.dispose();
    _interestController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isLent = _type == DebtType.LENT;
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
        left: 20,
        right: 20,
        top: 20,
        bottom: effectiveBottomPadding,
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
                decoration: BoxDecoration(
                    color: context.divider,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Record loan or debt',
              style: AppText.title1.copyWith(fontSize: 18, color: context.textPrimary),
            ),
            SizedBox(height: 4),
            Text(
              "Kept separate from your monthly expenses, income and savings",
              style: AppText.label.copyWith(color: context.tokens.inkMuted),
            ),
            SizedBox(height: 16),

            // Borrowed vs lent
            SegmentToggle<DebtType>(
              selected: _type,
              segments: [
                Segment(
                    value: DebtType.BORROWED,
                    label: 'I borrowed',
                    color: context.tokens.coral),
                Segment(
                    value: DebtType.LENT,
                    label: 'I lent',
                    color: context.tokens.emerald),
              ],
              onChanged: (v) => setState(() => _type = v),
            ),
            const SizedBox(height: 16),

            // Counterparty Name
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: isLent
                    ? "Borrower name"
                    : "Lender or bank name",
              ),
            ),
            SizedBox(height: 12),

            // Counterparty Contact (Optional)
            TextField(
              controller: _contactController,
              decoration: InputDecoration(
                labelText: isLent
                    ? "Contact Phone / Email (Optional)"
                    : "Account / Reference # (Optional)",
              ),
            ),
            SizedBox(height: 12),

            // Principal Amount & Optional Interest Rate
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: "Principal Amount (LKR)",
                    ),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _interestController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: "Interest % (Opt.)",
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),

            // Date Pickers: Start Date & Due Date
            Row(
              children: [
                Expanded(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text("Start Date",
                        style: AppText.caption.copyWith(color: context.tokens.inkMuted)),
                    subtitle: Text(DateFormat('MMM d, yyyy').format(_startDate),
                        style: TextStyle(
                            color: context.textPrimary,
                            fontWeight: FontWeight.bold)),
                    trailing: Icon(Icons.calendar_today_rounded,
                        color: context.textMuted, size: 18),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _startDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2035),
                      );
                      if (picked != null) setState(() => _startDate = picked);
                    },
                  ),
                ),
                Expanded(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text("Due Date (Optional)",
                        style: AppText.caption.copyWith(color: context.tokens.inkMuted)),
                    subtitle: Text(
                      _dueDate != null
                          ? DateFormat('MMM d, yyyy').format(_dueDate!)
                          : "None",
                      style: TextStyle(
                          color:
                              _dueDate != null ? context.tokens.ink : context.tokens.inkMuted,
                          fontWeight: FontWeight.bold),
                    ),
                    trailing: Icon(Icons.event_available_rounded,
                        color: context.textMuted, size: 18),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _dueDate ??
                            DateTime.now().add(const Duration(days: 30)),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2035),
                      );
                      if (picked != null) setState(() => _dueDate = picked);
                    },
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),

            // Reminder Days
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Reminder Alert",
                    style: AppText.bodySmall.copyWith(color: context.textSecondary)),
                DropdownButton<int>(
                  value: _reminderDays,
                  dropdownColor: context.tokens.panel,
                  style: TextStyle(
                      color: context.textPrimary, fontFamily: 'Manrope'),
                  underline: SizedBox(),
                  items: const [
                    DropdownMenuItem(value: 1, child: Text("1 day before")),
                    DropdownMenuItem(value: 3, child: Text("3 days before")),
                    DropdownMenuItem(value: 7, child: Text("7 days before")),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _reminderDays = val);
                  },
                ),
              ],
            ),
            SizedBox(height: 8),

            // Notes
            TextField(
              controller: _noteController,
              decoration: InputDecoration(
                labelText: "Notes (Optional)",
              ),
            ),
            SizedBox(height: 24),

            // Submit Button
            _isSaving
                ? Center(
                    child: CircularProgressIndicator(color: context.tokens.emerald))
                : ElevatedButton(
                    onPressed: () async {
                      final name = _nameController.text.trim();
                      final amount =
                          double.tryParse(_amountController.text.trim());
                      if (name.isEmpty || amount == null || amount <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text(
                                  "Please enter a valid counterparty name and amount"),
                              backgroundColor: context.tokens.coral),
                        );
                        return;
                      }

                      final interest =
                          double.tryParse(_interestController.text.trim());

                      setState(() => _isSaving = true);
                      final debtProv =
                          Provider.of<DebtProvider>(context, listen: false);
                      final success = await debtProv.createDebt(
                        type: _type,
                        counterpartyName: name,
                        counterpartyContact:
                            _contactController.text.trim().isNotEmpty
                                ? _contactController.text.trim()
                                : null,
                        principalAmount: amount,
                        interestRate: interest,
                        startDate: _startDate,
                        dueDate: _dueDate,
                        reminderDaysBefore: _reminderDays,
                        note: _noteController.text.trim().isNotEmpty
                            ? _noteController.text.trim()
                            : null,
                      );

                      if (context.mounted) {
                        setState(() => _isSaving = false);
                        if (success) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text("Debt/Loan record created!"),
                                backgroundColor: context.tokens.brand),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text(debtProv.errorMessage ??
                                    "Failed to create record"),
                                backgroundColor: context.tokens.coral),
                          );
                        }
                      }
                    },
                    child: Text("Save Record",
                        style: AppText.title2.copyWith(color: context.textPrimary)),
                  ),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

// ==============================================================================
// RECORD REPAYMENT SHEET
// ==============================================================================
class RecordRepaymentSheet extends StatefulWidget {
  final DebtRecordModel debt;
  const RecordRepaymentSheet({super.key, required this.debt});

  @override
  State<RecordRepaymentSheet> createState() => _RecordRepaymentSheetState();
}

class _RecordRepaymentSheetState extends State<RecordRepaymentSheet> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  DateTime _repaymentDate = DateTime.now();
  PaymentMethod _paymentMethod = PaymentMethod.CASH;
  bool _isSaving = false;

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isLent = widget.debt.type == DebtType.LENT;
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
        left: 20,
        right: 20,
        top: 20,
        bottom: effectiveBottomPadding,
      ),
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
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          SizedBox(height: 16),
          Text(
            isLent ? "Collect Repayment" : "Pay Installment",
            style: AppText.title1.copyWith(fontSize: 18, color: context.textPrimary),
          ),
          SizedBox(height: 4),
          Text(
            "${isLent ? 'From' : 'To'}: ${widget.debt.counterpartyName} · Outstanding: LKR ${formatAmount(widget.debt.remainingAmount)}",
            style: AppText.label.copyWith(color: context.tokens.emerald),
          ),
          SizedBox(height: 16),

          // Amount + Quick Full Pay Chip
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: "Repayment Amount (LKR)",
                  ),
                ),
              ),
              SizedBox(width: 8),
              ActionChip(
                label: Text("Full Balance",
                    style:
                        AppText.caption.copyWith(fontWeight: FontWeight.bold)),
                backgroundColor:
                    context.tokens.emerald.withValues(alpha: 0.18),
                onPressed: () {
                  _amountController.text =
                      widget.debt.remainingAmount.toStringAsFixed(0);
                },
              ),
            ],
          ),
          SizedBox(height: 14),

          // Payment Method Selector
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Payment Method",
                  style: AppText.bodySmall.copyWith(color: context.textSecondary)),
              DropdownButton<PaymentMethod>(
                value: _paymentMethod,
                dropdownColor: context.tokens.panel,
                style: TextStyle(
                    color: context.textPrimary, fontFamily: 'Manrope'),
                underline: SizedBox(),
                items: PaymentMethod.values.map((m) {
                  final label =
                      m == PaymentMethod.CASH ? 'Cash' : 'Bank transfer';
                  return DropdownMenuItem(value: m, child: Text(label));
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _paymentMethod = val);
                },
              ),
            ],
          ),
          SizedBox(height: 8),

          // Repayment Date
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text("Repayment Date",
                style: AppText.caption.copyWith(color: context.tokens.inkMuted)),
            subtitle: Text(DateFormat('MMM d, yyyy').format(_repaymentDate),
                style: TextStyle(
                    color: context.textPrimary, fontWeight: FontWeight.bold)),
            trailing: Icon(Icons.calendar_today_rounded,
                color: context.textMuted, size: 18),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _repaymentDate,
                firstDate: DateTime(2020),
                lastDate: DateTime(2035),
              );
              if (picked != null) setState(() => _repaymentDate = picked);
            },
          ),
          SizedBox(height: 8),

          // Note
          TextField(
            controller: _noteController,
            decoration: InputDecoration(
              labelText: "Note (Optional)",
            ),
          ),
          SizedBox(height: 24),

          // Submit
          _isSaving
              ? Center(
                  child: CircularProgressIndicator(color: context.tokens.emerald))
              : ElevatedButton(
                  onPressed: () async {
                    final amount =
                        double.tryParse(_amountController.text.trim());
                    if (amount == null || amount <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content:
                                Text("Please enter a valid repayment amount"),
                            backgroundColor: context.tokens.coral),
                      );
                      return;
                    }
                    if (amount > widget.debt.remainingAmount) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                              "Amount exceeds outstanding balance of LKR ${formatAmount(widget.debt.remainingAmount)}"),
                          backgroundColor: context.tokens.coral,
                        ),
                      );
                      return;
                    }

                    setState(() => _isSaving = true);
                    final debtProv =
                        Provider.of<DebtProvider>(context, listen: false);
                    final success = await debtProv.recordRepayment(
                      debtId: widget.debt.id,
                      amount: amount,
                      repaymentDate: _repaymentDate,
                      paymentMethod: _paymentMethod,
                      note: _noteController.text.trim().isNotEmpty
                          ? _noteController.text.trim()
                          : null,
                    );

                    if (context.mounted) {
                      setState(() => _isSaving = false);
                      if (success) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text("Repayment logged successfully!"),
                              backgroundColor: context.tokens.brand),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text(debtProv.errorMessage ??
                                  "Failed to log repayment"),
                              backgroundColor: context.tokens.coral),
                        );
                      }
                    }
                  },
                  child: Text("Confirm Repayment",
                      style: AppText.title2.copyWith(color: context.textPrimary)),
                ),
          SizedBox(height: 20),
        ],
      ),
    );
  }
}

// ==============================================================================
// DEBT DETAILS & REPAYMENT HISTORY SHEET
// ==============================================================================
class DebtDetailsSheet extends StatelessWidget {
  final DebtRecordModel debt;
  const DebtDetailsSheet({super.key, required this.debt});

  @override
  Widget build(BuildContext context) {
    final bool isLent = debt.type == DebtType.LENT;
    final mediaQuery = MediaQuery.of(context);
    final systemBottomPadding = mediaQuery.viewPadding.bottom > 0
        ? mediaQuery.viewPadding.bottom
        : mediaQuery.padding.bottom;
    final effectiveBottomPadding =
        (systemBottomPadding > 0 ? systemBottomPadding : 16.0) + 20.0;

    return Container(
      decoration: BoxDecoration(
        color: context.tokens.panel,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: effectiveBottomPadding,
      ),
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
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                debt.counterpartyName,
                style: AppText.title1.copyWith(color: context.textPrimary),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (isLent
                          ? context.tokens.emerald
                          : context.tokens.cobalt)
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isLent ? "Lent (Receivable)" : "Borrowed (Debt)",
                  style: AppText.caption.copyWith(fontWeight: FontWeight.bold, color: isLent
                        ? context.tokens.emerald
                        : context.tokens.cobalt),
                ),
              ),
            ],
          ),
          if (debt.note != null && debt.note!.isNotEmpty) ...[
            SizedBox(height: 6),
            Text(debt.note!,
                style: AppText.label.copyWith(color: context.tokens.inkMuted)),
          ],
          SizedBox(height: 16),

          // Key metrics card
          Container(
            padding: EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: context.tokens.inputFill,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.divider),
            ),
            child: Column(
              children: [
                _buildMetricRow(context, "Principal Amount",
                    "LKR ${formatAmount(debt.principalAmount)}"),
                if (debt.interestRate != null && debt.interestRate! > 0)
                  _buildMetricRow(context, "Interest Rate", "${debt.interestRate}%"),
                _buildMetricRow(context, "Total Amount Due",
                    "LKR ${formatAmount(debt.totalAmountDue)}"),
                _buildMetricRow(context, "Total Repaid",
                    "LKR ${formatAmount(debt.amountRepaid)}"),
                _buildMetricRow(context, "Remaining Balance",
                    "LKR ${formatAmount(debt.remainingAmount)}",
                    isHighlight: true),
                _buildMetricRow(context, "Start Date",
                    DateFormat('MMM d, yyyy').format(debt.startDate)),
                if (debt.dueDate != null)
                  _buildMetricRow(context, "Due Date",
                      DateFormat('MMM d, yyyy').format(debt.dueDate!)),
              ],
            ),
          ),
          SizedBox(height: 18),

          // Repayment History List
          Text(
            "Repayment History (${debt.repayments.length})",
            style: AppText.title2.copyWith(fontSize: 14, color: context.textSecondary),
          ),
          SizedBox(height: 8),
          if (debt.repayments.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 12.0),
              child: Center(
                child: Text(
                  "No repayments recorded yet.",
                  style: AppText.label.copyWith(color: context.tokens.inkMuted),
                ),
              ),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: debt.repayments.length,
                itemBuilder: (context, index) {
                  final rep = debt.repayments[index];
                  final methodLabel = rep.paymentMethod == PaymentMethod.CASH
                      ? 'Cash'
                      : 'Bank transfer';
                  return Container(
                    margin: EdgeInsets.only(bottom: 6),
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: context.tokens.inputFill,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              DateFormat('MMM d, yyyy')
                                  .format(rep.repaymentDate),
                              style: AppText.label.copyWith(fontWeight: FontWeight.bold, color: context.textSecondary),
                            ),
                            Text(
                              "Via $methodLabel${rep.note != null ? ' · ${rep.note}' : ''}",
                              style: AppText.caption.copyWith(color: context.tokens.inkMuted),
                            ),
                          ],
                        ),
                        Text(
                          "+ LKR ${formatAmount(rep.amount)}",
                          style: AppText.title2.copyWith(fontSize: 13, color: context.tokens.emerald),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: context.divider,
              padding: EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child:
                Text("Close", style: TextStyle(color: context.textSecondary)),
          ),
          SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildMetricRow(BuildContext context, String label, String value,
      {bool isHighlight = false}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: AppText.label.copyWith(color: context.tokens.inkMuted)),
          Text(
            value,
            style: AppText.label.copyWith(fontWeight: isHighlight ? FontWeight.bold : FontWeight.w600, color: isHighlight ? context.tokens.emerald : context.tokens.ink),
          ),
        ],
      ),
    );
  }
}
