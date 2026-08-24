package com.manager.money_manager.dto;

import jakarta.validation.constraints.NotBlank;
import lombok.Getter;
import lombok.Setter;

@Getter
@Setter
public class FcmTokenUpdateRequest {

    @NotBlank(message = "Token must not be blank")
    private String fcmToken;
}
