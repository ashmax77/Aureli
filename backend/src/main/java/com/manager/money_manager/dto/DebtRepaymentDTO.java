package com.manager.money_manager.dto;

import com.manager.money_manager.model.PaymentMethod;
import lombok.Getter;
import lombok.Setter;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;

@Getter
@Setter
public class DebtRepaymentDTO {
    private Long id;
    private Long debtRecordId;
    private BigDecimal amount;
    private LocalDate repaymentDate;
    private PaymentMethod paymentMethod;
    private String note;
    private LocalDateTime createdAt;
}
