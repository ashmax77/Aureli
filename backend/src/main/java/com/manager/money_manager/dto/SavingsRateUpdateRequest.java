package com.manager.money_manager.dto;

import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotNull;
import lombok.Getter;
import lombok.Setter;

@Getter
@Setter
public class SavingsRateUpdateRequest {

    @NotNull(message = "Savings rate percentage is required")
    @DecimalMin(value = "5.0", message = "Minimum mandatory savings rate is 5.0%")
    @DecimalMax(value = "20.0", message = "Maximum savings rate is 20.0%")
    private Double savingsRatePercentage;
}
