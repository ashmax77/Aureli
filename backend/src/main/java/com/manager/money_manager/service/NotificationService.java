package com.manager.money_manager.service;

import com.google.firebase.messaging.FirebaseMessaging;
import com.google.firebase.messaging.FirebaseMessagingException;
import com.google.firebase.messaging.Message;
import com.google.firebase.messaging.Notification;
import com.google.firebase.messaging.MessagingErrorCode;
import com.manager.money_manager.dto.NotificationDTO;
import com.manager.money_manager.model.AppNotification;
import com.manager.money_manager.model.User;
import com.manager.money_manager.model.UserDevice;
import com.manager.money_manager.repository.NotificationRepository;
import com.manager.money_manager.repository.UserDeviceRepository;
import com.manager.money_manager.repository.UserRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import java.util.List;
import java.util.stream.Collectors;

@Service
@Transactional
public class NotificationService {
    
    private static final Logger logger = LoggerFactory.getLogger(NotificationService.class);
    
    private final UserDeviceRepository userDeviceRepository;
    private final NotificationRepository notificationRepository;
    private final UserRepository userRepository;

    public NotificationService(UserDeviceRepository userDeviceRepository,
                               NotificationRepository notificationRepository,
                               UserRepository userRepository) {
        this.userDeviceRepository = userDeviceRepository;
        this.notificationRepository = notificationRepository;
        this.userRepository = userRepository;
    }

    @Async
    public void sendPushAlertsToUser(Long userId, String title, String body) {
        // 1. Persist the notification to the database
        User user = userRepository.findById(userId).orElse(null);
        if (user != null) {
            AppNotification notification = new AppNotification();
            notification.setUser(user);
            notification.setTitle(title);
            notification.setBody(body);
            notificationRepository.save(notification);
        }

        // 2. Send FCM push to all devices
        List<UserDevice> devices = userDeviceRepository.findByUserId(userId);
        if (devices.isEmpty()) {
            return;
        }

        for (UserDevice device : devices) {
            String token = device.getFcmToken();
            try {
                Message message = Message.builder()
                        .setToken(token)
                        .setNotification(Notification.builder()
                                .setTitle(title)
                                .setBody(body)
                                .build())
                        .build();

                String response = FirebaseMessaging.getInstance().send(message);
                logger.info("Successfully sent push notification to device id {}: {}", device.getId(), response);
            } catch (FirebaseMessagingException e) {
                logger.error("Firebase error sending to token {}: {}", token, e.getMessagingErrorCode());
                if (e.getMessagingErrorCode() == MessagingErrorCode.UNREGISTERED 
                        || e.getMessagingErrorCode() == MessagingErrorCode.INVALID_ARGUMENT) {
                    logger.warn("Deleting invalid or unregistered FCM token from DB: {}", token);
                    userDeviceRepository.deleteByFcmToken(token);
                }
            } catch (Exception e) {
                logger.error("Unknown error sending push notification to token {}: {}", token, e.getMessage());
            }
        }
    }

    public List<NotificationDTO> getNotifications(User user) {
        List<AppNotification> notifications = notificationRepository.findByUserIdOrderByCreatedAtDesc(user.getId());
        return notifications.stream().map(n -> {
            NotificationDTO dto = new NotificationDTO();
            dto.setId(n.getId());
            dto.setTitle(n.getTitle());
            dto.setBody(n.getBody());
            dto.setRead(n.isRead());
            dto.setCreatedAt(n.getCreatedAt());
            return dto;
        }).collect(Collectors.toList());
    }

    public long getUnreadCount(User user) {
        return notificationRepository.countByUserIdAndIsReadFalse(user.getId());
    }

    public void markAllAsRead(User user) {
        List<AppNotification> notifications = notificationRepository.findByUserIdOrderByCreatedAtDesc(user.getId());
        for (AppNotification n : notifications) {
            if (!n.isRead()) {
                n.setRead(true);
            }
        }
        notificationRepository.saveAll(notifications);
    }
}
