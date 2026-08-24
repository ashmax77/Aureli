package com.manager.money_manager.dto;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import lombok.Getter;
import lombok.Setter;
import java.math.BigDecimal;
import java.time.LocalDate;

@Getter
@Setter
public class CreateBudgetRequest {

    @NotNull(message = "Category ID is required")
    private Long categoryId;

    @NotNull(message = "Budget month is required")
    private LocalDate budgetMonth;

    @NotNull(message = "Amount limit is required")
    @Positive(message = "Amount limit must be positive")
    private BigDecimal amountLimit;
}
