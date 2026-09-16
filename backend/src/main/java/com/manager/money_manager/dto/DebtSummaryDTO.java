package com.manager.money_manager.dto;

import lombok.Getter;
import lombok.Setter;

import java.math.BigDecimal;

@Getter
@Setter
public class DebtSummaryDTO {
    private BigDecimal totalLent;         // Total active receivables (people owe user)
    private BigDecimal totalBorrowed;     // Total active liabilities (user owes lenders)
    private BigDecimal netDebtPosition;   // totalLent - totalBorrowed
    private long activeLentCount;
    private long activeBorrowedCount;
    private long overdueCount;
}
