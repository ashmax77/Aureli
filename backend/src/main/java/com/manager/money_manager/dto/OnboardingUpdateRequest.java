package com.manager.money_manager.dto;

import com.manager.money_manager.model.OnboardingStatus;
import jakarta.validation.constraints.NotNull;
import lombok.Getter;
import lombok.Setter;

@Getter
@Setter
public class OnboardingUpdateRequest {

    @NotNull(message = "Status must not be null")
    private OnboardingStatus status;
}
