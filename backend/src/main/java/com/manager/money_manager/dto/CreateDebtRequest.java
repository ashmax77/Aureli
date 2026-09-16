package com.manager.money_manager.dto;

import com.manager.money_manager.model.DebtType;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import lombok.Getter;
import lombok.Setter;

import java.math.BigDecimal;
import java.time.LocalDate;

@Getter
@Setter
public class CreateDebtRequest {

    @NotNull(message = "Debt type is required (BORROWED or LENT)")
    private DebtType type;

    @NotBlank(message = "Counterparty name is required")
    private String counterpartyName;

    private String counterpartyContact;

    @NotNull(message = "Principal amount is required")
    @Positive(message = "Principal amount must be positive")
    private BigDecimal principalAmount;

    private BigDecimal interestRate; // Optional percentage (e.g. 5.0%)

    @NotNull(message = "Start date is required")
    private LocalDate startDate;

    private LocalDate dueDate; // Optional expected settlement / maturity date

    private Integer reminderDaysBefore = 3;

    private String note;
}
