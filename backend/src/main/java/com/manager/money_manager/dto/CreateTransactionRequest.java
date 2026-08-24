package com.manager.money_manager.dto;

import com.manager.money_manager.model.PaymentMethod;
import com.manager.money_manager.model.TransactionType;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import lombok.Getter;
import lombok.Setter;
import java.math.BigDecimal;
import java.time.LocalDate;

@Getter
@Setter
public class CreateTransactionRequest {

    @NotNull(message = "Transaction type must not be null")
    private TransactionType type;

    @NotNull(message = "Amount must not be null")
    @Positive(message = "Amount must be greater than zero")
    private BigDecimal amount;

    @NotNull(message = "Transaction date must not be null")
    private LocalDate transactionDate;

    private String note;

    @NotNull(message = "Payment method must not be null")
    private PaymentMethod paymentMethod;

    @NotNull(message = "Category ID must not be null")
    private Long categoryId;
}
