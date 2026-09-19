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
  double _savingsRate = 20.0; // Recommended default 20%
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<TransactionProvider>(context, listen: false).fetchCategories().then((_) {
        final categories = Provider.of<TransactionProvider>(context, listen: false).categories;
        for (var cat in categories) {
          if (cat.type == TransactionType.EXPENSE) {
            _budgetControllers[cat.id] = TextEditingController(text: "500");
            _categoryColors[cat.id] = cat.color;
          }
        }
        setState(() {});
      });
    });
  }

  @override
  void dispose() {
    for (var controller in _budgetControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _showColorPicker(CategoryModel cat) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF141B26) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text("Choose Color for ${cat.name}", style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontFamily: 'Manrope', fontSize: 16)),
          content: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: CategoryModel.defaultPalette.map((color) {
              final isSelected = _categoryColors[cat.id]?.value == color.value;
              return GestureDetector(
                onTap: () {
                  setState(() => _categoryColors[cat.id] = color);
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
                      ? const Icon(Icons.check_rounded, color: Colors.white, size: 20)
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
    final transactionProvider = Provider.of<TransactionProvider>(context, listen: false);
    final budgetProvider = Provider.of<BudgetProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    final expenseCategories = transactionProvider.categories.where((c) => c.type == TransactionType.EXPENSE);

    try {
      // 1. Update savings rate percentage
      await authProvider.updateSavingsRate(_savingsRate);

      // 2. Update category colors if changed
      for (var cat in expenseCategories) {
        final chosenColor = _categoryColors[cat.id];
        if (chosenColor != null) {
          final String colorHex = '#${chosenColor.value.toRadixString(16).substring(2).toUpperCase()}';
          await transactionProvider.updateCategory(
            cat.id,
            cat.name,
            cat.type,
            colorKey: colorHex,
            iconKey: cat.iconKey,
          );
        }
      }

      // 3. Set budget limit for each category input
      final now = DateTime.now();
      for (var cat in expenseCategories) {
        final text = _budgetControllers[cat.id]?.text ?? "0";
        final double limit = double.tryParse(text) ?? 0.0;
        if (limit > 0) {
          await budgetProvider.setCategoryBudget(
            categoryId: cat.id,
            month: now,
            limit: limit,
          );
        }
      }

      // 4. Transition onboarding completed status
      final success = await authProvider.completeOnboarding();
      if (success && mounted) {
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
                    color: const Color(0xFF147D64).withValues(alpha: 0.4),
                    blurRadius: 100,
                    spreadRadius: 50,
                  ),
                ],
              ),
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 12),
                  const Text(
                    "Welcome to Aureli",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "Set up your automated savings vault and category limits to take charge of your finances.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 16),

                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // 1. Savings Rate Target Card
                          GlassCard(
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
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFE89A58).withValues(alpha: 0.18),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: const Icon(Icons.savings_rounded, color: Color(0xFFE89A58), size: 20),
                                        ),
                                        const SizedBox(width: 10),
                                        const Text(
                                          "Monthly Savings Target",
                                          style: TextStyle(
                                            fontFamily: 'Manrope',
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE89A58).withValues(alpha: 0.18),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        "${_savingsRate.toInt()}%",
                                        style: const TextStyle(
                                          fontFamily: 'Manrope',
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFFE89A58),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  "Automatically reserved from all income and locked in your Savings Vault. Mandatory range is 5% to 20%.",
                                  style: TextStyle(
                                    fontFamily: 'Manrope',
                                    fontSize: 12,
                                    color: Colors.white.withValues(alpha: 0.65),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Slider(
                                  value: _savingsRate,
                                  min: 5.0,
                                  max: 20.0,
                                  divisions: 15,
                                  activeColor: const Color(0xFFE89A58),
                                  inactiveColor: Colors.white12,
                                  onChanged: (val) => setState(() => _savingsRate = val),
                                ),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text("Min: 5%", style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11)),
                                    Row(
                                      children: [
                                        AppSvgIcons.sparkles(size: 13, color: const Color(0xFF2CB8A0)),
                                        const SizedBox(width: 4),
                                        const Text("Recommended: 20%", style: TextStyle(color: Color(0xFF2CB8A0), fontSize: 11, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                    Text("Max: 20%", style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11)),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                // Simulation Preview
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.04),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: Colors.white10),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Simulation on LKR 100,000 income:",
                                        style: TextStyle(
                                          fontFamily: 'Manrope',
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white.withValues(alpha: 0.5),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            children: [
                                              AppSvgIcons.lock(size: 13, color: const Color(0xFFE89A58)),
                                              const SizedBox(width: 4),
                                              Text("Locked in Savings Vault:", style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.85))),
                                            ],
                                          ),
                                          Text("LKR ${NumberFormat('#,##0').format(simulatedSavings)}", style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFE89A58), fontSize: 12)),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            children: [
                                              AppSvgIcons.cash(size: 13, color: const Color(0xFF2CB8A0)),
                                              const SizedBox(width: 4),
                                              Text("Spendable Allowance:", style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.85))),
                                            ],
                                          ),
                                          Text("LKR ${NumberFormat('#,##0').format(simulatedSpendable)}", style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2CB8A0), fontSize: 12)),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // 2. Category Limits Card
                          GlassCard(
                            padding: const EdgeInsets.all(18.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Text(
                                  "Divide Allowance into Category Limits (LKR)",
                                  style: TextStyle(
                                    fontFamily: 'Manrope',
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                if (transactionProvider.isCategoriesLoading)
                                  const Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(24.0),
                                      child: CircularProgressIndicator(color: Color(0xFF147D64)),
                                    ),
                                  )
                                else
                                  ListView.builder(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    itemCount: expenseCategories.length,
                                    itemBuilder: (context, index) {
                                      final cat = expenseCategories[index];
                                      final controller = _budgetControllers[cat.id];
                                      if (controller == null) return const SizedBox.shrink();

                                      return Container(
                                        margin: const EdgeInsets.only(bottom: 10.0),
                                        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.04),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: Colors.white.withValues(alpha: 0.06),
                                            width: 1,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            GestureDetector(
                                              onTap: () => _showColorPicker(cat),
                                              child: Stack(
                                                children: [
                                                  CircleAvatar(
                                                    radius: 18,
                                                    backgroundColor: (_categoryColors[cat.id] ?? cat.color).withOpacity(0.25),
                                                    child: AppSvgIcons.getCategorySvg(
                                                      cat.iconKey,
                                                      cat.name,
                                                      size: 16,
                                                      color: _categoryColors[cat.id] ?? cat.color,
                                                    ),
                                                  ),
                                                  Positioned(
                                                    right: 0,
                                                    bottom: 0,
                                                    child: Container(
                                                      padding: const EdgeInsets.all(2),
                                                      decoration: BoxDecoration(
                                                        color: _categoryColors[cat.id] ?? cat.color,
                                                        shape: BoxShape.circle,
                                                      ),
                                                      child: const Icon(Icons.palette_rounded, size: 8, color: Colors.white),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Text(
                                                cat.name,
                                                style: const TextStyle(
                                                  fontFamily: 'Manrope',
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            SizedBox(
                                              width: 100,
                                              child: TextField(
                                                controller: controller,
                                                keyboardType: TextInputType.number,
                                                textAlign: TextAlign.end,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                                decoration: const InputDecoration(
                                                  border: InputBorder.none,
                                                  hintText: "0.0",
                                                  hintStyle: TextStyle(color: Colors.white30),
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
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),

                  // Submit Button
                  _isSaving
                      ? const Center(
                          child: CircularProgressIndicator(color: Color(0xFF147D64)),
                        )
                      : ElevatedButton(
                          onPressed: _complete,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF147D64),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            "Complete Onboarding Setup",
                            style: TextStyle(
                              fontFamily: 'Manrope',
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
