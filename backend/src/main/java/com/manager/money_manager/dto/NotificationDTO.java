package com.manager.money_manager.dto;

import lombok.Getter;
import lombok.Setter;
import java.time.LocalDateTime;

@Getter
@Setter
public class NotificationDTO {
    private Long id;
    private String title;
    private String body;
    private boolean isRead;
    private LocalDateTime createdAt;
}
