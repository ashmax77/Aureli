package com.manager.money_manager.dto;

import lombok.Getter;
import lombok.Setter;

import java.math.BigDecimal;
import java.util.List;

/**
 * Response of GET /budgets/dashboard-summary. The mobile dashboard reads every field here
 * (savings vault, spendable allowance, cash / bank transfer split), so any field it needs
 * must be copied in {@link #from(BudgetSummaryResponseDTO)}; missing fields show as 0 in the app.
 */
@Getter
@Setter
public class DashboardSummaryDTO {
    private BigDecimal totalIncome;
    private BigDecimal totalExpenses;
    private BigDecimal netCashFlow;
    private BigDecimal previousMonthExpenses;
    private List<CategoryBudgetSummaryDTO> categoryBudgets;

    // Savings vault & allowance
    private Double savingsRatePercentage;
    private BigDecimal monthlyReservedSavings;
    private BigDecimal cumulativeSavings;
    private BigDecimal scheduledPaymentsTotal;
    private BigDecimal spendableAllowance;
    private BigDecimal totalAllocatedCategoryBudgets;
    private BigDecimal unallocatedAllowance;

    // Payment method breakdowns
    private BigDecimal cashIncome;
    private BigDecimal bankTransferIncome;
    private BigDecimal cashSpendable;
    private BigDecimal bankTransferSpendable;
    private BigDecimal cashExpenses;
    private BigDecimal cardExpenses;
    private BigDecimal bankTransferExpenses;

    public static DashboardSummaryDTO from(BudgetSummaryResponseDTO source) {
        DashboardSummaryDTO result = new DashboardSummaryDTO();
        result.totalIncome = source.getTotalIncome();
        result.totalExpenses = source.getTotalExpenses();
        result.netCashFlow = source.getNetCashFlow();
        result.previousMonthExpenses = source.getPreviousMonthExpenses();
        result.categoryBudgets = source.getCategoryBudgets();
        result.savingsRatePercentage = source.getSavingsRatePercentage();
        result.monthlyReservedSavings = source.getMonthlyReservedSavings();
        result.cumulativeSavings = source.getCumulativeSavings();
        result.scheduledPaymentsTotal = source.getScheduledPaymentsTotal();
        result.spendableAllowance = source.getSpendableAllowance();
        result.totalAllocatedCategoryBudgets = source.getTotalAllocatedCategoryBudgets();
        result.unallocatedAllowance = source.getUnallocatedAllowance();
        result.cashIncome = source.getCashIncome();
        result.bankTransferIncome = source.getBankTransferIncome();
        result.cashSpendable = source.getCashSpendable();
        result.bankTransferSpendable = source.getBankTransferSpendable();
        result.cashExpenses = source.getCashExpenses();
        result.cardExpenses = source.getCardExpenses();
        result.bankTransferExpenses = source.getBankTransferExpenses();
        return result;
    }
}
