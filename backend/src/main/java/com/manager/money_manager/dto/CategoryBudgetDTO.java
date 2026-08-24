package com.manager.money_manager.dto;

import lombok.Getter;
import lombok.Setter;
import java.math.BigDecimal;
import java.time.LocalDate;

@Getter
@Setter
public class CategoryBudgetDTO {
    private Long id;
    private Long categoryId;
    private String categoryName;
    private LocalDate budgetMonth;
    private BigDecimal amountLimit;
}
