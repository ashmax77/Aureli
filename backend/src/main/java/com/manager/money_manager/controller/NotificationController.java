package com.manager.money_manager.controller;

import com.manager.money_manager.dto.NotificationDTO;
import com.manager.money_manager.model.User;
import com.manager.money_manager.service.NotificationService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/v1/notifications")
public class NotificationController {

    private final NotificationService notificationService;

    public NotificationController(NotificationService notificationService) {
        this.notificationService = notificationService;
    }

    @GetMapping
    public ResponseEntity<List<NotificationDTO>> getNotifications(
            @RequestAttribute("currentUser") User user) {
        List<NotificationDTO> notifications = notificationService.getNotifications(user);
        return ResponseEntity.ok(notifications);
    }

    @GetMapping("/unread-count")
    public ResponseEntity<Map<String, Long>> getUnreadCount(
            @RequestAttribute("currentUser") User user) {
        long count = notificationService.getUnreadCount(user);
        return ResponseEntity.ok(Map.of("count", count));
    }

    @PostMapping("/mark-read")
    public ResponseEntity<Void> markAllAsRead(
            @RequestAttribute("currentUser") User user) {
        notificationService.markAllAsRead(user);
        return ResponseEntity.ok().build();
    }
}
