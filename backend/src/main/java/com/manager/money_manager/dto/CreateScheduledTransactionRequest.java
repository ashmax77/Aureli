package com.manager.money_manager.dto;

import com.manager.money_manager.model.PaymentMethod;
import com.manager.money_manager.model.ScheduledFrequency;
import com.manager.money_manager.model.TransactionType;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.Data;
import java.math.BigDecimal;
import java.time.LocalDate;

@Data
public class CreateScheduledTransactionRequest {

    @NotNull
    private Long categoryId;

    @NotNull
    private TransactionType type = TransactionType.EXPENSE;

    @NotBlank
    private String title;

    @NotNull
    @DecimalMin(value = "0.01", message = "Amount must be greater than zero")
    private BigDecimal amount;

    @NotNull
    private LocalDate dueDate;

    @NotNull
    private PaymentMethod paymentMethod = PaymentMethod.CASH;

    private String note;

    private ScheduledFrequency recurringFrequency = ScheduledFrequency.ONCE;

    private Integer reminderDaysBefore = 3;
}
