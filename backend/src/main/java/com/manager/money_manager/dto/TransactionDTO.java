package com.manager.money_manager.dto;

import com.manager.money_manager.model.PaymentMethod;
import com.manager.money_manager.model.TransactionType;
import lombok.Getter;
import lombok.Setter;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;

@Getter
@Setter
public class TransactionDTO {
    private Long id;
    private TransactionType type;
    private BigDecimal amount;
    private LocalDate transactionDate;
    private String note;
    private PaymentMethod paymentMethod;
    private Long categoryId;
    private String categoryName;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;
}
