import 'package:aureli/theme/app_colors.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/budget_provider.dart';
import '../../models/category_model.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/svg_icons.dart';

class OnboardingView extends StatefulWidget {
  const OnboardingView({super.key});

  @override
  State<OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends State<OnboardingView> {
  final Map<int, TextEditingController> _budgetControllers = {};
  final Map<int, Color> _categoryColors = {};
  // Categories whose color the user chose here; a reload must not overwrite those.
  final Set<int> _pickedColorIds = {};
  double _savingsRate = 20.0; // Recommended default 20%
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadCategories());
  }

  /// The page itself is usable at once; only the category limits need the server, so they
  /// load here and can be retried if the connection was too slow or failed.
  Future<void> _loadCategories({bool force = false}) async {
    await Provider.of<TransactionProvider>(context, listen: false)
        .fetchCategories(force: force);
    if (!mounted) return;
    final categories =
        Provider.of<TransactionProvider>(context, listen: false).categories;
    for (var cat in categories) {
      if (cat.type != TransactionType.EXPENSE) continue;
      // Keep the amount the user may already have typed.
      _budgetControllers.putIfAbsent(
          cat.id, () => TextEditingController(text: "500"));
      // Take the server's current color unless the user picked one themselves.
      if (!_pickedColorIds.contains(cat.id)) {
        _categoryColors[cat.id] = cat.color;
      }
    }
    setState(() {});
  }

  @override
  void dispose() {
    for (var controller in _budgetControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _showColorPicker(CategoryModel cat) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: context.cardLightBg,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text("Choose Color for ${cat.name}",
              style: TextStyle(
                  color: context.textPrimary,
                  fontFamily: 'Manrope',
                  fontSize: 16)),
          content: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: CategoryModel.defaultPalette.map((color) {
              final isSelected = _categoryColors[cat.id]?.value == color.value;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _categoryColors[cat.id] = color;
                    _pickedColorIds.add(cat.id);
                  });
                  Navigator.pop(context);
                },
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? Colors.white : Colors.transparent,
                      width: 3,
                    ),
                  ),
                  child: isSelected
                      ? Icon(Icons.check_rounded,
                          color: context.textPrimary, size: 20)
                      : null,
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Future<void> _complete() async {
    setState(() => _isSaving = true);
    final transactionProvider =
        Provider.of<TransactionProvider>(context, listen: false);
    final budgetProvider = Provider.of<BudgetProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    final expenseCategories = transactionProvider.categories
        .where((c) => c.type == TransactionType.EXPENSE);

    // Each step needs the server. They are all safe to repeat, so on the first failure we
    // stop, say why, and let the user simply press the button again.
    void fail(String? message) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message ?? "Could not finish setup. Please try again."),
          backgroundColor: context.tokens.coral,
        ),
      );
    }

    try {
      // Without the category list there are no limits to save, and finishing would mark
      // onboarding complete with nothing set up.
      if (expenseCategories.isEmpty) {
        fail("Your categories have not loaded yet. Check your connection and try again.");
        _loadCategories(force: true);
        return;
      }

      // 1. Update savings rate percentage
      if (!await authProvider.updateSavingsRate(_savingsRate)) {
        fail(authProvider.actionErrorMessage);
        return;
      }

      // 2. Update category colors if changed
      for (var cat in expenseCategories) {
        final chosenColor = _categoryColors[cat.id];
        if (chosenColor != null) {
          final String colorHex =
              '#${chosenColor.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
          final updated = await transactionProvider.updateCategory(
            cat.id,
            cat.name,
            cat.type,
            colorKey: colorHex,
            iconKey: cat.iconKey,
          );
          if (!updated) {
            fail(transactionProvider.actionErrorMessage);
            return;
          }
        }
      }

      // 3. Set budget limit for each category input
      final now = DateTime.now();
      for (var cat in expenseCategories) {
        final text = _budgetControllers[cat.id]?.text ?? "0";
        final double limit = double.tryParse(text) ?? 0.0;
        if (limit > 0) {
          final result = await budgetProvider.setCategoryBudget(
            categoryId: cat.id,
            month: now,
            limit: limit,
          );
          if (result == null) {
            fail(budgetProvider.errorMessage);
            return;
          }
        }
      }

      // 4. Transition onboarding completed status
      final success = await authProvider.completeOnboarding();
      if (!success) {
        fail(authProvider.actionErrorMessage);
        return;
      }
      if (mounted) {
        budgetProvider.fetchSummary();
      }
    } catch (e) {
      if (kDebugMode) debugPrint("Onboarding error: $e");
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final transactionProvider = Provider.of<TransactionProvider>(context);
    final expenseCategories = transactionProvider.categories
        .where((c) => c.type == TransactionType.EXPENSE)
        .toList();

    // Simulated numbers for LKR 100,000 monthly income
    const double sampleIncome = 100000.0;
    final double simulatedSavings = sampleIncome * (_savingsRate / 100);
    final double simulatedSpendable = sampleIncome - simulatedSavings;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          // Background blobs
          Positioned(
            top: -100,
            left: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.transparent,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0B3B5A).withValues(alpha: 0.5),
                    blurRadius: 100,
                    spreadRadius: 50,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            right: -50,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.transparent,
                boxShadow: [
                  BoxShadow(
                    color: context.tokens.emerald.withValues(alpha: 0.4),
                    blurRadius: 100,
                    spreadRadius: 50,
                  ),
                ],
              ),
            ),
          ),

          SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(height: 12),
                  Text(
                    "Welcome to Aureli",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: context.textPrimary,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    "Set up your automated savings vault and category limits to take charge of your finances.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 13,
                      color: context.tokens.inkMuted,
                    ),
                  ),
                  SizedBox(height: 16),

                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // 1. Savings Rate Target Card
                          GlassCard(
                            padding: EdgeInsets.all(18.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: context.tokens.amber
                                                .withValues(alpha: 0.18),
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                          child: Icon(
                                              Icons.savings_rounded,
                                              color: context.tokens.amber,
                                              size: 20),
                                        ),
                                        SizedBox(width: 10),
                                        Text(
                                          "Monthly Savings Target",
                                          style: TextStyle(
                                            fontFamily: 'Manrope',
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                            color: context.textPrimary,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: context.tokens.amber
                                            .withValues(alpha: 0.18),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        "${_savingsRate.toInt()}%",
                                        style: TextStyle(
                                          fontFamily: 'Manrope',
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: context.tokens.amber,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 12),
                                Text(
                                  "Automatically reserved from all income and locked in your Savings Vault. Mandatory range is 5% to 20%.",
                                  style: TextStyle(
                                    fontFamily: 'Manrope',
                                    fontSize: 12,
                                    color: context.tokens.inkMuted,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Slider(
                                  value: _savingsRate,
                                  min: 5.0,
                                  max: 20.0,
                                  divisions: 15,
                                  activeColor: context.tokens.amber,
                                  inactiveColor: context.divider,
                                  onChanged: (val) =>
                                      setState(() => _savingsRate = val),
                                ),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text("Min: 5%",
                                        style: TextStyle(
                                            color: Colors.white
                                                .withValues(alpha: 0.4),
                                            fontSize: 11)),
                                    Row(
                                      children: [
                                        AppSvgIcons.sparkles(
                                            size: 13,
                                            color: context.tokens.emerald),
                                        SizedBox(width: 4),
                                        Text("Recommended: 20%",
                                            style: TextStyle(
                                                color: context.tokens.emerald,
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                    Text("Max: 20%",
                                        style: TextStyle(
                                            color: Colors.white
                                                .withValues(alpha: 0.4),
                                            fontSize: 11)),
                                  ],
                                ),
                                SizedBox(height: 12),
                                // Simulation Preview
                                Container(
                                  padding: EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: context.tokens.inputFill,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: context.divider),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Simulation on LKR 100,000 income:",
                                        style: TextStyle(
                                          fontFamily: 'Manrope',
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white
                                              .withValues(alpha: 0.5),
                                        ),
                                      ),
                                      SizedBox(height: 6),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            children: [
                                              AppSvgIcons.lock(
                                                  size: 13,
                                                  color:
                                                      context.tokens.amber),
                                              SizedBox(width: 4),
                                              Text("Locked in Savings Vault:",
                                                  style: TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.white
                                                          .withValues(
                                                              alpha: 0.85))),
                                            ],
                                          ),
                                          Text(
                                              "LKR ${NumberFormat('#,##0').format(simulatedSavings)}",
                                              style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: context.tokens.amber,
                                                  fontSize: 12)),
                                        ],
                                      ),
                                      SizedBox(height: 4),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            children: [
                                              AppSvgIcons.cash(
                                                  size: 13,
                                                  color:
                                                      context.tokens.emerald),
                                              SizedBox(width: 4),
                                              Text("Spendable Allowance:",
                                                  style: TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.white
                                                          .withValues(
                                                              alpha: 0.85))),
                                            ],
                                          ),
                                          Text(
                                              "LKR ${NumberFormat('#,##0').format(simulatedSpendable)}",
                                              style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: context.tokens.emerald,
                                                  fontSize: 12)),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 16),

                          // 2. Category Limits Card
                          GlassCard(
                            padding: EdgeInsets.all(18.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  "Divide Allowance into Category Limits (LKR)",
                                  style: TextStyle(
                                    fontFamily: 'Manrope',
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: context.textPrimary,
                                  ),
                                ),
                                SizedBox(height: 12),
                                if (transactionProvider.isCategoriesLoading)
                                  Center(
                                    child: Padding(
                                      padding: const EdgeInsets.all(24.0),
                                      child: Column(
                                        children: [
                                          CircularProgressIndicator(
                                              color: context.tokens.emerald),
                                          const SizedBox(height: 12),
                                          Text(
                                            "Loading your categories. If the server was asleep this can take up to a minute.",
                                            key: const Key('categories-loading'),
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontFamily: 'Manrope',
                                              fontSize: 12,
                                              color: Colors.white
                                                  .withValues(alpha: 0.6),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                else if (expenseCategories.isEmpty)
                                  Center(
                                    child: Column(
                                      children: [
                                        Text(
                                          "Your categories could not be loaded yet.",
                                          key: const Key('categories-failed'),
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontFamily: 'Manrope',
                                            fontSize: 12,
                                            color: Colors.white
                                                .withValues(alpha: 0.6),
                                          ),
                                        ),
                                        TextButton(
                                          onPressed: () =>
                                              _loadCategories(force: true),
                                          child: const Text("Try again"),
                                        ),
                                      ],
                                    ),
                                  )
                                else
                                  ListView.builder(
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    itemCount: expenseCategories.length,
                                    itemBuilder: (context, index) {
                                      final cat = expenseCategories[index];
                                      final controller =
                                          _budgetControllers[cat.id];
                                      if (controller == null) {
                                        return SizedBox.shrink();
                                      }

                                      return Container(
                                        margin: EdgeInsets.only(bottom: 10.0),
                                        padding: EdgeInsets.symmetric(
                                            horizontal: 12.0, vertical: 4.0),
                                        decoration: BoxDecoration(
                                          color: Colors.white
                                              .withValues(alpha: 0.04),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          border: Border.all(
                                            color: Colors.white
                                                .withValues(alpha: 0.06),
                                            width: 1,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            GestureDetector(
                                              onTap: () =>
                                                  _showColorPicker(cat),
                                              child: Stack(
                                                children: [
                                                  CircleAvatar(
                                                    radius: 18,
                                                    backgroundColor:
                                                        (_categoryColors[
                                                                    cat.id] ??
                                                                cat.color)
                                                            .withValues(alpha: 0.25),
                                                    child: AppSvgIcons
                                                        .getCategorySvg(
                                                      cat.iconKey,
                                                      cat.name,
                                                      size: 16,
                                                      color: _categoryColors[
                                                              cat.id] ??
                                                          cat.color,
                                                    ),
                                                  ),
                                                  Positioned(
                                                    right: 0,
                                                    bottom: 0,
                                                    child: Container(
                                                      padding:
                                                          EdgeInsets.all(2),
                                                      decoration: BoxDecoration(
                                                        color: _categoryColors[
                                                                cat.id] ??
                                                            cat.color,
                                                        shape: BoxShape.circle,
                                                      ),
                                                      child: Icon(
                                                          Icons.palette_rounded,
                                                          size: 8,
                                                          color: context
                                                              .textPrimary),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            SizedBox(width: 12),
                                            Expanded(
                                              child: Text(
                                                cat.name,
                                                style: TextStyle(
                                                  fontFamily: 'Manrope',
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                  color: context.textPrimary,
                                                ),
                                              ),
                                            ),
                                            SizedBox(width: 12),
                                            SizedBox(
                                              width: 100,
                                              child: TextField(
                                                controller: controller,
                                                keyboardType:
                                                    TextInputType.number,
                                                textAlign: TextAlign.end,
                                                style: TextStyle(
                                                  color: context.textPrimary,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                                decoration:
                                                    InputDecoration(
                                                  border: InputBorder.none,
                                                  hintText: "0.0",
                                                  hintStyle: TextStyle(
                                                      color: context.tokens.hairline),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                              ],
                            ),
                          ),
                          SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),

                  // Submit Button
                  _isSaving
                      ? Center(
                          child: CircularProgressIndicator(
                              color: context.tokens.emerald),
                        )
                      : ElevatedButton(
                          onPressed: _complete,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: context.tokens.brand,
                            foregroundColor: context.textPrimary,
                            padding: EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            "Complete Onboarding Setup",
                            style: TextStyle(
                              fontFamily: 'Manrope',
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                  SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
