package com.manager.money_manager.dto;

import com.manager.money_manager.model.DebtStatus;
import lombok.Getter;
import lombok.Setter;

import java.time.LocalDate;

@Getter
@Setter
public class UpdateDebtRequest {

    private String counterpartyName;
    private String counterpartyContact;
    private LocalDate dueDate;
    private Integer reminderDaysBefore;
    private DebtStatus status;
    private String note;
}
