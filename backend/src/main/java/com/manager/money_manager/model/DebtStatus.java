package com.manager.money_manager.model;

public enum DebtStatus {
    ACTIVE,    // Outstanding balance remains to be repaid
    SETTLED,   // Fully repaid / closed
    OVERDUE,   // Due date has passed and remaining balance > 0
    CANCELLED  // Forgiven, written off, or cancelled
}
