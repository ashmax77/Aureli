package com.manager.money_manager.dto;

import com.manager.money_manager.model.BudgetAlertState;
import lombok.Getter;
import lombok.Setter;
import java.math.BigDecimal;

@Getter
@Setter
public class CategoryBudgetSummaryDTO {
    private Long categoryId;
    private String categoryName;
    private BigDecimal budgetLimit;
    private BigDecimal currentSpend;
    private BigDecimal remainingBudget;
    private boolean isOverBudget;
    private BudgetAlertState alertState;
}
