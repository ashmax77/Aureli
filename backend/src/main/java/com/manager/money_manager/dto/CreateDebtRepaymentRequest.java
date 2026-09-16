package com.manager.money_manager.dto;

import com.manager.money_manager.model.PaymentMethod;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import lombok.Getter;
import lombok.Setter;

import java.math.BigDecimal;
import java.time.LocalDate;

@Getter
@Setter
public class CreateDebtRepaymentRequest {

    @NotNull(message = "Repayment amount is required")
    @Positive(message = "Repayment amount must be positive")
    private BigDecimal amount;

    @NotNull(message = "Repayment date is required")
    private LocalDate repaymentDate;

    @NotNull(message = "Payment method is required (CARD or BANK_TRANSFER)")
    private PaymentMethod paymentMethod;

    private String note;
}
