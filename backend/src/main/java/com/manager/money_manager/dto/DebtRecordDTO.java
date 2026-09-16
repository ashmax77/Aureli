package com.manager.money_manager.dto;

import com.manager.money_manager.model.DebtStatus;
import com.manager.money_manager.model.DebtType;
import lombok.Getter;
import lombok.Setter;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;

@Getter
@Setter
public class DebtRecordDTO {
    private Long id;
    private DebtType type;
    private String counterpartyName;
    private String counterpartyContact;
    private BigDecimal principalAmount;
    private BigDecimal interestRate;
    private BigDecimal totalAmountDue;
    private BigDecimal amountRepaid;
    private BigDecimal remainingAmount;
    private LocalDate startDate;
    private LocalDate dueDate;
    private DebtStatus status;
    private Integer reminderDaysBefore;
    private String note;
    private List<DebtRepaymentDTO> repayments;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;
}
