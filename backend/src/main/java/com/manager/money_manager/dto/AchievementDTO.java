package com.manager.money_manager.dto;

import lombok.Builder;
import lombok.Data;

@Data
@Builder
public class AchievementDTO {
    private String id;
    private String title;
    private String description;
    private String iconKey;
    private boolean isUnlocked;
    private String unlockedAt; // ISO-8601 string
}
