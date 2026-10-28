package com.manager.money_manager.dto;

import lombok.Getter;
import lombok.Setter;

import java.math.BigDecimal;
import java.util.List;

@Getter
@Setter
public class DashboardSummaryDTO {
    private BigDecimal totalIncome;
    private BigDecimal totalExpenses;
    private BigDecimal netCashFlow;
    private BigDecimal previousMonthExpenses;
    private List<CategoryBudgetSummaryDTO> categoryBudgets;
    private BigDecimal spendableAllowance;
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
        result.spendableAllowance = source.getSpendableAllowance();
        result.cashExpenses = source.getCashExpenses();
        result.cardExpenses = source.getCardExpenses();
        result.bankTransferExpenses = source.getBankTransferExpenses();
        return result;
    }
}