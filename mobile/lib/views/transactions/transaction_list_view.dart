import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/budget_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/category_model.dart';
import '../../models/transaction_model.dart';
import '../dashboard/dashboard_view.dart';
import '../../widgets/svg_icons.dart';

class TransactionListView extends StatefulWidget {
  const TransactionListView({super.key});

  @override
  State<TransactionListView> createState() => _TransactionListViewState();
}

class _TransactionListViewState extends State<TransactionListView> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<TransactionProvider>(context, listen: false);
      provider.fetchTransactions(refresh: true);
      provider.fetchCategories();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      Provider.of<TransactionProvider>(
        context,
        listen: false,
      ).fetchTransactions();
    }
  }

  void _onSearchChanged(String query) {
    final provider = Provider.of<TransactionProvider>(context, listen: false);
    provider.searchQuery = query;
    provider.fetchTransactions(refresh: true);
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FilterBottomSheet(),
    ).then((_) {
      if (!context.mounted) return;
      Provider.of<TransactionProvider>(
        context,
        listen: false,
      ).fetchTransactions(refresh: true);
    });
  }

  void _showAddTransactionSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const AddTransactionSheet(),
    ).then((success) {
      if (!context.mounted) return;
      if (success == true) {
        Provider.of<TransactionProvider>(context, listen: false)
            .fetchTransactions(refresh: true);
        Provider.of<BudgetProvider>(context, listen: false).fetchSummary();
      }
    });
  }

  void _changeMonth(int delta) {
    final provider = Provider.of<TransactionProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    int newMonth = provider.selectedMonth + delta;
    int newYear = provider.selectedYear;

    if (newMonth > 12) {
      newMonth = 1;
      newYear++;
    } else if (newMonth < 1) {
      newMonth = 12;
      newYear--;
    }

    provider.changeMonth(
      newYear, 
      newMonth,
      registrationDate: authProvider.userModel?.createdAt,
    );
  }

  bool _canGoToPreviousMonth() {
    final provider = Provider.of<TransactionProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final registrationDate = authProvider.userModel?.createdAt;
    if (registrationDate == null) return true;

    int prevMonth = provider.selectedMonth - 1;
    int prevYear = provider.selectedYear;
    if (prevMonth < 1) {
      prevMonth = 12;
      prevYear--;
    }

    if (prevYear < registrationDate.year) {
      return false;
    }
    if (prevYear == registrationDate.year &&
        prevMonth < registrationDate.month) {
      return false;
    }

    return true;
  }

  Widget _buildDateHeader(HeaderItem item) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(
        left: 20.0,
        right: 20.0,
        top: 16.0,
        bottom: 6.0,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141C28) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            item.heading,
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (item.cashExpense > 0 || item.cashIncome > 0) ...[
                _buildHeaderBadge(
                  icon: Icons.payments_outlined,
                  label: "Cash",
                  income: item.cashIncome,
                  expense: item.cashExpense,
                  color: const Color(0xFF2CB8A0),
                ),
                const SizedBox(width: 6),
              ],
              if (item.bankExpense > 0 || item.bankIncome > 0) ...[
                _buildHeaderBadge(
                  icon: Icons.account_balance_outlined,
                  label: "Bank",
                  income: item.bankIncome,
                  expense: item.bankExpense,
                  color: const Color(0xFF6C8CFF),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderBadge({
    required IconData icon,
    required String label,
    required double income,
    required double expense,
    required Color color,
  }) {
    final net = income - expense;
    String text;
    Color textColor;

    if (income > 0 && expense == 0) {
      text = "+LKR ${NumberFormat('#,##0').format(income)}";
      textColor = const Color(0xFF2CB8A0);
    } else if (expense > 0 && income == 0) {
      text = "-LKR ${NumberFormat('#,##0').format(expense)}";
      textColor = const Color(0xFFCD5C52);
    } else {
      if (net >= 0) {
        text = "+LKR ${NumberFormat('#,##0').format(net)}";
        textColor = const Color(0xFF2CB8A0);
      } else {
        text = "-LKR ${NumberFormat('#,##0').format(net.abs())}";
        textColor = const Color(0xFFCD5C52);
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            "$label $text",
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final transactionProvider = Provider.of<TransactionProvider>(context);

    final selectedDate = DateTime(
      transactionProvider.selectedYear,
      transactionProvider.selectedMonth,
    );
    final monthName = DateFormat('MMMM yyyy').format(selectedDate);

    // Prepare grouped flat list items
    final List<ListItem> listItems = [];
    if (transactionProvider.transactions.isNotEmpty) {
      final Map<String, List<TransactionModel>> grouped = {};
      final Map<String, DateTime> dateMap = {};

      for (var t in transactionProvider.transactions) {
        final key = DateFormat('yyyy-MM-dd').format(t.transactionDate);
        grouped.putIfAbsent(key, () => []).add(t);
        dateMap[key] = t.transactionDate;
      }

      final sortedDates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

      final now = DateTime.now();
      final todayStr = DateFormat('yyyy-MM-dd').format(now);
      final yesterdayStr = DateFormat(
        'yyyy-MM-dd',
      ).format(now.subtract(const Duration(days: 1)));

      for (var dateKey in sortedDates) {
        final dayTxs = grouped[dateKey]!;

        // Sort transactions for this day in ASCENDING order of time/createdAt/id
        dayTxs.sort((a, b) {
          if (a.createdAt != null && b.createdAt != null) {
            final cmp = a.createdAt!.compareTo(b.createdAt!);
            if (cmp != 0) return cmp;
          }
          return a.id.compareTo(b.id);
        });

        double cashIncome = 0.0;
        double cashExpense = 0.0;
        double bankIncome = 0.0;
        double bankExpense = 0.0;

        for (var t in dayTxs) {
          if (t.paymentMethod == PaymentMethod.CASH) {
            if (t.type == TransactionType.INCOME) {
              cashIncome += t.amount;
            } else {
              cashExpense += t.amount;
            }
          } else if (t.paymentMethod == PaymentMethod.BANK_TRANSFER) {
            if (t.type == TransactionType.INCOME) {
              bankIncome += t.amount;
            } else {
              bankExpense += t.amount;
            }
          }
        }

        String headerText;
        if (dateKey == todayStr) {
          headerText = "Today";
        } else if (dateKey == yesterdayStr) {
          headerText = "Yesterday";
        } else {
          headerText = DateFormat('d MMM yyyy').format(dateMap[dateKey]!);
        }

        listItems.add(
          HeaderItem(
            heading: headerText,
            cashIncome: cashIncome,
            cashExpense: cashExpense,
            bankIncome: bankIncome,
            bankExpense: bankExpense,
          ),
        );

        for (var t in dayTxs) {
          listItems.add(TransactionItem(t));
        }
      }
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          "Transactions",
          style: TextStyle(
            fontFamily: 'Manrope',
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Month Selector Navigator
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: Icon(
                    Icons.chevron_left_rounded,
                    color: _canGoToPreviousMonth()
                        ? (isDark ? Colors.white70 : const Color(0xFF334155))
                        : (isDark ? Colors.white24 : Colors.black12),
                  ),
                  onPressed:
                      _canGoToPreviousMonth() ? () => _changeMonth(-1) : null,
                ),
                Text(
                  monthName,
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.chevron_right_rounded,
                    color: isDark ? Colors.white70 : const Color(0xFF334155),
                  ),
                  onPressed: () => _changeMonth(1),
                ),
              ],
            ),
          ),

          // Search box & Filters
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 20.0,
              vertical: 8.0,
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF0F172A)),
                    decoration: InputDecoration(
                      hintText: "Search note keywords...",
                      hintStyle: TextStyle(
                          color: isDark
                              ? Colors.white30
                              : const Color(0xFF94A3B8)),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color:
                            isDark ? Colors.white54 : const Color(0xFF64748B),
                      ),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: Icon(
                                Icons.clear_rounded,
                                color: isDark
                                    ? Colors.white54
                                    : const Color(0xFF64748B),
                              ),
                              onPressed: () {
                                _searchController.clear();
                                _onSearchChanged("");
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: isDark
                          ? Colors.white.withOpacity(0.04)
                          : const Color(0xFFF1F5F9),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(Icons.filter_list_rounded,
                      color: isDark ? Colors.white70 : const Color(0xFF334155)),
                  onPressed: _showFilterSheet,
                  tooltip: "Filters",
                ),
              ],
            ),
          ),

          // Transactions Page List
          Expanded(
            child: transactionProvider.errorMessage != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Text(
                        transactionProvider.errorMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontSize: 14,
                          fontFamily: 'Manrope',
                        ),
                      ),
                    ),
                  )
                : listItems.isEmpty && !transactionProvider.isLoading
                    ? Center(
                        child: Text(
                          "No transactions found",
                          style: TextStyle(
                              color: isDark
                                  ? Colors.white.withOpacity(0.5)
                                  : const Color(0xFF64748B)),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.only(bottom: 100),
                        itemCount: listItems.length +
                            (transactionProvider.hasMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == listItems.length) {
                            return const Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Center(
                                child: CircularProgressIndicator(
                                  color: Color(0xFF147D64),
                                ),
                              ),
                            );
                          }

                          final item = listItems[index];
                          if (item is HeaderItem) {
                            return _buildDateHeader(item);
                          }

                          final t = (item as TransactionItem).transaction;
                          final isExpense = t.type == TransactionType.EXPENSE;
                          final timeStr = t.createdAt != null
                              ? DateFormat('h:mm a').format(t.createdAt!)
                              : null;
                          final methodStr =
                              t.paymentMethod == PaymentMethod.BANK_TRANSFER
                                  ? 'Bank'
                                  : 'Cash';

                          final subtitleStr = timeStr != null
                              ? "${t.category.name} · $timeStr · $methodStr"
                              : "${t.category.name} · $methodStr";

                          final formattedAmount =
                              "${isExpense ? '-LKR ' : '+LKR '}${NumberFormat('#,##0').format(t.amount)}";

                          return Container(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 20.0,
                              vertical: 6.0,
                            ),
                            padding: const EdgeInsets.all(14.0),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withOpacity(0.04)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isDark
                                    ? Colors.white.withOpacity(0.06)
                                    : const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 18,
                                  backgroundColor:
                                      t.category.color.withOpacity(0.2),
                                  child: AppSvgIcons.getCategorySvg(
                                    t.category.iconKey,
                                    t.category.name,
                                    color: t.category.color,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        t.note ?? t.category.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: isDark
                                              ? Colors.white
                                              : const Color(0xFF0F172A),
                                          fontSize: 15,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        subtitleStr,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isDark
                                              ? Colors.white.withOpacity(0.5)
                                              : const Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Flexible(
                                  child: Text(
                                    formattedAmount,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isExpense
                                          ? const Color(0xFFCD5C52)
                                          : const Color(0xFF147D64),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddTransactionSheet(context),
        backgroundColor: const Color(0xFF147D64), // Emerald
        foregroundColor: Colors.white,
        elevation: 6,
        shape: const CircleBorder(),
        child: const Icon(Icons.add_rounded, size: 28),
      ),
    );
  }
}

