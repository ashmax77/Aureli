import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/transaction_provider.dart';
import '../../models/category_model.dart';
import '../../models/transaction_model.dart';
import '../../widgets/glass_card.dart';

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
      Provider.of<TransactionProvider>(
        context,
        listen: false,
      ).fetchTransactions(refresh: true);
    });
  }

  Future<void> _exportCsv() async {
    final provider = Provider.of<TransactionProvider>(context, listen: false);
    final csvContent = await provider.exportCsv();
    if (!mounted) return;

    if (csvContent != null) {
      showDialog(
        context: context,
        builder: (context) => Dialog(
          backgroundColor: Colors.transparent,
          child: GlassCard(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  "CSV Export Ready",
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  height: 150,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      csvContent,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        "Close",
                        style: TextStyle(color: Colors.white60),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: csvContent));
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("CSV copied to clipboard"),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF147D64),
                      ),
                      icon: const Icon(
                        Icons.copy_rounded,
                        size: 18,
                        color: Colors.white,
                      ),
                      label: const Text(
                        "Copy CSV",
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to generate CSV export")),
      );
    }
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
    if (name.contains('salary') ||
        name.contains('work') ||
        name.contains('pay') ||
        name.contains('income')) {
      return Icons.payments_rounded;
    }
    return Icons.category_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final transactionProvider = Provider.of<TransactionProvider>(context);

    // Prepare grouped flat list items
    final List<ListItem> listItems = [];
    if (transactionProvider.transactions.isNotEmpty) {
      final now = DateTime.now();
      final todayStr = DateFormat('yyyy-MM-dd').format(now);
      final yesterdayStr = DateFormat(
        'yyyy-MM-dd',
      ).format(now.subtract(const Duration(days: 1)));

      String? currentHeader;

      for (var t in transactionProvider.transactions) {
        final tDateStr = DateFormat('yyyy-MM-dd').format(t.transactionDate);
        String header;
        if (tDateStr == todayStr) {
          header = "Today";
        } else if (tDateStr == yesterdayStr) {
          header = "Yesterday";
        } else {
          header = DateFormat('d MMM yyyy').format(t.transactionDate);
        }

        if (header != currentHeader) {
          listItems.add(HeaderItem(header));
          currentHeader = header;
        }
        listItems.add(TransactionItem(t));
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F1621),
      appBar: AppBar(
        title: const Text(
          "Transactions",
          style: TextStyle(
            fontFamily: 'Manrope',
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(
              Icons.file_download_rounded,
              color: Colors.white70,
            ),
            onPressed: _exportCsv,
            tooltip: "Export CSV",
          ),
          IconButton(
            icon: const Icon(Icons.filter_list_rounded, color: Colors.white70),
            onPressed: _showFilterSheet,
            tooltip: "Filters",
          ),
        ],
      ),
      body: Column(
        children: [
          // Search box
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 20.0,
              vertical: 8.0,
            ),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "Search note keywords...",
                hintStyle: const TextStyle(color: Colors.white30),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: Colors.white54,
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(
                          Icons.clear_rounded,
                          color: Colors.white54,
                        ),
                        onPressed: () {
                          _searchController.clear();
                          _onSearchChanged("");
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white.withOpacity(0.04),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
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
                      style: TextStyle(color: Colors.white.withOpacity(0.5)),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    itemCount:
                        listItems.length +
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
                        return Padding(
                          padding: const EdgeInsets.only(
                            left: 20.0,
                            top: 16.0,
                            bottom: 8.0,
                          ),
                          child: Text(
                            item.heading,
                            style: const TextStyle(
                              fontFamily: 'Manrope',
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.white70,
                            ),
                          ),
                        );
                      }

                      final t = (item as TransactionItem).transaction;
                      final isExpense = t.type == TransactionType.EXPENSE;
                      DateFormat('yyyy-MM-dd').format(t.transactionDate);

                      // Display subtitle in format "Category · Date/Relative Date"
                      final now = DateTime.now();
                      final todayStr = DateFormat('yyyy-MM-dd').format(now);
                      final yesterdayStr = DateFormat(
                        'yyyy-MM-dd',
                      ).format(now.subtract(const Duration(days: 1)));
                      final tDateStr = DateFormat(
                        'yyyy-MM-dd',
                      ).format(t.transactionDate);
                      String relativeDateStr;
                      if (tDateStr == todayStr) {
                        relativeDateStr = "Today";
                      } else if (tDateStr == yesterdayStr) {
                        relativeDateStr = "Yesterday";
                      } else {
                        relativeDateStr = DateFormat(
                          'd MMM yyyy',
                        ).format(t.transactionDate);
                      }
                      final subtitleStr =
                          "${t.category.name} · $relativeDateStr";

                      final formattedAmount =
                          "${isExpense ? '-LKR ' : '+LKR '}${NumberFormat('#,##0.00').format(t.amount)}";

                      return Dismissible(
                        key: Key("trans_${t.id}"),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20.0),
                          color: const Color(0xFFB42318), // Red
                          child: const Icon(
                            Icons.delete_sweep_rounded,
                            color: Colors.white,
                          ),
                        ),
                        onDismissed: (direction) {
                          transactionProvider.deleteTransaction(t.id);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Transaction deleted"),
                            ),
                          );
                        },
                        child: Container(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 20.0,
                            vertical: 6.0,
                          ),
                          padding: const EdgeInsets.all(14.0),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.04),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.06),
                            ),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: const Color(
                                  0xFF0B3B5A,
                                ).withOpacity(0.3),
                                child: Icon(
                                  _getCategoryIcon(t.category.name),
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      t.note ?? t.category.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
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
                                        color: Colors.white.withOpacity(0.5),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                formattedAmount,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isExpense
                                      ? const Color(0xFFCD5C52)
                                      : const Color(0xFF147D64),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
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

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF141B26),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: 20.0,
        left: 20.0,
        right: 20.0,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24.0,
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
                decoration: const BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.all(Radius.circular(2)),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Filters",
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                TextButton(
                  onPressed: _reset,
                  child: const Text(
                    "Reset All",
                    style: TextStyle(color: Colors.white54),
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
                    labelStyle: const TextStyle(color: Colors.white),
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
                    labelStyle: const TextStyle(color: Colors.white),
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
                    labelStyle: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Category Filter
            DropdownButtonFormField<int>(
              value: _categoryId,
              dropdownColor: const Color(0xFF141B26),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: "Filter Category",
                labelStyle: TextStyle(color: Colors.white70),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white24),
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
              title: const Text(
                "Date Range",
                style: TextStyle(color: Colors.white70),
              ),
              subtitle: Text(
                _startDate != null && _endDate != null
                    ? "${DateFormat('yyyy-MM-dd').format(_startDate!)} to ${DateFormat('yyyy-MM-dd').format(_endDate!)}"
                    : "No range selected",
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              trailing: const Icon(
                Icons.date_range_rounded,
                color: Colors.white70,
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
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: "Min Amount (LKR)",
                      labelStyle: TextStyle(color: Colors.white70),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.white24),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _maxController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: "Max Amount (LKR)",
                      labelStyle: TextStyle(color: Colors.white70),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.white24),
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
          ],
        ),
      ),
    );
  }
}

abstract class ListItem {}

class HeaderItem implements ListItem {
  final String heading;
  HeaderItem(this.heading);
}

class TransactionItem implements ListItem {
  final TransactionModel transaction;
  TransactionItem(this.transaction);
}
