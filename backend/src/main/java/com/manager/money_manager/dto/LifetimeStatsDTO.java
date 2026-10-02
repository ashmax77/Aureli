package com.manager.money_manager.dto;

import lombok.Builder;
import lombok.Data;

@Data
@Builder
public class LifetimeStatsDTO {
    private Double totalEarned;
    private Double totalSpent;
    private Double totalSaved;
    private Double netWorth;
    private Integer activeMonths;
}
