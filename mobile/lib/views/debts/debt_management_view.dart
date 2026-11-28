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
            style: TextStyle(
                color: context.textSecondary,
                fontFamily: 'Manrope',
                fontSize: 13),
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
                nav.pop();
                final debtProv =
                    Provider.of<DebtProvider>(context, listen: false);
                final success = await debtProv.deleteDebt(debt.id);
                if (success) {
                  messenger.showSnackBar(
                    SnackBar(
                        content: Text("Record deleted"),
                        backgroundColor: context.tokens.brand),
                  );
                } else {
                  messenger.showSnackBar(
                    SnackBar(
                        content: Text(
                            debtProv.errorMessage ?? "Failed to delete record"),
                        backgroundColor: context.tokens.coral),
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
              "Loan & Debt Ledger",
              style: TextStyle(
                fontFamily: 'Manrope',
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: context.textPrimary,
              ),
            ),
            Text(
              "Separated from monthly cash flow & savings",
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 11,
                color: context.tokens.inkMuted,
              ),
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
          // Background ambient gradient
          Positioned(
            top: -60,
            right: -60,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.transparent,
                boxShadow: [
                  BoxShadow(
                    color: context.tokens.cobalt.withValues(alpha: 0.2),
                    blurRadius: 100,
                    spreadRadius: 40,
                  ),
                ],
              ),
            ),
          ),
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

                // 2. Segmented Tab Bar
                Container(
                  margin: EdgeInsets.symmetric(horizontal: 16.0),
                  padding: EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: context.tokens.inputFill,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: context.divider),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicatorSize: TabBarIndicatorSize.tab,
                    indicator: BoxDecoration(
                      color: context.tokens.emerald.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color:
                              context.tokens.emerald.withValues(alpha: 0.5)),
                    ),
                    labelColor: context.textPrimary,
                    unselectedLabelColor: context.textMuted,
                    labelStyle: TextStyle(
                        fontFamily: 'Manrope',
                        fontWeight: FontWeight.bold,
                        fontSize: 13),
                    dividerColor: Colors.transparent,
                    tabs: [
                      Tab(text: "All (${debtProv.debts.length})"),
                      Tab(text: "Lent (${debtProv.lentDebts.length})"),
                      Tab(text: "Borrowed (${debtProv.borrowedDebts.length})"),
                    ],
                  ),
                ),
                SizedBox(height: 8),

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
        onPressed: () => _showAddDebtSheet(context),
        backgroundColor: context.tokens.brand,
        foregroundColor: context.textPrimary,
        elevation: 6,
        icon: Icon(Icons.add_rounded, size: 22),
        label: Text(
          "Record Loan / Debt",
          style: TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildNetDebtLedgerCard(DebtSummaryModel? summary) {
    final double netPos = summary?.netDebtPosition ?? 0.0;
    final bool isPositive = netPos >= 0;
    final Color positionColor =
        isPositive ? context.tokens.emerald : context.tokens.coral;

    return GlassCard(
      padding: EdgeInsets.all(18.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: positionColor.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      isPositive
                          ? Icons.account_balance_rounded
                          : Icons.money_off_csred_rounded,
                      color: positionColor,
                      size: 18,
                    ),
                  ),
                  SizedBox(width: 8),
                  Text(
                    "Net debt position",
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: context.textSecondary,
                    ),
                  ),
                ],
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: positionColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: positionColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  isPositive ? "Net Creditor" : "Net Debtor",
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: positionColor,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 6),
          Text(
            "Net = Total Lent (Receivables) − Total Borrowed (Liabilities)",
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 10,
              color: context.tokens.inkMuted,
            ),
          ),
          SizedBox(height: 10),
          Text(
            "${isPositive ? '+' : '-'} LKR ${formatAmount(netPos.abs())}",
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: positionColor,
              letterSpacing: -0.5,
            ),
          ),
          SizedBox(height: 14),
          Divider(color: context.divider, height: 1),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Total lent (assets)",
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: context.tokens.inkMuted,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      "LKR ${formatAmount(summary?.totalLent ?? 0.0)}",
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: context.tokens.emerald,
                      ),
                    ),
                    Text(
                      "${summary?.activeLentCount ?? 0} active loan(s)",
                      style: TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 10,
                          color: context.tokens.inkMuted),
                    ),
                  ],
                ),
              ),
              Container(width: 1, height: 36, color: context.divider),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Total borrowed (debt)",
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: context.tokens.inkMuted,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      "LKR ${formatAmount(summary?.totalBorrowed ?? 0.0)}",
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: context.tokens.coral,
                      ),
                    ),
                    Text(
                      "${summary?.activeBorrowedCount ?? 0} active debt(s)",
                      style: TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 10,
                          color: context.tokens.inkMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if ((summary?.overdueCount ?? 0) > 0) ...[
            SizedBox(height: 10),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: context.tokens.amber.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: context.tokens.amber.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      size: 16, color: context.tokens.amber),
                  SizedBox(width: 6),
                  Text(
                    "${summary!.overdueCount} payment(s) are currently overdue!",
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: context.tokens.amber,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
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
              style: TextStyle(
                  fontFamily: 'Manrope',
                  color: context.tokens.inkMuted,
                  fontSize: 15),
            ),
            SizedBox(height: 6),
            Text(
              "Tap 'Record Loan / Debt' to log a borrowed loan or money lent out",
              style: TextStyle(
                  fontFamily: 'Manrope',
                  color: context.tokens.inkMuted,
                  fontSize: 12),
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
    final bool isLent = debt.type == DebtType.LENT;
    final bool isSettled = debt.status == DebtStatus.SETTLED;
    final bool isOverdue = debt.status == DebtStatus.OVERDUE;

    Color badgeColor;
    String badgeText;
    if (isSettled) {
      badgeColor = context.tokens.emerald;
      badgeText = "Settled";
    } else if (isOverdue) {
      badgeColor = context.tokens.coral;
      badgeText = "Overdue";
    } else {
      badgeColor = isLent ? context.tokens.emerald : context.tokens.cobalt;
      badgeText = isLent ? "Receivable" : "Liability";
    }

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      child: GlassCard(
        padding: EdgeInsets.all(16),
        child: InkWell(
          onTap: () => _showDebtDetailsSheet(context, debt),
          borderRadius: BorderRadius.circular(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Top row: Type indicator + Counterparty + Status Badge
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: (isLent
                            ? context.tokens.emerald
                            : context.tokens.coral)
                        .withValues(alpha: 0.18),
                    child: Icon(
                      isLent
                          ? Icons.arrow_outward_rounded
                          : Icons.arrow_downward_rounded,
                      color: isLent
                          ? context.tokens.emerald
                          : context.tokens.coral,
                      size: 20,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              isLent ? "Lent to: " : "Borrowed from: ",
                              style: TextStyle(
                                fontFamily: 'Manrope',
                                fontSize: 11,
                                color: context.tokens.inkMuted,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                debt.counterpartyName,
                                style: TextStyle(
                                  fontFamily: 'Manrope',
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: context.textPrimary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        if (debt.counterpartyContact != null &&
                            debt.counterpartyContact!.isNotEmpty) ...[
                          SizedBox(height: 2),
                          Text(
                            debt.counterpartyContact!,
                            style: TextStyle(
                              fontFamily: 'Manrope',
                              fontSize: 11,
                              color: context.tokens.inkMuted,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: badgeColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border:
                          Border.all(color: badgeColor.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      badgeText,
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: badgeColor,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.delete_outline_rounded,
                        color: context.tokens.hairline, size: 18),
                    onPressed: () => _confirmDeleteDebt(context, debt),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              SizedBox(height: 12),

              // 2. Financial Amount Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Remaining",
                        style: TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: context.tokens.inkMuted,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        "LKR ${formatAmount(debt.remainingAmount)}",
                        style: TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isSettled
                              ? context.tokens.inkMuted
                              : (isLent
                                  ? context.tokens.emerald
                                  : context.tokens.coral),
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        "Total due",
                        style: TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: context.tokens.inkMuted,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        "LKR ${formatAmount(debt.totalAmountDue)}",
                        style: TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: context.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              SizedBox(height: 10),

              // 3. Progress bar (% repaid)
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: debt.progressPercentage,
                  minHeight: 6,
                  backgroundColor: context.divider,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isSettled
                        ? context.tokens.emerald
                        : (isLent
                            ? context.tokens.emerald
                            : context.tokens.cobalt),
                  ),
                ),
              ),
              SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Repaid: LKR ${formatAmount(debt.amountRepaid)} (${(debt.progressPercentage * 100).toInt()}%)",
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 11,
                      color: context.tokens.inkMuted,
                    ),
                  ),
                  if (debt.dueDate != null)
                    Text(
                      "Due: ${DateFormat('MMM d, yyyy').format(debt.dueDate!)}",
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 11,
                        color: isOverdue ? context.tokens.coral : context.tokens.inkMuted,
                        fontWeight:
                            isOverdue ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                ],
              ),

              // 4. Action buttons
              if (!isSettled) ...[
                SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showRepaymentSheet(context, debt),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: isLent
                              ? context.tokens.emerald
                              : context.tokens.cobalt,
                          side: BorderSide(
                            color: (isLent
                                    ? context.tokens.emerald
                                    : context.tokens.cobalt)
                                .withValues(alpha: 0.4),
                          ),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          padding: EdgeInsets.symmetric(vertical: 8),
                        ),
                        icon: Icon(
                          isLent
                              ? Icons.call_received_rounded
                              : Icons.payment_rounded,
                          size: 16,
                        ),
                        label: Text(
                          isLent ? "Collect / Repay" : "Pay Installment",
                          style: TextStyle(
                              fontFamily: 'Manrope',
                              fontSize: 12,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    IconButton(
                      icon: Icon(Icons.history_rounded,
                          color: context.textMuted, size: 20),
                      onPressed: () => _showDebtDetailsSheet(context, debt),
                      tooltip: "View History",
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
        color: Color(0xFF141C28),
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
              "Record Loan or Debt",
              style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: context.textPrimary),
            ),
            SizedBox(height: 4),
            Text(
              "Completely isolated from your monthly expenses, income & savings",
              style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 12,
                  color: context.tokens.inkMuted),
            ),
            SizedBox(height: 16),

            // Toggle Borrowed vs Lent
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: Center(child: Text("I borrowed (debt)")),
                    selected: _type == DebtType.BORROWED,
                    onSelected: (_) =>
                        setState(() => _type = DebtType.BORROWED),
                    selectedColor:
                        context.tokens.coral.withValues(alpha: 0.3),
                    backgroundColor: context.tokens.inputFill,
                    labelStyle: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _type == DebtType.BORROWED
                          ? context.tokens.coral
                          : context.tokens.inkMuted,
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: ChoiceChip(
                    label: Center(child: Text("I lent (receivable)")),
                    selected: _type == DebtType.LENT,
                    onSelected: (_) => setState(() => _type = DebtType.LENT),
                    selectedColor:
                        context.tokens.emerald.withValues(alpha: 0.3),
                    backgroundColor: context.tokens.inputFill,
                    labelStyle: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _type == DebtType.LENT
                          ? context.tokens.emerald
                          : context.tokens.inkMuted,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),

            // Counterparty Name
            TextField(
              controller: _nameController,
              style: TextStyle(color: context.textPrimary),
              decoration: InputDecoration(
                labelText: isLent
                    ? "Borrower Name (Who received the money?)"
                    : "Lender / Bank Name",
                labelStyle: TextStyle(color: context.tokens.inkMuted),
                enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: context.divider)),
                focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: context.tokens.emerald)),
              ),
            ),
            SizedBox(height: 12),

            // Counterparty Contact (Optional)
            TextField(
              controller: _contactController,
              style: TextStyle(color: context.textPrimary),
              decoration: InputDecoration(
                labelText: isLent
                    ? "Contact Phone / Email (Optional)"
                    : "Account / Reference # (Optional)",
                labelStyle: TextStyle(color: context.tokens.inkMuted),
                enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: context.divider)),
                focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: context.tokens.emerald)),
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
                    style: TextStyle(color: context.textPrimary),
                    decoration: InputDecoration(
                      labelText: "Principal Amount (LKR)",
                      labelStyle: TextStyle(color: context.tokens.inkMuted),
                      enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: context.divider)),
                      focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: context.tokens.emerald)),
                    ),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _interestController,
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: context.textPrimary),
                    decoration: InputDecoration(
                      labelText: "Interest % (Opt.)",
                      labelStyle: TextStyle(color: context.tokens.inkMuted),
                      enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: context.divider)),
                      focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: context.tokens.emerald)),
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
                        style: TextStyle(color: context.tokens.inkMuted, fontSize: 11)),
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
                        style: TextStyle(color: context.tokens.inkMuted, fontSize: 11)),
                    subtitle: Text(
                      _dueDate != null
                          ? DateFormat('MMM d, yyyy').format(_dueDate!)
                          : "None",
                      style: TextStyle(
                          color:
                              _dueDate != null ? Colors.white : context.tokens.inkMuted,
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
                    style: TextStyle(
                        color: context.textSecondary,
                        fontSize: 13,
                        fontFamily: 'Manrope')),
                DropdownButton<int>(
                  value: _reminderDays,
                  dropdownColor: const Color(0xFF141C28),
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
              style: TextStyle(color: context.textPrimary),
              decoration: InputDecoration(
                labelText: "Notes (Optional)",
                labelStyle: TextStyle(color: context.tokens.inkMuted),
                enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: context.divider)),
                focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: context.tokens.emerald)),
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
                    style: ElevatedButton.styleFrom(
                      backgroundColor: context.tokens.brand,
                      padding: EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text("Save Record",
                        style: TextStyle(
                            color: context.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 16)),
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
        color: Color(0xFF141C28),
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
            style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: context.textPrimary),
          ),
          SizedBox(height: 4),
          Text(
            "${isLent ? 'From' : 'To'}: ${widget.debt.counterpartyName} · Outstanding: LKR ${formatAmount(widget.debt.remainingAmount)}",
            style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 12,
                color: context.tokens.emerald,
                fontWeight: FontWeight.w600),
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
                  style: TextStyle(color: context.textPrimary),
                  decoration: InputDecoration(
                    labelText: "Repayment Amount (LKR)",
                    labelStyle: TextStyle(color: context.tokens.inkMuted),
                    enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: context.divider)),
                    focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: context.tokens.emerald)),
                  ),
                ),
              ),
              SizedBox(width: 8),
              ActionChip(
                label: Text("Full Balance",
                    style:
                        TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                backgroundColor:
                    context.tokens.emerald.withValues(alpha: 0.18),
                labelStyle: TextStyle(color: context.tokens.emerald),
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
                  style: TextStyle(
                      color: context.textSecondary,
                      fontSize: 13,
                      fontFamily: 'Manrope')),
              DropdownButton<PaymentMethod>(
                value: _paymentMethod,
                dropdownColor: const Color(0xFF141C28),
                style: TextStyle(
                    color: context.textPrimary, fontFamily: 'Manrope'),
                underline: SizedBox(),
                items: PaymentMethod.values.map((m) {
                  final label =
                      m == PaymentMethod.CASH ? 'Cash' : 'Bank Transfer';
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
                style: TextStyle(color: context.tokens.inkMuted, fontSize: 11)),
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
            style: TextStyle(color: context.textPrimary),
            decoration: InputDecoration(
              labelText: "Note (Optional)",
              labelStyle: TextStyle(color: context.tokens.inkMuted),
              enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: context.divider)),
              focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: context.tokens.emerald)),
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
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.tokens.brand,
                    padding: EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text("Confirm Repayment",
                      style: TextStyle(
                          color: context.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
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
        color: Color(0xFF141C28),
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
                style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: context.textPrimary),
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
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isLent
                        ? context.tokens.emerald
                        : context.tokens.cobalt,
                  ),
                ),
              ),
            ],
          ),
          if (debt.note != null && debt.note!.isNotEmpty) ...[
            SizedBox(height: 6),
            Text(debt.note!,
                style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 12,
                    color: context.tokens.inkMuted)),
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
                _buildMetricRow("Principal Amount",
                    "LKR ${formatAmount(debt.principalAmount)}"),
                if (debt.interestRate != null && debt.interestRate! > 0)
                  _buildMetricRow("Interest Rate", "${debt.interestRate}%"),
                _buildMetricRow("Total Amount Due",
                    "LKR ${formatAmount(debt.totalAmountDue)}"),
                _buildMetricRow("Total Repaid",
                    "LKR ${formatAmount(debt.amountRepaid)}"),
                _buildMetricRow("Remaining Balance",
                    "LKR ${formatAmount(debt.remainingAmount)}",
                    isHighlight: true),
                _buildMetricRow("Start Date",
                    DateFormat('MMM d, yyyy').format(debt.startDate)),
                if (debt.dueDate != null)
                  _buildMetricRow("Due Date",
                      DateFormat('MMM d, yyyy').format(debt.dueDate!)),
              ],
            ),
          ),
          SizedBox(height: 18),

          // Repayment History List
          Text(
            "Repayment History (${debt.repayments.length})",
            style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: context.textSecondary),
          ),
          SizedBox(height: 8),
          if (debt.repayments.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 12.0),
              child: Center(
                child: Text(
                  "No repayments recorded yet.",
                  style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 12,
                      color: context.tokens.inkMuted),
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
                      : 'Bank Transfer';
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
                              style: TextStyle(
                                  fontFamily: 'Manrope',
                                  fontSize: 12,
                                  color: context.textSecondary,
                                  fontWeight: FontWeight.bold),
                            ),
                            Text(
                              "Via $methodLabel${rep.note != null ? ' · ${rep.note}' : ''}",
                              style: TextStyle(
                                  fontFamily: 'Manrope',
                                  fontSize: 10,
                                  color: context.tokens.inkMuted),
                            ),
                          ],
                        ),
                        Text(
                          "+ LKR ${formatAmount(rep.amount)}",
                          style: TextStyle(
                              fontFamily: 'Manrope',
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: context.tokens.emerald),
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

  Widget _buildMetricRow(String label, String value,
      {bool isHighlight = false}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.55))),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 12,
              fontWeight: isHighlight ? FontWeight.bold : FontWeight.w600,
              color: isHighlight ? Color(0xFF2CB8A0) : Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
