package com.manager.money_manager.dto;

import lombok.Getter;
import lombok.Setter;
import java.math.BigDecimal;
import java.util.List;

@Getter
@Setter
public class BudgetSummaryResponseDTO {
    private BigDecimal totalIncome;
    private BigDecimal totalExpenses;
    private BigDecimal netCashFlow;
    private BigDecimal previousMonthExpenses;
    private List<CategoryBudgetSummaryDTO> categoryBudgets;
}
