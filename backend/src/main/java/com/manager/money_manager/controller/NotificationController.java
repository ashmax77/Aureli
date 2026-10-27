package com.manager.money_manager.controller;

import com.manager.money_manager.dto.NotificationDTO;
import com.manager.money_manager.model.User;
import com.manager.money_manager.service.NotificationService;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.data.web.PageableDefault;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import java.util.Map;

@RestController
@RequestMapping("/api/v1/notifications")
public class NotificationController {

    private final NotificationService notificationService;

    public NotificationController(NotificationService notificationService) {
        this.notificationService = notificationService;
    }

    @GetMapping
    public ResponseEntity<Page<NotificationDTO>> getNotifications(
            @RequestAttribute("currentUser") User user,
            @PageableDefault(size = 25, sort = "createdAt", direction = Sort.Direction.DESC) Pageable pageable) {
        Page<NotificationDTO> notifications = notificationService.getNotifications(user, pageable);
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
