package com.manager.money_manager.dto;

import com.manager.money_manager.model.OnboardingStatus;
import lombok.Getter;
import lombok.Setter;

import java.time.LocalDateTime;

@Getter
@Setter
public class UserProfileDTO {
    private Long id;
    private String firebaseUid;
    private String email;
    private String currencyCode;
    private OnboardingStatus onboardingStatus;
    private LocalDateTime onboardingCompletedAt;
    private Double savingsRatePercentage;
    private LocalDateTime createdAt;
}
