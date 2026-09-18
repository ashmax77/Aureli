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

  IconData _getCategoryIcon(String name) {
    name = name.toLowerCase();
    if (name.contains('food') || name.contains('eat') || name.contains('grocer')) {
      return Icons.restaurant_rounded;
    }
    if (name.contains('rent') || name.contains('home') || name.contains('house')) {
      return Icons.home_work_rounded;
    }
    if (name.contains('utility') || name.contains('bill') || name.contains('water') || name.contains('power')) {
      return Icons.lightbulb_outline_rounded;
    }
    if (name.contains('travel') || name.contains('transport') || name.contains('car') || name.contains('fuel')) {
      return Icons.directions_car_filled_rounded;
    }
    if (name.contains('entertain') || name.contains('movie') || name.contains('fun') || name.contains('game')) {
      return Icons.sports_esports_rounded;
    }
    if (name.contains('edu') || name.contains('school') || name.contains('study') || name.contains('book')) {
      return Icons.school_rounded;
    }
    if (name.contains('medic') || name.contains('health') || name.contains('pharma') || name.contains('doctor') || name.contains('hospital')) {
      return Icons.medical_services_rounded;
    }
    return Icons.category_rounded;
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

      // 2. Set budget limit for each category input
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

      // 3. Transition onboarding completed status
      final success = await authProvider.completeOnboarding();
      if (success && mounted) {
        budgetProvider.fetchSummary();
      }
    } catch (e) {
      debugPrint("Onboarding error: $e");
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
      backgroundColor: const Color(0xFF0F1621),
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
                                            CircleAvatar(
                                              radius: 16,
                                              backgroundColor: const Color(0xFF0B3B5A).withValues(alpha: 0.3),
                                              child: Icon(
                                                _getCategoryIcon(cat.name),
                                                color: Colors.white,
                                                size: 16,
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