class FilterBottomSheet extends StatefulWidget {
  const FilterBottomSheet({super.key});

  @override
  State<FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<FilterBottomSheet> {
  TransactionType? _type;
  int? _categoryId;
  DateTime? _startDate;
  DateTime? _endDate;
  final _minController = TextEditingController();
  final _maxController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final p = Provider.of<TransactionProvider>(context, listen: false);
    _type = p.selectedType;
    _categoryId = p.selectedCategoryId;
    _startDate = p.startDate;
    _endDate = p.endDate;
    if (p.minAmount != null) _minController.text = p.minAmount.toString();
    if (p.maxAmount != null) _maxController.text = p.maxAmount.toString();
  }

  @override
  void dispose() {
    _minController.dispose();
    _maxController.dispose();
    super.dispose();
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
    );
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }

  void _apply() {
    final p = Provider.of<TransactionProvider>(context, listen: false);
    p.selectedType = _type;
    p.selectedCategoryId = _categoryId;
    p.startDate = _startDate;
    p.endDate = _endDate;
    p.minAmount = double.tryParse(_minController.text);
    p.maxAmount = double.tryParse(_maxController.text);
    Navigator.pop(context);
  }

  void _reset() {
    final p = Provider.of<TransactionProvider>(context, listen: false);
    p.clearFilters();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final p = Provider.of<TransactionProvider>(context);

    final mediaQuery = MediaQuery.of(context);
    final bottomInset = mediaQuery.viewInsets.bottom;
    final systemBottomPadding = mediaQuery.viewPadding.bottom > 0
        ? mediaQuery.viewPadding.bottom
        : mediaQuery.padding.bottom;
    final effectiveBottomPadding = bottomInset +
        (systemBottomPadding > 0 ? systemBottomPadding : 16.0) +
        20.0;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetBg = isDark ? const Color(0xFF141B26) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? Colors.white70 : const Color(0xFF475569);

    return Container(
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: 20.0,
        left: 20.0,
        right: 20.0,
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
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: const BorderRadius.all(Radius.circular(2)),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Filters",
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                  ),
                ),
                TextButton(
                  onPressed: _reset,
                  child: Text(
                    "Reset All",
                    style: TextStyle(
                        color:
                            isDark ? Colors.white54 : const Color(0xFF64748B)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Type Filter
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: const Center(child: Text("ALL")),
                    selected: _type == null,
                    onSelected: (_) => setState(() => _type = null),
                    selectedColor: Colors.white12,
                    backgroundColor: Colors.transparent,
                    labelStyle: TextStyle(color: textPrimary),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ChoiceChip(
                    label: const Center(child: Text("EXPENSE")),
                    selected: _type == TransactionType.EXPENSE,
                    onSelected: (_) =>
                        setState(() => _type = TransactionType.EXPENSE),
                    selectedColor: const Color(0xFF0B3B5A),
                    backgroundColor: Colors.transparent,
                    labelStyle: TextStyle(color: textPrimary),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ChoiceChip(
                    label: const Center(child: Text("INCOME")),
                    selected: _type == TransactionType.INCOME,
                    onSelected: (_) =>
                        setState(() => _type = TransactionType.INCOME),
                    selectedColor: const Color(0xFF147D64),
                    backgroundColor: Colors.transparent,
                    labelStyle: TextStyle(color: textPrimary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Category Filter
            DropdownButtonFormField<int>(
              value: _categoryId,
              dropdownColor: sheetBg,
              style: TextStyle(color: textPrimary),
              decoration: InputDecoration(
                labelText: "Filter Category",
                labelStyle: TextStyle(color: textSecondary),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(
                      color: isDark ? Colors.white24 : const Color(0xFFCBD5E1)),
                ),
              ),
              items: [
                const DropdownMenuItem<int>(
                  value: null,
                  child: Text("All Categories"),
                ),
                ...p.categories.map(
                  (c) =>
                      DropdownMenuItem<int>(value: c.id, child: Text(c.name)),
                ),
              ],
              onChanged: (val) {
                setState(() => _categoryId = val);
              },
            ),
            const SizedBox(height: 16),

            // Date Range
            ListTile(
              title: Text(
                "Date Range",
                style: TextStyle(color: textSecondary),
              ),
              subtitle: Text(
                _startDate != null && _endDate != null
                    ? "${DateFormat('yyyy-MM-dd').format(_startDate!)} to ${DateFormat('yyyy-MM-dd').format(_endDate!)}"
                    : "No range selected",
                style: TextStyle(
                  color: textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              trailing: Icon(
                Icons.date_range_rounded,
                color: textSecondary,
              ),
              onTap: _pickDateRange,
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 16),

            // Amount Min / Max
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _minController,
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: textPrimary),
                    decoration: InputDecoration(
                      labelText: "Min Amount (LKR)",
                      labelStyle: TextStyle(color: textSecondary),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(
                            color: isDark
                                ? Colors.white24
                                : const Color(0xFFCBD5E1)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _maxController,
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: textPrimary),
                    decoration: InputDecoration(
                      labelText: "Max Amount (LKR)",
                      labelStyle: TextStyle(color: textSecondary),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(
                            color: isDark
                                ? Colors.white24
                                : const Color(0xFFCBD5E1)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            ElevatedButton(
              onPressed: _apply,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF147D64),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                "Apply Filters",
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

abstract class ListItem {}

class HeaderItem implements ListItem {
  final String heading;
  final double cashIncome;
  final double cashExpense;
  final double bankIncome;
  final double bankExpense;

  HeaderItem({
    required this.heading,
    required this.cashIncome,
    required this.cashExpense,
    required this.bankIncome,
    required this.bankExpense,
  });
}

class TransactionItem implements ListItem {
  final TransactionModel transaction;
  TransactionItem(this.transaction);
}
