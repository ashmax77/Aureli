package com.manager.money_manager.dto;

import com.fasterxml.jackson.annotation.JsonFormat;
import lombok.Getter;
import lombok.Setter;
import java.time.Instant;

@Getter
@Setter
public class NotificationDTO {
    private Long id;
    private String title;
    private String body;
    private boolean isRead;

    @JsonFormat(shape = JsonFormat.Shape.STRING, pattern = "yyyy-MM-dd'T'HH:mm:ss.SSSX", timezone = "UTC")
    private Instant createdAt;
}
