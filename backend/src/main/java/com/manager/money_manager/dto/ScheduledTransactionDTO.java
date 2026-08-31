package com.manager.money_manager.dto;

import com.manager.money_manager.model.PaymentMethod;
import com.manager.money_manager.model.ScheduledFrequency;
import com.manager.money_manager.model.ScheduledStatus;
import com.manager.money_manager.model.TransactionType;
import lombok.Data;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;

@Data
public class ScheduledTransactionDTO {
    private Long id;
    private Long categoryId;
    private String categoryName;
    private TransactionType type;
    private String title;
    private BigDecimal amount;
    private LocalDate dueDate;
    private PaymentMethod paymentMethod;
    private String note;
    private ScheduledFrequency recurringFrequency;
    private ScheduledStatus status;
    private Integer reminderDaysBefore;
    private LocalDateTime lastNotifiedAt;
    private LocalDateTime createdAt;
}
