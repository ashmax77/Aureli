package com.manager.money_manager.dto;

import lombok.AllArgsConstructor;
import lombok.Getter;
import lombok.Setter;
import java.math.BigDecimal;

@Getter
@Setter
@AllArgsConstructor
public class MonthlyTrendDTO {
    private String month; // Format: "YYYY-MM"
    private BigDecimal totalIncome;
    private BigDecimal totalExpenses;
}
