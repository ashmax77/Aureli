import 'dart:ui';
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

class _DebtManagementViewState extends State<DebtManagementView> with SingleTickerProviderStateMixin {
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
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF141C28),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Delete Record?", style: TextStyle(color: Colors.white, fontFamily: 'Manrope', fontWeight: FontWeight.bold)),
        content: Text(
          "Are you sure you want to delete the loan/debt record with '${debt.counterpartyName}'? All associated repayment history will also be removed.",
          style: const TextStyle(color: Colors.white70, fontFamily: 'Manrope', fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel", style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final provider = Provider.of<DebtProvider>(context, listen: false);
              final success = await provider.deleteDebt(debt.id);
              if (success && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Record deleted successfully"),
                    backgroundColor: Color(0xFF147D64),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFCD5C52)),
            child: const Text("Delete", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final debtProv = Provider.of<DebtProvider>(context);
    final summary = debtProv.summary;

    return Scaffold(
      backgroundColor: const Color(0xFF0F1621),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F1621),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Loan & Debt Ledger",
              style: TextStyle(
                fontFamily: 'Manrope',
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Colors.white,
              ),
            ),
            Text(
              "Separated from monthly cash flow & savings",
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 11,
                color: Colors.white.withOpacity(0.5),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
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
                    color: const Color(0xFF6C8CFF).withOpacity(0.2),
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
            color: const Color(0xFF2CB8A0),
            child: Column(
              children: [
                const SizedBox(height: 8),
                // 1. Net Debt Position Card
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: _buildNetDebtLedgerCard(summary),
                ),
                const SizedBox(height: 12),

                // 2. Segmented Tab Bar
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16.0),
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicatorSize: TabBarIndicatorSize.tab,
                    indicator: BoxDecoration(
                      color: const Color(0xFF147D64).withOpacity(0.35),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF2CB8A0).withOpacity(0.5)),
                    ),
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white54,
                    labelStyle: const TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.bold, fontSize: 13),
                    dividerColor: Colors.transparent,
                    tabs: [
                      Tab(text: "All (${debtProv.debts.length})"),
                      Tab(text: "Lent (${debtProv.lentDebts.length})"),
                      Tab(text: "Borrowed (${debtProv.borrowedDebts.length})"),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // 3. Tab Views
                Expanded(
                  child: debtProv.isLoading && debtProv.debts.isEmpty
                      ? const Center(child: CircularProgressIndicator(color: Color(0xFF2CB8A0)))
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
        backgroundColor: const Color(0xFF147D64),
        foregroundColor: Colors.white,
        elevation: 6,
        icon: const Icon(Icons.add_rounded, size: 22),
        label: const Text(
          "Record Loan / Debt",
          style: TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildNetDebtLedgerCard(DebtSummaryModel? summary) {
    final double netPos = summary?.netDebtPosition ?? 0.0;
    final bool isPositive = netPos >= 0;
    final Color positionColor = isPositive ? const Color(0xFF2CB8A0) : const Color(0xFFCD5C52);

    return GlassCard(
      padding: const EdgeInsets.all(18.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: positionColor.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      isPositive ? Icons.account_balance_rounded : Icons.money_off_csred_rounded,
                      color: positionColor,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    "NET DEBT POSITION",
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.white70,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: positionColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: positionColor.withOpacity(0.3)),
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
          const SizedBox(height: 6),
          Text(
            "Net = Total Lent (Receivables) − Total Borrowed (Liabilities)",
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 10,
              color: Colors.white.withOpacity(0.4),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            "${isPositive ? '+' : '-'} LKR ${NumberFormat('#,##0').format(netPos.abs())}",
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: positionColor,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 14),
          const Divider(color: Colors.white10, height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "TOTAL LENT (ASSETS)",
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withOpacity(0.5),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      "LKR ${NumberFormat('#,##0').format(summary?.totalLent ?? 0.0)}",
                      style: const TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2CB8A0),
                      ),
                    ),
                    Text(
                      "${summary?.activeLentCount ?? 0} active loan(s)",
                      style: TextStyle(fontFamily: 'Manrope', fontSize: 10, color: Colors.white.withOpacity(0.4)),
                    ),
                  ],
                ),
              ),
              Container(width: 1, height: 36, color: Colors.white10),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "TOTAL BORROWED (DEBT)",
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withOpacity(0.5),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      "LKR ${NumberFormat('#,##0').format(summary?.totalBorrowed ?? 0.0)}",
                      style: const TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFCD5C52),
                      ),
                    ),
                    Text(
                      "${summary?.activeBorrowedCount ?? 0} active debt(s)",
                      style: TextStyle(fontFamily: 'Manrope', fontSize: 10, color: Colors.white.withOpacity(0.4)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if ((summary?.overdueCount ?? 0) > 0) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFE89A58).withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE89A58).withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, size: 16, color: Color(0xFFE89A58)),
                  const SizedBox(width: 6),
                  Text(
                    "${summary!.overdueCount} payment(s) are currently overdue!",
                    style: const TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFE89A58),
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
            Icon(Icons.receipt_long_rounded, size: 52, color: Colors.white.withOpacity(0.2)),
            const SizedBox(height: 12),
            Text(
              "No debt records found",
              style: TextStyle(fontFamily: 'Manrope', color: Colors.white.withOpacity(0.6), fontSize: 15),
            ),
            const SizedBox(height: 6),
            Text(
              "Tap 'Record Loan / Debt' to log a borrowed loan or money lent out",
              style: TextStyle(fontFamily: 'Manrope', color: Colors.white.withOpacity(0.35), fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 100),
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
      badgeColor = const Color(0xFF147D64);
      badgeText = "SETTLED";
    } else if (isOverdue) {
      badgeColor = const Color(0xFFCD5C52);
      badgeText = "OVERDUE";
    } else {
      badgeColor = isLent ? const Color(0xFF2CB8A0) : const Color(0xFF6C8CFF);
      badgeText = isLent ? "RECEIVABLE" : "LIABILITY";
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        padding: const EdgeInsets.all(16),
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
                    backgroundColor: (isLent ? const Color(0xFF2CB8A0) : const Color(0xFFCD5C52)).withOpacity(0.18),
                    child: Icon(
                      isLent ? Icons.arrow_outward_rounded : Icons.arrow_downward_rounded,
                      color: isLent ? const Color(0xFF2CB8A0) : const Color(0xFFCD5C52),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
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
                                color: Colors.white.withOpacity(0.5),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                debt.counterpartyName,
                                style: const TextStyle(
                                  fontFamily: 'Manrope',
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        if (debt.counterpartyContact != null && debt.counterpartyContact!.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            debt.counterpartyContact!,
                            style: TextStyle(
                              fontFamily: 'Manrope',
                              fontSize: 11,
                              color: Colors.white.withOpacity(0.4),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: badgeColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: badgeColor.withOpacity(0.3)),
                    ),
                    child: Text(
                      badgeText,
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: badgeColor,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.white30, size: 18),
                    onPressed: () => _confirmDeleteDebt(context, debt),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // 2. Financial Amount Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "REMAINING",
                        style: TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white.withOpacity(0.45),
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "LKR ${NumberFormat('#,##0').format(debt.remainingAmount)}",
                        style: TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isSettled ? Colors.white54 : (isLent ? const Color(0xFF2CB8A0) : const Color(0xFFCD5C52)),
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        "TOTAL DUE",
                        style: TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white.withOpacity(0.45),
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "LKR ${NumberFormat('#,##0').format(debt.totalAmountDue)}",
                        style: const TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // 3. Progress bar (% repaid)
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: debt.progressPercentage,
                  minHeight: 6,
                  backgroundColor: Colors.white10,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isSettled ? const Color(0xFF147D64) : (isLent ? const Color(0xFF2CB8A0) : const Color(0xFF6C8CFF)),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Repaid: LKR ${NumberFormat('#,##0').format(debt.amountRepaid)} (${(debt.progressPercentage * 100).toInt()}%)",
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 11,
                      color: Colors.white.withOpacity(0.45),
                    ),
                  ),
                  if (debt.dueDate != null)
                    Text(
                      "Due: ${DateFormat('MMM d, yyyy').format(debt.dueDate!)}",
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 11,
                        color: isOverdue ? const Color(0xFFCD5C52) : Colors.white54,
                        fontWeight: isOverdue ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                ],
              ),

              // 4. Action buttons
              if (!isSettled) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showRepaymentSheet(context, debt),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: isLent ? const Color(0xFF2CB8A0) : const Color(0xFF6C8CFF),
                          side: BorderSide(
                            color: (isLent ? const Color(0xFF2CB8A0) : const Color(0xFF6C8CFF)).withOpacity(0.4),
                          ),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                        icon: Icon(
                          isLent ? Icons.call_received_rounded : Icons.payment_rounded,
                          size: 16,
                        ),
                        label: Text(
                          isLent ? "Collect / Repay" : "Pay Installment",
                          style: const TextStyle(fontFamily: 'Manrope', fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.history_rounded, color: Colors.white54, size: 20),
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

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF141C28),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
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
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              "Record Loan or Debt",
              style: TextStyle(fontFamily: 'Manrope', fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 4),
            Text(
              "Completely isolated from your monthly expenses, income & savings",
              style: TextStyle(fontFamily: 'Manrope', fontSize: 12, color: Colors.white.withOpacity(0.5)),
            ),
            const SizedBox(height: 16),

            // Toggle Borrowed vs Lent
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: const Center(child: Text("I BORROWED (DEBT)")),
                    selected: _type == DebtType.BORROWED,
                    onSelected: (_) => setState(() => _type = DebtType.BORROWED),
                    selectedColor: const Color(0xFFCD5C52).withOpacity(0.3),
                    backgroundColor: Colors.white.withOpacity(0.04),
                    labelStyle: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _type == DebtType.BORROWED ? const Color(0xFFCD5C52) : Colors.white60,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ChoiceChip(
                    label: const Center(child: Text("I LENT (RECEIVABLE)")),
                    selected: _type == DebtType.LENT,
                    onSelected: (_) => setState(() => _type = DebtType.LENT),
                    selectedColor: const Color(0xFF2CB8A0).withOpacity(0.3),
                    backgroundColor: Colors.white.withOpacity(0.04),
                    labelStyle: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _type == DebtType.LENT ? const Color(0xFF2CB8A0) : Colors.white60,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Counterparty Name
            TextField(
              controller: _nameController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: isLent ? "Borrower Name (Who received the money?)" : "Lender / Bank Name",
                labelStyle: const TextStyle(color: Colors.white60),
                enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF2CB8A0))),
              ),
            ),
            const SizedBox(height: 12),

            // Counterparty Contact (Optional)
            TextField(
              controller: _contactController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: isLent ? "Contact Phone / Email (Optional)" : "Account / Reference # (Optional)",
                labelStyle: const TextStyle(color: Colors.white60),
                enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF2CB8A0))),
              ),
            ),
            const SizedBox(height: 12),

            // Principal Amount & Optional Interest Rate
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: "Principal Amount (LKR)",
                      labelStyle: TextStyle(color: Colors.white60),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF2CB8A0))),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _interestController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: "Interest % (Opt.)",
                      labelStyle: TextStyle(color: Colors.white60),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF2CB8A0))),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Date Pickers: Start Date & Due Date
            Row(
              children: [
                Expanded(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text("Start Date", style: TextStyle(color: Colors.white60, fontSize: 11)),
                    subtitle: Text(DateFormat('MMM d, yyyy').format(_startDate), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    trailing: const Icon(Icons.calendar_today_rounded, color: Colors.white54, size: 18),
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
                    title: const Text("Due Date (Optional)", style: TextStyle(color: Colors.white60, fontSize: 11)),
                    subtitle: Text(
                      _dueDate != null ? DateFormat('MMM d, yyyy').format(_dueDate!) : "None",
                      style: TextStyle(color: _dueDate != null ? Colors.white : Colors.white38, fontWeight: FontWeight.bold),
                    ),
                    trailing: const Icon(Icons.event_available_rounded, color: Colors.white54, size: 18),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _dueDate ?? DateTime.now().add(const Duration(days: 30)),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2035),
                      );
                      if (picked != null) setState(() => _dueDate = picked);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Reminder Days
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Reminder Alert", style: TextStyle(color: Colors.white70, fontSize: 13, fontFamily: 'Manrope')),
                DropdownButton<int>(
                  value: _reminderDays,
                  dropdownColor: const Color(0xFF141C28),
                  style: const TextStyle(color: Colors.white, fontFamily: 'Manrope'),
                  underline: const SizedBox(),
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
            const SizedBox(height: 8),

            // Notes
            TextField(
              controller: _noteController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: "Notes (Optional)",
                labelStyle: TextStyle(color: Colors.white60),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF2CB8A0))),
              ),
            ),
            const SizedBox(height: 24),

            // Submit Button
            _isSaving
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF2CB8A0)))
                : ElevatedButton(
                    onPressed: () async {
                      final name = _nameController.text.trim();
                      final amount = double.tryParse(_amountController.text.trim());
                      if (name.isEmpty || amount == null || amount <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Please enter a valid counterparty name and amount"), backgroundColor: Color(0xFFCD5C52)),
                        );
                        return;
                      }

                      final interest = double.tryParse(_interestController.text.trim());

                      setState(() => _isSaving = true);
                      final debtProv = Provider.of<DebtProvider>(context, listen: false);
                      final success = await debtProv.createDebt(
                        type: _type,
                        counterpartyName: name,
                        counterpartyContact: _contactController.text.trim().isNotEmpty ? _contactController.text.trim() : null,
                        principalAmount: amount,
                        interestRate: interest,
                        startDate: _startDate,
                        dueDate: _dueDate,
                        reminderDaysBefore: _reminderDays,
                        note: _noteController.text.trim().isNotEmpty ? _noteController.text.trim() : null,
                      );

                      if (context.mounted) {
                        setState(() => _isSaving = false);
                        if (success) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Debt/Loan record created!"), backgroundColor: Color(0xFF147D64)),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(debtProv.errorMessage ?? "Failed to create record"), backgroundColor: const Color(0xFFCD5C52)),
                          );
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF147D64),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text("Save Record", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
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

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF141C28),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            isLent ? "Collect Repayment" : "Pay Installment",
            style: const TextStyle(fontFamily: 'Manrope', fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 4),
          Text(
            "${isLent ? 'From' : 'To'}: ${widget.debt.counterpartyName} · Outstanding: LKR ${NumberFormat('#,##0').format(widget.debt.remainingAmount)}",
            style: const TextStyle(fontFamily: 'Manrope', fontSize: 12, color: Color(0xFF2CB8A0), fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),

          // Amount + Quick Full Pay Chip
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: "Repayment Amount (LKR)",
                    labelStyle: TextStyle(color: Colors.white60),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF2CB8A0))),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ActionChip(
                label: const Text("Full Balance", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                backgroundColor: const Color(0xFF2CB8A0).withOpacity(0.18),
                labelStyle: const TextStyle(color: Color(0xFF2CB8A0)),
                onPressed: () {
                  _amountController.text = widget.debt.remainingAmount.toStringAsFixed(0);
                },
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Payment Method Selector
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Payment Method", style: TextStyle(color: Colors.white70, fontSize: 13, fontFamily: 'Manrope')),
              DropdownButton<PaymentMethod>(
                value: _paymentMethod,
                dropdownColor: const Color(0xFF141C28),
                style: const TextStyle(color: Colors.white, fontFamily: 'Manrope'),
                underline: const SizedBox(),
                items: PaymentMethod.values.map((m) {
                  final label = m == PaymentMethod.CASH ? 'Cash' : 'Bank Transfer';
                  return DropdownMenuItem(value: m, child: Text(label));
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _paymentMethod = val);
                },
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Repayment Date
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text("Repayment Date", style: TextStyle(color: Colors.white60, fontSize: 11)),
            subtitle: Text(DateFormat('MMM d, yyyy').format(_repaymentDate), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            trailing: const Icon(Icons.calendar_today_rounded, color: Colors.white54, size: 18),
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
          const SizedBox(height: 8),

          // Note
          TextField(
            controller: _noteController,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: "Note (Optional)",
              labelStyle: TextStyle(color: Colors.white60),
              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF2CB8A0))),
            ),
          ),
          const SizedBox(height: 24),

          // Submit
          _isSaving
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF2CB8A0)))
              : ElevatedButton(
                  onPressed: () async {
                    final amount = double.tryParse(_amountController.text.trim());
                    if (amount == null || amount <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Please enter a valid repayment amount"), backgroundColor: Color(0xFFCD5C52)),
                      );
                      return;
                    }
                    if (amount > widget.debt.remainingAmount) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text("Amount exceeds outstanding balance of LKR ${NumberFormat('#,##0').format(widget.debt.remainingAmount)}"),
                          backgroundColor: const Color(0xFFCD5C52),
                        ),
                      );
                      return;
                    }

                    setState(() => _isSaving = true);
                    final debtProv = Provider.of<DebtProvider>(context, listen: false);
                    final success = await debtProv.recordRepayment(
                      debtId: widget.debt.id,
                      amount: amount,
                      repaymentDate: _repaymentDate,
                      paymentMethod: _paymentMethod,
                      note: _noteController.text.trim().isNotEmpty ? _noteController.text.trim() : null,
                    );

                    if (context.mounted) {
                      setState(() => _isSaving = false);
                      if (success) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Repayment logged successfully!"), backgroundColor: Color(0xFF147D64)),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(debtProv.errorMessage ?? "Failed to log repayment"), backgroundColor: const Color(0xFFCD5C52)),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF147D64),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text("Confirm Repayment", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                ),
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

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF141C28),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                debt.counterpartyName,
                style: const TextStyle(fontFamily: 'Manrope', fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (isLent ? const Color(0xFF2CB8A0) : const Color(0xFF6C8CFF)).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isLent ? "Lent (Receivable)" : "Borrowed (Debt)",
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isLent ? const Color(0xFF2CB8A0) : const Color(0xFF6C8CFF),
                  ),
                ),
              ),
            ],
          ),
          if (debt.note != null && debt.note!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(debt.note!, style: TextStyle(fontFamily: 'Manrope', fontSize: 12, color: Colors.white.withOpacity(0.6))),
          ],
          const SizedBox(height: 16),

          // Key metrics card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              children: [
                _buildMetricRow("Principal Amount", "LKR ${NumberFormat('#,##0').format(debt.principalAmount)}"),
                if (debt.interestRate != null && debt.interestRate! > 0)
                  _buildMetricRow("Interest Rate", "${debt.interestRate}%"),
                _buildMetricRow("Total Amount Due", "LKR ${NumberFormat('#,##0').format(debt.totalAmountDue)}"),
                _buildMetricRow("Total Repaid", "LKR ${NumberFormat('#,##0').format(debt.amountRepaid)}"),
                _buildMetricRow("Remaining Balance", "LKR ${NumberFormat('#,##0').format(debt.remainingAmount)}", isHighlight: true),
                _buildMetricRow("Start Date", DateFormat('MMM d, yyyy').format(debt.startDate)),
                if (debt.dueDate != null)
                  _buildMetricRow("Due Date", DateFormat('MMM d, yyyy').format(debt.dueDate!)),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Repayment History List
          Text(
            "Repayment History (${debt.repayments.length})",
            style: const TextStyle(fontFamily: 'Manrope', fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white70),
          ),
          const SizedBox(height: 8),
          if (debt.repayments.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12.0),
              child: Center(
                child: Text(
                  "No repayments recorded yet.",
                  style: TextStyle(fontFamily: 'Manrope', fontSize: 12, color: Colors.white.withOpacity(0.4)),
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
                  final methodLabel = rep.paymentMethod == PaymentMethod.CASH ? 'Cash' : 'Bank Transfer';
                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.02),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              DateFormat('MMM d, yyyy').format(rep.repaymentDate),
                              style: const TextStyle(fontFamily: 'Manrope', fontSize: 12, color: Colors.white70, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              "Via $methodLabel${rep.note != null ? ' · ${rep.note}' : ''}",
                              style: TextStyle(fontFamily: 'Manrope', fontSize: 10, color: Colors.white.withOpacity(0.4)),
                            ),
                          ],
                        ),
                        Text(
                          "+ LKR ${NumberFormat('#,##0').format(rep.amount)}",
                          style: const TextStyle(fontFamily: 'Manrope', fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF2CB8A0)),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white12,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text("Close", style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricRow(String label, String value, {bool isHighlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontFamily: 'Manrope', fontSize: 12, color: Colors.white.withOpacity(0.55))),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 12,
              fontWeight: isHighlight ? FontWeight.bold : FontWeight.w600,
              color: isHighlight ? const Color(0xFF2CB8A0) : Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
